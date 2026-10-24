-- No desktop enumeration or protected/native frame writes are needed.
local frames, metrics, combat = {}, nil, false
local function Frame()
    local f = {scripts = {}, events = {}, shown = false}
    frames[#frames + 1] = f
    function f:SetSize(w, h) self.width, self.height = w, h end
    function f:SetPoint(...) self.point = {...} end
    function f:ClearAllPoints() self.point = nil end
    function f:SetScale(scale) self.scale = scale end
    function f:SetFrameStrata() end
    function f:EnableMouse(value) self.mouse = value end
    function f:SetWordWrap() end
    function f:SetText(text) self.text = text end
    function f:SetScript(event, handler) self.scripts[event] = handler end
    function f:RegisterEvent(event) self.events[event] = true end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:CreateFontString() return Frame() end
    return f
end
CreateFrame = Frame
UIParent = {GetWidth = function() return 1200 end, GetHeight = function() return 768 end}
InCombatLockdown = function() return combat end
local addon = {L = setmetatable({}, {__index = function(_, key) return key end}),
    UIControls = {StyleSurface = function() end},
    Viewport = {GetMetrics = function() return metrics end},
    Print = function(self, text) self.message = text end}
assert(loadfile("UI/DisplayIdentify.lua"))("Offhand", addon)
local identify = addon.DisplayIdentify
local fallback = identify:GetRegions(nil)
assert(#fallback == 1 and fallback[1].title == "IDENTIFY_WINDOW",
    "unspanned windows must not pretend to identify physical displays")
metrics = {isSpanned = true, companionTopology = true,
    physicalWidth = 4000, physicalHeight = 2560,
    gamePixelLeft = 1440, gamePixelBottom = 200, gamePixelWidth = 2560, gamePixelHeight = 1440,
    workspacePixelLeft = 0, workspacePixelBottom = 0, workspacePixelWidth = 1440, workspacePixelHeight = 2560}
local regions = identify:GetRegions(metrics)
assert(#regions == 2 and regions[1].x == 432 and regions[1].y == 60
    and regions[1].width == 768 and regions[1].height == 432,
    "unequal display heights and offsets must convert each physical axis independently")
assert(regions[2].width == 432 and regions[2].height == 768)
assert(regions[1].detail == "IDENTIFY_EXACT")
metrics.companionTopology = false
assert(identify:GetRegions(metrics)[1].detail == "IDENTIFY_CONFIGURED",
    "manual regions must not be described as detected physical screens")
metrics.workspacePixelWidth = math.huge
assert(#identify:GetRegions(metrics) == 1, "malformed rectangles must fall back to the current window")
metrics.workspacePixelWidth = 1440
assert(identify:Show())
local first, second = frames[1], frames[5]
assert(first.shown and second.shown and not first.mouse and not second.mouse,
    "only small label cards should be shown, without a full-screen input blocker")
assert(first.title.text == "IDENTIFY_MAINHAND" and second.title.text == "IDENTIFY_OFFHAND")
local controller = frames[9]
assert(controller.events.DISPLAY_SIZE_CHANGED and controller.events.UI_SCALE_CHANGED
    and controller.events.PLAYER_REGEN_DISABLED and controller.events.PLAYER_LEAVING_WORLD)
controller.scripts.OnUpdate(controller, 11)
assert(first.shown)
controller.scripts.OnUpdate(controller, 1)
assert(not first.shown and not second.shown and not controller.scripts.OnUpdate,
    "identification must expire and remove polling")
local count = #frames
identify:Show()
assert(#frames == count, "repeated identification must reuse cards and event handlers")
first.closeButton.scripts.OnClick()
assert(not first.shown and not second.shown)
identify:Show()
controller.scripts.OnEvent(controller, "DISPLAY_SIZE_CHANGED")
assert(not first.shown and not controller.scripts.OnUpdate,
    "a geometry change must invalidate the old labels immediately")
addon._displayGeometryTransitionActive = true
identify:Show()
assert(first.title.text == "IDENTIFY_WINDOW" and not second.shown)
addon._displayGeometryTransitionActive = nil
combat = true
assert(not identify:Show() and addon.message == "IDENTIFY_COMBAT" and not first.shown)
combat = false
metrics = nil
identify:Show()
assert(first.title.text == "IDENTIFY_WINDOW" and not second.shown)
assert(first.closeButton.text == "IDENTIFY_BACK_TO_SETUP" and not controller.scripts.OnUpdate,
    "placement instructions must remain readable until explicitly closed or invalidated")
identify:Hide()
assert(not controller.scripts.OnUpdate)
print("PASS: display identification bounds, honest source labels, combat, reuse, timeout and invalidation")
