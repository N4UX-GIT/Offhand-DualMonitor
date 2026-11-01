-- Panel placement measurement and Social/Communities anchor ownership.
local _, Offhand = ...
local Placement = {}
Offhand.CanvasPanelPlacement = Placement

function Placement.InstallSingleScreen(Canvas, services)
    local IsForeverProfessionsPanel = services.IsForeverProfessionsPanel
    local IsForeverEditModeFrame = services.IsForeverEditModeFrame
    local IsUnsafeForPanelMutation = services.IsUnsafeForPanelMutation
    -- A missing saved display leaves no workspace rectangle. Close only panels
    -- that were visible on that workspace so they do not get clamped into a pile
    -- on Mainhand. Their saved geometry and open-state snapshot are intentionally
    -- retained; reconnecting and reloading restores them. Panels opened manually
    -- after recovery remain usable with Blizzard's native single-screen anchors.
    local function IsSingleScreenRecovery(metrics)
        if Offhand.Viewport and Offhand.Viewport.IsSingleScreenRecovery then
            return Offhand.Viewport:IsSingleScreenRecovery(metrics)
        end
        return metrics and not metrics.isSpanned
            and metrics.topologyStatus == "MISMATCH" or false
    end

    function Canvas:PrepareSingleScreenRecovery(metrics)
        if not IsSingleScreenRecovery(metrics) or not Offhand.db
            or not Offhand.db.savedWorkspacePositions then return end
        for name in pairs(Offhand.db.savedWorkspacePositions) do
            if not tostring(name):match("^ChatFrame%d+$")
                and not IsForeverEditModeFrame(_G[name], name)
                and not IsForeverProfessionsPanel(_G[name], name) then
                local frame = _G[name]
                if frame and frame.IsShown and frame:IsShown() and frame.Hide then
                    pcall(frame.Hide, frame)
                end
            end
        end
    end

    function Canvas:PlaceForSingleScreenRecovery(frame, metrics)
        if not frame or not Offhand.db or not Offhand.db.savedWorkspacePositions then return false end
        metrics = metrics or (Offhand.Viewport and Offhand.Viewport.GetMetrics and Offhand.Viewport:GetMetrics())
        if not IsSingleScreenRecovery(metrics) then return false end
        local name = frame.GetName and frame:GetName()
        if not name or not Offhand.db.savedWorkspacePositions[name]
            or IsForeverEditModeFrame(frame, name) or IsUnsafeForPanelMutation(frame, name) then return false end

        -- Blizzard Edit Mode's Modern fallback already places chat correctly and
        -- may also restore its preferred size. Do not override it with panel logic.
        if tostring(name):match("^ChatFrame%d+$") then return false end

        if frame.SetClampedToScreen then pcall(frame.SetClampedToScreen, frame, true) end
        if frame.ClearAllPoints and frame.SetPoint then
            pcall(function()
                frame:ClearAllPoints()
                if name == "CharacterFrame" then
                    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 24, -80)
                elseif name == "ContainerFrameCombinedBags" or tostring(name):match("^ContainerFrame%d+$")
                    or tostring(name):match("Baganator") or tostring(name):match("Baginator")
                    or tostring(name):match("Bagnon") or tostring(name):match("BetterBags") then
                    frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -32, 140)
                else
                    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
                end
            end)
        end
        return true
    end
end

