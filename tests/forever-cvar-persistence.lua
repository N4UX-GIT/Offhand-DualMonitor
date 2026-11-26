-- Validates the Forever-only custom-CVar fallback for clients that write but
-- currently fail to reload normal SavedVariables.

local cvars = {}
local currentCharacterName = "Tester"
local currentCharacterRealm = "TestRealm"
UnitFullName = function() return currentCharacterName, currentCharacterRealm end
UnitName = function() return currentCharacterName end
UnitGUID = function() return "Player-" .. currentCharacterName end
GetNormalizedRealmName = function() return currentCharacterRealm end
local function ClearProfileSnapshotCVars()
    local count = tonumber(tostring(cvars.offhandForeverProfileManifest or ""):match(
        "^V1|%d+|(%d+)|")) or 0
    cvars.offhandForeverProfileManifest = nil
    for index = 1, count do cvars["offhandForeverProfileChunk_" .. index] = nil end
end
RegisterCVar = function(name, default)
    if cvars[name] == nil then cvars[name] = default end
end
SetCVar = function(name, value) cvars[name] = tostring(value) end
GetCVar = function(name) return cvars[name] end
C_CVar = nil
local clientBuild = "70009"
GetBuildInfo = function() return "1.60.1", clientBuild, "Sep 25 2026", 16001 end

local function NewAddon(isForever, accountDB, characterDB, recoveryVersion, diskState, characterRecovery)
    local addon = { isForever = isForever }
    addon.foreverDiskSavedVariables = diskState
    _G.Offhand = addon
    _G.OffhandDB = accountDB or {}
    _G.OffhandCharDB = characterDB or {}
    _G.OffhandForeverStateBridgeVersion = recoveryVersion
    _G.OffhandForeverCharacterRecovery = characterRecovery
    assert(loadfile("Core/Config.lua"))("Offhand", addon)
    assert(loadfile("Core/CanvasAddonEscape.lua"))("Offhand", addon)
    dofile("tests/support/core-bridges.lua").Load(addon, {"Bridges/RestedXP/Bridge.lua"})
    addon:InitializeConfig()
    return addon
end

local first = NewAddon(true)
assert(first.db.showGamepadPanelDragHandles == true,
    "Forever Gamepad drag handles must default to visible")
first.db.showGamepadPanelDragHandles = false
assert(first:IsExperimentalForeverProfessionsMovementEnabled(),
    "Forever Professions movement must default to enabled")
local compatibilityAccount = OffhandDB
local legacyDisabledAccount = {
    compatibility = { foreverProfessionsMovement = false },
}
local migratedProfessions = NewAddon(true, legacyDisabledAccount)
assert(migratedProfessions:IsExperimentalForeverProfessionsMovementEnabled()
        and OffhandDB.compatibility.foreverProfessionsMovementMigrationVersion == 1,
    "hidden legacy Professions opt-outs must migrate once to the enabled default")
assert(not migratedProfessions:SetExperimentalForeverProfessionsMovement(false),
    "the internal Professions compatibility API must still support disabling movement")
local migratedOptOutReload = NewAddon(true, OffhandDB)
assert(not migratedOptOutReload:IsExperimentalForeverProfessionsMovementEnabled(),
    "an API opt-out after migration must remain sticky")
local consentReload = NewAddon(true, compatibilityAccount)
assert(consentReload.db.showGamepadPanelDragHandles == false,
    "the Gamepad drag-handle visibility setting must remain profile-scoped")
assert(consentReload:IsExperimentalForeverProfessionsMovementEnabled(),
    "Professions movement must survive reload on the same client build")
clientBuild = "70010"
local changedBuild = NewAddon(true, compatibilityAccount)
assert(changedBuild:IsExperimentalForeverProfessionsMovementEnabled(),
    "a Forever client build change must retain enabled Professions movement")
assert(not changedBuild:SetExperimentalForeverProfessionsMovement(false),
    "the Advanced Compatibility option must support an explicit opt-out")
clientBuild = "70011"
local optedOutBuild = NewAddon(true, compatibilityAccount)
assert(not optedOutBuild:IsExperimentalForeverProfessionsMovementEnabled(),
    "an explicit Professions movement opt-out must remain sticky across builds")
clientBuild = "70009"
first:MarkWelcomeDismissed()
assert(cvars.offhandForeverOnboarding == "V3|1|0|0|0|0",
    "Acknowledging the welcome guide must persist in the Forever session fallback")
local onboardingReload = NewAddon(true)
assert(onboardingReload:IsWelcomeDismissed() and not onboardingReload:IsSetupComplete(),
    "Welcome acknowledgement must survive reload without falsely completing setup")
onboardingReload:SetOnboardingResumeStep(4)
onboardingReload:SetOnboardingSetupMethod("MANUAL")
local resumedOnboarding = NewAddon(true)
assert(resumedOnboarding:ConsumeOnboardingResumeStep() == 4,
    "Forever onboarding must restore its Reload UI resume step")
assert(resumedOnboarding:GetOnboardingSetupMethod() == "MANUAL",
    "Forever onboarding must restore the selected setup method")
resumedOnboarding:SetOnboardingSetupMethod("FANCYZONES")
local fancyZonesOnboarding = NewAddon(true)
assert(fancyZonesOnboarding:GetOnboardingSetupMethod() == "FANCYZONES",
    "Forever onboarding must preserve the FancyZones setup method")
