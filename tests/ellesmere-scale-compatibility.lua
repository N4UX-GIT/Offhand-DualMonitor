local root,combat=.64,false
local timers,hooks={},{}
UIParent={GetScale=function()return root end}
InCombatLockdown=function()return combat end
C_Timer={After=function(_,fn)timers[#timers+1]=fn end}
hooksecurefunc=function(t,k,fn)
 local old=t[k];hooks[#hooks+1]={t,k};t[k]=function(...)old(...);fn(...)end
end
local a={db={enabled=true},Viewport={GetMetrics=function()return{isSpanned=true}end}}
local calls=0
function a:ApplyFullLayout(preserveScale)
 assert(preserveScale==true,'external scale change must preserve player-selected root')
 assert(not combat);calls=calls+1
end
EllesmereUIDB={ppUIScale=.64}
EllesmereUI={PP={perfect=768/1440}}
local pp=EllesmereUI.PP
function pp.UpdateMult()pp.mult=pp.perfect/EllesmereUIDB.ppUIScale end
function pp.SetUIScale(v)if combat then return end;EllesmereUIDB.ppUIScale=v;root=v;pp.UpdateMult()end
assert(loadfile('Core/EllesmereScaleCompatibility.lua'))('Offhand',a)
local c=a.EllesmereScaleCompatibility
c:Refresh()
root=.4344242424;c:Refresh()
assert(math.abs(pp.mult-pp.perfect/root)<1e-9,'pixel grid retained saved scale after Offhand root change')
assert(EllesmereUIDB.ppUIScale==.64,'pixel-grid sync rewrote the saved EUI scale')
pp.UpdateMult();assert(math.abs(pp.mult-pp.perfect/root)<1e-9,'vendor refresh lost the actual pixel grid')
for _=1,4 do c:Refresh()end
assert(#hooks==2,'scale hooks duplicated')
pp.SetUIScale(.8);pp.SetUIScale(.9)
assert(#timers==1,'slider changes must coalesce')
table.remove(timers,1)();assert(calls==1 and root==.9,'layout did not retain the selected scale')
pp.SetUIScale(.7);a.db.enabled=false;table.remove(timers,1)();assert(calls==1,'disabled addon ran delayed geometry')
pp.UpdateMult();assert(pp.mult==pp.perfect/.7,'disabled adapter changed vendor behavior')
a.db.enabled=true;combat=true;pp.SetUIScale(.85);assert(#timers==0,'combat setter queued unsafe layout')
combat=false;pp.SetUIScale(.85);combat=true;table.remove(timers,1)();assert(calls==1,'combat callback ran layout')
combat=false;pp.SetUIScale(.85);table.remove(timers,1)();assert(calls==2)
a.Viewport.GetMetrics=function()return{isSpanned=false}end
pp.SetUIScale(.75);assert(#timers==0,'unspanned setter requested spanned geometry')
pp.perfect=0/0;pp.UpdateMult=function()pp.mult=.123 end;c:Refresh()
assert(pp.mult==.123,'invalid physical ratio overwrote the vendor result')
EllesmereUI=nil;c:Refresh()
print('PASS: Ellesmere pixel grid follows actual root; external scale refresh preserves preferences and yields when inactive/combat')
