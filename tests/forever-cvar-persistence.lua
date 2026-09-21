-- Validates the Forever-only custom-CVar fallback for clients that write but
-- currently fail to reload normal SavedVariables.

local cvars = {}
RegisterCVar = function(name, default)
    if cvars[name] == nil then cvars[name] = default end
end
SetCVar = function(name, value) cvars[name] = tostring(value) end
GetCVar = function(name) return cvars[name] end
C_CVar = nil

local function NewAddon(isForever)
    local addon = { isForever = isForever }
    _G.Offhand = addon
    _G.OffhandDB = {}
    _G.OffhandCharDB = {}
    assert(loadfile("Core/Config.lua"))("Offhand", addon)
    addon:InitializeConfig()
    return addon
end

local first = NewAddon(true)
first.ForeverPersistence:SaveWorkspacePosition(
    "ContainerFrameCombinedBags",
    { x = 274.8437194824219, y = 997.0802001953125 },
    320,
    220
)
assert(cvars.offhandForeverPositionIndex == "ContainerFrameCombinedBags", "Forever frame index must persist")

local reloaded = NewAddon(true)
local restored = reloaded.db.savedWorkspacePositions.ContainerFrameCombinedBags
assert(restored and math.abs(restored.x - 274.8437194824219) < 0.001, "Forever x coordinate must restore from its CVar")
assert(math.abs(restored.y - 997.0802001953125) < 0.001, "Forever y coordinate must restore from its CVar")
assert(restored.width == 320 and restored.height == 220, "Forever frame dimensions must restore from its CVar")

reloaded.ForeverPersistence:SaveOpenPanels({
    ContainerFrameCombinedBags = true,
    WorldMapFrame = true,
    CharacterFrame = false,
})
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
