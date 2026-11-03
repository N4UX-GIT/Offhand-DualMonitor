--[[
    Offhand: Multi-Monitor Setup Addon
    Core/Init.lua: Addon initialization, namespace, event dispatcher, and combat-safe queue
--]]

local addonName, Offhand = ...
_G.Offhand = Offhand

-- Forever's binding UI resolves a binding header through HEADER_<token>,
-- while other clients use BINDING_HEADER_<token>. Bindings.xml is discovered
-- independently of the TOC, so establish a stable brand label before the
-- localized Options module refreshes both globals later in addon loading.
_G.HEADER_OFFHAND = _G.HEADER_OFFHAND or "Offhand"
_G.BINDING_HEADER_OFFHAND = _G.BINDING_HEADER_OFFHAND or "Offhand"

Offhand.name = addonName
local getMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
Offhand.version = (getMetadata and getMetadata(addonName, "Version")) or "1.0.0"
-- Public addon release identity and Companion compatibility are independent.
-- Addon-only releases may advance X-Offhand-Release while keeping the same
-- Companion protocol and minimum version.
Offhand.companionVersion = (getMetadata and getMetadata(addonName, "X-Offhand-Companion-Version"))
    or Offhand.version
Offhand.companionProtocol = tonumber(
    (getMetadata and getMetadata(addonName, "X-Offhand-Companion-Protocol")) or "")
Offhand.companionMinVersion =
    (getMetadata and getMetadata(addonName, "X-Offhand-Companion-Min-Version")) or ""
Offhand.companionRelease = (getMetadata and getMetadata(addonName, "X-Offhand-Companion-Release"))
    or ""
Offhand.release = (getMetadata and getMetadata(addonName, "X-Offhand-Release"))
    or (getMetadata and getMetadata(addonName, "X-Offhand-Addon-Release")) or ""
local betaNumber = Offhand.release:match("^beta%.(%d+)$")
Offhand.releaseDisplay = betaNumber and ("Beta " .. betaNumber) or Offhand.release
Offhand.fullVersion = Offhand.version .. (Offhand.release ~= "" and ("-" .. Offhand.release) or "")
local companionBetaNumber = Offhand.companionRelease:match("^beta%.(%d+)$")
Offhand.companionReleaseDisplay = companionBetaNumber
    and ("Beta " .. companionBetaNumber) or Offhand.companionRelease
Offhand.companionFullVersion = Offhand.companionVersion
    .. (Offhand.companionRelease ~= "" and ("-" .. Offhand.companionRelease) or "")
Offhand.companionVersionDisplay = "v" .. Offhand.companionVersion
    .. (Offhand.companionReleaseDisplay ~= "" and (" " .. Offhand.companionReleaseDisplay) or "")
local companionArchiveName = Offhand.companionFullVersion == "2.1.2-beta.20"
    and "Offhand-Companion.zip"
    or ("Offhand-Companion-v" .. Offhand.companionFullVersion .. ".zip")
Offhand.companionStoreUrl = "https://apps.microsoft.com/detail/9PL4PW84Q90W"
Offhand.companionPortableDownloadUrl = "https://github.com/N4UX-GIT/Offhand-DualMonitor/releases/download/v"
    .. Offhand.companionFullVersion .. "/" .. companionArchiveName
-- Player-facing setup actions recommend the signed, managed Store package.
-- Keep the versioned GitHub URL above for portable and Linux/Wine guidance.
Offhand.companionDownloadUrl = Offhand.companionStoreUrl
-- The addon only links to Microsoft's documentation. It does not inspect or
-- depend on PowerToys; FancyZones is one optional way to place the WoW window.
Offhand.powerToysDownloadUrl = "https://aka.ms/getPowerToys"
Offhand.modules = {}
Offhand.callbacks = {}

-- Initialize L table early
Offhand.L = Offhand.L or setmetatable({}, { __index = function(t, key) return key end })

-- Client flavor detection
local clientVersion, clientBuild, clientBuildDate, tocVersion = GetBuildInfo()
Offhand.clientVersion = tostring(clientVersion or "unknown")
Offhand.clientBuild = tostring(clientBuild or "unknown")
Offhand.clientBuildDate = tostring(clientBuildDate or "unknown")
Offhand.tocVersion = tocVersion
Offhand.isLegacyWrath = tocVersion >= 30000 and tocVersion < 30400
local hasProjectIdentity = WOW_PROJECT_ID ~= nil
Offhand.isClassicEra = (hasProjectIdentity and WOW_PROJECT_CLASSIC ~= nil
    and WOW_PROJECT_ID == WOW_PROJECT_CLASSIC) or Offhand.isLegacyWrath
Offhand.isRetail = hasProjectIdentity and WOW_PROJECT_MAINLINE ~= nil
    and WOW_PROJECT_ID == WOW_PROJECT_MAINLINE or false
-- Forever uses a distinct interface branch, but Edit Mode ownership itself is
-- capability-detected below because Retail, Classic and Anniversary expose
-- different subsets and load timing.
Offhand.isForever = tocVersion >= 16000 and tocVersion < 17000

-- SavedVariables are available before addon files execute. Preserve the exact
-- tables the client loaded before ForeverState.lua runs: older Companion
-- snapshots assigned their bridge tables unconditionally, which could replace
-- newer same-session changes on /reload. Config chooses between these captured
-- disk tables and a genuinely new cold-start bridge snapshot.
if Offhand.isForever then
    Offhand.foreverDiskSavedVariables = {
        account = OffhandDB,
        character = OffhandCharDB,
    }
end

-- Formatted chat printing
local function FormatChatMessage(msg, ...)
    local count = select("#", ...)
    if count == 0 then return msg end
    local args = {...}
    -- Read-only diagnostics routinely encounter unavailable client CVars. A
    -- missing optional value must not abort the rest of /offhand diag.
    for index = 1, count do
        if args[index] == nil then args[index] = "unavailable" end
    end
    local ok, formatted = pcall(string.format, msg, unpack(args, 1, count))
    return ok and formatted or tostring(msg) .. " [format unavailable]"
end

function Offhand:Print(msg, ...)
    msg = FormatChatMessage(msg, ...)
    local frame = DEFAULT_CHAT_FRAME or (ChatFrame1 and ChatFrame1:IsShown() and ChatFrame1)
    if frame then
        frame:AddMessage("|cff00e5ff[Offhand]|r " .. tostring(msg))
    end
end

function Offhand:Debug(msg, ...)
    local db = (OffhandDB or OffhandDB)
    if db and db.debugMode then
        msg = FormatChatMessage(msg, ...)
        local frame = DEFAULT_CHAT_FRAME or (ChatFrame1 and ChatFrame1:IsShown() and ChatFrame1)
        if frame then
            frame:AddMessage("|cff888888[Offhand Debug]|r " .. tostring(msg))
        end
    end
end

-- Localization table with embedded English baseline
local L = Offhand.L or setmetatable({}, {
    __index = function(t, key)
        return key
    end
})
Offhand.L = L


-- ============================================================================
-- Color Picker Helper
-- ============================================================================
function Offhand:OpenColorPicker(initialR, initialG, initialB, initialA, hasOpacity, onColorChanged)
    if not ColorPickerFrame then return end

    local function ColorCallback(restore)
        local newR, newG, newB, newA
        if restore then
            newR, newG, newB, newA = restore.r, restore.g, restore.b, restore.opacity
        else
            if ColorPickerFrame.GetColorRGB then
                newR, newG, newB = ColorPickerFrame:GetColorRGB()
            else
                newR, newG, newB = initialR, initialG, initialB
            end
            if hasOpacity then
                local opVal = (OpacitySliderFrame and OpacitySliderFrame.GetValue and OpacitySliderFrame:GetValue()) or 0
                newA = 1 - opVal
            else
                newA = initialA or 1.0
            end
        end
        if onColorChanged then
            onColorChanged(newR, newG, newB, newA)
        end
    end

    if ColorPickerFrame.SetupColorPickerAndShow then
        local info = {
            swatchFunc = function() ColorCallback() end,
            opacityFunc = function() ColorCallback() end,
            cancelFunc = function(restore) ColorCallback(restore) end,
            hasOpacity = hasOpacity or false,
            opacity = hasOpacity and (1 - (initialA or 1.0)) or 0,
            r = initialR or 1.0,
            g = initialG or 1.0,
            b = initialB or 1.0,
        }
        ColorPickerFrame:SetupColorPickerAndShow(info)
    else
        ColorPickerFrame.hasOpacity = hasOpacity or false
        ColorPickerFrame.opacity = hasOpacity and (1 - (initialA or 1.0)) or 0
        ColorPickerFrame.previousValues = {
            r = initialR or 1.0,
            g = initialG or 1.0,
            b = initialB or 1.0,
            opacity = initialA or 1.0,
        }
        ColorPickerFrame.func = function() ColorCallback() end
        ColorPickerFrame.opacityFunc = function() ColorCallback() end
        ColorPickerFrame.cancelFunc = function(restore) ColorCallback(restore) end
        if ColorPickerFrame.SetColorRGB then
            ColorPickerFrame:SetColorRGB(initialR or 1.0, initialG or 1.0, initialB or 1.0)
        end
        ColorPickerFrame:Hide()
        ColorPickerFrame:Show()
    end
end

-- ============================================================================
-- Universal Tooltip Helper
-- ============================================================================
function Offhand:SetTooltip(frame, title, text, anchor)
    if not frame then return end
    if not (title or text) then return end
    if frame.EnableMouse then frame:EnableMouse(true) end

    local oldEnter = frame.GetScript and frame:GetScript("OnEnter")
    local oldLeave = frame.GetScript and frame:GetScript("OnLeave")

    frame:SetScript("OnEnter", function(self, ...)
        if oldEnter then pcall(oldEnter, self, ...) end
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, anchor or "ANCHOR_RIGHT")
        if title and title ~= "" then
            GameTooltip:AddLine(title, 1.0, 0.82, 0.0, true)
        end
        if text and text ~= "" then
            GameTooltip:AddLine(text, 1.0, 1.0, 1.0, true)
        end
        GameTooltip:Show()
    end)

    frame:SetScript("OnLeave", function(self, ...)
        if oldLeave then pcall(oldLeave, self, ...) end
        if GameTooltip and GameTooltip:GetOwner() == self then
            GameTooltip:Hide()
        end
    end)
end

-- ============================================================================
-- Combat-Safe Queue System
-- Modifying protected frames or layout during InCombatLockdown causes Lua errors.
-- We safely queue modifications until PLAYER_REGEN_ENABLED.
-- ============================================================================
local combatQueue = {}

function Offhand:RunOrQueueCombat(action, ...)
    if not InCombatLockdown() then
        action(...)
    else
        table.insert(combatQueue, { func = action, args = { ... } })
        Offhand:Debug("Action queued for post-combat execution.")
    end
end

