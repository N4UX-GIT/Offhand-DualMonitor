-- Lua 5.1. The centre guide sits exactly on the Mainhand rectangle.
local addon = { db = { enabled = true } }
local created = {}
local function region()
    local r = { points = {}, shown = false }
    function r:ClearAllPoints() self.points = {} end
    function r:SetPoint(...) self.points[#self.points + 1] = {...} end
    function r:SetSize(w, h) self.w, self.h = w, h end
    function r:SetWidth(w) self.w = w end
    function r:SetHeight(h) self.h = h end
    function r:Show() self.shown = true end
    function r:Hide() self.shown = false end
    function r:IsShown() return self.shown end
    function r:SetFrameStrata(s) self.strata = s end
    function r:EnableMouse(v) self.mouse = v end
    function r:SetColorTexture(...) self.color = {...} end
    function r:CreateTexture() local t = region(); created[#created + 1] = t; return t end
    return r
end
local frames = 0
CreateFrame = function() frames = frames + 1; return region() end
UIParent = {}
local metrics = { isSpanned = false, physicalHeight = 2160, screenHeight = 1706.7,
    gameLeft = 852.6, gameRight = 3886.7, gameBottom = 0, gameTop = 1706.7 }
addon.Viewport = { GetMetrics = function() return metrics end }
assert(loadfile("Core/CenterGuide.lua"))("Offhand", addon)
local G = addon.CenterGuide
assert(not G:Toggle() and frames == 0, "no guide frame without a span")
metrics.isSpanned = true
assert(G:Toggle() and G.frame:IsShown(), "toggle shows the guide")
local f = G.frame
assert(f.mouse == false and f.strata == "TOOLTIP", "never takes mouse input, drawn above Edit Mode")
local anchor = f.points[1]
assert(anchor[1] == "BOTTOMLEFT" and anchor[4] == 852.6 and anchor[5] == 0, "frame anchored at Mainhand")
assert(math.abs(f.w - (3886.7 - 852.6)) < 1e-6 and math.abs(f.h - 1706.7) < 1e-6, "frame covers Mainhand")
local v = G.vertical.points
assert(math.abs(v[1][4] - (3886.7 - 852.6) / 2) < 1e-6, "vertical line at Mainhand centre")
assert(math.abs(G.horizontal.points[1][5] - 1706.7 / 2) < 1e-6, "horizontal line at Mainhand centre")
assert(math.abs(G.vertical.w - 2 * 1706.7 / 2160) < 1e-6, "2 physical pixels wide")
assert(#created == 6 and G.quarters[1].points[1][4] == f.w / 4
    and G.quarters[4].points[1][5] == f.h * 3 / 4, "quarter marks match Mainhand")
metrics.screenHeight = 900
metrics.gameBottom, metrics.gameTop = 120, 800
G:Refresh(metrics)
assert(f.points[1][5] == 120 and f.h == 680 and G.horizontal.h == 2 * 900 / 2160,
    "layout refresh tracks Mainhand changes and UI scale")
assert(G:Toggle() and not f:IsShown(), "toggle hides it")
assert(G:Toggle() and f:IsShown() and frames == 1, "toggle reuses the same frame")
metrics.isSpanned = false
G:Refresh(metrics)
assert(not f:IsShown(), "guide hides when the span ends")
print("PASS: Mainhand centre guide")
