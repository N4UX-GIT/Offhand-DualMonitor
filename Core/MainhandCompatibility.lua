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

-- Anniversary's WatchFrame remains a child of the right managed container.
-- Its native layout always uses UIParent's full top-right, even after the
-- Minimap's Edit Mode layout has moved onto a shorter Mainhand display.
local classicRightState, classicRightPending, classicRightPlacing
local classicRightHooked = setmetatable({}, { __mode = "k" })
local classicRightStatus = "not-called"
local function WriteClassicRightPoint(root, point)
    classicRightPlacing = true
    local ok = pcall(SetRootPoint, root, point)
    classicRightPlacing = nil
    return ok
end
local function ClassicMinimapTrackerCeiling(metrics, root, tracker)
    local map = _G.MinimapCluster or _G.Minimap
    if not map or not map.GetBottom or not map.GetLeft or not map.GetRight
        or not map.GetEffectiveScale or (map.IsForbidden and map:IsForbidden())
        or (map.IsShown and not map:IsShown()) then return nil end
    local ok, ceiling = pcall(function()
        local factor = map:GetEffectiveScale() / UIParent:GetEffectiveScale()
        local center = (map:GetLeft() + map:GetRight()) * factor / 2
        local bottom = map:GetBottom() * factor
        if center < metrics.gameLeft or center > metrics.gameRight
            or bottom <= metrics.gameBottom or bottom >= metrics.gameTop then return nil end
        local headerOffset = 0
        if root.GetTop and tracker.GetTop and tracker.GetEffectiveScale then
            local rootTop, trackerTop = root:GetTop(), tracker:GetTop()
            if rootTop and trackerTop then
                local uiScale = UIParent:GetEffectiveScale()
                headerOffset = math.max(0, (trackerTop * tracker:GetEffectiveScale()
                    - rootTop * root:GetEffectiveScale()) / uiScale)
            end
        end
        return bottom - 12 * (metrics.hudScale or 1) - headerOffset
    end)
    return ok and ceiling or nil
end
function Compatibility.UpdateClassicRightContainer(metrics)
    if classicRightPlacing then return false end
    if InCombatLockdown() then
        classicRightStatus = "combat-deferred"
        if Offhand.RunOrQueueCombat and not classicRightPending then
            classicRightPending = true
            Offhand:RunOrQueueCombat(function()
                classicRightPending = nil
                local viewport = Offhand.Viewport
                Compatibility.UpdateClassicRightContainer(viewport and viewport.GetMetrics and viewport:GetMetrics())
            end)
        end
        return false
    end
    local root = _G.UIParentRightManagedFrameContainer
    local tracker = _G.QuestWatchFrame or _G.WatchFrame
    if classicRightState and classicRightState.frame ~= root then classicRightState = nil end
    if not root or (root.IsForbidden and root:IsForbidden()) then
        classicRightStatus = "root-unavailable"; classicRightState = nil; return false
    end
    local current = RootPoint(root)
    local native = current and current[1] == "TOPRIGHT" and current[3] == "TOPRIGHT"
        and (current[2] == UIParent or current[2] == "UIParent")
    if classicRightState and not SameRootPoint(current, classicRightState.applied) and not native then
        classicRightState = nil
        classicRightStatus = "external-anchor"
        return false
    end
    local eligible = not Offhand.isRetail and not Offhand.isForever and not Offhand.isLegacyWrath
        and Offhand.db and Offhand.db.enabled and Offhand.db.seamRedirect ~= false
        and not _G.ConsolePort and not Compatibility.IsNativeGamepadInterface()
        and metrics and metrics.isSpanned and tracker
        and not (tracker.IsForbidden and tracker:IsForbidden())
        and ((tracker.GetParent and tracker:GetParent() == root) or tracker.layoutParent == root)
        and not (tracker.IsUserPlaced and tracker:IsUserPlaced())
        and not (root.IsUserPlaced and root:IsUserPlaced())
        and type(metrics.gameRight) == "number" and type(metrics.gameTop) == "number"
    if not eligible then
        classicRightStatus = "ineligible"
        if classicRightState then
            if SameRootPoint(current, classicRightState.applied) then WriteClassicRightPoint(root, classicRightState.original) end
            classicRightState = nil
        end
        return false
    end
    if not classicRightState and not native then classicRightStatus = "non-native-anchor"; return false end
    if not root.GetEffectiveScale or not UIParent.GetEffectiveScale then return false end
    local scale = root:GetEffectiveScale() / UIParent:GetEffectiveScale()
    if scale <= 0 then return false end
    if native then classicRightState = { frame = root, original = current } end
    local original = classicRightState.original
    local desired = { "TOPRIGHT", UIParent, "BOTTOMLEFT",
        metrics.gameRight / scale + (original[4] or 0), metrics.gameTop / scale + (original[5] or 0) }
    -- The native fixed top inset can overlap a scaled or repositioned Minimap.
    -- Constrain only the managed root's top, using the live Minimap geometry;
    -- retain Blizzard's right-bar clearance and all child layout ownership.
    local ceiling = ClassicMinimapTrackerCeiling(metrics, root, tracker)
    if ceiling then desired[5] = math.min(desired[5], ceiling / scale) end
    if not WriteClassicRightPoint(root, desired) then classicRightStatus = "anchor-refused"; return false end
    classicRightState.applied = desired
    classicRightStatus = "applied"
    -- Native layout can reset the container outside the public delegate method.
    -- Observe the root's completed anchor write, with a re-entrancy guard for our
    -- own writes. Never hook or place the tracker or its protected children.
    if not classicRightHooked[root] and hooksecurefunc then
        classicRightHooked[root] = true
        hooksecurefunc(root, "SetPoint", function()
            if classicRightPlacing then return end
            if Offhand.Viewport and Offhand.Viewport.GetMetrics then
                Compatibility.UpdateClassicRightContainer(Offhand.Viewport:GetMetrics())
            end
        end)
    end
    return true