local function ProcessCombatQueue()
    if #combatQueue == 0 then return end
    Offhand:Debug("Processing %d combat-queued actions...", #combatQueue)
    local queueCopy = combatQueue
    combatQueue = {}
    for _, item in ipairs(queueCopy) do
        local success, err = pcall(item.func, unpack(item.args))
        if not success then
            Offhand:Print("|cffff3333Queue Execution Error:|r %s", tostring(err))
        end
    end
end

-- ============================================================================
-- Core Event Dispatcher
-- ============================================================================

-- Popup definitions are created before locale files run because Init.lua owns
-- the addon namespace. Keep a small English safety net so a partial/manual
-- installation with stale locale files never exposes localization identifiers
-- such as POPUP_COMPANION_VERSION_TEXT to the player.
local companionPopupFallbacks = {
    POPUP_COMPANION_HANDOFF_TEXT = "|cffffd100Offhand could not confirm the current display span.|r\n\nOpen Companion, select your displays and Mainhand monitor, then click Span WoW Now. If WoW was already running, type /reload once afterward.",
    POPUP_COMPANION_TOPOLOGY_TEXT = "|cffffd100The saved display layout no longer matches this WoW window.|r\n\nOpen Companion, confirm the selected displays and Mainhand monitor, then click Span WoW Now. If WoW was already running, type /reload once afterward.",
    POPUP_COMPANION_VERSION_TEXT = "|cffffd100Companion version mismatch|r\n\nThis display layout was created by Companion %s, but this addon requires %s. Update Companion, span WoW again, and type /reload.\n\nCopy the official download address below:",
    POPUP_BTN_GOT_IT = "Got it",
}

local function CompanionPopupLocale(key)
    local value = Offhand.L and Offhand.L[key]
    if type(value) ~= "string" or value == "" or value == key then
        return companionPopupFallbacks[key] or key
    end
    return value
end

StaticPopupDialogs["OFFHAND_COMPANION_HANDOFF_NOTICE"] = {
    text = CompanionPopupLocale("POPUP_COMPANION_HANDOFF_TEXT"),
    button1 = CompanionPopupLocale("POPUP_BTN_GOT_IT"),
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["OFFHAND_COMPANION_TOPOLOGY_WARNING"] = {
    text = CompanionPopupLocale("POPUP_COMPANION_TOPOLOGY_TEXT"),
    button1 = CompanionPopupLocale("POPUP_BTN_GOT_IT"),
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["OFFHAND_COMPANION_VERSION_WARNING"] = {
    text = CompanionPopupLocale("POPUP_COMPANION_VERSION_TEXT"),
    button1 = CompanionPopupLocale("POPUP_BTN_GOT_IT"),
    hasEditBox = true,
    editBoxWidth = 260,
    OnShow = function(self)
        local eb = self.EditBox or _G[self:GetName().."EditBox"]
        if eb then
            eb:SetText(Offhand.companionDownloadUrl)
            if eb.SetCursorPosition then eb:SetCursorPosition(0) end
            if eb.ClearFocus then eb:ClearFocus() end
        end
    end,
    gamepadEditBoxText = function() return Offhand.companionDownloadUrl end,
    EditBoxOnEscapePressed = function(self)
        self:GetParent():Hide()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}


StaticPopupDialogs["OFFHAND_WELCOME_SPAN_WARNING"] = {
    text = Offhand.L["POPUP_WELCOME_WARNING_TEXT"],
    button1 = Offhand.L["POPUP_BTN_SETUP_GUIDE"],
    button2 = Offhand.L["POPUP_BTN_IGNORE"],
    OnAccept = function()
        if Offhand.MarkWelcomeDismissed then Offhand:MarkWelcomeDismissed() end
        if Offhand.Onboarding and Offhand.Onboarding.Open then Offhand.Onboarding:Open() end
    end,
    OnCancel = function()
        if Offhand.MarkWelcomeDismissed then Offhand:MarkWelcomeDismissed() end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["OFFHAND_CONFIRM_EXISTING_WINDOW"] = {
    text = Offhand.L["POPUP_CONFIRM_EXISTING_WINDOW_TEXT"],
    button1 = Offhand.L["BTN_REMEMBER_CURRENT_WINDOW"],
    button2 = Offhand.L["FOREVER_EDIT_MODE_NOT_NOW"],
    OnAccept = function()
        local preview = Offhand.Viewport and Offhand.Viewport.GetManualPreviewMetrics
            and Offhand.Viewport:GetManualPreviewMetrics() or nil
        local method = Offhand.GetOnboardingSetupMethod
            and Offhand:GetOnboardingSetupMethod() or "MANUAL"
        local source = method == "FANCYZONES" and "FANCYZONES" or "MANUAL"
        local ok, reason, record
        if Offhand.ManualCanvas then
            ok, reason, record = Offhand.ManualCanvas:RememberFromMetrics(preview, nil, source)
        end
        if ok then
            Offhand:Print(Offhand.L["MSG_MANUAL_CANVAS_REMEMBERED"], record.name,
                record.referenceWidth, record.referenceHeight)
            if Offhand.ApplyFullLayout then Offhand:ApplyFullLayout() end
        else
            Offhand:Print(Offhand.L["MSG_MANUAL_CANVAS_REMEMBER_FAILED"],
                tostring(reason or "unavailable"))
        end
    end,
    OnCancel = function()
        Offhand._independentWindowPromptDismissed = true
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["OFFHAND_FOREVER_SINGLE_SCREEN_LAYOUT"] = {
    text = Offhand.L["FOREVER_SINGLE_SCREEN_LAYOUT_TEXT"],
    button1 = Offhand.L["FOREVER_USE_MODERN"],
    button2 = Offhand.L["FOREVER_KEEP_CURRENT_LAYOUT"],
    OnAccept = function()
        if Offhand.HUD and Offhand.HUD.ApplyForeverRecoveryChoice then
            Offhand.HUD:ApplyForeverRecoveryChoice("fallback")
        end
    end,
    OnCancel = function()
        if Offhand.HUD and Offhand.HUD.CancelForeverRecoveryChoice then
            Offhand.HUD:CancelForeverRecoveryChoice("fallback")
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["OFFHAND_FOREVER_RESTORE_LAYOUT"] = {
    text = Offhand.L["FOREVER_RESTORE_LAYOUT_TEXT"],
    button1 = Offhand.L["FOREVER_RESTORE_SAVED_LAYOUT"],
    button2 = Offhand.L["FOREVER_KEEP_MODERN"],
    OnAccept = function()
        if Offhand.HUD and Offhand.HUD.ApplyForeverRecoveryChoice then
            Offhand.HUD:ApplyForeverRecoveryChoice("restore")
        end
    end,
    OnCancel = function()
        if Offhand.HUD and Offhand.HUD.CancelForeverRecoveryChoice then
            Offhand.HUD:CancelForeverRecoveryChoice("restore")
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["OFFHAND_FOREVER_EDIT_MODE_CONTROLS"] = {
    text = Offhand.L["FOREVER_EDIT_MODE_CONTROLS_TEXT"],
    button1 = Offhand.L["FOREVER_EDIT_MODE_BRING_TO_MAINHAND"],
    button2 = Offhand.L["FOREVER_EDIT_MODE_NOT_NOW"],
    OnAccept = function()
        Offhand._foreverEditModeControlsStaticPopupShown = nil
        if Offhand.HUD and Offhand.HUD.BringForeverEditModeControlsToMainhand then
            Offhand.HUD:BringForeverEditModeControlsToMainhand()
        end
    end,
    OnCancel = function()
        Offhand._foreverEditModeControlsStaticPopupShown = nil
        if Offhand.HUD and Offhand.HUD.DismissForeverEditModeControlsPrompt then
            Offhand.HUD:DismissForeverEditModeControlsPrompt()
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["OFFHAND_FOREVER_PARTY_FRAME_RECOVERY"] = {
    text = Offhand.L["FOREVER_PROTECTED_HUD_RECOVERY_TEXT"],
    button1 = Offhand.L["PROTECTED_HUD_RECOVERY_REPAIR"],
    button2 = Offhand.L["FOREVER_EDIT_MODE_NOT_NOW"],
    OnAccept = function()
        local ok, value, moved
        if Offhand.HUD and Offhand.HUD.RepairProtectedHUDLayout then
            ok, value, moved = Offhand.HUD:RepairProtectedHUDLayout()
        end
        if ok then
            Offhand:Print(Offhand.L["MAINHAND_LAYOUT_CREATED"], tostring(value), moved or 0)
        elseif value == "maximum" then
            Offhand:Print(Offhand.L["MAINHAND_LAYOUT_MAXIMUM"])
        else
            Offhand:Print(Offhand.L["MAINHAND_LAYOUT_FAILED"], tostring(value or "unavailable"))
        end
    end,
    OnCancel = function()
        if Offhand.HUD and Offhand.HUD.DismissForeverPartyFrameRecoveryPrompt then
            Offhand.HUD:DismissForeverPartyFrameRecoveryPrompt()
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["OFFHAND_MAINHAND_LAYOUT_ATTENTION"] = {
    text = Offhand.L["WIZARD_STEP_5_BODY"],
    button1 = Offhand.L["MAINHAND_LAYOUT_CREATE"],
    button2 = Offhand.L["FOREVER_EDIT_MODE_NOT_NOW"],
    OnAccept = function()
        Offhand._mainhandLayoutAttentionDismissed = true
        local ok, value, moved, activation
        if Offhand.Mainhand and Offhand.Mainhand.CreateOrUpdateEditModeLayout then
            ok, value, moved, activation = Offhand.Mainhand:CreateOrUpdateEditModeLayout()
        end
        if ok then
            if activation == "preset" then
                Offhand:Print(Offhand.L["MAINHAND_GAMEPAD_PRESET_APPLIED"], moved or 0)
            else
                Offhand:Print(Offhand.L["MAINHAND_LAYOUT_CREATED"], tostring(value), moved or 0)
            end
            if activation == "select" and Offhand.Mainhand.PromptManualLayoutSelection then
                Offhand.Mainhand:PromptManualLayoutSelection(value)
            elseif Offhand.Mainhand.PromptReload then
                Offhand.Mainhand:PromptReload()
            end
        elseif value == "maximum" then
            Offhand:Print(Offhand.L["MAINHAND_LAYOUT_MAXIMUM"])
        else
            Offhand:Print(Offhand.L["MAINHAND_LAYOUT_FAILED"], tostring(value or "unavailable"))
        end
    end,
    OnCancel = function()
        Offhand._mainhandLayoutAttentionDismissed = true
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["OFFHAND_HUD_SETUP_REMINDER"] = {
    text = Offhand.L["HUD_SETUP_REMINDER_TEXT"],
    button1 = Offhand.L["HUD_SETUP_RESUME"],
    button2 = Offhand.L["HUD_SETUP_DECLINE"],
    OnAccept = function()
        Offhand._hudSetupReminderShown = true
        if Offhand.Wizard and Offhand.Wizard.OpenHUDSetup then Offhand.Wizard:OpenHUDSetup() end
    end,
    OnCancel = function(_, _, reason)
        Offhand._hudSetupReminderShown = true
        if reason ~= "clicked" then return end
        if type(OffhandCharDB) == "table" then
            OffhandCharDB.hudSetupReminder = nil
            OffhandCharDB.hudSetupReminderDeclined = true
            if Offhand.isForever and Offhand.ForeverPersistence and Offhand.ForeverPersistence.SaveProfileSnapshot then
                Offhand.ForeverPersistence:SaveProfileSnapshot(true)
            end
        end
    end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

local function PositionGamepadSafeFrame(frame)
    local metrics = Offhand.Viewport and Offhand.Viewport.GetMetrics
        and Offhand.Viewport:GetMetrics() or nil
    if metrics and metrics.isSpanned and metrics.gameWidth and metrics.gameWidth > 0
        and Offhand.UIControls and Offhand.UIControls.FitDialog then
        local scale = Offhand.UIControls.FitDialog(frame, metrics)
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT",
            (metrics.gameLeft + metrics.gameRight) / (2 * scale),
            (metrics.gameBottom + metrics.gameTop) / (2 * scale))
        return
    end
    local mainhand = Offhand.API and Offhand.API.GetMainhandFrame
        and Offhand.API.GetMainhandFrame() or nil
    frame:ClearAllPoints()
    if mainhand then
        frame:SetPoint("CENTER", mainhand, "CENTER", 0, 0)
        return
    end

    local metrics = Offhand.Viewport and Offhand.Viewport.GetMetrics
        and Offhand.Viewport:GetMetrics() or nil
    if metrics and metrics.gameLeft and metrics.gameRight
        and metrics.gameBottom and metrics.gameTop then
        local parentScale = (UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
        local centerX = (metrics.gameLeft + metrics.gameRight) / 2
        local centerY = (metrics.gameBottom + metrics.gameTop) / 2
        frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT",
            centerX / parentScale, centerY / parentScale)
        return
    end
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
end

local function FormatPopupText(textValue, textArg1, textArg2)
    local text = tostring(textValue or "")
    if textArg1 == nil then return text end
    local ok, formatted
    if textArg2 ~= nil then
        ok, formatted = pcall(string.format, text, textArg1, textArg2)
    else
        ok, formatted = pcall(string.format, text, textArg1)
    end
    return ok and formatted or text
end

-- Native Gamepad UI treats every Blizzard StaticPopup as part of its protected
-- focus and binding stack. An addon-triggered popup can therefore taint
-- FrameControlsManager before it reaches a protected gamepad action. Route all
-- Offhand dialogs through one addon-owned card while that interface is active.
local function GetGamepadSafePopup()
    if Offhand._gamepadSafePopup then return Offhand._gamepadSafePopup end

    local template = not Offhand.isLegacyWrath and "BackdropTemplate" or nil
    local frame = CreateFrame("Frame", "OffhandGamepadSafePopup", UIParent, template)
    frame:SetSize(520, 210)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = false, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 },
        })
    end

    local text = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    if frame.SetBackdropColor then frame:SetBackdropColor(0.035, 0.035, 0.045, 1) end
    text:SetPoint("TOPLEFT", frame, "TOPLEFT", 28, -26)
    text:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -28, -26)
    text:SetHeight(112)
    text:SetJustifyH("CENTER")
    text:SetJustifyV("TOP")
    if text.SetWordWrap then text:SetWordWrap(true) end
    frame.text = text

    local editBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    editBox:SetSize(430, 24)
    editBox:SetPoint("BOTTOM", frame, "BOTTOM", 0, 58)
    if editBox.SetAutoFocus then editBox:SetAutoFocus(false) end
    editBox:SetScript("OnEscapePressed", function(self)
        if self.ClearFocus then self:ClearFocus() end
    end)
    frame.EditBox = editBox

    local accept = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    accept:SetSize(210, 24)
    accept:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 42, 22)
    frame.accept = accept

    local cancel = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    cancel:SetSize(210, 24)
    cancel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -42, 22)
    frame.cancel = cancel
    local alternate = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    alternate:SetSize(145, 24)
    alternate:SetPoint("BOTTOM", frame, "BOTTOM", 0, 22)
    frame.alternate = alternate

    local function Finish(handler)
        local definition, data = frame.definition, frame.data
        frame:Hide()
        if definition and type(definition[handler]) == "function" then
            definition[handler](frame, data, "clicked")
        end
    end
    accept:SetScript("OnClick", function() Finish("OnAccept") end)
    cancel:SetScript("OnClick", function() Finish("OnCancel") end)
    alternate:SetScript("OnClick", function() Finish("OnAlt") end)
    frame:SetScript("OnHide", function(self)
        local definition = self.definition
        self.popupKey, self.definition, self.data = nil, nil, nil
        if definition and type(definition.OnHide) == "function" then
            definition.OnHide(self)
        end
    end)
    frame:Hide()
    Offhand._gamepadSafePopup = frame
    return frame
end

function Offhand:ShowPopup(popupKey, textArg1, textArg2, data)
    local recoveryPopup = popupKey == "OFFHAND_CONFIRM_RECOVERY"
    local setupPopup = popupKey == "OFFHAND_DOWNLOAD_LINK" or popupKey == "OFFHAND_POWERTOYS_LINK"
        or popupKey == "OFFHAND_WIZARD_SKIP_MAINHAND_LAYOUT"
        or popupKey == "OFFHAND_HUD_SETUP_REMINDER"
    if not self:IsGamepadUIEnabled() and not setupPopup and not recoveryPopup then
        if StaticPopup_Show then return StaticPopup_Show(popupKey, textArg1, textArg2, data) end
        return nil
    end

    local definition = StaticPopupDialogs and StaticPopupDialogs[popupKey]
    if not definition then return nil end
    local frame = GetGamepadSafePopup()
    if frame.popupKey then frame:Hide() end
    frame.popupKey, frame.definition, frame.data = popupKey, definition, data
    frame.text:SetJustifyH(recoveryPopup and "LEFT" or "CENTER")
    if frame.text.SetFontObject then
        frame.text:SetFontObject(GameFontHighlight)
    end
    frame.text:SetText(FormatPopupText(definition.text, textArg1, textArg2))
    -- Remove the previous card's height before measuring, avoiding truncated
    -- GetStringHeight results when a longer message reuses this FontString.
    -- Only our owned card changes strata. Native popup frames are untouched.
    frame:SetFrameStrata((setupPopup or recoveryPopup) and "TOOLTIP" or "FULLSCREEN_DIALOG")
    if self.UIControls and self.UIControls.MeasureWrappedText then
        frame.text:SetHeight(0)
        local measure = self.UIControls.MeasurePopupText or self.UIControls.MeasureWrappedText
        local height = measure(frame.text, frame.text:GetText(), 464) + 8
        frame.text:SetHeight(height)
        frame:SetHeight(math.max(210, height + (definition.hasEditBox and 118 or 76)))
    end

    local editValue = definition.gamepadEditBoxText
    if type(editValue) == "function" then editValue = editValue() end
    if editValue ~= nil then
        frame.EditBox:SetText(tostring(editValue))
        if frame.EditBox.SetCursorPosition then frame.EditBox:SetCursorPosition(0) end
        if frame.EditBox.ClearFocus then frame.EditBox:ClearFocus() end
        frame.EditBox:Show()
    else
        frame.EditBox:Hide()
    end

    frame.accept:SetText(definition.button1 or OKAY or "OK")
    frame.accept:SetWidth(definition.button3 and 145 or 210)
    frame.cancel:SetWidth(definition.button3 and 145 or 210)
    frame.alternate:Hide()
    if definition.button3 then
        frame.alternate:SetText(definition.button3)
        frame.alternate:Show()
    end
    if definition.button2 then
        frame.accept:ClearAllPoints()
        frame.accept:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 42, 22)
        frame.cancel:SetText(definition.button2)
        frame.cancel:Show()
    else
        frame.accept:ClearAllPoints()
        frame.accept:SetPoint("BOTTOM", frame, "BOTTOM", 0, 22)
        frame.cancel:Hide()
    end
    PositionGamepadSafeFrame(frame)
    frame:Show()
    if setupPopup and not self:IsGamepadUIEnabled() and editValue ~= nil then
        if frame.EditBox.HighlightText then frame.EditBox:HighlightText() end
        if frame.EditBox.SetFocus then frame.EditBox:SetFocus() end
    end
    return frame
end

function Offhand:HidePopup(popupKey)
    local frame = self._gamepadSafePopup
    if frame and frame.popupKey == popupKey then
        frame:Hide()
        return true
    end
    if not self:IsGamepadUIEnabled() and StaticPopup_Hide then
        StaticPopup_Hide(popupKey)
        return true
    end
    return false
end


function Offhand:InitializePopups()
    local handoff = StaticPopupDialogs["OFFHAND_COMPANION_HANDOFF_NOTICE"]
    handoff.text = CompanionPopupLocale("POPUP_COMPANION_HANDOFF_TEXT")
    handoff.button1 = CompanionPopupLocale("POPUP_BTN_GOT_IT")
    local topology = StaticPopupDialogs["OFFHAND_COMPANION_TOPOLOGY_WARNING"]
    topology.text = CompanionPopupLocale("POPUP_COMPANION_TOPOLOGY_TEXT")
    topology.button1 = CompanionPopupLocale("POPUP_BTN_GOT_IT")
    local version = StaticPopupDialogs["OFFHAND_COMPANION_VERSION_WARNING"]
    version.text = CompanionPopupLocale("POPUP_COMPANION_VERSION_TEXT")
    version.button1 = CompanionPopupLocale("POPUP_BTN_GOT_IT")
    for _, notice in ipairs({handoff, topology, version}) do
        notice.button1 = Offhand.L["POPUP_BTN_SETUP_GUIDE"]
        notice.button2 = Offhand.L["FOREVER_EDIT_MODE_NOT_NOW"]
        notice.button3 = Offhand.L["HUD_SETUP_CALIBRATE"]
        notice.OnAccept = function()
            if Offhand.Onboarding then Offhand.Onboarding:Open() end
        end
        notice.OnAlt = function()
            if Offhand.Wizard then Offhand.Wizard:Open() end
        end
    end
    local reminder = StaticPopupDialogs["OFFHAND_HUD_SETUP_REMINDER"]
    reminder.text = Offhand.L["HUD_SETUP_REMINDER_TEXT"]
    reminder.button1 = Offhand.L["HUD_SETUP_RESUME"]
    reminder.button2 = Offhand.L["HUD_SETUP_DECLINE"]
    
    StaticPopupDialogs["OFFHAND_WELCOME_SPAN_WARNING"].text = Offhand.L["POPUP_WELCOME_WARNING_TEXT"]
    StaticPopupDialogs["OFFHAND_WELCOME_SPAN_WARNING"].button1 = Offhand.L["POPUP_BTN_SETUP_GUIDE"]
    StaticPopupDialogs["OFFHAND_WELCOME_SPAN_WARNING"].button2 = Offhand.L["POPUP_BTN_IGNORE"]
    local independent = StaticPopupDialogs["OFFHAND_CONFIRM_EXISTING_WINDOW"]
    independent.text = Offhand.L["POPUP_CONFIRM_EXISTING_WINDOW_TEXT"]
    independent.button1 = Offhand.L["BTN_REMEMBER_CURRENT_WINDOW"]
    independent.button2 = Offhand.L["FOREVER_EDIT_MODE_NOT_NOW"]

    local single = StaticPopupDialogs["OFFHAND_FOREVER_SINGLE_SCREEN_LAYOUT"]
    single.text = Offhand.L["FOREVER_SINGLE_SCREEN_LAYOUT_TEXT"]
    single.button1 = Offhand.L["FOREVER_USE_MODERN"]
    single.button2 = Offhand.L["FOREVER_KEEP_CURRENT_LAYOUT"]
    local restore = StaticPopupDialogs["OFFHAND_FOREVER_RESTORE_LAYOUT"]
    restore.text = Offhand.L["FOREVER_RESTORE_LAYOUT_TEXT"]
    restore.button1 = Offhand.L["FOREVER_RESTORE_SAVED_LAYOUT"]
    restore.button2 = Offhand.L["FOREVER_KEEP_MODERN"]
    local editMode = StaticPopupDialogs["OFFHAND_FOREVER_EDIT_MODE_CONTROLS"]
    editMode.text = Offhand.L["FOREVER_EDIT_MODE_CONTROLS_TEXT"]
    editMode.button1 = Offhand.L["FOREVER_EDIT_MODE_BRING_TO_MAINHAND"]
    editMode.button2 = Offhand.L["FOREVER_EDIT_MODE_NOT_NOW"]
    local partyFrame = StaticPopupDialogs["OFFHAND_FOREVER_PARTY_FRAME_RECOVERY"]
    partyFrame.text = Offhand.L["FOREVER_PROTECTED_HUD_RECOVERY_TEXT"]
    partyFrame.button1 = Offhand.L["PROTECTED_HUD_RECOVERY_REPAIR"]
    partyFrame.button2 = Offhand.L["FOREVER_EDIT_MODE_NOT_NOW"]
    local mainhandLayout = StaticPopupDialogs["OFFHAND_MAINHAND_LAYOUT_ATTENTION"]
    mainhandLayout.text = Offhand.L["WIZARD_STEP_5_BODY"]
    mainhandLayout.button1 = Offhand.L["MAINHAND_LAYOUT_CREATE"]
    mainhandLayout.button2 = Offhand.L["FOREVER_EDIT_MODE_NOT_NOW"]
end

local companionNoticePopups = {
    HANDOFF = "OFFHAND_COMPANION_HANDOFF_NOTICE",
    TOPOLOGY = "OFFHAND_COMPANION_TOPOLOGY_WARNING",
    VERSION = "OFFHAND_COMPANION_VERSION_WARNING",
}

local function FrameIsShown(frame)
    if not frame or type(frame.IsShown) ~= "function" then return false end
    local ok, shown = pcall(frame.IsShown, frame)
    return ok and shown == true
end

function Offhand:IsCinematicOrMovieActive()
    if self._cinematicEventActive then return true end
    if type(InCinematic) == "function" then
        local ok, active = pcall(InCinematic)
        if ok and active then return true end
    end
    return FrameIsShown(_G.CinematicFrame) or FrameIsShown(_G.MovieFrame)
end

-- Cinematic APIs do not cover every first-character intro sequence.  Modern
-- clients can reserve keyboard input through PLAYER_CONTROL_LOST before (or
-- without) showing CinematicFrame/MovieFrame.  Keep this broader predicate
-- separate from the visual check so startup restoration and Escape persistence
-- also stay out of Blizzard's input-owned interval.
function Offhand:IsBlizzardInputReserved()
    return self._playerControlLost == true or self:IsCinematicOrMovieActive()
end

-- Retail and Forever anchor their native skip-confirmation dialogs against the
-- full bounding canvas. The dialog can be outside the visible Mainhand area.
-- Observe only the dialog's native OnShow and move that
-- already-open window into Mainhand; never consume a key or invoke Skip/Confirm.
local cinematicSkipDialogsHooked = setmetatable({}, { __mode = "k" })

local function ResolveCinematicSkipDialogs()
    local dialogs, seen = {}, {}
    local function Add(dialog, source)
        if dialog and not seen[dialog] then
            seen[dialog] = true
            dialogs[#dialogs + 1] = { frame = dialog, source = source }
        end
    end
    Add(_G.CinematicFrame and (_G.CinematicFrame.closeDialog
        or _G.CinematicFrame.CloseDialog), "CinematicFrame")
    Add(_G.MovieFrame and (_G.MovieFrame.closeDialog
        or _G.MovieFrame.CloseDialog), "MovieFrame")
    Add(_G.CinematicFrameCloseDialog, "CinematicFrameCloseDialog")
    return dialogs
end

function Offhand:CenterCinematicSkipDialog(dialog, source)
    if not (self.isForever or self.isRetail) or not self.db or not self.db.enabled
        or not dialog or not FrameIsShown(dialog)
        or not self.Viewport or not self.Viewport.GetMetrics then return false end
    if dialog.IsForbidden and dialog:IsForbidden() then return false end
    if dialog.IsProtected and dialog:IsProtected() then return false end
    local metrics = self.Viewport:GetMetrics()
    if not metrics or not metrics.isSpanned then return false end
    if not dialog.GetEffectiveScale or not dialog.ClearAllPoints or not dialog.SetPoint then
        return false
    end
    local dialogScale = dialog:GetEffectiveScale()
    local parentScale = UIParent and UIParent.GetEffectiveScale
        and UIParent:GetEffectiveScale() or nil
    if not dialogScale or dialogScale <= 0 or not parentScale or parentScale <= 0 then
        return false
    end
    local factor = parentScale / dialogScale
    local centerX = ((metrics.gameLeft or 0) + (metrics.gameRight or 0)) / 2
    local centerY = ((metrics.gameBottom or 0) + (metrics.gameTop or 0)) / 2
    dialog:ClearAllPoints()
    dialog:SetPoint("CENTER", UIParent, "BOTTOMLEFT", centerX * factor, centerY * factor)
    self._cinematicSkipDialogStatus = string.format("centered:%s@%.0f,%.0f",
        tostring(source or "unknown"), centerX, centerY)
    return true
end

function Offhand:AttachCinematicSkipDialogRecovery()
    if not (self.isForever or self.isRetail) or not self.db or not self.db.enabled then return false end
    local attached = false
    for _, candidate in ipairs(ResolveCinematicSkipDialogs()) do
        local dialog, source = candidate.frame, candidate.source
        local accessible = not (dialog.IsForbidden and dialog:IsForbidden())
            and not (dialog.IsProtected and dialog:IsProtected())
        if accessible and dialog.HookScript and not cinematicSkipDialogsHooked[dialog] then
            cinematicSkipDialogsHooked[dialog] = true
            dialog:HookScript("OnShow", function(frame)
                Offhand:CenterCinematicSkipDialog(frame, source)
            end)
            attached = true
        end
        if accessible and FrameIsShown(dialog) then
            self:CenterCinematicSkipDialog(dialog, source)
        end
    end
    if attached and not self._cinematicSkipDialogStatus then self._cinematicSkipDialogStatus = "attached" end
    return attached
end

local function ScheduleCinematicSkipDialogRecovery()
    Offhand:AttachCinematicSkipDialogRecovery()
    if C_Timer and C_Timer.After then
        -- Native playback handlers may create/show their UI later in this event.
        -- Every retry checks current enabled, span and visibility state.
        C_Timer.After(0, function() Offhand:AttachCinematicSkipDialogRecovery() end)
        C_Timer.After(0.25, function() Offhand:AttachCinematicSkipDialogRecovery() end)
    end
end

function Offhand:DeferAutomaticUIForCinematic()
    self._automaticUIPendingAfterCinematic = true
end

function Offhand:HideCompanionNotices(exceptKind)
    for kind, popupKey in pairs(companionNoticePopups) do
        if kind ~= exceptKind then
            Offhand:HidePopup(popupKey)
            if Offhand._companionNoticesShown then
                Offhand._companionNoticesShown[kind] = nil
            end
        end
    end
end

function Offhand:RefreshMainhandLayoutAttention()
    if InCombatLockdown and InCombatLockdown() then return false end
    local pendingHUD = type(OffhandCharDB) == "table"
        and (OffhandCharDB.hudSetupReminder or OffhandCharDB.mainhandLayoutDeferred)
        and not OffhandCharDB.hudSetupReminderDeclined
    if pendingHUD
        and not self._hudSetupReminderShown and self.HasBlizzardEditMode and self:HasBlizzardEditMode() then
        self._hudSetupReminderShown = true
        self:ShowPopup("OFFHAND_HUD_SETUP_REMINDER")
        return true
    end
    if Offhand.isForever or Offhand._mainhandLayoutAttentionDismissed
        or not Offhand.Mainhand or not Offhand.Mainhand.NeedsEditModeLayoutAttention then
        return false
    end
    local needed = Offhand.Mainhand:NeedsEditModeLayoutAttention()
    if needed then
        Offhand:ShowPopup("OFFHAND_MAINHAND_LAYOUT_ATTENTION")
        return true
    end
    Offhand:HidePopup("OFFHAND_MAINHAND_LAYOUT_ATTENTION")
    return false
end

function Offhand:HideResolvedSpanPrompts(metrics)
    local spanReady = metrics and metrics.isSpanned
        and (metrics.topologyStatus == "READY" or metrics.companionTopology == true
            or metrics.manualCanvas == true)
    if not spanReady then return false end
    Offhand:HidePopup("OFFHAND_WELCOME_SPAN_WARNING")
    -- Compatibility with the pre-Beta-19 download-link warning.
    Offhand:HidePopup("OFFHAND_COMPANION_WARNING")
    return true
end

function Offhand:GetCompanionNoticeKind(metrics, recoveryPromptActive)
    if recoveryPromptActive or Offhand._displayGeometryTransitionActive or not metrics then
        return nil
    end

    if metrics.topologyStatus == "READY" then
        if metrics.companionVersionStatus == "MISMATCH" then
            return "VERSION"
        end
        return nil
    end

    if metrics.manualCanvas then return nil end

    if metrics.manualCanvasState == "EXACT_REQUIRED" then return "HANDOFF" end

    -- Forever has its own single-screen recovery prompt for a stale snapshot.
    if metrics.topologyStatus == "MISMATCH" then
        if Offhand.isForever then return nil end
        return "TOPOLOGY"
    end

    return nil
end

function Offhand:ShowCompanionNotice(kind, metrics)
    if kind and Offhand:IsBlizzardInputReserved() then
        Offhand:DeferAutomaticUIForCinematic()
        return
    end
    if not kind then
        Offhand:HideCompanionNotices()
        Offhand:HideResolvedSpanPrompts(metrics)
        return
    end
    Offhand:HideCompanionNotices(kind)
    Offhand:HideResolvedSpanPrompts(metrics)
    Offhand._companionNoticesShown = Offhand._companionNoticesShown or {}
    if Offhand._companionNoticesShown[kind] then return end
    Offhand._companionNoticesShown[kind] = true

    if kind == "VERSION" then
        local dialog = StaticPopupDialogs["OFFHAND_COMPANION_VERSION_WARNING"]
        local actual = metrics and metrics.companionVersion or "unknown"
        local expected = metrics and metrics.expectedCompanionVersion
            or Offhand.companionFullVersion
        dialog.text = string.format(CompanionPopupLocale("POPUP_COMPANION_VERSION_TEXT"), actual, expected)
        Offhand:ShowPopup("OFFHAND_COMPANION_VERSION_WARNING")
    elseif kind == "TOPOLOGY" then
        Offhand:ShowPopup("OFFHAND_COMPANION_TOPOLOGY_WARNING")
    elseif kind == "HANDOFF" then
        Offhand:ShowPopup("OFFHAND_COMPANION_HANDOFF_NOTICE")
    end
end

function Offhand:RefreshCompanionNoticeState(metrics)
    Offhand:HideResolvedSpanPrompts(metrics)
    local setupComplete = Offhand.IsSetupComplete and Offhand:IsSetupComplete()
        or (Offhand.db and Offhand.db.firstRunComplete)
    if not Offhand.db or not Offhand.db.enabled or not setupComplete then
        Offhand:HideCompanionNotices()
        return nil
    end
    local recoveryPromptActive = Offhand.isForever and Offhand.HUD
        and Offhand.HUD.foreverRecoveryPromptShown ~= nil
    local kind = Offhand:GetCompanionNoticeKind(metrics, recoveryPromptActive)
    Offhand:ShowCompanionNotice(kind, metrics)
    local manualState = metrics and metrics.manualCanvasState
    local manual = Offhand.ManualCanvas and Offhand.ManualCanvas.GetDiagnostics
        and Offhand.ManualCanvas:GetDiagnostics() or nil
    if not kind and metrics and not metrics.companionTopology
        and not metrics.isSpanned and metrics.topologyStatus == "ABSENT"
        and manual and manual.count == 0
        and not Offhand._independentWindowPromptDismissed then
        Offhand._independentWindowPromptDismissed = true
        Offhand:ShowPopup("OFFHAND_CONFIRM_EXISTING_WINDOW")
        return "INDEPENDENT"
    end
    if not kind and metrics and not metrics.companionTopology
        and not metrics.isSpanned and manualState
        and manualState ~= "EXACT_REQUIRED" then
        local noticeKey = tostring(manualState) .. ":"
            .. tostring(metrics.physicalWidth or 0) .. "x" .. tostring(metrics.physicalHeight or 0)
        if Offhand._manualCanvasNoticeKey ~= noticeKey then
            Offhand._manualCanvasNoticeKey = noticeKey
            if manual and manual.count == 0 then
                Offhand:Print(Offhand.L["MANUAL_CANVAS_UNREMEMBERED"])
            else
                Offhand:Print(Offhand.L["MANUAL_CANVAS_MISMATCH"],
                    metrics.physicalWidth or 0, metrics.physicalHeight or 0)
            end
        end
    elseif metrics and metrics.isSpanned then
        Offhand._manualCanvasNoticeKey = nil
    end
    return kind
end

function Offhand:ShowForeverLayoutRecoveryPrompt(kind, layoutName)
    if Offhand:IsBlizzardInputReserved() then
        Offhand:DeferAutomaticUIForCinematic()
        return
    end
    local key = kind == "restore" and "OFFHAND_FOREVER_RESTORE_LAYOUT"
        or "OFFHAND_FOREVER_SINGLE_SCREEN_LAYOUT"
    Offhand:ShowPopup(key, layoutName or "Offhand")
end

function Offhand:HideForeverLayoutRecoveryPrompt(kind)
    local key = kind == "restore" and "OFFHAND_FOREVER_RESTORE_LAYOUT"
        or "OFFHAND_FOREVER_SINGLE_SCREEN_LAYOUT"
    Offhand:HidePopup(key)
end

-- Blizzard's native Gamepad UI tracks StaticPopup focus. Closing an Offhand
-- StaticPopup while Edit Mode is open can make FrameControlsManager restore
-- focus to a stale LootFrame control and fail inside FocusGamepad. Keep the
-- hardware-click recovery action, but host it in an addon-owned card that is
-- never registered with Blizzard's popup or gamepad focus stacks.
local function GetForeverGamepadEditModeControlsPrompt()
    if Offhand._foreverGamepadEditModeControlsPrompt then
        return Offhand._foreverGamepadEditModeControlsPrompt
    end

    local template = not Offhand.isLegacyWrath and "BackdropTemplate" or nil
    local frame = CreateFrame("Frame", "OffhandGamepadEditModeControlsPrompt", UIParent, template)
    frame:SetSize(440, 150)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetClampedToScreen(true)
    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 },
        })
    end

    local text = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    text:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -24)
    text:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -24, -24)
    text:SetJustifyH("CENTER")
    text:SetJustifyV("TOP")
    text:SetText(Offhand.L["FOREVER_EDIT_MODE_CONTROLS_TEXT"])
    frame.text = text

    local accept = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    accept:SetSize(190, 24)
    accept:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 22, 20)
    accept:SetText(Offhand.L["FOREVER_EDIT_MODE_BRING_TO_MAINHAND"])
    accept:SetScript("OnClick", function()
        frame:Hide()
        if Offhand.HUD and Offhand.HUD.BringForeverEditModeControlsToMainhand then
            Offhand.HUD:BringForeverEditModeControlsToMainhand()
        end
    end)
    frame.accept = accept

    local cancel = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    cancel:SetSize(190, 24)
    cancel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -22, 20)
    cancel:SetText(Offhand.L["FOREVER_EDIT_MODE_NOT_NOW"])
    cancel:SetScript("OnClick", function()
        frame:Hide()
        if Offhand.HUD and Offhand.HUD.DismissForeverEditModeControlsPrompt then
            Offhand.HUD:DismissForeverEditModeControlsPrompt()
        end
    end)
    frame.cancel = cancel

    frame:Hide()
    Offhand._foreverGamepadEditModeControlsPrompt = frame
    return frame
