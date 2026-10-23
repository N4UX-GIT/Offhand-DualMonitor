-- Exercise the player-facing capture lifecycle without entering native focus code.
local addon = { isForever = true, db = {}, L = {} }
local combat, saves = false, 0
local bindings = { PADBACK = "TOGGLEUIFOCUS", PAD2 = "JUMP" }
InCombatLockdown = function() return combat end
StaticPopupDialogs = {}
C_KeyBindings = { GetBindingContextForAction = function() return 9 end }
GetBindingAction = function(key, _, context) assert(context == 9); return bindings[key] or "" end
GetBindingKey = function(_, _, context) assert(context == 9); return "PADBACK" end
SetBinding = function(key, action, context)
    assert(context == 9); bindings[key] = action; return true
end
SaveBindings = function() saves = saves + 1 end
GetCurrentBindingSet = function() return 2 end
RunBinding = function() error("picker must not execute a focus action") end
GamepadMode = setmetatable({}, { __index = function() error("native focus manager accessed") end })
local function frame()
    local value = { scripts = {}, shown = false }
    function value:SetScript(event, handler) self.scripts[event] = handler end
    function value:Show() self.shown = true end
    function value:Hide()
        local wasShown = self.shown
        self.shown = false
        if wasShown and self.scripts.OnHide then self.scripts.OnHide(self) end
    end
    function value:EnableGamePadButton(enabled) self.gamepad = enabled end
    function value:EnableKeyboard(enabled) self.keyboard = enabled end
    function value:SetText(text) self.text = text end
    function value:CreateFontString() return frame() end
    for _, method in ipairs({ "SetSize", "SetPoint", "ClearAllPoints", "SetFrameStrata",
        "EnableMouse", "SetBackdrop", "SetHeight", "SetWordWrap", "RegisterEvent" }) do
        value[method] = function() end
    end
    return value
end
UIParent = frame()
CreateFrame = function() return frame() end
assert(loadfile("Core/WorkspaceBehavior.lua"))("Offhand", addon)
assert(loadfile("Locales/enUS.lua"))("Offhand", addon)
assert(loadfile("UI/Controls.lua"))("Offhand", addon)
assert(loadfile("UI/Options.lua"))("Offhand", addon)
local options = addon.Options
options.gamepadFocusBindingStatus = frame()
assert(options:OpenGamepadFocusKeybindings())
local picker = options.gamepadFocusCapture
assert(picker.shown and picker.gamepad and picker.keyboard)
picker.scripts.OnGamePadButtonDown(picker, "PAD2")
assert(bindings.PAD2 == "JUMP" and saves == 0 and picker.accept.shown,
    "first conflicting press must request confirmation without changing bindings")
picker.scripts.OnGamePadButtonDown(picker, "PAD3")
assert(saves == 0, "a different button must not confirm the pending replacement")
picker.scripts.OnKeyDown(picker, "ESCAPE")
assert(not picker.shown and not picker.gamepad and not picker.keyboard and saves == 0,
    "cancel must release input and preserve the conflicting binding")
assert(options:OpenGamepadFocusKeybindings())
assert(options.gamepadFocusCapture == picker, "reopening must reuse the capture frame")
picker.scripts.OnGamePadButtonDown(picker, "PAD2")
picker.scripts.OnGamePadButtonDown(picker, "PAD2")
assert(bindings.PAD2 == "TOGGLEUIFOCUS" and saves == 1 and not picker.shown,
    "repeat confirmation must save the native contextual action and release capture")
assert(options.gamepadFocusBindingStatus.text:find("PADBACK", 1, true),
    "closing the picker must refresh native focus binding status")
assert(options:OpenGamepadFocusKeybindings())
combat = true
picker.scripts.OnEvent(picker, "PLAYER_REGEN_DISABLED")
assert(not picker.shown and not picker.gamepad and not picker.keyboard,
    "combat entry must release the capture")
assert(not options:OpenGamepadFocusKeybindings() and saves == 1,
    "capture must not start in combat")
combat = false
assert(options:OpenGamepadFocusKeybindings())
picker.scripts.OnGamePadButtonDown(picker, "PAD3")
assert(bindings.PAD3 == "TOGGLEUIFOCUS" and saves == 2 and not picker.shown,
    "an unused controller button must be assigned directly")
print("PASS: native Gamepad focus picker, conflicts, cancellation and combat cleanup")
