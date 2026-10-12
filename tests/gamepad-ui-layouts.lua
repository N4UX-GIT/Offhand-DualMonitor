-- Forever Gamepad UI: Mainhand layout generation follows the active interface
-- style instead of assuming keyboard and mouse.

local function frame(name)
    local f = { name = name, points = {}, shown = true, scale = 1 }
    function f:GetName() return self.name end
    function f:SetFrameStrata(value) self.strata = value end
    function f:SetFrameLevel(value) self.level = value end
    function f:EnableMouse(value) self.mouse = value end
    function f:SetAllPoints(relative) self.allPoints = relative end
    function f:ClearAllPoints() self.points = {} end
    function f:SetPoint(...) self.points[#self.points + 1] = {...} end
    function f:RegisterEvent() end
    function f:SetScript(script, callback) self[script] = callback end
    function f:IsForbidden() return false end
    function f:IsProtected() return false end
    function f:IsShown() return self.shown end
    function f:GetEffectiveScale() return self.scale end
    function f:GetWidth() return self.w end
    function f:GetHeight() return self.h end
    function f:GetPoint(index)
        local point = self.points[index or 1]
        if point then return unpack(point) end
    end
    function f:GetLeft() return self.left end
    function f:GetRight() return self.right end
    return f
end

UIParent = frame("UIParent")
function UIParent:GetWidth() return 4000 end
function UIParent:GetHeight() return 2560 end
function UIParent:GetChildren() end
WorldFrame = frame("WorldFrame")
CreateFrame = function(_, name) return frame(name) end
InCombatLockdown = function() return false end
UnitAffectingCombat = function() return false end
C_Timer = { After = function(_, callback) callback() end }
UnitName = function() return "Tester" end

local metrics = {
    gameLeft = 1440, gameBottom = 0, gameRight = 4000, gameTop = 1440,
    isSpanned = true,
}
local gamepadUI = true
local addon = {
    db = { enabled = true }, isForever = true, isRetail = false,
    L = setmetatable({}, { __index = function(_, key) return key end }),
    Viewport = { GetMetrics = function() return metrics end },
    RunOrQueueCombat = function(_, callback) callback() end,
}
-- Mirrors Core/Init.lua; Mainhand only consults these when present.
function addon:IsGamepadUIEnabled() return gamepadUI end
function addon:GetForeverLayoutKeys()
    if self:IsGamepadUIEnabled() then
        return "foreverEditModeLayoutNameGamepad", "foreverEditModeLayoutIDGamepad"
    end
    return "foreverEditModeLayoutName", "foreverEditModeLayoutID"
end
OffhandCharDB = {}
assert(loadfile("Core/Mainhand.lua"))("Offhand", addon)
assert(addon.Mainhand:Update("test"))

-- Real Forever 1.60.1 enum values.
Enum = {
    EditModeLayoutType = { Preset = 0, Account = 1 },
    InputDeviceInterfaceType = { Mkb = 1, Gamepad = 2 },
    EditModeSystem = { ActionBar = 0, StatusTrackingBar = 15, GamepadMainActionBar = 30 },
    EditModeActionBarSystemIndices = { MainBar = 1, StanceBar = 11, PetActionBar = 12 },
}
Constants = { EditModeConsts = { EditModeMaxLayoutsPerType = 10 } }
StatusTrackingBarManager = frame("StatusTrackingBarManager")
StatusTrackingBarManager.w, StatusTrackingBarManager.h = 1000, 12

local modern = {
    layoutName = "Modern", layoutIndex = 1, layoutType = 0, interfaceStyle = 1,
    systems = {
        { system = 0, systemIndex = 1, isInDefaultPosition = true,
          anchorInfo = { point = "BOTTOM", relativeTo = "UIParent", relativePoint = "BOTTOM", offsetX = 0, offsetY = 0 } },
    },
}
local gamepadPreset = {
    layoutName = "Gamepad", layoutIndex = 3, layoutType = 0, interfaceStyle = 2,
    systems = {
        -- The Gamepad UI main bar is its own Edit Mode system.
        { system = 30, systemIndex = nil, isInDefaultPosition = true,
          anchorInfo = { point = "BOTTOM", relativeTo = "UIParent", relativePoint = "BOTTOM", offsetX = 0, offsetY = 46 } },
        -- The cast bar follows the gamepad bar and must stay relative to it.
        { system = 1, isInDefaultPosition = true,
          anchorInfo = { point = "BOTTOM", relativeTo = "GamepadMainActionBarFrame", relativePoint = "TOP", offsetX = 0, offsetY = 46 } },
        -- Gamepad UI layouts still carry the hidden keyboard/mouse Action Bar
        -- 1 entry, which would enable the keyboard/mouse refinement.
        { system = 0, systemIndex = 1, isInDefaultPosition = true,
          anchorInfo = { point = "BOTTOM", relativeTo = "UIParent", relativePoint = "BOTTOM", offsetX = 0, offsetY = 0 } },
        -- A default status bar would be restacked by the keyboard/mouse
        -- refinement; under the Gamepad UI it is only translated.
        { system = 15, systemIndex = 1, isInDefaultPosition = true,
          anchorInfo = { point = "TOPRIGHT", relativeTo = "UIParent", relativePoint = "TOPRIGHT", offsetX = -20, offsetY = -30 } },
    },
}
EditModePresetLayoutManager = {
    GetCopyOfPresetLayouts = function()
        return { modern, { layoutName = "Classic", layoutIndex = 2, interfaceStyle = 1 }, gamepadPreset }
    end,
}
local layoutData = { activeLayout = 3, layouts = {} }
local saved, activated
C_EditMode = {
    GetLayouts = function() return layoutData end,
    SaveLayouts = function(data) saved = data; layoutData = data end,
    SetActiveLayout = function(id) activated = id; layoutData.activeLayout = id end,
}

local ok, name, moved = addon.Mainhand:CreateOrUpdateEditModeLayout()
assert(ok and name == "Offhand - Mainhand (Gamepad) - Tester" and moved == 3,
    "Gamepad UI layout was not generated from the active Gamepad preset")
assert(activated == 4 and #saved.layouts == 1, "generated gamepad layout used the wrong global ID")
local generated = saved.layouts[1]
assert(generated.interfaceStyle == 2,
    "generated layout must keep the Gamepad interface style so Blizzard enables it")
assert(generated.systems[1].anchorInfo.offsetX == 720 and generated.systems[1].anchorInfo.offsetY == 46,
    "GamepadMainActionBar was not translated to the bottom center of Mainhand")
assert(generated.systems[2].anchorInfo.relativeTo == "GamepadMainActionBarFrame"
        and generated.systems[2].anchorInfo.offsetY == 46,
    "a system anchored to the gamepad bar must be left relative to it")
assert(generated.systems[4].anchorInfo.point == "TOPRIGHT"
        and generated.systems[4].anchorInfo.offsetX == -20
        and generated.systems[4].anchorInfo.offsetY == -1150,
    "keyboard/mouse HUD refinement must not run on a Gamepad UI layout")
assert(gamepadPreset.systems[1].anchorInfo.offsetX == 0, "the Gamepad preset was mutated")
assert(OffhandCharDB.mainhandLayoutGamepad
        and OffhandCharDB.mainhandLayoutGamepad.sourceName == "Gamepad"
        and OffhandCharDB.mainhandLayout == nil,
    "the Gamepad UI layout record must be separate from the keyboard/mouse record")
assert(OffhandCharDB.foreverEditModeLayoutNameGamepad == name
        and OffhandCharDB.foreverEditModeLayoutIDGamepad == 4
        and OffhandCharDB.foreverEditModeLayoutName == nil,
    "the Forever recovery preference must be stored for the Gamepad UI only")
local status = addon.Mainhand:GetLayoutStatus()
assert(status.configured and status.generatedName == name,
    "layout status must report the Gamepad UI layout while the Gamepad UI is active")

-- Keyboard/mouse mode reports its own (missing) record and refuses to clone a
-- Gamepad UI layout, which Blizzard would disable for this interface style.
gamepadUI = false
assert(not addon.Mainhand:GetLayoutStatus().configured,
    "keyboard/mouse status must not report the Gamepad UI layout")
OffhandCharDB = {}
layoutData = { activeLayout = 3, layouts = {} }
local refused, why = addon.Mainhand:CreateOrUpdateEditModeLayout()
assert(not refused and why == "style",
    "keyboard/mouse mode must not generate from the Gamepad preset")

-- The reverse mismatch: Gamepad UI on while a keyboard/mouse layout is active.
gamepadUI = true
OffhandCharDB = {}
layoutData = { activeLayout = 1, layouts = {} }
refused, why = addon.Mainhand:CreateOrUpdateEditModeLayout()
assert(not refused and why == "style",
    "Gamepad UI mode must not generate from a keyboard/mouse layout")

print("PASS: Gamepad UI layout generation, style isolation, and per-style records")
