-- A character's HUD check is separate from account installation and profiles.
local _, Offhand = ...
local Setup = {}
Offhand.CharacterSetup = Setup

local function Context()
    local mainhand = Offhand.Mainhand
    local geometry = mainhand and mainhand.GetGeometrySignature and mainhand:GetGeometrySignature()
    if type(geometry) ~= "string" or geometry == "" then return nil end
    return geometry, Offhand.IsGamepadUIEnabled and Offhand:IsGamepadUIEnabled() == true or false
end

local function SaveCharacterSetupSnapshot()
    if Offhand.isForever and Offhand.ForeverPersistence
        and Offhand.ForeverPersistence.SaveProfileSnapshot then
        Offhand.ForeverPersistence:SaveProfileSnapshot(true)
    end
end

local function SaveChoice(choice, complete)
    if type(OffhandCharDB) ~= "table" then return false end
    local geometry, gamepad = Context()
    if not geometry then return false end
    OffhandCharDB.characterSetup = {
        version = 1, choice = choice, complete = complete == true,
        geometrySignature = geometry, gamepad = gamepad,
    }
    if choice == "later" then
        OffhandCharDB.hudSetupReminder = nil
        OffhandCharDB.hudSetupReminderDeclined = true
    else
        OffhandCharDB.hudSetupReminderDeclined = nil
        if complete then OffhandCharDB.hudSetupReminder = nil
        else OffhandCharDB.hudSetupReminder = true end
    end
    SaveCharacterSetupSnapshot()
    return true
end

function Setup:InitializePopups(statusKey)
    local L = Offhand.L
    if statusKey == "CHARACTER_SETUP_WAITING_FOR_SPAN" then
        StaticPopupDialogs.OFFHAND_CHARACTER_SETUP = {
            text = "%s",
            button1 = L.POPUP_BTN_GOT_IT,
            button2 = L.CHARACTER_SETUP_HIDE_SPAN_NOTICE,
            OnAccept = function() Setup.spanNoticeDismissed = true end,
            OnCancel = function(_, _, reason)
                if reason == "clicked" and type(OffhandCharDB) == "table" then
                    OffhandCharDB.hudSpanNoticeDismissed = true
                    SaveCharacterSetupSnapshot()
                end
            end,
            OnHide = function() Setup.shown = nil end,
            timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
        }
        return
    end
    local review = statusKey == "CHARACTER_SETUP_ELLESMERE"
    local refresh = statusKey == "CHARACTER_SETUP_REFRESH"
    local offerReuse = not review and not refresh and statusKey ~= "CHARACTER_SETUP_NO_LAYOUT"
    local function Customize()
        if InCombatLockdown and InCombatLockdown() then
            Setup:Show("CHARACTER_SETUP_RETRY")
            return
        end
        if Offhand.Wizard and Offhand.Wizard.OpenHUDSetup then
            SaveChoice("customize", false)
            Offhand.Wizard:OpenHUDSetup(review)
        else
            Setup:Show("CHARACTER_SETUP_RETRY")
        end
    end
    StaticPopupDialogs.OFFHAND_CHARACTER_SETUP = {
        text = review and L.CHARACTER_SETUP_ELLESMERE or L.CHARACTER_SETUP_TEXT,
        button1 = review and L.CHARACTER_SETUP_REVIEW or refresh and L.CHARACTER_SETUP_REFRESH_BUTTON
            or offerReuse and L.CHARACTER_SETUP_USE or L.CHARACTER_SETUP_CUSTOMIZE,
        button2 = L.CHARACTER_SETUP_LATER,
        button3 = offerReuse and L.CHARACTER_SETUP_CUSTOMIZE or nil,
        OnAccept = offerReuse and function() Setup:UseExisting() end or Customize,
        OnCancel = function(_, _, reason)
            if reason == "clicked" then SaveChoice("later", true) end
        end,
        OnAlt = offerReuse and Customize or nil,
        OnHide = function() Setup.shown = nil end,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }
end

function Setup:Show(statusKey)
    if Offhand.IsBlizzardInputReserved and Offhand:IsBlizzardInputReserved() then
        Offhand:DeferAutomaticUIForCinematic()
        return false
    end
    if InCombatLockdown and InCombatLockdown() then
        self.pendingCombat, self.offeredContext = true, nil
        return false
    end
    self:InitializePopups(statusKey)
    self.shown = Offhand:ShowPopup("OFFHAND_CHARACTER_SETUP", Offhand.L[statusKey]) and statusKey or nil
    return self.shown ~= nil
