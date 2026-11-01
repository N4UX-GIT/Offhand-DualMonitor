-- Mainhand transient frames, secure bounds, group loot, and temporary overlays.
local _, Offhand = ...
local Transient = {}
Offhand.HUDTransientFrames = Transient

function Transient.Install(HUD, services)
    local Points = assert(services.Points, "Missing transient HUD anchor writer")
    local Anchor = assert(services.Anchor, "Missing transient HUD anchor placement")
    local Prepare = assert(services.Prepare, "Missing transient HUD frame preparation")
    local UsesForeverEditMode = Offhand.HUDCompatibility.UsesForeverEditMode
    local Policy = Offhand.HUDTransientPolicy
    local mainhandTransientFrames = Policy.GetSpecs()
    local ResolveMainhandTransient = Policy.Resolve
    local CanPositionMainhandTransient = Policy.CanPosition
    local NormalizeMainhandTransientScale = Policy.NormalizeScale

    -- Blizzard owns the visibility and interaction lifecycle of these transient
    -- frames, but their stock anchors are relative to the complete spanned
    -- UIParent. Keep only their presentation anchor relative to Mainhand. In
    -- particular, do not register them as workspace panels, remember visibility,
    -- or add Escape-key protection.
    local transientHooks = {}
    local specialPopupPoints = setmetatable({}, { __mode = "k" })
    local specialPopupHooks = {}
    local specialPopupNames = Policy.GetRetailSpecialPopupNames()

    local function SamePopupPoint(a, b)
        return a and b and a[1] == b[1] and a[2] == b[2] and a[3] == b[3]
            and math.abs((a[4] or 0) - (b[4] or 0)) < 0.001
            and math.abs((a[5] or 0) - (b[5] or 0)) < 0.001
    end

    function HUD:PositionPremadeGroupDialogs(m, preparing)
        if not Offhand.isRetail or (InCombatLockdown and InCombatLockdown()) then return end
        m = m or (Offhand.Viewport and Offhand.Viewport:GetMetrics())
        local active = Offhand.db and Offhand.db.enabled and Offhand.db.seamRedirect
            and m and m.isSpanned
        local needed = {}
        local known = {}
        for _, name in ipairs(specialPopupNames) do
            if _G[name] then known[_G[name]] = true end
        end
        -- Native collapse removes hidden dialogs from its list without
        -- necessarily rebuilding the remaining anchor chain. A visible dialog
        -- can still depend on a hidden root; keep that root in place until the
        -- visible chain ends. Never change native visibility to maintain it.
        for _, name in ipairs(specialPopupNames) do
            local frame = _G[name]
            if CanPositionMainhandTransient(frame) and (frame == preparing or (frame.IsShown and frame:IsShown())) then
                for _ = 1, #specialPopupNames do
                    if not CanPositionMainhandTransient(frame) or needed[frame] then break end
                    needed[frame] = true
                    if not frame.GetNumPoints or not frame.GetPoint or frame:GetNumPoints() ~= 1 then break end
                    local _, relative = frame:GetPoint(1)
                    if not known[relative] then break end
                    frame = relative
                end
            end
        end
        for _, name in ipairs(specialPopupNames) do
            local frame = _G[name]
            if CanPositionMainhandTransient(frame) and frame.GetNumPoints and frame.GetPoint then
                local state = specialPopupPoints[frame]
                local current = frame:GetNumPoints() == 1 and { frame:GetPoint(1) } or nil
                local owned = state and SamePopupPoint(current, state.applied)
                if not active or not needed[frame] then
                    if owned then Points(frame, state.original) end
                    specialPopupPoints[frame] = nil
                else
                    local original = owned and state.original or current
                    -- Keep Blizzard's dialog-to-dialog stack graph intact. Only
                    -- its top root is relative to the full-screen parent.
                    if original and original[2] == UIParent
                        and original[1] == "TOP" and original[3] == "TOP"
                        and frame.GetEffectiveScale then
                        local scale = frame:GetEffectiveScale()
                        local parentScale = UIParent:GetEffectiveScale()
                        if scale and scale > 0 and parentScale and parentScale > 0 then
                            local factor = parentScale / scale
                            local desired = { "TOP", UIParent, "BOTTOMLEFT",
                                (m.gameLeft + m.gameRight) / 2 * factor + (original[4] or 0),
                                m.gameTop * factor + (original[5] or 0) }
                            specialPopupPoints[frame] = { original = original, applied = desired }
                            Points(frame, desired)
                        end
                    else
                        specialPopupPoints[frame] = nil
                    end
                end
            end
        end
    end

    local function HookPremadeGroupPlacement()
        if not Offhand.isRetail or not hooksecurefunc then return end
        for _, name in ipairs({ "StaticPopup_SetUpPosition", "StaticPopupSpecial_Show", "StaticPopupSpecial_Hide", "StaticPopup_Hide" }) do
            if type(_G[name]) == "function" and not specialPopupHooks[name] then
                specialPopupHooks[name] = true
                hooksecurefunc(name, function(dialog)
                    -- SetUpPosition runs before Show; include that pending root.
                    HUD:PositionPremadeGroupDialogs(nil, name == "StaticPopup_SetUpPosition" and dialog or nil)
                end)
            end
        end
    end

    local notificationSpecs = Policy.GetRetailNotificationSpecs()
    local notificationState = setmetatable({}, { __mode = "k" })
    local notificationHooks = setmetatable({}, { __mode = "k" })
    local notificationCombatPending = setmetatable({}, { __mode = "k" })
    local notificationCaptureFrame
    local captureRootNames = { "ChallengeModeCompleteBanner", "EventToastManagerFrame",
        "EventToastManagerSideDisplay", "BossBanner", "AlertFrame", "ScenarioObjectiveTracker" }
    local function CaptureFrameName(frame)
        if not frame then return "nil" end
        if frame.IsForbidden and frame:IsForbidden() then return "forbidden" end
        if frame == UIParent then return "UIParent" end
        return (frame.GetName and frame:GetName()) or "unnamed"
    end
    local function DescribeCapturedFrame(frame)
        if not frame then return "absent" end
        if frame.IsForbidden and frame:IsForbidden() then return "forbidden" end
        local shown = frame.IsShown and frame:IsShown()
        local detail = (shown and "shown" or "hidden") .. ",parent="
            .. CaptureFrameName(frame.GetParent and frame:GetParent())
            .. ",protected=" .. tostring(frame.IsProtected and frame:IsProtected() or false)
            .. ",managed=" .. tostring(frame.isManagedFrame == true)
            .. ",user=" .. tostring(frame.IsUserPlaced and frame:IsUserPlaced() or false)
        if shown and frame.GetEffectiveAlpha then
            detail = detail .. string.format(",alpha=%.2f", frame:GetEffectiveAlpha())
        end
        if frame.GetNumPoints and frame.GetPoint then
            local count = frame:GetNumPoints()
            detail = detail .. ",points=" .. tostring(count)
            for i = 1, math.min(count, 2) do
                local point, relative, relativePoint, x, y = frame:GetPoint(i)
                detail = detail .. string.format(",p%d=%s/%s/%s/%.1f/%.1f", i,
                    tostring(point), CaptureFrameName(relative), tostring(relativePoint), x or 0, y or 0)
            end
        end
        if shown and frame.GetLeft and frame.GetBottom and frame.GetWidth
            and frame.GetHeight and frame.GetEffectiveScale then
            local left, bottom = frame:GetLeft(), frame:GetBottom()
            if left and bottom then
                local factor = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
                detail = detail .. string.format(",uiRect=%.0f/%.0f/%.0f/%.0f",
                    left * factor, bottom * factor, frame:GetWidth() * factor, frame:GetHeight() * factor)
            end
        end
        return detail
    end

    function HUD:RecordNotificationCapture(phase)
        local capture = self.notificationCapture
        if not capture or not capture.active then return end
        local function Add(name, detail)
            if capture.last[name] == detail then return end
            capture.last[name] = detail
            if #capture.lines >= 64 then table.remove(capture.lines, 1); capture.trimmed = capture.trimmed + 1 end
            capture.lines[#capture.lines + 1] = string.format("+%.2fs %s %s=%s",
                (GetTime and GetTime() or 0) - capture.started, phase, name, detail)
        end
        if InCombatLockdown and InCombatLockdown() then Add("capture", "deferred:combat"); return end
        for _, name in ipairs(captureRootNames) do
            local ok, detail = pcall(DescribeCapturedFrame, _G[name])
            Add(name, ok and detail or "unavailable")
        end
        -- This native pooled toast can disappear before the tester opens /fstack.
        -- Read its structure only; never record titles, party members or chat.
        local ok, detail = pcall(function()
            local manager = _G.EventToastManagerFrame
            if not manager then return "absent" end
            if manager.IsForbidden and manager:IsForbidden() then return "forbidden" end
            local toast = manager.currentDisplayingToast
            if not toast then return "absent" end
            if toast.IsForbidden and toast:IsForbidden() then return "forbidden" end
            return DescribeCapturedFrame(toast) .. ",displayType="
                .. tostring(toast.toastInfo and toast.toastInfo.displayType or "unknown")
        end)
        Add("active-event-toast", ok and detail or "unavailable")
        ok, detail = pcall(function()
            local banner = _G.TopBannerMgr and _G.TopBannerMgr.currentBanner
            local frame = banner and banner.frame
            if not frame then return "absent" end
            return "name=" .. CaptureFrameName(frame) .. "," .. DescribeCapturedFrame(frame)
        end)
        Add("active-top-banner", ok and detail or "unavailable")
    end

    function HUD:StopNotificationCapture()
        local capture = self.notificationCapture
        if not capture then return end
        capture.active = false
        if notificationCaptureFrame and notificationCaptureFrame.UnregisterAllEvents then
            notificationCaptureFrame:UnregisterAllEvents()
        end
    end

    function HUD:ArmNotificationCapture()
        if not Offhand.isRetail or (InCombatLockdown and InCombatLockdown())
            or not CreateFrame or not C_Timer or not C_Timer.After then return false end
        self:StopNotificationCapture()
        local capture = { active = true, last = {}, lines = {}, trimmed = 0,
            started = GetTime and GetTime() or 0 }
        self.notificationCapture = capture
        if not notificationCaptureFrame then notificationCaptureFrame = CreateFrame("Frame") end
        notificationCaptureFrame:SetScript("OnEvent", function(_, event)
            if HUD.notificationCapture ~= capture or not capture.active then return end
            HUD:RecordNotificationCapture(event)
            if capture.queued then return end
            capture.queued = true
            for _, delay in ipairs({0, 0.15, 0.6, 1.5, 4}) do
                C_Timer.After(delay, function()
                    if HUD.notificationCapture ~= capture or not capture.active then return end
                    HUD:RecordNotificationCapture(event .. ":settled")
                    if delay == 4 then capture.queued = false end
                end)
            end
        end)
        for _, event in ipairs({ "DISPLAY_EVENT_TOASTS", "CHALLENGE_MODE_COMPLETED",
            "CHALLENGE_MODE_COMPLETED_REWARDS", "SCENARIO_COMPLETED" }) do
            pcall(notificationCaptureFrame.RegisterEvent, notificationCaptureFrame, event)
        end
        C_Timer.After(3600, function()
            if HUD.notificationCapture == capture then HUD:StopNotificationCapture() end
        end)
        self:RecordNotificationCapture("armed")
        return true
    end

    function HUD:GetNotificationCaptureReports()
        local capture = self.notificationCapture
        if not capture then return nil end
        local reports = { string.format("%s,records=%d,trimmed=%d,rect-units=UIParent",
            capture.active and "armed" or "stopped", #capture.lines, capture.trimmed) }
        for _, line in ipairs(capture.lines) do reports[#reports + 1] = line end
        return reports
    end
    local function CaptureNotificationPoints(frame)
        if not frame.GetNumPoints or not frame.GetPoint then return nil end
        local count = frame:GetNumPoints()
        if count < 1 or count > 2 then return nil end
        local points = {}
        for i = 1, count do points[i] = { frame:GetPoint(i) } end
        return points
    end
    local function SameNotificationPoints(a, b)
        if not a or not b or #a ~= #b then return false end
        for i = 1, #a do if not SamePopupPoint(a[i], b[i]) then return false end end
        return true
    end
    local function TranslateNotificationPoints(points, frame, m)
        local scale, parentScale = frame:GetEffectiveScale(), UIParent:GetEffectiveScale()
        if not scale or scale <= 0 or not parentScale or parentScale <= 0 then return nil end
        local factor, result = parentScale / scale, {}
        for _, point in ipairs(points) do
            local relativePoint = point[3] or point[1]
            if point[2] ~= UIParent or type(relativePoint) ~= "string" then return nil end
            local x = relativePoint:find("LEFT") and m.gameLeft
                or relativePoint:find("RIGHT") and m.gameRight or (m.gameLeft + m.gameRight) / 2
            local y = relativePoint:find("TOP") and m.gameTop
                or relativePoint:find("BOTTOM") and m.gameBottom or (m.gameBottom + m.gameTop) / 2
            result[#result + 1] = { point[1], UIParent, "BOTTOMLEFT",
                x * factor + (point[4] or 0), y * factor + (point[5] or 0) }
        end
        return result
    end

    function HUD:PositionRetailNotifications(m, nativeRefresh)
        if not Offhand.isRetail then return end
        if InCombatLockdown and InCombatLockdown() then
            -- Retain the request, never native geometry, across combat. Do not
            -- adopt an expired toast or an external placement when replaying it.
            if nativeRefresh and not notificationCombatPending[nativeRefresh] and Offhand.RunOrQueueCombat then
                notificationCombatPending[nativeRefresh] = true
                Offhand:RunOrQueueCombat(function()
                    notificationCombatPending[nativeRefresh] = nil
                    if InCombatLockdown and InCombatLockdown() then return end
                    for _, spec in ipairs(notificationSpecs) do
                        if _G[spec.name] == nativeRefresh and spec.nativeOffsets
                            and CanPositionMainhandTransient(nativeRefresh)
                            and nativeRefresh.IsShown and nativeRefresh:IsShown() then
                            local current = CaptureNotificationPoints(nativeRefresh)
                            local point = current and #current == 1 and current[1]
                            if point and (SamePopupPoint(point,
                                { spec.point, UIParent, spec.relativePoint, spec.x, spec.y })
                                or SamePopupPoint(point, { "TOP", UIParent, "TOP", 0, 0 })) then
                                HUD:PositionRetailNotifications(nil, nativeRefresh)
                            end
                        end
                    end
                end)
            end
            return
        end
        m = m or (Offhand.Viewport and Offhand.Viewport:GetMetrics())
        local active = Offhand.db and Offhand.db.enabled and Offhand.db.seamRedirect and m and m.isSpanned
        for _, spec in ipairs(notificationSpecs) do
            local frame = _G[spec.name]
            if CanPositionMainhandTransient(frame) and frame.GetEffectiveScale then
                local current = CaptureNotificationPoints(frame)
                local state = notificationState[frame]
                local owned = state and SameNotificationPoints(current, state.applied)
                if not active or not (frame == nativeRefresh or (frame.IsShown and frame:IsShown())) then
                    if owned then Points(frame, unpack(state.original)) end
                    notificationState[frame] = nil
                elseif (frame.GetParent and frame:GetParent() ~= UIParent)
                    or (frame.IsUserPlaced and frame:IsUserPlaced()) or frame.isManagedFrame then
                    notificationState[frame] = nil
                else
                    local original = owned and state.original or current
                    local stock = original and #original == 1 and SamePopupPoint(original[1],
                        { spec.point, UIParent, spec.relativePoint, spec.x, spec.y })
                    -- Native toast setup may supply two anchors and texture-kit
                    -- offsets. Trust that completed transaction only; a later
                    -- external/custom placement must cause periodic recovery to yield.
                    if owned or stock or (spec.nativeOffsets and frame == nativeRefresh) then
                        local desired = original and TranslateNotificationPoints(original, frame, m)
                        if desired then
                            notificationState[frame] = { original = original, applied = desired }
                            Points(frame, unpack(desired))
                        end
                    else
                        notificationState[frame] = nil
                    end
                end
            end
        end
    end

    function HUD:HookRetailNotifications()
        if not Offhand.isRetail or not hooksecurefunc then return end
        for _, spec in ipairs(notificationSpecs) do
            local frame = _G[spec.name]
            if CanPositionMainhandTransient(frame) then
                local installed = notificationHooks[frame] or {}
                notificationHooks[frame] = installed
                for _, method in ipairs({ spec.method, spec.finalMethod }) do
                    if type(frame[method]) == "function" and not installed[method] then
                        installed[method] = true
                        hooksecurefunc(frame, method, function()
                            local capturing = HUD.notificationCapture and HUD.notificationCapture.active
                            if capturing then HUD:RecordNotificationCapture("native:" .. spec.name .. ":" .. method) end
                            local refresh = spec.nativeOffsets and frame or nil
                            if method == spec.finalMethod and frame.IsShown and not frame:IsShown() then refresh = nil end
                            HUD:PositionRetailNotifications(nil, refresh)
                            if capturing then HUD:RecordNotificationCapture("placed:" .. spec.name) end
                        end)
                    end
                end
            end
        end
    end
    local secureTransientOwned = setmetatable({}, { __mode = "k" })
    local secureTransientPoints = setmetatable({}, { __mode = "k" })
    local secureTransientPositioner
    local groupLootPreloadAttempted = false
    local petBattlePreloadAttempted = false
    local petBattleConflict
    local groupLootRowsOwned = setmetatable({}, { __mode = "k" })
    local groupLootRowMover = {
        active = false,
        hooked = false,
        container = nil,
        physicalX = nil,
        physicalY = nil,
        rowsMoved = 0,
        conflict = nil,
    }
    local groupLootMoverFrame
    local groupLootMoverRequested = false
    local groupLootMoverDragging = false

    -- Keep /offhand diag focused on the current group-loot QA surface without
    -- reading protected frame geometry in combat. These flags describe only the
    -- addon-owned secure setup; the tester's screenshot confirms final placement.
    function HUD:GetGroupLootDiagnostics()
        local container = _G.GroupLootContainer
        local triggerCount = 0
        for index = 1, 4 do
            if _G["GroupLootFrame" .. index] then triggerCount = triggerCount + 1 end
        end
        return {
            loaded = container ~= nil,
            preloadAttempted = groupLootPreloadAttempted,
            anchorPrepared = container and secureTransientOwned[container] == true or false,
            rowMoverPrepared = groupLootRowMover.hooked,
            rowMoverActive = groupLootRowMover.active,
            rowsMoved = groupLootRowMover.rowsMoved or 0,
            conflict = groupLootRowMover.conflict,
            customPosition = Offhand.db and type(Offhand.db.groupLootPosition) == "table"
                and tonumber(Offhand.db.groupLootPosition.x) ~= nil
                and tonumber(Offhand.db.groupLootPosition.y) ~= nil or false,
            moverShown = groupLootMoverFrame and groupLootMoverFrame.IsShown
                and groupLootMoverFrame:IsShown() or false,
            moverDragging = groupLootMoverDragging,
            stackDirection = Offhand.db and Offhand.db.groupLootStackDirection == "DOWN"
                and "DOWN" or "UP",
            triggerCount = triggerCount,
            inCombat = InCombatLockdown and InCombatLockdown() or false,
        }
    end

    function HUD:GetPetBattleDiagnostics()
        local frame = _G.PetBattleFrame
        return {
            loaded = frame ~= nil,
            preloadAttempted = petBattlePreloadAttempted,
            boundsPrepared = frame and secureTransientOwned[frame] == true or false,
            conflict = petBattleConflict,
            inCombat = InCombatLockdown and InCombatLockdown() or false,
        }
    end

    local function PreloadGroupLootForSecurePositioning()
        if groupLootPreloadAttempted or _G.GroupLootContainer or InCombatLockdown()
            or not Offhand.db or not Offhand.db.enabled then return end
        local metrics = Offhand.Viewport and Offhand.Viewport.GetMetrics
            and Offhand.Viewport:GetMetrics() or nil
        if not metrics or not metrics.isSpanned then return end
        local load = C_AddOns and C_AddOns.LoadAddOn or _G.LoadAddOn
        if type(load) ~= "function" then return end
        groupLootPreloadAttempted = true
        -- Load Blizzard's own LoD module while the player is safe so both the
        -- container fallback anchor and the native roll-update hook exist before
        -- the first in-combat roll of the session.
        pcall(load, "Blizzard_GroupLoot")
    end

    local function PreloadPetBattleForSecurePositioning()
        if petBattlePreloadAttempted or _G.PetBattleFrame or InCombatLockdown()
            or not Offhand.db or not Offhand.db.enabled or not Offhand.db.seamRedirect then return end
        local metrics = Offhand.Viewport and Offhand.Viewport.GetMetrics
            and Offhand.Viewport:GetMetrics() or nil
        if not metrics or not metrics.isSpanned then return end
        local load = C_AddOns and C_AddOns.LoadAddOn or _G.LoadAddOn
        if type(load) ~= "function" then return end
        petBattlePreloadAttempted = true
        -- Wild pet battles enter combat lockdown. Load Blizzard's LoD module and
        -- establish its root bounds beforehand so no protected anchor write is
        -- needed when the battle starts.
        pcall(load, "Blizzard_PetBattleUI")
    end

    local function EnsureSecureTransientPositioner()
        if secureTransientPositioner then return secureTransientPositioner end
        if not CreateFrame or not UIParent or InCombatLockdown() then return nil end
        local ok, positioner = pcall(CreateFrame, "Frame", nil, UIParent, "SecureHandlerBaseTemplate")
        if not ok or not positioner or not positioner.SetFrameRef
            or not positioner.SetAttribute or not positioner.Execute then return nil end
        secureTransientPositioner = positioner
        return positioner
    end

    -- Forever initially anchors the Escape menu to the full spanned UIParent, whose
    -- center can be the upper-left corner of Mainhand in a mixed-height topology.
    -- Correct it from an external secure post-hook during the same ToggleGameMenu
    -- call, before the next rendered frame. Do not replace Blizzard's function or
    -- attach scripts to the menu itself.
    local function PositionForeverGameMenu()
        if not UsesForeverEditMode() or InCombatLockdown()
            or not Offhand.db or not Offhand.db.enabled or not Offhand.db.seamRedirect then return false end
        local frame = _G.GameMenuFrame
        local m = Offhand.Viewport and Offhand.Viewport.GetMetrics
            and Offhand.Viewport:GetMetrics() or nil
        if not frame or not m or not m.isSpanned or not frame.ClearAllPoints
            or not frame.SetPoint or (frame.IsForbidden and frame:IsForbidden()) then return false end
        if frame.IsProtected then
            local ok, protected = pcall(frame.IsProtected, frame)
            if not ok or protected then return false end
        end
        local factor = UIParent:GetEffectiveScale() / frame:GetEffectiveScale()
        local cx = (m.gameLeft + m.gameRight) / 2
        local cy = (m.gameBottom + m.gameTop) / 2
        local ok = pcall(function()
            frame:ClearAllPoints()
            frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx * factor, cy * factor)
        end)
        return ok
    end

    local function CaptureSecurePoints(frame)
        local points = {}
        for index = 1, frame:GetNumPoints() do points[index] = { frame:GetPoint(index) } end
        return points
    end

    local function SameSecurePoints(frame, points)
        if not points or frame:GetNumPoints() ~= #points then return false end
        for index, point in ipairs(points) do
            if not SamePopupPoint({ frame:GetPoint(index) }, point) then return false end
        end
        return true
    end

    local function RecordSecurePoints(frame, original)
        local state = secureTransientPoints[frame]
        secureTransientPoints[frame] = {
            original = state and state.original or original,
            applied = CaptureSecurePoints(frame),
        }
        secureTransientOwned[frame] = true
    end

    local function IsStockSecureTransientAnchor(frame, spec)
        local state = secureTransientPoints[frame]
        local userPlaced = frame.IsUserPlaced and frame:IsUserPlaced()
        if state and not userPlaced and SameSecurePoints(frame, state.applied) then return true end
        if state then
            secureTransientOwned[frame] = nil
            -- Only the recorded native placement or the reviewed stock point
            -- may reset an adopted frame. A later mover owns every other change.
            if not SameSecurePoints(frame, state.original) then
                local point = frame:GetNumPoints() == 1 and { frame:GetPoint(1) }
                local stock = { spec.stockPoint, UIParent, spec.stockRelativePoint, spec.stockX, spec.stockY }
                local nativeReset = SamePopupPoint(point, stock)
                if spec.groupLootRows then
                    -- Blizzard's managed container also resets to the bottom
                    -- edge before the alert layout adds its reserved offset.
                    nativeReset = nativeReset or SamePopupPoint(point,
                        { spec.stockPoint, UIParent, spec.stockRelativePoint, spec.stockX, 0 })
                end
                if not nativeReset then
                    return false
                end
            end
        end
        if frame.IsUserPlaced and frame:IsUserPlaced() then return false end
        if not frame.GetNumPoints or not frame.GetPoint then return false end
        local numPoints = frame:GetNumPoints()
        -- GroupLootContainer is declared hidden without an XML anchor. Its first
        -- BottomManagedFrameContainer anchor is created only when a roll shows it,
        -- which can happen after combat begins. Preloading is useful only if that
        -- pristine zero-point state is eligible for the secure setup.
        if numPoints == 0 then return spec.allowUnanchored == true end
        if numPoints ~= 1 then return false end
        local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
        if relativeTo ~= nil and relativeTo ~= UIParent then return false end
        -- GroupLootContainer's stock vertical offset varies between client builds.
        -- A single UIParent-relative, non-user-placed anchor is still native stock;
        -- addon/user placements relative to another frame remain untouched.
        if spec.allowAnyUIParentAnchor then return true end
        local tolerance = 0.5
        return point == spec.stockPoint
            and (relativePoint or point) == spec.stockRelativePoint
            and math.abs((tonumber(x) or 0) - spec.stockX) <= tolerance
            and math.abs((tonumber(y) or 0) - spec.stockY) <= tolerance
    end

    local function SecureScreenPoint(frame, point, x, y, relativePoint)
        if InCombatLockdown() then return false end
        local positioner = EnsureSecureTransientPositioner()
        if not positioner then return false end
        local ok = pcall(function()
            positioner:SetFrameRef("offhandTransient", frame)
            positioner:SetAttribute("offhandPoint", point)
            positioner:SetAttribute("offhandRelativePoint", relativePoint or "BOTTOMLEFT")
            positioner:SetAttribute("offhandX", x)
            positioner:SetAttribute("offhandY", y)
            positioner:SetAttribute("offhandBounds", false)
            positioner:Execute([[
                local frame = self:GetFrameRef("offhandTransient")
                if frame then
                    frame:ClearAllPoints()
                    frame:SetPoint(
                        self:GetAttribute("offhandPoint"),
                        self:GetParent(), self:GetAttribute("offhandRelativePoint"),
                        self:GetAttribute("offhandX"), self:GetAttribute("offhandY"))
                end
            ]])
        end)
        return ok
    end

    local overridePoints = setmetatable({}, { __mode = "k" })
    local overrideCombatPending = false
    function HUD:PositionRetailOverrideBar(m)
        if not Offhand.isRetail then return end
        local frame = _G.OverrideActionBar
        if not frame then self.retailOverrideStatus = "absent"; return end
        if InCombatLockdown() then
            self.retailOverrideStatus = "deferred:combat"
            if not overrideCombatPending and Offhand.RunOrQueueCombat then
                overrideCombatPending = true
                Offhand:RunOrQueueCombat(function()
                    overrideCombatPending = false
                    HUD:PositionRetailOverrideBar()
                end)
            end
            return
        end
        if (frame.IsForbidden and frame:IsForbidden()) or not frame.GetNumPoints
            or not frame.GetPoint or not frame.GetEffectiveScale then
            self.retailOverrideStatus = "unavailable"; return
        end
        if not frame.GetParent or frame:GetParent() ~= UIParent then
            overridePoints[frame] = nil
            self.retailOverrideStatus = "yield:parent"; return
        end
        local state = overridePoints[frame]
        local current = frame:GetNumPoints() == 1 and { frame:GetPoint(1) } or nil
        local owned = state and SamePopupPoint(current, state.applied)
        m = m or (Offhand.Viewport and Offhand.Viewport:GetMetrics())
        local compatibility = Offhand.HUDCompatibility
        local external = compatibility.HasCustomActionBarAddon and compatibility.HasCustomActionBarAddon()
        local controller = compatibility.UsesControllerInterface and compatibility.UsesControllerInterface()
        local active = Offhand.db and Offhand.db.enabled and Offhand.db.seamRedirect
            and m and m.isSpanned and not external and not controller
        if not active then
            if owned then
                if not SecureScreenPoint(frame, state.original[1], state.original[4] or 0,
                    state.original[5] or 0, state.original[3]) then
                    self.retailOverrideStatus = "restore-pending"; return
                end
            end
            overridePoints[frame] = nil
            self.retailOverrideStatus = external and "yield:external-actionbars"
                or controller and "yield:controller" or owned and "restored" or "inactive"
            return
        end
        if not owned then
            overridePoints[frame] = nil
            -- Adopt only the reviewed stock XML root. Never rewrite user or
            -- replacement-addon placement, Edit Mode systems or native children.
            if (frame.IsUserPlaced and frame:IsUserPlaced()) or frame.isManagedFrame
                or not SamePopupPoint(current, { "BOTTOM", UIParent, "BOTTOM", 0, 0 }) then
                self.retailOverrideStatus = "yield:custom-anchor"; return
            end
            state = { original = current }
        end
        local scale, parentScale = frame:GetEffectiveScale(), UIParent:GetEffectiveScale()
        if not scale or scale <= 0 or not parentScale or parentScale <= 0 then return end
        local factor = parentScale / scale
        -- Native skin/art/width and slide animations remain untouched.
        local desired = { "BOTTOM", UIParent, "BOTTOMLEFT",
            (m.gameLeft + m.gameRight) / 2 * factor, m.gameBottom * factor }
        if not SamePopupPoint(current, desired) then
            if not SecureScreenPoint(frame, desired[1], desired[4], desired[5]) then
                self.retailOverrideStatus = "placement-pending"; return
            end
        end
        state.applied = desired
        overridePoints[frame] = state
        self.retailOverrideStatus = "mainhand"
    end

    local function PointMatches(point, relativeTo, relativePoint, x, y,
            expectedPoint, expectedRelativePoint, expectedX, expectedY)
        local tolerance = 0.5
        return point == expectedPoint
            and (relativeTo == nil or relativeTo == UIParent)
            and (relativePoint or point) == expectedRelativePoint
            and math.abs((tonumber(x) or 0) - expectedX) <= tolerance
            and math.abs((tonumber(y) or 0) - expectedY) <= tolerance
    end

    local function IsNativePetBattleBounds(frame, metrics, mainhandOnly)
        if frame.IsUserPlaced and frame:IsUserPlaced() then return false end
        if not frame.GetNumPoints or not frame.GetPoint or frame:GetNumPoints() ~= 2 then return false end

        local factor = UIParent:GetEffectiveScale() / frame:GetEffectiveScale()
        local expected = {
            stockTopLeft = { "TOPLEFT", "TOPLEFT", 0, 0 },
            stockBottomRight = { "BOTTOMRIGHT", "BOTTOMRIGHT", 0, 0 },
            mainBottomLeft = {
                "BOTTOMLEFT", "BOTTOMLEFT", metrics.gameLeft * factor, metrics.gameBottom * factor,
            },
            mainTopRight = {
                "TOPRIGHT", "BOTTOMLEFT", metrics.gameRight * factor, metrics.gameTop * factor,
            },
        }
        local matches = {}
        for index = 1, 2 do
            local point, relativeTo, relativePoint, x, y = frame:GetPoint(index)
            for key, value in pairs(expected) do
                if PointMatches(point, relativeTo, relativePoint, x, y,
                        value[1], value[2], value[3], value[4]) then
                    matches[key] = true
                end
            end
        end
        return (not mainhandOnly and matches.stockTopLeft and matches.stockBottomRight)
            or (matches.mainBottomLeft and matches.mainTopRight)
    end

    local function SecureScreenBounds(frame, metrics)
        if InCombatLockdown() then return false end
        local positioner = EnsureSecureTransientPositioner()
        if not positioner then return false end
        local factor = UIParent:GetEffectiveScale() / frame:GetEffectiveScale()
        local ok = pcall(function()
            positioner:SetFrameRef("offhandTransient", frame)
            positioner:SetAttribute("offhandLeft", metrics.gameLeft * factor)
            positioner:SetAttribute("offhandBottom", metrics.gameBottom * factor)
            positioner:SetAttribute("offhandRight", metrics.gameRight * factor)
            positioner:SetAttribute("offhandTop", metrics.gameTop * factor)
            positioner:SetAttribute("offhandBounds", true)
            positioner:Execute([[
                local frame = self:GetFrameRef("offhandTransient")
                if frame then
                    frame:ClearAllPoints()
                    frame:SetPoint("BOTTOMLEFT", self:GetParent(), "BOTTOMLEFT",
                        self:GetAttribute("offhandLeft"), self:GetAttribute("offhandBottom"))
                    frame:SetPoint("TOPRIGHT", self:GetParent(), "BOTTOMLEFT",
                        self:GetAttribute("offhandRight"), self:GetAttribute("offhandTop"))
                end
            ]])
        end)
        return ok
    end

    local function ReleasePetBattleBounds()
        local frame = _G.PetBattleFrame
        local state = frame and secureTransientPoints[frame]
        if not state then return end
        if frame.IsForbidden and frame:IsForbidden() then
            secureTransientPoints[frame], secureTransientOwned[frame] = nil, nil
            petBattleConflict = nil
            return
        end
        if not (frame.IsUserPlaced and frame:IsUserPlaced())
            and SameSecurePoints(frame, state.applied)
            and not SameSecurePoints(frame, state.original) then
            local positioner = EnsureSecureTransientPositioner()
            if not positioner then return end
            local ok = pcall(function()
                positioner:SetFrameRef("offhandRestore", frame)
                positioner:SetAttribute("offhandRestoreCount", #state.original)
                for index, point in ipairs(state.original) do
                    positioner:SetFrameRef("offhandRestoreRelative" .. index, point[2] or UIParent)
                    positioner:SetAttribute("offhandRestorePoint" .. index, point[1])
                    positioner:SetAttribute("offhandRestoreRelativePoint" .. index, point[3] or point[1])
                    positioner:SetAttribute("offhandRestoreX" .. index, point[4] or 0)
                    positioner:SetAttribute("offhandRestoreY" .. index, point[5] or 0)
                end
                positioner:Execute([[
                    local frame = self:GetFrameRef("offhandRestore")
                    frame:ClearAllPoints()
                    for index = 1, self:GetAttribute("offhandRestoreCount") do
                        frame:SetPoint(self:GetAttribute("offhandRestorePoint" .. index),
                            self:GetFrameRef("offhandRestoreRelative" .. index),
                            self:GetAttribute("offhandRestoreRelativePoint" .. index),
                            self:GetAttribute("offhandRestoreX" .. index),
                            self:GetAttribute("offhandRestoreY" .. index))
                    end
                ]])
            end)
            if not ok then return end
        end
        secureTransientPoints[frame], secureTransientOwned[frame] = nil, nil
        petBattleConflict = nil
    end

    local function IsRetailChatSettlementActive(frame)
        return Offhand.Canvas and Offhand.Canvas.IsRetailEditModeChatSettlementActive
            and Offhand.Canvas:IsRetailEditModeChatSettlementActive(frame) or false
    end

    -- Blizzard deliberately owns GroupLootContainer through its alert-layout
    -- system. Moving that managed container is only a fallback: combat and other
    -- alert updates can place it back at the full-canvas center. The roll rows are
    -- ordinary, non-protected frames, however, and Blizzard already rebuilds their
    -- anchors in GroupLootContainer_Update. Follow Blizzard's native update first,
    -- then preserve its ordering and spacing while
    -- anchoring the visible rows directly inside Mainhand. A container relocation
    -- can no longer carry those rows back to the monitor seam.
    local function IsNativeGroupLootRowAnchor(row, container)
        if not row.GetNumPoints or not row.GetPoint then return false end
        local numPoints = row:GetNumPoints()
        if numPoints == 0 then return true end
        if numPoints ~= 1 then return false end
        local _, relativeTo = row:GetPoint(1)
        if relativeTo == container then return true end
        -- UIParent is accepted only after Offhand has adopted this row. A fresh
        -- UIParent-relative point may belong to another mover and must be preserved.
        return relativeTo == UIParent and groupLootRowsOwned[row] == true
    end

    local function GetSavedGroupLootCenter(metrics)
        local position = Offhand.db and Offhand.db.groupLootPosition
        local xRatio = type(position) == "table" and tonumber(position.x) or nil
        local yRatio = type(position) == "table" and tonumber(position.y) or nil
        if not xRatio or not yRatio or xRatio < 0 or xRatio > 1 or yRatio < 0 or yRatio > 1 then
            return nil, nil
        end
        return metrics.gameLeft + (metrics.gameRight - metrics.gameLeft) * xRatio,
            metrics.gameBottom + (metrics.gameTop - metrics.gameBottom) * yRatio
    end

    local function GetDefaultGroupLootCenter(metrics, container)
        local row = container and container.rollFrames and container.rollFrames[1]
        local rowScale = row and row.GetEffectiveScale and row:GetEffectiveScale() or 1
        local parentScale = UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
        local factor = parentScale / math.max(tonumber(rowScale) or 1, 0.0001)
        local reservedSize = tonumber(container and container.reservedSize) or 100
        return (metrics.gameLeft + metrics.gameRight) / 2,
            metrics.gameBottom + 190 * metrics.hudScale + (reservedSize * 0.5 / factor)
    end

    local function GetGroupLootCenter(metrics, container)
        local x, y = GetSavedGroupLootCenter(metrics)
        if x and y then return x, y, true end
        x, y = GetDefaultGroupLootCenter(metrics, container)
        return x, y, false
    end

    local function GetGroupLootStackDirection()
        return Offhand.db and Offhand.db.groupLootStackDirection == "DOWN"
            and "DOWN" or "UP"
    end

    local function PositionGroupLootRows(container)
        if not groupLootRowMover.active or container ~= groupLootRowMover.container
            or not Offhand.db or not Offhand.db.enabled or not Offhand.db.seamRedirect then return false end
        local metrics = Offhand.Viewport and Offhand.Viewport.GetMetrics
            and Offhand.Viewport:GetMetrics() or nil
        if not metrics or not metrics.isSpanned then return false end

        local rows = container and container.rollFrames
        if type(rows) ~= "table" then return false end
        local maxIndex = tonumber(container.maxIndex) or 0
        local reservedSize = tonumber(container.reservedSize) or 100
        local centerX, centerY = GetGroupLootCenter(metrics, container)
        local stackStep = GetGroupLootStackDirection() == "DOWN" and -reservedSize or reservedSize

        -- Validate the complete native set before moving anything. This makes an
        -- addon-owned mover (a row relative to its own anchor) an explicit conflict
        -- instead of creating a last-writer contest.
        for index = 1, maxIndex do
            local row = rows[index]
            if row then
                if (row.IsForbidden and row:IsForbidden())
                    or (row.IsProtected and row:IsProtected())
                    or not IsNativeGroupLootRowAnchor(row, container) then
                    local name = row.GetName and row:GetName() or tostring(index)
                    groupLootRowMover.active = false
                    groupLootRowMover.conflict = "custom-or-protected-row:" .. tostring(name)
                    return false
                end
            end
        end

        local moved = 0
        for index = 1, maxIndex do
            local row = rows[index]
            if row and row.ClearAllPoints and row.SetPoint then
                local rowScale = row.GetEffectiveScale and row:GetEffectiveScale() or 1
                local parentScale = UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
                local factor = parentScale / math.max(tonumber(rowScale) or 1, 0.0001)
                row:ClearAllPoints()
                row:SetPoint("CENTER", UIParent, "BOTTOMLEFT",
                    centerX * factor,
                    centerY * factor + stackStep * (index - 1))
                groupLootRowsOwned[row] = true
                moved = moved + 1
            end
        end
        groupLootRowMover.rowsMoved = moved
        groupLootRowMover.conflict = nil
        return true
    end

    local function ConfigureGroupLootRowMover(container, physicalX, physicalY)
        if InCombatLockdown() or not container then return false end
        groupLootRowMover.container = container
        groupLootRowMover.physicalX = physicalX
        groupLootRowMover.physicalY = physicalY
        groupLootRowMover.active = true
        groupLootRowMover.conflict = nil

        if not groupLootRowMover.hooked and type(_G.GroupLootContainer_Update) == "function"
            and type(hooksecurefunc) == "function" then
            hooksecurefunc("GroupLootContainer_Update", function(updatedContainer)
                PositionGroupLootRows(updatedContainer or _G.GroupLootContainer)
            end)
            groupLootRowMover.hooked = true
        end
        PositionGroupLootRows(container)
        return groupLootRowMover.hooked
    end

    local function PositionGroupLootMoverFrame(metrics)
        -- Layout, scale and native-alert refreshes may run repeatedly while the
        -- mouse is held. Re-anchoring here would fight StartMoving and make the
        -- preview jump back to its last saved point until mouse release.
        if not groupLootMoverFrame or groupLootMoverDragging then return false end
        metrics = metrics or (Offhand.Viewport and Offhand.Viewport.GetMetrics
            and Offhand.Viewport:GetMetrics() or nil)
        if not metrics or not metrics.isSpanned then return false end
        local x, y = GetGroupLootCenter(metrics, groupLootRowMover.container or _G.GroupLootContainer)
        groupLootMoverFrame:ClearAllPoints()
        groupLootMoverFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
        return true
    end

    local function SaveGroupLootMoverPosition(frame)
        local metrics = Offhand.Viewport and Offhand.Viewport.GetMetrics
            and Offhand.Viewport:GetMetrics() or nil
        if not metrics or not metrics.isSpanned or not frame.GetCenter then return false end
        local centerX, centerY = frame:GetCenter()
        if not centerX or not centerY then return false end

        local halfWidth = ((frame.GetWidth and frame:GetWidth()) or 277) * 0.5
        local halfHeight = ((frame.GetHeight and frame:GetHeight()) or 67) * 0.5
        centerX = math.max(metrics.gameLeft + halfWidth,
            math.min(metrics.gameRight - halfWidth, centerX))
        centerY = math.max(metrics.gameBottom + halfHeight,
            math.min(metrics.gameTop - halfHeight, centerY))

        local width = math.max(metrics.gameRight - metrics.gameLeft, 1)
        local height = math.max(metrics.gameTop - metrics.gameBottom, 1)
        Offhand.db.groupLootPosition = {
            x = math.max(0, math.min(1, (centerX - metrics.gameLeft) / width)),
            y = math.max(0, math.min(1, (centerY - metrics.gameBottom) / height)),
        }
        PositionGroupLootMoverFrame(metrics)
        HUD:PositionMainhandTransientFrames(metrics)
        return true
    end

    local function EnsureGroupLootMoverFrame()
        if groupLootMoverFrame then return groupLootMoverFrame end
        if not CreateFrame or not UIParent or InCombatLockdown() then return nil end
        local template = not Offhand.isLegacyWrath and "BackdropTemplate" or nil
        groupLootMoverFrame = CreateFrame("Frame", "OffhandGroupLootMover", UIParent, template)
        groupLootMoverFrame:SetSize(277, 67)
        groupLootMoverFrame:SetFrameStrata("DIALOG")
        if groupLootMoverFrame.SetFrameLevel then groupLootMoverFrame:SetFrameLevel(900) end
        groupLootMoverFrame:SetMovable(true)
        groupLootMoverFrame:EnableMouse(true)
        groupLootMoverFrame:RegisterForDrag("LeftButton")
        if groupLootMoverFrame.SetBackdrop then
            groupLootMoverFrame:SetBackdrop({
                bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true, tileSize = 16, edgeSize = 12,
                insets = { left = 3, right = 3, top = 3, bottom = 3 },
            })
            groupLootMoverFrame:SetBackdropColor(0.05, 0.05, 0.05, 0.92)
            groupLootMoverFrame:SetBackdropBorderColor(1, 0.82, 0, 1)
        end

        local title = groupLootMoverFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("CENTER", groupLootMoverFrame, "CENTER", 0, 8)
        title:SetText((Offhand.L and Offhand.L["GROUP_LOOT_MOVER_TITLE"]) or "Group Loot Rolls")
        local instruction = groupLootMoverFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        instruction:SetPoint("TOP", title, "BOTTOM", 0, -3)
        instruction:SetText((Offhand.L and Offhand.L["GROUP_LOOT_MOVER_DRAG"]) or "Drag to move")

        groupLootMoverFrame:SetScript("OnDragStart", function(self)
            if InCombatLockdown() or not groupLootMoverRequested then return end
            groupLootMoverDragging = true
            self:StartMoving()
        end)
        groupLootMoverFrame:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            groupLootMoverDragging = false
            if InCombatLockdown() then return end
            SaveGroupLootMoverPosition(self)
        end)
        if groupLootMoverFrame.RegisterEvent then
            groupLootMoverFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
            groupLootMoverFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
            groupLootMoverFrame:SetScript("OnEvent", function(self, event)
                if event == "PLAYER_REGEN_DISABLED" then
                    if groupLootMoverDragging then self:StopMovingOrSizing() end
                    groupLootMoverDragging = false
                    self:Hide()
                elseif groupLootMoverRequested then
                    PositionGroupLootMoverFrame()
                    self:Show()
                end
            end)
        end
        groupLootMoverFrame:Hide()
        return groupLootMoverFrame
    end

    function HUD:SetGroupLootMoverShown(shown)
        shown = shown == true
        if shown and InCombatLockdown() then return false, "combat" end
        if shown then
            PreloadGroupLootForSecurePositioning()
            self:PositionMainhandTransientFrames()
            if groupLootRowMover.conflict then return false, "conflict" end
            if not groupLootRowMover.hooked or not groupLootRowMover.active then
                return false, "unavailable"
            end
            local metrics = Offhand.Viewport and Offhand.Viewport.GetMetrics
                and Offhand.Viewport:GetMetrics() or nil
            if not metrics or not metrics.isSpanned then return false, "span" end
            local mover = EnsureGroupLootMoverFrame()
            if not mover then return false, "unavailable" end
            groupLootMoverRequested = true
            PositionGroupLootMoverFrame(metrics)
            mover:Show()
            return true, "shown"
        end
        groupLootMoverRequested = false
        if groupLootMoverFrame then
            if groupLootMoverDragging then groupLootMoverFrame:StopMovingOrSizing() end
            groupLootMoverDragging = false
            groupLootMoverFrame:Hide()
        end
        return true, "hidden"
    end

    function HUD:ToggleGroupLootMover()
        return self:SetGroupLootMoverShown(not groupLootMoverRequested)
    end

    function HUD:ResetGroupLootPosition()
        if not Offhand.db or InCombatLockdown() then return false end
        Offhand.db.groupLootPosition = {}
        local metrics = Offhand.Viewport and Offhand.Viewport.GetMetrics
            and Offhand.Viewport:GetMetrics() or nil
        if metrics and metrics.isSpanned then
            PositionGroupLootMoverFrame(metrics)
            self:PositionMainhandTransientFrames(metrics)
        end
        return true
    end

    function HUD:SetGroupLootStackDirection(direction)
        if not Offhand.db then return false end
        Offhand.db.groupLootStackDirection = direction == "DOWN" and "DOWN" or "UP"
        if groupLootRowMover.active and groupLootRowMover.container then
            PositionGroupLootRows(groupLootRowMover.container)
        end
        return true
    end

    local function PositionSecureMainhandTransient(frame, spec, m)
        if spec.petBattleBounds then
            local state = secureTransientPoints[frame]
            local owned = state and not (frame.IsUserPlaced and frame:IsUserPlaced())
                and SameSecurePoints(frame, state.applied)
            if not owned and not IsNativePetBattleBounds(frame, m) then
                secureTransientOwned[frame] = nil
                petBattleConflict = "custom-anchor"
                return false
            end
            local original = CaptureSecurePoints(frame)
            -- Keep the two-point rectangle stable on the maintenance ticker.
            -- Clearing a size-derived root needlessly invalidates all children.
            if IsNativePetBattleBounds(frame, m, true) then
                RecordSecurePoints(frame, original)
                petBattleConflict = nil
                return true
            end
            if SecureScreenBounds(frame, m) then
                RecordSecurePoints(frame, original)
                petBattleConflict = nil
                return true
            end
            return false
        end
        if not IsStockSecureTransientAnchor(frame, spec) then
            if spec.groupLootRows then
                groupLootRowMover.active = false
                groupLootRowMover.conflict = "custom-anchor"
            end
            return false
        end
        local original = CaptureSecurePoints(frame)
        local px = spec.point:find("LEFT") and m.gameLeft or spec.point:find("RIGHT") and m.gameRight
            or (m.gameLeft + m.gameRight) / 2
        local py = spec.point:find("TOP") and m.gameTop or spec.point:find("BOTTOM") and m.gameBottom
            or (m.gameBottom + m.gameTop) / 2
        local physicalX = px + (spec.x or 0) * m.hudScale
        local physicalY = py + (spec.y or 0) * m.hudScale
        local factor = UIParent:GetEffectiveScale() / frame:GetEffectiveScale()
        local x = physicalX * factor
        local y = physicalY * factor
        if spec.groupLootRows then
            ConfigureGroupLootRowMover(frame, physicalX, physicalY)
            if groupLootMoverRequested then PositionGroupLootMoverFrame(m) end
        end
        if SecureScreenPoint(frame, spec.point, x, y) then
            RecordSecurePoints(frame, original)
            return true
        end
        return false
    end

    local function PositionTimerTracker(frame, m)
        local parent = frame.GetParent and frame:GetParent()
        if parent and parent ~= UIParent then
            -- Commentator mode reparents TimerTracker to WorldFrame. Restore native
            -- fill behavior if Offhand previously bounded it, then yield ownership.
            if frame._OffhandMainhandTimerTracker and frame.SetAllPoints then
                frame:ClearAllPoints()
                frame:SetAllPoints(parent)
                frame._OffhandMainhandTimerTracker = nil
            end
            return
        end

        local factor = UIParent:GetEffectiveScale() / frame:GetEffectiveScale()
        Points(frame,
            {"BOTTOMLEFT", UIParent, "BOTTOMLEFT", m.gameLeft * factor, m.gameBottom * factor},
            {"TOPRIGHT", UIParent, "BOTTOMLEFT", m.gameRight * factor, m.gameTop * factor})
        frame._OffhandMainhandTimerTracker = true

        -- The final "Go" texture is explicitly anchored to UIParent in Blizzard's
        -- XML instead of TimerTracker. Reattach only that presentation texture;
        -- its glow remains natively anchored to the texture.
        if type(frame.timerList) == "table" then
            for _, timer in pairs(frame.timerList) do
                local goTexture = timer and timer.GoTexture
                if goTexture and goTexture.ClearAllPoints and goTexture.SetPoint then
                    goTexture:ClearAllPoints()
                    goTexture:SetPoint("CENTER", frame, "CENTER", 0, 0)
                end
            end
        end
    end

    function HUD:PositionMainhandTransientFrames(m)
        self:PositionRetailOverrideBar(m)
        self:PositionPremadeGroupDialogs(m)
        self:PositionRetailNotifications(m)
        if InCombatLockdown() then
            if not self.mainhandTransientCombatPending and Offhand.RunOrQueueCombat then
                self.mainhandTransientCombatPending = true
                Offhand:RunOrQueueCombat(function()
                    HUD.mainhandTransientCombatPending = false
                    HUD:PositionMainhandTransientFrames()
                end)
            end
            return
        end
        m = m or Offhand.Viewport:GetMetrics()
        if not Offhand.db or not Offhand.db.enabled or not Offhand.db.seamRedirect
            or not m or not m.isSpanned then
            ReleasePetBattleBounds()
            return
        end

        for _, spec in ipairs(mainhandTransientFrames) do
            local frame = ResolveMainhandTransient(spec)
            if not spec.specialPopup
                and not (Offhand.isRetail and (spec.retailSpecialPopup or spec.retailNotification))
                and CanPositionMainhandTransient(frame, spec) then
                pcall(function()
                    if spec.secure then
                        PositionSecureMainhandTransient(frame, spec, m)
                    else
                        Prepare(frame, m)
                        if spec.normalizeScale then NormalizeMainhandTransientScale(frame) end
                        if spec.bounds then
                            PositionTimerTracker(frame, m)
                        else
                            Anchor(frame, spec.point, m, spec.x, spec.y, true)
                        end
                    end
                end)
            end
        end

        -- Static popups are pooled and Blizzard may restore their stock CENTER
        -- point after OnShow. Reapplying the same desired point is a no-op, while a
        -- later native reset is repaired on the next layout/ticker pass.
        for i = 1, Offhand.isRetail and 0 or 4 do
            local frame = _G["StaticPopup" .. i]
            if CanPositionMainhandTransient(frame) then
                pcall(function()
                    Prepare(frame, m)
                    NormalizeMainhandTransientScale(frame)
                    Anchor(frame, "CENTER", m, 0, (i - 1) * 120, true)
                end)
            end
        end
    end

    function HUD:HookMainhandTransientFrames()
        HookPremadeGroupPlacement()
        self:HookRetailNotifications()
        PreloadGroupLootForSecurePositioning()
        PreloadPetBattleForSecurePositioning()
        -- Housing controls and the full-screen House Editor are load-on-demand.
        -- Install the hook as soon as Blizzard creates either module so an already
        -- shown child (notably HouseEditorFrame.ModeBar) is positioned before the
        -- periodic recovery pass. ModeBar does not receive its own OnShow when its
        -- hidden top-level parent becomes visible, so waiting for that script alone
        -- leaves it centered on the complete spanned UIParent.
        if not self.mainhandTransientLoader and CreateFrame then
            local loader = CreateFrame("Frame")
            if loader and loader.RegisterEvent and loader.SetScript then
                self.mainhandTransientLoader = loader
                loader:RegisterEvent("ADDON_LOADED")
                if Offhand.isRetail then
                    for _, event in ipairs({ "UPDATE_OVERRIDE_ACTIONBAR", "UPDATE_VEHICLE_ACTIONBAR",
                        "UNIT_ENTERED_VEHICLE", "UNIT_EXITED_VEHICLE" }) do loader:RegisterEvent(event) end
                end
                loader:SetScript("OnEvent", function(_, event, addonName)
                    if (event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE")
                        and addonName ~= "player" then return end
                    if event == "ADDON_LOADED" and addonName ~= "Blizzard_HousingControls"
                        and addonName ~= "Blizzard_HouseEditor"
                        and addonName ~= "Blizzard_UIWidgets"
                        and addonName ~= "Blizzard_PVPMatch"
                        and addonName ~= "Blizzard_GroupLoot"
                        and addonName ~= "Blizzard_LootUI"
                        and addonName ~= "Blizzard_CombatText"
                        and addonName ~= "Blizzard_PetBattleUI"
                        and addonName ~= "Blizzard_GroupFinder"
                        and addonName ~= "Blizzard_StaticPopup"
                        and addonName ~= "Blizzard_OverrideActionBar"
                        and addonName ~= "Blizzard_ChallengesUI"
                        and addonName ~= "Blizzard_StaticPopup_Game" then return end
                    HUD:HookMainhandTransientFrames()
                    HUD:PositionMainhandTransientFrames()
                    if C_Timer and C_Timer.After then
                        C_Timer.After(0, function()
                            HUD:HookMainhandTransientFrames()
                            HUD:PositionMainhandTransientFrames()
                        end)
                    end
                end)
            end
        end

        for _, spec in ipairs(mainhandTransientFrames) do
            local frame = ResolveMainhandTransient(spec)
            -- Do not attach addon scripts to secret-sensitive widget/score trees.
            -- Their stock anchors are adopted before combat and repaired by the
            -- existing layout/ticker pass after combat.
            if not spec.secure and not spec.specialPopup
                and not (Offhand.isRetail and (spec.retailSpecialPopup or spec.retailNotification))
                and CanPositionMainhandTransient(frame, spec)
                and not transientHooks[frame] and frame.HookScript then
                transientHooks[frame] = true
                frame:HookScript("OnShow", function()
                    HUD:PositionMainhandTransientFrames()
                    if C_Timer and C_Timer.After then
                        for _, delay in ipairs({0, 0.05, 0.2}) do
                            C_Timer.After(delay, function() HUD:PositionMainhandTransientFrames() end)
                        end
                    end
                end)
                if spec.hookEvent then
                    frame:HookScript("OnEvent", function()
                        HUD:PositionMainhandTransientFrames()
                        if C_Timer and C_Timer.After then
                            C_Timer.After(0, function() HUD:PositionMainhandTransientFrames() end)
                        end
                    end)
                end
            end
        end
    end

    return {
        PositionForeverGameMenu = PositionForeverGameMenu,
        IsRetailChatSettlementActive = IsRetailChatSettlementActive,
    }
end