end

function Compatibility.GetClassicRightContainerDiagnostics()
    if InCombatLockdown() then return "deferred:combat" end
    local ok, report = pcall(function()
        local root = _G.UIParentRightManagedFrameContainer
        local tracker = _G.QuestWatchFrame or _G.WatchFrame
        local function Name(frame)
            return frame and frame.GetName and frame:GetName() or (frame == UIParent and "UIParent" or tostring(frame))
        end
        local points = root and root.GetNumPoints and root:GetNumPoints() or 0
        local point = RootPoint(root)
        local anchor = point and string.format("%s/%s/%s/%.1f/%.1f", tostring(point[1]),
            Name(point[2]), tostring(point[3]), point[4] or 0, point[5] or 0) or "unresolved"
        return string.format("Status=%s | Points=%d | Anchor=%s | Tracker=%s | Parent=%s | LayoutParent=%s | RootUserPlaced=%s | TrackerUserPlaced=%s",
            classicRightStatus, points, anchor, Name(tracker),
            Name(tracker and tracker.GetParent and tracker:GetParent()), Name(tracker and tracker.layoutParent),
            tostring(root and root.IsUserPlaced and root:IsUserPlaced() or false),
            tostring(tracker and tracker.IsUserPlaced and tracker:IsUserPlaced() or false))
    end)
    return ok and report or "unavailable"
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
    local gamepad = Enum and Enum.InputDeviceInterfaceType
        and Enum.InputDeviceInterfaceType.Gamepad
    -- IsControllerMode cannot identify a controller preset without this enum.
    -- Native Gamepad and ConsolePort checks already run before this adapter.
    -- Return that same false result without copying the unused presets.
    if gamepad == nil then return false end
    -- Forever's native preset manager has a stricter ownership boundary. Keep
    -- its existing copy-based compatibility path until that client is retested.
    if Offhand.isForever then return nil end
    local manager = _G.EditModePresetLayoutManager
    local presets = manager and manager.presetLayoutInfo
    if type(presets) ~= "table" or type(presets[1]) ~= "table" then return nil end
    -- Read only this scalar; never retain, copy, modify or traverse systems.
    return presets[1].interfaceStyle == gamepad
end

