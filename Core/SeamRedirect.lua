-- Anchor managed HUD frames inside the same rectangle used by WorldFrame.
local _, Offhand = ...
local HUD = {}
Offhand.SeamRedirect = HUD
Offhand.HUD = HUD
local aligning, pending = false, false
local hooks = {}
local desiredFrames = {}
local function IsAddonPresent(name)
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        if C_AddOns.IsAddOnLoaded(name) then return true end
    elseif IsAddOnLoaded then
        if IsAddOnLoaded(name) then return true end
    end
    if _G and _G[name] ~= nil then return true end
    return false
end

local function HasCustomActionBarAddon()
    -- Action bar addons generally hide or unregister the native MainMenuBar.
    if _G.Bartender4 or _G.Dominos or _G.ElvUI or _G.Tukui or _G.ConsolePort then return true end
    local main = _G.MainMenuBar or _G.MainActionBar
    if not main then return true end
    return false
end

local function HasCustomBagAddon()
    if _G.Bagnon or _G.AdiBags or _G.ArkInventory or _G.BetterBags or _G.Inventorian or _G.ElvUI or _G.Tukui then return true end
    
    local c1 = _G.ContainerFrame1
    if not c1 then return true end
    
    return false
end

local function HasCustomMinimapAddon()
    -- Heuristic check for minimap overrides.
    if _G.SexyMap or _G.Carbonite or _G.ElvUI then return true end
    
    local mm = _G.MinimapCluster
    if not mm then return true end
    
    -- If another addon has forcibly moved or unanchored the Minimap natively without Offhand's permission
    if mm.IsUserPlaced and mm:IsUserPlaced() then return true end
    
    return false
end

Offhand.HasCustomActionBarAddon = HasCustomActionBarAddon
Offhand.HasCustomBagAddon = HasCustomBagAddon
Offhand.HasCustomMinimapAddon = HasCustomMinimapAddon

local actionNames = {"MainMenuBar", "MainActionBar", "StatusTrackingBarManager", "MainMenuExpBar",
    "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarLeft", "MultiBarRight",
    }
local function Remember(frame)
    desiredFrames[frame] = desiredFrames[frame] or {}
    return desiredFrames[frame]
end

-- Rewriting identical anchors dirties Blizzard layout again on the next frame.
local function Points(frame, ...)
    local desired = {...}
    Remember(frame).points = desired
    local same = frame:GetNumPoints() == #desired
    if same then
        for i, point in ipairs(desired) do
            local a, b, c, x, y = frame:GetPoint(i)
            if a ~= point[1] or b ~= point[2] or c ~= point[3]
                or math.abs((x or 0) - point[4]) > 0.001
                or math.abs((y or 0) - point[5]) > 0.001 then
                same = false; break
            end
        end
    end
    if same then return end
    frame:ClearAllPoints()
    for _, point in ipairs(desired) do frame:SetPoint(unpack(point)) end
end

local function ScreenPoint(frame, point, x, y)
    local factor = UIParent:GetEffectiveScale() / frame:GetEffectiveScale()
    Points(frame, {point, UIParent, "BOTTOMLEFT", x * factor, y * factor})
end

local function Anchor(frame, point, m, x, y, force)
    if not frame then return end
    if not force and frame.IsUserPlaced and frame:IsUserPlaced() then return end
    if not force and frame.IsInDefaultPosition and not frame:IsInDefaultPosition() then return end
    local px = point:find("LEFT") and m.gameLeft or point:find("RIGHT") and m.gameRight
        or (m.gameLeft + m.gameRight) / 2
    local py = point:find("TOP") and m.gameTop or point:find("BOTTOM") and m.gameBottom
        or (m.gameBottom + m.gameTop) / 2
    ScreenPoint(frame, point,
        px + (x or 0) * m.hudScale, py + (y or 0) * m.hudScale)
end

local function Prepare(frame, m)
    if not frame then return end
    frame:SetClampedToScreen(false)
end

function HUD:RequestLayout()
    if aligning or pending or not Offhand.db or not Offhand.db.enabled then return end
    pending = true
    C_Timer.After(0.05, function()
        if not Offhand.db or not Offhand.db.enabled then pending = false; return end
        -- A HUD repair must not resize WorldFrame, the deck or docked modules.
        Offhand:RunOrQueueCombat(function()
            pending = false
            if Offhand.db and Offhand.db.enabled then HUD:AlignHUDFrames() end
        end)
    end)
end

