-- Lua 5.1. Companion topology acceptance must agree with the live UI canvas.
local addon = {}
assert(loadfile("Core/Viewport.lua"))("Offhand", addon)
local viewport = addon.Viewport
local function plan(w, h, game, workspace)
    return {schema=1, physicalWidth=w, physicalHeight=h, game=game, workspace=workspace}
end
local function rect(x, y, w, h) return {x=x, y=y, width=w, height=h} end
local mixed = plan(3640, 1816, rect(1080, 0, 2560, 1440), rect(0, 0, 1080, 1816))
-- Reporter screenshots select the portrait as Mainhand, with the landscape
-- primary as workspace. The exact vertical offset is not known; exercise
-- several valid offsets without treating screenshot proportions as pixels.
for _, offset in ipairs({0, 128, 376}) do
    addon.isForever = true
    OffhandCompanionTopology = plan(3640, 1816,
        rect(0, 0, 1080, 1816), rect(1080, offset, 2560, 1440))
    local accepted, status = viewport:GetCompanionTopology(2560, 1440, 2287, 1141)
    assert(status == "READY" and accepted.game.width == 1080 and accepted.workspace.width == 2560,
        "reporter's landscape workspace physical report must retain portrait Mainhand and offset")
    local _, restoredStatus = viewport:GetCompanionTopology(2560, 1440, 2560, 1440)
    assert(restoredStatus == "MISMATCH", "reporter's restored primary must reject the span")