end

function Offhand:ShowForeverEditModeControlsPrompt()
    if Offhand:IsBlizzardInputReserved() then
        Offhand:DeferAutomaticUIForCinematic()
        return
    end
    if Offhand:IsGamepadUIEnabled() then
        local frame = GetForeverGamepadEditModeControlsPrompt()
        frame.text:SetText(Offhand.L["FOREVER_EDIT_MODE_CONTROLS_TEXT"])
        frame.accept:SetText(Offhand.L["FOREVER_EDIT_MODE_BRING_TO_MAINHAND"])
        frame.cancel:SetText(Offhand.L["FOREVER_EDIT_MODE_NOT_NOW"])
        PositionGamepadSafeFrame(frame)
        frame:Show()
        return
    end
    if StaticPopup_Show then
        local popup = StaticPopup_Show("OFFHAND_FOREVER_EDIT_MODE_CONTROLS")
        Offhand._foreverEditModeControlsStaticPopupShown = popup and true or nil
        local mainhand = Offhand.API and Offhand.API.GetMainhandFrame
            and Offhand.API.GetMainhandFrame() or nil
        -- Keep Offhand's recovery choice away from Blizzard's centered modal.
        if popup and mainhand and popup.ClearAllPoints and popup.SetPoint then
            popup:ClearAllPoints()
            popup:SetPoint("TOP", mainhand, "TOP", 0, -36)
        end
    end
