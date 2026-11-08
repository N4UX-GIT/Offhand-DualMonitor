local a={db={enabled=true}}
assert(loadfile('Core/WorkspaceRegions.lua'))('Offhand',a)
assert(loadfile('Core/Viewport.lua'))('Offhand',a)
assert(loadfile('Core/WorkspaceProfiles.lua'))('Offhand',a)
local function copy(v)
 if type(v)~='table' then return v end
 local out={};for k,x in pairs(v)do out[k]=copy(x)end;return out
end
local function centered()
 return {schema=3,mode='CUSTOM_REGIONS',coordinateSpace='BOTTOM_LEFT_PHYSICAL',physicalWidth=5120,physicalHeight=1440,
  mainhandDevice='ultra',selectedDevices={'ultra'},displays={{device='ultra',x=0,y=0,width=5120,height=1440}},
  game={x=1280,y=0,width=2560,height=1440},primaryWorkspace='left',workspaces={
   {id='left',device='ultra',x=0,y=0,width=1280,height=1440},
   {id='right',device='ultra',x=3840,y=0,width=1280,height=1440}}}
end
local raw=centered();local valid=a.WorkspaceRegions:ValidateFlexibleTopology(raw)
assert(valid and valid.workspace==raw.workspaces[1] and not raw.workspace,'Validator modified the generated bridge')
assert(not a.WorkspaceRegions:ValidateTopology(raw),'Legacy reader accepted schema 3')
local old=copy(raw);old.schema=2;assert(not a.WorkspaceRegions:ValidateTopology(old),'Schema 2 same-device guard weakened')
UIParent={GetWidth=function()return 2560 end,GetHeight=function()return 720 end}
GetPhysicalScreenSize=function()return 5120,1440 end
OffhandCompanionTopology=raw
local m=a.Viewport:GetMetrics()
assert(m.topologySchema==3 and m.isSpanned and #m.workspaceRegions==2)
assert(m.gamePixelLeft==1280 and m.gamePixelWidth==2560 and m.gameLeft==640 and m.gameRight==1920)
assert(m.workspaceRegions[2].x==1920 and m.workspaceRegions[2].width==640)
assert(a.WorkspaceRegions:Destination(m,200,500,100,100)=='left')
assert(a.WorkspaceRegions:Destination(m,1100,500,100,100)=='MAINHAND')
assert(a.WorkspaceRegions:Destination(m,2100,500,100,100)=='right')
raw.workspaceProfileID=string.rep('a',32);raw.workspaceProfileName='Centered desk'
a.WorkspaceProfiles:SyncCompanion(m)
assert(select(2,a.WorkspaceProfiles:List())=='companion_'..raw.workspaceProfileID,'New schema did not associate its named addon layout')
assert(a.WorkspaceProfiles:Create('Manual selection'));local _,manual=a.WorkspaceProfiles:List()
a.WorkspaceProfiles:SyncCompanion(m);assert(select(2,a.WorkspaceProfiles:List())==manual,'Reload/reapply overwrote manual selection')

local mutations={
 function(t)t.coordinateSpace='TOP_LEFT'end,
 function(t)t.displays=nil end,function(t)t.displays[1].width=100 end,
 function(t)t.displays[1].x=-32769 end,function(t)t.displays[1].width=32769 end,
 function(t)t.displays[1].x=.5 end,function(t)t.displays[1].device='other'end,
 function(t)t.displays[2]=copy(t.displays[1])end,
 function(t)t.displays[3]=copy(t.displays[1])end,
 function(t)t.displays[1].x=1 end,
 function(t)t.displays[2]={device='unused',x=5120,y=0,width=960,height=600};t.selectedDevices[2]='unused'end,
 function(t)t.selectedDevices={'ultra','ULTRA'}end,function(t)t.selectedDevices[1]='other'end,
 function(t)t.selectedDevices[3]='ultra'end,function(t)t.selectedDevices='ultra'end,
 function(t)t.workspaces[1].id='game'end,function(t)t.workspaces[2].id='left'end,
 function(t)t.workspaces[2].device='other'end,function(t)t.game.x=0 end,
 function(t)t.workspaces[2].x=1 end,function(t)t.workspaces[1].height=599 end,
 function(t)t.workspaces[1].width=479 end,function(t)t.workspaces[1].x=0/0 end,
 function(t)t.schema=4 end,function(t)t.physicalWidth=16385 end,
}
for i,mutate in ipairs(mutations)do
 local bad=centered();mutate(bad)
 assert(not a.WorkspaceRegions:ValidateFlexibleTopology(bad),'Malformed flexible topology accepted: '..i)
end
-- A monitor may extend below the native backing window. Stale physical API
-- dimensions need matching UI aspect and a declared full-monitor rectangle.
local offset={schema=3,mode='CUSTOM_REGIONS',coordinateSpace='BOTTOM_LEFT_PHYSICAL',physicalWidth=2920,physicalHeight=1480,
 mainhandDevice='ultra',selectedDevices={'ultra'},displays={{device='ultra',x=0,y=-680,width=3840,height=2160}},
 game={x=1000,y=0,width=1920,height=1080},primaryWorkspace='a',workspaces={
 {id='a',device='ultra',x=0,y=880,width=800,height=600},{id='b',device='ultra',x=0,y=180,width=800,height=600}}}
assert(a.WorkspaceRegions:ValidateFlexibleTopology(offset))
OffhandCompanionTopology=offset
UIParent.GetWidth=function()return 1460 end;UIParent.GetHeight=function()return 740 end
GetPhysicalScreenSize=function()return 3840,2160 end
assert(a.Viewport:GetMetrics().topologySchema==3,'Matching declared monitor fallback was not accepted')
m=a.Viewport:GetMetrics();assert(not a.WorkspaceRegions:Destination(m,450,400,20,20),'Desktop gap was claimed by a workspace')
UIParent.GetWidth=function()return 1920 end;UIParent.GetHeight=function()return 1080 end
assert(not a.Viewport:GetMetrics().isSpanned,'Restored UI aspect accepted stale topology')
print('PASS: flexible topology bounds/device coverage, same-monitor destinations, profile association, malformed data and stale-window refusal')
