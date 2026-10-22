-- Lua 5.1. Mock engine coordinates: 768 units high before effective scale.
local addon = { companionFullVersion="2.1.2-beta.18", companionMinVersion="2.1.2-beta.18",
    db = {enabled=true, deckWidthRatio=0.36, hudScale=0.7,
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
    function f:GetWidth() return self.width end
    function f:GetHeight() return self.height end
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
    function f:ClearAllPoints() self.points={};self.allPoints=nil;self.clears=(self.clears or 0)+1 end
    function f:SetClampedToScreen() end
    function f:SetSize(w,h) self.width,self.height=w,h end
    function f:IsShown() return true end
    function f:SetAllPoints(owner) self.allPoints=owner or self.parent;self.points={} end
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
OffhandDB={}
assert(loadfile("Core/ManualCanvas.lua"))("Offhand",addon)
assert(loadfile("Core/Viewport.lua"))("Offhand",addon)
assert(loadfile("Core/SeamRedirect.lua"))("Offhand",addon)
local initialPreview=addon.Viewport:GetManualPreviewMetrics()
assert(addon.ManualCanvas:RememberFromMetrics(initialPreview,"Geometry test","MANUAL"))
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
-- Model the explicit Companion selection, which hands geometry ownership back
-- from a previously remembered manual canvas to the generated exact bridge.
OffhandDB.preferredGeometrySource="AUTO"
OffhandCompanionTopology={schema=1,companionVersion="2.1.2-beta.18",physicalWidth=5360,physicalHeight=1440,mode="DUAL_DISPLAY",
    workspace={x=0,y=360,width=1920,height=1080},game={x=1920,y=0,width=3440,height=1440}}
local tm=addon.Viewport:GetMetrics()
assert(tm.companionTopology and tm.gamePixelWidth==3440 and tm.gamePixelHeight==1440
    and tm.companionVersionStatus=="MATCH")
OffhandCompanionTopology.companionVersion="2.1.2-beta.12"
tm=addon.Viewport:GetMetrics()
assert(tm.companionVersionStatus=="MISMATCH" and tm.companionVersion=="2.1.2-beta.12"
    and tm.expectedCompanionVersion=="2.1.2-beta.18")
OffhandCompanionTopology.companionVersion="2.1.2-beta.19"
tm=addon.Viewport:GetMetrics()
assert(tm.companionVersionStatus=="MATCH",
    "a newer Companion beta must satisfy the addon's declared minimum version")
OffhandCompanionTopology.companionVersion="2.1.2"
tm=addon.Viewport:GetMetrics()
assert(tm.companionVersionStatus=="MATCH",
    "a stable Companion release must satisfy an older beta minimum")
OffhandCompanionTopology.companionVersion="future-build"
tm=addon.Viewport:GetMetrics()
assert(tm.companionVersionStatus=="UNKNOWN",
    "an unparseable future Companion version must not produce a false update warning")
OffhandCompanionTopology.companionVersion="2.1.2-beta.18"
tm=addon.Viewport:GetMetrics()
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
local performance=addon.Viewport:GetPerformanceDiagnostics(addon.Viewport:GetMetrics())
local originalNamePlateAPI, originalFramerate = C_NamePlate, GetFramerate
C_NamePlate = {GetNamePlates = function() error("support text diagnostics enumerated nameplates") end}
GetFramerate = function() error("support text diagnostics sampled renderer performance") end
local textDiagnostics = addon.Viewport:GetWorldTextDiagnostics(addon.Viewport:GetMetrics())
for _, field in ipairs({"worldTextScale", "originalWorldTextScale", "worldTextScaleCVar",
    "worldTextMethod", "worldTextCompensationEnabled", "worldTextFineTune",
    "worldTextHeightRatio", "worldTextCompensationRatio"}) do
    assert(textDiagnostics[field] == performance[field], "world-text support evidence drifted: " .. field)
end
C_NamePlate, GetFramerate = originalNamePlateAPI, originalFramerate
near(performance.fps,73.5)
near(performance.spanPixels,4480*1440)
near(performance.mainhandPixels,2560*1440)
near(performance.boundsToMainhandRatio,1.75)
assert(performance.gxWindowedResolution=="2544x1342" and performance.renderScale=="1"
    and performance.gxApi=="D3D12" and performance.gxVSync=="1"
    and performance.maxFPS=="120" and performance.lowLatencyMode=="2"
    and performance.msaaAlphaTest=="1" and performance.antiAliasingMode=="2"
    and performance.cmaa2Quality=="3" and performance.textureFilteringMode=="5"
    and performance.dynamicRenderScale=="0" and performance.resampleSharpness=="0.2",
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
assert(tm.isSpanned and tm.companionTopology and tm.topologyStatus=="READY",
    "Forever must accept a matching canvas with a stale Mainhand-sized physical report")

-- Beta 21 report: Forever 1.60.1 build 70450 reports 2560x1440 while
-- the spanned canvas is 2287x1141 and the Companion bounds are 3640x1816.
OffhandCompanionTopology={schema=1,physicalWidth=3640,physicalHeight=1816,mode="DUAL_DISPLAY",
    workspace={x=0,y=0,width=1080,height=1816},game={x=1080,y=0,width=2560,height=1440}}
UIParent.GetWidth=function() return 2287 end
UIParent.GetHeight=function() return 1141 end
tm=addon.Viewport:GetMetrics()
assert(tm.isSpanned and tm.companionTopology and tm.topologyStatus=="READY"
        and tm.physicalWidth==3640 and tm.physicalHeight==1816
        and tm.gamePixelWidth==2560 and tm.gamePixelHeight==1440
        and tm.workspacePixelWidth==1080,
    "reported Forever canvas must accept the Companion span without guessing monitor geometry")
topologyDiagnostics=addon.Viewport:GetTopologyDiagnostics()
assert(topologyDiagnostics.accepted and topologyDiagnostics.status=="READY"
        and topologyDiagnostics.liveWidth==2560 and topologyDiagnostics.liveHeight==1440
        and topologyDiagnostics.canvasWidth==2287 and topologyDiagnostics.canvasHeight==1141,
    "accepted topology diagnostics must preserve the raw stale physical report")

-- Matching aspect alone cannot authorize unrelated physical dimensions.
pw,ph=1920,1080
tm=addon.Viewport:GetMetrics()
assert(not tm.isSpanned and tm.topologyStatus=="MISMATCH",
    "Forever must reject physical reports that match neither selected display")
pw,ph=2560,1440
UIParent.GetWidth=function() return (2560/1440)*1141 end
tm=addon.Viewport:GetMetrics()
assert(not tm.isSpanned and tm.topologyStatus=="MISMATCH",
    "Forever must reject stale topology after restoring a single-monitor canvas")
topologyDiagnostics=addon.Viewport:GetTopologyDiagnostics()
assert(topologyDiagnostics.status=="MISMATCH" and topologyDiagnostics.loaded
    and not topologyDiagnostics.accepted and topologyDiagnostics.expectedWidth==3640
    and topologyDiagnostics.expectedHeight==1816 and topologyDiagnostics.liveWidth==2560
    and topologyDiagnostics.liveHeight==1440,
    "mismatch diagnostics must preserve both expected topology and live dimensions")
addon.isForever=false
UIParent.GetWidth, UIParent.GetHeight = originalGetWidth, originalGetHeight
OffhandCompanionTopology=nil
addon.isForever=true
addon.db.aspectRatioMode="16_9"
OffhandDB.manualCanvases={}
local foreverPreview=addon.Viewport:GetManualPreviewMetrics()
assert(addon.ManualCanvas:RememberFromMetrics(foreverPreview,"Forever manual","MANUAL"))
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

-- An absent generated topology is not proof of a manual span. The ordinary
-- one-monitor Forever window observed during live testing must fail safely
-- until the player explicitly remembers a matching independent canvas.
OffhandDB.manualCanvases={}
pw,ph=2114,1353
tm=addon.Viewport:GetMetrics()
assert(not tm.isSpanned and tm.topologyStatus=="ABSENT"
        and tm.manualCanvasState=="MISMATCH"
        and tm.gamePixelWidth==2114 and tm.workspacePixelWidth==0,
    "an unremembered one-monitor window must use safe single-screen geometry")

-- Match the reported equal-landscape manual span. Without a generated
-- CompanionTopology.lua, a 50/50 preset must still confine WorldFrame to the
-- left monitor instead of treating the full window as the game rectangle.
pw,ph=3835,1059
addon.db.layoutPreset="LANDSCAPE_DUAL"
addon.db.primaryPosition="LEFT"
addon.db.deckWidthRatio=0.50
addon.db.aspectRatioMode="16_9"
addon.db.gameBottomPixels=0
OffhandDB.manualCanvases={}
local landscapePreview=addon.Viewport:GetManualPreviewMetrics()
assert(addon.ManualCanvas:RememberFromMetrics(landscapePreview,"Landscape manual","MANUAL"))
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
OffhandDB.manualCanvases={}
local scalePreview=addon.Viewport:GetManualPreviewMetrics()
assert(addon.ManualCanvas:RememberFromMetrics(scalePreview,"Scale test","MANUAL"))
local writes=0
local worldWrites=0
function UIParent:GetScale() return uiScale end
function UIParent:SetScale(value)
    writes=writes+1;uiScale=value
    -- Simulate reentrant display callbacks during a root scale change.
    addon.Viewport:ApplyGlobalScale()
end
local nativeWorldScale = WorldFrame:GetScale()
local setWorldScale = WorldFrame.SetScale
function WorldFrame:SetScale(value)
    worldWrites=worldWrites+1
    setWorldScale(self,value)
end
local original=uiScale
-- The client CVar can be clamped independently of the actual root scale.
local cvarWrites={}
local worldTextScale=1
local worldTextAvailable=true
local worldTextV2Scale=1
local worldTextV2Available=false
local nameplateSize=5
local friendlyPlayerNames=0
local friendlyPlayerNameWrites={}
local nameplateWidth,nameplateHeight=240,60
local nameplateDimensionWrites=0
local nameplateVisualWrites=0
local nameplateFrame=frame(WorldFrame)
nameplateFrame.scale=0.325
nameplateFrame.width,nameplateFrame.height=240,60
nameplateFrame.unitToken="nameplate1"
local nameplateUnitFrame=frame(nameplateFrame)
nameplateUnitFrame:SetAllPoints(nameplateFrame)
nameplateFrame.UnitFrame=nameplateUnitFrame
local setNameplateVisualScale=nameplateUnitFrame.SetScale
function nameplateUnitFrame:SetScale(value)
    nameplateVisualWrites=nameplateVisualWrites+1
    setNameplateVisualScale(self,value)
end
local friendlyNameplateFrame=frame(WorldFrame)
friendlyNameplateFrame.scale=0.275
friendlyNameplateFrame.width,friendlyNameplateFrame.height=150,45
friendlyNameplateFrame.unitToken="nameplate2"
local friendlyNameplateUnitFrame=frame(friendlyNameplateFrame)
friendlyNameplateUnitFrame:SetAllPoints(friendlyNameplateFrame)
friendlyNameplateUnitFrame.scale=0.8
friendlyNameplateFrame.UnitFrame=friendlyNameplateUnitFrame
C_NamePlate={
    GetNamePlateSize=function() return nameplateWidth,nameplateHeight end,
    GetNamePlates=function() return {nameplateFrame,friendlyNameplateFrame} end,
    SetNamePlateSize=function(width,height)
        nameplateDimensionWrites=nameplateDimensionWrites+1
        nameplateWidth,nameplateHeight=width,height
    end,
}
NamePlateDriverFrame={
    UpdateNamePlateSize=function(_,width,height)
        nameplateWidth,nameplateHeight=width,height
    end,
}
addon.db.originalNameplateSize=3
GetCVar=function(name)
    if name=="uiScale" then return "0.64" end
    if name=="WorldTextScale_v2" then
        return worldTextV2Available and tostring(worldTextV2Scale) or nil
    end
    if name=="WorldTextScale" then
        return worldTextAvailable and tostring(worldTextScale) or nil
    end
    if name=="nameplateSize" then return tostring(nameplateSize) end
    if name=="UnitNameFriendlyPlayerName" then return tostring(friendlyPlayerNames) end
    -- Retail 12.1 can render friendly player plates while this legacy CVar is
    -- unavailable. UnitNameFriendlyPlayerName remains the authoritative name
    -- visibility switch and must not be gated on this missing value.
    if name=="nameplateShowFriends" then return nil end
    if name=="NamePlateHorizontalScale" then return nil end
    if name=="NamePlateVerticalScale" then return nil end
    if name=="nameplateGlobalScale" then return nil end
    return "1"
end
SetCVar=function(name,value)
    cvarWrites[name]=(cvarWrites[name] or 0)+1
    if name=="WorldTextScale_v2" then worldTextV2Scale=tonumber(value) end
    if name=="WorldTextScale" then worldTextScale=tonumber(value) end
    if name=="nameplateSize" then nameplateSize=tonumber(value) end
    if name=="UnitNameFriendlyPlayerName" then
        friendlyPlayerNameWrites[#friendlyPlayerNameWrites+1]=tostring(value)
        -- Retail boolean CVars require their canonical integer token.
        if value=="0" or value=="1" then friendlyPlayerNames=tonumber(value) end
    end
end
addon.isRetail=true
addon.isForever=false
local unknownAddon=frame(UIParent);unknownAddon.scale=1.2
local getSpannedMetrics=addon.Viewport.GetMetrics
addon.Viewport.GetMetrics=function() return {isSpanned=false} end
addon.Viewport:ApplyGlobalScale()
near(friendlyPlayerNames,1)
near(addon.db.originalFriendlyPlayerName,0)
assert(friendlyPlayerNameWrites[1]=="1",
    "friendly player names were not kept visible while Offhand was enabled but unspanned")
addon.Viewport.GetMetrics=getSpannedMetrics
addon.Viewport:ApplyGlobalScale()
near(friendlyPlayerNames,1)
assert(friendlyPlayerNameWrites[1]=="1",
    "friendly player-name visibility was not written when the legacy plate CVar was unavailable")
near(addon.db.originalFriendlyPlayerName,0)
local expectedHUDScale=1440/2560*0.7
near(uiScale,expectedHUDScale)
near(WorldFrame:GetEffectiveScale(),nativeWorldScale)
near(worldTextScale,expectedHUDScale)
near(nameplateSize,3)
near(nameplateWidth,240)
near(nameplateHeight,60)
near(nameplateFrame:GetScale(),0.325)
near(friendlyNameplateFrame:GetScale(),0.275)
near(addon.Viewport.namePlateCompensationRatio,expectedHUDScale)
near(nameplateUnitFrame:GetEffectiveScale(),expectedHUDScale)
near(friendlyNameplateUnitFrame:GetEffectiveScale(),0.8*expectedHUDScale)
assert(nameplateUnitFrame.allPoints==nil and friendlyNameplateUnitFrame.allPoints==nil,
    "active nameplate UnitFrames retained scale-cancelling SetAllPoints anchors")
near(nameplateUnitFrame:GetWidth(),240)
near(nameplateUnitFrame:GetHeight(),60)
near(friendlyNameplateUnitFrame:GetWidth(),240)
near(friendlyNameplateUnitFrame:GetHeight(),60)
near(unknownAddon:GetEffectiveScale(),uiScale*1.2)
addon.SeamRedirect:AlignHUDFrames()
near(MainMenuBar:GetEffectiveScale(),uiScale)
for i=1,100 do addon.Viewport:ApplyGlobalScale() end
assert(writes==1,"unchanged global scale was rewritten")
assert(worldWrites==0,"native WorldFrame scale was unexpectedly rewritten")
assert(not cvarWrites.uiScale,"layout wrote a clamped uiScale CVar and risks a display feedback loop")
assert(cvarWrites.WorldTextScale==1,"unchanged world text correction was rewritten")
assert(cvarWrites.nameplateSize==1,
    "the prior beta's discrete nameplate setting was not restored exactly once")
assert(nameplateDimensionWrites==0,
    "Offhand changed Blizzard's native nameplate dimensions")
assert(nameplateVisualWrites==1,
    "unchanged visual nameplate compensation was rewritten")
NamePlateDriverFrame:UpdateNamePlateSize(300,75)
near(nameplateWidth,300)
near(nameplateHeight,75)
assert(nameplateDimensionWrites==0,
    "a Blizzard nameplate settings refresh was unexpectedly intercepted")
nameplateUnitFrame:SetScale(1.2)
addon.Viewport:ApplyNamePlateVisualScale(addon.Viewport:GetMetrics())
near(nameplateWidth,300)
near(nameplateHeight,75)
near(nameplateUnitFrame:GetEffectiveScale(),1.2*expectedHUDScale)
assert(nameplateDimensionWrites==0,
    "a Blizzard settings refresh caused Offhand to rewrite native dimensions")
assert(nameplateVisualWrites==3,
    "a Blizzard visual-scale refresh did not establish and compensate a new baseline")
combat=true;addon.db.hudScale=0.65;addon.Viewport:ApplyGlobalScale();assert(writes==1)
combat=false;addon.Viewport:ApplyGlobalScale();assert(writes==2)
near(WorldFrame:GetEffectiveScale(),nativeWorldScale)
near(nameplateUnitFrame:GetEffectiveScale(),1.2*(1440/2560*0.65))
near(worldTextScale,1440/2560*0.65)
assert(nameplateDimensionWrites==0,
    "HUD scale changes rewrote native nameplate dimensions")
assert(addon.Viewport:RestoreNamePlateUnit("nameplate1"),
    "removed nameplate was not restored before pool reuse")
near(nameplateUnitFrame:GetScale(),1.2)
assert(nameplateUnitFrame.allPoints==nameplateFrame,
    "removed nameplate did not recover Blizzard's SetAllPoints contract")
addon.Viewport:ApplyNamePlateVisualScale(addon.Viewport:GetMetrics())
addon.db.enabled=false;addon.Viewport:ApplyGlobalScale();
near(uiScale,original)
near(WorldFrame:GetScale(),nativeWorldScale)
near(worldTextScale,1)
near(nameplateSize,3)
near(friendlyPlayerNames,0)
assert(friendlyPlayerNameWrites[#friendlyPlayerNameWrites]=="0",
    "friendly player-name preference was not restored as a Retail boolean CVar")
assert(addon.db.originalFriendlyPlayerName==nil,
    "friendly player-name preference was not restored when Offhand was disabled")
near(nameplateWidth,300)
near(nameplateHeight,75)
near(nameplateFrame:GetScale(),0.325)
near(friendlyNameplateFrame:GetScale(),0.275)
near(nameplateUnitFrame:GetScale(),1.2)
near(friendlyNameplateUnitFrame:GetScale(),0.8)
assert(nameplateUnitFrame.allPoints==nameplateFrame
    and friendlyNameplateUnitFrame.allPoints==friendlyNameplateFrame,
    "disabled layout did not restore Blizzard's pooled nameplate anchors")
assert(cvarWrites.WorldTextScale==3,"original WorldTextScale was not restored exactly once")
assert(cvarWrites.nameplateSize==1,
    "the migrated discrete nameplate setting was unexpectedly rewritten")
assert(nameplateDimensionWrites==0,
    "native nameplate dimensions were unexpectedly changed")
assert(nameplateVisualWrites==7,
    "nameplate visual baseline was not restored exactly once")
assert(worldWrites==1,
    "native WorldFrame scale was unexpectedly changed before restore")

-- World text follows the calculated Mainhand visual baseline only where the
-- physical canvas is taller than Mainhand. Equal-height spans need no automatic
-- correction, but the user fine-tune remains a multiplier in every topology.
local universalMetrics = {
    {name="equal-height side-by-side report", physicalWidth=4480, physicalHeight=1440,
        gamePixelWidth=2560, gamePixelHeight=1440},
    {name="mixed-height side-by-side", physicalWidth=4000, physicalHeight=2560,
        gamePixelWidth=2560, gamePixelHeight=1440},
    {name="vertically stacked", physicalWidth=2560, physicalHeight=2520,
        gamePixelWidth=2560, gamePixelHeight=1440},
    {name="dual 4K-width canvas", physicalWidth=7680, physicalHeight=2160,
        gamePixelWidth=3840, gamePixelHeight=2160},
    {name="single ultrawide split", physicalWidth=5120, physicalHeight=1440,
        gamePixelWidth=2560, gamePixelHeight=1440},
    {name="short Mainhand beside tall workspace", physicalWidth=3360, physicalHeight=2560,
        gamePixelWidth=1920, gamePixelHeight=1080},
}
local nativeGetMetrics = addon.Viewport.GetMetrics
addon.isForever = true
addon.db.hudScale = 0.7
addon.db.worldTextCompensation = true
addon.db.worldTextScale = 1
for _, sample in ipairs(universalMetrics) do
    local calculated = math.max(0.05, math.min(
        sample.gamePixelHeight / sample.physicalHeight,
        sample.gamePixelWidth * 768 / (1100 * sample.physicalHeight))
        * addon.db.hudScale)
    local expectedWorld = math.abs(sample.gamePixelHeight / sample.physicalHeight - 1) <= 0.01
        and addon.db.worldTextScale or calculated * addon.db.worldTextScale
    sample.isSpanned = true
    addon.db.enabled = true
    addon.db.originalWorldTextScale = nil
    addon.Viewport.originalScale = nil
    worldTextScale = 1.25
    addon.Viewport.GetMetrics = function() return sample end
    addon.Viewport:ApplyGlobalScale()
    near(uiScale, calculated)
    near(worldTextScale, 1.25 * expectedWorld)
    local sampleDiagnostics = addon.Viewport:GetPerformanceDiagnostics(sample)
    near(sampleDiagnostics.worldTextCompensationRatio, expectedWorld)
    addon.db.enabled = false
    addon.Viewport:ApplyGlobalScale()
    near(worldTextScale, 1.25)
end
addon.Viewport.GetMetrics = nativeGetMetrics

-- Regression: the reporter's equal-height 5120x1440 span previously returned
-- early with ratio 1, so moving the visible slider to 50% changed no CVar.
local equalHeightMetrics = universalMetrics[5]
addon.db.enabled = true
addon.db.originalWorldTextScale = nil
addon.Viewport.originalScale = nil
worldTextScale = 1
addon.db.worldTextScale = 0.5
addon.Viewport.GetMetrics = function() return equalHeightMetrics end
addon.Viewport:ApplyGlobalScale()
near(worldTextScale, 0.5)
near(addon.Viewport:GetPerformanceDiagnostics(equalHeightMetrics).worldTextCompensationRatio, 0.5)
addon.db.enabled = false
addon.Viewport:ApplyGlobalScale()
near(worldTextScale, 1)
addon.db.worldTextScale = 1
addon.Viewport.GetMetrics = nativeGetMetrics

-- User controls are independent from the global HUD scale: the toggle restores
-- native text while spanned, and fine tuning multiplies only the correction.
local adjustableMetrics = universalMetrics[2]
addon.db.enabled = true
addon.db.originalWorldTextScale = nil
addon.Viewport.originalScale = nil
worldTextScale = 1
addon.Viewport.GetMetrics = function() return adjustableMetrics end
addon.db.worldTextScale = 1.2
addon.Viewport:ApplyGlobalScale()
local adjustableBase = math.max(0.05, math.min(
    adjustableMetrics.gamePixelHeight / adjustableMetrics.physicalHeight,
    adjustableMetrics.gamePixelWidth * 768 / (1100 * adjustableMetrics.physicalHeight))
    * addon.db.hudScale)
near(worldTextScale, adjustableBase * 1.2)
addon.db.worldTextCompensation = false
addon.Viewport:ApplyGlobalScale()
near(worldTextScale, 1)
addon.db.enabled = false
addon.Viewport:ApplyGlobalScale()
addon.db.worldTextCompensation = true
addon.db.worldTextScale = 1
addon.Viewport.GetMetrics = nativeGetMetrics

-- Some clients expose neither supported world-text CVar. Live Forever Beta 22
-- testing also proved that engine-rendered combat/XP text ignores WorldFrame
-- scale, so keep the world root native on any missing-CVar client.
local foreverFallbackMetrics = {
    physicalWidth=4480, physicalHeight=1440,
    gamePixelWidth=2560, gamePixelHeight=1440, isSpanned=true,
}
local foreverExpected = 0.7
local foreverWorldExpected = 1
worldTextAvailable = false
addon.isForever = true
addon.db.enabled = true
addon.db.hudScale = 0.7
addon.db.originalWorldTextScale = nil
addon.Viewport.originalScale = nil
addon.Viewport.GetMetrics = function() return foreverFallbackMetrics end
addon.Viewport:ApplyGlobalScale()
near(uiScale, foreverExpected)
near(WorldFrame:GetScale(), nativeWorldScale)
local fallbackDiagnostics = addon.Viewport:GetPerformanceDiagnostics(foreverFallbackMetrics)
assert(fallbackDiagnostics.worldTextMethod == "UNMANAGED",
    "Forever missing-CVar world text was not reported as unmanaged")
near(fallbackDiagnostics.worldTextCompensationRatio, foreverWorldExpected)
near(fallbackDiagnostics.worldFrameLocalScale, nativeWorldScale)
addon.db.enabled = false
addon.Viewport:ApplyGlobalScale()
near(WorldFrame:GetScale(), nativeWorldScale)

-- Forever exposes the native control as WorldTextScale_v2. Prefer it over the
-- legacy spelling, record the selected key, and restore the same key exactly.
worldTextV2Available = true
worldTextV2Scale = 1
addon.db.enabled = true
addon.Viewport.originalScale = nil
addon.Viewport.GetMetrics = function() return foreverFallbackMetrics end
addon.Viewport:ApplyGlobalScale()
near(worldTextV2Scale, foreverWorldExpected)
assert(addon.db.originalWorldTextScaleCVar == "WorldTextScale_v2",
    "versioned world-text CVar was not selected")
local selectedWorldTextCVar, selectedWorldTextValue =
    addon.Viewport:GetWorldTextScaleControl()
assert(selectedWorldTextCVar == "WorldTextScale_v2",
    "public world-text capability did not report the versioned control")
near(selectedWorldTextValue, foreverWorldExpected)
local versionedDiagnostics = addon.Viewport:GetPerformanceDiagnostics(foreverFallbackMetrics)
assert(versionedDiagnostics.worldTextMethod == "CVAR"
    and versionedDiagnostics.worldTextScaleCVar == "WorldTextScale_v2",
    "versioned world-text CVar diagnostics were not reported")
addon.db.enabled = false
addon.Viewport:ApplyGlobalScale()
near(worldTextV2Scale, 1)
assert(addon.db.originalWorldTextScaleCVar == nil,
    "versioned world-text CVar ownership was not released")
worldTextV2Available = false

-- A hybrid client can retain GetCVar while exposing WorldTextScale only through
-- C_CVar. The namespaced value must win over the legacy nil and avoid fallback.
local namespacedWorldTextScale = 1
C_CVar = {
    GetCVar = function(name)
        return name == "WorldTextScale" and tostring(namespacedWorldTextScale) or nil
    end,
    SetCVar = function(name, value)
        if name == "WorldTextScale" then namespacedWorldTextScale = tonumber(value) end
    end,
}
addon.db.enabled = true
addon.Viewport.originalScale = nil
addon.Viewport.GetMetrics = function() return foreverFallbackMetrics end
addon.Viewport:ApplyGlobalScale()
near(WorldFrame:GetScale(), nativeWorldScale)
near(namespacedWorldTextScale, foreverWorldExpected)
assert(addon.Viewport:GetPerformanceDiagnostics(foreverFallbackMetrics).worldTextMethod
    == "CVAR", "namespaced-only WorldTextScale did not prevent root fallback")
addon.db.enabled = false
addon.Viewport:ApplyGlobalScale()
near(namespacedWorldTextScale, 1)
C_CVar = nil

addon.isForever = false
addon.db.enabled = true
addon.Viewport.originalScale = nil
addon.Viewport.GetMetrics = function() return foreverFallbackMetrics end
addon.Viewport:ApplyGlobalScale()
near(WorldFrame:GetScale(), nativeWorldScale)
assert(addon.Viewport:GetPerformanceDiagnostics(foreverFallbackMetrics).worldTextMethod
    == "UNMANAGED", "non-Forever missing-CVar client unexpectedly scaled WorldFrame")
addon.db.enabled = false
addon.Viewport:ApplyGlobalScale()
worldTextAvailable = true
addon.Viewport.GetMetrics = nativeGetMetrics
print("PASS: inherited global baseline, addon relative scales, no repeated writes, recursion/combat guards, restore")

