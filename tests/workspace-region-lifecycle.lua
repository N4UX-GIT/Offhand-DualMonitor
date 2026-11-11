-- Synthetic lifecycle through the production restore and passive bag tracker.
-- This does not emulate native client timing, protected descendants or hardware.
local function copy(value)
    if type(value)~='table' then return value end
    local result={};for key,item in pairs(value)do result[key]=copy(item)end;return result
end
local function equal(a,b)
    if type(a)~=type(b)then return false end
    if type(a)~='table'then return a==b end
    for key,value in pairs(a)do if not equal(value,b[key])then return false end end
    for key in pairs(b)do if a[key]==nil then return false end end
    return true
end
local full={schema=2,mode='CUSTOM_REGIONS',physicalWidth=5920,physicalHeight=1440,
    mainhandDevice='game',primaryWorkspace='left',game={x=1440,y=0,width=2560,height=1440},
    workspaces={{id='left',device='left-monitor',x=0,y=0,width=1440,height=1440},
        {id='right',device='right-monitor',x=4000,y=0,width=1920,height=1080}}}
local name='EUI_MainBagFrame'
local function boot(db,topology,frameName)
    local name=frameName or name
    local env=setmetatable({}, {__index=_G});env._G=env
    local addon={db=copy(db),Canvas={}}
    local canvas=addon.Canvas
    env.InCombatLockdown=function()return env.combat==true end
    env.CreateFrame=function()return {RegisterEvent=function()end,SetScript=function()end}end
    env.UIParent={GetWidth=function()return topology.physicalWidth/2 end,
        GetHeight=function()return topology.physicalHeight/2 end,GetEffectiveScale=function()return 0.5 end}
    env.GetPhysicalScreenSize=function()return topology.physicalWidth,topology.physicalHeight end
    env.OffhandCompanionTopology=copy(topology)
    local function load(path)local chunk=assert(loadfile(path));setfenv(chunk,env);chunk('Offhand',addon)end
    load('Core/CanvasPanelRegistry.lua');load('Core/WorkspaceRegions.lua');load('Core/Viewport.lua');load('Core/CanvasPersistence.lua');load('Core/CanvasPanelPlacement.lua');load('Core/WorkspaceRouting.lua')
    local frame={x=1000,y=300,w=200,h=100,writes=0,shown=true}
    function frame:GetName()return name end
    function frame:GetLeft()return self.x end
    function frame:GetTop()return self.y end
    function frame:GetWidth()return self.w end
    function frame:GetHeight()return self.h end
    function frame:GetEffectiveScale()return 0.5 end
    function frame:IsShown()return self.shown end
    function frame:IsVisible()return self.shown end
    function frame:ClearAllPoints()self.writes=self.writes+1 end
    function frame:SetClampedToScreen()end
    function frame:SetPoint(_,_,_,x,y)
        if self.failAnchor then error('synthetic anchor refusal')end
        self.x,self.y=x,y;self.writes=self.writes+1
    end
    canvas.ShouldDeferSecondaryChatRestore=function()return false end
    canvas.SetWorkspacePanelOpen=function()end
    canvas.PlaceForSingleScreenRecovery=function()end
    canvas.IsFrameOnWorkspace=function(f)return addon.WorkspaceRegions:ContainsFrame(addon.Viewport:GetMetrics(),f,false)end
    local services=setmetatable({WithWorkspace=function(m)return m end,
        IsFrameOnWorkspace=canvas.IsFrameOnWorkspace,
        IsUnsafeForPanelMutation=function()return env.unsafe==true end,
        ShouldYieldFrameToClassicUIForever=function()return env.externalOwner==true end},
        {__index=function()return function()return false end end})
    addon.CanvasPanelPlacement.InstallMainhand(canvas,services)
    canvas.RestoreWorkspacePosition=addon.CanvasPersistence.InstallRestore(canvas,services)
    canvas.OnPanelDragStop=addon.CanvasPersistence.InstallDrag(canvas,services)
    load('Core/BagPersistence.lua');addon.BagPersistence.frames[name]=frame;addon.BagPersistence.paused=false
    return addon,frame,env