onboardingReload:MarkSetupComplete()
local completedReload = NewAddon(true)
assert(completedReload:IsWelcomeDismissed() and completedReload:IsSetupComplete(),
    "Completed onboarding must survive Forever reloads")

first.ForeverPersistence:SaveWorkspacePosition(
    "ContainerFrameCombinedBags",
    { x = 274.8437194824219, y = 997.0802001953125, canvasHeight = 1697.8769 },
    320,
    220
)
assert(cvars.offhandForeverPositionIndex == "ContainerFrameCombinedBags", "Forever frame index must persist")

local reloaded = NewAddon(true)
local restored = reloaded.db.savedWorkspacePositions.ContainerFrameCombinedBags
assert(restored and math.abs(restored.x - 274.8437194824219) < 0.001, "Forever x coordinate must restore from its CVar")
assert(math.abs(restored.y - 997.0802001953125) < 0.001, "Forever y coordinate must restore from its CVar")
assert(restored.width == 320 and restored.height == 220, "Forever frame dimensions must restore from its CVar")
assert(math.abs(restored.canvasHeight - 1697.8769) < 0.001,
    "Forever capture canvas height must restore from its CVar")

reloaded.ForeverPersistence:SaveOpenPanels({
    ContainerFrameCombinedBags = true,
    WorldMapFrame = true,
    CharacterFrame = false,
})
assert(cvars.offhandForeverOpenPanels == "V1|ContainerFrameCombinedBags,WorldMapFrame",
    "Forever visibility snapshot must include its initialized marker")
local visibilityReload = NewAddon(true)
assert(visibilityReload.db.openWorkspacePanels.ContainerFrameCombinedBags == true,
    "Forever combined bag visibility must restore from its CVar")
assert(visibilityReload.db.openWorkspacePanels.WorldMapFrame == true,
    "Forever map visibility must restore from its CVar")
assert(visibilityReload.db.openWorkspacePanels.CharacterFrame == nil,
    "Closed Forever panels must remain closed")

visibilityReload.ForeverPersistence:SaveOpenPanels({})
local visibilityCleared = NewAddon(true)
assert(next(visibilityCleared.db.openWorkspacePanels) == nil,
    "An intentionally empty Forever open-panel set must remain empty")

-- Registered custom CVars reset when the executable closes. On a cold launch,
-- an empty CVar must not erase a valid visibility snapshot loaded from disk.
cvars.offhandForeverOpenPanels = nil
cvars.offhandForeverPositionIndex = nil
cvars.offhandForeverOnboarding = nil
local coldAccountDB = { profiles = { Default = {
    openWorkspacePanels = { CharacterFrame = true, WorldMapFrame = true },
    savedWorkspacePositions = { WorldMapFrame = { x = 12, y = 1685, canvasHeight = 1697 } },
    firstRunComplete = true,
} } }
local coldLaunch = NewAddon(true, coldAccountDB)
assert(coldLaunch.foreverPersistenceDiagnostics.source == "savedvariables"
        and coldLaunch.foreverPersistenceDiagnostics.bridge == "absent",
    "Cold-launch diagnostics must identify normal SavedVariables without a Companion bridge")
assert(coldLaunch.db.openWorkspacePanels.CharacterFrame == true
    and coldLaunch.db.openWorkspacePanels.WorldMapFrame == true,
    "Cold launch must preserve disk-loaded panel visibility")
assert(coldLaunch.db.savedWorkspacePositions.WorldMapFrame.x == 12,
    "Cold launch must preserve disk-loaded frame positions")
assert(coldLaunch:IsWelcomeDismissed() and coldLaunch:IsSetupComplete(),
    "Cold launch must migrate a completed legacy setup into account onboarding")

-- A generated cold-recovery snapshot must beat stale empty session CVars once,
-- then seed those CVars so user changes win on subsequent reloads.
cvars.offhandForeverOpenPanels = "V1|"
cvars.offhandForeverPositionIndex = ""
cvars.offhandForeverRecoveryVersion = nil
local recovered = NewAddon(true, coldAccountDB, nil, "snapshot-1")
assert(recovered.foreverPersistenceDiagnostics.source == "companion-bridge"
        and recovered.foreverPersistenceDiagnostics.bridge == "used",
    "Fresh bridge diagnostics must identify the Companion recovery source")
assert(recovered.db.openWorkspacePanels.CharacterFrame == true
    and recovered.db.openWorkspacePanels.WorldMapFrame == true,
    "Fresh bridge snapshot must beat stale empty visibility CVar")
assert(cvars.offhandForeverRecoveryVersion == "snapshot-1",
    "Fresh bridge snapshot must be marked consumed for this session")
assert(cvars.offhandForeverOpenPanels == "V1|CharacterFrame,WorldMapFrame",
    "Fresh bridge snapshot must seed the session visibility fallback")
assert(cvars.offhandForeverOnboarding == "V3|1|1|0|0|0",
    "Fresh bridge snapshot must seed Forever onboarding state")
