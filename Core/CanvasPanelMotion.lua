-- Guarded Canvas title motion and native panel anchor-reset observation.
local _, Offhand = ...
local Motion = {}
Offhand.CanvasPanelMotion = Motion

function Motion.InstallGenericDragging(Canvas, services)
    local ShouldYieldFrameToClassicUIForever = services.ShouldYieldFrameToClassicUIForever
    local ShouldYieldWorldMapToMoveAny = services.ShouldYieldWorldMapToMoveAny
    local IsForeverEditModeFrame = services.IsForeverEditModeFrame
    local IsForeverWorldMap = services.IsForeverWorldMap
    local SetPanelDragging = services.SetPanelDragging
    local IsUnsafeForPanelMutation = services.IsUnsafeForPanelMutation
    local IsForeverNativeContainerName = services.IsForeverNativeContainerName
    local HookCombinedBagCloseButton = services.HookCombinedBagCloseButton
    local RestoreSavedPositionAfterShow = services.RestoreSavedPositionAfterShow
    local HookContainerTitlePersistence = services.HookContainerTitlePersistence
    local HookPanelCloseButton = services.HookPanelCloseButton
    local AttachForeverWorldMapDragHandle = services.AttachForeverWorldMapDragHandle
    local HookKnownPanelAnchorResets = services.HookKnownPanelAnchorResets
    local AttachGuardedForeverPanelMotion = services.AttachGuardedForeverPanelMotion
    local OnPanelDragStop = services.OnPanelDragStop
    local function MakePanelDraggable(frame)
        if not frame then return end
        if ShouldYieldFrameToClassicUIForever(frame) then return end
        if ShouldYieldWorldMapToMoveAny(frame) then return end
        if IsForeverWorldMap(frame) then
            AttachForeverWorldMapDragHandle(frame)
            return
        end
        if frame._OffhandMovable then
            local existingHandle = frame._OffhandHandle
            if existingHandle and existingHandle._OffhandSyntheticPanelDragHandle
                and existingHandle.Show then
                existingHandle:Show()
            end
            return
        end
        local name = frame.GetName and frame:GetName()
        if IsForeverNativeContainerName(name) then return end
        if IsForeverEditModeFrame(frame, name) or IsUnsafeForPanelMutation(frame, name) then return end

        if name == "MinimapCluster" and Offhand.HasCustomMinimapAddon and Offhand.HasCustomMinimapAddon() then
            return
        end

        if name and string.match(name, "^ContainerFrame") and Offhand.HasCustomBagAddon and Offhand.HasCustomBagAddon() then
            return
        end

        -- Registered Forever UIPanels fail closed through the guarded title adapter.
        -- Do not fall back to the legacy whole-panel mouse/drag hooks if the secure
        -- grip cannot be established.
        if AttachGuardedForeverPanelMotion(frame, name) then return end

        local movableOK = pcall(function()
            frame:SetMovable(true)
            frame:SetClampedToScreen(false)
        end)
        if not movableOK or (frame.IsMovable and not frame:IsMovable()) then return end

        local function HookPanelDragSurface(surface)
            if not surface or surface._OffhandPanelDragTarget == frame
                or (surface.IsForbidden and surface:IsForbidden()) then return false end

            local hooked = pcall(function()
                surface:EnableMouse(true)
                surface:RegisterForDrag("LeftButton")
                surface:HookScript("OnDragStart", function()
                    if InCombatLockdown() or not Offhand.db.enabled
                        or ShouldYieldFrameToClassicUIForever(frame, name) then return end
                    local started = pcall(function() frame:StartMoving() end)
                    frame._OffhandDragging = started and true or false
                end)
                surface:HookScript("OnDragStop", function()
                    if ShouldYieldFrameToClassicUIForever(frame, name) then
                        SetPanelDragging(frame, false)
                        return
                    end
                    OnPanelDragStop(frame)
                end)
            end)
            if not hooked then return false end
            surface._OffhandPanelDragTarget = frame
            return true
        end

        -- Modern Blizzard panel templates place TitleContainer at frame level 510.
        -- Use that native title region directly: a child overlay at the parent's
        -- ordinary frame level sits underneath it and never receives drag input.
        -- Fall back to an elevated overlay only for older panels without a title
        -- container.
        -- MinimapCluster uses MinimapZoneTextButton as its natural drag handle and must not have an overlaid handle
        -- Unit frames (PartyMemberFrame, CompactPartyFrame) and FocusedRosterFrame must NOT have an overlaid handle
        -- to prevent blocking unit targeting, healing, right-click context menus, and roster row selection
        local isUnitFrame = name and (string.match(name, "^PartyMemberFrame") or string.match(name, "^CompactPartyFrame") or name == "PlayerFrame" or name == "TargetFrame")
        if frame ~= MinimapCluster and not isUnitFrame  then
            local titleContainer = frame.TitleContainer or (name and _G[name .. "TitleContainer"])
            if titleContainer and HookPanelDragSurface(titleContainer) then
                frame._OffhandHandle = titleContainer
            elseif not frame._OffhandHandle and CreateFrame then
                local handle
                handle = CreateFrame("Frame", nil, frame)
                handle._OffhandSyntheticPanelDragHandle = true
                handle:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, 0)
                handle:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -36, 0)
                handle:SetHeight(32)
                local lvl = (frame.GetFrameLevel and frame:GetFrameLevel()) or 1
                if handle.SetFrameLevel then handle:SetFrameLevel(math.max(lvl + 25, 520)) end
                HookPanelDragSurface(handle)
                frame._OffhandHandle = handle
            end
        end

        local frameIsProtected = frame.IsProtected and frame:IsProtected()
        if not frameIsProtected then
            frame:EnableMouse(true)
            frame:RegisterForDrag("LeftButton")

            frame:HookScript("OnDragStart", function(self)
                if InCombatLockdown() or not Offhand.db.enabled
                    or ShouldYieldFrameToClassicUIForever(frame, name) then return end
                frame._OffhandDragging = true
                frame:StartMoving()
            end)

            frame:HookScript("OnDragStop", function(self)
                if ShouldYieldFrameToClassicUIForever(frame, name) then
                    SetPanelDragging(frame, false)
                    return
                end
                OnPanelDragStop(frame)
            end)
        end

        -- Modern/Forever combined bags are dragged by their native TitleContainer,
        -- which may not exist yet when the parent frame is first discovered.
        HookContainerTitlePersistence(frame, name)
        HookCombinedBagCloseButton(frame, name)
        HookPanelCloseButton(frame, name)
        HookKnownPanelAnchorResets(frame, name)

        pcall(function()
            frame:HookScript("OnShow", function(self)
                HookContainerTitlePersistence(frame, name)
                HookCombinedBagCloseButton(frame, name)
                HookPanelCloseButton(frame, name)
                RestoreSavedPositionAfterShow(frame)
                if Offhand.db and Offhand.db.savedWorkspacePositions
                    and Offhand.db.savedWorkspacePositions[name] then
                    Canvas:SetWorkspacePanelOpen(frame, true)
                end
            end)
        end)

        if frame == MinimapCluster then
            local function HookMinimapDragHandle(handleFrame)
                if handleFrame and not handleFrame._OffhandHooked then
                    handleFrame._OffhandHooked = true
                    handleFrame:EnableMouse(true)
                    handleFrame:RegisterForDrag("LeftButton")
                    handleFrame:HookScript("OnDragStart", function(self)
                        if InCombatLockdown() or not Offhand.db.enabled then return end
                        frame:SetMovable(true)
                        frame._OffhandDragging = true
                        frame:StartMoving()
                    end)
                    handleFrame:HookScript("OnDragStop", function(self)
                        OnPanelDragStop(frame)
                    end)
                end
            end

            HookMinimapDragHandle(MinimapZoneTextButton)
            HookMinimapDragHandle(_G["MinimapBorderTop"])
            HookMinimapDragHandle(MinimapCluster)
        end

        if frame == WorldMapFrame and not Offhand.isForever then
            if WorldMapTitleButton and not WorldMapTitleButton._OffhandHooked then
                WorldMapTitleButton._OffhandHooked = true
                WorldMapTitleButton:RegisterForDrag("LeftButton")
                WorldMapTitleButton:HookScript("OnDragStart", function(self)
                    if InCombatLockdown() or not Offhand.db.enabled
                        or ShouldYieldFrameToClassicUIForever(frame) then return end
                    frame._OffhandDragging = true
                end)
                WorldMapTitleButton:HookScript("OnDragStop", function(self)
                    OnPanelDragStop(frame)
                end)
            end
            if WorldMapTitleButton_OnDragStop and not Canvas._titleButtonHooked then
                Canvas._titleButtonHooked = true
                hooksecurefunc("WorldMapTitleButton_OnDragStop", function()
                    OnPanelDragStop(frame)
                end)
            end
        end

        frame._OffhandMovable = true
    end
    return MakePanelDraggable
