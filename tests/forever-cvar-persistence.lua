-- Validates the Forever-only custom-CVar fallback for clients that write but
-- currently fail to reload normal SavedVariables.

local cvars = {}
RegisterCVar = function(name, default)
    if cvars[name] == nil then cvars[name] = default end
end
SetCVar = function(name, value) cvars[name] = tostring(value) end
GetCVar = function(name) return cvars[name] end
C_CVar = nil

local function NewAddon(isForever, accountDB, characterDB, recoveryVersion)
    local addon = { isForever = isForever }
    _G.Offhand = addon
    _G.OffhandDB = accountDB or {}
    _G.OffhandCharDB = characterDB or {}
    _G.OffhandForeverStateBridgeVersion = recoveryVersion
    assert(loadfile("Core/Config.lua"))("Offhand", addon)
    addon:InitializeConfig()
    return addon
end

local first = NewAddon(true)
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
local coldAccountDB = { profiles = { Default = {
    openWorkspacePanels = { CharacterFrame = true, WorldMapFrame = true },
    savedWorkspacePositions = { WorldMapFrame = { x = 12, y = 1685, canvasHeight = 1697 } },
} } }
local coldLaunch = NewAddon(true, coldAccountDB)
assert(coldLaunch.db.openWorkspacePanels.CharacterFrame == true
    and coldLaunch.db.openWorkspacePanels.WorldMapFrame == true,
    "Cold launch must preserve disk-loaded panel visibility")
assert(coldLaunch.db.savedWorkspacePositions.WorldMapFrame.x == 12,
    "Cold launch must preserve disk-loaded frame positions")

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
recovered.ForeverPersistence:SaveOpenPanels({ CharacterFrame = true })
local sameSession = NewAddon(true, coldAccountDB, nil, "snapshot-1")
assert(sameSession.db.openWorkspacePanels.CharacterFrame == true
    and sameSession.db.openWorkspacePanels.WorldMapFrame == nil,
    "A consumed bridge snapshot must yield to later same-session visibility")

visibilityCleared.ForeverPersistence:ClearPosition("ContainerFrameCombinedBags")
local cleared = NewAddon(true)
assert(cleared.db.savedWorkspacePositions.ContainerFrameCombinedBags == nil, "Cleared Forever position must stay cleared")

local writesBefore = cvars.offhandForeverPositionIndex
local openPanelsBefore = cvars.offhandForeverOpenPanels
local otherClient = NewAddon(false)
otherClient.ForeverPersistence:SaveWorkspacePosition("ContainerFrameCombinedBags", { x = 1, y = 2 }, 3, 4)
otherClient.ForeverPersistence:SaveOpenPanels({ CharacterFrame = true })
assert(cvars.offhandForeverPositionIndex == writesBefore, "Non-Forever clients must not write fallback CVars")
assert(cvars.offhandForeverOpenPanels == openPanelsBefore, "Non-Forever clients must not write visibility CVars")
assert(otherClient.db.savedWorkspacePositions.ContainerFrameCombinedBags == nil,
    "Non-Forever clients must not restore fallback CVars")

print("PASS: Forever CVar position fallback restores coordinates and dimensions without affecting other clients")
