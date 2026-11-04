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
else error('Unknown bridge fixture')end
assert(raw.selectedDevices[1]=='ultra-device' and not raw.selectedDevices[2],'Physical display was duplicated for same-monitor regions')
print('PASS: exact C# schema 3 '..arg[2]..' bridge accepted by the addon with independent region metrics')