end

function Offhand:HideForeverEditModeControlsPrompt()
    local frame = Offhand._foreverGamepadEditModeControlsPrompt
    if frame then frame:Hide() end
    if Offhand._foreverEditModeControlsStaticPopupShown and StaticPopup_Hide then
        Offhand._foreverEditModeControlsStaticPopupShown = nil
        StaticPopup_Hide("OFFHAND_FOREVER_EDIT_MODE_CONTROLS")
    end
end

function Offhand:ShowForeverPartyFrameRecoveryPrompt(frameName)
    if Offhand:IsBlizzardInputReserved() then
        Offhand:DeferAutomaticUIForCinematic()
        return
    end
    Offhand:ShowPopup("OFFHAND_FOREVER_PARTY_FRAME_RECOVERY", frameName or "HUD")
end

function Offhand:HideForeverPartyFrameRecoveryPrompt()
    Offhand:HidePopup("OFFHAND_FOREVER_PARTY_FRAME_RECOVERY")
end

local eventFrame = CreateFrame("Frame", "OffhandEventFrame")

-- Blizzard can restore WorldFrame to the complete spanned window while an
-- in-engine cinematic starts or finishes.  The independently positioned UI
-- remains on Mainhand, but the 3D projection then centres on the monitor seam.
-- Reassert only the viewport here: a full layout pass would needlessly touch
-- panels and saved workspace state during a cinematic transition.
local cinematicViewportGeneration = 0
local cinematicViewportQueuedForCombat = false

