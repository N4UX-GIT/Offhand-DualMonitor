--[[
    Offhand: Multi-Monitor Setup Addon
    Core/MainhandCompatibility.lua: Mainhand client and controller capability policy
--]]

local _, Offhand = ...

local Compatibility = {}
Offhand.MainhandCompatibility = Compatibility

-- Classic's default controls reference MainMenuBarArtFrame. Keep that entire
-- native assembly together by relocating only its root, outside combat.
-- No scripts, fields, parents, scale or visibility on native frames are changed.
local classicRootState
local function RootPoint(frame)
    if not frame or not frame.GetNumPoints or frame:GetNumPoints() ~= 1 then return end
    return {frame:GetPoint(1)}
end
local function SameRootPoint(a, b)
    return a and b and a[1] == b[1] and a[2] == b[2] and a[3] == b[3]
        and math.abs((a[4] or 0) - (b[4] or 0)) < 0.001
        and math.abs((a[5] or 0) - (b[5] or 0)) < 0.001
end
local function SetRootPoint(frame, point)
    if SameRootPoint(RootPoint(frame), point) then return end
    frame:ClearAllPoints()
    frame:SetPoint(unpack(point))
end

function Compatibility.UpdateClassicNativeBar(metrics)
    -- ApplyFullLayout already queues itself for combat end. Other callers must
    -- also leave both acquisition and restoration deferred during lockdown.
    if InCombatLockdown() then return false end
    local root, main = _G.MainMenuBar, _G.MainActionBar
    if classicRootState and classicRootState.frame ~= root then classicRootState = nil end
    if root and root.IsForbidden and root:IsForbidden() then classicRootState = nil; return false end
    local current = RootPoint(root)
    if classicRootState and not SameRootPoint(current, classicRootState.applied)
        and not SameRootPoint(current, classicRootState.original) then
        -- Another owner changed the anchor. Never restore over that choice.
        classicRootState = nil
        return false
    end
    local manager = _G.EditModeManagerFrame
    local eligible = Offhand.db and Offhand.db.enabled and metrics and metrics.isSpanned
        and not Offhand.isRetail and not Offhand.isForever and not Offhand.isLegacyWrath
        and type(Offhand.HasBlizzardEditMode) == "function" and Offhand:HasBlizzardEditMode()
        and not Compatibility.IsNativeGamepadInterface()
        and not _G.ConsolePort and not (Offhand.HasCustomActionBarAddon and Offhand.HasCustomActionBarAddon())
        and _G.MainMenuBarArtFrame and root and main
        and not (root.IsForbidden and root:IsForbidden())
        and root.IsShown and root:IsShown()
        and not (main.IsInitialized and not main:IsInitialized())
        and main.IsInDefaultPosition and main:IsInDefaultPosition()
        and not (root.IsUserPlaced and root:IsUserPlaced())
        and type(metrics.gameLeft) == "number" and type(metrics.gameRight) == "number"
        and type(metrics.gameBottom) == "number"
    local default = {"BOTTOM", UIParent, "BOTTOM", 0, 0}
    if not eligible then
        if classicRootState then
            if SameRootPoint(current, classicRootState.applied) then SetRootPoint(root, classicRootState.original) end
            classicRootState = nil
        end
        return false
    end
    if manager and manager.IsShown and manager:IsShown() then return false end
    if not classicRootState and not SameRootPoint(current, default) then return false end
    if not root.GetEffectiveScale or not root.GetWidth then return false end
    local scale = root:GetEffectiveScale() / UIParent:GetEffectiveScale()
    if scale <= 0 or (root:GetWidth() + 256) * scale > metrics.gameRight - metrics.gameLeft then
        if classicRootState then
            if SameRootPoint(current, classicRootState.applied) then SetRootPoint(root, classicRootState.original) end
            classicRootState = nil
        end
        return false
    end
    classicRootState = classicRootState or {frame=root, original=current}
    local desired = {"BOTTOM", UIParent, "BOTTOMLEFT",
        (metrics.gameLeft + metrics.gameRight) / (2 * scale), metrics.gameBottom / scale}
    SetRootPoint(root, desired)
    classicRootState.applied = desired
    return true
end

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

function Compatibility.ReadControllerPresetMode()
    -- Forever's native preset manager has a stricter ownership boundary. Keep
    -- its existing copy-based compatibility path until that client is retested.
    if Offhand.isForever then return nil end
    local gamepad = Enum and Enum.InputDeviceInterfaceType
        and Enum.InputDeviceInterfaceType.Gamepad
    local manager = _G.EditModePresetLayoutManager
    local presets = manager and manager.presetLayoutInfo
    if gamepad == nil or type(presets) ~= "table" or type(presets[1]) ~= "table" then return nil end
    -- Read only this scalar; never retain, copy, modify or traverse systems.
    return presets[1].interfaceStyle == gamepad
end

