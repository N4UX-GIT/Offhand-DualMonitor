-- Native Mainhand geometry, safe gathering, and generated Edit Mode layouts.

local children = {}
local function frame(name)
    local f = { name = name, points = {}, shown = true, movable = false, scale = 1 }
    function f:GetName() return self.name end
    function f:SetFrameStrata(value) self.strata = value end
    function f:SetFrameLevel(value) self.level = value end
    function f:EnableMouse(value) self.mouse = value end
    function f:SetAllPoints(relative) self.allPoints = relative end
    function f:ClearAllPoints() self.points = {} end
    function f:SetPoint(...) self.points[#self.points + 1] = {...} end
    function f:RegisterEvent(event) self.events = self.events or {}; self.events[event] = true end
    function f:SetScript(script, callback) self[script] = callback end
    function f:IsForbidden() return self.forbidden == true end
    function f:IsProtected() return self.protected == true end
    function f:IsShown() return self.shown end
    function f:IsMovable() return self.movable end
    function f:IsObjectType(kind) return self.kind == kind end
    function f:GetEffectiveScale() return self.scale end
    function f:GetLeft() return self.left end
    function f:GetRight() return self.right end
    function f:GetBottom() return self.bottom end
    function f:GetTop() return self.top end
    return f
end

UIParent = frame("UIParent")
function UIParent:GetWidth() return 4000 end
function UIParent:GetHeight() return 2560 end
function UIParent:GetEffectiveScale() return 1 end
function UIParent:GetChildren() return unpack(children) end
WorldFrame = frame("WorldFrame")

local created = {}
CreateFrame = function(_, name)
    local f = frame(name)
    created[#created + 1] = f
    return f
end
InCombatLockdown = function() return false end
local unitCombat = false
UnitAffectingCombat = function(unit) return unit == "player" and unitCombat end
C_Timer = { After = function(_, callback) callback() end }
StaticPopupDialogs = {}
StaticPopup_Show = function() end
ReloadUI = function() end
RELOADUI, LATER = "Reload", "Later"
UnitName = function() return "Tester" end

local metrics = {
    gameLeft = 1440, gameBottom = 0, gameRight = 4000, gameTop = 1440,
    isSpanned = true,
}
local addon = {
    db = { enabled = true }, isForever = true, isRetail = false,
    L = setmetatable({}, { __index = function(_, key) return key end }),
    Viewport = { GetMetrics = function() return metrics end },
    RunOrQueueCombat = function(_, callback) callback() end,
}
OffhandCharDB = {}
assert(loadfile("Core/Mainhand.lua"))("Offhand", addon)

local callbackRect, callbackRevision
assert(addon.API.RegisterGeometryCallback("test", function(rect, _, revision)
    callbackRect, callbackRevision = rect, revision
end))
assert(addon.Mainhand:Update("test"), "initial geometry was not applied")
local anchor = addon.API.GetMainhandFrame()
assert(anchor.points[1][1] == "BOTTOMLEFT" and anchor.points[1][4] == 1440
        and anchor.points[2][1] == "TOPRIGHT" and anchor.points[2][4] == 4000
        and anchor.points[2][5] == 1440,
    "Mainhand anchor did not use Viewport metrics")
assert(callbackRect.left == 1440 and callbackRect.right == 4000 and callbackRevision == 1,
    "geometry callback did not receive the committed rectangle")

local cooperative = frame("CooperativeAddonFrame")
assert(addon.API.AnchorToMainhand(cooperative, "CENTER", "CENTER", 4, -3))
assert(cooperative.points[1][2] == anchor, "cooperating frame did not anchor to Mainhand")
cooperative.protected = true
assert(not addon.API.AnchorToMainhand(cooperative), "protected frames must be rejected")

local safe = frame("SafeWindow")
safe.movable, safe.left, safe.right, safe.bottom, safe.top = true, 50, 450, 1900, 2200
local protected = frame("ProtectedWindow")
protected.movable, protected.protected = true, true
protected.left, protected.right, protected.bottom, protected.top = 50, 450, 1900, 2200
local managed = frame("EditModeManaged")
managed.movable, managed.isManagedFrame = true, true
managed.left, managed.right, managed.bottom, managed.top = 50, 450, 1900, 2200
children = { safe, protected, managed }
local ok, why, moved = addon.Mainhand:GatherSafeUI()
assert(ok and not why and moved == 1, "safe gather did not move exactly one eligible frame")
assert(safe.points[1] and safe.points[1][1] == "CENTER", "safe window was not gathered")
assert(#protected.points == 0 and #managed.points == 0,
    "safe gather touched a protected or Edit Mode-owned frame")

local canvasGathered = false
addon.Canvas = {
    GatherSafeUIToMainhand = function()
        canvasGathered = true
        return true, nil, 3, 0
    end,
}
unitCombat = true
ok, why, moved = addon.Mainhand:GatherSafeUI()
assert(not ok and why == "combat" and moved == 0 and not canvasGathered,
    "player combat state did not block safe gather when lockdown lagged")
unitCombat = false
local activeRect = addon.Mainhand.rect
addon.Mainhand.rect = {
    left = 0, bottom = 0, right = 4000, top = 2560,
    width = 4000, height = 2560, isSpanned = false,
}
ok, why, moved = addon.Mainhand:GatherSafeUI()
assert(ok and not why and moved == 3 and canvasGathered,
    "safe gather let a stale anchor block live Canvas recovery")
addon.Mainhand.rect = activeRect
addon.Canvas = nil

Enum = {
    EditModeLayoutType = { Account = 1 },
    InputDeviceInterfaceType = { Gamepad = 2 },
}
Constants = { EditModeConsts = { EditModeMaxLayoutsPerType = 10 } }
local preset = {
    layoutName = "Modern", layoutIndex = 1, layoutType = 1, interfaceStyle = 1,
    systems = {
        { isInDefaultPosition = true,
          anchorInfo = { point = "CENTER", relativeTo = "UIParent", relativePoint = "CENTER", offsetX = 0, offsetY = 0 } },
        { isInDefaultPosition = true,
          anchorInfo = { point = "TOPRIGHT", relativeTo = "UIParent", relativePoint = "TOPRIGHT", offsetX = -20, offsetY = -30 } },
        { isInDefaultPosition = false,
          anchorInfo = { point = "LEFT", relativeTo = "OtherSystem", relativePoint = "RIGHT", offsetX = 5, offsetY = 0 } },
    },
}
EditModePresetLayoutManager = {
    GetCopyOfPresetLayouts = function() return { preset, { layoutName = "Classic", layoutIndex = 2 },
        { layoutName = "Internal", layoutIndex = 3 } } end,
}
local layoutData = { activeLayout = 1, layouts = {} }
local saved, activated
C_EditMode = {
    GetLayouts = function() return layoutData end,
    SaveLayouts = function(data) saved = data; layoutData = data end,
    SetActiveLayout = function(id) activated = id; layoutData.activeLayout = id end,
}

ok, localName, moved = addon.Mainhand:CreateOrUpdateEditModeLayout()
assert(ok and localName == "Offhand - Mainhand - Tester" and moved == 2,
    "Mainhand Edit Mode layout was not generated from the active preset")
assert(activated == 4 and #saved.layouts == 1, "generated custom layout used the wrong global ID")
local generated = saved.layouts[1]
assert(generated.systems[1].anchorInfo.offsetX == 720
        and generated.systems[1].anchorInfo.offsetY == -560,
    "center anchor was not translated to the Mainhand center")
assert(generated.systems[2].anchorInfo.offsetX == -20
        and generated.systems[2].anchorInfo.offsetY == -1150,
    "edge anchor was not translated to the Mainhand edge")
assert(generated.systems[3].anchorInfo.offsetX == 5,
    "a system-relative anchor was unexpectedly changed")
assert(preset.systems[1].anchorInfo.offsetX == 0 and preset.systems[1].anchorInfo.offsetY == 0,
    "the source preset was mutated")
assert(OffhandCharDB.mainhandLayout.sourcePreset
        and OffhandCharDB.mainhandLayout.sourceID == 1
        and OffhandCharDB.foreverEditModeLayoutID == 4,
    "per-character layout provenance was not recorded")

-- Updating for another topology must rebuild from the original preset, not
-- translate the generated layout a second time.
metrics = { gameLeft = 0, gameBottom = 0, gameRight = 2560, gameTop = 1440, isSpanned = true }
addon.Mainhand:Update("topology")
ok, localName, moved = addon.Mainhand:CreateOrUpdateEditModeLayout()
assert(ok and #saved.layouts == 1 and activated == 4 and moved == 2,
    "layout update duplicated the generated layout")
generated = saved.layouts[1]
assert(generated.systems[1].anchorInfo.offsetX == -720
        and generated.systems[1].anchorInfo.offsetY == -560,
    "layout update drifted instead of rebuilding from its source")

-- Forever may expose the native post-save layout-added transaction without a
-- directly callable SetActiveLayout. Creation must still activate the new
-- custom layout, while subsequent updates work because it is already active.
OffhandCharDB = {}
layoutData = { activeLayout = 1, layouts = {} }
saved, activated = nil, nil
C_EditMode.SetActiveLayout = nil
C_EditMode.OnLayoutAdded = function(index, activate)
    assert(index == 1 and activate, "layout-added fallback received the wrong custom index")
    layoutData.activeLayout = 3 + index
end
metrics = { gameLeft = 1440, gameBottom = 0, gameRight = 4000, gameTop = 1440, isSpanned = true }
addon.Mainhand:Update("forever-layout-added")
ok, localName, moved = addon.Mainhand:CreateOrUpdateEditModeLayout()
assert(ok and layoutData.activeLayout == 4 and #saved.layouts == 1,
    "Forever layout-added fallback did not activate the generated layout")

-- The Options action must preserve every return value from Mainhand. Wrapping
-- this call in an `and` expression collapses the layout name and moved count.
assert(loadfile("UI/Options.lua"))("Offhand", addon)
local createLayout = addon.Mainhand.CreateOrUpdateEditModeLayout
addon.Mainhand.CreateOrUpdateEditModeLayout = function()
    return true, "Offhand - Mainhand - Return Contract", 7
end
local actionOK, actionName, actionMoved = addon.Options:CreateMainhandHUDLayout()
assert(actionOK and actionName == "Offhand - Mainhand - Return Contract" and actionMoved == 7,
    "Options collapsed the Mainhand layout result values")
addon.Mainhand.CreateOrUpdateEditModeLayout = createLayout

C_EditMode.SaveLayouts = nil
ok, why = addon.Mainhand:CreateOrUpdateEditModeLayout()
assert(not ok and why == "save-api",
    "missing Edit Mode save capability must report its exact failure")

print("PASS: Mainhand anchor, public API, safe gather, layout transform, and provenance")
