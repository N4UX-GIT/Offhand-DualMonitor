local addon = {}

assert(loadfile("Core/MainhandCompatibility.lua"))("Offhand", addon)
local compatibility = assert(addon.MainhandCompatibility)

Enum = nil
C_InputInterfaceStyle = nil
assert(not compatibility.IsNativeGamepadInterface(),
    "missing native Gamepad APIs must fail closed")

Enum = { InputDeviceInterfaceType = { Gamepad = 2 } }
local currentStyle = 1
C_InputInterfaceStyle = {
    GetCurrentStyle = function() return currentStyle end,
}
assert(not compatibility.IsNativeGamepadInterface(),
    "keyboard interface style must not be reported as native Gamepad UI")
currentStyle = 2
assert(compatibility.IsNativeGamepadInterface(),
    "matching interface style must report native Gamepad UI")
C_InputInterfaceStyle.GetCurrentStyle = function() error("restricted") end
assert(not compatibility.IsNativeGamepadInterface(),
    "interface-style API errors must fail closed")

local overrideEnabled = false
addon.IsGamepadUIEnabled = function() return overrideEnabled end
assert(not compatibility.IsNativeGamepadInterface(),
    "the shared client capability override must take priority")
overrideEnabled = true
assert(compatibility.IsNativeGamepadInterface(),
    "the shared client capability override must enable native Gamepad UI")

addon.IsGamepadUIEnabled = nil
C_InputInterfaceStyle.GetCurrentStyle = function() return 1 end
ConsolePort = {}
assert(compatibility.IsControllerMode({}),
    "ConsolePort must select controller layout policy")
ConsolePort = nil
assert(compatibility.IsControllerMode({ { interfaceStyle = 2 } }),
    "a Gamepad preset must select controller layout policy")
assert(not compatibility.IsControllerMode({ { interfaceStyle = 1 } })
        and not compatibility.IsControllerMode(nil),
    "keyboard or missing presets must not select controller layout policy")

print("PASS: Mainhand native Gamepad and controller-layout capability policy")
