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
local cases = {
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
