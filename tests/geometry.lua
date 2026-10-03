-- Lua 5.1. Mock engine coordinates: 768 units high before effective scale.
local addon = { companionFullVersion="2.1.2-beta.18", db = {enabled=true, deckWidthRatio=0.36, hudScale=0.7,
    gameBottomPixels=6, primaryPosition="RIGHT"}, Debug=function() end, Print=error }
local pw, ph, uiScale = 4000, 2560, 0.8
local function near(a,b) assert(math.abs(a-b)<0.01, tostring(a).." ~= "..tostring(b)) end
UIParent = {GetWidth=function() return pw/ph*768/uiScale end,
    GetHeight=function() return 768/uiScale end,
    GetEffectiveScale=function() return uiScale end}
GetPhysicalScreenSize=function() return pw,ph end
InCombatLockdown=function() return false end
local cvars = { useUiScale = "1" }
GetFramerate = function() return 73.5 end
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
OffhandCompanionTopology={schema=1,companionVersion="2.1.2-beta.18",physicalWidth=5360,physicalHeight=1440,mode="DUAL_DISPLAY",
    workspace={x=0,y=360,width=1920,height=1080},game={x=1920,y=0,width=3440,height=1440}}
local tm=addon.Viewport:GetMetrics()
assert(tm.companionTopology and tm.gamePixelWidth==3440 and tm.gamePixelHeight==1440
    and tm.companionVersionStatus=="MATCH")
OffhandCompanionTopology.companionVersion="2.1.2-beta.12"
tm=addon.Viewport:GetMetrics()
assert(tm.companionVersionStatus=="MISMATCH" and tm.companionVersion=="2.1.2-beta.12"
    and tm.expectedCompanionVersion=="2.1.2-beta.18")
OffhandCompanionTopology.companionVersion="2.1.2-beta.18"
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

-- Classic/TBC can report only Mainhand's native resolution after the Companion
-- has resized the window. The complete UI canvas aspect still proves that the
-- exact topology is active. Accept it, but reject the same file after the
-- window returns to Mainhand's single-monitor aspect.
pw,ph=2560,1440
OffhandCompanionTopology={schema=1,physicalWidth=4000,physicalHeight=2560,mode="DUAL_DISPLAY",
    workspace={x=0,y=0,width=1440,height=2560},game={x=1440,y=6,width=2560,height=1440}}
local originalGetWidth, originalGetHeight = UIParent.GetWidth, UIParent.GetHeight
UIParent.GetWidth=function() return (4000/2560)*768/uiScale end
UIParent.GetHeight=function() return 768/uiScale end
tm=addon.Viewport:GetMetrics()
assert(tm.companionTopology and tm.topologyStatus=="READY"
        and tm.physicalWidth==4000 and tm.physicalHeight==2560
        and tm.gamePixelWidth==2560 and tm.workspacePixelWidth==1440,
    "Classic Mainhand-sized physical report must accept matching spanned canvas topology")
UIParent.GetWidth=function() return (2560/1440)*768/uiScale end
tm=addon.Viewport:GetMetrics()
assert(not tm.isSpanned and tm.topologyStatus=="MISMATCH",
    "restored single-monitor canvas must reject stale Companion topology")

-- Renderer diagnostics stay read-only and distinguish the complete spanned
-- window bounds from the Mainhand viewport. A saved gxWindowedResolution is
-- evidence to report, not a replacement for the live physical dimensions.
pw,ph=4480,1440
UIParent.GetWidth=function() return (4480/1440)*768/uiScale end
UIParent.GetHeight=function() return 768/uiScale end
OffhandCompanionTopology={schema=1,companionVersion="2.1.2-beta.18",physicalWidth=4480,physicalHeight=1440,mode="DUAL_DISPLAY",
    workspace={x=2560,y=0,width=1920,height=1080},game={x=0,y=0,width=2560,height=1440}}
cvars.gxWindowedResolution="2544x1342"
cvars.RenderScale="1"
cvars.ResampleQuality="3"
cvars.gxApi="D3D12"
cvars.vsync="1"
cvars.maxFPS="120"
cvars.maxFPSBk="30"
cvars.LowLatencyMode="2"
cvars.MSAAQuality="0"
cvars.MSAAAlphaTest="1"
cvars.ffxAntiAliasingMode="2"
cvars.CMAA2Quality="3"
cvars.textureFilteringMode="5"
cvars.DynamicRenderScale="0"
cvars.ResampleAlwaysSharpen="0"
cvars.ResampleSharpness="0.2"
cvars.RenderScaleDowngradeForegroundMinSize="1080"
cvars.RenderScaleDowngradeBackgroundMinSize="720"
local performance=addon.Viewport:GetPerformanceDiagnostics(addon.Viewport:GetMetrics())
near(performance.fps,73.5)
near(performance.spanPixels,4480*1440)
near(performance.mainhandPixels,2560*1440)
near(performance.boundsToMainhandRatio,1.75)
assert(performance.gxWindowedResolution=="2544x1342" and performance.renderScale=="1"
    and performance.gxApi=="D3D12" and performance.gxVSync=="1"
    and performance.maxFPS=="120" and performance.lowLatencyMode=="2"
    and performance.msaaAlphaTest=="1" and performance.antiAliasingMode=="2"
    and performance.cmaa2Quality=="3" and performance.textureFilteringMode=="5"
    and performance.dynamicRenderScale=="0" and performance.resampleSharpness=="0.2"
    and performance.foregroundDowngradeMin=="1080"
    and performance.backgroundDowngradeMin=="720",
    "performance diagnostics must retain renderer CVars without changing them")
