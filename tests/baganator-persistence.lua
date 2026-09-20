local addon = { db = { enabled=true, savedWorkspacePositions={} }, Canvas={} }
local queue, tick, onEvent = {}, nil, nil
local combat = false
InCombatLockdown = function() return combat end
C_Timer = {
    After = function(_, fn) queue[#queue+1] = fn end,
    NewTicker = function(_, fn) tick = fn; return {} end,
}
CreateFrame = function() return {
    RegisterEvent=function() end,
    SetScript=function(_, _, fn) onEvent=fn end,
} end
UIParent = { GetEffectiveScale=function() return 0.5 end }
local function flush()
    local count=0
    while #queue>0 do
        count=count+1; assert(count<100, "unbounded restore retry")
        local fn=table.remove(queue,1); fn()
    end
end
local name="Baganator_CategoryViewBackpackViewFrameTest"
local bag={shown=false,x=100,y=300,scripts={}}
function bag:GetName() return name end
function bag:IsVisible() return self.shown end
function bag:GetEffectiveScale() return 0.5 end
function bag:GetLeft() return self.x end
function bag:GetBottom() return self.y end
function bag:HookScript(s,fn) self.scripts[s]=fn end
function bag:Show() self.shown=true; if self.scripts.OnShow then self.scripts.OnShow() end end
function bag:Hide() self.shown=false; if self.scripts.OnHide then self.scripts.OnHide() end end
addon.Canvas.IsFrameOnWorkspace=function(f) return f.x < 1440 end
function addon.Canvas:RestoreWorkspacePosition(f)
    local p=addon.db.savedWorkspacePositions[f:GetName()]; f.x=p.x; f.y=p.y
end
_G[name]=bag
-- An item button remains locally shown even when its parent bag is hidden.
BGRLiveItemButton1={IsShown=function() return true end}
local toggles=0
ToggleAllBags=function() toggles=toggles+1; if bag.shown then bag:Hide() else bag:Show() end end
assert(loadfile("Core/BagPersistence.lua"))("Offhand",addon)
local tracker=addon.BagPersistence
onEvent(nil,"PLAYER_LOGIN"); onEvent(nil,"PLAYER_ENTERING_WORLD"); flush()
bag:Show(); tick()
assert(addon.db.baganatorWorkspacePanels[name].x==100)
-- UI teardown hides the bag before leaving; deferred hide must not erase state.
bag:Hide(); onEvent(nil,"PLAYER_LEAVING_WORLD"); flush(); tick()
assert(addon.db.baganatorWorkspacePanels[name])
bag.x=2000
onEvent(nil,"PLAYER_ENTERING_WORLD"); flush()
assert(bag.shown and bag.x==100 and toggles==1, "restore root bag and position despite shown item button")
onEvent(nil,"PLAYER_LEAVING_WORLD"); onEvent(nil,"PLAYER_ENTERING_WORLD"); flush()
assert(toggles==1, "already-open bag must not toggle closed")
bag:Hide(); flush(); assert(not next(addon.db.baganatorWorkspacePanels), "manual close must persist")
onEvent(nil,"PLAYER_LEAVING_WORLD"); onEvent(nil,"PLAYER_ENTERING_WORLD"); flush()
assert(not bag.shown and toggles==1)
bag.x=2000; bag:Show(); tick()
assert(not next(addon.db.baganatorWorkspacePanels), "game-view bags must not be restored")
bag.x=100; tick(); bag:Hide(); onEvent(nil,"PLAYER_LEAVING_WORLD"); flush()
combat=true; onEvent(nil,"PLAYER_ENTERING_WORLD"); flush(); assert(not bag.shown)
combat=false; onEvent(nil,"PLAYER_REGEN_ENABLED"); flush(); assert(bag.shown)
addon.db.restoreWorkspaceOnReload=false; tick()
assert(not next(addon.db.baganatorWorkspacePanels), "disabled preference must clear snapshot")
-- Roots can be created after entering the world (lazy addon initialization).
addon.db.restoreWorkspaceOnReload=true
addon.db.baganatorWorkspacePanels={[name]={x=110,y=310}}
bag.shown=false; _G[name]=nil; tracker.frames={}
onEvent(nil,"PLAYER_ENTERING_WORLD")
table.remove(queue,1)()
assert(#queue>0 and not bag.shown)
_G[name]=bag; flush(); assert(bag.shown and bag.x==110)
print("PASS: Baganator reload snapshots, root-only detection, lazy restore, manual close, settings and combat")

