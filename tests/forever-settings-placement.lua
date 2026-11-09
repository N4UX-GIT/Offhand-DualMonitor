-- Cooldown Settings must not be mistaken for its Edit Mode cooldown HUD roots.
local combat, gamepad = false, false
UIParent={GetEffectiveScale=function() return .5 end, GetWidth=function() return 5120 end,
    GetHeight=function() return 2880 end}
InCombatLockdown=function() return combat end
local metrics={isSpanned=true,gameLeft=0,gameBottom=0,gameRight=5120,gameTop=1440,
    workspaceLeft=1280,workspaceBottom=1440,workspaceRight=3840,workspaceTop=2880}
local addon={isForever=true, db={enabled=true,seamRedirect=true},
    IsGamepadUIEnabled=function() return gamepad end,
    Viewport={GetMetrics=function() return metrics end}}
local callbacks, queue, registrations={}, {}, 0
EventRegistry={RegisterCallback=function(_,event,callback,owner)
    registrations=registrations+1; callbacks[event]=function(frame) callback(owner,frame) end
end}
C_Timer={After=function(delay, fn) assert(delay==0); queue[#queue+1]=fn end}
local function Flush() local pending=queue; queue={}; for _,fn in ipairs(pending) do fn() end end
assert(loadfile("Core/MenuPlacement.lua"))("Offhand",addon)
local menus=addon.MenuPlacement
local panel={shown=true,left=16,top=2764,width=399,height=609,points={},writes=0}
function panel:IsShown() return self.shown end
function panel:IsProtected() return self.protected end
function panel:IsForbidden() return self.forbidden end
function panel:GetLeft() return self.left end
function panel:GetTop() return self.top end
function panel:GetWidth() return self.width end
function panel:GetHeight() return self.height end
function panel:GetEffectiveScale() return .5 end
function panel:GetNumPoints() return #self.points end
function panel:GetPoint(i) return unpack(self.points[i] or {}) end
function panel:ClearAllPoints() self.points={};self.writes=self.writes+1 end
function panel:SetPoint(...) self.points[1]={...};self.writes=self.writes+1 end
CooldownViewerSettings=panel
assert(menus:InstallForeverSettingsRecovery())
assert(not menus:InstallForeverSettingsRecovery() and registrations==1, "event installation duplicated")
callbacks["CooldownViewerSettings.OnShow"](panel)
assert(panel.writes==0, "settings placement ran inside native OnShow")
Flush()
assert(panel.writes==2 and panel.points[1][4]==0 and panel.points[1][5]==-720,
    "upside-down T void did not recover to the physical Mainhand center")
local writes=panel.writes
panel.left,panel.top=1400,2400
assert(not menus:RecoverForeverCooldownSettings(panel) and panel.writes==writes,
    "reachable workspace placement must remain untouched")
panel.left,panel.top=16,2764
metrics.workspaceRegions={{x=1280,y=1440,width=2560,height=1440}}
combat=true;assert(not menus:RecoverForeverCooldownSettings(panel));combat=false
gamepad=true;assert(not menus:RecoverForeverCooldownSettings(panel));gamepad=false
panel.protected=true;assert(not menus:RecoverForeverCooldownSettings(panel));panel.protected=false
panel.forbidden=true;assert(not menus:RecoverForeverCooldownSettings(panel));panel.forbidden=false
addon.db.seamRedirect=false;assert(not menus:RecoverForeverCooldownSettings(panel));addon.db.seamRedirect=true
assert(panel.writes==writes, "ineligible settings recovery changed the native frame")
callbacks["CooldownViewerSettings.OnShow"](panel)
panel.shown=false;Flush()
assert(panel.writes==writes and not panel.shown, "deferred recovery reopened a closed settings panel")
panel.shown=true
callbacks["CooldownViewerSettings.OnShow"](panel)
callbacks["CooldownViewerSettings.OnShow"](panel)
Flush()
assert(panel.writes==writes, "already owned correct anchor must not be rewritten")
assert(not panel.OnShow and not panel.OnUpdate, "settings recovery installed native scripts")
print("PASS: Forever Cooldown Settings event recovery, physical void, guards, ownership and bounded lifecycle")
