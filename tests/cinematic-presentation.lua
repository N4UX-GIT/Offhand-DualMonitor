local addon={isRetail=true,db={enabled=true}}
local combat,queue,timers=false,{},{}
InCombatLockdown=function() return combat end
addon.RunOrQueueCombat=function(_,fn) queue[#queue+1]=fn end
C_Timer={After=function(_,fn) timers[#timers+1]=fn end}
UIParent={GetEffectiveScale=function() return 0.5 end}
local m={isSpanned=true,gameLeft=1440,gameBottom=0,gameRight=4000,gameTop=1440}
addon.Viewport={GetMetrics=function() return m end}
local loader,secureHooks
secureHooks={}
CreateFrame=function()
    loader={events={}}
    function loader:RegisterEvent(event) self.events[event]=true end
    function loader:SetScript(_,fn) self.onEvent=fn end
    return loader
end
hooksecurefunc=function(object,method,fn)
    if type(object)=="string" then secureHooks[object]=method
    else secureHooks[object]=fn; assert(method=="AddSubtitle") end
end
CinematicFrame_UpdateLettboxForAspectRatio=function() end
Enum={CameraModeAspectRatio={Default=0,LegacyLetterbox=1,HighDefinition_16_X_9=2,Cinemascope_2_Dot_4_X_1=3}}
local function Frame()
    local f={shown=false,points={{"CENTER",UIParent,"CENTER",0,0}},scale=1,width=800,height=128,writes=0,scripts={}}
    function f:IsShown() return self.shown end
    function f:IsForbidden() return self.forbidden end
    function f:IsProtected() return self.protected end
    function f:GetEffectiveScale() return self.scale end
    function f:GetNumPoints() return #self.points end
    function f:GetPoint(i) return unpack(self.points[i]) end
    function f:ClearAllPoints() self.points={};self.writes=self.writes+1 end
    function f:SetPoint(...) self.points[#self.points+1]={...} end
    function f:HookScript(event,fn)
        assert(event=="OnShow" or event=="OnHide","presentation must not hook input")
        assert(not self.scripts[event],"duplicate hook");self.scripts[event]=fn
    end
    function f:GetWidth() return self.width end
    function f:SetWidth(v) self.width=v end
    function f:GetHeight() return self.height end
    function f:SetHeight(v) self.height=v end
    return f
end
WorldFrame,CinematicFrame,MovieFrame,SubtitlesFrame=Frame(),Frame(),Frame(),Frame()
local font,bg,upper,lower=Frame(),Frame(),Frame(),Frame()
SubtitlesFrame.Subtitles={font};SubtitlesFrame.SubtitleBackground=bg
SubtitlesFrame.AddSubtitle=function() end
local refits=0
font.ScaleTextToFit=function() refits=refits+1 end
CinematicFrame.UpperBlackBar=upper;CinematicFrame.LowerBlackBar=lower
CinematicFrame.forcedAspectRatio=1
local nativeKey,nativeClick=function() end,function() end
CinematicFrame.OnKeyDown=nativeKey;MovieFrame.OnClick=nativeClick
assert(loadfile('Core/CinematicPresentation.lua'))('Offhand',addon)
local p=addon.CinematicPresentation
assert(loader.events.PLAY_MOVIE and loader.events.STOP_MOVIE)
CinematicFrame.shown=true;SubtitlesFrame.shown=true
p:Apply()
local function Point(frame,index,x,y)
    local a=frame.points[index]
    assert(a[2]==UIParent and a[3]=="BOTTOMLEFT" and math.abs(a[4]-x)<0.001 and math.abs(a[5]-y)<0.001)
end
Point(CinematicFrame,1,720,0);Point(CinematicFrame,2,2000,720)
Point(SubtitlesFrame,1,720,0);Point(SubtitlesFrame,2,2000,720)
Point(WorldFrame,1,720,0);Point(WorldFrame,2,2000,720)
assert(upper.height==40 and lower.height==40)
local writes=CinematicFrame.writes;p:Apply();assert(CinematicFrame.writes==writes,'no repeated root writes')
assert(CinematicFrame.OnKeyDown==nativeKey and MovieFrame.OnClick==nativeClick)
-- Portrait Mainhand: letterboxing uses Mainhand, not the full bounding canvas.
m.gameLeft=0;m.gameRight=1000;m.gameTop=2000
p:Apply();Point(WorldFrame,1,0,359.375);Point(WorldFrame,2,500,640.625)
assert(math.abs(upper.height-359.375)<0.001)
assert(font.width==452 and bg.width==452,'subtitle text and backdrop must fit a narrow display')
assert(refits==1,'native subtitle fitting must rerun when its width changes')
-- Native text refresh can reset backdrop dimensions; the completed call is confined.
bg.width=700;secureHooks[SubtitlesFrame]();assert(bg.width==452)
-- Wider Mainhand with a requested 16:9 camera ratio must pillarbox.
m.gameLeft=1440;m.gameRight=4000;m.gameTop=1000
CinematicFrame.forcedAspectRatio=2
secureHooks.CinematicFrame_UpdateLettboxForAspectRatio()
Point(WorldFrame,1,915.55555555556,0);Point(WorldFrame,2,1804.4444444444,500)
assert(upper.height==128,'legacy bars restore outside legacy mode')
-- Cinemascope preserves its requested 2.4:1 camera picture on this monitor.
CinematicFrame.forcedAspectRatio=3
p:Apply()
Point(WorldFrame,1,760,0);Point(WorldFrame,2,1960,500)
-- Hidden/unknown presentation modes do not inherit the preceding camera crop.
CinematicFrame.forcedAspectRatio=0;p:Apply()
Point(WorldFrame,1,720,0);Point(WorldFrame,2,2000,500)
-- A movie uses its own root; subtitles remain on Mainhand.
CinematicFrame.shown=false;MovieFrame.shown=true
loader.onEvent(nil,'PLAY_MOVIE')
assert(CinematicFrame.points[1][1]=='CENTER','finished cinematic must regain native points')
Point(MovieFrame,1,720,0);Point(MovieFrame,2,2000,500)
-- Combat work is coalesced and evaluates current state after combat.
combat=true;p:Apply();p:Apply();assert(#queue==1)
addon.db.enabled=false
combat=false;queue[1]()
assert(MovieFrame.points[1][1]=='CENTER' and SubtitlesFrame.points[1][1]=='CENTER')
assert(font.width==800 and bg.width==700,'native text dimensions must restore')
-- Do not restore stale anchors over a later external owner.
addon.db.enabled=true;p:Apply()
MovieFrame.points={{'TOP',UIParent,'TOP',22,33}}
MovieFrame.shown=false;SubtitlesFrame.shown=false;p:Apply()
assert(MovieFrame.points[1][1]=='TOP' and MovieFrame.points[1][4]==22)
-- Pending playback retries must not restore confinement after unspanning.
MovieFrame.shown=true;p:Schedule();m.isSpanned=false
for _,fn in ipairs(timers) do fn() end
assert(MovieFrame.points[1][1]=='TOP')
local blocked=Frame();blocked.protected=true;MovieFrame=blocked
p:Attach();assert(next(blocked.scripts)==nil)
local other={isRetail=false}
assert(loadfile('Core/CinematicPresentation.lua'))('Offhand',other)
assert(other.CinematicPresentation==nil,'unreviewed clients must keep native presentation')
print('PASS: Mainhand cinematic/movie/subtitle bounds, aspect ratios, native restoration, combat deferral and ownership')
