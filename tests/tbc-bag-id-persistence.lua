local timers,combatQueue={},{}
local now,sequence=0,0
local combat=false
InCombatLockdown=function() return combat end
C_Timer={After=function(delay,fn) sequence=sequence+1; timers[#timers+1]={at=now+delay,sequence=sequence,fn=fn} end}
local function Flush()
    while #timers>0 do
        table.sort(timers,function(a,b) return a.at<b.at or (a.at==b.at and a.sequence<b.sequence) end)
        local timer=table.remove(timers,1); now=timer.at; timer.fn()
    end
end
local metrics={isSpanned=true}
local addon={tocVersion=20506,db={enabled=true,persistentWorkspacePanels=true,restoreWorkspaceOnReload=true,
    savedWorkspacePositions={},openWorkspacePanels={ContainerFrame9=true,ContainerFrame10=false},
    nativeBackpackWorkspaceOpen=true},Viewport={GetMetrics=function() return metrics end}}
assert(loadfile('Core/CanvasPanelRegistry.lua'))('Offhand',addon)
assert(loadfile('Core/CanvasBackpackState.lua'))('Offhand',addon)
local bags=addon.CanvasBackpackState
NUM_CONTAINER_FRAMES=5
local function Frame(index,id,shown,workspace)
    local f={id=id,shown=shown,workspace=workspace,name='ContainerFrame'..index}
    function f:GetID() return self.id end
    function f:GetName() return self.name end
    function f:IsShown() return self.shown end
    function f:Show() error('must open through native bag ID API') end
    _G[f.name]=f
    addon.db.savedWorkspacePositions[f.name]={x=index*100,y=700}
    return f
end
local equipped=Frame(1,3,true,true) -- pool frame 1 is not necessarily backpack
equipped.GetLeft=function() return 100 end
equipped.GetTop=function() return 700 end
equipped.GetWidth=function() return 192 end
equipped.GetHeight=function() return 250 end
equipped.GetEffectiveScale=function() return 1 end
UIParent={GetEffectiveScale=function() return 1 end,GetHeight=function() return 1200 end}
metrics.workspaceLeft=0; metrics.workspaceBottom=0; metrics.workspaceWidth=1000; metrics.workspaceHeight=1200
metrics.workspaceRight=1000; metrics.workspaceTop=1200
assert(loadfile('Core/CanvasPersistence.lua'))('Offhand',addon)
-- Grouped bag layout can remove the pooled frame's independent position while
-- leaving its rendered equipped bag on Offhand.
addon.db.savedWorkspacePositions.ContainerFrame1=nil
local backpack=Frame(2,0,false,true)
Frame(3,-1,true,true) -- bank must never persist
Frame(4,2,true,false) -- Mainhand must remain native
Frame(5,8,true,true) -- bank bag must never persist
local opened,placed={},{}
local canvas={IsFrameOnWorkspace=function(frame) return frame.workspace end,
    RestoreWorkspacePosition=function(frame) placed[frame.id]=addon.db.savedWorkspacePositions[frame.name].x end}
addon.Canvas=canvas
addon.RunOrQueueCombat=function(_,fn) combatQueue[#combatQueue+1]=fn end
OpenAllBags=function() error('never restore all bags from frame markers') end
ToggleAllBags=OpenAllBags
IsBagOpen=function(id)
    for i=1,5 do local f=_G['ContainerFrame'..i]; if f.shown and f.id==id then return i end end
end
OpenBag=function(id)
    opened[#opened+1]=id
    -- Model a different allocation order after reload.
    local frame=id==3 and ContainerFrame2 or ContainerFrame1
    frame.id=id; frame.shown=true; frame.workspace=true
end
bags.CaptureTBCBagIDs(canvas)
local snapshot=addon.db.tbcWorkspaceBagSnapshot
assert(snapshot.open['3'] and not snapshot.open['0'] and not snapshot.open['2'] and not snapshot.open['8'])
assert(snapshot.open['3'].position.x==100)
equipped.shown=false
bags.QueueTBCBagIDRestore(canvas); Flush()
assert(#opened==1 and opened[1]==3 and placed[3]==100,
    'restore must follow equipped bag ID into its newly allocated frame and preserve its position')
assert(not IsBagOpen(0), 'restoring one equipped bag must not open backpack')
for i=1,5 do _G['ContainerFrame'..i].shown=false end
bags.CaptureTBCBagIDs(canvas)
assert(next(addon.db.tbcWorkspaceBagSnapshot.open)==nil)
bags.QueueTBCBagIDRestore(canvas); Flush()
assert(#opened==1, 'authoritative empty snapshot must override missing/false/true legacy frame flags')
addon.db.tbcWorkspaceBagSnapshot=nil
bags.QueueTBCBagIDRestore(canvas); Flush()
assert(#opened==1 and canvas.tbcBagIDRestoreStatus=='legacy-frame-intent-ignored',
    'old ambiguous records must never trigger any bag opener')
backpack.id=0; backpack.shown=true
bags.CaptureTBCBagIDs(canvas)
assert(addon.db.tbcWorkspaceBagSnapshot.open['0'])
backpack.shown=false
bags.QueueTBCBagIDRestore(canvas); Flush()
assert(#opened==2 and opened[2]==0, 'backpack-only snapshot must open exactly ID 0')
-- Closing before the delayed callback invalidates the old generation.
for i=1,5 do _G['ContainerFrame'..i].shown=false end
addon.db.tbcWorkspaceBagSnapshot={schema=1,open={['3']={position={x=100,y=700}}}}
bags.QueueTBCBagIDRestore(canvas)
bags.CaptureTBCBagIDs(canvas)
Flush(); assert(#opened==2)
addon.db.tbcWorkspaceBagSnapshot={schema=1,open={['3']={position={x=100,y=700}}}}
bags.QueueTBCBagIDRestore(canvas)
combat=true; Flush(); assert(#combatQueue==1 and #opened==2)
addon.db.enabled=false
combat=false; combatQueue[1](); combatQueue={}; Flush(); assert(#opened==2)
addon.db.enabled=true
bags.QueueTBCBagIDRestore(canvas)
metrics.isSpanned=false; Flush(); assert(#opened==2)
metrics.isSpanned=true
hooksecurefunc=function(name,callback)
    local native=_G[name]
    _G[name]=function(...) local result=native(...); callback(...); return result end
end
CloseBag=function(id)
    for i=1,5 do local frame=_G['ContainerFrame'..i]; if frame.id==id then frame.shown=false end end
end
bags.InstallTBCBagIDTracking(canvas)
equipped.id=3; equipped.shown=true
bags.CaptureTBCBagIDs(canvas)
bags.QueueTBCBagIDRestore(canvas)
CloseBag(3)
Flush()
assert(#opened==2 and next(addon.db.tbcWorkspaceBagSnapshot.open)==nil,
    'actual CloseBag post-hook must cancel an older delayed reload request')
addon.HasCustomBagAddon=function() return true end
assert(not bags.UsesTBCBagIDs())
bags.QueueTBCBagIDRestore(canvas); Flush(); assert(#opened==2)
addon.HasCustomBagAddon=nil
addon.tocVersion=120107
assert(not bags.UsesTBCBagIDs())
-- Fresh UI: the persisted snapshot wants Backpack, but no bag is rendered yet.
-- Native login cleanup closes that already-closed set before the delayed restore.
addon.tocVersion=20506
for i=1,5 do _G['ContainerFrame'..i].shown=false end
addon.db.tbcWorkspaceBagSnapshot={schema=1,open={['0']={position={x=100,y=700}}}}
canvas.tbcBagObservedSignature=nil
CloseAllBags=function() for i=1,5 do _G['ContainerFrame'..i].shown=false end end
bags.InstallTBCBagIDTracking(canvas)
local before=#opened
bags.QueueTBCBagIDRestore(canvas)
CloseAllBags()
Flush()
assert(#opened==before+1 and opened[#opened]==0 and addon.db.tbcWorkspaceBagSnapshot.open['0'],
    'unchanged startup cleanup must not erase the saved open set or cancel its restore')
CloseBag(0); Flush()
assert(next(addon.db.tbcWorkspaceBagSnapshot.open)==nil,
    'a real close after restoration must still record an authoritative closed set')
local afterClose=#opened
bags.QueueTBCBagIDRestore(canvas)
CloseAllBags(); Flush()
assert(#opened==afterClose and next(addon.db.tbcWorkspaceBagSnapshot.open)==nil,
    'preserving unchanged startup state must not resurrect an explicitly closed snapshot')
-- Mixed Backpack/equipped set after grouped layout cleared the equipped root's
-- position. Native frame coordinates must be converted to UIParent units.
equipped.id=0; equipped.shown=true
backpack.id=3; backpack.shown=true
backpack.GetLeft=function() return 120 end
backpack.GetTop=function() return 450 end
backpack.GetWidth=function() return 192 end
backpack.GetHeight=function() return 250 end
backpack.GetEffectiveScale=function() return 0.5 end
UIParent.GetEffectiveScale=function() return 0.25 end
addon.db.savedWorkspacePositions.ContainerFrame2=nil
bags.CaptureTBCBagIDs(canvas)
snapshot=addon.db.tbcWorkspaceBagSnapshot
assert(snapshot.open['0'] and snapshot.open['3'], 'grouped layout must capture every visible workspace bag ID')
assert(snapshot.open['3'].position.x==240 and snapshot.open['3'].position.y==900
    and snapshot.open['3'].position.canvasWidth==1000, 'fallback geometry must use UIParent scaling and canvas metadata')
assert(addon.db.savedWorkspacePositions.ContainerFrame2==nil, 'capture must not rewrite frame ownership or anchors')
CloseBag(3); Flush()
assert(addon.db.tbcWorkspaceBagSnapshot.open['0'] and not addon.db.tbcWorkspaceBagSnapshot.open['3'],
    'closing the equipped bag must keep Backpack intent independently')
print('PASS: TBC bag-ID snapshots prevent bulk reopening and handle frame reuse, cancellation and combat')