end
local initial={enabled=true,savedWorkspacePositions={},savedMainPositions={}}
local addon,frame=boot(initial,full)
local saved=addon.CanvasPersistence.CreateWorkspacePosition(addon.Viewport:GetMetrics(),2100,300,200,100,false)
initial.savedWorkspacePositions[name]=saved;initial.baganatorWorkspacePanels={[name]=copy(saved)}
addon,frame=boot(initial,full);addon.Canvas:RestoreWorkspacePosition(frame)
assert(frame.x==2100 and frame.y==300,'Initial region restore failed')
addon.BagPersistence:Capture();assert(addon.db.savedWorkspacePositions[name].regionId=='right')
local flipped=copy(full);flipped.primaryWorkspace='right'
addon,frame=boot(initial,flipped);addon.Canvas:RestoreWorkspacePosition(frame)
assert(frame.x==2100,'Primary change reassigned an existing region')
local missing=copy(full);missing.physicalWidth=4000;table.remove(missing.workspaces,2)
addon,frame=boot(initial,missing);addon.Canvas:RestoreWorkspacePosition(frame)
assert(frame.x>=12 and frame.x+frame.w<=720,'Missing region fallback is unreachable')
local restoreWrites=frame.writes
for i=1,10 do addon.BagPersistence:Capture()end
assert(equal(addon.db.savedWorkspacePositions[name],saved),'Passive capture replaced missing-region ownership')
assert(equal(addon.db.baganatorWorkspacePanels[name],saved),'Passive capture replaced missing-region open snapshot')
assert(frame.writes==restoreWrites and frame.regionId==nil,'Passive observer wrote to the owned root')
frame.x=frame.x+0.2;frame.h=frame.h+20;addon.BagPersistence:Capture()
assert(equal(addon.db.savedWorkspacePositions[name],saved),'Subpixel rounding or root resizing revoked region ownership')
local retained=copy(addon.db)
local reconnected,reopened=boot(retained,full);reconnected.Canvas:RestoreWorkspacePosition(reopened)
assert(reopened.x==2100 and reopened.y==300,'Reconnect lost original workspace position')
local coldFallback,coldRoot=boot(retained,missing);coldFallback.Canvas:RestoreWorkspacePosition(coldRoot)
coldFallback.BagPersistence:Capture()
assert(equal(coldFallback.db.savedWorkspacePositions[name],saved),'Fresh fixture load lost unavailable destination')
frame.shown=false;addon.BagPersistence:Capture()
assert(not next(addon.db.baganatorWorkspacePanels) and equal(addon.db.savedWorkspacePositions[name],saved),'Closing fallback bag lost position or retained stale open intent')
frame.shown=true
frame.x=frame.x+40;addon.BagPersistence:Capture()
assert(addon.db.savedWorkspacePositions[name].regionId=='left','Actual external move did not supersede fallback')
frame.x=1000;addon.BagPersistence:Capture()
assert(not addon.db.savedWorkspacePositions[name] and not next(addon.db.baganatorWorkspacePanels),'Actual Mainhand move retained stale ownership')
local ordinary,ordinaryFrame,ordinaryEnv=boot(initial,full)
ordinaryEnv.GetPhysicalScreenSize=function()return 2560,1440 end
ordinaryEnv.UIParent.GetWidth=function()return 1280 end
ordinaryFrame.x=1000;ordinary.BagPersistence:Capture()
assert(equal(ordinary.db.savedWorkspacePositions[name],saved),'Single-screen fallback erased saved region')
assert(equal(ordinary.db.baganatorWorkspacePanels[name],saved),'Single-screen fallback erased open snapshot')
for _,guard in ipairs({'combat','externalOwner'})do
    local guarded,root,env=boot(initial,full);env[guard]=true
    guarded.Canvas:RestoreWorkspacePosition(root)
    assert(root.writes==0 and equal(guarded.db.savedWorkspacePositions[name],saved),'Restore ignored ownership guard: '..guard)
end
local legacy=copy(initial);legacy.savedWorkspacePositions[name]={x=2100,y=300}
addon,frame=boot(legacy,full);frame.failAnchor=true
assert(not pcall(addon.Canvas.RestoreWorkspacePosition,addon.Canvas,frame))
assert(not addon.db.savedWorkspacePositions[name].regionId and not addon.db.savedWorkspaceRegionLegacyPositions,'Failed anchor published migration')
frame.failAnchor=false;addon.Canvas:RestoreWorkspacePosition(frame)
assert(addon.db.savedWorkspacePositions[name].regionId=='right' and equal(addon.db.savedWorkspaceRegionLegacyPositions[name],legacy.savedWorkspacePositions[name]),'Successful migration did not preserve legacy record')
print('PASS: independent region restore, cold fixture state, primary change, missing/reconnected region, passive bags, safe fallback and ownership guards')

