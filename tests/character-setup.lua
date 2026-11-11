-- Real config, character identity, read-only layout reuse and entry dispatch.
-- Native layouts, timers and popup presentation are mocked, not live evidence.
local player, guid, geometry = "First", "Player-first", "span-A"
local combat, reserved, gamepad = false, false, false
local spanned = false
local data = {activeLayout = 1, layouts = {{layoutName = "Offhand", systems = {{anchorInfo = {offsetX = 123}}}}}}
local cvars, timers, entryEvent = {}, {}, nil
local selections, saves, reloads, guides, hudSteps, popupCount = 0, 0, 0, 0, 0, 0
local currentPopup, currentStatus
local notices = {}
StaticPopupDialogs, SlashCmdList = {}, {}
strtrim = function(value) return value:match("^%s*(.-)%s*$") end
GetBuildInfo = function() return "1.60.1", "70790", "synthetic", 16001 end
GetLocale = function() return "enUS" end
UnitName = function() return player end
UnitGUID = function() return guid end
UnitFullName = function() return player, "Realm" end
GetNormalizedRealmName = function() return "Realm" end
InCombatLockdown = function() return combat end
RegisterCVar = function(name, default) if cvars[name] == nil then cvars[name] = default or "" end end
GetCVar = function(name) return cvars[name] end
SetCVar = function(name, value) cvars[name] = tostring(value) end
local function QueueTimer(_, callback) timers[#timers + 1] = callback end
C_Timer = {After = QueueTimer, NewTimer = function(delay, callback) QueueTimer(delay, callback); return {} end}
UIParent = {GetEffectiveScale = function() return 1 end}
GetScreenWidth = function() return 1920 end
CreateFrame = function(_, name) return {
    RegisterEvent = function() end,
    SetScript = function(_, event, callback)
        if name == "OffhandEventFrame" and event == "OnEvent" then entryEvent = callback end
    end,
} end
local presets = {{layoutName = "Modern"}, {layoutName = "Classic"}, {layoutName = "Gamepad"}}
EditModePresetLayoutManager = {GetCopyOfPresetLayouts = function() return presets end}
C_EditMode = {
    GetLayouts = function() return data end,
    SaveLayouts = function() saves = saves + 1; error("character reuse must never rewrite layouts") end,
    SetActiveLayout = function(id) selections = selections + 1; data.activeLayout = id end,
}
local addon = {}
assert(loadfile("Core/Init.lua"))("Offhand", addon)
assert(loadfile("Core/ClientRuntime.lua"))("Offhand", addon)
assert(loadfile("Locales/enUS.lua"))("Offhand", addon)
assert(loadfile("Core/Config.lua"))("Offhand", addon)
OffhandDB = {
    onboarding = {setupComplete = true, welcomeDismissed = true},
    profiles = {Default = {enabled = true, deckWidthRatio = 0.4}},
    sharedMainhandLayouts = {Offhand = {version = 1, client = "forever", ownershipSignature = "",
        geometrySignature = "span-A", sourceName = "Modern", sourceID = 1, sourcePreset = true}},
}
OffhandCharDB = {}
addon:InitializeConfig()
addon.Mainhand = {GetRect = function() return {isSpanned = true} end,
    GetGeometrySignature = function() return geometry end}
addon.MainhandCompatibility = {IsNativeGamepadInterface = function() return gamepad end,
    IsControllerMode = function() return gamepad end}
addon.MainhandGeometry = {}
assert(loadfile("Core/MainhandEditMode.lua"))("Offhand", addon)
addon.Mainhand.PromptReload = function() reloads = reloads + 1 end
addon.HasBlizzardEditMode = function() return true end
addon.IsGamepadUIEnabled = function() return gamepad end
addon.IsBlizzardInputReserved = function() return reserved end
addon.Viewport = {GetMetrics = function() return {isSpanned = spanned} end}
addon.ApplyFullLayout = function() end
addon.Print = function(_, message) notices[#notices + 1] = message end
addon.Onboarding = {Open = function() guides = guides + 1 end}
addon.Wizard = {OpenHUDSetup = function() hudSteps = hudSteps + 1 end}
addon.ShowPopup = function(_, key, status)
    currentPopup, currentStatus = key, status
    popupCount = popupCount + 1
    return {}
end
addon.HidePopup = function(_, key)
    if currentPopup == key then
        currentPopup = nil
        local definition = StaticPopupDialogs[key]
        if definition and definition.OnHide then definition.OnHide() end
    end
end
local function LoadCheck()
    assert(loadfile("Core/CharacterSetup.lua"))("Offhand", addon)
    return addon.CharacterSetup
end
local function Click(handler)
    local definition = assert(StaticPopupDialogs[currentPopup])
    addon:HidePopup(currentPopup)
    definition[handler](nil, nil, "clicked")
end
local function NewCharacter(name, identity)
    player, guid, OffhandCharDB = name, identity, {}
    addon:InitializeConfig()
    return LoadCheck()
end

local check = LoadCheck()
assert(OffhandCharDB.hudSetupReminder, "new character must be marked independently of account completion")
local beforePopups = popupCount
reserved = true
entryEvent(nil, "PLAYER_ENTERING_WORLD")
table.remove(timers, 1)()
table.remove(timers, 1)()
assert(#notices == 0 and popupCount == beforePopups, "first login must defer guidance during the intro")
reserved = false
table.remove(timers, 1)()
assert(currentPopup == "OFFHAND_CHARACTER_SETUP" and currentStatus == addon.L.CHARACTER_SETUP_WAITING_FOR_SPAN
        and popupCount == beforePopups + 1 and #notices == 0 and guides == 0,
    "one-monitor entry must show the span instruction after the intro without relying on chat")
addon:RefreshMainhandLayoutAttention()
assert(popupCount == beforePopups + 1, "an open span notice must not be reopened on repeated refresh")
Click("OnAccept")
addon:RefreshMainhandLayoutAttention()
assert(popupCount == beforePopups + 1 and not currentPopup
        and OffhandCharDB.hudSetupReminder and not OffhandCharDB.hudSpanNoticeDismissed
        and not OffhandCharDB.characterSetup,
    "acknowledging the notice must keep HUD setup pending and avoid reopening the notice")
addon:InitializeConfig(); check = LoadCheck()
addon:RefreshMainhandLayoutAttention()
assert(currentStatus == addon.L.CHARACTER_SETUP_WAITING_FOR_SPAN and popupCount == beforePopups + 2,
    "Got it must dismiss the notice only until reload")
Click("OnCancel")
assert(OffhandCharDB.hudSpanNoticeDismissed and OffhandCharDB.hudSetupReminder
        and not OffhandCharDB.characterSetup and not OffhandCharDB.hudSetupReminderDeclined,
    "Don't show again must persist without deferring the HUD check")
addon:InitializeConfig(); check = LoadCheck()
addon:RefreshMainhandLayoutAttention()
assert(not currentPopup and popupCount == beforePopups + 2,
    "the dismissed span notice must stay hidden after reload")
OffhandDB, OffhandCharDB = {}, {}
addon:InitializeConfig(); check = LoadCheck()
addon:RefreshMainhandLayoutAttention()
assert(addon.foreverPersistenceDiagnostics.source == "session-fallback"
        and OffhandCharDB.hudSpanNoticeDismissed and not currentPopup and popupCount == beforePopups + 2,
    "the Forever fallback must retain the dismissal for this character")
spanned = true
entryEvent(nil, "DISPLAY_SIZE_CHANGED")
table.remove(timers, 1)()
assert(currentPopup == "OFFHAND_CHARACTER_SETUP", "a settled span must resume the deferred HUD check")
assert(currentStatus == addon.L.CHARACTER_SETUP_READY and saves == 0 and selections == 0,
    "automatic discovery must not activate or rewrite any layout")
assert(StaticPopupDialogs[currentPopup].button3 == addon.L.CHARACTER_SETUP_CUSTOMIZE)
addon:RefreshMainhandLayoutAttention()
assert(popupCount == beforePopups + 3, "character check must appear once per entry context")
EditModeManagerFrame = {IsShown = function() return true end}
Click("OnAccept")
assert(currentStatus == addon.L.CHARACTER_SETUP_RETRY and not OffhandCharDB.mainhandLayout
        and selections == 0 and saves == 0,
    "open Edit Mode must produce an actionable retry without claiming a missing layout")
EditModeManagerFrame = nil
Click("OnAccept")
assert(OffhandCharDB.characterSetup.choice == "existing" and OffhandCharDB.characterSetup.complete)
assert(OffhandCharDB.mainhandLayout.ownerGUID == guid and data.activeLayout == 4
        and saves == 0 and selections == 1 and reloads == 1,
    "Use existing must only activate the verified shared layout and associate this character")
assert(OffhandCharDB.mainhandLayout.sourceName == "Modern"
        and data.layouts[1].systems[1].anchorInfo.offsetX == 123,
    "selection must preserve rollback provenance and exact saved anchors")
assert(addon.db.deckWidthRatio == 0.4 and addon:IsSetupComplete() and guides == 0 and hudSteps == 0,
    "character reuse must leave monitor calibration, account guide and profile intact")
addon:InitializeConfig(); check = LoadCheck()
beforePopups = popupCount
addon:RefreshMainhandLayoutAttention()
assert(popupCount == beforePopups, "returning configured character must stay quiet after reload")

check = NewCharacter("Second", "Player-second")
addon.Wizard.IsOpen = function() return true end
assert(check:Refresh() and not currentPopup and popupCount == beforePopups,
    "the automatic HUD reminder must yield while the player is already in setup")
addon.Wizard.IsOpen = nil
addon.HUD = {foreverRecoveryPromptShown = "restore"}
assert(check:Refresh() and not currentPopup and popupCount == beforePopups,
    "automatic setup must not replace the recovery card on re-spanning")
addon.HUD = nil
addon:RefreshMainhandLayoutAttention()
assert(currentPopup == "OFFHAND_CHARACTER_SETUP" and not OffhandCharDB.mainhandLayout,
    "new character must receive its own check without inheriting character HUD ownership")
Click("OnCancel")
assert(OffhandCharDB.characterSetup.choice == "later" and OffhandCharDB.hudSetupReminderDeclined)
addon:InitializeConfig(); check = LoadCheck()
beforePopups = popupCount
addon:RefreshMainhandLayoutAttention()
assert(popupCount == beforePopups, "Later must remain quiet across reload without a legacy reminder")
assert(addon:CreateProfile("Second profile"))
addon:RefreshMainhandLayoutAttention()
assert(popupCount == beforePopups and OffhandCharDB.characterSetup.choice == "later"
        and not addon.db.characterSetup and addon.db.deckWidthRatio == 0.4,
    "profile creation must not duplicate or reset the character's choice")

-- Recover the per-character decision through the existing Forever full snapshot.
assert(addon.ForeverPersistence:SaveProfileSnapshot(true))
OffhandDB, OffhandCharDB = {}, {}
addon:InitializeConfig(); check = LoadCheck()
assert(addon.foreverPersistenceDiagnostics.source == "session-fallback"
        and OffhandCharDB.characterSetup.choice == "later")
beforePopups = popupCount
addon:RefreshMainhandLayoutAttention()
assert(popupCount == beforePopups, "Forever fallback must retain Later for this exact character")

geometry = "span-B"
addon:RefreshMainhandLayoutAttention()
assert(currentPopup == "OFFHAND_CHARACTER_SETUP" and currentStatus == addon.L.CHARACTER_SETUP_NO_LAYOUT,
    "changed display geometry must offer a check without adopting a mismatched layout")
local unavailable = StaticPopupDialogs[currentPopup]
assert(unavailable.button1 == addon.L.CHARACTER_SETUP_CUSTOMIZE
        and unavailable.button2 == addon.L.CHARACTER_SETUP_LATER
        and unavailable.button3 == nil and unavailable.OnAlt == nil,
    "the card must omit Use existing setup when no compatible HUD is available")
assert(not check:UseExisting())
assert(currentPopup == "OFFHAND_CHARACTER_SETUP" and OffhandCharDB.characterSetup.geometrySignature == "span-A"
        and saves == 0 and selections == 1, "failed reuse must not mark setup complete or create a layout")
Click("OnAccept")
assert(hudSteps == 1 and OffhandCharDB.characterSetup.choice == "customize"
        and not OffhandCharDB.characterSetup.complete and guides == 0,
    "Customize must open only HUD setup, preserving its incomplete status")

-- Recreated same-name characters cannot inherit acknowledgement or HUD state.
OffhandCharDB.hudSpanNoticeDismissed = true
guid = "Player-second-recreated"
assert(addon:EnsureCharacterIdentity() and not OffhandCharDB.characterSetup
        and OffhandCharDB.hudSetupReminder and not OffhandCharDB.hudSetupReminderDeclined
        and not OffhandCharDB.hudSpanNoticeDismissed)
check = LoadCheck()
combat = true
beforePopups = popupCount
addon:RefreshMainhandLayoutAttention()
assert(check.pendingCombat and popupCount == beforePopups)
combat = false
entryEvent(nil, "PLAYER_REGEN_ENABLED")
assert(currentPopup == "OFFHAND_CHARACTER_SETUP" and popupCount == beforePopups + 1,
    "deferred first-character check must open after combat")
Click("OnCancel")
gamepad = true
addon:RefreshMainhandLayoutAttention()
assert(currentPopup == "OFFHAND_CHARACTER_SETUP",
    "a changed input mode must recheck a previously deferred HUD")
check:Hide()
check.offeredContext = nil
reserved = true
beforePopups = popupCount
addon:RefreshMainhandLayoutAttention()
assert(popupCount == beforePopups and addon._automaticUIPendingAfterCinematic,
    "character check must defer to cinematic input")
reserved = false
addon:RefreshMainhandLayoutAttention()
assert(popupCount == beforePopups + 1)
entryEvent(nil, "CINEMATIC_START")
assert(not currentPopup and not check.shown and not check.offeredContext
        and addon._automaticUIPendingAfterCinematic,
    "a cinematic starting while the character check is visible must hide and defer it")
entryEvent(nil, "CINEMATIC_STOP")
addon:RefreshMainhandLayoutAttention()
assert(currentPopup == "OFFHAND_CHARACTER_SETUP", "the hidden check must be eligible again after playback")
addon.db.enabled = false
beforePopups = popupCount
check:Refresh()
assert(popupCount == beforePopups, "disabled profiles must not trigger character setup")
addon.db.enabled = true
cvars = {}
OffhandDB = {profiles = {Default = {enabled = true}}}
check = NewCharacter("Third", "Player-third")
beforePopups = popupCount
check:Refresh()
assert(popupCount == beforePopups and not OffhandCharDB.characterSetup,
    "unfinished account installation must take priority over character HUD choices")

OffhandDB.onboarding.setupComplete = true
OffhandCharDB.hudSetupReminder = nil
OffhandCharDB.mainhandLayoutDeferred = nil
addon.EllesmereLayout = {IsAvailable = function() return true end, ShowPreview = function() end}
addon.Mainhand.GetCharacterSetupLayoutStatus = function()
    return {available = true, ellesmereReview = true}
end
local reviewRequested
addon.Wizard.OpenHUDSetup = function(_, review) reviewRequested = review end
assert(check:Refresh() and currentStatus == addon.L.CHARACTER_SETUP_ELLESMERE
    and StaticPopupDialogs[currentPopup].button1 == addon.L.CHARACTER_SETUP_REVIEW,
    "enabling EllesmereUI on a configured span should offer its own review even without a generic HUD reminder")
Click("OnAccept")
assert(reviewRequested and saves == 0 and selections == 1 and reloads == 1,
    "review must open the EllesmereUI wizard step without changing the native layout")
print("PASS: character choices, reuse-only selection, profile isolation, GUID recreation, persistence and input deferral")
