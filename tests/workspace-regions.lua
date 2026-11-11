local addon={db={enabled=true}}
assert(loadfile('Core/WorkspaceRegions.lua'))('Offhand',addon)
assert(loadfile('Core/Viewport.lua'))('Offhand',addon)
local R,V=addon.WorkspaceRegions,addon.Viewport
local function copy(t) if type(t)~='table' then return t end local r={} for k,v in pairs(t) do r[k]=copy(v) end return r end
local function rect(x,y,w,h,id,device) return {x=x,y=y,width=w,height=h,id=id,device=device} end
local raw={schema=2,mode='CUSTOM_REGIONS',physicalWidth=5920,physicalHeight=1440,
 mainhandDevice='game',game=rect(1440,0,2560,1440),primaryWorkspace='left',
 workspaces={rect(0,0,1440,1440,'left','display-left'),rect(4000,0,1920,1080,'right','display-right')}}
assert(R:ValidateTopology(raw).workspace.id=='left' and not raw.workspace)
for _,change in ipairs({
 function(t)t.workspaces[2].id='left'end, function(t)t.workspaces[2].device='DISPLAY-LEFT'end,
 function(t)t.workspaces[2].device='GAME'end,function(t)t.workspaces[2].x=3900 end,
 function(t)t.workspaces[2].width=0 end,function(t)t.workspaces[2].height=599 end,
 function(t)t.workspaces[2].x=0/0 end,function(t)t.workspaces[2].x=4000.5 end,
 function(t)t.workspaces[2].x=-1 end,function(t)t.workspaces[2].width=2000 end,
 function(t)t.workspaces[2].id='with space'end,function(t)t.primaryWorkspace='gone'end,
 function(t)t.workspaces[3]=copy(t.workspaces[2])end,function(t)t.workspaces.extra=true end,
 function(t)t.workspaces[1]=nil end,function(t)t.physicalWidth=17000 end,
 function(t)t.physicalWidth=16000;t.physicalHeight=1440 end,
 function(t)t.game.width=900 end,function(t)t.mode='DUAL_DISPLAY'end,
 function(t)t.workspaces[2].x=600;t.workspaces[2].width=500 end,
}) do local t=copy(raw);change(t);assert(not R:ValidateTopology(t),'Malformed region accepted') end
UIParent={GetWidth=function()return 2960 end,GetHeight=function()return 720 end,GetEffectiveScale=function()return 0.5 end}
GetPhysicalScreenSize=function()return 5920,1440 end
OffhandCompanionTopology=raw
local m=V:GetMetrics()
assert(m.topologySchema==2 and m.isSpanned and #m.workspaceRegions==2)
assert(m.gamePixelLeft==1440 and m.workspaceWidth==720 and m.workspaceRight==720)
assert(R:ForRegion(m,'right').workspaceLeft==2000 and m.workspaceLeft==0)
assert(R:Destination(m,2100,300,200,100)=='right')
assert(R:Destination(m,1000,300,200,100)=='MAINHAND')
assert(R:Destination(m,2100,700,100,100)==nil,'Reserved hole became workspace')
assert(R:Destination(m,1900,300,400,100)=='right','Overlap fallback lost workspace')
local seams=R:Seams(m)
assert(#seams==2 and seams[1].height==720 and seams[2].height==540,'Adjacent workspace seam segments incorrect')
local distant=copy(m);distant.workspaceRegions[2].x=2100
assert(#R:Seams(distant)==1,'Guide invented a seam across a desktop gap')
local f={GetLeft=function()return 4200 end,GetTop=function()return 600 end,
 GetWidth=function()return 400 end,GetHeight=function()return 200 end,GetEffectiveScale=function()return 0.25 end}
assert(R:ContainsFrame(m,f,true))
assert(R:ForFrame(m,f).workspaceRegionID=='right')
local p=R:SavePosition({x=2100,y=300},R:ForRegion(m,'right'))
assert(p.regionId=='right' and math.abs(p.regionX-100/960)<0.00001)
assert(R:ForFrame(m,f,{regionId='missing'}).workspaceRegionID=='left')
assert(m.workspaceLeft==0 and not raw.workspace and raw.workspaces[2].x==4000)
assert(loadfile('Core/CanvasPersistence.lua'))('Offhand',addon)
local saved=addon.CanvasPersistence.CreateWorkspacePosition(m,2100,300,200,100,false)
assert(saved.regionId=='right','Drag did not persist destination region')
assert(R:ForPosition(m,{x=2100,y=300},200,100).workspaceRegionID=='right','Legacy placement containment migration lost region')
local resized=copy(m);resized.workspaceRegions[2].x=2200;resized.workspaceRegions[2].width=800
local x,y=addon.CanvasPersistence.ResolveWorkspacePosition(resized,saved,200,100,false)
assert(math.abs(x-(2200+saved.regionX*800))<0.001 and y==300,'Saved region-relative position did not follow moved/resized region')
local removed=copy(m);table.remove(removed.workspaceRegions,2)
local fallback=addon.CanvasPersistence.ResolveWorkspacePosition(removed,saved,200,100,false)
assert(fallback>=12 and fallback<=508 and saved.regionId=='right','Missing region did not preserve record and fall back safely')
local preference='AUTO'
addon.ManualCanvas={GetGeometryPreference=function()return preference end,Match=function()return {state='MATCH'} end}
OffhandCompanionTopology=copy(raw);OffhandCompanionTopology.primaryWorkspace='missing'
local safe=V:GetMetrics()
assert(not safe.isSpanned and safe.topologyStatus=='MISMATCH','Rejected schema 2 fell back to a manual split')
OffhandCompanionTopology=raw
local _,status=V:GetCompanionTopology(2560,1440,2560,1440)
assert(status=='MISMATCH','Restored ordinary window accepted stale schema 2')
local old={schema=1,physicalWidth=4000,physicalHeight=1440,game=rect(1440,0,2560,1440),workspace=rect(0,0,1440,1440)}
OffhandCompanionTopology=old
GetPhysicalScreenSize=function()return 4000,1440 end
UIParent.GetWidth=function()return 2000 end
local legacy=V:GetMetrics()
assert(legacy.isSpanned and not legacy.workspaceRegions and legacy.gamePixelLeft==1440,'Schema 1 contract changed')
print('PASS: schema 2 strict validation, primary aliases, independent destinations, holes, scale conversion, ownership and safe mismatch; schema 1 preserved')