recovered.ForeverPersistence:SaveOpenPanels({ CharacterFrame = true })
recovered.db.openWorkspacePanels = { CharacterFrame = true }
recovered.ForeverPersistence:SaveProfileSnapshot(true)
local sameSession = NewAddon(true, coldAccountDB, nil, "snapshot-1")
assert(sameSession.db.openWorkspacePanels.CharacterFrame == true
    and sameSession.db.openWorkspacePanels.WorldMapFrame == nil,
    "A consumed bridge snapshot must yield to later same-session visibility")
ClearProfileSnapshotCVars()

-- A cold launch can see a new bridge hash generated before the most recent
-- settings write. The captured disk revision must win even with empty session
-- CVars, and the next reload must continue to use those settings.
local oldBridgeAccount = {
    foreverPersistenceRevision = 2,
    onboarding = { setupComplete = false },
    profiles = { Default = { enabled = false } },
}
local currentDisk = {
    account = {
        foreverPersistenceRevision = 3,
        onboarding = { setupComplete = true, welcomeDismissed = true },
        profiles = {
            Default = { enabled = false },
            Raid = {
                enabled = true, rawMouseInput = false, chatPosition = "DECK",
                savedMainPositions = { CharacterFrame = { x = 2400, y = 980 } },
                savedWorkspacePositions = { WorldMapFrame = { x = 12, y = 80, regionId = "workspace-b" } },
                openWorkspacePanels = { WorldMapFrame = true, ContainerFrameCombinedBags = true },
                workspaceRegionScales = { version = 1, layouts = { desktop = { a = { size = 0.75, chat = true } } } },
            },
        },
    },
    character = { characterGUID = "Player-Tester", activeProfile = "Raid", foreverEditModeLayoutID = 19, hudSetupReminderDeclined = true },
}
local function AssertCurrentDiskPreferences(addon)
    assert(OffhandCharDB.activeProfile == "Raid" and OffhandCharDB.foreverEditModeLayoutID == 19
            and OffhandCharDB.hudSetupReminderDeclined and OffhandDB.profiles.Default.enabled == false,
        "Recovery must preserve character HUD decisions and the inactive account profile")
    local db = addon.db
    assert(addon:IsSetupComplete() and db.enabled and db.rawMouseInput == false and db.chatPosition == "DECK"
            and db.savedMainPositions.CharacterFrame.x == 2400
            and db.savedWorkspacePositions.WorldMapFrame.regionId == "workspace-b"
            and db.savedWorkspacePositions.WorldMapFrame.x == 12 and db.openWorkspacePanels.WorldMapFrame
            and db.openWorkspacePanels.ContainerFrameCombinedBags
            and db.workspaceRegionScales.layouts.desktop.a.size == 0.75,
        "Recovery must preserve setup, inputs, panel positions, open intent and workspace scale")
end
cvars.offhandForeverDisplayFlags = "V2|0|1|1"
cvars.offhandForeverOnboarding = "V3|0|0|0|0|0"
cvars.offhandForeverOpenPanels = "V1|"
local staleBridgeLaunch = NewAddon(true, oldBridgeAccount, { foreverEditModeLayoutID = 6 },
    "stale-bridge", currentDisk)
local persistence = staleBridgeLaunch.foreverPersistenceDiagnostics
AssertCurrentDiskPreferences(staleBridgeLaunch)
assert(persistence.source == "savedvariables" and persistence.bridge == "present-stale"
        and persistence.diskRevision == 3 and persistence.activeRevision == 3,
    "A rejected bridge must report the disk revision that was retained")
assert(cvars.offhandForeverDisplayFlags == "V2|1|0|0"
        and cvars.offhandForeverOnboarding == "V3|1|1|0|0|0",
    "Rejecting the old bridge must reseed the legacy display and setup fallbacks")
local staleBridgeReload = NewAddon(true, oldBridgeAccount, {}, "stale-bridge", { account = {}, character = {} })
AssertCurrentDiskPreferences(staleBridgeReload)
assert(staleBridgeReload.foreverPersistenceDiagnostics.source == "session-fallback",
    "Reload must recover the new selection even if the client misses the ordinary SavedVariables")
ClearProfileSnapshotCVars()
local recoverMissingDisk = NewAddon(true, currentDisk.account, currentDisk.character, "restore-missing-disk", {})
AssertCurrentDiskPreferences(recoverMissingDisk)
assert(recoverMissingDisk.foreverPersistenceDiagnostics.bridge == "used"
        and recoverMissingDisk.foreverPersistenceDiagnostics.diskRevision == nil,
    "A fresh bridge must still recover missing SavedVariables and keep the disk revision unset")
ClearProfileSnapshotCVars()
local malformedDisk = NewAddon(true, currentDisk.account, currentDisk.character, "restore-malformed-disk", {
    account = { foreverPersistenceRevision = 4, profiles = { Raid = true } },
    character = { activeProfile = "Raid" },
})
AssertCurrentDiskPreferences(malformedDisk)
assert(malformedDisk.foreverPersistenceDiagnostics.source == "companion-bridge",
    "A higher revision in malformed SavedVariables must not suppress a usable bridge")
ClearProfileSnapshotCVars()
local newerBridgeLaunch = NewAddon(true, currentDisk.account, currentDisk.character, "newer-bridge", {
    account = oldBridgeAccount, character = { activeProfile = "Default" },
})
AssertCurrentDiskPreferences(newerBridgeLaunch)
assert(newerBridgeLaunch.foreverPersistenceDiagnostics.bridge == "used",
    "A fresh bridge must still recover an older ordinary load")