-- A narrow region cannot contain an oversized root. Automatic Mainhand fallback
-- must retain saved intent through passive replacement-bag capture and fresh boot.
local oversized=copy(initial)
addon,frame=boot(oversized,full);frame.w=1000
addon.Canvas:RestoreWorkspacePosition(frame)
assert(frame.x>=720 and frame.x+frame.w<=2000,'Oversized panel did not recover inside Mainhand')
for i=1,10 do addon.BagPersistence:Capture() end
assert(equal(addon.db.savedWorkspacePositions[name],saved),'Passive capture erased oversized fallback intent')
assert(equal(addon.db.baganatorWorkspacePanels[name],saved),'Passive capture erased oversized fallback open state')
local recovered=copy(addon.db)
local cold,root=boot(recovered,full);root.w=1000;cold.Canvas:RestoreWorkspacePosition(root)
assert(root.x>=720 and equal(cold.db.savedWorkspacePositions[name],saved),'Cold oversized recovery lost saved region')
root.w=200;cold.Canvas:RestoreWorkspacePosition(root)
assert(root.x==2100 and root.y==300,'Fitting panel did not return to saved region')
cold.BagPersistence:Capture()
assert(cold.db.savedWorkspacePositions[name].regionId=='right')
print('PASS: oversized region restore keeps Mainhand reachable and preserves passive/cold recovery intent')

addon,frame=boot(initial,full);frame.w=1000;frame.x=2000
addon.Canvas.OnPanelDragStop(frame)
assert(equal(addon.db.savedWorkspacePositions[name],saved),'Rejected oversized drop replaced saved placement')
assert(frame.x>=720 and frame.x+frame.w<=2000,'Rejected drop did not recover to Mainhand')
addon.BagPersistence:Capture()
assert(equal(addon.db.savedWorkspacePositions[name],saved),'Rejected drop fallback was treated as explicit Mainhand move')
frame.x=frame.x+40;addon.BagPersistence:Capture()
assert(not addon.db.savedWorkspacePositions[name],'Genuine external move did not supersede fit fallback')
print('PASS: oversized drop preserves prior intent until a genuine external move')
addon,frame=boot(initial,full);frame.h=1000
addon.Canvas:RestoreWorkspacePosition(frame)
assert(frame.y<=720-12 and frame.y>=12,'Oversized fallback title is outside the physical Mainhand')
assert(equal(addon.db.savedWorkspacePositions[name],saved),'Tall fallback replaced original intent')
for _,guard in ipairs({'combat','externalOwner'})do
    local guarded,root,env=boot(initial,full);root.w=1000;env[guard]=true
    guarded.Canvas:RestoreWorkspacePosition(root)
    assert(root.writes==0,'Oversized recovery ignored '..guard)
end
print('PASS: tall fallback keeps title reachable and respects ownership guards')

-- Rules must pass the production restore guards before generating any record.
local routedDB={enabled=true,savedWorkspacePositions={},savedMainPositions={},workspacePanelRoutes={achievements='right'}}
for _,guard in ipairs({'combat','externalOwner','unsafe'})do
    local guarded,root,env=boot(routedDB,full,'AchievementFrame');env[guard]=true
    guarded.Canvas:RestoreWorkspacePosition(root)
    assert(root.writes==0 and not next(guarded.db.savedWorkspacePositions),'Routing bypassed '..guard)
end
local routed,root=boot(routedDB,full,'AchievementFrame')
routed.Canvas:RestoreWorkspacePosition(root)
assert(root.x>=2012 and routed.db.savedWorkspacePositions.AchievementFrame.autoRoute=='achievements','First routed restore did not use the target region')
local routedSaved=copy(routed.db)
local fallback,fallbackRoot=boot(routedSaved,missing,'AchievementFrame')
fallback.Canvas:RestoreWorkspacePosition(fallbackRoot)
assert(fallbackRoot.x<720 and fallback.db.savedWorkspacePositions.AchievementFrame.regionId=='right','Missing routed region lost intent or was unreachable')
local returned,returnedRoot=boot(fallback.db,full,'AchievementFrame')
returned.Canvas:RestoreWorkspacePosition(returnedRoot)
assert(returnedRoot.x>=2012,'Routed region reconnect did not restore its destination')
returnedRoot.x=100;returnedRoot.y=500;returned.Canvas.OnPanelDragStop(returnedRoot)
local manual=returned.db.savedWorkspacePositions.AchievementFrame
assert(manual.regionId=='left' and not manual.autoRoute,'Real drag did not supersede automatic routing')
returned.WorkspaceRouting:SetRule('achievements','right');returned.Canvas:RestoreWorkspacePosition(returnedRoot)
assert(returned.db.savedWorkspacePositions.AchievementFrame==manual and returnedRoot.x<720,'A rule change overrode manual placement')
local large,largeRoot=boot(routedDB,full,'AchievementFrame');largeRoot.w=2000
large.Canvas:RestoreWorkspacePosition(largeRoot)
assert(largeRoot.x>=720 and large.db.savedWorkspacePositions.AchievementFrame.regionId=='right','Oversized routed panel did not retain intent during Mainhand recovery')
print('PASS: production routing guards, first restore, missing/reconnected regions, real manual drag and oversized Mainhand recovery')
