-- Lua 5.1: production region resolver, placement transactions and lifecycle.
local a={db={enabled=true,savedWorkspacePositions={},savedMainPositions={},independentWorkspacePanels=false,
    persistentWorkspacePanels=false},Canvas={}}
local combat,timers,queue=false,{},{}
InCombatLockdown=function()return combat end
C_Timer={After=function(_,f)timers[#timers+1]=f end}
function a:RunOrQueueCombat(f)queue[#queue+1]=f end
local function flush()
    local q=timers;timers={};for _,f in ipairs(q)do f()end
end
local function near(x,y)assert(math.abs(x-y)<.0001,tostring(x)..' ~= '..tostring(y))end
hooksecurefunc=function(obj,method,fn)
    if type(obj)=='string' then fn=method;method=obj;obj=_G end
    local original=obj[method]
    obj[method]=function(...)local r=original(...);fn(...);return r end
end
UIParent={GetEffectiveScale=function()return .5 end,GetWidth=function()return 3000 end,GetHeight=function()return 1000 end}
local function frame(name,width)
    local f={name=name,scale=1,x=1400,y=900,w=width or 600,h=300,writes=0}
    function f:GetName()return self.name end
    function f:GetScale()return self.scale end
    function f:SetScale(v)if self.reject then error('rejected')end;self.scale=v;self.writes=self.writes+1 end
    function f:GetEffectiveScale()return self.scale*.5 end
    function f:GetLeft()return self.x end;function f:GetTop()return self.y end
    function f:GetWidth()return self.w end;function f:GetHeight()return self.h end
    function f:IsShown()return not self.hidden end
    function f:IsProtected()return self.protected end
    function f:IsForbidden()return self.forbidden end
    function f:ClearAllPoints()end
    function f:SetPoint(_,_,_,x,y)self.x=x;self.y=y end
    function f:SetUserPlaced()end;function f:SetClampedToScreen()end
    function f:GetParent()return self.parent or UIParent end
    _G[name]=f;return f
end
assert(loadfile('Core/WorkspaceRegions.lua'))('Offhand',a)
assert(loadfile('Core/WorkspaceScale.lua'))('Offhand',a)
assert(loadfile('Core/CanvasPanelRegistry.lua'))('Offhand',a)
assert(loadfile('Core/CanvasPersistence.lua'))('Offhand',a)
assert(loadfile('Core/CanvasPanelPlacement.lua'))('Offhand',a)
local S,R,P=a.WorkspaceScale,a.WorkspaceRegions,a.CanvasPersistence
local m={isSpanned=true,companionTopology=true,screenWidth=3000,screenHeight=1000,physicalWidth=6000,
    gameLeft=0,gameRight=1000,gameBottom=0,gameTop=1000,gameWidth=1000,gameHeight=1000,
    workspaceLeft=1000,workspaceRight=2000,workspaceBottom=0,workspaceTop=1000,workspaceWidth=1000,workspaceHeight=1000,
    primaryWorkspaceRegion='a',workspaceRegions={{id='a',device='left',x=1000,y=0,width=1000,height=1000},
        {id='b',device='right',x=2000,y=0,width=1000,height=1000}}}
local raw={schema=3,mode='CUSTOM_REGIONS',mainhandDevice='main',workspaceProfileID=string.rep('a',32),
    selectedDevices={'main','left','right'},game={x=0,y=0,width=2000,height=2000},
    workspaces={{id='a',device='left'},{id='b',device='right'}},
    panelScaleMetadata={version=1,game={device='main',identity='main-id',percent=200},workspaces={
        a={device='left',identity='left-id',percent=100},b={device='right',identity='right-id',percent=150}}}}
S:ApplyTopologyMetrics(m,raw)
a.Viewport={GetMetrics=function()return m end}
local restoreCount=0
function a.Canvas:CanScaleWorkspacePanel(f)return not (f.protected or f.forbidden or f.external or f.editMode)end
function a.Canvas:ShouldDeferSecondaryChatRestore()return false end
function a.Canvas:SetWorkspacePanelOpen()end
local services=setmetatable({WithWorkspace=function(x)return x end,
    GetNonMovablePanels=function()return {}end,IsFrameOnWorkspace=function()return true end,
    IsUnsafeForPanelMutation=function(f)return not a.Canvas:CanScaleWorkspacePanel(f)end},
    {__index=function()return function()return false end end})
a.CanvasPanelPlacement.InstallMainhand(a.Canvas,services)
local restore=P.InstallRestore(a.Canvas,services)
a.Canvas.RestoreWorkspacePosition=function(self,f)restoreCount=restoreCount+1;return restore(f or self)end
local drag=P.InstallDrag(a.Canvas,services)
local ma,mb=R:ForRegion(m,'a'),R:ForRegion(m,'b')

-- New metadata must not change existing users, even after repeated refresh.
assert(S:GetSetting(ma)==1 and S:GetMultiplier(ma)==1)
local bag=frame('ContainerFrameCombinedBags')
a.db.savedWorkspacePositions[bag.name]={x=1400,y=900,regionId='a'}
restore(bag);S:Refresh();assert(bag.scale==1 and bag.writes==0)
assert(not S:SetSetting(ma,'missing',.5))
assert(S:SetSetting(ma,'a','AUTO'))
near(S:GetMultiplier(ma),.5);near(S:GetMultiplier(mb),1)
assert(S:SetSetting(mb,'b','AUTO'));near(S:GetMultiplier(mb),.75)
raw.panelScaleMetadata.workspaces.a.percent=999
near(S:GetMultiplier(ma),.5) -- metrics own a sanitized copy
assert(S:SetSetting(ma,'a',.5));restore(bag);near(bag.scale,.5)
local writes=bag.writes;restore(bag);assert(bag.writes==writes)

-- Drag resolves a region once, before measuring the desired scale.
local large=frame('LargeReviewPanel',1200);large.x=1100
drag(large);near(large.scale,.5)
assert(a.db.savedWorkspacePositions[large.name].regionId=='a','Shrink-to-fit was rejected')
local small=frame('SmallReviewPanel',600);small.x=1400
assert(S:SetSetting(ma,'a',1.5));drag(small)
near(small.scale,1.5)
assert(small.x*small.scale+small.w*small.scale<=1988.01,'Enlarged drag overflowed')
small.x=2200/small.scale;drag(small)
near(small.scale,.75);assert(a.db.savedWorkspacePositions[small.name].regionId=='b')
assert(S:SetSetting(ma,'a',.5))

-- A native bag reset coalesces one repair and re-enters the real restore path.
restore(bag);flush();local before=restoreCount
bag:SetScale(1);bag:SetScale(1);assert(#timers==1)
flush();near(bag.scale,.5);assert(restoreCount==before+1)
assert(#timers==0,'Self writes scheduled another resize')
bag:SetScale(.8);flush();near(bag.scale,.8)
restore(bag);near(bag.scale,.8) -- external final scale is respected

-- Recheck protected/owner/Edit Mode state after the timer was scheduled.
local guarded=frame('GuardedPanel');restore(guarded)
a.db.savedWorkspacePositions[guarded.name]={x=1400,y=900,regionId='a'}
restore(guarded);S:Schedule(guarded);guarded.protected=true
writes=guarded.writes;flush();assert(guarded.writes==writes)
guarded.protected=false;S:Schedule(guarded);guarded.external=true
flush();assert(guarded.writes==writes);guarded.external=false

-- An intentional oversized Mainhand fallback retains workspace intent, but a
-- delayed reset must not resize it again. A user setting change can retry it.
local fallback=frame('FallbackPanel',2400)
a.db.savedWorkspacePositions[fallback.name]={x=1400,y=900,regionId='a'}
restore(fallback);near(fallback.scale,1)
assert(P.PreservedFitFallback(fallback,m,a.db.savedWorkspacePositions[fallback.name]))
writes=fallback.writes;S:Schedule(fallback);flush();assert(fallback.writes==writes)

-- Superseded work must not act on another profile/layout or cross combat.
before=restoreCount;writes=guarded.writes
S:Schedule(guarded);local old=a.db;a.db={enabled=true,savedWorkspacePositions={},savedMainPositions={}}
flush();assert(guarded.writes==writes and restoreCount==before,'Stale work touched a new profile')
a.db=old
combat=true;before=restoreCount;S:Schedule(guarded);flush();assert(restoreCount==before and #queue>0)
S.generation=S.generation+1;combat=false
local q=queue;queue={};for _,fn in ipairs(q)do fn()end;flush();assert(restoreCount==before)

-- Failed writes do not publish applied ownership, and remain retryable.
local bad=frame('RejectedPanel');bad.reject=true
assert(not S:Apply(bad,true,ma));assert(not S.state[bad] and S.lastFailure==bad.name)
bad.reject=false;assert(S:Apply(bad,true,ma));near(bad.scale,.5)
local protected=frame('ObjectiveTrackerFrame');protected.protected=true
assert(S:Apply(protected,true,ma));assert(protected.writes==0)

-- Optional chat follows its dock primary. Every separate secondary edit box
-- transfers with it; inherited tabs never receive a second multiplier.
local c1,c3=frame('ChatFrame1'),frame('ChatFrame3')
local dock,e3,t3=frame('GeneralDockManager'),frame('ChatFrame3EditBox'),frame('ChatFrame3Tab')
GENERAL_CHAT_DOCK=dock;dock.primary=c1;dock.DOCKED_CHAT_FRAMES={c1}
assert(S:SetSetting(ma,'a',.5,false));S:Apply(c3,true,ma);near(c3.scale,1)
assert(S:SetSetting(ma,'a',.5,true));S:Apply(c3,true,ma);near(e3.scale,.5)
dock.DOCKED_CHAT_FRAMES={c1,c3};t3.parent=dock
S:Apply(c1,true,ma);near(t3.scale,1);near(e3.scale,.5)
S:Apply(c1,false,ma)
for _,f in ipairs({c1,c3,dock,e3,t3})do near(f.scale,1)end
GENERAL_CHAT_DOCK=nil

-- Region settings survive preset save/activate/copy, without leaking values.
assert(loadfile('Core/WorkspaceProfiles.lua'))('Offhand',a)
local profiles=a.WorkspaceProfiles
assert(profiles:List());assert(profiles:Create('Second'))
assert(S:SetSetting(ma,'a',.9));assert(profiles:Activate('default'))
near(S:GetSetting(ma),.5)
local second
for _,item in ipairs(profiles:List())do if item.name=='Second' then second=item.id end end
assert(profiles:Activate(second));near(S:GetSetting(ma),.9)
local store=a.db.workspaceRegionScales;store.version=99
assert(not S:SetSetting(ma,'a',.8) and store.version==99)
near(S:GetMultiplier(ma),1);store.version=1

-- Auto fallback, clamping, same-monitor regions and plan isolation.
assert(S:SetSetting(ma,'a','AUTO'))
ma.workspaceScaleDisplays.a.percent=nil
local value,source=S:GetMultiplier(ma);assert(value==1 and source=='UNAVAILABLE')
ma.workspaceScaleDisplays.a.percent=25
value,source=S:GetMultiplier(ma);assert(value==S.MIN and source=='BOUNDED')
ma.workspaceScaleDisplays.a.percent=200;near(S:GetMultiplier(ma),1)
local savedLayout=ma.workspaceScaleLayout;ma.workspaceScaleLayout='another-plan'
near(S:GetMultiplier(ma),1);ma.workspaceScaleLayout=savedLayout

-- Native restoration preserves the visible top-left on disable.
assert(S:SetSetting(ma,'a',.5));local release=frame('ReleasePanel')
S:Apply(release,true,ma);local x,y=release.x*release.scale,release.y*release.scale
a.db.enabled=false;S:RestoreAll();near(release.scale,1)
near(release.x*release.scale,x);near(release.y*release.scale,y)

-- Forever can expose player combat before lockdown. A lockdown-only queue
-- would run synchronously, so defer via an addon-owned regeneration listener.
local playerCombat=true
a.MainhandGeometry={IsPlayerCombatRestricted=function()return playerCombat end}
local regenerated,immediate=0,0
CreateFrame=function()
    return {RegisterEvent=function(_,event)assert(event=='PLAYER_REGEN_ENABLED')end,
        SetScript=function(_,_,fn)regenerated=fn end}
end
a.RunOrQueueCombat=function(_,fn)immediate=immediate+1;fn()end
a.db.enabled=true;a.db.savedWorkspacePositions={DeferredPanel={x=1400,y=900,regionId='a'}}
local deferred=frame('DeferredPanel')
assert(S:SetSetting(ma,'a',.7))
assert(deferred.scale==1 and immediate==0 and type(regenerated)=='function','Player combat bypassed deferral or recursed through the queue')
playerCombat=false;regenerated();near(deferred.scale,.7)
print('PASS: opt-in per-region sizing, drag/restore fitting, guarded reopen, ownership, combat, chat, presets and restoration')
