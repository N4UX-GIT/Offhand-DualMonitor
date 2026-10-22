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

local nativeBindingRuns = {}
RunBinding = function(binding) nativeBindingRuns[#nativeBindingRuns + 1] = binding end
addon.Mainhand = { IsNativeGamepadInterface = function() return true end }
assert(not Offhand_ToggleGamepadUIFocus(),
    "non-Forever clients must not forward the native Gamepad focus binding")
addon.isForever = true
local nativeContext = 9
local focusAssignments = { PADBACK = "TOGGLEUIFOCUS", PAD2 = "JUMP" }
local bindingSaves = 0
C_KeyBindings = { GetBindingContextForAction = function(action)
    assert(action == "TOGGLEUIFOCUS")
    return nativeContext
end }
GetBindingKey = function(action, _, context)
    assert(action == "TOGGLEUIFOCUS" and context == nativeContext,
        "native focus status must read the Gamepad context")
    return "PADBACK"
end
GetBindingAction = function(key, _, context)
    assert(context == nativeContext, "focus configuration escaped the Gamepad context")
    return focusAssignments[key] or ""
end
local rejectBinding = false
SetBinding = function(key, action, context)
    assert(context == nativeContext)
    if rejectBinding then return false end
    focusAssignments[key] = action
    return true
end
GetCurrentBindingSet = function() return 2 end
SaveBindings = function(set)
    assert(set == 2, "focus assignment must preserve character binding scope")
    bindingSaves = bindingSaves + 1
end
assert(behavior:GetGamepadFocusBindingKeys() == "PADBACK",
    "the existing native focus button was not detected")
local bindingOK, bindingReason, oldAction = behavior:AssignGamepadFocusBinding("PAD2")
assert(not bindingOK and bindingReason == "conflict" and oldAction == "JUMP"
        and focusAssignments.PAD2 == "JUMP" and bindingSaves == 0,
    "a conflicting controller assignment changed without confirmation")
assert(behavior:AssignGamepadFocusBinding("PAD2", true)
        and focusAssignments.PAD2 == "TOGGLEUIFOCUS" and bindingSaves == 1
        and focusAssignments.PADBACK == "TOGGLEUIFOCUS",
    "confirmed assignment must target the native action and retain the existing focus button")
inCombat = true
assert(not behavior:AssignGamepadFocusBinding("PAD3") and bindingSaves == 1,
    "focus configuration must not mutate bindings in combat")
inCombat = false
assert(not behavior:AssignGamepadFocusBinding("ESCAPE") and bindingSaves == 1,
    "the controller picker must not replace Escape")
rejectBinding = true
assert(not behavior:AssignGamepadFocusBinding("PAD3") and bindingSaves == 1,
    "a rejected assignment must not be persisted")
rejectBinding = false
nativeContext = nil
assert(not behavior:AssignGamepadFocusBinding("PAD3") and bindingSaves == 1,
    "missing native context must not fall back to global bindings")
nativeContext = 9
assert(Offhand_ToggleGamepadUIFocus(),
    "Forever Gamepad UI must forward the player-assigned focus binding")
assert(#nativeBindingRuns == 1 and nativeBindingRuns[1] == "TOGGLEUIFOCUS",
    "focus delegate must call only Forever's native TOGGLEUIFOCUS binding")
addon.Mainhand.IsNativeGamepadInterface = function() return false end
assert(not Offhand_ToggleGamepadUIFocus() and #nativeBindingRuns == 1,
    "inactive Gamepad UI must not run the native focus binding")
addon.Mainhand.IsNativeGamepadInterface = function() return true end
addon.isForever = false

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