local function ApplyCinematicViewportRecovery()
    if not Offhand.db or not Offhand.db.enabled
        or not Offhand.Viewport or not Offhand.Viewport.Apply then
        return
    end

    if InCombatLockdown() then
        if cinematicViewportQueuedForCombat then return end
        cinematicViewportQueuedForCombat = true
        Offhand:RunOrQueueCombat(function()
            cinematicViewportQueuedForCombat = false
            if Offhand.db and Offhand.db.enabled
                and Offhand.Viewport and Offhand.Viewport.Apply then
                Offhand.Viewport:Apply()
            end
        end)
        return
    end

    Offhand.Viewport:Apply()
end

local function ScheduleCinematicViewportRecovery()
    cinematicViewportGeneration = cinematicViewportGeneration + 1
    local generation = cinematicViewportGeneration

    -- The zero-delay pass runs after Blizzard's current event dispatch.  Some
    -- clients finish their cinematic teardown over later frames, so retain two
    -- short idempotent follow-ups. A newer transition supersedes older timers.
    for _, delay in ipairs({0, 0.1, 0.5}) do
        C_Timer.After(delay, function()
            if generation == cinematicViewportGeneration then
                ApplyCinematicViewportRecovery()
            end
        end)
    end
end

local function EvaluateEntryNotices(attempt)
    attempt = attempt or 1
    if Offhand:IsBlizzardInputReserved() then
        Offhand:DeferAutomaticUIForCinematic()
        if not Offhand._automaticUIRetryScheduled and C_Timer and C_Timer.After then
            Offhand._automaticUIRetryScheduled = true
            C_Timer.After(1, function()
                Offhand._automaticUIRetryScheduled = nil
                EvaluateEntryNotices(1)
            end)
        end
        return
    end
    Offhand._automaticUIPendingAfterCinematic = nil
    if Offhand._displayGeometryTransitionActive and attempt < 5 then
        C_Timer.After(0.5, function()
            EvaluateEntryNotices(attempt + 1)
        end)
        return
    end
    if not Offhand.db then return end

    local viewportMetrics = Offhand.Viewport and Offhand.Viewport.GetMetrics
        and Offhand.Viewport:GetMetrics() or nil
    local isSpanned = viewportMetrics and viewportMetrics.isSpanned
    local w = GetScreenWidth() * UIParent:GetEffectiveScale()
    local physW = w
    if GetPhysicalScreenSize then
        pcall(function() physW = select(1, GetPhysicalScreenSize()) end)
    end
    if isSpanned == nil then
        isSpanned = not (w and physW and w <= (physW + 50))
    end

    local welcomeDismissed = Offhand.IsWelcomeDismissed and Offhand:IsWelcomeDismissed()
        or Offhand.db.firstRunComplete
    local setupComplete = Offhand.IsSetupComplete and Offhand:IsSetupComplete()
        or Offhand.db.firstRunComplete
    local onboardingResumeStep = Offhand.GetOnboardingResumeStep
        and Offhand:GetOnboardingResumeStep() or nil
    if Offhand.db.enabled and (onboardingResumeStep or not welcomeDismissed or not setupComplete) then
        Offhand:HideCompanionNotices()
        Offhand:HideResolvedSpanPrompts(viewportMetrics)
        -- Installation onboarding is deliberately independent from display
        -- calibration. A saved reload handoff takes priority over an older
        -- welcome acknowledgement. Acknowledging the welcome never substitutes
        -- for completing calibration; deliberately disabled profiles stay quiet.
        if Offhand.Onboarding and Offhand.Onboarding.Open then
            Offhand.Onboarding:Open()
        elseif not isSpanned then
            Offhand:ShowPopup("OFFHAND_WELCOME_SPAN_WARNING")
        elseif Offhand.Wizard and Offhand.Wizard.Open then
            Offhand.Wizard:Open()
        else
            Offhand:Print(Offhand.L["MSG_FIRST_RUN"])
        end
    elseif Offhand.db.enabled and setupComplete then
        local companionNotice = Offhand:RefreshCompanionNoticeState(viewportMetrics)
        if not companionNotice then Offhand:RefreshMainhandLayoutAttention() end
    end
end

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_LEAVING_WORLD")
eventFrame:RegisterEvent("PLAYER_LOGOUT")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("ZONE_CHANGED")
eventFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
eventFrame:RegisterEvent("UI_SCALE_CHANGED")
eventFrame:RegisterEvent("DISPLAY_SIZE_CHANGED")
eventFrame:RegisterEvent("CINEMATIC_START")
eventFrame:RegisterEvent("CINEMATIC_STOP")
if Offhand.isRetail or Offhand.isForever then eventFrame:RegisterEvent("PLAY_MOVIE") end
eventFrame:RegisterEvent("PLAYER_CONTROL_LOST")
eventFrame:RegisterEvent("PLAYER_CONTROL_GAINED")

