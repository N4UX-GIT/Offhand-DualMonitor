local addon={modules={},tocVersion=20506,db={enabled=true,seamRedirect=true}}
local combat,spanned=false,true
InCombatLockdown=function()return combat end
UIParent={GetEffectiveScale=function()return 0.394 end}
addon.Viewport={GetMetrics=function()return {isSpanned=spanned}end}
assert(loadfile('Core/PopupBounds.lua'))('Offhand',addon)
local p=addon.PopupBounds
local frame={scale=1,writes=0}
function frame:GetScale()return self.scale end
function frame:SetScale(v)self.scale=v;self.writes=self.writes+1;p:UpdateSettingsTooltipScale(self)end
function frame:GetParent()return self.parent end
function frame:IsIgnoringParentScale()return self.ignore end
SettingsTooltip=frame
assert(p:UpdateSettingsTooltipScale(frame) and frame.scale==0.394)
assert(not p:UpdateSettingsTooltipScale(frame) and frame.writes==1,'Repeated update wrote scale again')
UIParent.GetEffectiveScale=function()return 0.7 end
assert(p:UpdateSettingsTooltipScale(frame) and frame.scale==0.7,'UI-scale change did not update owned scale')
assert(p:UpdateSettingsTooltipScale(frame,true) and frame.scale==1,'Hide failed to restore native scale')
frame.parent=UIParent
assert(not p:UpdateSettingsTooltipScale(frame) and frame.scale==1,'Inherited scale was compensated twice')
frame.ignore=true
assert(p:UpdateSettingsTooltipScale(frame) and frame.scale==0.7)
p:UpdateSettingsTooltipScale(frame,true);frame.ignore=nil;frame.parent=nil
assert(p:UpdateSettingsTooltipScale(frame))
frame.scale=0.8
assert(not p:UpdateSettingsTooltipScale(frame) and frame.scale==0.8,'External scale was overwritten')
assert(not p:UpdateSettingsTooltipScale(frame,true) and frame.scale==0.8,'Release overwrote external scale')
-- Fresh roots exercise independent guards without reusing yielded ownership.
local function fresh()
 local f=setmetatable({scale=1,writes=0},{__index=frame});SettingsTooltip=f;return f
end
for _,guard in ipairs({'combat','disabled','ordinary','external','forbidden','protected','otherClient','parent'})do
 local f=fresh();combat=guard=='combat';spanned=guard~='ordinary';addon.db.enabled=guard~='disabled'
 TipTac=guard=='external' and {} or nil
 f.IsForbidden=function()return guard=='forbidden' end;f.IsProtected=function()return guard=='protected' end
 addon.tocVersion=guard=='otherClient' and 11509 or 20506
 if guard=='parent'then f.parent={}end
 assert(not p:UpdateSettingsTooltipScale(f) and f.writes==0,'Guard failed: '..guard)
end
combat=false;spanned=true;addon.db.enabled=true;addon.tocVersion=20506;TipTac=nil
addon.db.seamRedirect=false
local f=fresh();assert(p:UpdateSettingsTooltipScale(f));addon.db.enabled=false
assert(p:UpdateSettingsTooltipScale(f) and f.scale==1,'Feature-off update did not restore native scale')
local unrelated=fresh();SettingsTooltip={}
assert(not p:UpdateSettingsTooltipScale(unrelated),'Unrelated tooltip normalized')
addon.db.enabled=true
local queued=fresh();queued.IsShown=function()return true end
local timers={};C_Timer={After=function(_,callback)timers[#timers+1]=callback end}
p:QueueSettingsTooltipScale(queued);p:QueueSettingsTooltipScale(queued)
assert(#timers==1 and queued.writes==0,'Native layout was interrupted or work was duplicated')
timers[1]();assert(queued.scale==0.7)
queued.IsShown=function()return false end
p:QueueSettingsTooltipScale(queued);timers[2]()
assert(queued.writes==1,'Hidden tooltip was scaled by delayed work')
print('PASS: Anniversary SettingsTooltip scale is bounded, reversible, idempotent and ownership/combat guarded')
