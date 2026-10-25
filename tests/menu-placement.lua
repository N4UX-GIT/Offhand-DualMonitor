-- Existing open menus must follow a settled canvas resize without taking over
-- protected, moved, hidden or externally re-anchored panels.
local combat, width, height = false, 4000, 2560
UIParent = {GetEffectiveScale=function() return 0.4 end,
    GetWidth=function() return width end, GetHeight=function() return height end}
InCombatLockdown = function() return combat end
local metrics={isSpanned=true,gameLeft=1440,gameRight=4000,gameBottom=0,gameTop=1440}
local addon={db={enabled=true}, Viewport={GetMetrics=function() return metrics end}}
assert(loadfile("Core/MenuPlacement.lua"))("Offhand",addon)
local function Frame()
    local f={points={},shown=true,writes=0}
    function f:IsShown() return self.shown end
    function f:IsForbidden() return self.forbidden end
    function f:IsProtected() return self.protected end
    function f:GetNumPoints() return #self.points end
    function f:GetPoint(i) return unpack(self.points[i] or {}) end
    function f:ClearAllPoints() self.points={}; self.writes=self.writes+1 end
    function f:SetPoint(...) self.points[1]={...}; self.writes=self.writes+1 end
    function f:GetEffectiveScale() return 0.7 end
    return f
end
local menus=addon.MenuPlacement
local panel=Frame()
assert(menus:Center(panel))
local _,relative,rp,x,y=panel:GetPoint(1)
assert(relative==UIParent and rp=="CENTER" and math.abs(x-720*0.4/0.7)<0.01
    and math.abs(y+560*0.4/0.7)<0.01,"spanned Mainhand center must respect frame/UI scales")
local writes=panel.writes
menus:Refresh()
assert(panel.writes==writes,"unchanged geometry must not dirty native anchors")
width,height=2114,1353
metrics={isSpanned=false,gameLeft=0,gameRight=width,gameBottom=0,gameTop=height}
menus:Refresh()
_,relative,rp,x,y=panel:GetPoint(1)
assert(x==0 and y==0 and relative==UIParent,"restored window must center an already-open owned panel")
writes=panel.writes
menus:Refresh()
assert(panel.writes==writes)
panel:SetPoint("CENTER",UIParent,"CENTER",44,55)
writes=panel.writes
menus:Refresh()
assert(panel.writes==writes,"external/user re-anchoring must revoke ownership")
panel:SetPoint("CENTER",UIParent,"CENTER",0,0)
menus:Refresh()
assert(panel.writes==writes+1,"revoked ownership must not be silently reclaimed")
assert(menus:Center(panel))
panel.shown=false
width,height=4000,2560
metrics={isSpanned=true,gameLeft=1440,gameRight=4000,gameBottom=0,gameTop=1440}
writes=panel.writes
menus:Refresh()
assert(panel.writes==writes and not panel.shown,"refresh must not show hidden menus")
panel.shown=true; combat=true
menus:Refresh()
assert(panel.writes==writes,"combat must defer menu writes")
combat=false; panel.protected=true
menus:Refresh()
assert(panel.writes==writes,"protected native roots must remain untouched")
panel.protected=false; panel.forbidden=true
menus:Refresh()
assert(panel.writes==writes)
panel.forbidden=false; addon.db.enabled=false
menus:Refresh()
assert(panel.writes==writes,"disabled profiles must not reposition panels")
addon.db.enabled=true
menus:Refresh()
assert(panel.writes>writes,"safe later layout refresh should finish the resize")
local untouched=Frame()
menus:Refresh()
assert(untouched.writes==0,"unowned frames must never be adopted by refresh")
metrics.gameLeft=0/0
writes=panel.writes
assert(not menus:Center(panel) and panel.writes==writes,"invalid geometry must not reach native setters")
print("PASS: menu restore/spanning transitions, effective scale, ownership, idempotence and protected/input boundaries")
