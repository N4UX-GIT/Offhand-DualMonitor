local addon={isRetail=true,db={enabled=true,seamRedirect=true},HUDCompatibility={UsesForeverEditMode=function() return false end}}
local combat=false
local queued={}
function addon:RunOrQueueCombat(fn) if combat then queued[#queued+1]=fn else fn() end end
local function LeaveCombat()
    combat=false;local pending=queued;queued={}
    for _,fn in ipairs(pending) do fn() end
end
InCombatLockdown=function() return combat end
UIParent={GetEffectiveScale=function() return 0.5 end}
local m={isSpanned=true,gameLeft=1440,gameRight=4000,gameBottom=6,gameTop=1446}
addon.Viewport={GetMetrics=function() return m end}
local hookCount=0
hooksecurefunc=function(frame,method,fn)
    assert(type(frame)=='table','only known native frame methods are hooked here')
    local native=frame[method];hookCount=hookCount+1
    frame[method]=function(...) local result=native(...);fn(...);return result end
end
local function Frame(point,relative,x,y)
    local f={shown=false,points={{point,UIParent,relative,x,y}},scale=1,writes=0}
    function f:GetNumPoints() return #self.points end
    function f:GetPoint(i) return unpack(self.points[i]) end
    function f:GetEffectiveScale() return self.scale end
    function f:GetParent() return self.parent or UIParent end
    function f:IsShown() return self.shown end
    function f:IsProtected() return self.protected end
    function f:IsForbidden() return self.forbidden end
    function f:IsUserPlaced() return self.userPlaced end
    function f:ClearAllPoints() assert(not combat);self.points={};self.writes=self.writes+1 end
    function f:SetPoint(...) assert(not combat);self.points[#self.points+1]={...} end
    function f:HookScript() error('must preserve native ancestry scripts') end
    function f:Show() error('must not force native notifications') end
    function f:Hide() error('must not hide native notifications') end
    return f
end
local key=Frame('CENTER','CENTER',0,40)
local banner=Frame('TOP','TOP',0,-120)
local toast=Frame('TOP','TOP',0,-190)
local side=Frame('TOPRIGHT','TOP',-189,-170)
ChallengesKeystoneFrame,ChallengeModeCompleteBanner,EventToastManagerFrame,EventToastManagerSideDisplay=key,banner,toast,side
key.ShowKeystoneFrame=function(self) self.shown=true;return 'native-key' end
banner.PlayBanner=function(self) self.shown=true;return 'native-banner' end
side.DisplayToastsByLevel=function(self) self.shown=not self.shown;return 'native-side' end
toast.UpdateAnchor=function(self,x,y)
    -- Native writes are allowed in the simulation, addon writers still assert
    -- out of combat in ClearAllPoints/SetPoint.
    self.points={}
    if x then self.points[#self.points+1]={'LEFT',UIParent,'LEFT',x,0} end
    self.points[#self.points+1]={'TOP',UIParent,'TOP',0,y or -190}
    return 'native-toast'
end
toast.DisplayToast=function(self,hidden)
    self:UpdateAnchor()
    -- Captured test.4 sequence: the early post-hook places the root, then
    -- the remainder of display resets it to TOP/UIParent/TOP/0/0.
    self.points={{'TOP',UIParent,'TOP',0,0}};self.shown=not hidden
    return 'native-display'
end
local nativeAction=function() end;key.StartButton={OnClick=nativeAction}
assert(loadfile('Core/HUDTransientPolicy.lua'))('Offhand',addon)
assert(loadfile('Core/HUDTransientFrames.lua'))('Offhand',addon)
local function Points(frame,...)
    local desired={...};local same=#desired==#frame.points
    if same then for i,p in ipairs(desired) do for j=1,5 do if p[j]~=frame.points[i][j] then same=false end end end end
    if same then return end
    frame:ClearAllPoints();for _,point in ipairs(desired) do frame:SetPoint(unpack(point)) end
end
local hud={}
addon.HUDTransientFrames.Install(hud,{Points=Points,Anchor=function() error('must translate native offsets') end,Prepare=function() end})
hud:HookRetailNotifications();hud:HookRetailNotifications();assert(hookCount==5)
local function at(frame,i,point,x,y)
    local p=frame.points[i]
    assert(p[1]==point and p[2]==UIParent and p[3]=='BOTTOMLEFT')
    assert(math.abs(p[4]-x)<0.001 and math.abs(p[5]-y)<0.001)
end
assert(key:ShowKeystoneFrame()=='native-key');at(key,1,'CENTER',1360,403)
assert(key.StartButton.OnClick==nativeAction)
assert(banner:PlayBanner()=='native-banner');at(banner,1,'TOP',1360,603)
assert(side:DisplayToastsByLevel()=='native-side');at(side,1,'TOPRIGHT',1171,553)
side:DisplayToastsByLevel();assert(side.points[1][3]=='TOP','closing side display restores native anchor')
assert(toast:UpdateAnchor()=='native-toast');at(toast,1,'TOP',1360,533)
assert(toast:DisplayToast()=='native-display');at(toast,1,'TOP',1360,723)
combat=true;local combatWrites=toast.writes
toast:DisplayToast();toast:DisplayToast()
assert(toast.writes==combatWrites and #queued==1,'coalesce replay without addon writes in combat')
LeaveCombat();at(toast,1,'TOP',1360,723)
combat=true;toast:DisplayToast();toast.shown=false;LeaveCombat()
assert(toast.points[1][3]=='TOP','expired toast must not be adopted')
combat=true;toast:DisplayToast();toast.points={{'TOP',UIParent,'TOP',99,-77}};LeaveCombat()
assert(toast.points[1][4]==99,'deferred replay must yield to a custom anchor')
combat=true;toast:DisplayToast();addon.db.enabled=false;LeaveCombat()
assert(toast.points[1][3]=='TOP','disabled during combat must not be recentered')
addon.db.enabled=true;toast:DisplayToast();toast:DisplayToast(true)
assert(toast.points[1][3]=='TOP','closing DisplayToast must release placement')
-- Native setup before Show and every later refresh must preserve both anchors/custom offsets.
toast.shown=true;toast:UpdateAnchor(55,-210)
at(toast,1,'LEFT',775,363);at(toast,2,'TOP',1360,513)
local writes=toast.writes;hud:PositionRetailNotifications();assert(toast.writes==writes)
toast:UpdateAnchor(60,-205);at(toast,1,'LEFT',780,363);at(toast,2,'TOP',1360,518)
addon.db.enabled=false;hud:PositionRetailNotifications()
assert(#toast.points==2 and toast.points[1][3]=='LEFT' and toast.points[1][4]==60 and toast.points[2][5]==-205)
assert(key.points[1][3]=='CENTER' and key.points[1][5]==40)
addon.db.enabled=true;key:ShowKeystoneFrame()
m.gameLeft=0;m.gameRight=1000;m.gameTop=2000;key.scale=0.5
hud:PositionRetailNotifications();at(key,1,'CENTER',500,1043)
m.isSpanned=false;hud:PositionRetailNotifications();assert(key.points[1][3]=='CENTER')
m.isSpanned=true;key:ShowKeystoneFrame()
combat=true;local before=key.writes;hud:PositionRetailNotifications();assert(key.writes==before)
combat=false;addon.db.seamRedirect=false;hud:PositionRetailNotifications();assert(key.points[1][3]=='CENTER')
addon.db.seamRedirect=true
key.points={{'CENTER',UIParent,'CENTER',99,88}};key:ShowKeystoneFrame();assert(key.points[1][4]==99)
key.points={{'CENTER',UIParent,'CENTER',0,40}};key.userPlaced=true;key:ShowKeystoneFrame();assert(key.points[1][3]=='CENTER')
key.userPlaced=false;key.protected=true;key:ShowKeystoneFrame();assert(key.points[1][3]=='CENTER')
key.protected=false;key.forbidden=true;key:ShowKeystoneFrame();assert(key.points[1][3]=='CENTER')
key.forbidden=false;key.parent={};key:ShowKeystoneFrame();assert(key.points[1][3]=='CENTER')
key.parent=nil;key.isManagedFrame=true;key:ShowKeystoneFrame();assert(key.points[1][3]=='CENTER')
key.isManagedFrame=false;addon.isRetail=false;key:ShowKeystoneFrame();assert(key.points[1][3]=='CENTER')
print('PASS: Retail keystone/banner/side-toast placement, final native toast offsets, restore, scale and owner exclusions')
