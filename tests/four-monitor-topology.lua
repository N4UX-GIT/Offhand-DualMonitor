-- Lua 5.1. Four monitors: one Mainhand plus three workspace areas, for both the
-- separate-monitor (schema 2) and flexible (schema 3) topologies.
local a={db={enabled=true}}
assert(loadfile('Core/WorkspaceRegions.lua'))('Offhand',a)
assert(loadfile('Core/WorkspaceScale.lua'))('Offhand',a)
assert(loadfile('Core/Viewport.lua'))('Offhand',a)
local R=a.WorkspaceRegions
assert(R.MAX_WORKSPACES==3 and R.MAX_DISPLAYS==4,'four monitors: 1 Mainhand + 3 workspaces')
local function copy(v)if type(v)~='table'then return v end local o={}for k,x in pairs(v)do o[k]=copy(x)end return o end
-- 1080p portrait | 4K Mainhand | 1440p | 1440p, bottoms aligned.
local function four(schema)
 local t={schema=schema,mode='CUSTOM_REGIONS',physicalWidth=10040,physicalHeight=2160,mainhandDevice='uhd',
  game={x=1080,y=0,width=3840,height=2160},primaryWorkspace='left',workspaces={
   {id='left',device='portrait',x=0,y=0,width=1080,height=1920},
   {id='right',device='qhd1',x=4920,y=0,width=2560,height=1440},
   {id='far',device='qhd2',x=7480,y=0,width=2560,height=1440}}}
 if schema==3 then
  t.coordinateSpace='BOTTOM_LEFT_PHYSICAL'
  t.selectedDevices={'portrait','uhd','qhd1','qhd2'}
  t.displays={{device='portrait',x=0,y=0,width=1080,height=1920},{device='uhd',x=1080,y=0,width=3840,height=2160},
   {device='qhd1',x=4920,y=0,width=2560,height=1440},{device='qhd2',x=7480,y=0,width=2560,height=1440}}
 end
 return t
end
assert(R:ValidateTopology(four(2)),'schema 2 accepts three workspace monitors')
assert(R:ValidateFlexibleTopology(four(3)),'schema 3 accepts four displays and three workspaces')
-- Limits still hold.
local five=four(2);five.workspaces[4]={id='extra',device='hd',x=0,y=1920,width=1080,height=240}
assert(not R:ValidateTopology(five),'four workspace areas are rejected')
local f3=four(3);f3.workspaces[4]=copy(f3.workspaces[3]);f3.workspaces[4].id='x4'
assert(not R:ValidateFlexibleTopology(f3),'four workspace areas are rejected (schema 3)')
local d5=four(3);d5.displays[5]={device='hd',x=0,y=1920,width=1080,height=240};d5.selectedDevices[5]='hd'
assert(not R:ValidateFlexibleTopology(d5),'five displays are rejected')
local dup=four(2);dup.workspaces[3].device='qhd1'
assert(not R:ValidateTopology(dup),'schema 2 still rejects two workspaces on one monitor')
local overlap=four(2);overlap.workspaces[3].x=6000
assert(not R:ValidateTopology(overlap),'overlapping workspace areas are rejected')
local budget=four(2);budget.physicalWidth=16384;budget.physicalHeight=2160*4
assert(not R:ValidateTopology(budget),'the 4x surface budget still applies')
-- Companion's generated file follows the same topology and device contract.
if arg and arg[1] then
    assert(loadfile(arg[1]))()
    UIParent = { GetWidth = function() return 5020 end, GetHeight = function() return 1080 end }
    GetPhysicalScreenSize = function() return 10040, 2160 end
    local m = a.Viewport:GetMetrics()
    assert(m.isSpanned and m.topologySchema == OffhandCompanionTopology.schema and #m.workspaceRegions == 3)
    assert(R:Destination(m, 4000, 600, 100, 100) == 'far')
    assert(m.workspaceScaleDisplays.far.device == 'far')
    print('PASS: generated Companion four-monitor bridge accepted by Lua schema ' .. m.topologySchema)
    return
end

-- Simulated metrics resolve the destinations for all four regions.
UIParent={GetWidth=function()return 5020 end,GetHeight=function()return 1080 end}
GetPhysicalScreenSize=function()return 10040,2160 end
for _,schema in ipairs({2,3})do
 OffhandCompanionTopology=four(schema)
 local m=a.Viewport:GetMetrics()
 assert(m.isSpanned and m.companionTopology and #m.workspaceRegions==3,'three live regions (schema '..schema..')')
 assert(R:Destination(m,100,600,100,100)=='left')
 assert(R:Destination(m,2000,600,100,100)=='MAINHAND')
 assert(R:Destination(m,2600,600,100,100)=='right')
 assert(R:Destination(m,4000,600,100,100)=='far','third workspace area is reachable')
 local far=R:ForRegion(m,'far')
 assert(far.workspaceRegionID=='far' and math.abs(far.workspaceLeft-3740)<1e-6,'third area metrics')
end
print('PASS: four-monitor topologies')