end


function Motion.Install(Canvas, services)
    local Compatibility = Offhand.CanvasCompatibility
    local IsForeverProfessionsPanel = Compatibility.IsForeverProfessionsPanel
    local IsExperimentalForeverProfessionsMovementEnabled = Compatibility.IsExperimentalForeverProfessionsMovementEnabled
    local IsForeverEditModeFrame = Compatibility.IsForeverEditModeFrame
    local FrameState = Offhand.CanvasFrameState
    local IsForeverWorldMap = FrameState.IsForeverWorldMap
    local SetPanelDragging = FrameState.SetDragging
    local IsPanelDragging = FrameState.IsDragging
    local foreverPanelMotionStatus = setmetatable({}, { __mode = "k" })
    local RestoreSavedPositionAfterShow = assert(services.RestoreSavedPositionAfterShow, "Missing panel motion service: RestoreSavedPositionAfterShow")
    local RestoreWorkspacePosition = assert(services.RestoreWorkspacePosition, "Missing panel motion service: RestoreWorkspacePosition")
    local IsUnsafeForPanelMutation = assert(services.IsUnsafeForPanelMutation, "Missing panel motion service: IsUnsafeForPanelMutation")
    local CanManagePanelsFromAddon = assert(services.CanManagePanelsFromAddon, "Missing panel motion service: CanManagePanelsFromAddon")
    local OnPanelDragStop = assert(services.OnPanelDragStop, "Missing panel motion service: OnPanelDragStop")
    local HookPanelCloseButton = assert(services.HookPanelCloseButton, "Missing panel motion service: HookPanelCloseButton")

    -- Communities changes its own root anchor when switching between Chat, Roster,
    -- Info and recruitment/settings views. Preserve an explicit Offhand placement
    -- after that native layout pass instead of letting the panel jump to UIParent's
    -- spanned top-left corner. Visibility and tab selection remain Blizzard-owned.
    local function HookKnownPanelAnchorResets(frame, name)
        local panelName = name or (frame and frame.GetName and frame:GetName())
        local isCommunities = (panelName == "CommunitiesFrame")
        local isProfessions = IsForeverProfessionsPanel(frame, panelName) and IsExperimentalForeverProfessionsMovementEnabled()
        if (not isCommunities and not isProfessions) or frame._OffhandAnchorResetHooked
            or not hooksecurefunc or not C_Timer or not C_Timer.After then return end
        frame._OffhandAnchorResetHooked = true
        hooksecurefunc(frame, "SetPoint", function()
            if frame._OffhandAnchorRepairing or frame._OffhandDragging
                or not Offhand.db or not Offhand.db.enabled then return end
            local workspace = Offhand.db.savedWorkspacePositions
                and Offhand.db.savedWorkspacePositions[panelName]
            local mainhand = Offhand.db.savedMainPositions
                and Offhand.db.savedMainPositions[panelName]
            if not workspace and not mainhand then return end
            if isProfessions then
                if not frame._OffhandExperimentalProfessionsAttached
                    or not IsExperimentalForeverProfessionsMovementEnabled() then return end
                frame._OffhandAnchorRepairing = true
                frame._OffhandExperimentalProfessionsRestoreAllowed = true
                RestoreSavedPositionAfterShow(frame)
                frame._OffhandExperimentalProfessionsRestoreAllowed = nil
                frame._OffhandAnchorRepairing = nil
                return
            end
            if frame._OffhandAnchorRepairPending then return end
            frame._OffhandAnchorRepairPending = true
            C_Timer.After(0, function()
                frame._OffhandAnchorRepairPending = nil
                if frame._OffhandDragging or not Offhand.db or not Offhand.db.enabled
                    or (frame.IsShown and not frame:IsShown()) then return end
                frame._OffhandAnchorRepairing = true
                RestoreWorkspacePosition(frame)
                frame._OffhandAnchorRepairing = nil
            end)
        end)
    end

    -- Forever's ordinary registered UIPanels use the same original Offhand motion
    -- adapter that was validated with Professions. The Blizzard title template owns
    -- StartMoving/StopMovingOrSizing; Offhand only observes the completed gesture
    -- and persists the resulting monitor placement. No panel-body mouse ownership,
    -- script replacement, or protected Edit Mode frame is involved.
    local function AttachGuardedForeverPanelMotion(frame, name)
        if not Offhand.isForever or not frame or not name
            or not UIPanelWindows or not UIPanelWindows[name] then return false end
        if IsForeverEditModeFrame(frame, name) or IsForeverProfessionsPanel(frame, name)
            or IsForeverWorldMap(frame) or IsUnsafeForPanelMutation(frame, name) then
            return false
        end
        if not CanManagePanelsFromAddon() then
            foreverPanelMotionStatus[frame] = "native_gamepad"
            return true
        end

        local motion = Offhand.PanelMotion
        if not motion or not motion.AttachGuardedTitleGrip then
            foreverPanelMotionStatus[frame] = "module_unavailable"
            return true
        end

        local title = frame.TitleContainer or _G[name .. "TitleContainer"] or frame
        local grip, status = motion:AttachGuardedTitleGrip(frame, {
            anchorFrame = title,
            leftInset = 10,
            rightInset = 36,
            height = 32,
            onBegin = function()
                if not Offhand.db or not Offhand.db.enabled then return end
                SetPanelDragging(frame, true)
            end,
            onFinish = function()
                if IsPanelDragging(frame) and Offhand.db and Offhand.db.enabled then
                    OnPanelDragStop(frame)
                else
                    SetPanelDragging(frame, false)
                end
            end,
        })
        foreverPanelMotionStatus[frame] = status
        if not grip then
            if status == "combat_deferred" and Offhand.RunOrQueueCombat then
                Offhand:RunOrQueueCombat(function()
                    if Offhand.db and Offhand.db.enabled then
                        AttachGuardedForeverPanelMotion(frame, name)
                    end
                end)
            end
            return true
        end

        frame._OffhandPanelMotionGrip = grip
        frame._OffhandHandle = grip
        HookPanelCloseButton(frame, name)
        HookKnownPanelAnchorResets(frame, name)

        if frame.HookScript and not frame._OffhandGuardedPanelShowHooked then
            frame._OffhandGuardedPanelShowHooked = true
            frame:HookScript("OnShow", function(self)
                if not Offhand.db or not Offhand.db.enabled then return end
                local workspacePosition = Offhand.db.savedWorkspacePositions
                    and Offhand.db.savedWorkspacePositions[name]
                local mainPosition = Offhand.db.savedMainPositions
                    and Offhand.db.savedMainPositions[name]
                if name == "FlightMapFrame" and not workspacePosition and not mainPosition then
                    Canvas:PlacePanelOnMainhand(self, nil, nil, false)
                else
                    RestoreSavedPositionAfterShow(self)
                end
                if workspacePosition then
                    Canvas:SetWorkspacePanelOpen(self, true)
                end
                if name == "FlightMapFrame" and C_Timer and C_Timer.After then
                    local function SettleFlightMap()
                        if not self.IsShown or not self:IsShown() or not Offhand.db
                            or not Offhand.db.enabled then return end
                        local savedWorkspace = Offhand.db.savedWorkspacePositions
                            and Offhand.db.savedWorkspacePositions[name]
                        local savedMain = Offhand.db.savedMainPositions
                            and Offhand.db.savedMainPositions[name]
                        if savedWorkspace or savedMain then
                            RestoreSavedPositionAfterShow(self)
                        else
                            Canvas:PlacePanelOnMainhand(self, nil, nil, false)
                        end
                    end
                    C_Timer.After(0, SettleFlightMap)
                    C_Timer.After(0.10, SettleFlightMap)
                end
            end)
        end

        frame._OffhandMovable = true
        return true
    end

    function Canvas:GetPanelMotionStatus(frame)
        return frame and foreverPanelMotionStatus[frame] or nil
    end

    return {
        HookKnownPanelAnchorResets = HookKnownPanelAnchorResets,
        AttachGuardedForeverPanelMotion = AttachGuardedForeverPanelMotion,
    }
end

