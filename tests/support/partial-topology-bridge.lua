-- Consume bytes emitted by the actual Companion writer in a temporary fixture.
local addon = { db = {} }
assert(loadfile("Core/Viewport.lua"))("Offhand", addon)
assert(loadfile("Core/CanvasPersistence.lua"))("Offhand", addon)
local root = assert(arg[1], "fixture directory required")
local checks = 0
local positions = 0
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
    for _, scale in ipairs({1, 0.5}) do
        UIParent = { GetWidth = function() return 4080 * scale end,
            GetHeight = function() return 1440 * scale end }
        GetPhysicalScreenSize = function() return 4080, 1440 end
        local metrics = addon.Viewport:GetMetrics()
        assert(metrics.companionTopology and metrics.topologyStatus == "READY")
        assert(metrics.workspaceWidth == 640 * scale and metrics.workspaceHeight == 1440 * scale)
        local persistence = addon.CanvasPersistence
        for _, chat in ipairs({false, true}) do
            -- A fitting panel saved on the old wider workspace must remain
            -- reachable after shrinking and moving the workspace to either side.
            local previous = { x = 1500, y = 1200, canvasLeft = 1000,
                canvasBottom = 100, canvasWidth = 1440, canvasHeight = 2560 }
            local x, y = persistence.ResolveWorkspacePosition(metrics, previous,
                200 * scale, 250 * scale, chat)
            assert(x >= metrics.workspaceLeft + (chat and 48 or 12))
            assert(x + 200 * scale <= metrics.workspaceRight - 12)
            assert(y - 250 * scale >= metrics.workspaceBottom + 12
                and y <= metrics.workspaceTop - 12)
            local saved = assert(persistence.CreateWorkspacePosition(metrics, x, y,
                200 * scale, 250 * scale, chat))
            local restoredX, restoredY = persistence.ResolveWorkspacePosition(metrics,
                saved, 200 * scale, 250 * scale, chat)
            assert(math.abs(x - restoredX) < 0.000001 and math.abs(y - restoredY) < 0.000001)
            assert(saved.regionId == nil and previous.canvasWidth == 1440
                and previous.canvasLeft == 1000 and previous.x == 1500)
            positions = positions + 1
        end
    end
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
print("PASS: " .. positions .. " partial-workspace metric and saved-position round trips")
for index=1,4 do
    assert(loadfile(root .. "/secondary" .. index .. ".lua"))()
    local expected=assert(loadfile(root .. "/secondary" .. index .. "-expected.lua"))()
    local topology=OffhandCompanionTopology
    assert(topology.mode=="DUAL_DISPLAY" and topology.schema==1)
    assert(topology.workspace.x==expected.x and topology.workspace.y==expected.y)
    assert(topology.workspace.width==expected.w and topology.workspace.height==expected.h)
    for _,scale in ipairs({1,0.5}) do
        UIParent={GetWidth=function()return expected.width*scale end,GetHeight=function()return expected.height*scale end}
        GetPhysicalScreenSize=function()return expected.width,expected.height end
        local metrics=addon.Viewport:GetMetrics()
        assert(metrics.companionTopology and metrics.topologyStatus=="READY")
        assert(math.abs(metrics.workspaceLeft-expected.x*scale)<0.001)
        assert(math.abs(metrics.workspaceBottom-expected.y*scale)<0.001)
        assert(math.abs(metrics.workspaceWidth-expected.w*scale)<0.001)
        assert(math.abs(metrics.workspaceHeight-expected.h*scale)<0.001)
        local persistence=addon.CanvasPersistence
        local x,y=persistence.ResolveWorkspacePosition(metrics,{x=1500,y=1200,canvasLeft=0,canvasBottom=0,canvasWidth=1440,canvasHeight=2560},200*scale,250*scale,false)
        assert(x>=metrics.workspaceLeft and x+200*scale<=metrics.workspaceRight)
        assert(y-250*scale>=metrics.workspaceBottom and y<=metrics.workspaceTop)
        local saved=assert(persistence.CreateWorkspacePosition(metrics,x,y,200*scale,250*scale,false))
        local rx,ry=persistence.ResolveWorkspacePosition(metrics,saved,200*scale,250*scale,false)
        assert(math.abs(rx-x)<0.001 and math.abs(ry-y)<0.001)
        local accepted,status=addon.Viewport:GetCompanionTopology(expected.width,expected.height,expected.width*scale*0.75,expected.height*scale)
        assert(not accepted and status=="MISMATCH")
    end
end
print("PASS: secondary workspace C# to Lua metrics, offset persistence and stale-canvas rejection at two UI scales")
