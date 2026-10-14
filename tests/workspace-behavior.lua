-- Workspace behavior: bounded lock-open policy and reversible CharacterFrame scaling.

local addon = {
    db = {
        enabled = true,
        persistentWorkspacePanels = false,
        restoreWorkspaceOnReload = false,
        lockWorkspaceWindows = false,
        lockedWorkspaceWindowTypes = { map = true, bags = true, character = true },
        characterWorkspaceScale = 1.25,
        savedWorkspacePositions = {
            WorldMapFrame = { x = 100, y = 900 },
            CharacterFrame = { x = 120, y = 880 },
            ContainerFrameCombinedBags = { x = 140, y = 860 },
        },
        openWorkspacePanels = {},
    },
}
_G.Offhand = addon

local inCombat = false
InCombatLockdown = function() return inCombat end
local metrics = { isSpanned = true }
addon.Viewport = { GetMetrics = function() return metrics end }

local restores = 0
local restoreMode
addon.Canvas = {
    RestorePersistentFrames = function(_, mode)
        restores = restores + 1
        restoreMode = mode
    end,
}

local function frame(name, shown, scale)
    local value = { name = name, shown = shown, scale = scale or 1, scaleWrites = 0 }
    function value:GetName() return self.name end
    function value:IsVisible() return self.shown end
    function value:IsShown() return self.shown end
    function value:GetScale() return self.scale end
    function value:SetScale(nextScale) self.scale = nextScale; self.scaleWrites = self.scaleWrites + 1 end
    return value
end

WorldMapFrame = frame("WorldMapFrame", false)
CharacterFrame = frame("CharacterFrame", true, 0.9)
ContainerFrameCombinedBags = frame("ContainerFrameCombinedBags", false)

C_AddOns = { IsAddOnLoaded = function() return false end }
C_Timer = {
    After = function(_, callback) callback() end,
    NewTicker = function(_, callback) return { callback = callback, Cancel = function() end } end,
}
local eventFrame
CreateFrame = function()
    eventFrame = { events = {} }
    function eventFrame:RegisterEvent(event) self.events[event] = true end
    function eventFrame:SetScript(_, callback) self.callback = callback end
    return eventFrame
end

assert(loadfile("Core/WorkspaceBehavior.lua"))("Offhand", addon)
local behavior = addon.WorkspaceBehavior

assert(behavior:SetLockEnabled(true), "supported clients must enable lock-open")
assert(restores == 0 and not addon.db.openWorkspacePanels.WorldMapFrame,
    "active lock restoration must remain suspended during login or reload")
eventFrame.callback(eventFrame, "PLAYER_ENTERING_WORLD")
assert(addon.db.persistentWorkspacePanels and addon.db.restoreWorkspaceOnReload,
    "lock-open must enable the persistence paths it depends upon")
assert(addon.db.openWorkspacePanels.WorldMapFrame
        and addon.db.openWorkspacePanels.CharacterFrame
        and addon.db.openWorkspacePanels.ContainerFrameCombinedBags,
    "lock-open must preserve open intent for every selected supported category")
assert(addon.db.nativeBackpackWorkspaceOpen == true and restores > 0,
    "a hidden locked native backpack must request restoration through Canvas")
assert(restoreMode == "lock",
    "active lock enforcement must use the bounded lock settlement path")
assert(behavior:IsFrameLocked(WorldMapFrame, "WorldMapFrame"),
    "a saved selected workspace map must report locked")

behavior:RefreshCharacterScale()
assert(math.abs(CharacterFrame.scale - 1.125) < 0.001,
    "CharacterFrame scale must be a multiplier over its native scale")
local writes = CharacterFrame.scaleWrites
behavior:RefreshCharacterScale()
assert(CharacterFrame.scaleWrites == writes,
    "an unchanged CharacterFrame scale must not be rewritten every refresh")

addon.db.savedWorkspacePositions.CharacterFrame = nil
behavior:RefreshCharacterScale()
assert(math.abs(CharacterFrame.scale - 0.9) < 0.001,
    "moving CharacterFrame off the workspace must restore its native scale")

addon.isForever = true
addon.db.lockWorkspaceWindows = false
assert(not behavior:SetLockEnabled(true) and addon.db.lockWorkspaceWindows == false,
    "Forever must keep the stronger lock-open policy disabled")
assert(not behavior:IsFrameLocked(WorldMapFrame, "WorldMapFrame"),
    "Forever must never advertise a native workspace frame as locked")

addon.isForever = false
addon.db.savedWorkspacePositions.CharacterFrame = { x = 120, y = 880 }
inCombat = true
CharacterFrame.scale = 0.9
behavior:RefreshCharacterScale()
assert(CharacterFrame.scale == 0.9,
    "CharacterFrame scaling must not mutate UI during combat")

eventFrame.callback(eventFrame, "PLAYER_LEAVING_WORLD")
WorldMapFrame.shown = false
local restoresBeforeLeaving = restores
behavior:RestoreLockedWindows()
assert(restores == restoresBeforeLeaving,
    "lock enforcement must stop while reload or world exit is in progress")

print("PASS: workspace lock policy and reversible CharacterFrame scaling")