function HUD:AlignChatFrame(m)
    if not ChatFrame1 or Offhand.db.dockChat == false then return end
    local chat = ChatFrame1
    -- Chattynator replaces the visible chat frame. Use its exposed handler to
    -- locate the primary window without changing its saved profile or messages.
    local handler = Chattynator and Chattynator.API and Chattynator.API.GetHyperlinkHandler
        and Chattynator.API.GetHyperlinkHandler()
    if handler then
        for _, child in ipairs({handler:GetChildren()}) do
            if child:GetID() == 1 and child.ScrollingMessages then chat = child; break end
        end
    end
    Prepare(chat, m)
    local chatName = (chat.GetName and chat:GetName()) or "ChatFrame1"
    local isWs = (Offhand.db and Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions[chatName])
        or (Offhand.Canvas and Offhand.Canvas.IsFrameOnWorkspace and Offhand.Canvas.IsFrameOnWorkspace(chat))
    if isWs then
        if Offhand.Canvas and Offhand.Canvas.RestoreWorkspacePosition then
            Offhand.Canvas:RestoreWorkspacePosition(chat)
        elseif Offhand.Canvas and Offhand.Canvas.OnPanelDragStop and not (Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions[chatName]) then
            Offhand.Canvas.OnPanelDragStop(chat)
        end
        if ChatFrame1EditBox then
            Points(ChatFrame1EditBox,
                {"TOPLEFT", chat, "BOTTOMLEFT", 0, 0},
                {"TOPRIGHT", chat, "BOTTOMRIGHT", 0, 0})
        end
        return
    end
    if chat.IsUserPlaced and chat:IsUserPlaced() and Offhand.db.chatPosition ~= "DECK" then return end
    if chat ~= ChatFrame1 and not hooks[chat] then
        hooks[chat] = true
        hooksecurefunc(chat, "SetPoint", function()
            local isWorkspace = (Offhand.db and Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions[chatName])
                or (Offhand.Canvas and Offhand.Canvas.IsFrameOnWorkspace and Offhand.Canvas.IsFrameOnWorkspace(chat))
            if not isWorkspace and not (chat.IsUserPlaced and chat:IsUserPlaced()) then
                HUD:RequestLayout()
            end
        end)
    end
    if Offhand.db.chatPosition == "DECK" and Offhand.canvas then
        pcall(function() chat:SetUserPlaced(false) end)
        local x = Offhand.db.primaryPosition == "LEFT" and m.gameRight + m.bezel or 0
        ScreenPoint(chat, "BOTTOMLEFT",
            x + 24 * m.hudScale, 45 * m.hudScale)
        chat:SetSize(math.min(460, m.deckWidth / m.hudScale - 48), 220)
    else
        Anchor(chat, "BOTTOMLEFT", m, 24, 120)
        chat:SetSize(math.min(460, m.gameWidth / m.hudScale * 0.40), 220)
    end
    if ChatFrame1EditBox then
        Points(ChatFrame1EditBox,
            {"TOPLEFT", chat, "BOTTOMLEFT", 0, 0},
            {"TOPRIGHT", chat, "BOTTOMRIGHT", 0, 0})
    end
end

function HUD:AlignHUDFrames(m)
    if aligning or InCombatLockdown() or not Offhand.db.enabled then return end
    aligning = true
    local ok, err = pcall(function()
        m = m or Offhand.Viewport:GetMetrics()
        if not HasCustomActionBarAddon() then
            local main = MainMenuBar or MainActionBar
            Prepare(main, m)
            if main then Anchor(main, "BOTTOM", m, 0, 0) end
            if MainActionBar and MainActionBar ~= main and (not MainActionBar.IsInDefaultPosition or MainActionBar:IsInDefaultPosition()) then
                Prepare(MainActionBar, m)
                Points(MainActionBar, {"BOTTOMLEFT", main, "BOTTOMLEFT", 8, 4})
            end

            local xp = StatusTrackingBarManager or MainMenuExpBar
            Prepare(xp, m)
            if xp and main and (not xp.IsInDefaultPosition or xp:IsInDefaultPosition()) then
                Points(xp, {"BOTTOM", main, "TOP", 0, -2})
            end
            -- Preserve Blizzard's visibility rules (XP at max level, pet, stance, etc.).
            local bottomLeft, bottomRight = MultiBarBottomLeft, MultiBarBottomRight
            Prepare(bottomLeft, m)
            Prepare(bottomRight, m)
            if bottomLeft and main and (not bottomLeft.IsInDefaultPosition or bottomLeft:IsInDefaultPosition()) then
                Points(bottomLeft, {"BOTTOMLEFT", main, "TOPLEFT", 0, 8})
            end
            if bottomRight and main and (not bottomRight.IsInDefaultPosition or bottomRight:IsInDefaultPosition()) then
                Points(bottomRight, {"BOTTOMLEFT", main, "TOPLEFT", 515, 8})
            end
                        -- StanceBar and PetActionBar are inherently tied to EditMode and deeply protected.
            -- Offhand no longer manually points these frames, avoiding the ADDON_ACTION_BLOCKED taint.
            -- EditMode will natively drag them alongside the MainMenuBar.
            Prepare(MultiBarRight, m)
            if MultiBarRight then Anchor(MultiBarRight, "RIGHT", m, -4, 0) end
            Prepare(MultiBarLeft, m)
            if MultiBarLeft then Anchor(MultiBarLeft, "RIGHT", m, -48, 0) end
        end

        for _, item in ipairs({
            {"MinimapCluster", "TOPRIGHT", 0, 0},
            {"PlayerFrame", "TOPLEFT", 16, -16},
            {"TargetFrame", "TOPLEFT", 260, -16},
            {"PartyMemberFrame1", "TOPLEFT", 16, -160},
            {"CompactPartyFrame", "TOPLEFT", 16, -160},
            {"BuffFrame", "TOPRIGHT", -210, -16},
            {"BuffCluster", "TOPRIGHT", -210, -16},
            {"CastingBarFrame", "BOTTOM", 0, 165},
            {"PlayerCastingBarFrame", "BOTTOM", 0, 165},
        }) do
            local frame = _G[item[1]]
            if frame then
                if item[1] == "MinimapCluster" and HasCustomMinimapAddon() then
                    -- Yield completely to custom minimap addon (e.g. SexyMap, BasicMinimap, ElvUI)
                elseif frame._OffhandDragging then
                    -- Frame is actively being dragged by the player; do not interrupt!
                else
                    Prepare(frame, m)
                    local isWorkspace = Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions[item[1]]
                    if isWorkspace then
                        if Offhand.Canvas and Offhand.Canvas.RestoreWorkspacePosition then
                            Offhand.Canvas.RestoreWorkspacePosition(frame)
                        end
                    else
                        if item[1] == "MinimapCluster" then
                            pcall(function() frame:SetUserPlaced(false) end)
                            Anchor(frame, item[2], m, item[3], item[4], true)
                            if frame.IsShown and not frame:IsShown() and frame.Show then
                                frame:Show()
                            end
                            if frame.SetAlpha then frame:SetAlpha(1) end
                        elseif item[1] == "PartyMemberFrame1" or item[1] == "CompactPartyFrame" then
                            local mainPos = Offhand.db.savedMainPositions and Offhand.db.savedMainPositions[item[1]]
                            local isEditModeCustomized = frame.IsInDefaultPosition and not frame:IsInDefaultPosition()
                            if isEditModeCustomized then
                                -- Yield to Edit Mode
                            elseif mainPos and mainPos.x and mainPos.y then
                                local factor = UIParent:GetEffectiveScale() / frame:GetEffectiveScale()
                                frame:ClearAllPoints()
                                frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", mainPos.x * factor, mainPos.y * factor)
                            elseif not (frame.IsUserPlaced and frame:IsUserPlaced()) then
                                Anchor(frame, item[2], m, item[3], item[4], false)
                            end
                        elseif not (frame.IsUserPlaced and frame:IsUserPlaced()) then
                            Anchor(frame, item[2], m, item[3], item[4], false)
                        end
                    end
                end
            end
        end

        self:AlignChatFrame(m)
        if Offhand.db.seamRedirect then
            for _, item in ipairs({{"UIErrorsFrame", -60}, {"RaidWarningFrame", -100}}) do
                local frame = _G[item[1]]
                Prepare(frame, m)
                if frame then Anchor(frame, "TOP", m, 0, item[2]) end
            end
        end
    end)
    aligning = false
    if not ok then Offhand:Print("HUD layout error: %s", tostring(err)) end
