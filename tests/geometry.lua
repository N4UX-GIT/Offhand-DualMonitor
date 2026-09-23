-- Lua 5.1. Mock engine coordinates: 768 units high before effective scale.
local addon = { db = {enabled=true, deckWidthRatio=0.36, hudScale=0.7,
    gameBottomPixels=6, primaryPosition="RIGHT"}, Debug=function() end, Print=error }
local pw, ph, uiScale = 4000, 2560, 0.8
local function near(a,b) assert(math.abs(a-b)<0.01, tostring(a).." ~= "..tostring(b)) end
UIParent = {GetWidth=function() return pw/ph*768/uiScale end,
    GetHeight=function() return 768/uiScale end,
    GetEffectiveScale=function() return uiScale end}
GetPhysicalScreenSize=function() return pw,ph end
InCombatLockdown=function() return false end
local cvars = { useUiScale = "1" }
GetCVar = function(name) 
    if name == "uiScale" then return tostring(uiScale) end
    return cvars[name] 
end
SetCVar = function(name, value) 
    if name == "uiScale" then uiScale = tonumber(value) or uiScale end
    cvars[name] = tostring(value) 
end
local function frame(parent, w, h)
    local f={parent=parent, scale=1, width=w or 100, height=h or 50, points={}}
    function f:GetFrameLevel() return self.level or 1 end
    function f:SetFrameLevel(v) self.level=v end
    function f:GetParent() return self.parent end
    function f:GetScale() return self.scale end
    function f:SetScale(v) self.scale=v end
    function f:GetEffectiveScale() return self.scale*(self.parent and self.parent:GetEffectiveScale() or 1) end
    function f:SetScrollChild(c) self.scrollChild = c end
    function f:SetVerticalScroll(v) self.verticalScroll = v end
    function f:SetPoint(point, relative, relativePoint, x, y)
        self.points[point]={relative,relativePoint,x,y}
    end
    function f:GetNumPoints() local n=0; for _ in pairs(self.points) do n=n+1 end; return n end
    function f:GetPoint(i)
        local n=0
        for point, v in pairs(self.points) do n=n+1; if n==i then return point,unpack(v) end end
    end
    function f:ClearAllPoints() self.points={}; self.clears=(self.clears or 0)+1 end
    function f:SetClampedToScreen() end
    function f:SetSize(w,h) self.width,self.height=w,h end
    function f:IsShown() return true end
    function f:SetAllPoints() end
    return f
end
WorldFrame=frame(nil)
MainMenuBar=frame(UIParent,1024,53)
MainActionBar=frame(UIParent,454,35)
ActionButton1=frame(MainActionBar,36,36)
PlayerFrame=frame(UIParent)
TargetFrame=frame(UIParent)
MinimapCluster=frame(UIParent)
ChatFrame1=frame(UIParent)
MicroMenuContainer=frame(UIParent)
MicroMenu=frame(MicroMenuContainer)
BagsBar=frame(UIParent)
MainMenuBarBackpackButton=frame(BagsBar)
CharacterBag0Slot=frame(BagsBar)
CharacterBag1Slot=frame(BagsBar)
CharacterBag2Slot=frame(BagsBar)
CharacterBag3Slot=frame(BagsBar)
assert(loadfile("Core/Viewport.lua"))("Offhand",addon)
assert(loadfile("Core/SeamRedirect.lua"))("Offhand",addon)
local function worldPixels()
    local bl,tr=WorldFrame.points.BOTTOMLEFT,WorldFrame.points.TOPRIGHT
    local factor=WorldFrame:GetEffectiveScale()*ph/768
    return bl[3]*factor,bl[4]*factor,(tr[3]-bl[3])*factor,(tr[4]-bl[4])*factor
end
for _,scale in ipairs({0.56,0.8,1,1.2}) do
    uiScale=scale
    addon.Viewport:Apply()
    local x,y,w,h=worldPixels()
    near(x,1440); near(y,6); near(w,2560); near(h,1440)
    addon.SeamRedirect:AlignHUDFrames()
    local p=MainMenuBar.points.BOTTOM
    local factor=MainMenuBar:GetEffectiveScale()*ph/768
    near(p[3]*factor,2720); near(p[4]*factor,6)
    near(MainMenuBar:GetEffectiveScale(),ActionButton1:GetEffectiveScale())
    -- Native child scales inherit UIParent without per-frame overrides.
    near(MainMenuBar:GetEffectiveScale(),uiScale)
