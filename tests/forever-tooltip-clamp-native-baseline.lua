-- Forever report (14 Nov 2026): after hovering bag gear on the Offhand workspace
-- (with a comparison card), world tooltips owned by UIParent kept the
-- workspace's right/top clamp and were squeezed into the workspace corner.
-- Captured: bag -12/2538.4/153.6/-12.6, then world -652/2538.4/153.6/-12.
-- Each clamp must be built from the tooltip's own native insets, never from
-- insets left on the frame by an earlier clamp or by the comparison layout.
local combat = false
InCombatLockdown = function() return combat end
UIParent = { GetEffectiveScale = function() return 0.6 end,
    GetWidth = function() return 2916 end, GetHeight = function() return 1280 end }
local metrics = { isSpanned = true, hudScale = 1,
    gameLeft = 640, gameRight = 2916, gameBottom = 0, gameTop = 1280,
    workspaceLeft = 0, workspaceRight = 640, workspaceBottom = 0.6, workspaceTop = 1138.4 }
local addon = { isForever = true, modules = {}, db = { enabled = true, seamRedirect = true },
    Viewport = { GetMetrics = function() return metrics end } }
assert(loadfile("Core/PopupBounds.lua"))("Offhand", addon)

local function rect(l, r, t, b)
    return { GetLeft = function() return l end, GetRight = function() return r end,
        GetTop = function() return t end, GetBottom = function() return b end,
        GetEffectiveScale = function() return 0.6 end, IsObjectType = function() return false end,
        IsShown = function() return true end, ClearAllPoints = function() end, SetPoint = function() end }
end
local bagItem = rect(100, 130, 400, 370)
local tooltip = rect(0, 0, 0, 0)
local pos = { 2600, 2814, 300, 265 }
tooltip.GetLeft = function() return pos[1] end
tooltip.GetRight = function() return pos[2] end
tooltip.GetTop = function() return pos[3] end
tooltip.GetBottom = function() return pos[4] end
local insets, clamped, owner, shown = { 0, 0, 25, 0 }, false, nil, false
tooltip.IsShown = function() return shown end
tooltip.GetOwner = function() return owner end
tooltip.GetClampRectInsets = function() return unpack(insets) end
tooltip.SetClampRectInsets = function(_, ...) assert(not combat); insets = { ... } end
tooltip.IsClampedToScreen = function() return clamped end
tooltip.SetClampedToScreen = function(_, value) clamped = value end
tooltip.GetScale = function() return 1 end
tooltip.SetScale = function() end
GameTooltip = tooltip
addon.PopupBounds:ObserveTooltip(tooltip) -- records the native baseline {0,0,25,0}

local function Clamp(newOwner, left)
    owner, shown, pos = newOwner, true, { left, left + 214, 300, 265 }
    assert(addon.PopupBounds:UpdateClassicTooltipClamp(tooltip), "clamp was not applied")
    return insets
end
local function Near(a, b) return math.abs(a - b) < 0.05 end

local world = Clamp(UIParent, 2600)
assert(Near(world[1], -652) and Near(world[2], 12) and Near(world[3], 25) and Near(world[4], -12),
    "fresh world tooltip must use the Mainhand clamp")

local bag = Clamp(bagItem, 140)
assert(Near(bag[1], -12) and Near(bag[3], 153.6), "bag tooltip must use the workspace clamp")

-- The comparison layout (or any refresh) changes the insets outside our
-- state, and the hide that should restore them never matches. Simulate the
-- leftover the capture showed on the hidden tooltip.
insets = { -12, 2538.4, 153.6, -0.0 }
shown = false

world = Clamp(UIParent, 2600)
assert(Near(world[1], -652), "world tooltip left limit must be Mainhand")
assert(Near(world[2], 12), "a workspace right limit leaked into a world tooltip: " .. world[2])
assert(Near(world[3], 25), "a workspace top limit leaked into a world tooltip: " .. world[3])
assert(Near(world[4], -12), "world tooltip bottom limit must be Mainhand")
print("forever-tooltip-clamp-native-baseline: ok")