eventFrame:SetScript("OnEvent", function(self, event, arg1, ...)
    if event == "ADDON_LOADED" and arg1 == addonName then
        Offhand:InitializePopups()
        Offhand:InitializeConfig()
        if Offhand.InitializeUserMedia then Offhand:InitializeUserMedia() end
        if Offhand.InitializeThemes then Offhand:InitializeThemes() end
        if Offhand.InitializeCanvas then Offhand:InitializeCanvas() end
        if Offhand.InitializeWorkspaceBehavior then Offhand:InitializeWorkspaceBehavior() end
        if Offhand.InitializeViewport then Offhand:InitializeViewport() end
        if Offhand.InitializeSeamRedirect then Offhand:InitializeSeamRedirect() end
        if Offhand.InitializeOptions then Offhand:InitializeOptions() end

        -- Initialize child modules
        for name, module in pairs(Offhand.modules) do
            if module.Initialize then
                module:Initialize()
            end
        end

    elseif event == "ADDON_LOADED" and arg1 == "Offhand_UserMedia" then
        if Offhand.UserMedia and Offhand.UserMedia.Refresh then
            Offhand.UserMedia:Refresh(false)
            if Offhand.UpdateTheme then Offhand:UpdateTheme() end
            if Offhand.Options and Offhand.Options.RefreshPanel then Offhand.Options:RefreshPanel() end
        end

    elseif event == "PLAYER_LOGIN" then
        if Offhand.EnsureCharacterIdentity then Offhand:EnsureCharacterIdentity() end
        if Offhand.db and Offhand.db.antiShimmer and Offhand.SetAntiShimmer then
            Offhand:SetAntiShimmer(true)
        end
        local loginMetrics = Offhand.Viewport and Offhand.Viewport.GetMetrics and Offhand.Viewport:GetMetrics()
        if Offhand.db and Offhand.db.enabled and (not loginMetrics or loginMetrics.isSpanned) then
            -- Unclamp chat while Offhand is active so native tab dragging can
            -- cross monitor boundaries. Disabled profiles retain Blizzard state.
            if ChatFrame1 and ChatFrame1.SetClampedToScreen then
                ChatFrame1:SetClampedToScreen(false)
                hooksecurefunc(ChatFrame1, "SetClampedToScreen", function(self, clamped)
                    if Offhand.db and Offhand.db.enabled and clamped then
                        self:SetClampedToScreen(false)
                    end
                end)
            end
            pcall(function()
                if not (Offhand.HasCustomBagAddon and Offhand.HasCustomBagAddon()) then
                    for i=1, 13 do
                        local f = _G["ContainerFrame"..i]
                        if f then f:SetUserPlaced(false) end
                    end
                    if ContainerFrameCombinedBags then
                        ContainerFrameCombinedBags:SetUserPlaced(false)
                    end
                end
                -- Forever's Blizzard Edit Mode owns these frames. Even seemingly
                -- harmless SetUserPlaced calls can taint its party-frame refresh
                -- when Edit Mode closes.
                if not Offhand.isForever then
                    if PlayerFrame then PlayerFrame:SetUserPlaced(false) end
                    if TargetFrame then TargetFrame:SetUserPlaced(false) end
                    if MinimapCluster and not (Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions["MinimapCluster"]) then
                        MinimapCluster:SetUserPlaced(false)
                    end
                end
            end)
        end
        Offhand:ApplyFullLayout()
        if Offhand.RawMouse and Offhand.RawMouse.Refresh then
            Offhand.RawMouse:Refresh(loginMetrics)
        end
        Offhand:Print(L["MSG_LOADED"], Offhand.version)

    elseif event == "PLAYER_LEAVING_WORLD" or event == "PLAYER_LOGOUT" then
        -- Some Forever builds dispatch PLAYER_LOGOUT, but not
        -- PLAYER_LEAVING_WORLD, during /reload. Capture once per transition so
        -- a later teardown event cannot replace the visible snapshot with an
        -- empty one after Blizzard has already hidden its panels.
        if Offhand._openPanelsCapturedForTransition then return end
        Offhand._openPanelsCapturedForTransition = true
        if Offhand.Canvas and Offhand.Canvas.FinalizeForeverNativeBagStateForTransition then
            Offhand.Canvas:FinalizeForeverNativeBagStateForTransition()
        end
        local transitionMetrics = Offhand.Viewport and Offhand.Viewport.GetMetrics and Offhand.Viewport:GetMetrics()
        local preserveWorkspaceSnapshot = Offhand.Viewport and Offhand.Viewport.IsSingleScreenRecovery
            and Offhand.Viewport:IsSingleScreenRecovery(transitionMetrics)
            or (transitionMetrics and not transitionMetrics.isSpanned
                and transitionMetrics.topologyStatus == "MISMATCH")
        if not preserveWorkspaceSnapshot and Offhand.db and Offhand.db.enabled and Offhand.db.savedWorkspacePositions and Offhand.db.restoreWorkspaceOnReload ~= false then
            -- Explicit panel toggles and close buttons maintain this table while
            -- the player is active. Preserve that last known state here: on
            -- Forever, Blizzard can hide CharacterFrame and the Combined
            -- Backpack before the first teardown event reaches addons.
            Offhand.db.openWorkspacePanels = Offhand.db.openWorkspacePanels or {}
            for name, _ in pairs(Offhand.db.savedWorkspacePositions) do
                local frame = _G[name]
                local foreverNativeBackpack = Offhand.isForever
                    and (name == "ContainerFrame1"
                        or name == "ContainerFrameCombinedBags")
                if frame and frame:IsVisible() and not foreverNativeBackpack then
                    Offhand.db.openWorkspacePanels[name] = true
                end
            end
            
            if Offhand.CanvasPanelLifecycle and Offhand.CanvasPanelLifecycle.CaptureTBCPanelOpenState then
                Offhand.CanvasPanelLifecycle.CaptureTBCPanelOpenState(Offhand.Canvas)
            end
            for key, val in pairs(_G) do
                if type(key) == "string" and type(val) == "table" and type(rawget(val, 0)) == "userdata" and val.IsShown then
                    local okShow, isShown = pcall(function() return val:IsShown() end)
                    if okShow and isShown then
                        if key:match("^Baganator") or key:match("^Baginator") or key:match("^Bagnon") or key:match("^AdiBags") or key:match("^BetterBags") or key:match("^ArkInventory") or key:match("^ElvUI_ContainerFrame") then
                            -- Replacement bag addons commonly derive every child
                            -- widget name from the root. Persist only top-level
                            -- windows; saving title text/buttons makes a new
                            -- character inherit phantom Escape-owned panels.
                            local isTopLevel = val.GetParent and val:GetParent() == UIParent
                            if isTopLevel and Offhand.Canvas and Offhand.Canvas.IsFrameOnWorkspace then
                                local okWs, onWs = pcall(Offhand.Canvas.IsFrameOnWorkspace, val)
                                if okWs and onWs then
                                    Offhand.db.openWorkspacePanels[key] = true
                                    Offhand.db.savedWorkspacePositions[key] = Offhand.db.savedWorkspacePositions[key] or {}
                                end
                            end
                        end
                    end
                end
            end
            if Offhand.ForeverPersistence then
                Offhand.ForeverPersistence:SaveOpenPanels(Offhand.db.openWorkspacePanels)
            end
        elseif not preserveWorkspaceSnapshot then
            if Offhand.db then
                Offhand.db.openWorkspacePanels = {}
                if Offhand.ForeverPersistence then
                    Offhand.ForeverPersistence:SaveOpenPanels(Offhand.db.openWorkspacePanels)
                end
            end
        end
        -- The complete Forever snapshot must be written after open-panel
        -- capture. Otherwise its older embedded visibility table wins over the
        -- newer field-specific CVar on the next /reload.
        if Offhand.ForeverPersistence and Offhand.ForeverPersistence.SaveProfileSnapshot then
            Offhand.ForeverPersistence:SaveProfileSnapshot(true)
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        Offhand._openPanelsCapturedForTransition = false
        local shouldEvaluateNotices = not Offhand._hasEnteredWorld
        Offhand._hasEnteredWorld = true
        -- Refresh viewport and layout after zone transition or loading screen
        C_Timer.After(0.5, function()
            Offhand:ApplyFullLayout()
            local entryMetrics = Offhand.Viewport and Offhand.Viewport.GetMetrics and Offhand.Viewport:GetMetrics()
            if Offhand.RawMouse and Offhand.RawMouse.Refresh then
                Offhand.RawMouse:Refresh(entryMetrics)
            end
            if (not entryMetrics or entryMetrics.isSpanned) and Offhand.Canvas and Offhand.Canvas.RestorePersistentFrames then
                Offhand.Canvas:RestorePersistentFrames()
            end
            if Offhand.Canvas and Offhand.Canvas.RequestPersistentWorldMapRefocus then
                Offhand.Canvas:RequestPersistentWorldMapRefocus()
            end

            -- PLAYER_ENTERING_WORLD also fires after zone transitions. Setup
            -- guidance is a once-per-UI-session check, delayed until Companion
            -- and display-size handoffs have had time to settle.
            if shouldEvaluateNotices then
                C_Timer.After(1.0, function()
                    EvaluateEntryNotices(1)
                end)
            end
        end)

    elseif event == "PLAYER_CONTROL_LOST" then
        Offhand._playerControlLost = true
        Offhand:DeferAutomaticUIForCinematic()
        Offhand:HideCompanionNotices()
        if Offhand.Onboarding and Offhand.Onboarding.Close then Offhand.Onboarding:Close() end
        if Offhand.Wizard and Offhand.Wizard.Close then Offhand.Wizard:Close() end

    elseif event == "PLAYER_CONTROL_GAINED" then
        Offhand._playerControlLost = nil
        if Offhand.Canvas and Offhand.Canvas.persistentRestorePendingForInput
            and Offhand.Canvas.RestorePersistentFrames then
            Offhand.Canvas:RestorePersistentFrames()
        end
        if Offhand._automaticUIPendingAfterCinematic and C_Timer and C_Timer.After then
            C_Timer.After(0.5, function() EvaluateEntryNotices(1) end)
        end

    elseif event == "PLAY_MOVIE" then
        ScheduleCinematicSkipDialogRecovery()

    elseif event == "CINEMATIC_START" or event == "CINEMATIC_STOP" then
        if event == "CINEMATIC_START" then
            Offhand._cinematicEventActive = true
            ScheduleCinematicSkipDialogRecovery()
            local welcomePending = not (Offhand.IsWelcomeDismissed and Offhand:IsWelcomeDismissed())
                or (Offhand.GetOnboardingResumeStep and Offhand:GetOnboardingResumeStep() ~= nil)
            if welcomePending or (Offhand._companionNoticesShown and next(Offhand._companionNoticesShown))
                or (Offhand.HUD and Offhand.HUD.foreverRecoveryPromptShown) then
                Offhand:DeferAutomaticUIForCinematic()
            end
            Offhand:HideCompanionNotices()
            Offhand:HideForeverEditModeControlsPrompt()
            Offhand:HidePopup("OFFHAND_WELCOME_SPAN_WARNING")
            Offhand:HidePopup("OFFHAND_FOREVER_SINGLE_SCREEN_LAYOUT")
            Offhand:HidePopup("OFFHAND_FOREVER_RESTORE_LAYOUT")
            Offhand:HidePopup("OFFHAND_FOREVER_PARTY_FRAME_RECOVERY")
            if Offhand.HUD then Offhand.HUD.foreverRecoveryPromptShown = nil end
            if Offhand.Onboarding and Offhand.Onboarding.Close then Offhand.Onboarding:Close() end
            if Offhand.Wizard and Offhand.Wizard.Close then Offhand.Wizard:Close() end
        else
            Offhand._cinematicEventActive = nil
        end
        ScheduleCinematicViewportRecovery()
        if event == "CINEMATIC_STOP" then
            C_Timer.After(0.5, function()
                local metrics = Offhand.Viewport and Offhand.Viewport.GetMetrics
                    and Offhand.Viewport:GetMetrics() or nil
                if Offhand.RawMouse and Offhand.RawMouse.Refresh then
                    Offhand.RawMouse:Refresh(metrics)
                end
            end)
            if Offhand._automaticUIPendingAfterCinematic then
                C_Timer.After(0.75, function()
                    if Offhand:IsBlizzardInputReserved() then
                        EvaluateEntryNotices(1)
                        return
                    end
                    local metrics = Offhand.Viewport and Offhand.Viewport.GetMetrics
                        and Offhand.Viewport:GetMetrics() or nil
                    if Offhand.HUD and Offhand.HUD.UpdateForeverRecoveryLayout then
                        Offhand.HUD:UpdateForeverRecoveryLayout(metrics)
                    end
                    EvaluateEntryNotices(1)
                end)
            end
        end

    elseif event == "ZONE_CHANGED_NEW_AREA" or event == "ZONE_CHANGED"
        or event == "ZONE_CHANGED_INDOORS" then
        if Offhand.Canvas and Offhand.Canvas.RequestPersistentWorldMapRefocus then
            Offhand.Canvas:RequestPersistentWorldMapRefocus()
        end

    elseif event == "PLAYER_REGEN_ENABLED" then
        ProcessCombatQueue()

    elseif event == "UI_SCALE_CHANGED" or event == "DISPLAY_SIZE_CHANGED" then
        -- A Companion span can dispatch several size/scale notifications while
        -- Blizzard is still rebuilding UIParent and Edit Mode geometry. Treat
        -- the whole burst as one transition and restore saved panels only after
        -- the final canvas dimensions have settled.
        Offhand._displayGeometryGeneration = (Offhand._displayGeometryGeneration or 0) + 1
        local generation = Offhand._displayGeometryGeneration
        Offhand._displayGeometryTransitionActive = true
        if Offhand._displayDebounceTimer and Offhand._displayDebounceTimer.Cancel then
            Offhand._displayDebounceTimer:Cancel()
        end
        Offhand._displayDebounceTimer = C_Timer.NewTimer(0.75, function()
            if generation ~= Offhand._displayGeometryGeneration then return end
            Offhand._displayDebounceTimer = nil
            Offhand:RunOrQueueCombat(function()
                -- Combat may delay this callback beyond another display reset.
                -- Only the newest settled generation may restore geometry.
                if generation ~= Offhand._displayGeometryGeneration then return end
                Offhand:ApplyFullLayout()
                local displayMetrics = Offhand.Viewport and Offhand.Viewport.GetMetrics and Offhand.Viewport:GetMetrics()
                if Offhand.RawMouse and Offhand.RawMouse.Refresh then
                    Offhand.RawMouse:Refresh(displayMetrics)
                end
                if (not displayMetrics or displayMetrics.isSpanned) and Offhand.Canvas and Offhand.Canvas.RestorePersistentFrames then
                    Offhand.Canvas:RestorePersistentFrames()
                end
                if Offhand.Canvas and Offhand.Canvas.RefreshLeatrixMapCoordinateFonts then
                    Offhand.Canvas:RefreshLeatrixMapCoordinateFonts()
                end
                if generation == Offhand._displayGeometryGeneration then
                    Offhand._displayGeometryTransitionActive = false
                    Offhand:RefreshCompanionNoticeState(displayMetrics)
                end
            end)
        end)
    end
end)

-- Convenience master layout apply with reentrancy protection
local isApplyingLayout = false
local layoutPending = false

function Offhand:ApplyFullLayout()
    if not Offhand.db then return end
    if InCombatLockdown() then
        if not layoutPending then
            layoutPending = true
            self:RunOrQueueCombat(function()
                layoutPending = false
                Offhand:ApplyFullLayout()
            end)
        end
        return
    end
    if isApplyingLayout then return end
    isApplyingLayout = true

    local success, err = pcall(function()
        if Offhand.Viewport and Offhand.Viewport.ApplyGlobalScale then Offhand.Viewport:ApplyGlobalScale() end
        if Offhand.UpdateViewport then
            Offhand:UpdateViewport()
        end
        if Offhand.Mainhand and Offhand.Mainhand.Update then
            Offhand.Mainhand:Update("layout")
        end
        if Offhand.RetailFullscreen and Offhand.RetailFullscreen.Apply then
            Offhand.RetailFullscreen:Apply()
        end
        if Offhand.UpdateCanvas then
            Offhand:UpdateCanvas()
        end
        local metrics = Offhand.Viewport and Offhand.Viewport.GetMetrics and Offhand.Viewport:GetMetrics()
        if Offhand.Mainhand and Offhand.Mainhand.UpdateWindowModeLayout then
            Offhand.Mainhand:UpdateWindowModeLayout(metrics)
        end
        if Offhand.MainhandCompatibility and Offhand.MainhandCompatibility.UpdateClassicNativeBar then
            Offhand.MainhandCompatibility.UpdateClassicNativeBar(metrics)
        end
        if Offhand.MainhandCompatibility and Offhand.MainhandCompatibility.UpdateClassicRightContainer then
            Offhand.MainhandCompatibility.UpdateClassicRightContainer(metrics)
        end
        if Offhand.RawMouse and Offhand.RawMouse.Update then
            Offhand.RawMouse:Update(metrics)
        end
        if Offhand.HUD and Offhand.HUD.UpdateForeverRecoveryLayout then
            Offhand.HUD:UpdateForeverRecoveryLayout(metrics)
        end
        if Offhand.Canvas and Offhand.Canvas.PrepareSingleScreenRecovery then
            Offhand.Canvas:PrepareSingleScreenRecovery(metrics)
        end
        -- An open Options/Game Menu can still carry our old spanned offset.
        -- Refresh owned menu anchors even when the current canvas is unspanned.
        if Offhand.MenuPlacement then Offhand.MenuPlacement:Refresh() end
        if not metrics or metrics.isSpanned then
            if Offhand.UpdateSeamRedirect then
                Offhand:UpdateSeamRedirect()
            end
            for _, module in pairs(Offhand.modules) do
                if module.ApplyLayout then
                    module:ApplyLayout()
                end
            end
        end
    end)

    isApplyingLayout = false
    if not success then
        Offhand:Print(L["MSG_LAYOUT_ERROR"], tostring(err))
    end
end

-- ============================================================================
-- Primary Slash Command Registration (Registered immediately on load)
-- ============================================================================
SLASH_OFFHAND1 = "/offhand"
SLASH_OFFHAND2 = "/oh"
SLASH_OFFHAND3 = "/Offhand"

