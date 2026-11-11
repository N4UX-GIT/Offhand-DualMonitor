-- Serialized native HUD fitting only; no native-frame mutation/client claims.
local assertions = 0
local function Check(value, message) assertions = assertions + 1; assert(value, message) end
local function Copy(value)
    if type(value) ~= "table" then return value end
    local result = {}; for key, child in pairs(value) do result[key] = Copy(child) end; return result
end
local function Same(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for key, value in pairs(a) do if not Same(value, b[key]) then return false end end
    for key in pairs(b) do if a[key] == nil then return false end end
    return true
end
local uiScale = .581
UIParent = {GetWidth = function() return 2496 end, GetHeight = function() return 1322 end,
    GetEffectiveScale = function() return uiScale end}
Enum = {EditModeSystem = {ActionBar = 10}, EditModeActionBarSystemIndices = {ClassBar = 99}}
local addon = {Mainhand = {}, MainhandGeometry = {}, MainhandCompatibility = {}, isForever = true,
    HUDCompatibility = {IsExternallyOwnedEditModeSystem = function(entry) return entry.external end}}
assert(loadfile("Core/MainhandEditMode.lua"))("Offhand", addon)
local Fit
for i = 1, 100 do
    local name, value = debug.getupvalue(addon.Mainhand.CreateOrUpdateEditModeLayout, i)
    if not name then break end
    if name == "FitNativeHUDLayout" then Fit = value; break end
end
assert(Fit, "production fitting helper was not wired into layout generation")
local frames = {}
EditModeManagerFrame = {GetRegisteredSystemFrame = function(_, system, index) return frames[system .. ":" .. tostring(index)] end}
local function Frame(system, name, width, height, index)
    local f = {width = width or 100, height = height or 100}
    function f:GetWidth() return self.width end
    function f:GetHeight() return self.height end
    function f:GetEffectiveScale() return uiScale end
    function f:GetName() return name end
    function f:SetPoint() error("fitting mutated a live protected system") end
    function f:SetSize() error("fitting resized a live system") end
    frames[system .. ":" .. tostring(index)] = f
    return f
end
local function Entry(system, point, relative, relativePoint, x, y, index)
    return {system = system, systemIndex = index, isInDefaultPosition = false,
        settings = {{setting = 123, value = 456}}, anchorInfo = {point = point, relativeTo = relative,
            relativePoint = relativePoint, offsetX = x, offsetY = y}}
end
Frame(1, "Map")
Frame(2, "AlreadyInside", 50, 50)
Frame(3, "Status", 2496, 20)
Frame(4, "Root")
Frame(5, "Child")
local source = {layoutName = "Player's custom HUD", systems = {
    Entry(1, "TOPRIGHT", "UIParent", "BOTTOMLEFT", 2450, 1290),
    Entry(2, "CENTER", "UIParent", "BOTTOMLEFT", 200, 200),
    Entry(3, "BOTTOMLEFT", "UIParent", "BOTTOMLEFT", 0, 10),
    Entry(5, "TOPLEFT", "Root", "TOPRIGHT", 0, 0),
    Entry(4, "BOTTOMLEFT", "UIParent", "BOTTOMLEFT", 1800, 300),
}}
source.systems[3].anchorInfo2 = {point = "BOTTOMRIGHT", relativeTo = "UIParent", relativePoint = "BOTTOMRIGHT", offsetX = 0, offsetY = 10}
local before, generated = Copy(source), Copy(source)
local rect = {left = 0, bottom = 0, right = 1755, top = 1097, width = 1755, height = 1097}
local moved, skipped, status = Fit(generated, rect)
Check(moved == 3 and skipped == 0 and status == "complete", "absolute, stretched and snapped-root groups were not fitted")
Check(generated.systems[1].anchorInfo.offsetX <= 1755 and generated.systems[1].anchorInfo.offsetY <= 1097
    and generated.systems[1].anchorInfo.offsetX > 1600, "custom minimap still spans the canvas")
Check(generated.systems[3].anchorInfo2.offsetX == -741, "second XP anchor still spans the canvas")
Check(math.abs(generated.systems[5].anchorInfo.offsetX - 1800 / 2496 * 1755) < .001
    and Same(generated.systems[4], source.systems[4]), "snapped children must follow a projected root without anchor edits")
Check(Same(generated.systems[2], source.systems[2]), "an in-Mainhand custom position was changed")
Check(Same(source, before) and Same(generated.systems[1].settings, source.systems[1].settings), "source layout/settings were overwritten")
before = Copy(generated)
Check(Fit(generated, rect) == 0 and Same(generated, before), "fitting a completed copy must be idempotent")

for _, area in ipairs({{left = 741, bottom = 0, right = 2496, top = 1097},
    {left = 400, bottom = 500, right = 2000, top = 1322}, {left = 0, bottom = 0, right = 1400, top = 600}}) do
    area.width, area.height = area.right - area.left, area.top - area.bottom
    local result = Copy(source)
    Check(select(3, Fit(result, area)) == "complete", "right/stacked Mainhand fit was incomplete")
    local function Inside(l, b, r, t)
        return l >= area.left - .001 and r <= area.right + .001 and b >= area.bottom - .001 and t <= area.top + .001
    end
    local map, inside, status, root = result.systems[1].anchorInfo, result.systems[2].anchorInfo,
        result.systems[3], result.systems[5].anchorInfo
    Check(Inside(map.offsetX - 100, map.offsetY - 100, map.offsetX, map.offsetY), "map escaped right/stacked Mainhand")
    Check(Inside(inside.offsetX - 25, inside.offsetY - 25, inside.offsetX + 25, inside.offsetY + 25), "custom frame escaped right/stacked Mainhand")
    Check(Inside(status.anchorInfo.offsetX, status.anchorInfo.offsetY, 2496 + status.anchorInfo2.offsetX,
        status.anchorInfo.offsetY + 20), "stretched status frame escaped right/stacked Mainhand")
    Check(Inside(root.offsetX, root.offsetY, root.offsetX + 200, root.offsetY + 100), "snapped group escaped right/stacked Mainhand")
end
Frame(11, "CustomBarA"); Frame(12, "CustomBarB")
local spread = {systems = {Entry(11, "BOTTOMLEFT", "UIParent", "BOTTOMLEFT", 2000, 500),
    Entry(12, "BOTTOMLEFT", "UIParent", "BOTTOMLEFT", 2300, 500)}}
Fit(spread, rect)
Check(spread.systems[2].anchorInfo.offsetX - spread.systems[1].anchorInfo.offsetX >= 100,
    "independent custom bars collapsed onto the same Mainhand edge")

-- Native SaveLayouts rounds the persisted anchors to a slightly different
-- precision than physical-to-UI geometry. A seam epsilon is not a new topology.
local boundaryRect = {left = 1571.4286024306, right = 3142.8572048611,
    bottom = 10, top = 1767.8571777344}
boundaryRect.width, boundaryRect.height = boundaryRect.right - boundaryRect.left,
    boundaryRect.top - boundaryRect.bottom
for _, position in ipairs({{boundaryRect.left - .00002, 100},
    {boundaryRect.right - 100 + .00002, 100}, {1800, boundaryRect.bottom - .00002},
    {1800, boundaryRect.top - 100 + .00002}}) do
    local layout = {systems = {Entry(1, "BOTTOMLEFT", "UIParent", "BOTTOMLEFT", position[1], position[2])}}
    before = Copy(layout)
    Check(Fit(layout, boundaryRect) == 0 and Same(layout, before),
        "native boundary rounding projected a preserved custom position across Mainhand")
end
Frame(13, "RoundedWidth", boundaryRect.width + .00002, 100)
local rounded = {systems = {Entry(13, "BOTTOMLEFT", "UIParent", "BOTTOMLEFT", boundaryRect.left, 100)}}
before = Copy(rounded)
moved, skipped = Fit(rounded, boundaryRect)
Check(moved == 0 and skipped == 0 and Same(rounded, before), "native rounded width was treated as an oversized group")
local outside = {systems = {Entry(1, "BOTTOMLEFT", "UIParent", "BOTTOMLEFT", boundaryRect.left - .02, 100)}}
Check(Fit(outside, boundaryRect) == 1, "boundary tolerance suppressed a meaningful outlying position")

-- Moving a parent must never move an external or unmeasurable snapped child.
for _, unknown in ipairs({false, true}) do
    local layout = {systems = {Entry(4, "BOTTOMLEFT", "UIParent", "BOTTOMLEFT", 1800, 300),
        Entry(unknown and 6 or 5, "TOPLEFT", "Root", "TOPRIGHT", 0, 0)}}
    layout.systems[2].external = not unknown
    before = Copy(layout)
    Fit(layout, rect)
    Check(Same(layout, before), "external/unknown child group moved indirectly")
end
local huge = Frame(7, "Huge", 2000, 100)
local unsafe = {systems = {Entry(7, "BOTTOMLEFT", "UIParent", "BOTTOMLEFT", 1800, 10)}}
before = Copy(unsafe)
moved, skipped, status = Fit(unsafe, rect)
Check(moved == 0 and skipped == 1 and status == "partial" and Same(unsafe, before), "oversized non-stretched HUD must yield without scaling user bars")
Frame(10, "Class", 100, 100, 99)
unsafe = {systems = {Entry(10, "BOTTOMLEFT", "UIParent", "BOTTOMLEFT", 2000, 100, 99)}}
before = Copy(unsafe); Fit(unsafe, rect)
Check(Same(unsafe, before), "ambiguous Forever ClassBar was moved")
Frame(8, "CycleA"); Frame(9, "CycleB")
unsafe = {systems = {Entry(8, "LEFT", "CycleB", "RIGHT", 0, 0), Entry(9, "LEFT", "CycleA", "RIGHT", 0, 0)}}
before = Copy(unsafe); moved, skipped = Fit(unsafe, rect)
Check(moved == 0 and skipped == 2 and Same(unsafe, before), "cyclic anchors must fail closed")
local secret = setmetatable({}, {__lt = function() error("secret compared") end, __mul = function() error("secret multiplied") end})
issecretvalue = function(value) return value == secret end
huge.width = secret
unsafe = {systems = {Entry(7, "BOTTOMLEFT", "UIParent", "BOTTOMLEFT", 1800, 10)}}
before = Copy(unsafe); moved, skipped = Fit(unsafe, rect)
Check(moved == 0 and skipped == 1 and Same(unsafe, before), "secret geometry must not cause writes")
huge.width = 100
unsafe.systems[1].anchorInfo.offsetX = secret
moved, skipped = Fit(unsafe, rect)
Check(moved == 0 and skipped == 1 and unsafe.systems[1].anchorInfo.offsetX == secret, "secret anchor offset was compared or changed")
uiScale = 0
Check(select(3, Fit(generated, rect)) == "unavailable", "invalid UI scale must fail closed")
uiScale = .581
EditModeManagerFrame.GetRegisteredSystemFrame = nil
Check(select(3, Fit(generated, rect)) == "unavailable", "older client without registered-frame lookup must retain its fallback")
print("PASS: " .. assertions .. " native HUD copy fitting, custom preservation, stretched/linked anchors and safety assertions")