ClearProfileSnapshotCVars()
local noDiskCharacter = NewAddon(true, oldBridgeAccount, { activeProfile = "Raid", foreverEditModeLayoutID = 6 },
    "stale-bridge-other-character", { account = currentDisk.account })
assert(noDiskCharacter:IsSetupComplete() and OffhandDB == currentDisk.account,
    "Missing character data must not suppress a newer account revision")
assert(OffhandCharDB.activeProfile == nil and OffhandCharDB.foreverEditModeLayoutID == nil
        and noDiskCharacter.db == OffhandDB.profiles.Default,
    "Rejecting a stale bridge must not borrow its character profile or HUD layout")
ClearProfileSnapshotCVars()

-- A cold launch can retain older field-specific workspace CVars after a panel
-- was explicitly gathered to Mainhand. Never merge those mutually exclusive
-- owners or the next UIPanel reflow will move it back to Offhand.
cvars.offhandForeverPositionIndex = "CharacterFrame"
cvars.offhandForeverPosition_CharacterFrame = "W4|100|900|430|600|1440|2560|0|0"
cvars.offhandForeverOpenPanels = "V1|CharacterFrame"
local mainhandDisk = NewAddon(true, { profiles = { Default = {
    savedMainPositions = { CharacterFrame = { x = 1800, y = 1000 } },
    savedWorkspacePositions = {},
    openWorkspacePanels = {},
} } })
assert(mainhandDisk.db.savedMainPositions.CharacterFrame
        and mainhandDisk.db.savedWorkspacePositions.CharacterFrame == nil
        and mainhandDisk.db.openWorkspacePanels.CharacterFrame == nil,
    "stale field CVars must not override durable Mainhand ownership")

-- The Companion bridge may be generated from Forever's rotated .bak file and
-- lag the complete in-client snapshot by one shutdown. Revision comparison
-- must still run for a fresh bridge, then reseed/clear the older field CVars.
ClearProfileSnapshotCVars()
local newestMainhand = NewAddon(true, {
    profiles = { Default = {
        savedMainPositions = { CharacterFrame = { x = 1900, y = 980 } },
        savedWorkspacePositions = {},
        openWorkspacePanels = {},
    } },
    foreverPersistenceRevision = 4,
})
assert(newestMainhand.ForeverPersistence:SaveProfileSnapshot(true),
    "newer Mainhand fixture must create a complete revisioned snapshot")
cvars.offhandForeverRecoveryVersion = nil
cvars.offhandForeverPositionIndex = "CharacterFrame"
cvars.offhandForeverPosition_CharacterFrame = "W4|120|880|430|600|1440|2560|0|0"
cvars.offhandForeverOpenPanels = "V1|CharacterFrame"
local staleBridgeAccount = {
    profiles = { Default = {
        savedMainPositions = {},
        savedWorkspacePositions = {
            CharacterFrame = { x = 120, y = 880, canvasWidth = 1440, canvasHeight = 2560 },
        },
        openWorkspacePanels = { CharacterFrame = true },
    } },
    foreverPersistenceRevision = 4,
}
local bridgeWithNewerSnapshot = NewAddon(true, staleBridgeAccount, {}, "snapshot-2")
assert(bridgeWithNewerSnapshot.db.savedMainPositions.CharacterFrame
        and bridgeWithNewerSnapshot.db.savedMainPositions.CharacterFrame.x == 1900
        and bridgeWithNewerSnapshot.db.savedWorkspacePositions.CharacterFrame == nil
        and bridgeWithNewerSnapshot.db.openWorkspacePanels.CharacterFrame == nil,
    "a newer complete snapshot must supersede a lagging fresh Companion bridge")
assert(cvars.offhandForeverPosition_CharacterFrame == ""
        and cvars.offhandForeverOpenPanels == "V1|",
    "Mainhand bridge recovery must retire stale workspace position and visibility CVars")
ClearProfileSnapshotCVars()
cvars.offhandForeverRecoveryVersion = "snapshot-1"

-- Forever can lose ordinary SavedVariables during /reload. Mirror the two
-- display switches that determine whether the viewport and raw mouse manager
-- are active, without treating an uninitialized cold-launch CVar as a value.
cvars.offhandForeverDisplayFlags = nil
local displayFlags = NewAddon(true)
displayFlags:SetEnabled(true)
displayFlags:SetRawMouseInput(false)
assert(cvars.offhandForeverDisplayFlags == "V2|1|0|0",
    "Forever display flags must be written when either setting changes")
local displayReload = NewAddon(true)
assert(displayReload.db.enabled == true and displayReload.db.rawMouseInput == false,
    "Forever display flags must survive a same-session reload")
displayReload:SetEnabled(false)
displayReload:SetRawMouseInput(true)
local disabledReload = NewAddon(true)
assert(disabledReload.db.enabled == false and disabledReload.db.rawMouseInput == true,
    "Explicitly disabled Forever display flags must also survive reload")
assert(disabledReload.db.automaticSetupSuppressed == true,
    "explicit disable must preserve setup opt-out through the session fallback")
disabledReload:SetAutomaticSetupSuppressed(false)
local returnedToSetup = NewAddon(true)
assert(returnedToSetup.db.enabled == false and returnedToSetup.db.automaticSetupSuppressed == false,
    "returning to setup must clear the opt-out without activating the viewport")