SlashCmdList["OFFHAND"] = function(msg)
    msg = strtrim(msg or ""):lower()
    local cmd, arg = strsplit(" ", msg, 2)

    if cmd == "notifycapture" then
        local hud = Offhand.HUD
        if not hud or not hud.ArmNotificationCapture then return end
        local action = strtrim(arg or "")
        if action == "stop" then
            hud:StopNotificationCapture()
            Offhand:Print("Notification capture stopped. Read it with /offhand notifycapture show before /reload.")
        elseif action == "show" then
            for _, report in ipairs(hud:GetNotificationCaptureReports() or { "not-armed" }) do
                Offhand:Print("Notification capture: %s.", report)
            end
        elseif action == "" or action == "start" then
            if hud:ArmNotificationCapture() then
                Offhand:Print("Notification capture armed for one hour (64 recent changes). After the popup, use /offhand notifycapture stop and /offhand notifycapture show before /reload.")
            else
                Offhand:Print("Notification capture requires Retail, timers and being out of combat.")
            end
        else
            Offhand:Print("Use /offhand notifycapture start, stop or show.")
        end
    elseif cmd == "diag" or cmd == "metrics" or cmd == "info" then
        local fullDiagnostics = strtrim(arg or "") == "full"
        local snapshot = Offhand.Viewport:CaptureDiagnostics()
        local vpStatus = snapshot.viewportMatches and L["MSG_DIAG_PASS"] or L["MSG_DIAG_MISMATCH"]
        Offhand:Print(L["MSG_DIAG_VIEWPORT"], vpStatus)
        local m = snapshot.metrics or (Offhand.Viewport and Offhand.Viewport:GetMetrics()) or {}
        local versions = Offhand:GetVersionDiagnostics(m)
        Offhand:Print("Versions: WoW=%s | Build=%s | Interface=%s | Client=%s | Offhand=%s.",
            versions.clientVersion, versions.clientBuild, versions.interfaceVersion,
            versions.clientProject, versions.addonVersion)
        Offhand:Print("Companion: Writer=%s | Paired=%s | Minimum=%s | Protocol=%s | Status=%s.",
            tostring(versions.companionWriter), tostring(versions.companionPaired),
            tostring(versions.companionMinimum), tostring(versions.companionProtocol),
            tostring(versions.companionStatus))
        local operating = Offhand:GetOperatingDiagnostics(m)
        Offhand:Print("State: Enabled=%s | Spanned=%s | Source=%s | Preset=%s | Mainhand=%s | Combat=%s | Setup=%s.",
            operating.enabled and "1" or "0", operating.spanned and "1" or "0",
            operating.topologySource, tostring(operating.layoutPreset),
            tostring(operating.mainhandPosition), operating.inCombat and "1" or "0",
            operating.setupComplete and "1" or "0")
        Offhand:Print("Display rectangles: Mainhand=(%d,%d %dx%d) | Workspace=(%d,%d %dx%d).",
            operating.mainhandLeft, operating.mainhandBottom,
            operating.mainhandWidth, operating.mainhandHeight,
            operating.workspaceLeft, operating.workspaceBottom,
            operating.workspaceWidth, operating.workspaceHeight)
        local physW, physH = m.physicalWidth or 0, m.physicalHeight or 0
        local screenW = GetScreenWidth()
        local screenH = GetScreenHeight()
        local effScale = UIParent and UIParent:GetEffectiveScale() or 1.0
        Offhand:Print(L["MSG_DIAG_FULL"],
            physW, physH, screenW, screenH, effScale, m.deckWidth or 0, (Offhand.db.deckWidthRatio or 0) * 100, m.gameWidth or 0, m.gameHeight or 0)
        if Offhand.isLegacyWrath then
            Offhand:Print("Legacy Wrath diagnostics: Interface=%s | Timer=%s | PhysicalSource=%s.",
                tostring(Offhand.tocVersion or "unknown"),
                Offhand.legacyTimerShim and "compat" or "native",
                tostring(Offhand.legacyPhysicalSizeSource or "unavailable"))
        end
        local topologyDiag = Offhand.Viewport:GetTopologyDiagnostics()
        if fullDiagnostics or topologyDiag.status ~= "READY" then
            Offhand:Print("Topology diagnostics: state=%s | loaded=%s | schema=%s | expected=%sx%s | live=%dx%d | canvas=%.0fx%.0f.",
                tostring(topologyDiag.status or "UNKNOWN"),
                topologyDiag.loaded and "yes" or "no",
                tostring(topologyDiag.schema or "none"),
                tostring(topologyDiag.expectedWidth or "unknown"),
                tostring(topologyDiag.expectedHeight or "unknown"),
                topologyDiag.liveWidth, topologyDiag.liveHeight,
                topologyDiag.canvasWidth, topologyDiag.canvasHeight)
        end
        if (fullDiagnostics or (m.isSpanned and not m.companionTopology))
            and Offhand.ManualCanvas and Offhand.ManualCanvas.GetDiagnostics then
            local manual = Offhand.ManualCanvas:GetDiagnostics()
            Offhand:Print("Manual canvas diagnostics: state=%s | preference=%s | remembered=%d | selected=%s | source=%s | candidates=%d.",
                tostring(manual.state), tostring(manual.preference), manual.count or 0,
                tostring(manual.name or manual.id or "none"),
                tostring(manual.source or "none"), manual.candidateCount or 0)
        end
        if Offhand.isForever then
            local persistence = Offhand.foreverPersistenceDiagnostics or {}
            if fullDiagnostics then
                Offhand:Print("Forever persistence diagnostics: source=%s | bridge=%s | session=%s | diskRevision=%s | activeRevision=%s.",
                    tostring(persistence.source or "unknown"),
                    tostring(persistence.bridge or "unknown"),
                    tostring(persistence.sessionFallback or "unknown"),
                    tostring(persistence.diskRevision or "none"),
                    tostring(persistence.activeRevision or "none"))
            else
                Offhand:Print("Forever persistence diagnostics: source=%s | bridge=%s | session=%s.",
                    tostring(persistence.source or "unknown"),
                    tostring(persistence.bridge or "unknown"),
                    tostring(persistence.sessionFallback or "unknown"))
            end
        end
        if Offhand.isForever and Offhand.HUD and Offhand.HUD.GetForeverEditModeLayoutStatus then
            local editMode = Offhand.HUD:GetForeverEditModeLayoutStatus()
            Offhand:Print("Forever Edit Mode diagnostics: preferred=%s | preferredID=%s | available=%s | active=%s | activeID=%s | match=%s | recovery=%s.",
                tostring(editMode.preferredName or "unset"),
                tostring(editMode.preferredID or "unresolved"),
                editMode.preferredAvailable and "yes" or "no",
                tostring(editMode.activeName or (editMode.activeIsCustom and "unknown" or "built-in/unavailable")),
                tostring(editMode.activeID or "unknown"),
                editMode.activeMatches and "yes" or "no",
                editMode.recoveryPending and "pending" or "none")
        end
        -- Keep historical feature probes available on demand. Default reports
        -- must not enumerate native HUD trees or collect animation/debug state.
        if fullDiagnostics then
            if Offhand.HUD and Offhand.HUD.GetNotificationCaptureReports then
                for _, report in ipairs(Offhand.HUD:GetNotificationCaptureReports() or {}) do
                    Offhand:Print("Notification capture: %s.", report)
                end
            end
            Offhand:Print("Cinematic skip-dialog diagnostics: %s.",
                tostring(Offhand._cinematicSkipDialogStatus or "not-attached"))
            if Offhand.MainhandCompatibility and Offhand.MainhandCompatibility.GetClassicRightContainerDiagnostics then
                Offhand:Print("Classic tracker placement: %s.", Offhand.MainhandCompatibility.GetClassicRightContainerDiagnostics())
            end
            if Offhand.PopupBounds and Offhand.PopupBounds.GetTooltipPresentationDiagnostics then
                for _, report in ipairs(Offhand.PopupBounds:GetTooltipPresentationDiagnostics()) do
                    Offhand:Print("Tooltip presentation: %s.", report)
                end
                if Offhand.PopupBounds.ArmTooltipPresentationCapture
                    and Offhand.PopupBounds:ArmTooltipPresentationCapture() then
                    Offhand:Print("Tooltip capture armed for 30 seconds: hover an item to capture its visible backdrop.")
                end
            end
            if Offhand.HUD and Offhand.HUD.GetInteractionVisibilityDiagnostics then
                for _, report in ipairs(Offhand.HUD:GetInteractionVisibilityDiagnostics(m)) do
                    Offhand:Print("Interaction visibility: %s.", report)
                end
            end
            local perf = Offhand.Viewport:GetWorldTextDiagnostics(m)
            Offhand:Print("Combat text diagnostics: Current=%s | Original=%s | CVar=%s | Method=%s | Enabled=%s | FineTune=%.2f | HeightRatio=%.4f | AppliedRatio=%.4f.",
                perf.worldTextScale, tostring(perf.originalWorldTextScale or "unmanaged"),
                perf.worldTextScaleCVar,
                perf.worldTextMethod, perf.worldTextCompensationEnabled and "yes" or "no",
                perf.worldTextFineTune, perf.worldTextHeightRatio,
                perf.worldTextCompensationRatio)
            if Offhand.modules.ChatBubbles and Offhand.modules.ChatBubbles.GetDiagnostics then
                local bubbles = Offhand.modules.ChatBubbles:GetDiagnostics()
                Offhand:Print("Speech bubble diagnostics: Supported=%s | Visible=%d | Enabled=%s | FineTune=%.2f | Mode=%s | Conflict=%s | Replacements=%d.",
                    bubbles.supported and "yes" or "no", bubbles.visible or 0,
                    bubbles.foreverEnabled and "yes" or "no",
                    bubbles.foreverFineTune or 1,
                    tostring(bubbles.replacementMode or "native"),
                    tostring(bubbles.replacementConflict or "none"),
                    bubbles.visualManaged or 0)
            end
            if Offhand.HUD and Offhand.HUD.GetGroupLootDiagnostics then
                local loot = Offhand.HUD:GetGroupLootDiagnostics()
                Offhand:Print("Group loot diagnostics: Loaded=%s | Preload=%s | SecureAnchor=%s | RowMover=%s/%s | Rows=%d | Position=%s | Stack=%s | Preview=%s | Conflict=%s | Triggers=%d | Combat=%s.",
                    loot.loaded and "yes" or "no",
                    loot.preloadAttempted and "yes" or "no",
                    loot.anchorPrepared and "yes" or "no",
                    loot.rowMoverPrepared and "yes" or "no",
                    loot.rowMoverActive and "active" or "inactive",
                    loot.rowsMoved or 0,
                    loot.customPosition and "custom" or "default",
                    tostring(loot.stackDirection or "UP"),
                    loot.moverShown and "shown" or "hidden",
                    tostring(loot.conflict or "none"),
                    loot.triggerCount or 0,
                    loot.inCombat and "yes" or "no")
            end
            if Offhand.HUD and Offhand.HUD.GetPetBattleDiagnostics then
                local petBattle = Offhand.HUD:GetPetBattleDiagnostics()
                Offhand:Print("Pet battle diagnostics: Loaded=%s | Preload=%s | Bounds=%s | Conflict=%s | Combat=%s.",
                    petBattle.loaded and "yes" or "no",
                    petBattle.preloadAttempted and "yes" or "no",
                    petBattle.boundsPrepared and "prepared" or "unmanaged",
                    tostring(petBattle.conflict or "none"),
                    petBattle.inCombat and "yes" or "no")
            end
            if Offhand.HUD and Offhand.HUD.GetForeverGroupFrameDiagnostics then
                local groupFrames = Offhand.HUD:GetForeverGroupFrameDiagnostics()
                if groupFrames then Offhand:Print("Group frame diagnostics: %s.", groupFrames) end
            end
            if Offhand.HUD and Offhand.HUD.GetForeverProtectedHUDDiagnostics then
                local protectedHUD = Offhand.HUD:GetForeverProtectedHUDDiagnostics(m)
                if protectedHUD then Offhand:Print("Protected HUD diagnostics: %s.", protectedHUD) end
            end
        end
        if Offhand.Mainhand and Offhand.Mainhand.GetEditModeDiagnostics then
            Offhand:Print("Edit Mode layout diagnostics: %s.",
                Offhand.Mainhand:GetEditModeDiagnostics(not fullDiagnostics))
        end
        if Offhand.Canvas and Offhand.Canvas.GetCompatibilityDiagnostics then
            local compatibility = Offhand.Canvas:GetCompatibilityDiagnostics(not fullDiagnostics)
            if compatibility then
                Offhand:Print("Compatibility diagnostics: %s.", compatibility)
            end
        end
        if fullDiagnostics and Offhand.Canvas and Offhand.Canvas.GetPanelControllerDiagnostics then
            Offhand:Print("Panel controller diagnostics: %s.",
                Offhand.Canvas:GetPanelControllerDiagnostics())
        end
        if fullDiagnostics and Offhand.DialogueUICompat and Offhand.DialogueUICompat.GetDiagnostics then
            Offhand:Print("Dialogue UI diagnostics: %s.",
                Offhand.DialogueUICompat:GetDiagnostics())
        end
        if Offhand.UserMedia and Offhand.UserMedia.GetDiagnostics then
            local media = Offhand.UserMedia:GetDiagnostics()
            if fullDiagnostics then
                Offhand:Print("User media diagnostics: status=%s | installed=%s | enabled=%s | schema=%s | generator=%s | image=%sx%s | texture=%sx%s | fit=%s | reason=%s.",
                    tostring(media.status), media.installed and "yes" or "no",
                    media.enabled and "yes" or "no", tostring(media.schema or "none"),
                    tostring(media.generatorVersion or "none"),
                    tostring(media.imageWidth or "unknown"), tostring(media.imageHeight or "unknown"),
                    tostring(media.textureWidth or "unknown"), tostring(media.textureHeight or "unknown"),
                    tostring(media.fit or "none"), tostring(media.reason or "none"))
            elseif media.installed or media.status == "INVALID" then
                Offhand:Print("User media diagnostics: status=%s | enabled=%s | fit=%s | reason=%s.",
                    tostring(media.status), media.enabled and "yes" or "no",
                    tostring(media.fit or "none"), tostring(media.reason or "none"))
            end
        end
        if not fullDiagnostics then Offhand:Print("More detail: /offhand diag full.") end
    elseif cmd == "remember" then
        local preview = Offhand.Viewport and Offhand.Viewport.GetManualPreviewMetrics
            and Offhand.Viewport:GetManualPreviewMetrics() or nil
        local requestedName = arg
        local source = "MANUAL"
        if string.lower(arg or "") == "fancyzones" then
            requestedName = "FancyZones"
            source = "FANCYZONES"
        end
        local ok, id, record
        if Offhand.ManualCanvas then
            ok, id, record = Offhand.ManualCanvas:RememberFromMetrics(preview, requestedName, source)
        end
        if ok then
            Offhand:Print(L["MSG_MANUAL_CANVAS_REMEMBERED"], record.name,
                record.referenceWidth, record.referenceHeight)
            Offhand:ApplyFullLayout()
        else
            Offhand:Print(L["MSG_MANUAL_CANVAS_REMEMBER_FAILED"], tostring(id or "unavailable"))
        end
    elseif cmd == "geometry" then
        local value = string.upper(arg or "")
        if Offhand.ManualCanvas and Offhand.ManualCanvas:SetGeometryPreference(value) then
            Offhand:Print(L["MSG_GEOMETRY_SOURCE_CHANGED"], value)
            Offhand:ApplyFullLayout()
        else
            Offhand:Print(L["MSG_GEOMETRY_SOURCE_USAGE"])
        end
    elseif msg == "apply" or msg == "reload" then
        Offhand:ApplyFullLayout()
        Offhand:Print(L["LAYOUT_REAPPLIED"])
    elseif msg == "reset" then
        Offhand:ResetConfig()
    elseif msg == "toggle" then
        if Offhand.SetEnabled then
            Offhand:SetEnabled(not Offhand.db.enabled)
        else
            Offhand.db.enabled = not Offhand.db.enabled
        end
        Offhand:Print(L["MSG_TOGGLED"], Offhand.db.enabled and L["MSG_TOGGLE_ON"] or L["MSG_TOGGLE_OFF"])
        Offhand:ApplyFullLayout()
    elseif msg == "debug" then
        Offhand.db.debugMode = not Offhand.db.debugMode
        Offhand:Print(L["MSG_DEBUG_TOGGLED"], Offhand.db.debugMode and L["MSG_DEBUG_ON"] or L["MSG_DEBUG_OFF"])
    elseif cmd == "guide" or cmd == "setup" then
        if Offhand.Onboarding and Offhand.Onboarding.Open then
            Offhand.Onboarding:Open()
        elseif Offhand.Wizard and Offhand.Wizard.Open then
            Offhand.Wizard:Open()
        end
    elseif cmd == "wizard" or cmd == "calibrate" or cmd == "span" then
        if Offhand.Wizard and Offhand.Wizard.Open then
            Offhand.Wizard:Open()
        elseif Offhand.Options and Offhand.Options.Open then
            Offhand.Options:Open(true)
        end
    elseif cmd == "gather" then
        if Offhand.GatherOffScreenUI then
            Offhand:GatherOffScreenUI()
        end
    elseif cmd == "antishimmer" or cmd == "shimmer" then
        if Offhand.SetAntiShimmer then
            local newState
            if arg == "on" or arg == "1" or arg == "true" then
                newState = true
            elseif arg == "off" or arg == "0" or arg == "false" then
                newState = false
            else
                newState = not (Offhand.IsAntiShimmerEnabled and Offhand:IsAntiShimmerEnabled())
            end
            Offhand:SetAntiShimmer(newState)
            Offhand:Print(newState and L["MSG_ANTI_SHIMMER_ON"] or L["MSG_ANTI_SHIMMER_OFF"])
            if Offhand.Options and Offhand.Options.RefreshPanel then
                Offhand.Options:RefreshPanel()
            end
        end
    else
        if Offhand.Options and Offhand.Options.Open then
            Offhand.Options:Open()
        else
            Offhand:Print(L["MSG_STATUS"],
                Offhand.db.enabled and L["MSG_TOGGLE_ON"] or L["MSG_TOGGLE_OFF"])
        end
    end
