local a={db={enabled=true}}
assert(loadfile('Core/WorkspaceRegions.lua'))('Offhand',a)
assert(loadfile('Core/Viewport.lua'))('Offhand',a)
assert(loadfile(arg[1]))()
local raw=OffhandCompanionTopology
UIParent={GetWidth=function()return raw.physicalWidth/2 end,GetHeight=function()return raw.physicalHeight/2 end}
GetPhysicalScreenSize=function()return raw.physicalWidth,raw.physicalHeight end
local m=a.Viewport:GetMetrics()
assert(m.topologySchema==3 and m.isSpanned and #m.workspaceRegions==2)
assert(m.primaryWorkspaceRegion=='workspace-a')
if arg[2]=='centered' then assert(m.gamePixelLeft==1280 and m.gamePixelWidth==2560 and m.workspaceRegions[2].pixelX==3840)
elseif arg[2]=='stacked' then assert(m.gamePixelLeft==1280 and m.workspaceRegions[1].pixelY==720 and m.workspaceRegions[2].pixelY==0)
elseif arg[2]=='offset' then assert(m.gamePixelLeft==1000 and m.gamePixelBottom==0 and raw.displays[1].y==-680)
elseif arg[2]=='two-displays' then
 assert(m.gamePixelLeft==1440 and m.gamePixelBottom==960 and #raw.selectedDevices==2)
 assert(raw.selectedDevices[2]=='left-device' and m.workspaceRegions[1].device=='left-device' and m.workspaceRegions[2].device=='left-device')
 assert(m.workspaceRegions[1].pixelY==1200 and m.workspaceRegions[2].pixelY==0)
elseif arg[2]=='three-displays' then
 assert(m.gamePixelLeft==1440 and m.gamePixelBottom==0 and #raw.selectedDevices==3)
 assert(raw.selectedDevices[2]=='left-device' and raw.selectedDevices[3]=='right-device')
 assert(m.workspaceRegions[1].pixelY==240 and m.workspaceRegions[2].pixelY==360 and m.workspaceRegions[2].pixelX==6560)
else error('Unknown bridge fixture')end
assert(raw.selectedDevices[1]=='ultra-device')
if arg[2]~='two-displays' and arg[2]~='three-displays' then
 assert(not raw.selectedDevices[2],'Physical display was duplicated for same-monitor regions')
end
print('PASS: exact C# schema 3 '..arg[2]..' bridge accepted by the addon with independent region metrics')
