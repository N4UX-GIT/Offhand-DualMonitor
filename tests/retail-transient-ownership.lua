-- Regression coverage of actual local addon code with synthetic frames/time.
-- Reuses the reviewed fixture setup, never executes downloaded Blizzard code.
local input = assert(io.open("tests/party-editmode-and-void-rescue.lua", "r"))
local fixture = input:read("*a")
input:close()
local boundary = assert(fixture:find("-- TEST 2: Party Frame Click%-Safety"))
fixture = fixture:sub(1, boundary - 1)
local environment = setmetatable({}, { __index = _G })
environment._G = environment
environment.loadfile = function(path)
    local chunk, message = loadfile(path)
    if chunk then setfenv(chunk, environment) end
    return chunk, message
end
environment.print = function() end
local probes = [=[
do
    addon.isRetail, addon.isForever = true, false
    combatLocked = false
    local function resetPet()
        PetBattleFrame:ClearAllPoints()
        PetBattleFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
        PetBattleFrame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, 0)
        addon.HUD:PositionMainhandTransientFrames(metrics)
        assert(addon.HUD:GetPetBattleDiagnostics().boundsPrepared)
    end

    -- A: Bounds from Offhand's previous topology must remain recognizable as
    -- its own work, rather than becoming an apparent external custom anchor.
    do
        resetPet()
        local oldLeft, oldRight = metrics.gameLeft, metrics.gameRight
        metrics.gameLeft, metrics.gameRight = oldLeft + 100, oldRight - 100
        addon.HUD:PositionMainhandTransientFrames(metrics)
        local point = { PetBattleFrame:GetPoint(1) }
        assert(not addon.HUD:GetPetBattleDiagnostics().conflict and point[4] == metrics.gameLeft,
            "PET-TOPOLOGY: previously owned bounds must follow current metrics")
        metrics.gameLeft, metrics.gameRight = oldLeft, oldRight
        resetPet()
        PetBattleFrame:SetScale(0.5)
        addon.HUD:PositionMainhandTransientFrames(metrics)
        assert(select(4, PetBattleFrame:GetPoint(1)) == metrics.gameLeft * 2
            and not addon.HUD:GetPetBattleDiagnostics().conflict,
            "PET-TOPOLOGY: effective scale changes must preserve ownership")
        PetBattleFrame:SetScale(1)
        addon.HUD:PositionMainhandTransientFrames(metrics)
        combatLocked = true
        metrics.gameLeft, metrics.gameRight = oldLeft + 100, oldRight - 100
        addon.HUD:PositionMainhandTransientFrames(metrics)
        local queued = #combatQueue
        addon.HUD:PositionMainhandTransientFrames(metrics)
        assert(queued > 0 and #combatQueue == queued, "combat layout requests must coalesce per owner")
        LeaveCombat()
        assert(not addon.HUD:GetPetBattleDiagnostics().conflict
            and select(4, PetBattleFrame:GetPoint(1)) == metrics.gameLeft,
            "PET-TOPOLOGY: combat replay must follow latest metrics")
        metrics.gameLeft, metrics.gameRight = oldLeft, oldRight
        resetPet()
    end

    -- B: Turning off the owning feature should release still-owned bounds.
    -- No native external reset is synthesized on its behalf.
    do
        resetPet()
        addon.db.seamRedirect = false
        addon.HUD:PositionMainhandTransientFrames(metrics)
        local after = { PetBattleFrame:GetPoint(1) }
        assert(after[1] == "TOPLEFT" and after[3] == "TOPLEFT" and after[4] == 0
            and not addon.HUD:GetPetBattleDiagnostics().boundsPrepared,
            "PET-RELEASE: feature off must restore native bounds and release ownership")
        addon.db.seamRedirect = true
        resetPet()
        -- Releasing in combat waits and then rechecks current intent. A quick
        -- off/on must not replay stale cleanup over an enabled feature.
        combatLocked = true
        addon.db.seamRedirect = false
        addon.HUD:PositionMainhandTransientFrames(metrics)
        assert(select(1, PetBattleFrame:GetPoint(1)) == "BOTTOMLEFT")
        addon.db.seamRedirect = true
        LeaveCombat()
        assert(addon.HUD:GetPetBattleDiagnostics().boundsPrepared)
        combatLocked = true
        addon.db.enabled = false
        addon.HUD:PositionMainhandTransientFrames(metrics)
        LeaveCombat()
        assert(select(1, PetBattleFrame:GetPoint(1)) == "TOPLEFT"
            and not addon.HUD:GetPetBattleDiagnostics().boundsPrepared,
            "PET-RELEASE: addon disable must restore after combat")
        addon.db.enabled = true
        resetPet()
        metrics.isSpanned = false
        addon.HUD:PositionMainhandTransientFrames(metrics)
        assert(select(1, PetBattleFrame:GetPoint(1)) == "TOPLEFT",
            "PET-RELEASE: leaving spanned mode must restore native bounds")
        metrics.isSpanned = true
        resetPet()
        local external = makeMockFrame("AuditExternalPetOwner", 200, 100)
        PetBattleFrame:ClearAllPoints()
        PetBattleFrame:SetPoint("CENTER", external, "CENTER", 15, 30)
        addon.db.seamRedirect = false
        addon.HUD:PositionMainhandTransientFrames(metrics)
        assert(select(2, PetBattleFrame:GetPoint(1)) == external,
            "PET-RELEASE: cleanup must not overwrite an external owner")
        addon.db.seamRedirect = true
        resetPet()
    end

    -- C: After adoption, a later mover changes both anchor and user placement.
    -- The actual secure-transient path must notice the ownership transfer.
    do
        PVPMatchScoreboard.userPlaced = false
        PVPMatchScoreboard:ClearAllPoints()
        PVPMatchScoreboard:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        addon.HUD:PositionMainhandTransientFrames(metrics)
        local external = makeMockFrame("AuditExternalScoreboardOwner", 200, 100)
        PVPMatchScoreboard:ClearAllPoints()
        PVPMatchScoreboard:SetPoint("CENTER", external, "CENTER", 75, 25)
        PVPMatchScoreboard.userPlaced = true
        addon.HUD:PositionMainhandTransientFrames(metrics)
        local point = { PVPMatchScoreboard:GetPoint(1) }
        assert(point[2] == external and point[4] == 75 and point[5] == 25,
            "SECURE-TAKEOVER: later custom/user-placed anchors must survive")
        PVPMatchScoreboard.userPlaced = false
        for _ = 1, 3 do addon.HUD:PositionMainhandTransientFrames(metrics) end
        assert(select(2, PVPMatchScoreboard:GetPoint(1)) == external,
            "SECURE-TAKEOVER: yielding must survive subsequent maintenance passes")
        PVPMatchScoreboard.userPlaced = false
        PVPMatchScoreboard:ClearAllPoints()
        PVPMatchScoreboard:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        addon.HUD:PositionMainhandTransientFrames(metrics)
        for _, spec in ipairs(addon.HUDTransientPolicy.GetSpecs()) do
            if spec.secure and not spec.petBattleBounds then
                local frame = _G[spec.name]
                frame:ClearAllPoints()
                frame:SetPoint(spec.stockPoint, UIParent, spec.stockRelativePoint, spec.stockX, spec.stockY)
                addon.HUD:PositionMainhandTransientFrames(metrics)
                frame:ClearAllPoints()
                frame:SetPoint("CENTER", external, "CENTER", 13, 17)
                for _ = 1, 3 do addon.HUD:PositionMainhandTransientFrames(metrics) end
                assert(select(2, frame:GetPoint(1)) == external,
                    "secure transient must keep yielding after takeover: " .. spec.name)
                table.insert(UIParent.children, frame)
                addon.HUD.popupTicker.callback()
                assert(select(2, frame:GetPoint(1)) == external,
                    "generic scanner must not bypass dedicated ownership: " .. spec.name)
                if spec.groupLootRows then
                    assert(not addon.HUD:GetGroupLootDiagnostics().rowMoverActive,
                        "group-loot takeover must stop dependent row placement")
                end
                frame:ClearAllPoints()
                frame:SetPoint(spec.stockPoint, UIParent, spec.stockRelativePoint, spec.stockX, spec.stockY)
                addon.HUD:PositionMainhandTransientFrames(metrics)
                assert(select(3, frame:GetPoint(1)) == "BOTTOMLEFT",
                    "reviewed native reset must allow reacquisition: " .. spec.name)
            end
        end
    end

    -- D: The Trading Post adapter must not restore over a later mover when
    -- the player disables Offhand. Execute the local adapter, not a duplicate.
    do
        local previousSetter = addon.Viewport.SetPoint
        addon.Viewport.SetPoint = function(_, frame, point, relativePoint, x, y)
            local factor = UIParent:GetEffectiveScale() / frame:GetEffectiveScale()
            frame:SetPoint(point, UIParent, relativePoint, x * factor, y * factor)
        end
        PerksProgramFrame = makeMockFrame("PerksProgramFrame", 4000, 2560)
        PerksProgramFrame:ClearAllPoints()
        PerksProgramFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
        PerksProgramFrame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, 0)
        PerksProgramFrame:Hide()
        assert(loadfile("Core/RetailFullscreen.lua"))("Offhand", addon)
        assert(addon.RetailFullscreen:Apply(), "audit requires Trading Post adoption")
        local external = makeMockFrame("AuditTradingPostOwner", 100, 100)
        PerksProgramFrame:ClearAllPoints()
        PerksProgramFrame:SetPoint("CENTER", external, "CENTER", 40, 20)
        PerksProgramFrame:SetScale(0.8)
        addon.db.enabled = false
        addon.RetailFullscreen:Apply()
        local point = { PerksProgramFrame:GetPoint(1) }
        assert(point[2] == external and PerksProgramFrame:GetScale() == 0.8,
            "FULLSCREEN-RESTORE: cleanup must preserve later anchor and scale ownership")
        addon.db.enabled = true
        addon.RetailFullscreen:Apply()
        assert(select(2, PerksProgramFrame:GetPoint(1)) == external
            and PerksProgramFrame:GetScale() == 0.8,
            "FULLSCREEN-RESTORE: re-enable must keep yielding to the external owner")
        addon.Viewport.SetPoint = previousSetter
    end

    -- E: The generic UISpecialFrames OnShow closure captures the first metrics
    -- rather than consulting the current topology and feature switch.
    do
        local specialFrames = UISpecialFrames
        local popup = makeMockFrame("OffhandAuditSpecialPopup", 400, 200)
        popup:ClearAllPoints()
        popup:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        popup:Hide()
        UISpecialFrames = { "OffhandAuditSpecialPopup" }
        addon.HUD.popupTicker.callback()
        assert(popup:GetScript("OnShow"), "audit requires real popup hook installation")
        local oldLeft, oldRight = metrics.gameLeft, metrics.gameRight
        metrics.gameLeft, metrics.gameRight = oldLeft + 200, oldRight + 200
        popup:Show()
        local point = { popup:GetPoint(1) }
        local actualCenter = UIParent:GetWidth() / 2 + point[4]
        assert(actualCenter == (metrics.gameLeft + metrics.gameRight) / 2,
            "POPUP-STALE-GEOMETRY: OnShow must use current display metrics")
        metrics.gameLeft, metrics.gameRight = oldLeft, oldRight
        popup:Hide()
        popup:ClearAllPoints()
        popup:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        addon.db.seamRedirect = false
        local writes = popup.setPointCalls
        popup:Show()
        assert(popup.setPointCalls == writes,
            "POPUP-FEATURE-OFF: existing callbacks must honor feature off")
        table.insert(UIParent.children, popup)
        addon.HUD.popupTicker.callback()
        assert(popup.setPointCalls == writes,
            "POPUP-FEATURE-OFF: generic scanner must honor feature off")
        addon.db.seamRedirect = true
        -- An existing hook must also recheck span, protection, combat and
        -- explicit custom placement rather than blindly recentering on show.
        popup:Hide()
        metrics.isSpanned = false
        popup:Show()
        assert(popup.setPointCalls == writes)
        metrics.isSpanned = true
        popup:Hide()
        combatLocked = true
        popup:Show()
        assert(popup.setPointCalls == writes)
        combatLocked = false
        popup:Hide()
        popup.userPlaced = true
        popup:Show()
        assert(popup.setPointCalls == writes)
        popup.userPlaced = false
        popup:Hide()
        local originalProtected = popup.IsProtected
        popup.IsProtected = function() return true end
        popup:Show()
        assert(popup.setPointCalls == writes)
        popup.IsProtected = originalProtected
        popup:Hide()
        popup:ClearAllPoints()
        popup:SetPoint("CENTER", UIParent, "CENTER", 75, 25)
        writes = popup.setPointCalls
        popup:Show()
        assert(popup.setPointCalls == writes, "custom popup offsets must survive OnShow")
        popup:Hide()
        popup:ClearAllPoints()
        popup:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        popup:Show()
        assert(popup.setPointCalls > writes, "re-enabled popup redirection must resume")
        UISpecialFrames = specialFrames
    end
end
]=]
local run = assert(loadstring(fixture .. "\n" .. probes, "@retail-transient-audit"))
setfenv(run, environment)
run()
print("PASS: Retail transient topology, release, external ownership and popup option contracts")
