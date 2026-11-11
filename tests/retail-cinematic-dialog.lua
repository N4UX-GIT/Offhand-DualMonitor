-- Native input and visibility remain Blizzard-owned; this models presentation only.
StaticPopupDialogs, SlashCmdList = {}, {}
WOW_PROJECT_ID, WOW_PROJECT_MAINLINE = 1, 1
GetBuildInfo = function() return "12.1.5", "70575", "", 120105 end
local events, handler, timers = {}, nil, {}
CreateFrame = function(_, name)
    return { RegisterEvent = function(_, event) events[event] = true end,
        SetScript = function(_, script, fn)
            if name == "OffhandEventFrame" and script == "OnEvent" then handler = fn end
        end }
end
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
UIParent = { GetEffectiveScale = function() return 0.5 end }
local addon = {}
assert(loadfile("Core/Init.lua"))("Offhand", addon)
addon.db = { enabled = true }
local metrics = {isSpanned=true, gameLeft=1440, gameRight=4000, gameBottom=0, gameTop=1440}
addon.Viewport = {GetMetrics=function() return metrics end}
local function Dialog()
    local frame = {shown=false, hooks=0, writes=0, points={}}
    function frame:IsShown() return self.shown end
    function frame:IsForbidden() return self.forbidden end
    function frame:IsProtected() return self.protected end
    function frame:GetEffectiveScale() return 1 end
    function frame:ClearAllPoints() self.points={} end
    function frame:SetPoint(...) self.points={...}; self.writes=self.writes+1 end
    function frame:HookScript(event, fn)
        assert(event == "OnShow", "must not hook input, clicks or native visibility")
        self.hooks=self.hooks+1; self.onShow=fn
    end
    return frame
end
local cinematic, movie = Dialog(), Dialog()
local nativeKey, nativeClick = function() end, function() end
CinematicFrame = {closeDialog=cinematic, OnKeyDown=nativeKey}
cinematic.OnClick = nativeClick
assert(events.PLAY_MOVIE and addon.isRetail and not addon.isForever)
assert(addon:AttachCinematicSkipDialogRecovery())
assert(not addon:AttachCinematicSkipDialogRecovery() and cinematic.hooks==1)
assert(cinematic.writes==0 and not cinematic.shown, "attachment must not show or move a hidden dialog")
cinematic.shown=true; cinematic.onShow(cinematic)
assert(cinematic.points[1]=="CENTER" and cinematic.points[2]==UIParent
    and cinematic.points[3]=="BOTTOMLEFT"
    and cinematic.points[4]==1360 and cinematic.points[5]==360,
    "mixed-height Mainhand center must convert UIParent units to dialog scale")
assert(CinematicFrame.OnKeyDown==nativeKey and cinematic.OnClick==nativeClick)
assert(addon._cinematicSkipDialogStatus:find("centered:CinematicFrame",1,true))
-- Standalone movie event arrives before Blizzard's UI exists in this event turn.
handler(nil,"PLAY_MOVIE",123)
MovieFrame = {CloseDialog=movie}
for _, fn in ipairs(timers) do fn() end
assert(movie.hooks==1 and movie.writes==0)
movie.shown=true; movie.onShow(movie)
assert(movie.points[4]==1360 and movie.points[5]==360)
assert(addon._cinematicSkipDialogStatus:find("centered:MovieFrame",1,true))
local before=movie.writes
addon.db.enabled=false; movie.onShow(movie)
addon.db.enabled=true; metrics.isSpanned=false; movie.onShow(movie)
metrics.isSpanned=true; movie.protected=true; movie.onShow(movie)
movie.protected=false; movie.forbidden=true; movie.onShow(movie)
movie.forbidden=false; movie.shown=false; movie.onShow(movie)
movie.shown=true; addon.isRetail=false; movie.onShow(movie)
assert(movie.writes==before, "disabled, unspanned, protected, forbidden, hidden and other clients must yield")
addon.isForever=true; movie.onShow(movie)
assert(movie.writes==before+1, "Forever recovery must remain available")
local blocked = Dialog()
blocked.protected=true
MovieFrame.CloseDialog=blocked
addon:AttachCinematicSkipDialogRecovery()
assert(blocked.hooks==0, "must not attach presentation hooks to protected dialog ancestry")
blocked.protected=false; blocked.forbidden=true
addon:AttachCinematicSkipDialogRecovery()
assert(blocked.hooks==0, "must not attach hooks to forbidden frames")
io.write("PASS: Retail cinematic/movie dialog placement, late creation, scaling, native ownership and exclusions\n")