cvars.offhandForeverDisplayFlags = "V1|0|1"
local legacyDisplayFlags = NewAddon(true, { profiles = { Default = { automaticSetupSuppressed = true } } })
assert(legacyDisplayFlags.db.enabled == false and legacyDisplayFlags.db.automaticSetupSuppressed == true,
    "legacy flags must preserve a durable explicit opt-out")
local legacyFreshFlags = NewAddon(true)
assert(legacyFreshFlags.db.enabled == false and not legacyFreshFlags.db.automaticSetupSuppressed,
    "legacy inactive flags alone must not suppress first-launch guidance")
cvars.offhandForeverDisplayFlags = nil
local uninitializedDisplayFlags = NewAddon(true, { profiles = { Default = {
    enabled = true,
    rawMouseInput = false,
} } })
assert(uninitializedDisplayFlags.db.enabled == true and uninitializedDisplayFlags.db.rawMouseInput == false,
    "An empty cold-launch display CVar must not override disk-loaded settings")

-- Capture the complete active profile at the reload boundary. The account
-- revision distinguishes a broken/stale standard load from a repaired client
-- that has loaded the newly written SavedVariables table correctly.
cvars.offhandForeverDisplayFlags = nil
ClearProfileSnapshotCVars()
local legacyProfiles = {
    profiles = {
        Raid = { foreverEditModeRecovery = {
            restoreLayoutID = 6,
            restoreLayoutName = "Raid Layout",
            fallbackLayoutID = 1,
        } },
        Alt = { foreverEditModeRecovery = {
            restoreLayoutID = 7,
            restoreLayoutName = "Alt Layout",
            fallbackLayoutID = 1,
        } },
    },
}
local legacyCharacter = { activeProfile = "Raid" }
NewAddon(true, legacyProfiles, legacyCharacter)
assert(legacyProfiles.profiles.Raid.foreverEditModeRecovery == nil
        and legacyProfiles.profiles.Alt.foreverEditModeRecovery == nil,
    "Forever migration must scrub profile-scoped recovery from every profile")
assert(legacyCharacter.foreverEditModeLegacyRecovery
        and legacyCharacter.foreverEditModeLegacyRecovery.restoreLayoutID == 6,
    "Forever migration must stage only the character's active profile recovery for API validation")

local completeProfile = NewAddon(true, {
    onboarding = { welcomeDismissed = true, setupComplete = true },
    manualCanvasSchema = 1,
    preferredGeometrySource = "MANUAL",
    manualCanvases = { ["manual-1"] = {
        schema = 1, name = "FancyZones desk", source = "FANCYZONES",
        referenceWidth = 3998, referenceHeight = 2480,
        referenceAspect = 3998 / 2480, uiCanvasAspect = 3048 / 1890,
        measurementMode = "PHYSICAL_CANVAS", arrangement = "SIDE_BY_SIDE",
        primaryPosition = "RIGHT", confirmed = true,
        game = { x = 1439 / 3998, y = 0, width = 2559 / 3998, height = 1439 / 2480 },
        workspace = { x = 0, y = 0, width = 1439 / 3998, height = 1 },
    } },
    profiles = {
        Raid = {
            enabled = true,
            rawMouseInput = true,
            deckWidthRatio = 0.4125,
            workspaceRegionScales = {version=1,layouts={desktop={
                a={size="AUTO",chat=false},b={size=0.75,chat=true}}}},
            theme = "OBSIDIAN",
            customTrimColor = { r = 0.2, g = 0.4, b = 0.6 },
            savedMainPositions = { ChatFrame1 = { x = 1777.5, y = 812.25 } },
            foreverEditModeRecovery = {
                restoreLayoutID = 6,
                restoreLayoutName = "Offhand",
                fallbackLayoutID = 1,
                fallbackLayoutName = "Modern",
            },
        },
    },
}, { activeProfile = "Raid" })
assert(completeProfile.ForeverPersistence:SaveProfileSnapshot(true),
    "Forever must serialize its complete active profile before reload")
assert(OffhandDB.foreverPersistenceRevision == 1,
    "Saving a reload snapshot must advance the standard-table revision")

local brokenStandardLoad = NewAddon(true, {
    profiles = { Default = { enabled = false } },
    foreverPersistenceRevision = 0,
}, { activeProfile = "Default" })
assert(brokenStandardLoad.foreverPersistenceDiagnostics.source == "session-fallback"
        and brokenStandardLoad.foreverPersistenceDiagnostics.sessionFallback == "fallback",
    "Stale standard-load diagnostics must identify the in-client session fallback")
assert(OffhandCharDB.activeProfile == "Raid" and brokenStandardLoad.db.enabled == true,
    "A newer session snapshot must restore the active profile after a stale Forever load")
assert(OffhandDB.profiles.Default == nil and OffhandDB.onboarding.setupComplete == true,
    "The complete fallback must restore account-wide profile and onboarding state")
assert(OffhandDB.manualCanvasSchema == 1
        and OffhandDB.preferredGeometrySource == "MANUAL"
        and OffhandDB.manualCanvases["manual-1"].referenceWidth == 3998,
    "the bridge-free Forever session fallback must preserve remembered canvas signatures")
