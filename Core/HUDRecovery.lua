-- Edit Mode layout ownership, missing-monitor recovery, and protected HUD repair.
local _, Offhand = ...
local Recovery = {}
Offhand.HUDRecovery = Recovery

function Recovery.Install(HUD)
    local Compatibility = assert(Offhand.HUDCompatibility, "Offhand HUD compatibility must load before recovery")
    local HasEllesmerePartyFrames = Compatibility.HasEllesmerePartyFrames
    local HasBlizzardEditMode = Compatibility.HasBlizzardEditMode
    local UsesControllerInterface = Compatibility.UsesControllerInterface
    local UsesForeverEditMode = Compatibility.UsesForeverEditMode

    local function GetEditModeLayouts()
        if not C_EditMode or not C_EditMode.GetLayouts then return nil end
        local ok, data = pcall(C_EditMode.GetLayouts)
        if not ok or type(data) ~= "table" or type(data.layouts) ~= "table" then return nil end
        return data
    end

    local function SelectEditModeLayout(layoutID)
        if not layoutID or not C_EditMode or not C_EditMode.SetActiveLayout then return false end
        return pcall(C_EditMode.SetActiveLayout, layoutID)
    end

    -- Forever reserves global identifiers 1 and 2 for Modern and Classic and a
    -- third internal slot before custom layouts. GetLayouts().layouts contains only
    -- custom entries, while activeLayout/SetActiveLayout use the global identifier.
    -- For example, layouts[3] named Offhand is activeLayout 6.
    local FOREVER_CUSTOM_LAYOUT_OFFSET = 3
    local FOREVER_MODERN_LAYOUT_ID = 1
    local FOREVER_MISMATCH_GRACE_SECONDS = 8

    local function GetForeverLayoutByID(data, layoutID)
        if type(data) ~= "table" or type(data.layouts) ~= "table" then return nil end
        layoutID = tonumber(layoutID)
        if not layoutID or layoutID <= FOREVER_CUSTOM_LAYOUT_OFFSET then return nil end
        return data.layouts[layoutID - FOREVER_CUSTOM_LAYOUT_OFFSET]
    end

    local function EditModeLayoutNamesMatch(left, right)
        return type(left) == "string" and type(right) == "string"
            and string.lower(left) == string.lower(right)
    end

    local function GetActiveEditModeLayoutName()
        local manager = _G.EditModeManagerFrame
        if not manager or type(manager.GetActiveLayoutInfo) ~= "function" then return nil end
        local ok, activeInfo = pcall(manager.GetActiveLayoutInfo, manager)
        local name = ok and type(activeInfo) == "table" and activeInfo.layoutName or nil
        if type(name) ~= "string" or not name:match("%S") then return nil end
        return name
    end

    local function GetEditModeCustomLayoutOffset(data, activeName)
        local manager = _G.EditModePresetLayoutManager
        if manager and type(manager.GetCopyOfPresetLayouts) == "function" then
            local ok, presets = pcall(manager.GetCopyOfPresetLayouts, manager)
            if ok and type(presets) == "table" and #presets > 0 then return #presets end
        end
        -- If the preset manager has not materialized yet, a currently active custom
        -- layout still reveals the namespace offset without hard-coding its slot.
        local activeID = type(data) == "table" and tonumber(data.activeLayout) or nil
        if activeID and type(activeName) == "string" and type(data.layouts) == "table" then
            for index, layout in ipairs(data.layouts) do
                if EditModeLayoutNamesMatch(layout and layout.layoutName, activeName) then
                    local offset = activeID - index
                    if offset >= 0 then return offset end
                end
            end
        end
        -- All supported Blizzard Edit Mode branches reserve three preset/global
        -- identifiers before custom layouts. The live preset count above remains
        -- authoritative if a future branch changes that topology.
        return FOREVER_CUSTOM_LAYOUT_OFFSET
    end

    -- Retail and Anniversary can briefly restore the wrong active layout during
    -- login. Remember the player's last explicit selection per character so a
    -- later mismatch can be repaired without imposing one account-wide layout
    -- name on every class. Forever intentionally keeps its separate, click-driven
    -- missing-monitor recovery path and never writes this preference.
    local function RememberCharacterEditModeLayout(layoutID)
        if UsesForeverEditMode() or type(OffhandCharDB) ~= "table" then return nil end

        local name
        local data = GetEditModeLayouts()
        local index = tonumber(layoutID)
        local layout = data and index and data.layouts[index]
        if layout and type(layout.layoutName) == "string" and layout.layoutName:match("%S") then
            name = layout.layoutName
        else
            name = GetActiveEditModeLayoutName()
        end

        if name then OffhandCharDB.editModeLayoutName = name end
        return name
    end

    local function HookCharacterEditModeSelection()
        if UsesForeverEditMode() or HUD.characterEditModeSelectionHooked
            or not _G.EditModeManagerFrame
            or type(_G.EditModeManagerFrame.HookScript) ~= "function" then return end

        HUD.characterEditModeSelectionHooked = true
        _G.EditModeManagerFrame:HookScript("OnShow", function()
            HUD.characterEditModeManagerWasShown = true
            HUD.characterEditModeStartLayoutName = GetActiveEditModeLayoutName()
        end)
        _G.EditModeManagerFrame:HookScript("OnHide", function()
            if not HUD.characterEditModeManagerWasShown then return end
            HUD.characterEditModeManagerWasShown = nil
            local startName = HUD.characterEditModeStartLayoutName
            HUD.characterEditModeStartLayoutName = nil
            -- Read after Blizzard finishes its close/save transaction. Observing
            -- the manager avoids treating login-time API activity as a deliberate
            -- player choice.
            local function SettledSelection()
                local name = RememberCharacterEditModeLayout()
                if name and name ~= startName and Offhand.Mainhand
                    and Offhand.Mainhand.RememberWindowModeLayoutSelection then
                    Offhand.Mainhand:RememberWindowModeLayoutSelection(name)
                end
                if Offhand.Mainhand and Offhand.Mainhand.UpdateWindowModeLayout and Offhand.ApplyFullLayout then
                    Offhand:ApplyFullLayout()
                end
            end
            if C_Timer and C_Timer.After then C_Timer.After(0, SettledSelection)
            else SettledSelection() end
        end)
    end

    local function FindForeverLayoutByName(data, layoutName)
        if type(data) ~= "table" or type(data.layouts) ~= "table" or type(layoutName) ~= "string" then return nil end
        for index, layout in ipairs(data.layouts) do
            if layout and EditModeLayoutNamesMatch(layout.layoutName, layoutName) then
                return layout, index + FOREVER_CUSTOM_LAYOUT_OFFSET
            end
        end
    end

    local function ResolveForeverLayoutID(data, savedID, savedName)
        local numericID = tonumber(savedID)
        local layout = GetForeverLayoutByID(data, numericID)
        if layout and (not savedName or EditModeLayoutNamesMatch(layout.layoutName, savedName)) then
            return numericID, layout
        end
        local namedLayout, namedID = FindForeverLayoutByName(data, savedName)
        if namedID then return namedID, namedLayout end
        -- A remembered name is stronger evidence than a stale numeric slot. If the
        -- named layout no longer exists, never select whichever unrelated layout
        -- happens to occupy its former ID.
        if type(savedName) == "string" then return nil end
        return numericID, layout
    end

    local function PersistForeverEditModeState()
        local persistence = Offhand.ForeverPersistence
        if persistence and persistence.SaveProfileSnapshot then
            persistence:SaveProfileSnapshot(true)
        end
    end

    local function PrepareForeverEditModeState(data, metrics)
        if not UsesForeverEditMode() or type(OffhandCharDB) ~= "table"
            or type(data) ~= "table" then return nil end

        local changed = false
        local activeID = tonumber(data.activeLayout)
        local legacy = OffhandCharDB.foreverEditModeLegacyRecovery
        if type(legacy) == "table" then
            local restoreID, restoreLayout = ResolveForeverLayoutID(
                data, legacy.restoreLayoutID, legacy.restoreLayoutName)
            local fallbackID = tonumber(legacy.fallbackLayoutID) or FOREVER_MODERN_LAYOUT_ID
            if restoreID and restoreLayout
                and (activeID == restoreID or activeID == fallbackID) then
                OffhandCharDB.foreverEditModeLayoutName = restoreLayout.layoutName
                OffhandCharDB.foreverEditModeLayoutID = restoreID
                OffhandCharDB.foreverEditModeRecovery = {
                    restoreLayoutID = restoreID,
                    restoreLayoutName = restoreLayout.layoutName,
                    fallbackLayoutID = fallbackID,
                    fallbackLayoutName = type(legacy.fallbackLayoutName) == "string"
                        and legacy.fallbackLayoutName or "Modern",
                }
            end
            OffhandCharDB.foreverEditModeLegacyRecovery = nil
            changed = true
        end

        local preferredName = OffhandCharDB.foreverEditModeLayoutName
        local preferredID, preferredLayout = ResolveForeverLayoutID(
            data, OffhandCharDB.foreverEditModeLayoutID, preferredName)
        if preferredLayout then
            if preferredName ~= preferredLayout.layoutName or preferredID ~= OffhandCharDB.foreverEditModeLayoutID then
                OffhandCharDB.foreverEditModeLayoutName = preferredLayout.layoutName
                OffhandCharDB.foreverEditModeLayoutID = preferredID
                changed = true
            end
        elseif not preferredName and metrics and metrics.companionTopology and metrics.isSpanned then
            -- Safe upgrade path: a healthy exact span with an active custom layout
            -- is unambiguous. Built-in Modern/Classic layouts are never adopted.
            local activeLayout = GetForeverLayoutByID(data, activeID)
            if activeLayout and type(activeLayout.layoutName) == "string" then
                OffhandCharDB.foreverEditModeLayoutName = activeLayout.layoutName
                OffhandCharDB.foreverEditModeLayoutID = activeID
                preferredID, preferredLayout = activeID, activeLayout
                changed = true
            end
        end

        if changed then PersistForeverEditModeState() end
        return preferredID, preferredLayout
    end

    function HUD:GetForeverEditModeLayoutStatus()
        local data = GetEditModeLayouts()
        local character = type(OffhandCharDB) == "table" and OffhandCharDB or nil
        local activeID = data and tonumber(data.activeLayout) or nil
        local activeLayout = data and GetForeverLayoutByID(data, activeID) or nil
        local preferredName = character and character.foreverEditModeLayoutName or nil
        local preferredID, preferredLayout
        if data then
            preferredID, preferredLayout = ResolveForeverLayoutID(
                data, character and character.foreverEditModeLayoutID, preferredName)
        end
        return {
            preferredName = preferredName,
            preferredID = preferredID,
            preferredAvailable = preferredLayout ~= nil,
            activeName = activeLayout and activeLayout.layoutName or nil,
            activeID = activeID,
            activeIsCustom = activeLayout ~= nil,
            activeMatches = preferredID ~= nil and activeID == preferredID,
            recoveryPending = character and type(character.foreverEditModeRecovery) == "table" or false,
        }
    end

    function HUD:UseCurrentForeverEditModeLayout()
        if not UsesForeverEditMode() then return false, "client" end
        if InCombatLockdown() then return false, "combat" end
        if type(OffhandCharDB) ~= "table" then return false, "state" end
        local data = GetEditModeLayouts()
        if not data then return false, "unavailable" end
        local activeID = tonumber(data.activeLayout)
        local layout = GetForeverLayoutByID(data, activeID)
        if not layout or type(layout.layoutName) ~= "string" then return false, "builtin" end

        OffhandCharDB.foreverEditModeLayoutName = layout.layoutName
        OffhandCharDB.foreverEditModeLayoutID = activeID
        local generated = OffhandCharDB.mainhandLayout
        if type(generated) == "table"
            and EditModeLayoutNamesMatch(generated.generatedName, layout.layoutName) then
            generated.generatedID = activeID
            generated.activationPending = nil
        end
        OffhandCharDB.foreverEditModeLegacyRecovery = nil
        OffhandCharDB.foreverEditModeRecovery = nil
        self.foreverRecoveryPromptShown = nil
        if Offhand.HideForeverLayoutRecoveryPrompt then
            Offhand:HideForeverLayoutRecoveryPrompt("fallback")
            Offhand:HideForeverLayoutRecoveryPrompt("restore")
        end
        PersistForeverEditModeState()
        return true, layout.layoutName
    end

    local function IsForeverSingleScreenRecovery(metrics)
        if Offhand.Viewport and Offhand.Viewport.IsSingleScreenRecovery then
            return Offhand.Viewport:IsSingleScreenRecovery(metrics)
        end
        return metrics and not metrics.isSpanned
            and metrics.topologyStatus == "MISMATCH" or false
    end

    local function ScheduleForeverRecoveryRetry(self, delay)
        if not C_Timer or not C_Timer.After or self.foreverRecoveryRetryPending then return end
        self.foreverRecoveryRetryPending = true
        C_Timer.After(delay or 1, function()
            self.foreverRecoveryRetryPending = nil
            local current = Offhand.Viewport and Offhand.Viewport.GetMetrics and Offhand.Viewport:GetMetrics()
            self:UpdateForeverRecoveryLayout(current)
        end)
    end

    local function ScheduleForeverMismatchConfirmation(self)
        if not C_Timer or not C_Timer.After or self.foreverMismatchConfirmationPending then return end
        self.foreverMismatchConfirmationPending = true
        C_Timer.After(FOREVER_MISMATCH_GRACE_SECONDS, function()
            self.foreverMismatchConfirmationPending = nil
            local current = Offhand.Viewport and Offhand.Viewport.GetMetrics and Offhand.Viewport:GetMetrics()
            if IsForeverSingleScreenRecovery(current) then
                self.foreverMismatchConfirmed = true
                self:UpdateForeverRecoveryLayout(current)
            else
                self.foreverMismatchConfirmed = nil
                self.foreverMismatchDeclined = nil
                if Offhand.HideForeverLayoutRecoveryPrompt then
                    Offhand:HideForeverLayoutRecoveryPrompt("fallback")
                end
            end
        end)
    end

    -- Forever's protected HUD is owned by Blizzard Edit Mode. A layout saved for a
    -- 4000x2560 span remains active if a display disappears, so Blizzard clamps its
    -- anchors into a readable but malformed single-screen arrangement. Forever only
    -- accepts the protected layout change from a hardware event, so remember enough
    -- state and present a player-click prompt for both fallback and restoration. If
    -- the player chooses another layout during recovery, that explicit choice wins.
    function HUD:UpdateForeverRecoveryLayout(metrics)
        if not UsesForeverEditMode() or not Offhand.db or not Offhand.db.enabled
            or InCombatLockdown() or not metrics then return end

        local data = GetEditModeLayouts()
        if not data then
            ScheduleForeverRecoveryRetry(self, 2)
            return
        end

        local activeID = tonumber(data.activeLayout)
        local active = GetForeverLayoutByID(data, activeID)
        local activeName = active and active.layoutName
        local preferredID, preferredLayout = PrepareForeverEditModeState(data, metrics)
        local preferredName = preferredLayout and preferredLayout.layoutName
            or (type(OffhandCharDB) == "table" and OffhandCharDB.foreverEditModeLayoutName or nil)
        local recovery = type(OffhandCharDB) == "table" and OffhandCharDB.foreverEditModeRecovery or nil

        if IsForeverSingleScreenRecovery(metrics) then
            if not recovery then
                if not preferredID or activeID ~= preferredID
                    or not EditModeLayoutNamesMatch(activeName, preferredName) then return end
                if self.foreverMismatchDeclined then return end
                if not self.foreverMismatchConfirmed then
                    ScheduleForeverMismatchConfirmation(self)
                    return
                end
                recovery = {
                    restoreLayoutID = activeID,
                    restoreLayoutName = activeName,
                    fallbackLayoutID = FOREVER_MODERN_LAYOUT_ID,
                    fallbackLayoutName = "Modern",
                }
                OffhandCharDB.foreverEditModeRecovery = recovery
                PersistForeverEditModeState()
            end
            if activeID == tonumber(recovery.restoreLayoutID)
                and self.foreverRecoveryPromptShown ~= "fallback" then
                self.foreverRecoveryPromptShown = "fallback"
                if Offhand.ShowForeverLayoutRecoveryPrompt then
                    Offhand:ShowForeverLayoutRecoveryPrompt("fallback", recovery.restoreLayoutName)
                end
            end
            return
        end


        self.foreverMismatchConfirmed = nil
        self.foreverMismatchDeclined = nil

        if recovery and metrics.companionTopology and metrics.isSpanned then
            local restoreID, restoreLayout = ResolveForeverLayoutID(
                data, recovery.restoreLayoutID, recovery.restoreLayoutName)
            if restoreID and restoreLayout then
                local changed = recovery.restoreLayoutID ~= restoreID
                    or recovery.restoreLayoutName ~= restoreLayout.layoutName
                recovery.restoreLayoutID = restoreID
                recovery.restoreLayoutName = restoreLayout.layoutName
                if changed then PersistForeverEditModeState() end
            end
            local fallbackMatches = activeID == tonumber(recovery.fallbackLayoutID)
            if activeID == restoreID then
                OffhandCharDB.foreverEditModeRecovery = nil
                PersistForeverEditModeState()
                self.foreverRecoveryPromptShown = nil
                if Offhand.HideForeverLayoutRecoveryPrompt then
                    Offhand:HideForeverLayoutRecoveryPrompt("fallback")
                    Offhand:HideForeverLayoutRecoveryPrompt("restore")
                end
                return
            end
            if not fallbackMatches or not restoreID then
                -- A different active layout means the player made an explicit
                -- choice during recovery. Do not replace it.
                OffhandCharDB.foreverEditModeRecovery = nil
                PersistForeverEditModeState()
                self.foreverRecoveryPromptShown = nil
                if Offhand.HideForeverLayoutRecoveryPrompt then
                    Offhand:HideForeverLayoutRecoveryPrompt("fallback")
                    Offhand:HideForeverLayoutRecoveryPrompt("restore")
                end
                return
            end
            if self.foreverRecoveryPromptShown ~= "restore" then
                self.foreverRecoveryPromptShown = "restore"
                if Offhand.ShowForeverLayoutRecoveryPrompt then
                    Offhand:ShowForeverLayoutRecoveryPrompt("restore", recovery.restoreLayoutName)
                end
            end
        end
    end

    -- Forever marks layout switching AllowedWhenUntainted. Calls made from addon
    -- timers are ignored, while the same call succeeds from a player click. These
    -- methods are invoked only by the recovery popup buttons.
    function HUD:ApplyForeverRecoveryChoice(choice)
        if InCombatLockdown() or type(OffhandCharDB) ~= "table" then return end
        local recovery = OffhandCharDB.foreverEditModeRecovery
        if type(recovery) ~= "table" then return end
        local targetID
        if choice == "restore" then
            local data = GetEditModeLayouts()
            local layout
            targetID, layout = ResolveForeverLayoutID(data, recovery.restoreLayoutID, recovery.restoreLayoutName)
            if targetID and layout then
                recovery.restoreLayoutID = targetID
                recovery.restoreLayoutName = layout.layoutName
            end
        else
            targetID = tonumber(recovery.fallbackLayoutID)
        end
        if not targetID then return end
        SelectEditModeLayout(targetID)
        self.foreverRecoveryPromptShown = nil
        local confirmed = GetEditModeLayouts()
        if choice == "restore" and confirmed and tonumber(confirmed.activeLayout) == targetID then
            OffhandCharDB.foreverEditModeRecovery = nil
            PersistForeverEditModeState()
            return
        end
        if C_Timer and C_Timer.After then
            C_Timer.After(0.1, function()
                local current = Offhand.Viewport and Offhand.Viewport.GetMetrics and Offhand.Viewport:GetMetrics()
                self:UpdateForeverRecoveryLayout(current)
            end)
        end
    end

    function HUD:CancelForeverRecoveryChoice(kind)
        if type(OffhandCharDB) == "table" then
            OffhandCharDB.foreverEditModeRecovery = nil
            PersistForeverEditModeState()
        end
        self.foreverRecoveryPromptShown = nil
        if kind == "fallback" then self.foreverMismatchDeclined = true end
    end

    local function FrameFitsPhysicalDisplay(frame, metrics)
        if not frame or not metrics or not frame.GetLeft or not frame.GetBottom
            or not frame.GetWidth or not frame.GetHeight then return true end
        local ok, left, bottom, width, height = pcall(function()
            local parentScale = (UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
            local frameScale = (frame.GetEffectiveScale and frame:GetEffectiveScale()) or parentScale
            local factor = frameScale / parentScale
            return frame:GetLeft() * factor, frame:GetBottom() * factor,
                frame:GetWidth() * factor, frame:GetHeight() * factor
        end)
        if not ok or not left or not bottom or not width or not height then return true end
        local right, top = left + width, bottom + height
        local function Fits(l, b, r, t)
            return l and b and r and t and left >= l - 1 and bottom >= b - 1
                and right <= r + 1 and top <= t + 1
        end
        return Fits(metrics.gameLeft, metrics.gameBottom, metrics.gameRight, metrics.gameTop)
            or Fits(metrics.workspaceLeft, metrics.workspaceBottom, metrics.workspaceRight, metrics.workspaceTop)
    end

    local foreverEditModeControlNames = {
        "EditModeSystemSettingsDialog",
        "EditModeLayoutDialog",
        "EditModeImportLayoutDialog",
        "EditModeImportLayoutLinkDialog",
        "EditModeUnsavedChangesDialog",
        "EditModeDialog",
    }

    -- Transactional layout modals reuse stale anchors while Blizzard changes
    -- modes. Observing those anchors must never inject another modal into the
    -- save/rename/delete flow. Keep them in the explicit recovery action above,
    -- but only auto-offer recovery for persistent Edit Mode control surfaces.
    local foreverEditModeAutoRecoveryNames = {
        EditModeSystemSettingsDialog = true,
    }

    local foreverEditModeTransactionalNames = {
        "EditModeLayoutDialog",
        "EditModeImportLayoutDialog",
        "EditModeImportLayoutLinkDialog",
        "EditModeUnsavedChangesDialog",
        "EditModeDialog",
    }

    local function CanRecoverForeverEditModeControls(metrics)
        return metrics and (metrics.isSpanned or IsForeverSingleScreenRecovery(metrics)) or false
    end

    -- Transactional dialogs no longer use this popup path, so the persistent
    -- manager/settings controls need only survive one fast recovery scan.
    local FOREVER_EDIT_MODE_RECOVERY_SETTLE_SECONDS = 0.15

    local function ClearForeverEditModeControlsCandidate(self)
        self.foreverEditModeControlsCandidate = nil
        self.foreverEditModeControlsCandidateConfirmed = nil
        self.foreverEditModeControlsCandidateGeneration =
            (self.foreverEditModeControlsCandidateGeneration or 0) + 1
    end

    local function CenterUnprotectedEditModeControl(frame, metrics)
        if not frame or not frame.IsShown or not frame:IsShown()
            or (frame.IsForbidden and frame:IsForbidden())
            or (frame.IsProtected and frame:IsProtected())
            or FrameFitsPhysicalDisplay(frame, metrics) then return false end
        local parentScale = (UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
        local frameScale = (frame.GetEffectiveScale and frame:GetEffectiveScale()) or parentScale
        local factor = parentScale / frameScale
        local centerX = (metrics.gameLeft + metrics.gameRight) / 2
        local centerY = (metrics.gameBottom + metrics.gameTop) / 2
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER",
            (centerX - UIParent:GetWidth() / 2) * factor,
            (centerY - UIParent:GetHeight() / 2) * factor)
        return true
    end

    -- Save, rename, import, and delete dialogs are ordinary unprotected control
    -- surfaces on Forever. Keep their recovery non-modal: while Edit Mode is open,
    -- center only a visible dialog that is genuinely outside both displays. Never
    -- hook Blizzard frames or touch protected HUD systems.
    function HUD:RecoverForeverTransactionalEditModeDialogs(metrics)
        if not HasBlizzardEditMode() or InCombatLockdown()
            or not Offhand.db or not Offhand.db.enabled then return 0 end
        local manager = _G.EditModeManagerFrame
        if not manager or not manager.IsShown or not manager:IsShown() then return 0 end
        metrics = metrics or (Offhand.Viewport and Offhand.Viewport.GetMetrics
            and Offhand.Viewport:GetMetrics())
        if not CanRecoverForeverEditModeControls(metrics) then return 0 end
        local moved = 0
        for _, name in ipairs(foreverEditModeTransactionalNames) do
            local ok, changed = pcall(CenterUnprotectedEditModeControl, _G[name], metrics)
            if ok and changed then moved = moved + 1 end
        end
        return moved
    end

    -- Blizzard can anchor its Edit Mode manager outside the physical displays on a
    -- mixed-height span. This occurs on Retail as well as Forever. Detection stays
    -- read-only until a candidate survives native layout settlement. Only known
    -- unprotected controls can then be rescued; the preference retains the manual
    -- recovery prompt for players who disable automatic recovery.
    function HUD:UpdateForeverEditModeControlsRecovery(metrics)
        if not HasBlizzardEditMode() or not Offhand.db or not Offhand.db.enabled then return end
        local manager = _G.EditModeManagerFrame
        local shown = manager and manager.IsShown and manager:IsShown()
        if not shown then
            if self.foreverEditModeManagerWasShown and Offhand.HideForeverEditModeControlsPrompt then
                Offhand:HideForeverEditModeControlsPrompt()
            end
            self.foreverEditModeManagerWasShown = nil
            self.foreverEditModeControlsPromptShown = nil
            self.foreverEditModeControlsPromptDeclined = nil
            self.foreverEditModeOutsideControl = nil
            ClearForeverEditModeControlsCandidate(self)
            return
        end

        if not self.foreverEditModeManagerWasShown then
            self.foreverEditModeManagerWasShown = true
            self.foreverEditModeControlsPromptShown = nil
            self.foreverEditModeControlsPromptDeclined = nil
            ClearForeverEditModeControlsCandidate(self)
        end
        if InCombatLockdown() then return end
        metrics = metrics or (Offhand.Viewport and Offhand.Viewport.GetMetrics and Offhand.Viewport:GetMetrics())
        -- A stale spanned layout can strand the manager or its settings dialog
        -- after the Companion restores WoW to one display. That recovery state is
        -- as actionable as the mixed-height span. Controls still pass the same
        -- physical-display, settlement and protected-frame checks before rescue.
        if not CanRecoverForeverEditModeControls(metrics) then
            ClearForeverEditModeControlsCandidate(self)
            return
        end
        self:RecoverForeverTransactionalEditModeDialogs(metrics)

        -- The manager toolbar can be fully visible while the separate settings
        -- dialog opened for a selected HUD element is mostly in the mixed-height
        -- void. Transactional dialogs were handled separately above; protected
        -- HUD systems are never moved by control recovery.
        local outsideControl
        local visibleDialog
        for _, name in ipairs(foreverEditModeControlNames) do
            local frame = _G[name]
            if frame and frame.IsShown and frame:IsShown() then
                visibleDialog = frame
                if foreverEditModeAutoRecoveryNames[name]
                    and not FrameFitsPhysicalDisplay(frame, metrics) then
                    outsideControl = frame
                    break
                end
            end
        end
        -- A reachable Blizzard modal should have exclusive focus. Defer recovery
        -- of an off-screen manager until that save/rename/delete dialog closes;
        -- an off-screen modal itself still takes priority and remains recoverable.
        if not outsideControl and not visibleDialog
            and not FrameFitsPhysicalDisplay(manager, metrics) then
            outsideControl = manager
        end
        if not outsideControl then
            -- Blizzard can finish centering a modal after the scan that raised our
            -- recovery prompt. Dismiss that now-stale prompt so it never obscures
            -- a reachable save/rename/delete dialog. Clearing the decline marker
            -- also lets a later reuse of EditModeLayoutDialog be recovered.
            if self.foreverEditModeControlsPromptShown
                and Offhand.HideForeverEditModeControlsPrompt then
                Offhand:HideForeverEditModeControlsPrompt()
            end
            self.foreverEditModeControlsPromptShown = nil
            self.foreverEditModeControlsPromptDeclined = nil
            self.foreverEditModeOutsideControl = nil
            ClearForeverEditModeControlsCandidate(self)
            return
        end
        if self.foreverEditModeOutsideControl ~= outsideControl then
            if self.foreverEditModeControlsPromptShown
                and Offhand.HideForeverEditModeControlsPrompt then
                Offhand:HideForeverEditModeControlsPrompt()
            end
            self.foreverEditModeControlsPromptShown = nil
            self.foreverEditModeControlsPromptDeclined = nil
            self.foreverEditModeOutsideControl = outsideControl
            ClearForeverEditModeControlsCandidate(self)
        end
        if self.foreverEditModeControlsPromptShown or self.foreverEditModeControlsPromptDeclined then return end

        -- EditModeLayoutDialog briefly inherits its old/off-screen anchor while
        -- Blizzard changes between save, rename, and delete modes. Wait for that
        -- native positioning pass to settle before offering recovery. This avoids
        -- a one-second popup flash without hooking or writing protected UI.
        if self.foreverEditModeControlsCandidate ~= outsideControl then
            self.foreverEditModeControlsCandidate = outsideControl
            self.foreverEditModeControlsCandidateConfirmed = nil
            self.foreverEditModeControlsCandidateGeneration =
                (self.foreverEditModeControlsCandidateGeneration or 0) + 1
            local generation = self.foreverEditModeControlsCandidateGeneration
            if C_Timer and C_Timer.After then
                C_Timer.After(FOREVER_EDIT_MODE_RECOVERY_SETTLE_SECONDS, function()
                    if HUD.foreverEditModeControlsCandidateGeneration ~= generation
                        or HUD.foreverEditModeControlsCandidate ~= outsideControl then return end
                    HUD.foreverEditModeControlsCandidateConfirmed = outsideControl
                    HUD:UpdateForeverEditModeControlsRecovery()
                end)
                return
            end
            self.foreverEditModeControlsCandidateConfirmed = outsideControl
        end
        if self.foreverEditModeControlsCandidateConfirmed ~= outsideControl then return end
        if Offhand.db.autoRecoverEditModeControls ~= false then
            local ok, moved = pcall(CenterUnprotectedEditModeControl, outsideControl, metrics)
            if ok and moved then
                if Offhand.HideForeverEditModeControlsPrompt then
                    Offhand:HideForeverEditModeControlsPrompt()
                end
                self.foreverEditModeControlsPromptShown = nil
                self.foreverEditModeControlsPromptDeclined = nil
                self.foreverEditModeOutsideControl = nil
                ClearForeverEditModeControlsCandidate(self)
                return
            end
        end
        ClearForeverEditModeControlsCandidate(self)
        self.foreverEditModeControlsPromptShown = true
        if Offhand.ShowForeverEditModeControlsPrompt then
            Offhand:ShowForeverEditModeControlsPrompt()
        end
    end

    -- Supported Blizzard clients accept these unprotected control-surface anchor
    -- changes from the recovery control's hardware click. Do not move Edit Mode
    -- systems, attach handlers, or alter Blizzard's panel metadata from this path.
    function HUD:BringForeverEditModeControlsToMainhand()
        if not HasBlizzardEditMode() or InCombatLockdown() then return false end
        local manager = _G.EditModeManagerFrame
        if not manager or not manager.IsShown or not manager:IsShown()
            or (manager.IsForbidden and manager:IsForbidden())
            or (manager.IsProtected and manager:IsProtected()) then return false end
        local metrics = Offhand.Viewport and Offhand.Viewport.GetMetrics
            and Offhand.Viewport:GetMetrics()
        if not CanRecoverForeverEditModeControls(metrics) then return false end

        local moved = false
        local function Recover(frame)
            if CenterUnprotectedEditModeControl(frame, metrics) then moved = true end
        end

        Recover(manager)
        for _, name in ipairs(foreverEditModeControlNames) do Recover(_G[name]) end
        if not moved then return false end
        self.foreverEditModeControlsPromptShown = nil
        self.foreverEditModeControlsPromptDeclined = nil
        self.foreverEditModeOutsideControl = nil
        ClearForeverEditModeControlsCandidate(self)
        return true
    end

    function HUD:DismissForeverEditModeControlsPrompt()
        self.foreverEditModeControlsPromptShown = nil
        self.foreverEditModeControlsPromptDeclined = true
        ClearForeverEditModeControlsCandidate(self)
    end

    local foreverPartyRaidRecoveryNames = {
        PartyFrame = true, PartyMemberFrame1 = true, CompactPartyFrame = true,
        CompactRaidFrameContainer = true,
    }

    local function FrameIsActuallyVisible(frame)
        if not frame then return false end
        local method = type(frame.IsVisible) == "function" and frame.IsVisible or frame.IsShown
        if type(method) ~= "function" then return false end
        local ok, visible = pcall(method, frame)
        return ok and visible == true
    end

    local function VisibleChildFitsPhysicalDisplay(frame, metrics, depth)
        if not frame or type(frame.GetChildren) ~= "function" or (depth or 0) > 2 then
            return false
        end
        local ok, children = pcall(function() return { frame:GetChildren() } end)
        if not ok or type(children) ~= "table" then return false end
        for _, child in ipairs(children) do
            if FrameIsActuallyVisible(child) then
                local dimensionsOK, width, height = pcall(function()
                    return child.GetWidth and child:GetWidth() or 0,
                        child.GetHeight and child:GetHeight() or 0
                end)
                if not dimensionsOK then width, height = 0, 0 end
                if width and height and width > 2 and height > 2
                    and FrameFitsPhysicalDisplay(child, metrics) then
                    return true
                end
                if VisibleChildFitsPhysicalDisplay(child, metrics, (depth or 0) + 1) then
                    return true
                end
            end
        end
        return false
    end

    -- Retail exposes overlapping PartyFrame/CompactPartyFrame ownership roots.
    -- A legacy or preview container can retain stale full-canvas bounds even while
    -- the actual visible member frames from the selected layout are correctly on
    -- Mainhand. Treat a reachable visible group presentation as authoritative so
    -- the stale alias cannot create an endless Repair HUD loop.
    local function RetailGroupPresentationFits(metrics)
        if UsesForeverEditMode() then return false end
        for name in pairs(foreverPartyRaidRecoveryNames) do
            local frame = _G[name]
            if FrameIsActuallyVisible(frame) and (FrameFitsPhysicalDisplay(frame, metrics)
                or VisibleChildFitsPhysicalDisplay(frame, metrics, 0)) then
                return true
            end
        end
        return false
    end

    -- Retail's MinimapCluster is another Edit Mode ownership container whose root
    -- can retain preview coordinates in mixed-height dead space. The actual
    -- Minimap child is the user-visible presentation, so its reachable bounds are
    -- authoritative. Unlike the status-bar proxies below, a genuinely unreachable
    -- minimap remains eligible for recovery.
    local function ProtectedHUDPresentationFits(name, frame, metrics)
        if name ~= "MinimapCluster" then return false end
        local minimap = _G.Minimap
        if FrameIsActuallyVisible(minimap) and (FrameFitsPhysicalDisplay(minimap, metrics)
            or VisibleChildFitsPhysicalDisplay(minimap, metrics, 0)) then
            return true
        end
        return VisibleChildFitsPhysicalDisplay(frame, metrics, 0)
    end

    -- Explicit roots for protected Edit Mode systems whose previews can expose an
    -- unreachable anchor. Keep this bounded: transient tooltips, loot popups and
    -- nameplates use separate positioning/scaling lifecycles and do not belong in
    -- protected-layout recovery.
    local foreverProtectedHUDRecoveryNames = {
        "PlayerFrame", "TargetFrame", "FocusFrame", "PetFrame", "BossTargetFrameContainer",
        "PartyFrame", "PartyMemberFrame1", "CompactPartyFrame", "CompactRaidFrameContainer",
        "MainMenuBar", "MainActionBar", "MultiBarBottomLeft", "MultiBarBottomRight",
        "MultiBarLeft", "MultiBarRight", "StanceBar", "PetActionBar", "PossessActionBar",
        "MinimapCluster", "StatusTrackingBarManager", "MainMenuExpBar",
        "BuffFrame", "BuffCluster", "CastingBarFrame", "PlayerCastingBarFrame",
        "ExtraAbilityContainer", "ExtraActionBarFrame", "ZoneAbilityFrame",
        "EncounterBar", "UIWidgetPowerBarContainerFrame", "LossOfControlFrame",
        "MainMenuBarVehicleLeaveButton", "VehicleExitButton", "TotemFrame",
        "MultiCastActionBarFrame", "PersonalResourceDisplayFrame",
        "EssentialCooldownViewer", "UtilityCooldownViewer", "BuffIconCooldownViewer",
        "DamageMeter", "DurabilityFrame", "RaidWarningFrame", "UIErrorsFrame",
    }

    -- These containers expose stale or synthetic preview bounds in Edit Mode even
    -- when their live XP/reputation bars are correctly placed. Rebuilding the same
    -- layout cannot change that ownership-root rectangle, so it must never trigger
    -- the automatic Repair HUD transaction.
    local unreliableProtectedHUDRecoveryNames = {
        StatusTrackingBarManager = true,
        MainMenuExpBar = true,
    }

    -- Mixed-height spans contain real UIParent space that is not backed by a
    -- physical monitor. Blizzard Edit Mode anchors can land there on Retail and
    -- Forever.
    -- Detect the condition without writing anchors and explain the player-click
    -- recovery once per occurrence.
    function HUD:UpdateForeverPartyFrameRecovery(metrics)
        if not HasBlizzardEditMode() or not Offhand.db or not Offhand.db.enabled then return end
        -- Blizzard's Gamepad UI owns these protected HUD systems and its Edit Mode
        -- preset. Inspecting the native frame tree during that focus/layout
        -- transaction can taint secret unit-frame values, and Offhand cannot repair
        -- the controller preset. Clear stale keyboard-mode recovery state instead.
        if UsesControllerInterface() then
            if self.foreverPartyFrameOutsideDisplays and Offhand.HideForeverPartyFrameRecoveryPrompt then
                Offhand:HideForeverPartyFrameRecoveryPrompt()
            end
            self.foreverPartyFrameOutsideDisplays = nil
            self.foreverProtectedHUDDetectedInEditMode = nil
            self.foreverPartyFrameRecoveryPromptShown = nil
            self.foreverPartyFrameRecoveryPromptDeclined = nil
            return
        end
        metrics = metrics or (Offhand.Viewport and Offhand.Viewport.GetMetrics
            and Offhand.Viewport:GetMetrics())
        if not metrics or not metrics.isSpanned then
            if self.foreverPartyFrameOutsideDisplays and Offhand.HideForeverPartyFrameRecoveryPrompt then
                Offhand:HideForeverPartyFrameRecoveryPrompt()
            end
            self.foreverPartyFrameOutsideDisplays = nil
            self.foreverProtectedHUDDetectedInEditMode = nil
            self.foreverPartyFrameRecoveryPromptShown = nil
            self.foreverPartyFrameRecoveryPromptDeclined = nil
            return
        end
        if InCombatLockdown() then return end

        local manager = _G.EditModeManagerFrame
        local editModeOpen = manager and manager.IsShown and manager:IsShown() or false
        local outsideName
        if editModeOpen then
            -- Blizzard retains several dormant ownership roots with stale bounds.
            -- They are not evidence of a lost HUD frame during ordinary play. Only
            -- inspect them while Edit Mode is actively presenting the corresponding
            -- systems, then remember that observed candidate until Edit Mode closes.
            for _, name in ipairs(foreverProtectedHUDRecoveryNames) do
                local frame = _G[name]
                local customPartyFrames = foreverPartyRaidRecoveryNames[name] and HasEllesmerePartyFrames()
                local groupPresentationFits = foreverPartyRaidRecoveryNames[name]
                    and RetailGroupPresentationFits(metrics)
                local protectedPresentationFits = ProtectedHUDPresentationFits(name, frame, metrics)
                if not unreliableProtectedHUDRecoveryNames[name]
                    and not customPartyFrames and not groupPresentationFits
                    and not protectedPresentationFits
                    and FrameIsActuallyVisible(frame)
                    and not FrameFitsPhysicalDisplay(frame, metrics) then
                    outsideName = name
                    break
                end
            end
        else
            -- Party/Raid previews can become hidden as soon as Edit Mode closes.
            -- Retain a candidate observed while Edit Mode was open long enough to
            -- offer the repair after Blizzard's layout transaction has finished.
            if self.foreverProtectedHUDDetectedInEditMode
                and self.foreverPartyFrameOutsideDisplays then
                outsideName = self.foreverPartyFrameOutsideDisplays
            end
        end

        if not outsideName then
            if self.foreverPartyFrameOutsideDisplays and Offhand.HideForeverPartyFrameRecoveryPrompt then
                Offhand:HideForeverPartyFrameRecoveryPrompt()
            end
            self.foreverPartyFrameOutsideDisplays = nil
            self.foreverProtectedHUDDetectedInEditMode = nil
            self.foreverPartyFrameRecoveryPromptShown = nil
            self.foreverPartyFrameRecoveryPromptDeclined = nil
            return
        end
        self.foreverPartyFrameOutsideDisplays = outsideName
        if editModeOpen then
            self.foreverProtectedHUDDetectedInEditMode = true
            return
        end
        if self.foreverPartyFrameRecoveryPromptShown
            or self.foreverPartyFrameRecoveryPromptDeclined then return end
        self.foreverPartyFrameRecoveryPromptShown = true
        if Offhand.ShowForeverPartyFrameRecoveryPrompt then
            Offhand:ShowForeverPartyFrameRecoveryPrompt(outsideName)
        end
    end

    function HUD:DismissForeverPartyFrameRecoveryPrompt()
        self.foreverPartyFrameRecoveryPromptShown = nil
        self.foreverPartyFrameRecoveryPromptDeclined = true
        self.foreverProtectedHUDDetectedInEditMode = nil
    end

    -- Protected HUD frames cannot be reanchored safely. The recovery popup is a
    -- hardware click, so use the same Blizzard Edit Mode layout transaction as the
    -- setup wizard, then let Blizzard apply the protected anchors during reload.
    function HUD:RepairProtectedHUDLayout()
        if InCombatLockdown() then
            self.foreverPartyFrameRecoveryPromptShown = nil
            return false, "combat"
        end
        if UsesControllerInterface() then
            self:DismissForeverPartyFrameRecoveryPrompt()
            return false, "gamepad"
        end
        local manager = _G.EditModeManagerFrame
        if manager and ((manager.IsShown and manager:IsShown()) or manager.editModeActive) then
            self.foreverPartyFrameRecoveryPromptShown = nil
            return false, "open"
        end
        local mainhand = Offhand.Mainhand
        if not mainhand or type(mainhand.CreateOrUpdateEditModeLayout) ~= "function" then
            self:DismissForeverPartyFrameRecoveryPrompt()
            return false, "unavailable"
        end

        local candidate = self.foreverPartyFrameOutsideDisplays
        local ok, value, moved = mainhand:CreateOrUpdateEditModeLayout({
            repairFrameName = candidate,
        })
        if not ok then
            if value == "combat" or value == "open" then
                self.foreverPartyFrameRecoveryPromptShown = nil
            else
                self:DismissForeverPartyFrameRecoveryPrompt()
            end
            return false, value
        end

        self:DismissForeverPartyFrameRecoveryPrompt()
        if mainhand.PromptReload then mainhand:PromptReload() end
        return true, value, moved
    end

    -- Read-only evidence for reports where protected group frames appear in Edit
    -- Mode but not during play. Blizzard intentionally hides these frames while
    -- solo, so diagnostics must distinguish native visibility from an unreachable
    -- anchor before recommending recovery.
    function HUD:GetForeverGroupFrameDiagnostics()
        if not HasBlizzardEditMode() then return nil end
        local grouped = type(IsInGroup) == "function" and IsInGroup() or false
        local raiding = type(IsInRaid) == "function" and IsInRaid() or false
        local manager = _G.EditModeManagerFrame
        local editModeOpen = manager and manager.IsShown and manager:IsShown() or false
        local states = {}
        for _, name in ipairs({"PartyFrame", "PartyMemberFrame1", "CompactPartyFrame", "CompactRaidFrameContainer"}) do
            local frame = _G[name]
            if not frame then
                states[#states + 1] = name .. "=missing"
            else
                local shown = false
                if frame.IsShown then
                    local ok, value = pcall(frame.IsShown, frame)
                    shown = ok and value or false
                end
                local bounds = "unresolved"
                if frame.GetLeft and frame.GetBottom and frame.GetRight and frame.GetTop then
                    local ok, left, bottom, right, top = pcall(function()
                        return frame:GetLeft(), frame:GetBottom(), frame:GetRight(), frame:GetTop()
                    end)
                    if ok and left and bottom and right and top then
                        bounds = string.format("%.0f,%.0f-%.0f,%.0f", left, bottom, right, top)
                    end
                end
                states[#states + 1] = string.format("%s=%s@%s", name,
                    shown and "shown" or "hidden", bounds)
            end
        end
        return string.format("Group=%s | Raid=%s | EditMode=%s | %s",
            grouped and "yes" or "no", raiding and "yes" or "no",
            editModeOpen and "open" or "closed", table.concat(states, ","))
    end

    function HUD:GetForeverProtectedHUDDiagnostics(metrics)
        if not HasBlizzardEditMode() then return nil end
        metrics = metrics or (Offhand.Viewport and Offhand.Viewport.GetMetrics
            and Offhand.Viewport:GetMetrics())
        local manager = _G.EditModeManagerFrame
        local editModeOpen = manager and manager.IsShown and manager:IsShown() or false
        local visible, outside = 0, {}
        for _, name in ipairs(foreverProtectedHUDRecoveryNames) do
            local frame = _G[name]
            if FrameIsActuallyVisible(frame) then
                visible = visible + 1
                local groupPresentationFits = foreverPartyRaidRecoveryNames[name]
                    and RetailGroupPresentationFits(metrics)
                local protectedPresentationFits = ProtectedHUDPresentationFits(name, frame, metrics)
                if editModeOpen and metrics and not unreliableProtectedHUDRecoveryNames[name]
                    and not groupPresentationFits and not protectedPresentationFits
                    and not FrameFitsPhysicalDisplay(frame, metrics) then
                    outside[#outside + 1] = name
                end
            end
        end
        return string.format("EditMode=%s | Visible=%d | Outside=%s | Candidate=%s",
            editModeOpen and "open" or "closed", visible,
            editModeOpen and (#outside > 0 and table.concat(outside, ",") or "none")
                or "not-scanned",
            tostring(self.foreverPartyFrameOutsideDisplays or "none"))
    end

    return {
        GetEditModeLayouts = GetEditModeLayouts,
        EditModeLayoutNamesMatch = EditModeLayoutNamesMatch,
        GetActiveEditModeLayoutName = GetActiveEditModeLayoutName,
        GetEditModeCustomLayoutOffset = GetEditModeCustomLayoutOffset,
        RememberCharacterEditModeLayout = RememberCharacterEditModeLayout,
        HookCharacterEditModeSelection = HookCharacterEditModeSelection,
        PrepareForeverEditModeState = PrepareForeverEditModeState,
    }
end