end
local stacked = plan(2560, 2520, rect(0, 0, 2560, 1440), rect(200, 1440, 1920, 1080))
local split = plan(5120, 1440, rect(0, 0, 2560, 1440), rect(2560, 0, 2560, 1440))
split.mode = "SPLIT_ULTRAWIDE"
-- Investigation fixture only: the Companion planner does not yet expose this
-- partial-width mode. Characterize schema 1 acceptance without relaxing it.
local partial = plan(4080, 1440, rect(640, 0, 3440, 1440), rect(0, 0, 640, 1440))
partial.mode = "SPLIT_ULTRAWIDE"
local cases = {
    {"partial occupied window", partial, 4080, 1440, 4080, 1440, "READY"},
    {"partial stale full monitor", partial, 5120, 1440, 4080, 1440, "MISMATCH"},
    {"partial stale full canvas", partial, 4080, 1440, 5120, 1440, "MISMATCH"},
    {"partial restored game", partial, 3440, 1440, 3440, 1440, "MISMATCH"},
    {"exact mixed", mixed, 3640, 1816, 2287, 1141, "READY"},
    {"stale Mainhand", mixed, 2560, 1440, 2287, 1141, "READY"},
    {"stale workspace", mixed, 1080, 1816, 2287, 1141, "READY"},
    {"restored canvas", mixed, 2560, 1440, 2560, 1440, "MISMATCH"},
    {"stale full physical report", mixed, 3640, 1816, 2560, 1440, "MISMATCH"},
    {"unrelated physical report", mixed, 1920, 1080, 2287, 1141, "MISMATCH"},
    {"pixel tolerance", mixed, 3638, 1818, 2287, 1141, "READY"},
    {"outside pixel tolerance", mixed, 3637, 1816, 2287, 1141, "MISMATCH"},
    {"offset stacked Mainhand", stacked, 2560, 1440, 2560, 2520, "READY"},
    {"offset stacked workspace", stacked, 1920, 1080, 2560, 2520, "READY"},
    {"restored stacked", stacked, 2560, 1440, 2560, 1440, "MISMATCH"},
    {"single ultrawide split", split, 5120, 1440, 5120, 1440, "READY"},
    {"restored half split", split, 2560, 1440, 2560, 1440, "MISMATCH"},
    {"missing canvas", mixed, 3640, 1816, nil, nil, "MISMATCH"},
    {"zero canvas", mixed, 3640, 1816, 0, 0, "MISMATCH"},
    {"invalid canvas number", mixed, 3640, 1816, 0/0, 1141, "MISMATCH"},
    {"infinite canvas", mixed, 3640, 1816, math.huge, 1141, "MISMATCH"},
}
-- A diagonal arrangement can have the same overall aspect as either display.
-- A stale monitor report plus that aspect cannot establish that it is spanned.
local diagonal = plan(3840, 2160, rect(1920, 1080, 1920, 1080), rect(0, 0, 1920, 1080))
cases[#cases+1] = {"ambiguous aspect", diagonal, 1920, 1080, 1920, 1080, "MISMATCH"}
cases[#cases+1] = {"exact diagonal", diagonal, 3840, 2160, 3840, 2160, "READY"}
local nonfinite = plan(math.huge, 1816, rect(0, 0, math.huge, 1440), rect(0, 1440, 1080, 376))
cases[#cases+1] = {"infinite geometry", nonfinite, 1080, 376, 2287, 1141, "MISMATCH"}
local outside = plan(3640, 1816, rect(1080, 0, 2563, 1440), mixed.workspace)
cases[#cases+1] = {"outside bounds", outside, 3640, 1816, 2287, 1141, "MISMATCH"}
local missing = plan(3640, 1816, nil, mixed.workspace)
cases[#cases+1] = {"missing game rectangle", missing, 3640, 1816, 2287, 1141, "MISMATCH"}
local negative = plan(3640, 1816, rect(-1, 0, 2560, 1440), mixed.workspace)
cases[#cases+1] = {"negative relative coordinate", negative, 3640, 1816, 2287, 1141, "MISMATCH"}
local zero = plan(3640, 0, mixed.game, mixed.workspace)
cases[#cases+1] = {"zero topology height", zero, 3640, 1816, 2287, 1141, "MISMATCH"}
for _, forever in ipairs({false, true}) do
    addon.isForever = forever
    for _, case in ipairs(cases) do
        OffhandCompanionTopology = case[2]
        local accepted, status = viewport:GetCompanionTopology(case[3], case[4], case[5], case[6])
        assert(status == case[7], case[1] .. " Forever=" .. tostring(forever) .. ": " .. status)
        assert((accepted ~= nil) == (status == "READY"), case[1] .. ": acceptance/status disagreement")
    end
end
print("PASS: Companion topology dimensions, canvas agreement, stale APIs, offsets, split and malformed data")

local physicalWidth, physicalHeight = 4520, 1922
local canvasWidth, canvasHeight = 4520, 1922
local timers, queued, points = {}, {}, {}
local inCombat, reserved = false, false
GetPhysicalScreenSize = function() return physicalWidth, physicalHeight end
InCombatLockdown = function() return inCombat end
UIParent = {
    GetWidth = function() return canvasWidth end,
    GetHeight = function() return canvasHeight end,
    GetEffectiveScale = function() return 1 end,
}
WorldFrame = {
    GetEffectiveScale = function() return 1 end,
    ClearAllPoints = function() points = {} end,
    SetPoint = function(_, point, _, relative, x, y) points[point] = {relative, x, y} end,
}
C_Timer = {After = function(delay, callback)
    assert(delay > 0)
    timers[#timers + 1] = callback
end}
addon.RunOrQueueCombat = function(_, callback) queued[#queued + 1] = callback end
addon.IsBlizzardInputReserved = function() return reserved end
addon.Debug = function() end
addon.companionMinVersion = "2.1.8"
addon.db = {enabled=true, firstRunComplete=true, hudScale=0.65}
local reporterPlan = plan(4520, 1922, rect(1080, 0, 3440, 1440), rect(0, 2, 1080, 1920))
reporterPlan.companionVersion = "2.1.8"
OffhandCompanionTopology = reporterPlan

-- Simulate WoW replacing a correct rectangle after the normal entry apply.
local function expectRefresh()
    assert(points.BOTTOMLEFT[2] == 1080 and points.BOTTOMLEFT[3] == 0)
    assert(points.TOPRIGHT[2] == 4520 and points.TOPRIGHT[3] == 1440)
    assert(viewport.settledCompanionRefresh and addon.db.firstRunComplete and addon.db.hudScale == 0.65)
end
local function tick() table.remove(timers, 1)() end
for cycle = 1, 3 do
    viewport:Apply()
    points = {}
    viewport:ScheduleSettledCompanionRefresh()
    assert(not next(points), "the settled pass must be delayed")
    tick()
    expectRefresh()
end
points = {}
viewport:ScheduleSettledCompanionRefresh()
addon._displayGeometryGeneration = 1
tick()
assert(not next(points), "a newer display event must invalidate stale work")
viewport:ScheduleSettledCompanionRefresh()
inCombat = true
tick()
assert(not next(points) and #queued == 1, "combat must defer the viewport write")
inCombat = false
table.remove(queued, 1)()
expectRefresh()

local function expectSkipped()
    points = {}
    viewport:ScheduleSettledCompanionRefresh()
    tick()
    assert(not next(points) and not viewport.settledCompanionRefresh)
end
physicalWidth, physicalHeight, canvasWidth, canvasHeight = 3440, 1440, 3440, 1440
expectSkipped()
physicalWidth, physicalHeight, canvasWidth, canvasHeight = 4520, 1922, 4520, 1922
reporterPlan.companionVersion = "2.1.7"
expectSkipped()
reporterPlan.companionVersion = "2.1.8"
reserved = true
expectSkipped()
reserved = false
OffhandCompanionTopology = split
physicalWidth, physicalHeight, canvasWidth, canvasHeight = 5120, 1440, 5120, 1440
expectSkipped()
assert(#timers == 0, "the settled refresh must not poll")
print("PASS: repeated mixed-height re-spans recover the viewport without calibration in the fixture")