end

-- Replay the last committed layout for just the frame Blizzard changed. A timer
-- exposes the reset geometry for several rendered frames even when idle.
-- Cache only layout written by AlignHUDFrames; never replace Blizzard methods or
-- force visibility/action state. The guard prevents our setters from re-entering.
function HUD:RepairFrame(frame)
    if aligning or not Offhand.db or not Offhand.db.enabled then return end
    if frame.IsUserPlaced and frame:IsUserPlaced() then return end
    if frame.IsInDefaultPosition and not frame:IsInDefaultPosition() then return end
    if HasCustomActionBarAddon() then return end
    local desired = desiredFrames[frame]
    if not desired then return end
    if InCombatLockdown() then self:RequestLayout(); return end
    aligning = true
    local ok, err = pcall(function()
        if desired.points then Points(frame, unpack(desired.points)) end
    end)
    aligning = false
    if not ok then Offhand:Print("HUD layout error: %s", tostring(err)) end
end

function HUD:IsManagedFrame(frame)
    return desiredFrames[frame] ~= nil
end

function HUD:HookFrames()
    if not HasCustomActionBarAddon() then
        if not self.managerHooked and UIParent_ManageFramePositions then
            self.managerHooked = true
            hooksecurefunc("UIParent_ManageFramePositions", function()
                if InCombatLockdown() then return end
                for _, name in ipairs(actionNames) do
                    local frame = _G[name]
                    if frame then HUD:RepairFrame(frame) end
                end
                HUD:RequestLayout()
            end)
        end
        for _, name in ipairs(actionNames) do
            local frame = _G[name]
            if frame and not hooks[frame] then
                hooks[frame] = true
                hooksecurefunc(frame, "SetPoint", function() HUD:RepairFrame(frame) end)
            end
        end
    end
    for _, name in ipairs({"PlayerFrame", "TargetFrame", "PartyMemberFrame1", "CompactPartyFrame", "ChatFrame1",
        "BuffFrame", "UIErrorsFrame", "RaidWarningFrame"}) do
        local frame = _G[name]
        if frame and not hooks[frame] then
            hooks[frame] = true
            hooksecurefunc(frame, "SetPoint", function()
                local isWs = Offhand.db and Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions[name]
                if not isWs and not (frame.IsUserPlaced and frame:IsUserPlaced()) then
                    HUD:RequestLayout()
                end
            end)
        end
    end

    -- Center Game Menu (Escape menu), AddonList, Edit Mode dialogs, and settings panels onto the primary game monitor
    local menuFrameNames = {
        "GameMenuFrame", "SettingsPanel", "InterfaceOptionsFrame", "VideoOptionsFrame",
        "AddonList", "KeyBindingFrame", "HelpFrame",
        "BugSackFrame", "RedIsFriendFrame",
        "EditModeSystemSettingsDialog", "EditModeUnsavedChangesDialog", "EditModeDialog"
    }

    local function PositionEditMode()
        if InCombatLockdown() or not Offhand.db or not Offhand.db.enabled then return end
        local m = Offhand.Viewport:GetMetrics()
        if not m or not m.isSpanned then return end
        local cx = (m.gameLeft + m.gameRight) / 2
        local factor = UIParent:GetEffectiveScale()

        -- Dock EditModeManagerFrame toolbar cleanly at the top-center of the 3D Game View
        local mgr = _G["EditModeManagerFrame"]
        if mgr and mgr:IsShown() then
            mgr:ClearAllPoints()
            local mScale = mgr:GetEffectiveScale() or factor
            local scaleFactor = factor / mScale
            local offsetX = cx - (UIParent:GetWidth() / 2)
            local offsetY = (m.gameTop - 20) - (UIParent:GetHeight() / 2)
            mgr:SetPoint("TOP", UIParent, "CENTER", offsetX * scaleFactor, offsetY * scaleFactor)
        end

        -- Center dialogs inside the 3D Game View
        for _, name in ipairs({"EditModeSystemSettingsDialog", "EditModeUnsavedChangesDialog", "EditModeDialog"}) do
            local dlg = _G[name]
            if dlg and dlg:IsShown() then
                dlg:ClearAllPoints()
                local dScale = dlg:GetEffectiveScale() or factor
                local scaleFactor = factor / dScale
                local cy = (m.gameBottom + m.gameTop) / 2
                local offsetX = cx - (UIParent:GetWidth() / 2)
                local offsetY = cy - (UIParent:GetHeight() / 2)
                dlg:SetPoint("CENTER", UIParent, "CENTER", offsetX * scaleFactor, offsetY * scaleFactor)
            end
        end
    end

    local function CenterGameMenu()
        PositionEditMode()
        for _, name in ipairs(menuFrameNames) do
            local frame = _G[name]
            if frame and frame:IsShown() and not InCombatLockdown() and Offhand.db and Offhand.db.enabled then
                local m = Offhand.Viewport:GetMetrics()
                frame:ClearAllPoints()
                local cx = (m.gameLeft + m.gameRight) / 2
                local cy = (m.gameBottom + m.gameTop) / 2
                local factor = UIParent:GetEffectiveScale() / frame:GetEffectiveScale()
                local offsetX = cx - (UIParent:GetWidth() / 2)
                local offsetY = cy - (UIParent:GetHeight() / 2)
                frame:SetPoint("CENTER", UIParent, "CENTER", offsetX * factor, offsetY * factor)
            end
        end
    end

    local function HookMenuFrame(name)
        local frame = _G[name]
        if frame and not hooks[frame] then
            hooks[frame] = true
            if SetUIPanelAttribute then
                pcall(function() SetUIPanelAttribute(frame, "area", nil) end)
            end
            frame:HookScript("OnShow", function(self)
                CenterGameMenu()
                C_Timer.After(0, CenterGameMenu)
            end)
            if name == "AddonList" and UISpecialFrames then
                local found = false
                for _, sName in ipairs(UISpecialFrames) do
                    if sName == "AddonList" then found = true; break end
                end
                if not found then table.insert(UISpecialFrames, "AddonList") end
            end
        end
    end

    if UIPanelWindows then
        for _, name in ipairs(menuFrameNames) do
            if UIPanelWindows[name] then
                UIPanelWindows[name].area = nil
                UIPanelWindows[name].centerFrameSkipAnchoring = true
            end
        end
    end

    for _, name in ipairs(menuFrameNames) do
        HookMenuFrame(name)
    end

    local function PatchEditModeUtil()
        if not _G.EditModeUtil then return end
        if _G.EditModeUtil._offhand_patched then return end
        _G.EditModeUtil._offhand_patched = true

        local function SafeGetBarsLayoutSize(barHierarchy, getWidth)
            if not barHierarchy then return 0 end
            for _, bar in ipairs(barHierarchy) do
                if bar and bar.IsVisible and bar:IsVisible()
                    and (not bar.IsInitialized or bar:IsInitialized())
                    and (not bar.IsInDefaultPosition or bar:IsInDefaultPosition())
                    then
                    local offset, size
                    if getWidth then
                        offset = select(4, bar:GetPoint(1)) or 0
                        size = (bar.GetWidth and bar:GetWidth()) or 0
                    else
                        offset = select(5, bar:GetPoint(1)) or 0
                        size = (bar.GetHeight and bar:GetHeight()) or 0
                    end
                    offset = tonumber(offset) or 0
                    size = tonumber(size) or 0
                    return math.abs(offset) + size
                end
            end
            return 0
        end

        _G.EditModeUtil.GetBottomActionBarHeight = function(self)
            local barHierarchy = {
                _G.MainMenuBarVehicleLeaveButton, _G.PossessActionBar, _G.PetActionBar,
                _G.StanceBar, _G.OverrideActionBar, _G.MultiBarBottomRight,
                _G.MultiBarBottomLeft, _G.MainActionBar
            }
            return SafeGetBarsLayoutSize(barHierarchy, false)
        end

        _G.EditModeUtil.GetRightActionBarWidth = function(self)
            local barHierarchy = { _G.MultiBarLeft, _G.MultiBarRight }
            return SafeGetBarsLayoutSize(barHierarchy, true)
        end
    end

    local function CheckEditModeHooks()
        PatchEditModeUtil()
        local mgr = _G["EditModeManagerFrame"]
        if mgr and not hooks[mgr] then
            hooks[mgr] = true
            mgr:HookScript("OnShow", function()
                PositionEditMode()
                C_Timer.After(0, PositionEditMode)
            end)
        end
        for _, name in ipairs({"EditModeSystemSettingsDialog", "EditModeUnsavedChangesDialog", "EditModeDialog"}) do
            HookMenuFrame(name)
        end
    end
    CheckEditModeHooks()

    -- Universal Void Rescue & Popup Redirection Engine
    -- Rescues frames anchoring into the unrendered black space above the 3D Game Viewport,
    -- and redirects popups that anchor to the bezel seam center.
    local function RedirectExternalPopups()
        if InCombatLockdown() or not Offhand.db or not Offhand.db.enabled then return end
        
        local m = Offhand.Viewport:GetMetrics()
        if not m or not m.isSpanned then return end
        local cx = (m.gameLeft + m.gameRight) / 2
        local cy = (m.gameBottom + m.gameTop) / 2
        local parentScale = UIParent:GetEffectiveScale() or 1
        local isPortraitDeck = Offhand.db.primaryPosition ~= "LEFT"
        local gameLeftThreshold = isPortraitDeck and (m.deckWidth - 20) or 0
        local gameRightThreshold = isPortraitDeck and m.screenWidth or m.gameRight

        -- 1. Check UISpecialFrames (standard config panels)
        if UISpecialFrames then
            for _, name in ipairs(UISpecialFrames) do
                local frame = _G[name]
                if frame and type(frame) == "table" and frame.GetPoint and not hooks[frame] and frame.IsProtected and not frame:IsProtected() then
                    hooks[frame] = true
                    frame:HookScript("OnShow", function(self)
                        if InCombatLockdown() or not Offhand.db or not Offhand.db.enabled then return end
                        local pt, rel = self:GetPoint(1)
                        if (rel == UIParent or rel == nil) and (pt == "CENTER") then
                            self:ClearAllPoints()
                            local factor = UIParent:GetEffectiveScale() / self:GetEffectiveScale()
                            local offsetX = cx - (UIParent:GetWidth() / 2)
                            local offsetY = cy - (UIParent:GetHeight() / 2)
                            self:SetPoint("CENTER", UIParent, "CENTER", offsetX * factor, offsetY * factor)
                        end
                    end)
                end
            end
        end

        -- 2. Void Rescue: Detect any frame on the game monitor side whose top extends into the black void above m.gameTop
        local voidTargets = {
            _G.EditModeManagerFrame,
            _G.EditModeSystemSettingsDialog,
            _G.EditModeUnsavedChangesDialog,
        }
        for _, frame in ipairs(voidTargets) do
            if frame and type(frame) == "table" then
                pcall(function()
                    if frame.IsForbidden and frame:IsForbidden() then return end
                    if frame.IsProtected and frame:IsProtected() then return end
                    if not frame.IsShown or not frame:IsShown() then return end
                    local fScale = (frame.GetEffectiveScale and frame:GetEffectiveScale()) or parentScale
                    if fScale <= 0 then fScale = parentScale end
                    local scaleFactor = fScale / parentScale
                    local top = (frame:GetTop() or 0) * scaleFactor
                    local left = (frame:GetLeft() or 0) * scaleFactor
                    local onGameSide = isPortraitDeck and (left >= gameLeftThreshold) or (left < gameRightThreshold)
                    if onGameSide and top > (m.gameTop + 2) then
                        frame:ClearAllPoints()
                        local invFactor = parentScale / fScale
                        local offsetX = cx - (UIParent:GetWidth() / 2)
                        local offsetY = cy - (UIParent:GetHeight() / 2)
                        frame:SetPoint("CENTER", UIParent, "CENTER", offsetX * invFactor, offsetY * invFactor)
                    end
                end)
            end
        end

        -- 3. Scan active children of UIParent for rogue centered popup frames or frames in the void
        for _, child in ipairs({UIParent:GetChildren()}) do
            if type(child) == "table" and child ~= WorldFrame and child ~= Offhand.canvas then
                pcall(function()
                    if child.IsForbidden and child:IsForbidden() then return end
                    if not child.IsShown or not child:IsShown() then return end
                    if child.IsProtected and child:IsProtected() then return end

                    local cName
                    if child.GetName then
                        local okName, name = pcall(child.GetName, child)
                        if okName then cName = name end
                    end
                    if cName == "OffhandCanvasFrame" then return end

                    -- Void Rescue check for general children on the game side
                    local fScale = (child.GetEffectiveScale and child:GetEffectiveScale()) or parentScale
                    if fScale <= 0 then fScale = parentScale end
                    local scaleFactor = fScale / parentScale
                    local top = (child.GetTop and child:GetTop() or 0) * scaleFactor
                    local left = (child.GetLeft and child:GetLeft() or 0) * scaleFactor
                    local onGameSide = isPortraitDeck and (left >= gameLeftThreshold) or (left < gameRightThreshold)
                    if onGameSide and top > (m.gameTop + 2) then
                        if child.GetPoint and child.ClearAllPoints and child.SetPoint then
                            child:ClearAllPoints()
                            local invFactor = parentScale / fScale
                            local offsetX = cx - (UIParent:GetWidth() / 2)
                            local offsetY = cy - (UIParent:GetHeight() / 2)
                            child:SetPoint("CENTER", UIParent, "CENTER", offsetX * invFactor, offsetY * invFactor)
                        end
                    end

                    -- Seam centering check
                    if not child._offhand_centered and child.GetNumPoints and child:GetNumPoints() == 1 then
                        local pt, rel, relPt, x, y = child:GetPoint(1)
                        if (rel == UIParent or rel == nil) and pt == "CENTER" and relPt == "CENTER" then
                            if (x or 0) == 0 and (y or 0) == 0 then
                                child._offhand_centered = true
                                if child.ClearAllPoints and child.SetPoint then
                                    child:ClearAllPoints()
                                    local factor = UIParent:GetEffectiveScale() / child:GetEffectiveScale()
                                    local offsetX = cx - (UIParent:GetWidth() / 2)
                                    local offsetY = cy - (UIParent:GetHeight() / 2)
                                    child:SetPoint("CENTER", UIParent, "CENTER", offsetX * factor, offsetY * factor)
                                end
                            end
                        end
                    end
                end)
            end
        end
    end

    if C_Timer and C_Timer.NewTicker then
        C_Timer.NewTicker(2, function()
            RedirectExternalPopups()
            CheckEditModeHooks()
        end)
    end

        local function AutoLoadEditModeLayout()
        if InCombatLockdown() or not Offhand.db or not Offhand.db.enabled then return end
        if not C_EditMode or not C_EditMode.GetLayouts then return end
        
        local layoutData = C_EditMode.GetLayouts()
        if not layoutData or not layoutData.layouts then return end
        
        local targetName = "Offhand"
        for index, layout in ipairs(layoutData.layouts) do
            if layout.layoutName and string.match(string.lower(layout.layoutName), string.lower(targetName)) then
                local id = layout.layoutType or index
                if layoutData.activeLayout ~= id then
                    if EditModeManagerFrame and EditModeManagerFrame.SelectLayout then
                        EditModeManagerFrame:SelectLayout(index)
                    elseif C_EditMode.SetActiveLayout then
                        C_EditMode.SetActiveLayout(id)
                    end
                    Offhand:Print("Auto-loaded Edit Mode layout: " .. layout.layoutName)
                end
                break
            end
        end
    end

    local function UpdateUIPanelOffsets()
        if InCombatLockdown() or not Offhand.db or not Offhand.db.enabled then return end
        local m = Offhand.Viewport:GetMetrics()
        if m and m.isSpanned and UIParent.SetAttribute then
            -- Default blizzard panels to the Game World monitor, but add standard 16px left padding
            -- and preserve Blizzard's native -104px top padding (so they don't jam into the absolute corner)
            local left = (m.gameLeft or 0) + 16
            UIParent:SetAttribute("LEFT_OFFSET", left)
            
            local topDelta = (UIParent:GetHeight() or 0) - (m.gameTop or 0)
            UIParent:SetAttribute("TOP_OFFSET", -104 - (topDelta > 0 and topDelta or 0))
        end
    end

    UpdateUIPanelOffsets()
    C_Timer.After(3, AutoLoadEditModeLayout)

    if not self.menuHooksInstalled then
        self.menuHooksInstalled = true
        if ToggleGameMenu then
            hooksecurefunc("ToggleGameMenu", function()
                CenterGameMenu()
                C_Timer.After(0, CenterGameMenu)
                C_Timer.After(0.05, CenterGameMenu)
            end)
        end
        if CreateFrame then
            local editModeLoader = CreateFrame("Frame")
            if editModeLoader and editModeLoader.RegisterEvent and editModeLoader.SetScript then
                editModeLoader:RegisterEvent("ADDON_LOADED")
                editModeLoader:SetScript("OnEvent", function(_, _, addonName)
                    if addonName == "Blizzard_EditMode" or addonName == "Blizzard_Settings" then
                        CheckEditModeHooks()
                        for _, name in ipairs(menuFrameNames) do HookMenuFrame(name) end
                    end
                end)
            end
        end
        if ShowUIPanel then
            hooksecurefunc("ShowUIPanel", function(frame)
                if frame and not InCombatLockdown() and Offhand.db and Offhand.db.enabled then
                    local name = frame.GetName and frame:GetName()
                    if name then
                        local isMenu = false
                        for _, n in ipairs(menuFrameNames) do
                            if n == name then isMenu = true; break end
                        end
                        
                        local info = UIPanelWindows and UIPanelWindows[name]
                        if isMenu or (info and info.area == "center") then
                            local function DoCenter()
                                if frame:IsShown() and not InCombatLockdown() then
                                    local m = Offhand.Viewport:GetMetrics()
                                    frame:ClearAllPoints()
                                    local cx = (m.gameLeft + m.gameRight) / 2
                                    local cy = (m.gameBottom + m.gameTop) / 2
                                    local factor = UIParent:GetEffectiveScale() / frame:GetEffectiveScale()
                                    local offsetX = cx - (UIParent:GetWidth() / 2)
                                    local offsetY = cy - (UIParent:GetHeight() / 2)
                                    frame:SetPoint("CENTER", UIParent, "CENTER", offsetX * factor, offsetY * factor)
                                end
                            end
                            DoCenter()
                            C_Timer.After(0, DoCenter)
                        end
                    end
                end
            end)
        end
        if UpdateUIPanelPositions then
            hooksecurefunc("UpdateUIPanelPositions", function()
                UpdateUIPanelOffsets()
            end)
        end
    end

    -- Keep bags on regular monitor unless user explicitly dragged them to workspace
    local isArrangingBags = false
    function HUD:LayoutBags()
        if HasCustomBagAddon() or isArrangingBags or InCombatLockdown() or not Offhand.db or not Offhand.db.enabled then return end
        isArrangingBags = true

        local m = Offhand.Viewport and Offhand.Viewport:GetMetrics()
        if not m then
            isArrangingBags = false
            return
        end

        local isPortraitDeck = Offhand.db.primaryPosition ~= "LEFT"
        local deckMinX = isPortraitDeck and 12 or (m.gameRight + 12)
        local deckMaxX = isPortraitDeck and (m.deckWidth - 12) or (m.screenWidth - 12)
        local deckMinY = 12
        local screenHeight = m.screenHeight or (UIParent.GetHeight and UIParent:GetHeight()) or 1080
        local deckMaxY = math.max(deckMinY, screenHeight - 30)

        -- Determine if bags are stationed on the workspace
        local bpPos = Offhand.db.savedWorkspacePositions and (
            Offhand.db.savedWorkspacePositions["ContainerFrame1"] or 
            Offhand.db.savedWorkspacePositions["ContainerFrameCombinedBags"]
        )
        local bagsOnWorkspace = false
        if bpPos and bpPos.x and bpPos.y then
            bagsOnWorkspace = true
        else
            for i = 1, (NUM_CONTAINER_FRAMES or 13) do
                local f = _G["ContainerFrame" .. i]
                local fname = f and f:GetName()
                if fname and Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions[fname] then
                    bagsOnWorkspace = true
                    bpPos = Offhand.db.savedWorkspacePositions[fname]
                    break
                end
            end
        end

        local bagSpacing = 4
        local defaultBagWidth = 192
        local defaultBagHeight = 250

        if bagsOnWorkspace and bpPos then
            -- Layout on workspace: dock unpositioned bags relative to the backpack on the workspace
            local expandRight = (bpPos.x + (defaultBagWidth + bagSpacing) * 3 <= deckMaxX)
            local currentY = bpPos.y
            local rowBagCount = 0

            for i = 1, (NUM_CONTAINER_FRAMES or 13) do
                local frame = _G["ContainerFrame" .. i]
                if frame and frame:IsShown() then
                    local name = frame:GetName()
                    local pos = Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions[name]
                    if pos and pos.x and pos.y then
                        if Offhand.Canvas and Offhand.Canvas.RestoreWorkspacePosition then
                            Offhand.Canvas.RestoreWorkspacePosition(frame)
                        end
                        if frame.SetAlpha then frame:SetAlpha(1) end
                    else
                        local w = frame:GetWidth() or defaultBagWidth
                        local h = frame:GetHeight() or defaultBagHeight
                        local targetX, targetY

                        if expandRight then
                            targetX = bpPos.x + (w + bagSpacing) * (rowBagCount + 1)
                            targetY = currentY
                            if targetX + w > deckMaxX then
                                currentY = math.min(deckMaxY - h, currentY + h + bagSpacing)
                                rowBagCount = 0
                                targetX = bpPos.x + (w + bagSpacing) * (rowBagCount + 1)
                                targetY = currentY
                            end
                        else
                            targetX = bpPos.x - (w + bagSpacing) * (rowBagCount + 1)
                            targetY = currentY
                            if targetX < deckMinX then
                                currentY = math.min(deckMaxY - h, currentY + h + bagSpacing)
                                rowBagCount = 0
                                targetX = bpPos.x - (w + bagSpacing) * (rowBagCount + 1)
                                targetY = currentY
                            end
                        end

                        targetX = math.max(deckMinX, math.min(targetX, deckMaxX - w))
                        targetY = math.max(deckMinY, math.min(targetY, deckMaxY - h))

                        local name = frame:GetName()
                        if name and not string.match(name, "^ContainerFrame") then
                            frame:SetUserPlaced(true)
                        end
                        frame:ClearAllPoints()
                        local factor = UIParent:GetEffectiveScale() / frame:GetEffectiveScale()
                        frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", targetX * factor, targetY * factor)
                        if frame.SetAlpha then frame:SetAlpha(1) end
                        rowBagCount = rowBagCount + 1
                    end
                end
            end
        else
            -- Standard game view bag layout (bottom right of gaming screen)
            local right = m.gameRight - 16
            local bottom = m.gameBottom + 32
            local bagIndex = 0

            for i = 1, (NUM_CONTAINER_FRAMES or 13) do
                local frame = _G["ContainerFrame" .. i]
                if frame and frame:IsShown() then
                    local name = frame:GetName()
                    local pos = Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions[name]
                    if not pos then
                        frame:SetUserPlaced(false)
                        frame:ClearAllPoints()
                        local w = frame:GetWidth() or defaultBagWidth
                        local factor = UIParent:GetEffectiveScale() / frame:GetEffectiveScale()
                        local x = (right - (w + bagSpacing) * bagIndex) * factor
                        local y = bottom * factor
                        frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMLEFT", x, y)
                        if frame.SetAlpha then frame:SetAlpha(1) end
                        bagIndex = bagIndex + 1
                    end
                end
            end
        end

        if ContainerFrameCombinedBags and ContainerFrameCombinedBags:IsShown() then
            local pos = Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions["ContainerFrameCombinedBags"]
            if not pos then
                local right = m.gameRight - 16
                local bottom = m.gameBottom + 32
                ContainerFrameCombinedBags:SetUserPlaced(false)
                ContainerFrameCombinedBags:ClearAllPoints()
                local factor = UIParent:GetEffectiveScale() / ContainerFrameCombinedBags:GetEffectiveScale()
                ContainerFrameCombinedBags:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMLEFT", right * factor, bottom * factor)
                if ContainerFrameCombinedBags.SetAlpha then ContainerFrameCombinedBags:SetAlpha(1) end
            end
        end

        isArrangingBags = false
    end

    -- Override UpdateContainerFrameAnchors to completely eliminate Blizzard's anchor family connection crashes
    if _G.UpdateContainerFrameAnchors and not self.anchorsHooked then
        self.anchorsHooked = true
        local origUpdateContainerFrameAnchors = _G.UpdateContainerFrameAnchors
        _G.UpdateContainerFrameAnchors = function(...)
            if HasCustomBagAddon() or not Offhand.db or not Offhand.db.enabled then
                return origUpdateContainerFrameAnchors(...)
            end
            HUD:LayoutBags()
        end
    end

    -- Pre-hook bag OnShow to suppress flicker by setting alpha 0 before positioning
    for i = 1, (NUM_CONTAINER_FRAMES or 13) do
        local frame = _G["ContainerFrame" .. i]
        if frame and not hooks[frame] then
            hooks[frame] = true
            frame:HookScript("OnShow", function(self)
                if HasCustomBagAddon() then return end
                local name = self:GetName()
                local pos = Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions[name]
                if not pos then
                    if self.SetAlpha then self:SetAlpha(0) end
                end
                HUD:LayoutBags()
                if C_Timer and C_Timer.After then
                    C_Timer.After(0, function()
                        if not HasCustomBagAddon() then
                            HUD:LayoutBags()
                        end
                    end)
                end
            end)
        end
    end
    if ContainerFrameCombinedBags and not hooks[ContainerFrameCombinedBags] then
        hooks[ContainerFrameCombinedBags] = true
        ContainerFrameCombinedBags:HookScript("OnShow", function(self)
            if HasCustomBagAddon() then return end
            local pos = Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions["ContainerFrameCombinedBags"]
            if not pos then
                if self.SetAlpha then self:SetAlpha(0) end
            end
            HUD:LayoutBags()
            if C_Timer and C_Timer.After then
                C_Timer.After(0, function()
                    if not HasCustomBagAddon() then
                        HUD:LayoutBags()
                    end
                end)
            end
        end)
    end

    if not self.bagHooksInstalled then
        self.bagHooksInstalled = true
        local function TriggerBagLayout()
            if HasCustomBagAddon() then return end
            HUD:LayoutBags()
            if C_Timer and C_Timer.After then
                C_Timer.After(0, function()
                    if not HasCustomBagAddon() then
                        HUD:LayoutBags()
                    end
                end)
            end
        end
        if ContainerFrame_GenerateFrame then
            hooksecurefunc("ContainerFrame_GenerateFrame", TriggerBagLayout)
        end
        if ToggleBag then
            hooksecurefunc("ToggleBag", TriggerBagLayout)
        end
        if ToggleAllBags then
            hooksecurefunc("ToggleAllBags", TriggerBagLayout)
        end
        if OpenAllBags then
            hooksecurefunc("OpenAllBags", TriggerBagLayout)
        end
        if OpenBag then
            hooksecurefunc("OpenBag", TriggerBagLayout)
        end
        if CloseBag then
            hooksecurefunc("CloseBag", TriggerBagLayout)
        end
        if CloseAllBags then
            hooksecurefunc("CloseAllBags", TriggerBagLayout)
        end
    end
    for i = 1, 4 do
        local frame = _G["StaticPopup" .. i]
        if frame and not hooks[frame] then
            hooks[frame] = true
            local index = i
            frame:HookScript("OnShow", function(self)
                if InCombatLockdown() or not Offhand.db.enabled or not Offhand.db.seamRedirect then return end
                local m = Offhand.Viewport:GetMetrics()
                Prepare(self, m)
                Anchor(self, "CENTER", m, 0, (index - 1) * 120)
            end)
        end
    end