end

function Setup:Hide()
    Offhand:HidePopup("OFFHAND_CHARACTER_SETUP")
    self.shown = nil
    self.offeredContext = nil
end

function Setup:UseExisting()
    if not Offhand.db or not Offhand.db.enabled
        or (Offhand.IsBlizzardInputReserved and Offhand:IsBlizzardInputReserved()) then
        return false
    end
    local mainhand = Offhand.Mainhand
    local ok, layoutName, moved, changed
    if mainhand and mainhand.UseExistingEditModeLayout then
        ok, layoutName, moved, changed = mainhand:UseExistingEditModeLayout()
    end
    if not ok then
        local blocked = layoutName == "combat" or layoutName == "open" or layoutName == "input"
        self:Show(blocked and "CHARACTER_SETUP_RETRY"
            or layoutName == "review" and "CHARACTER_SETUP_ELLESMERE"
            or layoutName == "ownership" and "CHARACTER_SETUP_REFRESH"
            or "CHARACTER_SETUP_NO_LAYOUT")
        return false
    end
    SaveChoice("existing", true)
    Offhand:Print(Offhand.L.CHARACTER_SETUP_REUSED)
    if changed and mainhand.PromptReload then mainhand:PromptReload() end
    return true
end

function Setup:Refresh()
    self.pendingCombat = nil
    if not Offhand.db or not Offhand.db.enabled or type(OffhandCharDB) ~= "table"
        or not Offhand.IsSetupComplete or not Offhand:IsSetupComplete()
        or not Offhand.HasBlizzardEditMode or not Offhand:HasBlizzardEditMode() then return false end
    local mainhand = Offhand.Mainhand
    if not mainhand or not mainhand.GetCharacterSetupLayoutStatus then return false end
    local geometry, gamepad = Context()
    if not geometry then return false end
    local record = OffhandCharDB.characterSetup
    if type(record) ~= "table" or record.version ~= 1 then record = nil end
    local sameContext = record and record.geometrySignature == geometry and record.gamepad == gamepad
    if sameContext and record.choice == "later" then return true end
    if not record and OffhandCharDB.hudSetupReminderDeclined then return true end
    local pending = record ~= nil or OffhandCharDB.hudSetupReminder or OffhandCharDB.mainhandLayoutDeferred
    local transfer = Offhand.EllesmereLayout
    local canReview = transfer and transfer.ShowPreview and transfer.IsAvailable and transfer:IsAvailable()
    if not pending and not canReview then return false end
    local metrics = Offhand.Viewport and Offhand.Viewport:GetMetrics()
    if not metrics or Offhand._displayGeometryTransitionActive then return true end
    if InCombatLockdown and InCombatLockdown() then self.pendingCombat = true; return true end
    if Offhand.IsBlizzardInputReserved and Offhand:IsBlizzardInputReserved() then
        Offhand:DeferAutomaticUIForCinematic()
        return true
    end
    if not metrics.isSpanned then
        if not record and OffhandCharDB.hudSetupReminder and not OffhandCharDB.hudSpanNoticeDismissed
            and not self.spanNoticeDismissed
            and self.shown ~= "CHARACTER_SETUP_WAITING_FOR_SPAN" then
            self:Show("CHARACTER_SETUP_WAITING_FOR_SPAN")
        end
        return pending and true or false
    end
    if self.shown == "CHARACTER_SETUP_WAITING_FOR_SPAN" then self:Hide() end
    local status = mainhand:GetCharacterSetupLayoutStatus()
    local review = canReview and status.ellesmereReview
    if not pending and not review then return false end
    if status.reason == "open" or status.reason == "gamepad" then return true end
    if status.ready then
        if record and (not record.complete or not sameContext) then SaveChoice(record.choice, true) end
        if self.shown then self:Hide() end
        return true
    end
    local identity = tostring(OffhandCharDB.characterGUID or "") .. "|" .. geometry .. "|" .. tostring(gamepad)
    if self.offeredContext == identity then return true end
    self.offeredContext = identity
    return self:Show(review and "CHARACTER_SETUP_ELLESMERE"
        or (status.reason == "ownership" or status.ellesmereReview) and "CHARACTER_SETUP_REFRESH"
        or status.available and "CHARACTER_SETUP_READY" or "CHARACTER_SETUP_NO_LAYOUT")
end
