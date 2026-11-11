local combat,queue,external,controller=false,{},false,false
local addon={isRetail=true,db={enabled=true,seamRedirect=true},HUDCompatibility={
    UsesForeverEditMode=function() return false end,
    HasCustomActionBarAddon=function() return external end,
    UsesControllerInterface=function() return controller end}}
InCombatLockdown=function() return combat end
addon.RunOrQueueCombat=function(_,fn) queue[#queue+1]=fn end
UIParent={GetEffectiveScale=function() return 0.394 end}
local m={isSpanned=true,gameLeft=1097.14,gameRight=3047.62,gameBottom=4.57,gameTop=1101.71}
addon.Viewport={GetMetrics=function() return m end}
local creates=0
CreateFrame=function(_,_,parent,template)
    assert(not combat and template=='SecureHandlerBaseTemplate')
    creates=creates+1
    local f={attrs={},refs={}}
    function f:GetParent() return parent end
    function f:SetFrameRef(name,value) self.refs[name]=value end
    function f:GetFrameRef(name) return self.refs[name] end
    function f:SetAttribute(name,value) self.attrs[name]=value end
    function f:GetAttribute(name) return self.attrs[name] end
    function f:Execute(code)
        assert(not combat)
        assert(loadstring('return function(self) '..code..' end'))()(self)
    end
    return f
end
local root={points={{'BOTTOM',UIParent,'BOTTOM',0,0}},shown=false,writes=0,scale=0.394,parent=UIParent}
function root:GetParent() return self.parent end
function root:GetNumPoints() return #self.points end
function root:GetPoint(i) return unpack(self.points[i]) end
function root:GetEffectiveScale() return self.scale end
function root:IsForbidden() return self.forbidden end
function root:IsUserPlaced() return self.userPlaced end
function root:ClearAllPoints() assert(not combat);self.points={};self.writes=self.writes+1 end
function root:SetPoint(...) assert(not combat);self.points[#self.points+1]={...} end
function root:HookScript() error('must not hook vehicle ancestry') end
function root:Show() error('must not force native vehicle visibility') end
function root:Hide() error('must not hide native vehicle controls') end
function root:SetScale() error('must not resize native vehicle art') end
local nativeClick=function() end
root.LeaveButton={OnClick=nativeClick}
OverrideActionBar=root
assert(loadfile('Core/HUDTransientPolicy.lua'))('Offhand',addon)
assert(loadfile('Core/HUDTransientFrames.lua'))('Offhand',addon)
local hud={}
addon.HUDTransientFrames.Install(hud,{Points=function() error('vehicle must use secure anchor writer') end,
    Anchor=function() end,Prepare=function() end})
local function at(x,y,relative)
    local p=root.points[1]
    assert(p[1]=='BOTTOM' and p[2]==UIParent and p[3]==(relative or 'BOTTOMLEFT'))
    assert(math.abs(p[4]-x)<0.001 and math.abs(p[5]-y)<0.001)
end
hud:PositionRetailOverrideBar()
at(2072.38,4.57)
assert(not root.shown and root.LeaveButton.OnClick==nativeClick and hud.retailOverrideStatus=='mainhand')
local writes=root.writes;hud:PositionRetailOverrideBar();assert(root.writes==writes and creates==1)
root.shown=true;hud:PositionRetailOverrideBar();assert(root.writes==writes,'native entry needs no insecure show-time writes')
-- A scale/topology change uses current local units, not cached screen offsets.
root.scale=0.788;m.gameLeft=0;m.gameRight=1950;m.gameBottom=100
hud:PositionRetailOverrideBar();at(487.5,50)
addon.db.enabled=false;hud:PositionRetailOverrideBar();at(0,0,'BOTTOM')
addon.db.enabled=true;hud:PositionRetailOverrideBar();at(487.5,50)
m.isSpanned=false;hud:PositionRetailOverrideBar();at(0,0,'BOTTOM')
m.isSpanned=true;hud:PositionRetailOverrideBar()
addon.db.seamRedirect=false;hud:PositionRetailOverrideBar();at(0,0,'BOTTOM')
addon.db.seamRedirect=true;external=true;hud:PositionRetailOverrideBar();at(0,0,'BOTTOM')
external=false;controller=true;hud:PositionRetailOverrideBar();at(0,0,'BOTTOM')
controller=false
-- Combat requests coalesce, and disabling before completion restores current state.
hud:PositionRetailOverrideBar();combat=true
local before=root.writes
hud:PositionRetailOverrideBar();hud:PositionRetailOverrideBar()
assert(#queue==1 and root.writes==before)
addon.db.enabled=false;combat=false;queue[1]();at(0,0,'BOTTOM')
addon.db.enabled=true
root.points={{'BOTTOM',UIParent,'BOTTOM',10,20}}
hud:PositionRetailOverrideBar();at(10,20,'BOTTOM')
root.points={{'BOTTOM',UIParent,'BOTTOM',0,0}};root.userPlaced=true
hud:PositionRetailOverrideBar();at(0,0,'BOTTOM')
root.userPlaced=false;root.isManagedFrame=true
hud:PositionRetailOverrideBar();at(0,0,'BOTTOM')
root.isManagedFrame=false;hud:PositionRetailOverrideBar()
local other={};root.points={{'TOP',other,'TOP',5,6}}
hud:PositionRetailOverrideBar();assert(root.points[1][2]==other)
root.points={{'BOTTOM',UIParent,'BOTTOM',0,0}};root.parent=other
hud:PositionRetailOverrideBar();at(0,0,'BOTTOM')
root.parent=UIParent;root.forbidden=true;hud:PositionRetailOverrideBar();at(0,0,'BOTTOM')
root.forbidden=false;addon.isRetail=false;hud:PositionRetailOverrideBar();at(0,0,'BOTTOM')
print('PASS: Retail override stock-root secure positioning, hidden preparation, scale, restore, combat and owner exclusions')
