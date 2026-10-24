--[[
    Offhand: Multi-Monitor Setup Addon
    Core/MainhandCompatibility.lua: Mainhand client and controller capability policy
--]]

local _, Offhand = ...

local Compatibility = {}
Offhand.MainhandCompatibility = Compatibility

function Compatibility.IsNativeGamepadInterface()
    if type(Offhand.IsGamepadUIEnabled) == "function" then
        return Offhand:IsGamepadUIEnabled()
    end
    local gamepad = Enum and Enum.InputDeviceInterfaceType
        and Enum.InputDeviceInterfaceType.Gamepad
    local getStyle = C_InputInterfaceStyle and C_InputInterfaceStyle.GetCurrentStyle
    if gamepad == nil or type(getStyle) ~= "function" then return false end
    local ok, current = pcall(getStyle)
    return ok and current == gamepad
end

function Compatibility.IsControllerMode(presets)
    if _G.ConsolePort or Compatibility.IsNativeGamepadInterface() then return true end
    local gamepad = Enum and Enum.InputDeviceInterfaceType
        and Enum.InputDeviceInterfaceType.Gamepad
    return gamepad ~= nil and type(presets) == "table"
        and type(presets[1]) == "table"
        and presets[1].interfaceStyle == gamepad
end