end
addon.db.primaryPosition="LEFT"
addon.Viewport:Apply()
local x,y,w,h=worldPixels()
near(x,0); near(w,2560)
addon.db.primaryPosition="RIGHT"
addon.db.deckWidthRatio=0.55
addon.Viewport:Apply()
x,y,w,h=worldPixels()
near(x,2200); near(w,1800); near(h,1013)
addon.db.deckWidthRatio=0.36
addon.db.aspectRatioMode="FILL"
addon.db.gameHeightRatio=1
addon.Viewport:Apply()
x,y,w,h=worldPixels()
near(y+h,ph)
addon.db.deckWidthRatio=0/0
addon.db.customAspectRatio=0
addon.db.aspectRatioMode="CUSTOM"
local m=addon.Viewport:GetMetrics()
assert(m.gameWidth>0 and m.gameHeight>0 and m.gameTop<=m.screenHeight)
print("PASS: physical seam, cross-scale anchors, HUD fit, nested scale, left primary, fill bounds, invalid input")

-- Companion topology is authoritative and preserves mixed monitor heights and
-- offsets without guessing from the combined aspect ratio.
pw,ph=5360,1440
OffhandCompanionTopology={schema=1,physicalWidth=5360,physicalHeight=1440,mode="DUAL_DISPLAY",
    workspace={x=0,y=360,width=1920,height=1080},game={x=1920,y=0,width=3440,height=1440}}
local tm=addon.Viewport:GetMetrics()
assert(tm.companionTopology and tm.gamePixelWidth==3440 and tm.gamePixelHeight==1440)
assert(tm.workspacePixelLeft==0 and tm.workspacePixelBottom==360 and tm.workspacePixelHeight==1080)
addon.Viewport:Apply()
x,y,w,h=worldPixels()
near(x,1920); near(y,0); near(w,3440); near(h,1440)
pw,ph=2560,2520
OffhandCompanionTopology={schema=1,physicalWidth=2560,physicalHeight=2520,mode="DUAL_DISPLAY",
    workspace={x=200,y=1440,width=1920,height=1080},game={x=0,y=0,width=2560,height=1440}}
tm=addon.Viewport:GetMetrics()
assert(tm.workspacePixelBottom==1440 and tm.workspacePixelHeight==1080 and tm.gamePixelWidth==2560)
addon.Viewport:Apply()
x,y,w,h=worldPixels()
near(x,0); near(y,0); near(w,2560); near(h,1440)
OffhandCompanionTopology.physicalWidth=9999
tm=addon.Viewport:GetMetrics()
assert(not tm.isSpanned and tm.topologyStatus=="MISMATCH" and tm.gamePixelWidth==2560)
OffhandCompanionTopology=nil
addon.isForever=true
tm=addon.Viewport:GetMetrics()
assert(not tm.isSpanned and tm.topologyStatus=="ABSENT"
        and tm.gamePixelLeft==0 and tm.gamePixelBottom==0
        and tm.gamePixelWidth==pw and tm.gamePixelHeight==ph,
    "Forever must fail safe to the full current window without exact Companion topology")
assert(addon.Viewport:IsSingleScreenRecovery(tm),
    "Forever absent topology must enter the single-screen recovery path")
addon.isForever=false
tm=addon.Viewport:GetMetrics()
assert(tm.isSpanned and tm.topologyStatus=="ABSENT",
    "non-Forever clients must retain legacy manual-span geometry")
pw,ph=4000,2560
print("PASS: exact mixed-resolution topology, stale guard, Forever absent-topology fail-safe")

