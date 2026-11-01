-- Lua 5.1 simulation for OH-TBC-001. Real bottom control, layout dispatcher,
-- ManualCanvas and Viewport; native frames/renderer and other modules are mocked.
-- This cannot measure GPU allocations or reproduce a native client crash.
StaticPopupDialogs, SlashCmdList, OffhandDB = {}, {}, {}
GetBuildInfo = function() return '2.5.6', '70577', 'fixture', 20506 end
local combat=false
InCombatLockdown = function() return combat end
local physicalWidth, physicalHeight, uiScale = 4000, 2560, 0.8
GetPhysicalScreenSize = function() return physicalWidth, physicalHeight end
local frames = {}
function CreateFrame(kind,name)
    local f = {kind=kind, name=name, scripts={}, points={}, scale=1, width=100, height=50}
    function f:RegisterEvent() end
    function f:SetScript(event, callback) self.scripts[event]=callback end
    function f:SetSize(w,h) self.width,self.height=w,h end
    function f:SetWidth(w) self.width=w end
    function f:SetHeight(h) self.height=h end
    function f:GetHeight() return self.height end
    function f:SetWordWrap() end
    function f:SetPoint(point, relative, relativePoint, x,y)
        self.points[point]={relative,relativePoint,x,y}
    end
    function f:ClearAllPoints() self.points={}; self.clears=(self.clears or 0)+1 end
    function f:SetAllPoints(owner) self.owner=owner end
    function f:SetAutoFocus() end
    function f:SetNumeric() end
    function f:SetMaxLetters() end
    function f:SetText(value) self.text=value end
    function f:GetText() return self.text end
    function f:ClearFocus() end
    function f:GetScale() return self.scale end
    function f:GetEffectiveScale() return self.scale end
    function f:SetScale(value) self.scale=value end
    function f:CreateFontString() return CreateFrame('FontString') end
    frames[#frames+1]=f
    return f
end
UIParent = {
    GetWidth=function() return physicalWidth/physicalHeight*768/uiScale end,
    GetHeight=function() return 768/uiScale end,
    GetScale=function() return uiScale end,
    GetEffectiveScale=function() return uiScale end,
    SetScale=function(_,value) uiScale=value end,
}
WorldFrame=CreateFrame('WorldFrame')
GetCVar=function() return nil end
-- No timers should be required by this isolated direct control/layout path.
C_Timer={After=function() error('unexpected deferred work in calibration fixture') end}
local addon={}
assert(loadfile('Core/Init.lua'))('Offhand',addon)
addon.Print=function(_,message,detail) error(tostring(message)..': '..tostring(detail)) end
addon.db={enabled=true, deckWidthRatio=0.36, hudScale=0.7,
    gameBottomPixels=6, primaryPosition='RIGHT'}
assert(loadfile('Core/ManualCanvas.lua'))('Offhand',addon)
assert(loadfile('Core/Viewport.lua'))('Offhand',addon)
assert(loadfile('UI/Controls.lua'))('Offhand',addon)
local row=addon.UIControls.CreateBottomControl({})
local buttons={}
for _,frame in ipairs(frames) do
    if frame.kind=='Button' then buttons[frame.text]=frame end
end
local function settle()
    for _,f in ipairs(frames) do
        if f.scripts.OnUpdate then f.scripts.OnUpdate(f,0.3) end
    end
end
local function click(label) buttons[label].scripts.OnClick(); settle() end
assert(addon.ManualCanvas:RememberFromMetrics(
    addon.Viewport:GetManualPreviewMetrics(),'OOM fixture','MANUAL'))
local function metrics()
    local m=addon.Viewport:GetMetrics()
    assert(m.isSpanned and m.gamePixelWidth>0 and m.gamePixelHeight>0)
    assert(m.gamePixelBottom>=0 and m.gamePixelBottom+m.gamePixelHeight<=physicalHeight)
    return m
end
local function checkAppliedBottom(expected)
    local m=metrics()
    assert(m.gamePixelBottom==expected,'manual offset did not reach real metrics')
    local point=assert(WorldFrame.points.BOTTOMLEFT,'viewport did not apply')
    local pixelY=point[4]*WorldFrame:GetScale()*physicalHeight/768
    assert(math.abs(pixelY-expected)<0.001,'WorldFrame bottom differs from metrics')
end
local function exercise(count)
    for _=1,count do
        click('+1 px'); checkAppliedBottom(7)
        click('-1 px'); checkAppliedBottom(6)
    end
end
exercise(100)
collectgarbage('collect')
local retainedBefore=collectgarbage('count')
local framesBefore=#frames
local clearsBefore=WorldFrame.clears or 0
exercise(5000)
collectgarbage('collect')
local retainedDelta=collectgarbage('count')-retainedBefore
assert(#frames==framesBefore,'calibration allocated additional persistent frames')
local storedCount=0
for _ in pairs(OffhandDB.manualCanvases) do storedCount=storedCount+1 end
assert(storedCount==1,'calibration accumulated remembered canvas records')
assert(retainedDelta<64,'isolated fixture retained over 64 KiB after warmup/GC')
local manualWrites=(WorldFrame.clears or 0)-clearsBefore

-- Boundary input must remain finite and inside the canvas, even at 1px height.
row.editBox:SetText('99999'); click('BTN_APPLY_SHORT')
checkAppliedBottom(physicalHeight-1)
row.editBox:SetText('6'); click('BTN_APPLY_SHORT'); checkAppliedBottom(6)

-- Companion topology selects a different geometry source and ignores manual
-- bottom calibration. Verify source precedence without claiming native safety.
OffhandCompanionTopology={schema=1, physicalWidth=physicalWidth,
    physicalHeight=physicalHeight, mode='fixture',
    game={x=1440,y=0,width=2560,height=1440},
    workspace={x=0,y=0,width=1440,height=2560}}
assert(not metrics().companionTopology,
    'a bridge must not silently override the remembered manual preference')
assert(addon.ManualCanvas:SetGeometryPreference('AUTO'))
click('+1 px')
local exact=metrics()
assert(addon.db.gameBottomPixels==7 and exact.companionTopology
    and exact.gamePixelBottom==0 and exact.gamePixelHeight==1440,
    'Companion geometry did not override the manual bottom setting')
click('-1 px')
assert(metrics().gamePixelBottom==0)
OffhandCompanionTopology=nil
addon:ApplyFullLayout()
checkAppliedBottom(6)

-- Reporter working canvas: 1920x1080 right game at y=3, 1280x1024 workspace,
-- within 3200x1083. Manual 16:9 calibration reaches the height-clamp boundary.
physicalWidth,physicalHeight=3200,1083
addon.db.deckWidthRatio=0.4
addon.db.gameBottomPixels=3
row:Refresh()
assert(addon.ManualCanvas:RememberFromMetrics(
    addon.Viewport:GetManualPreviewMetrics(),'Reporter geometry','MANUAL'))
addon:ApplyFullLayout()
checkAppliedBottom(3)
local initial=metrics()
assert(initial.gamePixelLeft==1280 and initial.gamePixelWidth==1920
    and initial.gamePixelHeight==1080)
local initialScale=uiScale
for _=1,1000 do
    click('+1 px'); checkAppliedBottom(4)
    assert(metrics().gamePixelHeight==1079 and uiScale<initialScale,
        'manual bottom adjustment must exercise height clamp and scale change')
    click('-1 px'); checkAppliedBottom(3)
    assert(metrics().gamePixelHeight==1080 and math.abs(uiScale-initialScale)<0.00001,
        'reversing manual adjustment must restore the geometry and UI scale')
end
OffhandCompanionTopology={schema=1, physicalWidth=3200, physicalHeight=1083,
    mode='fixture', game={x=1280,y=3,width=1920,height=1080},
    workspace={x=0,y=0,width=1280,height=1024}}
assert(addon.ManualCanvas:SetGeometryPreference('AUTO'))
click('+1 px')
assert(metrics().companionTopology and metrics().gamePixelHeight==1080
    and metrics().gamePixelBottom==3 and math.abs(uiScale-initialScale)<0.00001,
    'Companion geometry must avoid the manual height/scale boundary')

-- Burst changes reach the dispatcher once, preserve the latest state across
-- combat, and apply the current topology rather than a queued snapshot.
OffhandCompanionTopology=nil
assert(addon.ManualCanvas:SetGeometryPreference('MANUAL'))
addon.db.gameBottomPixels=3; row:Refresh()
addon:ApplyFullLayout()
local beforeBurst=WorldFrame.clears
for _=1,1000 do
    buttons['+1 px'].scripts.OnClick()
    buttons['-1 px'].scripts.OnClick()
end
assert(WorldFrame.clears==beforeBurst,'burst applied synchronously')
combat=true
settle()
assert(WorldFrame.clears==beforeBurst,'settled calibration mutated viewport in combat')
buttons['+1 px'].scripts.OnClick(); settle()
assert(WorldFrame.clears==beforeBurst,'later combat calibration mutated viewport')
combat=false
for _,f in ipairs(frames) do
    if f.name=='OffhandEventFrame' then f.scripts.OnEvent(f,'PLAYER_REGEN_ENABLED') end
end
assert(WorldFrame.clears==beforeBurst+1,'combat deferred burst did not apply once')
checkAppliedBottom(4)
beforeBurst=WorldFrame.clears
buttons['+1 px'].scripts.OnClick()
OffhandCompanionTopology={schema=1, physicalWidth=3200, physicalHeight=1083,
    mode='fixture',game={x=1280,y=3,width=1920,height=1080},
    workspace={x=0,y=0,width=1280,height=1024}}
assert(addon.ManualCanvas:SetGeometryPreference('AUTO'))
settle()
assert(WorldFrame.clears==beforeBurst+1 and metrics().companionTopology
    and metrics().gamePixelBottom==3 and metrics().gamePixelHeight==1080,
    'pending adjustment must apply current Companion topology after ownership changes')
print(string.format('PASS: 10000 real layout/viewport updates; %d WorldFrame clears; '
    ..'retained Lua delta %.3f KiB; stable frames/storage; Companion source precedence; '
    ..'2000 reporter-geometry updates exercise manual height/scale boundary; '
    ..'burst/combat final state preserved',
    manualWrites,retainedDelta))
