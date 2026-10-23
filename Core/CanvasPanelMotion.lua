-- Guarded Canvas title motion and native panel anchor-reset observation.
local _, Offhand = ...
local Motion = {}
Offhand.CanvasPanelMotion = Motion

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