assert(math.abs(brokenStandardLoad.db.deckWidthRatio - 0.4125) < 0.0001
        and brokenStandardLoad.db.theme == "OBSIDIAN"
        and brokenStandardLoad.db.customTrimColor.g == 0.4,
    "A full Forever profile snapshot must restore geometry, theme, and nested color settings")
assert(brokenStandardLoad.db.savedMainPositions.ChatFrame1.x == 1777.5
        and brokenStandardLoad.db.foreverEditModeRecovery == nil
        and OffhandCharDB.foreverEditModeLegacyRecovery.restoreLayoutID == 6,
    "Forever migration must preserve main positions while staging legacy Edit Mode recovery per character")
assert(brokenStandardLoad.db.workspaceRegionScales.layouts.desktop.a.size=="AUTO"
    and brokenStandardLoad.db.workspaceRegionScales.layouts.desktop.b.size==0.75
    and brokenStandardLoad.db.workspaceRegionScales.layouts.desktop.b.chat==true,
    "Complete Forever profile recovery lost explicit per-region panel sizing")

-- The complete session fallback lives in account-global CVars. Its account
-- settings may recover on another character, but its per-character layout and
-- profile selection must not cross that boundary.
currentCharacterName = "OtherTester"
local otherCharacter = { activeProfile = "Default", marker = "keep-other-character" }
local crossCharacterFallback = NewAddon(true, {
    profiles = { Default = { enabled = false } },
    foreverPersistenceRevision = 0,
}, otherCharacter)
assert(crossCharacterFallback.foreverPersistenceDiagnostics.sessionFallback == "fallback"
        and OffhandDB.profiles.Raid and OffhandDB.onboarding.setupComplete == true,
    "a newer complete snapshot must still recover account state across characters")
assert(OffhandCharDB == otherCharacter
        and OffhandCharDB.activeProfile == "Default"
        and OffhandCharDB.marker == "keep-other-character"
        and OffhandCharDB.foreverEditModeLayoutName == nil,
    "an account-global session snapshot leaked per-character state to another character")
currentCharacterName = "Tester"

local repairedStandardAccount = {
    profiles = { Raid = {
        enabled = false,
        rawMouseInput = false,
        deckWidthRatio = 0.5,
        theme = "CLASSIC",
    } },
    foreverPersistenceRevision = 1,
}
local repairedStandardLoad = NewAddon(true, repairedStandardAccount, { activeProfile = "Raid" })
assert(repairedStandardLoad.foreverPersistenceDiagnostics.source == "savedvariables"
        and repairedStandardLoad.foreverPersistenceDiagnostics.sessionFallback == "standard",
    "Equal-revision diagnostics must identify normal SavedVariables as authoritative")
assert(repairedStandardLoad.db.enabled == false
        and repairedStandardLoad.db.deckWidthRatio == 0.5
        and repairedStandardLoad.db.theme == "CLASSIC",
    "An equal-revision standard SavedVariables load must supersede the session fallback automatically")

-- Older Companion bridge files assigned their snapshot before Config loaded.
-- Init captures the client's newer SavedVariables first; once that bridge
-- version is consumed, Config must restore the captured tables in full rather
-- than only repairing the fields mirrored through CVars.
local capturedAccountDB = { profiles = { Default = {
    enabled = true,
    foreverEditModeRecovery = {
        restoreLayoutID = 6,
        restoreLayoutName = "Offhand",
        fallbackLayoutID = 1,
        fallbackLayoutName = "Modern",
    },
} } }
local staleBridgeDB = { profiles = { Default = { enabled = true } } }
local capturedCharacterDB = { activeProfile = "Default" }
local bridgeReload = NewAddon(true, staleBridgeDB, {}, "snapshot-1", {
    account = capturedAccountDB,
    character = capturedCharacterDB,
})
assert(bridgeReload.db.foreverEditModeRecovery == nil
        and OffhandCharDB.foreverEditModeLegacyRecovery
        and OffhandCharDB.foreverEditModeLegacyRecovery.restoreLayoutID == 6,
    "A consumed Forever bridge must stage newer same-session recovery state on the character")
assert(OffhandDB == capturedAccountDB and OffhandCharDB == capturedCharacterDB,
    "A consumed Forever bridge must restore the exact client-loaded SavedVariables tables")

visibilityCleared.ForeverPersistence:ClearPosition("ContainerFrameCombinedBags")
local cleared = NewAddon(true)
assert(cleared.db.savedWorkspacePositions.ContainerFrameCombinedBags == nil, "Cleared Forever position must stay cleared")

local writesBefore = cvars.offhandForeverPositionIndex
local openPanelsBefore = cvars.offhandForeverOpenPanels
local onboardingBefore = cvars.offhandForeverOnboarding
local otherClient = NewAddon(false)
otherClient.ForeverPersistence:SaveWorkspacePosition("ContainerFrameCombinedBags", { x = 1, y = 2 }, 3, 4)
otherClient.ForeverPersistence:SaveOpenPanels({ CharacterFrame = true })
otherClient:MarkSetupComplete()
assert(cvars.offhandForeverPositionIndex == writesBefore, "Non-Forever clients must not write fallback CVars")
assert(cvars.offhandForeverOpenPanels == openPanelsBefore, "Non-Forever clients must not write visibility CVars")
assert(cvars.offhandForeverOnboarding == onboardingBefore, "Non-Forever clients must not write onboarding CVars")
assert(otherClient.db.savedWorkspacePositions.ContainerFrameCombinedBags == nil,
    "Non-Forever clients must not restore fallback CVars")