end

function HUD:GatherLostFrames()
    if InCombatLockdown() or not Offhand.db or not Offhand.db.enabled then
        Offhand:Print("Cannot gather frames while in combat or disabled.")
        return
    end
    local m = Offhand.Viewport:GetMetrics()
    if not m or not m.isSpanned then return end
    
    local parentScale = UIParent:GetEffectiveScale() or 1
    local isPortraitDeck = Offhand.db.primaryPosition ~= "LEFT"
    local gameLeftThreshold = isPortraitDeck and (m.deckWidth - 20) or 0
    local gameRightThreshold = isPortraitDeck and m.screenWidth or m.gameRight
    local cx = (m.gameLeft + m.gameRight) / 2
    local cy = (m.gameBottom + m.gameTop) / 2
    local count = 0

    for _, child in ipairs({UIParent:GetChildren()}) do
        if type(child) == "table" and child ~= WorldFrame and child ~= Offhand.canvas then
            pcall(function()
                if child.IsForbidden and child:IsForbidden() then return end
                -- Do NOT check IsProtected or IsShown here; this is an aggressive manual sweep.
                local fScale = (child.GetEffectiveScale and child:GetEffectiveScale()) or parentScale
                if fScale <= 0 then fScale = parentScale end
                local scaleFactor = fScale / parentScale
                local top = (child.GetTop and child:GetTop() or 0) * scaleFactor
                local left = (child.GetLeft and child:GetLeft() or 0) * scaleFactor
                local onGameSide = isPortraitDeck and (left >= gameLeftThreshold) or (left < gameRightThreshold)
                if onGameSide and top > (m.gameTop + 2) then
                    if child.GetPoint and child.ClearAllPoints and child.SetPoint then
                        child:ClearAllPoints()
                        local invFactor = parentScale / fScale
                        local offsetX = cx - (UIParent:GetWidth() / 2)
                        local offsetY = cy - (UIParent:GetHeight() / 2)
                        -- Stagger offsets slightly so they don't perfectly stack
                        offsetX = offsetX + (math.random(-50, 50))
                        offsetY = offsetY + (math.random(-50, 50))
                        child:SetPoint("CENTER", UIParent, "CENTER", offsetX * invFactor, offsetY * invFactor)
                        count = count + 1
                    end
                end
            end)
        end
    end
    Offhand:Print("Gathered " .. count .. " lost frames from the void. Please /reload after positioning them to clear any taint.")
end

function Offhand:InitializeSeamRedirect()
    HUD:HookFrames()
end
function Offhand:UpdateSeamRedirect()
    HUD:HookFrames()
    HUD:AlignHUDFrames()
end





