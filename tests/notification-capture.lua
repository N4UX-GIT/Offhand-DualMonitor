local addon={isRetail=true,HUDCompatibility={UsesForeverEditMode=function() return false end}}
local timers,clock,combat,created={},0,false,0
GetTime=function() return clock end
InCombatLockdown=function() return combat end
C_Timer={After=function(delay,fn) timers[#timers+1]={delay=delay,fn=fn} end}
local controller
CreateFrame=function(_,name,parent,template)
    assert(not name and not parent and not template,'capture controller must be addon-owned')
    created=created+1
    controller={events={},unregisters=0}
    function controller:RegisterEvent(event) self.events[event]=true end
    function controller:UnregisterAllEvents() self.events={};self.unregisters=self.unregisters+1 end
    function controller:SetScript(event,fn) assert(event=='OnEvent');self.onEvent=fn end
    return controller
end
UIParent={GetEffectiveScale=function() return 0.5 end}
assert(loadfile('Core/HUDTransientPolicy.lua'))('Offhand',addon)
assert(loadfile('Core/HUDTransientFrames.lua'))('Offhand',addon)
local hud={}
addon.HUDTransientFrames.Install(hud,{Points=function() error('capture must never reposition') end,Anchor=function() end,Prepare=function() end})
assert(hud:GetNotificationCaptureReports()==nil and created==0 and #timers==0,'no capture work before opt-in')
local x,shown=500,true
local toast={toastInfo={displayType=42,title='PRIVATE TITLE MUST NEVER BE RECORDED'}}
function toast:IsShown() if combat then error('combat frame read') end;return shown end
function toast:GetName() return nil end
function toast:GetParent() return EventToastManagerFrame end
function toast:GetNumPoints() return 1 end
function toast:GetPoint() return 'CENTER',EventToastManagerFrame,'CENTER',0,0 end
function toast:GetLeft() return x end
function toast:GetBottom() return 100 end
function toast:GetWidth() return 400 end
function toast:GetHeight() return 72 end
function toast:GetEffectiveScale() return 1 end
function toast:GetEffectiveAlpha() return 1 end
toast.Show=function() error('never show a native toast') end
toast.Hide=function() error('never hide a native toast') end
toast.SetPoint=function() error('never move a native toast') end
EventToastManagerFrame={currentDisplayingToast=toast,IsShown=function() return shown end,
    GetParent=function() return UIParent end,GetName=function() return 'EventToastManagerFrame' end}
TopBannerMgr={currentBanner={frame=toast}}
assert(hud:ArmNotificationCapture() and created==1)
assert(controller.events.CHALLENGE_MODE_COMPLETED and controller.events.DISPLAY_EVENT_TOASTS)
local reports=table.concat(hud:GetNotificationCaptureReports(),'\n')
assert(reports:find('displayType=42',1,true) and reports:find('uiRect=1000/200/800/144',1,true))
assert(not reports:find('PRIVATE TITLE',1,true))
controller.onEvent(nil,'CHALLENGE_MODE_COMPLETED')
local scheduled=#timers
controller.onEvent(nil,'DISPLAY_EVENT_TOASTS');assert(#timers==scheduled,'event bursts must share a bounded sample window')
local before=#hud.notificationCapture.lines
clock=0.2;combat=true;hud:RecordNotificationCapture('combat')
assert(#hud.notificationCapture.lines==before+1 and hud.notificationCapture.lines[#hud.notificationCapture.lines]:find('deferred:combat',1,true))
combat=false;shown=false;EventToastManagerFrame.currentDisplayingToast=nil
for i=2,#timers do clock=timers[i].delay;timers[i].fn() end
reports=table.concat(hud:GetNotificationCaptureReports(),'\n')
assert(reports:find('displayType=42',1,true),'visible pooled toast evidence must survive its disappearance')
assert(reports:find('active-event-toast=absent',1,true))
EventToastManagerFrame.currentDisplayingToast=toast;shown=true
for i=1,90 do x=i;hud:RecordNotificationCapture('bounded') end
assert(#hud.notificationCapture.lines==64 and hud.notificationCapture.trimmed>0)
hud:StopNotificationCapture();local count=#hud.notificationCapture.lines
controller.onEvent(nil,'SCENARIO_COMPLETED');hud:RecordNotificationCapture('stopped')
assert(#hud.notificationCapture.lines==count and next(controller.events)==nil)
local oldTimer=timers[1].fn
assert(hud:ArmNotificationCapture() and created==1)
oldTimer();assert(hud.notificationCapture.active,'old expiry must not stop a newer capture')
timers[#timers].fn();assert(not hud.notificationCapture.active,'capture expires after one hour')
combat=true;assert(not hud:ArmNotificationCapture());combat=false
addon.isRetail=false;assert(not hud:ArmNotificationCapture())
print('PASS: opt-in notification capture, disappearing pooled frames, privacy, combat exclusion, bounded work and expiry')