-- A mixed-height shaped span can exhaust WoW's hidden cursor while camera
-- looking. Raw input is managed only while Offhand is enabled and spanned,
-- and the player's prior preference must be restored afterward.
local rawMouseTimers = {}
C_Timer = {After = function(delay, callback)
    rawMouseTimers[#rawMouseTimers + 1] = {delay = delay, callback = callback}
end}
cvars.rawMouseEnable = "0"
local mouseAddon = NewAddon(false)
mouseAddon.db.enabled = true
mouseAddon.Viewport = {GetMetrics = function() return {isSpanned = true} end}
mouseAddon.RawMouse:Update({ isSpanned = true })
assert(cvars.rawMouseEnable == "1" and mouseAddon.db.originalRawMouseEnable == "0",
    "A spanned Offhand layout must enable raw mouse and remember the prior value")
mouseAddon.RawMouse:Update({ isSpanned = false })
assert(cvars.rawMouseEnable == "0" and not mouseAddon.db.rawMouseManaged,
    "Single-screen recovery must restore the prior raw-mouse preference")
mouseAddon.db.rawMouseInput = false
mouseAddon.RawMouse:Update({ isSpanned = true })
assert(cvars.rawMouseEnable == "0",
    "Disabling Offhand raw-mouse management must preserve the player preference")

-- A full-screen or display transition can leave the CVar at 1 while Retail's
-- native input registration is stale. Refresh must issue a real 0 -> 1 across
-- frames, without losing the original value or re-enabling after opt-out.
mouseAddon.db.rawMouseInput = true
cvars.rawMouseEnable = "1"
rawMouseTimers = {}
assert(mouseAddon.RawMouse:Refresh({isSpanned = true}) == true)
assert(cvars.rawMouseEnable == "0" and #rawMouseTimers == 1
        and rawMouseTimers[1].delay == 0,
    "raw-mouse refresh did not begin a deferred 0 -> 1 transition")
rawMouseTimers[1].callback()
assert(cvars.rawMouseEnable == "1",
    "raw-mouse refresh did not re-enable input on the following frame")

rawMouseTimers = {}
mouseAddon.RawMouse:Refresh({isSpanned = true})
mouseAddon.db.rawMouseInput = false
mouseAddon.RawMouse:Update({isSpanned = true})
rawMouseTimers[1].callback()
assert(cvars.rawMouseEnable == "1" and not mouseAddon.db.rawMouseManaged,
    "a cancelled raw-mouse refresh overrode the restored player preference")

print("PASS: Forever CVar persistence and reversible spanned raw-mouse management")

ClearProfileSnapshotCVars()
cvars.offhandForeverPositionIndex=nil
local regionAddon=NewAddon(true)
regionAddon.ForeverPersistence:SaveWorkspacePosition('CharacterFrame',{
 x=4200,y=900,canvasWidth=1920,canvasHeight=1080,canvasLeft=4000,canvasBottom=360,regionId='workspace-b'},430,600)
assert(cvars.offhandForeverPosition_CharacterFrame:match('^W5|'))
local reloadedRegions=NewAddon(true)
local regionPosition=reloadedRegions.db.savedWorkspacePositions.CharacterFrame
assert(regionPosition.regionId=='workspace-b' and regionPosition.x==4200 and regionPosition.canvasBottom==360)
local beforeRegion=cvars.offhandForeverPosition_CharacterFrame
regionAddon.ForeverPersistence:SaveWorkspacePosition('CharacterFrame',{x=1,y=2,regionId='bad|id'},3,4)
assert(cvars.offhandForeverPosition_CharacterFrame==beforeRegion,'Invalid region overwrote the last CVar')
cvars.offhandForeverPosition_CharacterFrame='W5|1|2|3|4|5|6|7|8|'..string.rep('a',33)
local invalidRegion=NewAddon(true)
assert(not invalidRegion.db.savedWorkspacePositions.CharacterFrame,'Overlong W5 region accepted')
print('PASS: bounded W5 workspace identity persistence, reload and malformed-record preservation')

-- Live Beta 36 regression: a cold bridge from Naux selected Naux's settings
-- while entering Moonweaver, then discarded Moonweaver's HUD ownership.
local function RecoveryAccount(revision)
    return { foreverPersistenceRevision = revision, profiles = {
        Default = {}, Moon = { canvasOpacity = 0.31 }, Naux = { canvasOpacity = 0.72 },
    } }
end
local function RecoveryCharacter(name, layout)
    return { characterGUID = "Player-" .. name, activeProfile = name,
        mainhandLayout = { ownerGUID = "Player-" .. name, ownerName = name, generatedName = layout },
        hudSetupReminderDeclined = true }
end
local function CheckRecovery(expected, bridgeCharacter, diskCharacter, payload, diskRevision, bridgeRevision)
    cvars = {}
    local addon = NewAddon(true, RecoveryAccount(bridgeRevision or 5), bridgeCharacter, "cold-identity", {
        account = RecoveryAccount(diskRevision or 5), character = diskCharacter,
    }, payload)
    assert((OffhandCharDB.activeProfile or "Default") == expected,
        "cold recovery selected another character's settings")
    assert(addon.db == OffhandDB.profiles[expected], "selected settings table does not match the character")
    if expected ~= "Default" then
        assert(OffhandCharDB.mainhandLayout and OffhandCharDB.mainhandLayout.ownerName == expected
                and not OffhandCharDB.previousHUDIdentity and OffhandCharDB.hudSetupReminderDeclined,
            "cold recovery replaced or discarded the current character's HUD")
    end
    return addon
end
currentCharacterName = "Moon"
local moonCharacter = RecoveryCharacter("Moon", "Offhand Main - Moon")
local nauxCharacter = RecoveryCharacter("Naux", "Offhand Main - Naux")
local legacyMismatch = CheckRecovery("Moon", nauxCharacter, moonCharacter)
assert(legacyMismatch.foreverPersistenceDiagnostics.bridgeCharacter == "unmatched"
        and legacyMismatch.foreverPersistenceDiagnostics.bridge == "used",
    "account recovery and rejected character recovery must be diagnosed independently")
CheckRecovery("Default", nauxCharacter, nil)
CheckRecovery("Default", { activeProfile = "Naux" }, nil)
CheckRecovery("Moon", moonCharacter, nil)
local payload = { schema = 1, characters = { nauxCharacter, moonCharacter } }
local recoveredMoon = CheckRecovery("Moon", nauxCharacter, nil, payload)
assert(recoveredMoon.foreverPersistenceDiagnostics.bridgeCharacter == "used")
-- Match identity rather than newest-file or array order, in both directions.
currentCharacterName = "Naux"
CheckRecovery("Naux", moonCharacter, nil, payload)
currentCharacterName = "Moon"
CheckRecovery("Moon", nauxCharacter, moonCharacter, { schema = 99, characters = { nauxCharacter } })
CheckRecovery("Moon", nauxCharacter, moonCharacter, { schema = 1, characters = false })
CheckRecovery("Moon", nauxCharacter, moonCharacter, { schema = 1, characters = { nauxCharacter } })
-- Neither stale nor already-consumed bridges may replace current disk state.
local staleIdentity = CheckRecovery("Moon", nauxCharacter, moonCharacter, payload, 6, 5)
assert(staleIdentity.foreverPersistenceDiagnostics.bridge == "present-stale")
local savedAccount, savedCharacter = OffhandDB, OffhandCharDB
local consumedIdentity = NewAddon(true, RecoveryAccount(5), nauxCharacter, "cold-identity", {
    account = savedAccount, character = savedCharacter,
}, payload)
assert(OffhandCharDB == savedCharacter and consumedIdentity.db == savedAccount.profiles.Moon)
ClearProfileSnapshotCVars()
local consumedMissing = NewAddon(true, RecoveryAccount(5), nauxCharacter, "cold-identity", {
    account = RecoveryAccount(5),
}, payload)
assert(OffhandCharDB.activeProfile == nil and not OffhandCharDB.mainhandLayout
        and consumedMissing.db == OffhandDB.profiles.Default,
    "an unconditional legacy bridge leaked character data on a consumed reload with missing disk state")
-- A recreated character with the same name must not inherit the former GUID.
local oldMoon = RecoveryCharacter("Moon", "Old layout")
oldMoon.characterGUID = "Player-OldMoon"
CheckRecovery("Default", oldMoon, nil, { schema = 1, characters = { oldMoon } })
local originalUnitGUID = UnitGUID
UnitGUID = function() return nil end
CheckRecovery("Default", nauxCharacter, nil, payload)
UnitGUID = originalUnitGUID
currentCharacterName = "Tester"
OffhandForeverCharacterRecovery = nil
print("PASS: character-scoped fresh, stale, consumed, legacy and recreated-character bridge recovery")

cvars = {
    offhandForeverPositionIndex = "RXPFrame,JournalFrame,RXPItemFrame",
    offhandForeverPosition_RXPFrame = "W|10|20|200|100",
    offhandForeverOpenPanels = "V1|RXPFrame,RXPItemFrame,JournalFrame",
}
local legacyGuide = {
    savedMainPositions = {RXPFrame = {x = 2320.595, y = 611.072}},
    savedWorkspacePositions = {RXPItemFrame = {x = 8, y = 12}, JournalFrame = {x = 1}},
    openWorkspacePanels = {RXPFrame = true, JournalFrame = true},
}
local repaired = NewAddon(true, {profiles = {Default = {}, Other = legacyGuide}})
assert(not legacyGuide.savedMainPositions.RXPFrame and not legacyGuide.savedWorkspacePositions.RXPItemFrame)
assert(not legacyGuide.openWorkspacePanels.RXPFrame and legacyGuide.openWorkspacePanels.JournalFrame)
assert(legacyGuide.savedWorkspacePositions.JournalFrame.x == 1)
repaired.ForeverPersistence:RestorePositions()
repaired.ForeverPersistence:RestoreOpenPanels()
assert(not repaired.db.savedWorkspacePositions.RXPFrame and not repaired.db.openWorkspacePanels.RXPItemFrame)
print("PASS: inactive RestedXP records retire and Forever session fallback cannot reseed them")
