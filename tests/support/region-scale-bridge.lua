local a={db={enabled=true}}
assert(loadfile('Core/WorkspaceRegions.lua'))('Offhand',a)
assert(loadfile('Core/WorkspaceScale.lua'))('Offhand',a)
assert(loadfile('Core/Viewport.lua'))('Offhand',a)
assert(loadfile(arg[1]))()
UIParent={GetWidth=function()return 1500 end,GetHeight=function()return 600 end}
GetPhysicalScreenSize=function()return 3000,1200 end
local m=a.Viewport:GetMetrics();local S=a.WorkspaceScale
assert(m.isSpanned and #m.workspaceRegions==2)
assert(S:GetMultiplier(m,'a')==1 and S:GetMultiplier(m,'b')==1,'New metadata changed an existing size')
assert(S:SetSetting(m,'a','AUTO'));assert(S:SetSetting(m,'b','AUTO'))
assert(S:GetMultiplier(m,'a')==.5 and S:GetMultiplier(m,'b')==.75)
OffhandCompanionTopology.panelScaleMetadata.workspaces.a.percent=300
assert(S:GetMultiplier(m,'a')==.5,'Applied metrics alias raw metadata')
print('PASS: generated Companion scale metadata accepted by exact Lua schema '..m.topologySchema)
