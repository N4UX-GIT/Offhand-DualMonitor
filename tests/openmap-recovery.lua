-- One-shot owner-coordinated recovery, including mixed-height physical voids.
local addon = {isForever=true, db={enabled=true}, L=setmetatable({}, {__index=function(_, key) return key end})}
local owner, combat, gamepad, held = "OpenMap", false, false, false
assert(loadfile("Core/CanvasCompatibility.lua"))("Offhand", addon)
addon.CanvasCompatibility.GetWorldMapExternalOwner=function() return owner end
addon.IsGamepadUIEnabled = function() return gamepad end
InCombatLockdown = function() return combat end
IsMouseButtonDown = function() return held end
CreateFrame = function() error("recovery must not install frames or hooks") end
C_Timer = setmetatable({}, {__index=function() error("recovery must not schedule work") end})
UIParent = {GetEffectiveScale=function() return .8 end, GetWidth=function() return 3000 end,
    GetHeight=function() return 2200 end}
local metrics = {isSpanned=true, gameLeft=1500, gameRight=3000, gameBottom=800, gameTop=2200}
addon.Viewport = {GetMetrics=function() return metrics end}
local db = {enabled=true, windowScale=.5, windowSize={1100,700}, window={"TOPLEFT","TOPLEFT",120,60}, unrelated=true}
local module = {db=db}
OpenMapDB = {worldmap=db}
OpenMap = {version="v0.7.5-beta", GetModule=function(_, name) assert(name=="worldmap"); return module end}
OpenMapAPI = {major=1,version=4,IsStitched=function() return true end}
local writes, fail = 0, false
local map = {point={"TOPLEFT", UIParent, "TOPLEFT",120,60}, shown=true, maximized=false, forbidden=false}
WorldMapFrame = map
function map:IsShown() return self.shown end
function map:IsVisible() return self.shown end
function map:IsMaximized() return self.maximized end
function map:IsForbidden() return self.forbidden end
function map:GetEffectiveScale() return .4 end
function map:GetScale() return .5 end
function map:GetWidth() return 1100 end
function map:GetHeight() return 700 end
function map:GetNumPoints() return self.point and 1 or 0 end
function map:GetPoint() return unpack(self.point) end
function map:GetTop() return self.point[1]=="TOP" and self.point[5] or 4460 end
function map:GetLeft() return self.point[1]=="TOP" and self.point[4]-550 or self.point[4] end
function map:ClearAllPoints() writes=writes+1; self.point=nil end
function map:SetPoint(point, relative, relativePoint, x, y)
    writes=writes+1
    if fail then fail=false; error("simulated root writer rejection") end
    self.point={point, relative, relativePoint, x, y}
    -- Model OpenMap's post-hook: a foreign root write loses to the owner's save.
    local saved=db.window
    if saved then self.point={saved[1], UIParent, saved[2], saved[3], saved[4]} end
end
assert(loadfile("Core/OpenMapRecovery.lua"))("Offhand", addon)
assert(writes==0, "loading recovery changed the map")
local recovery=addon.OpenMapRecovery
local oldSize, oldScale = db.windowSize, db.windowScale
assert(recovery:Run())
assert(db.window[1]=="TOP" and db.window[2]=="BOTTOMLEFT"
    and db.window[3]==4500 and db.window[4]==4352, "scaled Mainhand anchor is wrong")
assert(map:GetTop()*.5==2176 and (map:GetLeft()+550)*.5==2250,
    "title was put in the physical void instead of Mainhand")
assert(db.windowSize==oldSize and db.windowScale==oldScale and db.unrelated,
    "recovery reset unrelated vendor settings")
map:SetPoint("CENTER",UIParent,"CENTER",0,0)
assert(map.point[4]==4500, "the owner's ordinary reopen/restore must keep the recovered save")

local function Refuses(reason)
    local prior, count=db.window, writes
    local ok, why=recovery:Run()
    assert(not ok and why==reason)
    assert(db.window==prior and writes==count, "ineligible recovery mutated state")