function Placement.InstallMainhand(Canvas, services)
    local ShouldYieldFrameToClassicUIForever = services.ShouldYieldFrameToClassicUIForever
    local ShouldYieldWorldMapToMoveAny = services.ShouldYieldWorldMapToMoveAny
    local IsForeverProfessionsPanel = services.IsForeverProfessionsPanel
    local IsForeverEditModeFrame = services.IsForeverEditModeFrame
    local IsWorldMapMaximized = services.IsWorldMapMaximized
    local WithWorkspace = services.WithWorkspace
    local IsForeverSocialPositionRoot = services.IsForeverSocialPositionRoot
    local IsUnsafeForPanelMutation = services.IsUnsafeForPanelMutation
    local RegisterSpecialFrame = services.RegisterSpecialFrame
    local SaveOpenWorkspacePanels = services.SaveOpenWorkspacePanels
    local SaveForeverPanelOwnership = services.SaveForeverPanelOwnership
    local IsBackpackRoot = services.IsBackpackRoot
    local ClearOtherBackpackRootState = services.ClearOtherBackpackRootState
    local IsFrameOnWorkspace = services.IsFrameOnWorkspace
    -- Blizzard UIPanels anchor against the full UIParent. In an Offhand topology
    -- that native origin may be the workspace, so an unsaved Spellbook,
    -- Professions or Collections panel can open on the wrong monitor. Mainhand
    -- placements use physical UIParent coordinates and are clamped on every
    -- restore so display changes cannot strand a panel off screen.
    function Canvas:PlacePanelOnMainhand(frame, metrics, position, preserveContained, recoveryAction)
        local nonMovableSystemPanels = services.GetNonMovablePanels()
        if not frame or (InCombatLockdown and InCombatLockdown()) or not Offhand.db
            or not Offhand.db.enabled then return false end
        local registry = Offhand.CanvasPanelRegistry
        if registry and registry.GetPositionRoot(frame) ~= frame then return false end
        if IsWorldMapMaximized(frame) then return false end
        local name = frame.GetName and frame:GetName()
        if ShouldYieldFrameToClassicUIForever(frame, name) then return false end
        if ShouldYieldWorldMapToMoveAny(name or frame) then return false end
        if recoveryAction and services.RemodalizePanel
            and not (frame.IsForbidden and frame:IsForbidden())
            and not IsForeverEditModeFrame(frame, name) then
            -- A workspace menu may have been detached from UIPanelWindows.
            -- Restore the registration we saved before testing protected-panel
            -- eligibility or the native toggle's next anchor transaction.
            services.RemodalizePanel(frame)
        end
        local recoverySafePanel = recoveryAction and name and (
            IsBackpackRoot(name) or (UIPanelWindows and UIPanelWindows[name])
                or IsForeverSocialPositionRoot(frame, name)
        )
        if not name or (nonMovableSystemPanels and nonMovableSystemPanels[name])
            or IsForeverEditModeFrame(frame, name)
            or (IsUnsafeForPanelMutation(frame, name) and not recoverySafePanel) then return false end

        metrics = metrics or (Offhand.Viewport and Offhand.Viewport.GetMetrics
            and WithWorkspace(Offhand.Viewport:GetMetrics()))
        if not metrics or not metrics.isSpanned then return false end

        local parentScale = (UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
        local frameScale = (frame.GetEffectiveScale and frame:GetEffectiveScale()) or parentScale
        if parentScale <= 0 or frameScale <= 0 then return false end
        local scaleFactor = frameScale / parentScale
        local width = ((frame.GetWidth and frame:GetWidth()) or 0) * scaleFactor
        local height = ((frame.GetHeight and frame:GetHeight()) or 0) * scaleFactor
        if width <= 0 then width = 192 * scaleFactor end
        if height <= 0 then height = 192 * scaleFactor end

        local inset = 12
        local minX = metrics.gameLeft + inset
        local maxX = math.max(minX, metrics.gameRight - width - inset)
        local minY = metrics.gameBottom + height + inset
        local maxY = math.max(minY, metrics.gameTop - inset)

        if preserveContained and not position then
            local left = frame.GetLeft and frame:GetLeft()
            local top = frame.GetTop and frame:GetTop()
            if left and top then
                left, top = left * scaleFactor, top * scaleFactor
                if left >= minX and left + width <= metrics.gameRight - inset
                    and top <= maxY and top - height >= metrics.gameBottom + inset then
                    return false
                end
            end
        end

        local targetX = position and tonumber(position.x)
        local targetY = position and tonumber(position.y)
        if not targetX then
            targetX = metrics.gameLeft + (metrics.gameRight - metrics.gameLeft - width) / 2
        end
        if not targetY then
            targetY = metrics.gameBottom + (metrics.gameTop - metrics.gameBottom + height) / 2
        end
        local clampedX = math.max(minX, math.min(targetX, maxX))
        local clampedY = math.max(minY, math.min(targetY, maxY))
        local pointFactor = parentScale / frameScale

        local ok = pcall(function()
            if frame.SetClampedToScreen then frame:SetClampedToScreen(false) end
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT",
                clampedX * pointFactor, clampedY * pointFactor)
        end)
        if ok and not IsForeverProfessionsPanel(frame, name) then RegisterSpecialFrame(name) end
        return ok
    end

    -- Recovery is an explicit out-of-combat hardware action. Unlike a generic
    -- re-anchor, it must also retire Offhand's workspace ownership or the next
    -- OnShow/restore pass will put the panel back on the secondary display.
    function Canvas:GatherSafeUIToMainhand(missingOnly)
        local playerInCombat = InCombatLockdown and InCombatLockdown() or false
        if not playerInCombat and UnitAffectingCombat then
            local ok, active = pcall(UnitAffectingCombat, "player")
            playerInCombat = ok and active == true or false
        end
        if playerInCombat then return false, "combat", 0, 0 end
        if not Offhand.db or not Offhand.db.enabled then return false, "disabled", 0, 0 end
        local metrics = Offhand.Viewport and Offhand.Viewport.GetMetrics
            and WithWorkspace(Offhand.Viewport:GetMetrics())
        if not metrics or not metrics.isSpanned then return false, "span", 0, 0 end
        Offhand.db.savedWorkspacePositions = Offhand.db.savedWorkspacePositions or {}
        Offhand.db.openWorkspacePanels = Offhand.db.openWorkspacePanels or {}
        Offhand.db.savedMainPositions = Offhand.db.savedMainPositions or {}

        local candidates = {}
        local function Add(frame)
            if frame then
                local registry = Offhand.CanvasPanelRegistry
                frame = registry and registry.GetPositionRoot and registry.GetPositionRoot(frame) or frame
                candidates[frame] = true
            end
        end
        for name in pairs(Offhand.db.savedWorkspacePositions or {}) do Add(_G[name]) end
        for name in pairs(UIPanelWindows or {}) do Add(_G[name]) end
        if UIParent.GetChildren then
            for _, child in ipairs({UIParent:GetChildren()}) do
                pcall(function()
                    if not (child.IsForbidden and child:IsForbidden())
                        and child.IsMovable and child:IsMovable() then Add(child) end
                end)
            end
        end
        if Offhand.BagPersistence and type(Offhand.BagPersistence.frames) == "table" then
            for _, frame in pairs(Offhand.BagPersistence.frames) do Add(frame) end
        end
        Add(_G.WorldMapFrame)
        Add(_G.CharacterFrame)
        Add(_G.ContainerFrameCombinedBags)
        Add(_G.ContainerFrame1)

        local moved, skipped = 0, 0
        self.lastGatherReport = {}
        for frame in pairs(candidates) do
            -- A registered Blizzard panel can become forbidden after it enters a
            -- restricted state. Never call even basic frame methods until the
            -- complete inspection is behind a guarded boundary.
            local inspected, name, shown, tracked, onWorkspace = pcall(function()
                if frame.IsForbidden and frame:IsForbidden() then return nil, false, false, false end
                local frameName = frame.GetName and frame:GetName()
                local frameShown = frame.IsShown and frame:IsShown() or false
                local frameTracked = frameName and Offhand.db.savedWorkspacePositions[frameName]
                local frameOnWorkspace = frameShown and IsFrameOnWorkspace(frame) or false
                return frameName, frameShown, frameTracked, frameOnWorkspace
            end)
            local recover = shown and (tracked or onWorkspace)
            local reopen = false
            if missingOnly and inspected and name and Offhand.Recovery then
                local state = Offhand.Recovery.Inspect(frame, metrics)
                local registry = Offhand.CanvasPanelRegistry
                reopen = state == "hidden" and tracked and Offhand.db.openWorkspacePanels[name] == true
                    and registry and registry.IsBasePersistentCandidate(name)
                    and not IsBackpackRoot(name) and UIPanelWindows and UIPanelWindows[name]
                    and type(ShowUIPanel) == "function"
                if reopen and GetUIPanel then
                    -- Opening a native slot beside another panel can reflow or
                    -- close that visible panel. Yield rather than disturb it.
                    for _, slot in ipairs({"left", "center", "right", "doublewide"}) do
                        local read, occupant = pcall(GetUIPanel, slot)
                        if not read or (occupant and occupant ~= frame) then reopen = false; break end
                    end
                end
                recover = state == "missing" or reopen
            end
            if inspected and recover and name
                and frame ~= UIParent and frame ~= WorldFrame and frame ~= Offhand.canvas
                and not IsForeverEditModeFrame(frame, name)
                and not ShouldYieldFrameToClassicUIForever(frame, name)
                and not ShouldYieldWorldMapToMoveAny(name) then
                if frame == _G.WorldMapFrame and frame.SetScale then
                    pcall(frame.SetScale, frame, 1)
                end
                local called, placed = pcall(self.PlacePanelOnMainhand,
                    self, frame, metrics, nil, false, true)
                placed = called and placed
                if placed then
                    self.lastGatherReport[#self.lastGatherReport + 1] = name .. "=moved"
                    moved = moved + 1
                    Offhand.db.savedWorkspacePositions[name] = nil
                    Offhand.db.openWorkspacePanels[name] = nil
                    if Offhand.db.baganatorWorkspacePanels then
                        Offhand.db.baganatorWorkspacePanels[name] = nil
                    end

                    if IsBackpackRoot(name) then
                        ClearOtherBackpackRootState(nil)
                        Offhand.db.nativeBackpackWorkspacePosition = nil
                        Offhand.db.nativeBackpackWorkspaceOpen = nil
                    elseif Offhand.ForeverPersistence and Offhand.ForeverPersistence.ClearPosition then
                        Offhand.ForeverPersistence:ClearPosition(name)
                    end

                    local frameScale = (frame.GetEffectiveScale and frame:GetEffectiveScale()) or 1
                    local parentScale = (UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
                    local left = frame.GetLeft and frame:GetLeft()
                    local top = frame.GetTop and frame:GetTop()
                    if left and top and parentScale > 0 then
                        local factor = frameScale / parentScale
                        Offhand.db.savedMainPositions[name] = { x = left * factor, y = top * factor }
                    end
                    if reopen and ShowUIPanel then
                        local opened = pcall(ShowUIPanel, frame)
                        if not opened or not (frame.IsShown and frame:IsShown()) then skipped = skipped + 1 end
                    end
                else
                    skipped = skipped + 1
                    local reason = "placement-unavailable"
                    pcall(function()
                        if frame.IsProtected and frame:IsProtected() and not (UIPanelWindows and UIPanelWindows[name]) then
                            reason = "protected-unregistered"
                        elseif IsWorldMapMaximized(frame) then reason = "native-maximized-map" end
                    end)
                    self.lastGatherReport[#self.lastGatherReport + 1] = name .. "=" .. reason
                end
            elseif not inspected then
                skipped = skipped + 1
                self.lastGatherReport[#self.lastGatherReport + 1] = "uninspectable=skipped"
            elseif recover then
                skipped = skipped + 1
                local reason = IsForeverEditModeFrame(frame, name) and "native-HUD-or-EditMode" or "external-or-geometry-owner"
                self.lastGatherReport[#self.lastGatherReport + 1] = tostring(name) .. "=" .. reason
            end
        end

        SaveOpenWorkspacePanels()
        if Offhand.BagPersistence and not missingOnly then
            if Offhand.BagPersistence.ForgetOpenSnapshot then
                Offhand.BagPersistence:ForgetOpenSnapshot()
            end
            if Offhand.BagPersistence.Capture then Offhand.BagPersistence:Capture() end
        end
        if moved > 0 then SaveForeverPanelOwnership() end
        return true, nil, moved, skipped
    end
end

function Placement.InstallVoid(Canvas, services)
    local IsForeverEditModeFrame = services.IsForeverEditModeFrame
    local WithWorkspace = services.WithWorkspace
    local IsUnsafeForPanelMutation = services.IsUnsafeForPanelMutation
    local nonMovableSystemPanels = services.NonMovablePanels
    -- A normal Blizzard panel can be reachable by its left edge while its close
    -- button and most of its title bar sit in the mixed-height monitor void. Keep
    -- the complete window inside whichever visible monitor currently contains the
    -- greatest portion of it. Saved user placements are restored separately and
    -- therefore always take precedence over this default-position rescue.
    function Canvas:RescuePanelFromVoid(frame, metrics)
        if not frame or (InCombatLockdown and InCombatLockdown()) or not Offhand.db
            or not Offhand.db.enabled then return false end
        local registry = Offhand.CanvasPanelRegistry
        if registry and registry.GetPositionRoot(frame) ~= frame then return false end
        local name = frame.GetName and frame:GetName()
        if not name or nonMovableSystemPanels[name] or IsForeverEditModeFrame(frame, name)
            or IsUnsafeForPanelMutation(frame, name) then return false end
        if not UIPanelWindows or not UIPanelWindows[name] then return false end
        if frame.IsShown and not frame:IsShown() then return false end

        metrics = metrics or (Offhand.Viewport and Offhand.Viewport.GetMetrics
            and WithWorkspace(Offhand.Viewport:GetMetrics()))
        if not metrics or not metrics.isSpanned or metrics.workspaceLeft == nil then return false end

        local parentScale = (UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
        local frameScale = (frame.GetEffectiveScale and frame:GetEffectiveScale()) or parentScale
        if parentScale <= 0 or frameScale <= 0 then return false end
        local scaleFactor = frameScale / parentScale
        local left = frame.GetLeft and frame:GetLeft()
        local top = frame.GetTop and frame:GetTop()
        local width = frame.GetWidth and frame:GetWidth()
        local height = frame.GetHeight and frame:GetHeight()
        if not left or not top or not width or not height or width <= 0 or height <= 0 then return false end

        left, top = left * scaleFactor, top * scaleFactor
        width, height = width * scaleFactor, height * scaleFactor
        local right, bottom = left + width, top - height
        local inset = 12
        local areas = {
            {
                left = metrics.workspaceLeft, right = metrics.workspaceRight,
                bottom = metrics.workspaceBottom, top = metrics.workspaceTop,
            },
            {
                left = metrics.gameLeft, right = metrics.gameRight,
                bottom = metrics.gameBottom, top = metrics.gameTop,
            },
        }

        local function IsContained(area)
            return left >= area.left + inset and right <= area.right - inset
                and bottom >= area.bottom + inset and top <= area.top - inset
        end
        if IsContained(areas[1]) or IsContained(areas[2]) then return false end

        local function Overlap(area)
            local overlapWidth = math.max(0, math.min(right, area.right) - math.max(left, area.left))
            local overlapHeight = math.max(0, math.min(top, area.top) - math.max(bottom, area.bottom))
            return overlapWidth * overlapHeight
        end
        local target = Overlap(areas[1]) >= Overlap(areas[2]) and areas[1] or areas[2]
        local availableWidth = math.max(0, target.right - target.left - inset * 2)
        local availableHeight = math.max(0, target.top - target.bottom - inset * 2)
        local targetLeft = width <= availableWidth
            and math.max(target.left + inset, math.min(left, target.right - width - inset))
            or target.left + inset
        local targetTop = height <= availableHeight
            and math.max(target.bottom + height + inset, math.min(top, target.top - inset))
            or target.top - inset
        local pointFactor = parentScale / frameScale
        local ok = pcall(function()
            if frame.SetClampedToScreen then frame:SetClampedToScreen(false) end
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT",
                targetLeft * pointFactor, targetTop * pointFactor)
        end)
        return ok
    end
end



function Placement.Install(Canvas, services)
    local WithWorkspace = services.WithWorkspace
    local IsForeverSocialPositionRoot = services.IsForeverSocialPositionRoot
    local IsUnsafeForPanelMutation = services.IsUnsafeForPanelMutation
    local NotePanelControllerActivity = services.NotePanelControllerActivity
    local RestoreWorkspacePosition = services.RestoreWorkspacePosition
    local IsPanelDragging = Offhand.CanvasFrameState.IsDragging
    local GetPanelPhysicalPlacement, PlacementMatchesPosition
    local socialMainhandSessionPositions = setmetatable({}, { __mode = "k" })
    local socialAnchorRepairState = setmetatable({}, { __mode = "k" })

    GetPanelPhysicalPlacement = function(frame)
        if not frame then return nil end
        local ok, placement = pcall(function()
            local metrics = Offhand.Viewport and WithWorkspace(Offhand.Viewport:GetMetrics())
            if not metrics or not metrics.isSpanned then return nil end
            local frameScale = (frame.GetEffectiveScale and frame:GetEffectiveScale()) or 1
            local parentScale = (UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
            if frameScale <= 0 or parentScale <= 0 then return nil end
            local factor = frameScale / parentScale
            local width = ((frame.GetWidth and frame:GetWidth()) or 0) * factor
            local height = ((frame.GetHeight and frame:GetHeight()) or 0) * factor
            local left = frame.GetLeft and frame:GetLeft()
            local top = frame.GetTop and frame:GetTop()
            local centerX, centerY
            if frame.GetCenter then centerX, centerY = frame:GetCenter() end
            if left then left = left * factor end
            if top then top = top * factor end
            if centerX then centerX = centerX * factor end
            if centerY then centerY = centerY * factor end
            if not centerX and left and width > 0 then centerX = left + width / 2 end
            if not centerY and top and height > 0 then centerY = top - height / 2 end
            if not left and centerX and width > 0 then left = centerX - width / 2 end
            if not top and centerY and height > 0 then top = centerY + height / 2 end
            if not centerX or not centerY then return nil end
            return {
                x = left,
                y = top,
                onWorkspace = centerX >= metrics.workspaceLeft
                    and centerX <= metrics.workspaceRight
                    and centerY >= metrics.workspaceBottom
                    and centerY <= metrics.workspaceTop,
            }
        end)
        return ok and placement or nil
    end

    PlacementMatchesPosition = function(placement, position)
        return placement and position and position.x and position.y
            and math.abs(placement.x - position.x) < 0.5
            and math.abs(placement.y - position.y) < 0.5
    end

    local function RepairShownSocialPanel(frame, suppliedName)
        if not frame or not frame.IsShown or not frame:IsShown()
            or IsPanelDragging(frame) or InCombatLockdown() or not Offhand.db or not Offhand.db.enabled then return false end
        if Offhand.CanvasPanelRegistry.GetPositionRoot(frame) ~= frame then return false end
        local name = (frame.GetName and frame:GetName()) or suppliedName
        if not name then return false end
        local positionOnlyRoot = IsForeverSocialPositionRoot(frame, name)
            or IsForeverSocialPositionRoot(frame, suppliedName)
        if not positionOnlyRoot and IsUnsafeForPanelMutation(frame, name) then return false end

        local state = socialAnchorRepairState[frame]
        if not state then
            state = {}
            socialAnchorRepairState[frame] = state
        end
        if state.repairing then return false end

        local workspacePosition = Offhand.db.savedWorkspacePositions
            and (Offhand.db.savedWorkspacePositions[name]
                or (suppliedName and Offhand.db.savedWorkspacePositions[suppliedName]))
        local mainPosition = Offhand.db.savedMainPositions
            and (Offhand.db.savedMainPositions[name]
                or (suppliedName and Offhand.db.savedMainPositions[suppliedName]))
        local placement = GetPanelPhysicalPlacement(frame)
        state.repairing = true
        if workspacePosition or mainPosition then
            local savedPosition = workspacePosition or mainPosition
            if not PlacementMatchesPosition(placement, savedPosition) then
                NotePanelControllerActivity(name, "forever-social-community", "saved-repair")
                RestoreWorkspacePosition(frame)
            end
        else
            local sessionPosition = socialMainhandSessionPositions[frame]
            if sessionPosition then
                if not PlacementMatchesPosition(placement, sessionPosition) then
                    NotePanelControllerActivity(name, "forever-social-community", "session-repair")
                    Canvas:PlacePanelOnMainhand(frame, nil,
                        sessionPosition, false, true)
                end
            elseif placement and not placement.onWorkspace and placement.x and placement.y then
                -- Capture the panel's native Mainhand anchor before another member
                -- of Blizzard's shared UIPanel stack recalculates it.
                socialMainhandSessionPositions[frame] = {
                    x = placement.x,
                    y = placement.y,
                }
            elseif placement and placement.onWorkspace then
                -- An unsaved Friends frame has no intentional Offhand ownership.
                -- Restore the last native Mainhand anchor, or center it safely when
                -- this session first discovered the frame after displacement.
                NotePanelControllerActivity(name, "forever-social-community", "mainhand-rescue")
                Canvas:PlacePanelOnMainhand(frame, nil,
                    socialMainhandSessionPositions[frame], false, true)
                local restored = GetPanelPhysicalPlacement(frame)
                if restored and not restored.onWorkspace and restored.x and restored.y then
                    socialMainhandSessionPositions[frame] = {
                        x = restored.x,
                        y = restored.y,
                    }
                end
            end
        end
        state.repairing = nil
        return true
    end

    local function HookSocialPanelAnchorResets(frame, suppliedName)
        if not frame or not hooksecurefunc then return false end
        if Offhand.CanvasPanelRegistry.GetPositionRoot(frame) ~= frame then return false end
        local state = socialAnchorRepairState[frame]
        if not state then
            state = {}
            socialAnchorRepairState[frame] = state
        end
        if state.hooked then return true end
        state.hooked = true
        hooksecurefunc(frame, "SetPoint", function()
            if state.repairing or IsPanelDragging(frame) or not Offhand.db
                or not Offhand.db.enabled or not frame.IsShown or not frame:IsShown() then return end
            state.generation = (state.generation or 0) + 1
            local generation = state.generation
            -- Root SetPoint hooks run after Blizzard's write but before the next
            -- render. Repair immediately so the native intermediate anchor is not
            -- visible, then retain one bounded next-frame pass for layout work that
            -- continues asynchronously.
            RepairShownSocialPanel(frame, suppliedName)
            local function RepairAfterNativeLayout()
                if generation ~= state.generation or state.repairing
                    or not frame.IsShown or not frame:IsShown() then return end
                RepairShownSocialPanel(frame, suppliedName)
            end
            if C_Timer and C_Timer.After then
                C_Timer.After(0, RepairAfterNativeLayout)
            else
                RepairAfterNativeLayout()
            end
        end)
        return true
    end

    function Canvas:RepairShownSocialCommunityPanels()
        if InCombatLockdown() or not Offhand.db or not Offhand.db.enabled then return end
        local repaired = setmetatable({}, { __mode = "k" })
        local names = {
            "FriendsFrame", "FriendsListFrame", "SocialFrame", "SocialUIFrame",
            "CommunitiesFrame",
        }
        for _, name in ipairs(names) do
            local frame = _G[name]
            if frame and not repaired[frame] and frame.IsShown and frame:IsShown() then
                repaired[frame] = true
                HookSocialPanelAnchorResets(frame, name)
                RepairShownSocialPanel(frame, name)
            end
        end
    end
    return GetPanelPhysicalPlacement, PlacementMatchesPosition, HookSocialPanelAnchorResets
end

