-- Contextual B must not register with, reorder, or invoke the native Escape
-- dispatcher. A private-list registration regression reached SpellStopCasting
-- in both Gamepad and keyboard mode before the addon callback could run.
local combat, gamepad, reserved = false, true, false
local panels, overrides = {}, {}
local overrideWrites = 0
local function frame()
    local result = { attributes = {}, shown = false }
    function result:GetAttribute(key) return self.attributes[key] end
    function result:SetAttribute(key, value) self.attributes[key] = value end
    function result:ClearBindings() overrides[self] = nil end
    function result:IsShown() return self.shown end
    function result:RegisterEvent() end
    function result:SetScript() end
    return result
end
UIParent = frame()
GameMenuFrame = frame()
GameMenuFrame:SetAttribute("UIPanelLayout-area", "center")
GameMenuFrame.SetAttribute = function() error("native menu metadata must remain untouched") end
UIPanelWindows = { GameMenuFrame = { area = "center" } }
CreateFrame = function() return frame() end
RegisterStateDriver = function(_, state, condition)
    assert(state == "combat" and condition == "[combat] combat; nocombat")
end
InCombatLockdown = function() return combat end
GameMenuEscPriority = { AddOn = 8 }
RegisterGameMenuEscHandler = function() error("addon registration taints the shared Escape list") end
GameMenuFrame_Show = function() error("addon must not enter native Game Menu focus code") end
ToggleGameMenu = function() error("addon must not invoke the protected Escape dispatch") end
SpellStopCasting = function() error("casting must remain under native input ownership") end
SetOverrideBinding = function(owner, priority, key, action)
    assert(priority and key == "PAD2" and action == "TOGGLEUIFOCUS")
    overrides[owner] = action; overrideWrites = overrideWrites + 1
end
ClearOverrideBindings = function(owner) overrides[owner] = nil end
GetBindingAction = function()
    for _, action in pairs(overrides) do return action end
    return "CLICK NativeCloseButton:LeftButton"
end
SaveBindings = function() error("contextual Back must not change saved bindings") end
RunBinding = function() error("addon Lua must not execute protected focus work") end
local focusedPanel, otherPanel = frame(), frame()
focusedPanel.shown, otherPanel.shown = true, true
focusedPanel.Show = function() error("must never reopen a workspace panel") end
focusedPanel.Hide = function() error("must never hide a workspace panel") end
otherPanel.Show, otherPanel.Hide = focusedPanel.Show, focusedPanel.Hide
panels = { focusedPanel, otherPanel }
local focusManager = { isUIFocused = true, focusedFrame = focusedPanel }
GamepadMode = { FrameControlsManager = focusManager }
local addon = {
    isForever = true, db = { enabled = true },
    IsBlizzardInputReserved = function() return reserved end,
    Mainhand = {
        IsNativeGamepadInterface = function() return gamepad end,
        GetRect = function() return { isSpanned = true } end,
        GetShownForeverGamepadWorkspacePanels = function() return panels end,
    },
}
assert(loadfile("Core/WorkspaceBehavior.lua"))("Offhand", addon)
local behavior = addon.WorkspaceBehavior
assert(behavior:RefreshGamepadWorkspaceBack())
local owner = behavior.gamepadBackOwner
assert(overrides[owner] == "TOGGLEUIFOCUS",
    "focused workspace Back must dispatch directly to Blizzard's focus binding")
behavior:RefreshGamepadWorkspaceBack()
assert(overrideWrites == 1, "unchanged refresh must be idempotent")
assert(focusedPanel.shown and otherPanel.shown and focusManager.focusedFrame == focusedPanel)
GameMenuFrame.shown = true
behavior:RefreshGamepadWorkspaceBack()
assert(not overrides[owner], "a shown Game Menu must retain native Back")
GameMenuFrame.shown = false
focusManager.isUIFocused = false
behavior:RefreshGamepadWorkspaceBack()
assert(not overrides[owner], "gameplay B must retain its native action")
focusManager.isUIFocused = true
focusManager.focusedFrame = frame()
behavior:RefreshGamepadWorkspaceBack()
assert(not overrides[owner], "Mainhand focus must retain native Back")
focusManager.focusedFrame = focusedPanel
focusedPanel.dismissOnUnfocus = true
behavior:RefreshGamepadWorkspaceBack()
assert(not overrides[owner], "temporary dismissal must retain its native action")
focusedPanel.dismissOnUnfocus = nil
behavior:RefreshGamepadWorkspaceBack()
combat = true
local combatBody = assert(loadstring(owner:GetAttribute("_onstate-combat")))
setfenv(combatBody, { self = owner, newstate = "combat" })
combatBody()
assert(not overrides[owner], "secure combat transition must clear the override")
combat, gamepad = false, false
assert(not behavior:RefreshGamepadWorkspaceBack() and not overrides[owner],
    "keyboard mode must neither retain Back nor register an Escape callback")
gamepad = true
behavior:RefreshGamepadWorkspaceBack()
reserved = true
assert(not behavior:RefreshGamepadWorkspaceBack() and not overrides[owner])
reserved, panels = false, {}
assert(not behavior:RefreshGamepadWorkspaceBack() and not overrides[owner])
assert(GameMenuFrame:GetAttribute("UIPanelLayout-area") == "center"
        and UIPanelWindows.GameMenuFrame.area == "center"
        and behavior.HandleGamepadWorkspaceEscape == nil
        and behavior:GetGamepadWorkspaceBackDiagnostics():find("escape:native", 1, true),
    "Escape and Game Menu must remain native after the taint rollback")
print("PASS: contextual Gamepad Back without Escape registration or native menu mutation")