end
combat=true; Refuses("combat"); combat=false
gamepad=true; Refuses("unavailable"); gamepad=false
held=true; Refuses("unavailable"); held=false
addon.isForever=false; Refuses("unavailable"); addon.isForever=true
addon.db.enabled=false; Refuses("unavailable"); addon.db.enabled=true
for _, value in ipairs({"MoveAny", "ClassicUIForever", "LeatrixMaps"}) do owner=value; Refuses("unavailable") end
owner="OpenMap"
OpenMap.version="v0.7.6-beta"; Refuses("unavailable"); OpenMap.version="v0.7.5-beta"
OpenMapAPI.version=5; Refuses("unavailable"); OpenMapAPI.version=4
OpenMapAPI.IsStitched=function() return false end; Refuses("unavailable")
OpenMapAPI.IsStitched=function() return true end
OpenMapDB.worldmap={}; Refuses("unavailable"); OpenMapDB.worldmap=db
map.shown=false; Refuses("unavailable"); map.shown=true
map.forbidden=true; Refuses("unavailable"); map.forbidden=false
map.maximized=true; Refuses("unavailable"); map.maximized=false
db.windowScale=.6; Refuses("unavailable"); db.windowScale=.5
db.windowSize={800,700}; Refuses("unavailable"); db.windowSize=oldSize
local valid=db.window; db.window={}; Refuses("unavailable"); db.window=valid
metrics.gameTop=700; Refuses("unavailable"); metrics.gameTop=2200
metrics.gameRight=0/0; Refuses("unavailable"); metrics.gameRight=3000
issecretvalue=function(value) return value==1500 end; Refuses("unavailable"); issecretvalue=nil
local getTop=map.GetTop
map.GetTop=function() error("unavailable geometry after root write") end
local prior=db.window; local priorPoint={unpack(map.point)}
assert(not recovery:Run() and db.window==prior, "failed recovery did not restore the owner's save")
map.GetTop=getTop
assert(map.point[1]==priorPoint[1] and map.point[4]==priorPoint[4], "failed recovery lost the old anchor")
fail=true; assert(not recovery:Run() and db.window==prior, "root write failure lost saved state")

-- Restored single-screen recovery and upper/left Mainhand use the live rectangle too.
metrics={isSpanned=false, gameLeft=0,gameRight=3000,gameBottom=0,gameTop=2200}
assert(recovery:Run() and db.window[3]==3000)
metrics={isSpanned=true, gameLeft=0,gameRight=1200,gameBottom=900,gameTop=2200}
assert(recovery:Run() and db.window[3]==1200)
OpenMap.version="v0.8.6"
metrics.workspaceLeft, metrics.workspaceRight = 1200, 3000
metrics.workspaceBottom, metrics.workspaceTop = 0, 1300
assert(recovery:Run(true))
assert(db.window[3]==4200 and db.window[4]==2552 and db.windowSize==oldSize and db.windowScale==oldScale)
map:SetPoint("CENTER",UIParent,"CENTER",0,0)
assert(map.point[4]==4200 and map.point[5]==2552,
    "OpenMap 0.8.6 must retain the saved Offhand anchor when it reapplies its position")
OpenMap.version="v0.8.7"
metrics.workspaceBottom = 1000
local workspaceAnchor, before = db.window, writes
local fitted, fitReason = recovery:Run(true)
assert(not fitted and fitReason=="workspace-fit" and db.window==workspaceAnchor and writes==before)
metrics.workspaceBottom, metrics.isSpanned = 0, false
assert(not recovery:Run(true) and db.window==workspaceAnchor and writes==before)
metrics.isSpanned = true
local printed
addon.Print=function(_, text) printed=text end
assert(recovery:RunAndReport(true) and printed=="OPENMAP_WORKSPACE_DONE")
assert(recovery:RunAndReport() and printed=="OPENMAP_RECOVERY_DONE")
combat=true; recovery:RunAndReport(); assert(printed=="OPENMAP_RECOVERY_COMBAT")
print("PASS: OpenMap explicit recovery, ownership, scale/void geometry, guards, rollback and reporting")