end

SlashCmdList["Offhand"] = SlashCmdList["OFFHAND"]



-- Emergency bag layout rescue on logout
local logoutFix = CreateFrame('Frame')
logoutFix:RegisterEvent('PLAYER_LOGOUT')
logoutFix:SetScript('OnEvent', function()
    if Offhand.RawMouse and Offhand.RawMouse.Restore then
        Offhand.RawMouse:Restore()
    end
    if Offhand.Viewport and Offhand.Viewport.Reset then
        Offhand.Viewport:Reset()
    end
    local db = Offhand.db
    if db then
        if db.originalUiScale and SetCVar then
            SetCVar("uiScale", db.originalUiScale)
        end
        if db.originalUseUiScale and SetCVar then
            SetCVar("useUiScale", db.originalUseUiScale)
        end
        local cvarSetter = SetCVar or (C_CVar and C_CVar.SetCVar)
        if db.originalWorldTextScale and cvarSetter then
            local cvarName = db.originalWorldTextScaleCVar
            if not cvarName then
                local getter = GetCVar or (C_CVar and C_CVar.GetCVar)
                local ok, value = getter and pcall(getter, "WorldTextScale_v2")
                cvarName = ok and value ~= nil and "WorldTextScale_v2"
                    or "WorldTextScale"
            end
            cvarSetter(cvarName, db.originalWorldTextScale)
        end
        if db.originalNameplateSize and SetCVar then
            SetCVar("nameplateSize", db.originalNameplateSize)
        end
        if db.originalFriendlyPlayerName ~= nil and SetCVar then
            SetCVar("UnitNameFriendlyPlayerName", db.originalFriendlyPlayerName)
        end
    end

    -- A disabled profile must be completely inert. The viewport/CVar cleanup
    -- above is still safe and necessary if Offhand was disabled mid-session,
    -- but rewriting Blizzard bag anchors would modify the player's layout even
    -- though Offhand no longer owns it.
    if not db or not db.enabled then return end

    for i = 1, 13 do
        local bag = _G['ContainerFrame'..i]
        if bag then
            bag:ClearAllPoints()
            if i == 1 then
                bag:SetPoint('BOTTOMRIGHT', UIParent, 'BOTTOMRIGHT', -34, 70)
                bag:SetUserPlaced(true)
            else
                bag:SetUserPlaced(false)
            end
        end
    end
end)





-- A window is reachable when enough of its title edge is inside a visible area.
-- Use UIParent units throughout, including when the window has its own scale.
function Offhand:IsWindowReachable(left, top, width, m)
    local function InArea(x1, y1, x2, y2)
        return top >= y1 + 16 and top <= y2 + 2
            and math.min(left + width, x2) - math.max(left, x1) >= math.min(48, width)
    end
    if not m.isSpanned then return InArea(0, 0, m.screenWidth, m.screenHeight) end
    if InArea(m.gameLeft, m.gameBottom, m.gameRight, m.gameTop) then return true end
    if m.workspaceLeft ~= nil then
        return InArea(m.workspaceLeft, m.workspaceBottom, m.workspaceRight, m.workspaceTop)
    end
    local deckLeft = self.db.primaryPosition == "LEFT" and (m.gameRight + (m.bezel or 0)) or 0
    return InArea(deckLeft, 0, deckLeft + m.deckWidth, m.screenHeight)
end

function Offhand:GatherOffScreenUI()
    if InCombatLockdown() then self:Print(self.L["GATHER_COMBAT"]); return 0 end
    local m = self.Viewport and self.Viewport:GetMetrics()
    if not m then return 0 end
    local parentScale = UIParent:GetEffectiveScale() or 1
    local candidates = {}
    for name in pairs(UIPanelWindows or {}) do
        if _G[name] then candidates[_G[name]] = true end
    end
    if UIParent.GetChildren then
        for _, child in ipairs({ UIParent:GetChildren() }) do
            pcall(function()
                if child.IsForbidden and child:IsForbidden() then return end
                if child.IsMovable and child:IsMovable() then candidates[child] = true end
            end)
        end
    end
    local moved = 0
    for frame in pairs(candidates) do
        local ok, recovered = pcall(function()
            if frame == WorldFrame or frame == self.canvas then return false end
            if frame.IsForbidden and frame:IsForbidden() then return false end
            if not frame:IsShown() or frame:IsProtected() then return false end
            if frame.IsObjectType and frame:IsObjectType("GameTooltip") then return false end
            local scale = frame:GetEffectiveScale()
            if not scale or scale <= 0 then return false end
            local factor = scale / parentScale
            local left, top, width = frame:GetLeft(), frame:GetTop(), frame:GetWidth()
            if not left or not top or not width or width <= 0 then return false end
            if self:IsWindowReachable(left * factor, top * factor, width * factor, m) then return false end
            local x = (m.gameLeft + m.gameRight - UIParent:GetWidth()) / 2
            local y = (m.gameBottom + m.gameTop - UIParent:GetHeight()) / 2
            frame:ClearAllPoints()
            frame:SetPoint("CENTER", UIParent, "CENTER", x / factor, y / factor)
            return true
        end)
        if ok and recovered then moved = moved + 1 end
    end
    self:Print(string.format(self.L["GATHER_RESULT"], moved))
    return moved
end



local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function()
    local tooltips = { "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2", "SettingsTooltip" }

    local function HasActiveSpannedLayout()
        if not Offhand.db or not Offhand.db.enabled then return false end
        if Offhand.Viewport and Offhand.Viewport.GetMetrics then
            local ok, metrics = pcall(Offhand.Viewport.GetMetrics, Offhand.Viewport)
            if ok and metrics and metrics.isSpanned == false then return false end
        end
        return true
    end
    
    -- Dynamically find any other global tooltips safely
    for key, val in pairs(_G) do
        if type(key) == "string" and string.match(key, "Tooltip") and type(val) == "table" and type(rawget(val, 0)) == "userdata" and val.GetObjectType then
            local ok, objType = pcall(function() return val:GetObjectType() end)
            if ok and objType == "GameTooltip" then
                local found = false
                for _, v in ipairs(tooltips) do if v == key then found = true end end
                if not found then table.insert(tooltips, key) end
            end
        end
    end

    local function EnforceTooltipScale(self)
        if not Offhand.isRetail and not Offhand.isForever then return end
        if (InCombatLockdown and InCombatLockdown()) or not UIParent or not HasActiveSpannedLayout() then return end
        if self.SetIgnoreParentScale and self.IsIgnoringParentScale and self:IsIgnoringParentScale() then
            self:SetIgnoreParentScale(false)
        end
        
        -- Mathematically calculate the exact local scale required to make the tooltip's absolute size match UIParent.
        -- This flawlessly handles tooltips parented to UIParent (requiring 1.0) AND tooltips parented to WorldFrame (requiring 0.39).
        if self.GetScale then
            local desiredAbsolute = UIParent:GetEffectiveScale() or 1
            local parentAbsolute = (self:GetParent() and self:GetParent():GetEffectiveScale()) or 1
            local desiredLocal = desiredAbsolute / parentAbsolute
            
            if math.abs(self:GetScale() - desiredLocal) > 0.01 then
                self:SetScale(desiredLocal)
            end
        end
    end
    
    if (Offhand.isRetail or Offhand.isForever) and SharedTooltip_SetBackdropStyle then
        hooksecurefunc("SharedTooltip_SetBackdropStyle", EnforceTooltipScale)
    end
    
    for _, name in ipairs(tooltips) do
        local tt = _G[name]
        if tt then
            if Offhand.PopupBounds and Offhand.PopupBounds.ObserveTooltip then
                Offhand.PopupBounds:ObserveTooltip(tt)
            end
            if (Offhand.isRetail or Offhand.isForever) and tt.HookScript then
                tt:HookScript("OnShow", EnforceTooltipScale)
                tt:HookScript("OnSizeChanged", EnforceTooltipScale)
            end
            if (Offhand.isRetail or Offhand.isForever) and tt.SetOwner then
                hooksecurefunc(tt, "SetOwner", EnforceTooltipScale)
            end
            if (Offhand.isRetail or Offhand.isForever) and tt.SetIgnoreParentScale then
                if (not InCombatLockdown or not InCombatLockdown()) and HasActiveSpannedLayout() then tt:SetIgnoreParentScale(false) end
                hooksecurefunc(tt, "SetIgnoreParentScale", function(self, ignore)
                    if InCombatLockdown and InCombatLockdown() then return end
                    if ignore and HasActiveSpannedLayout() then self:SetIgnoreParentScale(false) end
                end)
            end
        end
    end
end)
