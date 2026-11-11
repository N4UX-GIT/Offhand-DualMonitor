-- Restoring the spanned root scale must also return registered Forever panels
-- to native layout, without closing/reopening their interaction sessions.
local combat,scale,reflows,spanned=false,.8,0,true
InCombatLockdown=function()return combat end
UIParent={GetScale=function()return scale end,SetScale=function(_,v)scale=v end}
WorldFrame={GetScale=function()return 1 end,SetScale=function()end}
GetCVar=function()return nil end
local addon={isForever=true,db={enabled=true,hudScale=.7}}
assert(loadfile('Core/Viewport.lua'))('Offhand',addon)
local v=addon.Viewport
v.GetMetrics=function()return{isSpanned=spanned,gamePixelHeight=1080,gamePixelWidth=1920,physicalHeight=2160}end
UpdateUIPanelPositions=function()
 assert(not combat and math.abs(scale-.8)<.00001,'native reflow must follow root restoration')
 reflows=reflows+1
end
v:ApplyGlobalScale();assert(math.abs(scale-.35)<.00001 and reflows==0)
addon.db.enabled=false;v:ApplyGlobalScale()
assert(scale==.8 and reflows==1,'owned scale release stranded native panel anchors')
v:ApplyGlobalScale();assert(reflows==1,'inactive refresh repeatedly reflowed native panels')

addon.db.enabled=true;v:ApplyGlobalScale();scale=.9
addon.db.enabled=false;v:ApplyGlobalScale()
assert(scale==.9 and reflows==1,'external scale ownership must not trigger panel takeover')

scale=.8;addon.db.enabled=true;v:ApplyGlobalScale();spanned=false;v:ApplyGlobalScale()
assert(scale==.8 and reflows==2,'loss of span must return native panel layout')

spanned=true;v:ApplyGlobalScale();addon.db.enabled=false;combat=true;v:ApplyGlobalScale()
assert(math.abs(scale-.35)<.00001 and reflows==2,'combat release touched protected layout')
combat=false;v:ApplyGlobalScale();assert(scale==.8 and reflows==3)

addon.isForever=false;addon.db.enabled=true;v:ApplyGlobalScale();addon.db.enabled=false;v:ApplyGlobalScale()
assert(reflows==3,'Forever correction leaked into other client adapters')
addon.isForever=true;addon.db.enabled=true;v:ApplyGlobalScale();addon.db.enabled=false
UpdateUIPanelPositions=nil;v:ApplyGlobalScale();assert(scale==.8,'missing optional native reflow broke scale release')
print('PASS: owned Forever scale release reflows native panels once, preserving external ownership, client and combat boundaries')
