local addon={modules={},db={enabled=true,dockMap=true,dockBags=true,primaryPosition="RIGHT"}}
local combat=false
local queue={}
function addon:RunOrQueueCombat(fn) queue[#queue+1]=fn end
function addon:Print(message,err) error(err or message) end
InCombatLockdown=function() return combat end
UIParent={GetEffectiveScale=function() return 1 end}
local m={gameLeft=1440,gameRight=4000,gameBottom=6,gameTop=1446,
    gameWidth=2560,gameHeight=1440,deckWidth=1440,screenHeight=2560,bezel=0,hudScale=1}
addon.Viewport={GetMetrics=function() return m end}
function addon.Viewport:SetPoint(f,p,r,x,y) f:SetPoint(p,UIParent,r,x/f.scale,y/f.scale) end
local children={}
children[1]={GetName=function() error("calling 'GetName' on bad self") end}
children[2]={IsForbidden=function() return true end,
    GetName=function() error("forbidden frame must not be queried") end}
children[3]={GetName=function() return "RestrictedWindow" end,
    IsMovable=function() error("inaccessible method") end}
function UIParent:GetChildren() return unpack(children) end
local function frame(name,w,h,x,y)
    local f={name=name,w=w,h=h,x=x,y=y,scale=1,shown=true,user=false}
    children[#children+1]=f
    function f:IsMovable() return true end
    function f:GetName() return self.name end
    function f:IsShown() return self.shown end
    function f:GetWidth() return self.w end
    function f:GetHeight() return self.h end
    function f:GetRect() return self.x/self.scale,self.y/self.scale,self.w,self.h end
    function f:GetEffectiveScale() return self.scale end
    function f:GetScale() return self.scale end
    function f:SetScale(v) self.scale=v end
    function f:SetSize(w,h) self.w,self.h=w,h end
    function f:IsObjectType(t) return t=="GameTooltip" and self.name=="GameTooltip" end
    function f:GetParent() return UIParent end
    function f:SetClampedToScreen() end
    function f:IsUserPlaced() return self.user end
    function f:ClearAllPoints() end
    function f:SetScrollChild(c) self.scrollChild = c end
    function f:SetVerticalScroll(v) self.verticalScroll = v end
    function f:SetPoint(p,r,rp,x,y)
        self.x=x*self.scale; self.y=y*self.scale-self.h*self.scale
        if p=="BOTTOMRIGHT" then self.x=self.x-self.w*self.scale; self.y=y*self.scale end
    end
    function f:HookScript() end
    return f
end
CreateFrame=function() return {RegisterEvent=function() end,SetScript=function() end} end
hooksecurefunc=function(f,key,fn)
    if type(f)~="table" then return end
    local original=f[key]
    f[key]=function(self,...)
        if original then original(self,...) end
        fn(self,...)
    end
end
UIPanelWindows={SpellBookFrame={area="left"},FriendsFrame={area="left"}}
SpellBookFrame=frame("SpellBookFrame",384,512,1500,1800)
FriendsFrame=frame("FriendsFrame",384,512,1800,1900)
GameMenuFrame=frame("GameMenuFrame",200,450,3800,0)
WorldMapFrame=frame("WorldMapFrame",1000,700,2000,1800)
assert(loadfile("Modules/CharacterDock.lua"))("Offhand",addon)
local tickerRegistered=false
local timers={}
C_Timer={NewTicker=function() tickerRegistered=true; return {} end,
    After=function(_,fn) timers[#timers+1]=fn end}
local function flush()
    local batch=timers;timers={}
    for _,fn in ipairs(batch) do fn() end
end
addon.Panels:Initialize()
assert(tickerRegistered,"bad child aborted initialization")
addon.Panels:Place(children[1])
addon.Panels:SavePosition(children[2])
assert(UIPanelWindows.SpellBookFrame.area=="left" and UIPanelWindows.FriendsFrame.area=="left")
local function inside(f,l,b,r,t)
    assert(f.x>=l-0.01 and f.y>=b-0.01 and f.x+f.w*f.scale<=r+0.01 and f.y+f.h*f.scale<=t+0.01,f.name.." is outside visible rectangle")
end
addon.Panels:ApplyLayout()
for _,f in ipairs({SpellBookFrame,FriendsFrame,GameMenuFrame}) do inside(f,1440,6,4000,1446); assert(f.scale==m.hudScale) end
inside(WorldMapFrame,0,0,1440,2560)
SpellBookFrame.user=true; SpellBookFrame.x=20;SpellBookFrame.y=100
addon.Panels:Place(SpellBookFrame); inside(SpellBookFrame,0,0,1440,2560)
SpellBookFrame.x=2000;SpellBookFrame.y=1900
addon.Panels:Place(SpellBookFrame); inside(SpellBookFrame,1440,6,4000,1446)
combat=true;SpellBookFrame.y=1900
addon.Panels:Place(SpellBookFrame);addon.Panels:Place(FriendsFrame)
assert(#queue==1 and SpellBookFrame.y==1900)
combat=false;queue[1]();inside(SpellBookFrame,1440,6,4000,1446)
SpellBookFrame._OffhandDragging=true;SpellBookFrame.y=1900
addon.Panels:Place(SpellBookFrame);assert(SpellBookFrame.y==1900)
SpellBookFrame._OffhandDragging=false
addon.db.primaryPosition="LEFT";m.gameLeft=0;m.gameRight=2560
addon.Panels:Place(WorldMapFrame);inside(WorldMapFrame,2560,0,4000,2560)
print("PASS: panel opening metadata, scale, invisible-gap rescue, deck dragging, combat, left primary")

-- A saved drag location overrides Blizzard's fresh anchor on every reopening.
addon.db.primaryPosition="RIGHT";m.gameLeft=1440;m.gameRight=4000
SpellBookFrame.x=1900;SpellBookFrame.y=400;SpellBookFrame.user=true
addon.Panels:SavePosition(SpellBookFrame)
local saved=addon.db.panelPositions.SpellBookFrame
assert(saved.monitor=="GAME")
SpellBookFrame.x=0;SpellBookFrame.y=1800;SpellBookFrame.user=false
addon.Panels:Place(SpellBookFrame)
assert(math.abs(SpellBookFrame.x-1900)<0.01 and math.abs(SpellBookFrame.y-400)<0.01)
-- Simulated reload: the saved table is retained but frame position is reset.
SpellBookFrame.x=30;SpellBookFrame.y=1900
assert(loadfile("Modules/CharacterDock.lua"))("Offhand",addon)
addon.Panels:Place(SpellBookFrame)
assert(math.abs(SpellBookFrame.x-1900)<0.01 and math.abs(SpellBookFrame.y-400)<0.01)
RiF_MainWindow=frame("RiF_MainWindow",750,550,2000,1800)
RiF_StatusWidget=frame("RiF_StatusWidget",40,40,3200,1600)
GameTooltip=frame("GameTooltip",200,50,3700,1200)
addon.Panels:ApplyLayout()
for _,f in ipairs({RiF_MainWindow,RiF_StatusWidget,GameTooltip}) do
    inside(f,1440,6,4000,1446)
    assert(f.scale==m.hudScale)
end
print("PASS: persisted panel positions override reopening anchors; RIF and tooltip scaling")

-- Blizzard lays out two anchors in one call stack. Do not intervene halfway.
local bag=frame("ContainerFrame1",200,300,-100,1900)
addon.Panels:Discover()
bag:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",-100,2400)
assert(bag.x==-100,"placement ran inside native SetPoint")
bag:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",-50,2300)
assert(bag.x==-50)
flush()
inside(bag,0,0,1440,2560)
assert(bag.w==200 and bag.h==300)
bag:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",-50,2300)
flush();inside(bag,0,0,1440,2560)

GameTooltip.x=3000;GameTooltip.y=400
addon.Panels:Place(GameTooltip)
assert(GameTooltip.x==3000 and GameTooltip.y==400,"native tooltip anchor was replaced")
GameTooltip.x=3900;GameTooltip.y=500
addon.Panels:Place(GameTooltip)
inside(GameTooltip,1440,6,4000,1446)
assert(GameTooltip.y==500,"tooltip snapped to top instead of minimal clamp")
assert(GameTooltip.w==200 and GameTooltip.h==50)
print("PASS: deferred bag anchors/reopening, native tooltip position and dimensions")