local topologyDiagnostics=addon.Viewport:GetTopologyDiagnostics()
assert(topologyDiagnostics.status=="READY" and topologyDiagnostics.loaded
    and topologyDiagnostics.schema==1 and topologyDiagnostics.accepted
    and topologyDiagnostics.expectedWidth==4480 and topologyDiagnostics.expectedHeight==1440
    and topologyDiagnostics.liveWidth==4480 and topologyDiagnostics.liveHeight==1440,
    "topology diagnostics must expose raw handoff and live renderer dimensions")
pw,ph=2560,1440
OffhandCompanionTopology={schema=1,physicalWidth=4000,physicalHeight=2560,mode="DUAL_DISPLAY",
    workspace={x=0,y=0,width=1440,height=2560},game={x=1440,y=6,width=2560,height=1440}}
addon.isForever=true
UIParent.GetWidth=function() return (4000/2560)*768/uiScale end
tm=addon.Viewport:GetMetrics()
assert(not tm.isSpanned and tm.topologyStatus=="MISMATCH",
    "Forever must retain strict exact-size topology validation")
topologyDiagnostics=addon.Viewport:GetTopologyDiagnostics()
assert(topologyDiagnostics.status=="MISMATCH" and topologyDiagnostics.loaded
    and not topologyDiagnostics.accepted and topologyDiagnostics.expectedWidth==4000
    and topologyDiagnostics.expectedHeight==2560 and topologyDiagnostics.liveWidth==2560
    and topologyDiagnostics.liveHeight==1440,
    "mismatch diagnostics must preserve both expected topology and live dimensions")
addon.isForever=false
UIParent.GetWidth, UIParent.GetHeight = originalGetWidth, originalGetHeight
OffhandCompanionTopology=nil
addon.isForever=true
addon.db.aspectRatioMode="16_9"
tm=addon.Viewport:GetMetrics()
assert(tm.isSpanned and tm.topologyStatus=="ABSENT"
        and tm.gamePixelLeft==922 and tm.gamePixelBottom==6
        and tm.gamePixelWidth==1638 and tm.gamePixelHeight==921,
    "Forever must retain manual percentage geometry when Companion topology is absent")
assert(not addon.Viewport:IsSingleScreenRecovery(tm),
    "Forever manual spanning must not enter Companion recovery")
topologyDiagnostics=addon.Viewport:GetTopologyDiagnostics()
assert(topologyDiagnostics.status=="ABSENT" and not topologyDiagnostics.loaded
    and not topologyDiagnostics.accepted,
    "absent topology diagnostics must remain distinct from a mismatch")

-- Match the reported equal-landscape manual span. Without a generated
-- CompanionTopology.lua, a 50/50 preset must still confine WorldFrame to the
-- left monitor instead of treating the full window as the game rectangle.
pw,ph=3835,1059
addon.db.layoutPreset="LANDSCAPE_DUAL"
addon.db.primaryPosition="LEFT"
addon.db.deckWidthRatio=0.50
addon.db.aspectRatioMode="16_9"
addon.db.gameBottomPixels=0
tm=addon.Viewport:GetMetrics()
assert(tm.isSpanned and tm.topologyStatus=="ABSENT"
        and tm.gamePixelLeft==0 and tm.gamePixelWidth==1917
        and tm.gamePixelHeight==1059 and tm.workspacePixelWidth==1918,
    "Forever manual dual-landscape geometry must split the spanned client")
addon.Viewport:Apply()
x,y,w,h=worldPixels()
near(x,0); near(y,0); near(w,1917); near(h,1059)

addon.isForever=false
tm=addon.Viewport:GetMetrics()
assert(tm.isSpanned and tm.topologyStatus=="ABSENT",
    "non-Forever clients must retain legacy manual-span geometry")
pw,ph=4000,2560
print("PASS: exact mixed-resolution topology, stale guard, and manual absent-topology spanning")

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

