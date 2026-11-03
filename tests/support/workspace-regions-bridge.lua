local addon={db={enabled=true}}
assert(loadfile('Core/WorkspaceRegions.lua'))('Offhand',addon)
assert(loadfile('Core/Viewport.lua'))('Offhand',addon)
assert(loadfile(arg[1]))()
UIParent={GetWidth=function()return 2960 end,GetHeight=function()return 720 end}
GetPhysicalScreenSize=function()return 5920,1440 end
local m=addon.Viewport:GetMetrics()
assert(m.topologySchema==2 and m.isSpanned and #m.workspaceRegions==2)
assert(m.gamePixelLeft==1440 and m.gamePixelWidth==2560 and m.workspacePixelWidth==1440)
local right=addon.WorkspaceRegions:Get(m,'right')
assert(right.pixelX==4000 and right.pixelY==360 and right.pixelWidth==1920 and right.pixelHeight==1080)
assert(not m.workspaceRegions[3])
print('PASS: exact production C# schema 2 bridge accepted by Lua viewport with independent physical/logical regions')
