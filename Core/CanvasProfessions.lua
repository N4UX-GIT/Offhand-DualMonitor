-- Forever Professions movement, Escape recovery, and ownership cleanup.
local _, Offhand = ...
local Professions = {}
Offhand.CanvasProfessions = Professions

function Professions.Install(Canvas, services)
    local Compatibility = Offhand.CanvasCompatibility
    local IsForeverProfessionsPanel = Compatibility.IsForeverProfessionsPanel
    local IsExperimentalForeverProfessionsMovementEnabled = Compatibility.IsExperimentalForeverProfessionsMovementEnabled
    local IsPersistentForeverProfessionsPanelName = Compatibility.IsPersistentForeverProfessionsPanelName
    local IsPanelDragging = Offhand.CanvasFrameState.IsDragging
    local CanManagePanelsFromAddon = assert(services.CanManagePanelsFromAddon, "Missing Professions service: CanManagePanelsFromAddon")
    local IsSpannedLayoutActive = assert(services.IsSpannedLayoutActive, "Missing Professions service: IsSpannedLayoutActive")
    local NotePanelControllerActivity = assert(services.NotePanelControllerActivity, "Missing Professions service: NotePanelControllerActivity")
    local RestoreSavedPositionAfterShow = assert(services.RestoreSavedPositionAfterShow, "Missing Professions service: RestoreSavedPositionAfterShow")
    local UnregisterSpecialFrame = assert(services.UnregisterSpecialFrame, "Missing Professions service: UnregisterSpecialFrame")
    local HookKnownPanelAnchorResets = assert(services.HookKnownPanelAnchorResets, "Missing Professions service: HookKnownPanelAnchorResets")
    local OnPanelDragStop = assert(services.OnPanelDragStop, "Missing Professions service: OnPanelDragStop")
    local SaveOpenWorkspacePanels = assert(services.SaveOpenWorkspacePanels, "Missing Professions service: SaveOpenWorkspacePanels")

    -- Experimental Forever Professions support is intentionally isolated from the
    -- universal panel lifecycle. Blizzard must first finish a native manual
    -- opening before an Offhand drag surface is attached. After the player moves
    -- the standalone Professions book into Offhand, that explicit open position
    -- may participate in the narrow reload-restoration path above. Other
    -- Professions windows retain native visibility. Existing saved anchors are
    -- restored, while the first opted-in opening is centered on Mainhand so its
    -- title cannot remain trapped in a non-physical part of a mixed-height UIParent.
    function Canvas:ObserveForeverProfessionsPanelHide(frame)
        if not Offhand.isForever or not frame or not CanManagePanelsFromAddon()
            or not C_Timer or not C_Timer.After or not Offhand.db or not Offhand.db.enabled
            or Offhand.db.persistentWorkspacePanels == false
            or (Offhand.IsBlizzardInputReserved and Offhand:IsBlizzardInputReserved())
            or (InCombatLockdown and InCombatLockdown()) then return false end
        local name = frame.GetName and frame:GetName()
        if not IsPersistentForeverProfessionsPanelName(name)
            or not Offhand.db.openWorkspacePanels
            or not Offhand.db.openWorkspacePanels[name]
            or not Offhand.db.savedWorkspacePositions
            or not Offhand.db.savedWorkspacePositions[name]
            or (frame.IsShown and frame:IsShown()) then return false end

        local pending = {
            frame = frame,
            name = name,
            menuWasShown = GameMenuFrame and GameMenuFrame.IsShown
                and GameMenuFrame:IsShown() or false,
        }
        self._foreverProfessionsEscapePending = pending
        -- A close-button click or ordinary panel transition has no immediately
        -- paired ToggleGameMenu call. Let that native close stand and expire the
        -- candidate instead of turning every explicit close into an automatic
        -- reopen.
        C_Timer.After(0.10, function()
            if Canvas._foreverProfessionsEscapePending == pending then
                Canvas._foreverProfessionsEscapePending = nil
                if pending.frame.IsShown and not pending.frame:IsShown() then
                    Canvas:SetWorkspacePanelOpen(pending.name, false)
                end
            end
        end)
        return true
    end

    function Canvas:RestoreForeverProfessionsAfterEscape(pending)
        if not pending or not Offhand.isForever or not CanManagePanelsFromAddon()
            or not Offhand.db or not Offhand.db.enabled
            or Offhand.db.persistentWorkspacePanels == false
            or (Offhand.IsBlizzardInputReserved and Offhand:IsBlizzardInputReserved())
            or (InCombatLockdown and InCombatLockdown())
            or not IsSpannedLayoutActive() then return false end
        local frame, name = pending.frame, pending.name
        if not frame or not IsPersistentForeverProfessionsPanelName(name)
            or not Offhand.db.openWorkspacePanels
            or not Offhand.db.openWorkspacePanels[name]
            or not Offhand.db.savedWorkspacePositions
            or not Offhand.db.savedWorkspacePositions[name] then return false end

        if frame.IsShown and not frame:IsShown() and frame.Show then
            pcall(frame.Show, frame)
        end
        if not frame.IsShown or not frame:IsShown() then return false end
        frame._OffhandExperimentalProfessionsRestoreAllowed = true
        NotePanelControllerActivity(name, "forever-professions", "escape-restore")
        RestoreSavedPositionAfterShow(frame)
        frame._OffhandExperimentalProfessionsRestoreAllowed = nil
        self:SetWorkspacePanelOpen(name, true)

        -- Showing a native panel can alter the Game Menu. Preserve the state the
        -- Escape press itself requested without calling ToggleGameMenu a second
        -- time, which would start another native panel-close transaction.
        local menuShouldBeShown = not pending.menuWasShown
        local menuIsShown = GameMenuFrame and GameMenuFrame.IsShown
            and GameMenuFrame:IsShown() or false
        if GameMenuFrame and menuShouldBeShown ~= menuIsShown then
            if menuShouldBeShown and GameMenuFrame.Show then
                pcall(GameMenuFrame.Show, GameMenuFrame)
            elseif GameMenuFrame.Hide then
                pcall(GameMenuFrame.Hide, GameMenuFrame)
            end
        end
        return true
    end

    function Canvas:InstallForeverProfessionsEscapeHooks()
        if not Offhand.isForever or not hooksecurefunc then return false end
        if HideUIPanel and not self._foreverProfessionsHideHooked then
            self._foreverProfessionsHideHooked = true
            hooksecurefunc("HideUIPanel", function(panel)
                Canvas:ObserveForeverProfessionsPanelHide(panel)
            end)
        end
        if ToggleGameMenu and not self._foreverProfessionsGameMenuHooked then
            self._foreverProfessionsGameMenuHooked = true
            hooksecurefunc("ToggleGameMenu", function()
                local pending = Canvas._foreverProfessionsEscapePending
                if not pending or not C_Timer or not C_Timer.After then return end
                Canvas._foreverProfessionsEscapePending = nil
                C_Timer.After(0, function()
                    Canvas:RestoreForeverProfessionsAfterEscape(pending)
                end)
            end)
        end
        return self._foreverProfessionsHideHooked
            and self._foreverProfessionsGameMenuHooked or false
    end

    function Canvas:QueueExperimentalForeverProfessionsMovement(frame, suppliedName)
        local name = suppliedName or (frame and frame.GetName and frame:GetName())
        if not frame or not name or not IsForeverProfessionsPanel(frame, name)
            or not IsExperimentalForeverProfessionsMovementEnabled()
            or not C_Timer or not C_Timer.After then return false end
        self:InstallForeverProfessionsEscapeHooks()
        if frame._OffhandExperimentalProfessionsQueued then return true end

        local function RestoreSavedProfessionsPosition()
            if not CanManagePanelsFromAddon() or not Offhand.db or not Offhand.db.enabled
                or Offhand.db.persistentWorkspacePanels == false
                or IsPanelDragging(frame)
                or not frame.IsShown or not frame:IsShown() then return end
            local workspacePosition = Offhand.db.savedWorkspacePositions
                and Offhand.db.savedWorkspacePositions[name]
            if not workspacePosition then return end

            -- Forever retains ownership of the active UIPanel slot. Attempting to
            -- vacate that slot with HideUIPanel followed by Show is rejected or
            -- reclaimed by the live panel manager and creates visible/audio churn.
            -- Escape persistence is handled by the bounded native transaction
            -- observer above, while the saved anchor remains independently owned.
            UnregisterSpecialFrame(name)
            frame._OffhandExperimentalProfessionsRestoreAllowed = true
            NotePanelControllerActivity(name, "forever-professions", "saved-restore")
            RestoreSavedPositionAfterShow(frame)
            frame._OffhandExperimentalProfessionsRestoreAllowed = nil
        end

        -- Once the handle is attached and cold-start initialization has settled,
        -- subsequent openings can restore their saved placement immediately instead
        -- of waiting 1.0 second at Blizzard's native spanned top-left anchor.
        if frame._OffhandExperimentalProfessionsAttached then
            HookKnownPanelAnchorResets(frame, name)
            local savedOnWorkspace = Offhand.db and Offhand.db.savedWorkspacePositions
                and Offhand.db.savedWorkspacePositions[name]
            if frame.IsShown and frame:IsShown() then
                Canvas:SetWorkspacePanelOpen(name,
                    IsPersistentForeverProfessionsPanelName(name) and savedOnWorkspace or false)
            end
            -- The external watcher runs every 0.5 seconds because Professions can
            -- reclaim its UIPanel slot without emitting a stable public event. Do
            -- not let that repair path compete with Blizzard's native drag gesture;
            -- the completed drag will save the new anchor through OnPanelDragStop.
            if IsPanelDragging(frame) then return true end
            local hasSavedPosition = Offhand.db and
                ((Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions[name])
                    or (Offhand.db.savedMainPositions and Offhand.db.savedMainPositions[name]))
            if hasSavedPosition then
                frame._OffhandExperimentalProfessionsRestoreAllowed = true
                RestoreSavedPositionAfterShow(frame)
                frame._OffhandExperimentalProfessionsRestoreAllowed = nil
            else
                Canvas:PlacePanelOnMainhand(frame, nil, nil, false)
            end
            local grip = frame._OffhandExperimentalProfessionsGrip
            if grip and Offhand.PanelMotion and Offhand.PanelMotion.SetTitleGripActive then
                local _, status = Offhand.PanelMotion:SetTitleGripActive(frame, true)
                frame._OffhandExperimentalProfessionsMotionStatus = status
            end
            RestoreSavedProfessionsPosition()
            return true
        end

        frame._OffhandExperimentalProfessionsQueued = true
        frame._OffhandExperimentalProfessionsGeneration =
            (frame._OffhandExperimentalProfessionsGeneration or 0) + 1
        local generation = frame._OffhandExperimentalProfessionsGeneration
        local hasSavedPosition = Offhand.db and
            ((Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions[name])
                or (Offhand.db.savedMainPositions and Offhand.db.savedMainPositions[name]))
        -- A load-on-demand frame with a saved position can be prepared while it is
        -- still hidden. That installs the anchor observer before the first visible
        -- native layout pass and prevents the login/reload top-left flash.
        local attachDelay = hasSavedPosition and 0 or 1.0
        C_Timer.After(attachDelay, function()
            frame._OffhandExperimentalProfessionsQueued = nil
            if frame._OffhandExperimentalProfessionsGeneration ~= generation
                or not IsExperimentalForeverProfessionsMovementEnabled()
                or (frame.IsShown and not frame:IsShown() and not hasSavedPosition) then return end
            if InCombatLockdown() then
                if Offhand.RunOrQueueCombat then
                    Offhand:RunOrQueueCombat(function()
                        Canvas:QueueExperimentalForeverProfessionsMovement(frame, name)
                    end)
                end
                return
            end

            if not frame._OffhandExperimentalProfessionsAttached then
                if not Offhand.PanelMotion or not Offhand.PanelMotion.AttachGuardedTitleGrip then
                    frame._OffhandExperimentalProfessionsMotionStatus = "module_unavailable"
                    return
                end

                local grip, status = Offhand.PanelMotion:AttachGuardedTitleGrip(frame, {
                    anchorFrame = frame.TitleContainer,
                    leftInset = 10,
                    rightInset = 36,
                    height = 32,
                    onBegin = function()
                        if not Offhand.db or not Offhand.db.enabled
                            or not IsExperimentalForeverProfessionsMovementEnabled() then return end
                        frame._OffhandDragging = true
                    end,
                    onFinish = function()
                        if frame._OffhandDragging and IsExperimentalForeverProfessionsMovementEnabled() then
                            OnPanelDragStop(frame)
                        else
                            frame._OffhandDragging = false
                        end
                    end,
                })
                frame._OffhandExperimentalProfessionsMotionStatus = status
                if not grip then return end

                frame._OffhandExperimentalProfessionsGrip = grip
                frame._OffhandExperimentalProfessionsAttached = true
                HookKnownPanelAnchorResets(frame, name)
                if frame.HookScript then
                    frame:HookScript("OnShow", function(self)
                        Canvas:QueueExperimentalForeverProfessionsMovement(self, name)
                    end)
                end
            end

            local grip = frame._OffhandExperimentalProfessionsGrip
            if grip and Offhand.PanelMotion and Offhand.PanelMotion.SetTitleGripActive then
                local _, status = Offhand.PanelMotion:SetTitleGripActive(frame, true)
                frame._OffhandExperimentalProfessionsMotionStatus = status
            end
            local savedOnWorkspace = Offhand.db and Offhand.db.savedWorkspacePositions
                and Offhand.db.savedWorkspacePositions[name]
            if frame.IsShown and frame:IsShown() then
                Canvas:SetWorkspacePanelOpen(name,
                    IsPersistentForeverProfessionsPanelName(name) and savedOnWorkspace or false)
            end
            hasSavedPosition = Offhand.db and
                ((Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions[name])
                    or (Offhand.db.savedMainPositions and Offhand.db.savedMainPositions[name]))
            if hasSavedPosition then
                frame._OffhandExperimentalProfessionsRestoreAllowed = true
                RestoreSavedPositionAfterShow(frame)
                frame._OffhandExperimentalProfessionsRestoreAllowed = nil
            else
                -- Blizzard anchors this panel against the complete spanned
                -- UIParent. With a portrait workspace beside a landscape Mainhand,
                -- that default upper-left anchor can put the title bar in the void
                -- above Mainhand and make our opt-in drag surface unreachable.
                -- This runs only after the one-second native-open settlement and
                -- only under explicit experimental consent; it does not open,
                -- demodalize, persist or otherwise join the generic panel lifecycle.
                Canvas:PlacePanelOnMainhand(frame, nil, nil, false)
            end
            RestoreSavedProfessionsPosition()
        end)
        return true
    end

    function Canvas:GetExperimentalProfessionsMotionDiagnostics()
        if not Offhand.isForever then return nil end
        local enabled = IsExperimentalForeverProfessionsMovementEnabled() and "1" or "0"
        local entries = {}
        if UIPanelWindows then
            for name in pairs(UIPanelWindows) do
                local frame = _G[name]
                if frame and IsForeverProfessionsPanel(frame, name) then
                    local protected = frame.IsProtected and frame:IsProtected() and "1" or "0"
                    local status = frame._OffhandExperimentalProfessionsMotionStatus
                        or (Offhand.PanelMotion and Offhand.PanelMotion.GetStatus
                            and Offhand.PanelMotion:GetStatus(frame)) or "not_attached"
                    entries[#entries + 1] = string.format("%s:%s/protected=%s", name, status, protected)
                end
            end
        end
        table.sort(entries)
        local allMotion = Offhand.PanelMotion and Offhand.PanelMotion.GetDiagnostics
            and Offhand.PanelMotion:GetDiagnostics() or "Attached=0 | Frames=none"
        return string.format("Enabled=%s | Professions=%s | %s", enabled,
            #entries > 0 and table.concat(entries, ",") or "not loaded", allMotion)
    end

    -- A saved Professions position can be restored before PanelMotion is allowed
    -- to attach its title grip. This happens most often while Forever is still
    -- changing interface styles, because native Gamepad safely rejects child
    -- controls on Blizzard panels. Retry only visible, still-unattached roots;
    -- once a grip exists this observer becomes a no-op and cannot compete with a
    -- live drag or with the panel's saved-position settlement.
    function Canvas:RetryMissingExperimentalForeverProfessionsMovement()
        if not IsExperimentalForeverProfessionsMovementEnabled()
            or not CanManagePanelsFromAddon() or not UIPanelWindows then return false end
        local queued = false
        for name in pairs(UIPanelWindows) do
            local frame = _G[name]
            if frame and IsForeverProfessionsPanel(frame, name)
                and not frame._OffhandExperimentalProfessionsAttached
                and frame.IsShown and frame:IsShown() then
                self:QueueExperimentalForeverProfessionsMovement(frame, name)
                queued = true
            end
        end
        return queued
    end

    function Canvas:EnableExperimentalForeverProfessionsMovement()
        if not IsExperimentalForeverProfessionsMovementEnabled() then return false end
        self:InstallForeverProfessionsEscapeHooks()
        self:RetryMissingExperimentalForeverProfessionsMovement()
        if UIPanelWindows then
            for name in pairs(UIPanelWindows) do
                local frame = _G[name]
                if frame and IsForeverProfessionsPanel(frame, name) then
                    if frame._OffhandExperimentalProfessionsAttached then
                        local grip = frame._OffhandExperimentalProfessionsGrip
                        if grip and Offhand.PanelMotion and Offhand.PanelMotion.SetTitleGripActive then
                            local _, status = Offhand.PanelMotion:SetTitleGripActive(frame, true)
                            frame._OffhandExperimentalProfessionsMotionStatus = status
                        end
                        HookKnownPanelAnchorResets(frame, name)
                    end
                end
            end
        end
        return true
    end

    function Canvas:DisableExperimentalForeverProfessionsMovement()
        if not Offhand.isForever then return false end
        if self.experimentalProfessionsWatcher then
            if self.experimentalProfessionsWatcher.Cancel then
                self.experimentalProfessionsWatcher:Cancel()
            end
            self.experimentalProfessionsWatcher = nil
        end
        if UIPanelWindows then
            for name in pairs(UIPanelWindows) do
                if IsForeverProfessionsPanel(nil, name) then
                    local frame = _G[name]
                    if frame then
                        frame._OffhandExperimentalProfessionsGeneration =
                            (frame._OffhandExperimentalProfessionsGeneration or 0) + 1
                        frame._OffhandExperimentalProfessionsQueued = nil
                        frame._OffhandExperimentalProfessionsRestoreAllowed = nil
                        local grip = frame._OffhandExperimentalProfessionsGrip
                        if grip and Offhand.PanelMotion and Offhand.PanelMotion.SetTitleGripActive then
                            local deactivated, status = Offhand.PanelMotion:SetTitleGripActive(frame, false)
                            frame._OffhandExperimentalProfessionsMotionStatus = status
                            if not deactivated and status == "combat_deferred" and Offhand.RunOrQueueCombat then
                                Offhand:RunOrQueueCombat(function()
                                    if Offhand.PanelMotion then
                                        local _, deferredStatus = Offhand.PanelMotion:SetTitleGripActive(frame, false)
                                        frame._OffhandExperimentalProfessionsMotionStatus = deferredStatus
                                    end
                                end)
                            end
                        end
                    end
                end
            end
        end
        self:RelinquishForeverProfessionsPanels()
        return true
    end

    -- Remove historical Offhand ownership records so an upgraded installation
    -- cannot keep retrying a Professions restore that the new policy forbids.
    -- This does not hide, show, anchor, register, or otherwise touch Blizzard's
    -- live frame.
    function Canvas:RelinquishForeverProfessionsPanels(onlyName)
        if not Offhand.isForever or not Offhand.db then return false end
        local cleared = false
        local clearedNames = {}
        local tables = {
            Offhand.db.savedWorkspacePositions,
            Offhand.db.savedMainPositions,
            Offhand.db.openWorkspacePanels,
        }
        for _, records in ipairs(tables) do
            if type(records) == "table" then
                for name in pairs(records) do
                    if (not onlyName or name == onlyName)
                        and IsForeverProfessionsPanel(nil, name) then
                        records[name] = nil
                        cleared = true
                        clearedNames[name] = true
                    end
                end
            end
        end
        if cleared and Offhand.ForeverPersistence and Offhand.ForeverPersistence.ClearPosition then
            for name in pairs(clearedNames) do
                Offhand.ForeverPersistence:ClearPosition(name)
            end
        end
        if cleared then SaveOpenWorkspacePanels() end
        return cleared
    end
end