-- Regression: Blizzard XP scale resets must be repaired before the call returns,
-- without scheduling another full viewport layout or recursively hooking itself.
local timers, combatQueue, combat = {}, {}, false
C_Timer = {After=function(_, fn) timers[#timers+1]=fn end}
InCombatLockdown=function() return combat end
function addon:RunOrQueueCombat(fn)
    if combat then combatQueue[#combatQueue+1]=fn else fn() end
end
function addon:ApplyFullLayout() error('HUD repair rebuilt the full layout') end
function hooksecurefunc(target, method, callback)
    if type(target)=='string' then
        callback=method
        local original=_G[target]
        _G[target]=function(...) original(...); callback(...) end
    else
        local original=target[method]
        target[method]=function(...) original(...); callback(...) end
    end
end
UIParent_ManageFramePositions=function() end
StatusTrackingBarManager=frame(UIParent)
MultiBarBottomLeft=frame(UIParent)
MultiBarBottomRight=frame(UIParent)
StanceBar=frame(UIParent)
ShapeshiftBarFrame=frame(UIParent)
PetActionBar=frame(UIParent)
addon.SeamRedirect:HookFrames()
-- Complete the independent delayed Edit Mode discovery before measuring HUD timers.
while #timers > 0 do table.remove(timers,1)() end
addon.SeamRedirect:AlignHUDFrames()
local expected=StatusTrackingBarManager:GetScale()
local clears=MainMenuBar.clears
for i=1,100 do
    StatusTrackingBarManager:SetScale(1)
    near(StatusTrackingBarManager:GetScale(),expected)
end
assert(#timers==0, 'XP scale correction scheduled a feedback loop')
for i=1,100 do UIParent_ManageFramePositions() end
assert(#timers==1, 'manager notifications were not coalesced')
local callback=table.remove(timers,1); callback()
assert(#timers==0, 'HUD repair scheduled itself')
assert(MainMenuBar.clears==clears, 'unchanged anchors were rewritten')
combat=true
for i=1,100 do StatusTrackingBarManager:SetScale(1) end
addon.SeamRedirect:RequestLayout()
assert(#timers==1)
table.remove(timers,1)()
assert(#combatQueue==1, 'combat recovery was not coalesced')
near(StatusTrackingBarManager:GetScale(),1)
combat=false
combatQueue[1]()
near(StatusTrackingBarManager:GetScale(),expected)
assert(#timers==0)
print('PASS: native scale retained, no HUD feedback, idempotent anchors, combat deferral')

-- Idle Blizzard updates to action bars 2/3 and modern/legacy form bars must
-- restore before SetPoint/SetScale returns, without a visible deferred pass.
combatQueue={}
local bars={MultiBarBottomLeft,MultiBarBottomRight}
-- Form and pet bars belong to native Edit Mode, not the HUD repair loop.
for _,bar in ipairs({StanceBar,ShapeshiftBarFrame,PetActionBar}) do
    assert(not addon.SeamRedirect:IsManagedFrame(bar))
end
for _,bar in ipairs(bars) do
    local wantedScale=bar:GetScale()
    local wanted=bar.points.BOTTOMLEFT
    for i=1,100 do
        bar:SetScale(1)
        near(bar:GetScale(),wantedScale)
        bar:ClearAllPoints()
        bar:SetPoint("CENTER",UIParent,"CENTER",100,200)
        assert(bar:GetNumPoints()==1 and bar.points.BOTTOMLEFT)
        local point=bar.points.BOTTOMLEFT
        assert(point[1]==wanted[1] and point[2]==wanted[2])
        near(point[3],wanted[3]); near(point[4],wanted[4])
    end
end
assert(#timers==0, 'action/form bar repair used a deferred pass')
combat=true
StanceBar:SetScale(1)
addon.SeamRedirect:RequestLayout()
assert(StanceBar:GetScale()==1 and #timers==1)
table.remove(timers,1)()
assert(#combatQueue==1)
combat=false
combatQueue[1]()
near(StanceBar:GetEffectiveScale(),MainMenuBar:GetEffectiveScale())
addon.db.enabled=false
MultiBarBottomLeft:SetScale(1)
assert(MultiBarBottomLeft:GetScale()==1 and #timers==0)
print('PASS: immediate action/form anchors, native scale retained, combat deferral, disabled state')

-- The viewport controls one global baseline; arbitrary addon children inherit it.
addon.db.enabled=true;addon.db.deckWidthRatio=0.36;addon.db.aspectRatioMode="16_9"
local writes=0
function UIParent:GetScale() return uiScale end
function UIParent:SetScale(value)
    writes=writes+1;uiScale=value
    -- Simulate reentrant display callbacks during a root scale change.
    addon.Viewport:ApplyGlobalScale()
end
local original=uiScale
-- The client CVar can be clamped independently of the actual root scale.
local cvarWrites=0
GetCVar=function(name) return name=="uiScale" and "0.64" or "1" end
SetCVar=function() cvarWrites=cvarWrites+1 end
local unknownAddon=frame(UIParent);unknownAddon.scale=1.2
addon.Viewport:ApplyGlobalScale()
near(uiScale,1440/2560*0.7)
near(unknownAddon:GetEffectiveScale(),uiScale*1.2)
addon.SeamRedirect:AlignHUDFrames()
near(MainMenuBar:GetEffectiveScale(),uiScale)
for i=1,100 do addon.Viewport:ApplyGlobalScale() end
assert(writes==1,"unchanged global scale was rewritten")
assert(cvarWrites==0,"layout wrote a clamped CVar and risks a display feedback loop")
combat=true;addon.db.hudScale=0.65;addon.Viewport:ApplyGlobalScale();assert(writes==1)
combat=false;addon.Viewport:ApplyGlobalScale();assert(writes==2)
addon.db.enabled=false;addon.Viewport:ApplyGlobalScale();
near(uiScale,original)
print("PASS: inherited global baseline, addon relative scales, no repeated writes, recursion/combat guards, restore")

