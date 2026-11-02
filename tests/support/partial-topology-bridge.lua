-- Consume bytes emitted by the actual Companion writer in a temporary fixture.
local addon = {}
assert(loadfile("Core/Viewport.lua"))("Offhand", addon)
local root = assert(arg[1], "fixture directory required")
local checks = 0
for index = 1, 8 do
    assert(loadfile(root .. "/" .. index .. ".lua"))()
    local topology = assert(OffhandCompanionTopology)
    local gameLeft = index % 2 == 0
    assert(topology.schema == 1 and topology.mode == "SPLIT_ULTRAWIDE")
    assert(topology.physicalWidth == 4080 and topology.physicalHeight == 1440)
    assert(topology.game.x == (gameLeft and 0 or 640) and topology.game.y == 0)
    assert(topology.game.width == 3440 and topology.game.height == 1440)
    assert(topology.workspace.x == (gameLeft and 3440 or 0) and topology.workspace.y == 0)
    assert(topology.workspace.width == 640 and topology.workspace.height == 1440)
    for _, forever in ipairs({false, true}) do
        addon.isForever = forever
        for _, case in ipairs({
            {4080, 1440, 4080, 1440, "READY"},
            {4080, 1440, 2040, 720, "READY"},
            {5120, 1440, 4080, 1440, "MISMATCH"},
            {3440, 1440, 3440, 1440, "MISMATCH"},
        }) do
            local accepted, status = addon.Viewport:GetCompanionTopology(case[1], case[2], case[3], case[4])
            assert(status == case[5], "fixture " .. index .. " Forever=" .. tostring(forever) .. " status=" .. status)
            assert((accepted ~= nil) == (status == "READY"))
            checks = checks + 1
        end
    end
end
print("PASS: " .. checks .. " generated C# to Lua partial-topology acceptance/rejection cases")
