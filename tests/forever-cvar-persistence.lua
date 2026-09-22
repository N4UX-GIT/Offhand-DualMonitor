-- Validates the Forever-only custom-CVar fallback for clients that write but
-- currently fail to reload normal SavedVariables.

local cvars = {}
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

local function NewAddon(isForever, accountDB, characterDB, recoveryVersion, diskState)
    local addon = { isForever = isForever }
    addon.foreverDiskSavedVariables = diskState
    _G.Offhand = addon
    _G.OffhandDB = accountDB or {}
    _G.OffhandCharDB = characterDB or {}
    _G.OffhandForeverStateBridgeVersion = recoveryVersion
    assert(loadfile("Core/Config.lua"))("Offhand", addon)
    addon:InitializeConfig()
    return addon
end

local first = NewAddon(true)
first:MarkWelcomeDismissed()
assert(cvars.offhandForeverOnboarding == "V1|1|0|0",
    "Acknowledging the welcome guide must persist in the Forever session fallback")
local onboardingReload = NewAddon(true)
assert(onboardingReload:IsWelcomeDismissed() and not onboardingReload:IsSetupComplete(),
    "Welcome acknowledgement must survive reload without falsely completing setup")
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
assert(recovered.db.openWorkspacePanels.CharacterFrame == true
    and recovered.db.openWorkspacePanels.WorldMapFrame == true,
    "Fresh bridge snapshot must beat stale empty visibility CVar")
assert(cvars.offhandForeverRecoveryVersion == "snapshot-1",
    "Fresh bridge snapshot must be marked consumed for this session")
assert(cvars.offhandForeverOpenPanels == "V1|CharacterFrame,WorldMapFrame",
    "Fresh bridge snapshot must seed the session visibility fallback")
assert(cvars.offhandForeverOnboarding == "V1|1|1|0",
    "Fresh bridge snapshot must seed Forever onboarding state")
recovered.ForeverPersistence:SaveOpenPanels({ CharacterFrame = true })
recovered.db.openWorkspacePanels = { CharacterFrame = true }
recovered.ForeverPersistence:SaveProfileSnapshot(true)
local sameSession = NewAddon(true, coldAccountDB, nil, "snapshot-1")
assert(sameSession.db.openWorkspacePanels.CharacterFrame == true
    and sameSession.db.openWorkspacePanels.WorldMapFrame == nil,
    "A consumed bridge snapshot must yield to later same-session visibility")
ClearProfileSnapshotCVars()

-- Forever can lose ordinary SavedVariables during /reload. Mirror the two
-- display switches that determine whether the viewport and raw mouse manager
-- are active, without treating an uninitialized cold-launch CVar as a value.
cvars.offhandForeverDisplayFlags = nil
local displayFlags = NewAddon(true)
displayFlags:SetEnabled(true)
displayFlags:SetRawMouseInput(false)
assert(cvars.offhandForeverDisplayFlags == "V1|1|0",
    "Forever display flags must be written when either setting changes")
local displayReload = NewAddon(true)
assert(displayReload.db.enabled == true and displayReload.db.rawMouseInput == false,
    "Forever display flags must survive a same-session reload")
displayReload:SetEnabled(false)
displayReload:SetRawMouseInput(true)
local disabledReload = NewAddon(true)
assert(disabledReload.db.enabled == false and disabledReload.db.rawMouseInput == true,
    "Explicitly disabled Forever display flags must also survive reload")
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
local completeProfile = NewAddon(true, {
    onboarding = { welcomeDismissed = true, setupComplete = true },
    profiles = {
        Raid = {
            enabled = true,
            rawMouseInput = true,
            deckWidthRatio = 0.4125,
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
assert(OffhandCharDB.activeProfile == "Raid" and brokenStandardLoad.db.enabled == true,
    "A newer session snapshot must restore the active profile after a stale Forever load")
assert(OffhandDB.profiles.Default == nil and OffhandDB.onboarding.setupComplete == true,
    "The complete fallback must restore account-wide profile and onboarding state")
assert(math.abs(brokenStandardLoad.db.deckWidthRatio - 0.4125) < 0.0001
        and brokenStandardLoad.db.theme == "OBSIDIAN"
        and brokenStandardLoad.db.customTrimColor.g == 0.4,
    "A full Forever profile snapshot must restore geometry, theme, and nested color settings")
assert(brokenStandardLoad.db.savedMainPositions.ChatFrame1.x == 1777.5
        and brokenStandardLoad.db.foreverEditModeRecovery.restoreLayoutID == 6,
    "A full Forever profile snapshot must restore main positions and Edit Mode recovery state")

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
assert(bridgeReload.db.foreverEditModeRecovery
        and bridgeReload.db.foreverEditModeRecovery.restoreLayoutID == 6,
    "A consumed Forever bridge must not erase newer same-session recovery state")
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
cvars.rawMouseEnable = "0"
local mouseAddon = NewAddon(false)
mouseAddon.db.enabled = true
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

print("PASS: Forever CVar persistence and reversible spanned raw-mouse management")
