-- Execute the real local loader and delayed restore with isolated services.
local addon={tocVersion=20506,db={enabled=true,persistentWorkspacePanels=true,restoreWorkspaceOnReload=true,
    savedWorkspacePositions={MacroFrame={x=30,y=700}},openWorkspacePanels={MacroFrame=true}}}
assert(loadfile('Core/CanvasPanelRegistry.lua'))('Offhand',addon)
local registry=addon.CanvasPanelRegistry
assert(registry.CanLoadPersistentPanel('MacroFrame','Blizzard_MacroUI'))
assert(not registry.CanLoadPersistentPanel('MacroFrame','Blizzard_AuctionUI'))
assert(not registry.CanLoadPersistentPanel('AuctionFrame') and not registry.CanLoadPersistentPanel('UnknownFrame'))
local f=assert(io.open('Core/Canvas.lua','rb')); local source=f:read('*a'); f:close()
local loader=assert(source:match('(function Canvas:RequestPersistentPanelLoad.-)\r?\nfunction Canvas:GetPersistentPanelLoadDiagnostics'))
local restore=assert(source:match('(function Canvas:QueuePersistentPanelRestore.-)\r?\nfunction Canvas:RestorePersistentFrames'))
local timers,queued={},{}
local combat,spanned,loaded=false,true,false
local loads,shows,restores=0,0,0
local e={Offhand=addon,PanelRegistry=registry,Canvas={panelLoadRequests={}},_G=false}
e._G=e; setmetatable(e,{__index=_G})
e.C_Timer={After=function(_,fn) timers[#timers+1]=fn end}
e.CanManagePanelsFromAddon=function() return true end
e.IsPersistentPanelLoadCandidate=function(name) return registry.IsBasePersistentCandidate(name) end
e.IsContextBoundPanel=registry.IsContextBoundPanel
e.ShouldYieldFrameToClassicUIForever=function() return false end
e.ShouldYieldWorldMapToMoveAny=function() return false end
e.IsForeverEditModeFrame=function() return false end
e.IsForeverProfessionsPanel=function() return false end
e.IsPersistentForeverProfessionsPanelName=function() return false end
e.IsSpannedLayoutActive=function() return spanned end
e.InCombatLockdown=function() return combat end
e.GetPanelMarker=function(frame,key) return frame[key] end
e.SetPanelMarker=function(frame,key,value) frame[key]=value end
e.RestoreWorkspacePosition=function() restores=restores+1 end
e.ShowUIPanel=function(frame) frame.shown=true; shows=shows+1 end
e.UIPanelWindows={MacroFrame={area='left'}}
e.Canvas.InitializePanelLoadTracking=function() end
e.Canvas.GetPersistentPanelAddon=function() return 'Blizzard_MacroUI' end
e.Canvas.TryMakeFrameDraggable=function() end
addon.RunOrQueueCombat=function(_,fn) queued[#queued+1]=fn end
registry.IsAddonLoaded=function() return loaded end
registry.LoadAddon=function()
    loads=loads+1; loaded=true
    e.MacroFrame={IsShown=function(self) return self.shown end}
    return true,true
end
for _,text in ipairs({loader,restore}) do local c=assert(loadstring(text)); setfenv(c,e); c() end
local function Flush()
    while #timers>0 do local fn=table.remove(timers,1); fn() end
end
combat=true
assert(e.Canvas:RequestPersistentPanelLoad('MacroFrame'))
assert(e.Canvas:RequestPersistentPanelLoad('MacroFrame') and #queued==1 and loads==0,
    'combat must coalesce and defer the owner load, not only its eventual show')
addon.db.openWorkspacePanels.MacroFrame=nil
combat=false; queued[1](); queued={}
assert(loads==0, 'cancelled open intent must prevent the deferred owner load')
addon.db.openWorkspacePanels.MacroFrame=true
for _,setting in ipairs({'enabled','persistentWorkspacePanels','restoreWorkspaceOnReload','spanned'}) do
    combat=true
    assert(e.Canvas:RequestPersistentPanelLoad('MacroFrame'))
    if setting=='spanned' then spanned=false else addon.db[setting]=false end
    combat=false; queued[1](); queued={}
    assert(loads==0, 'deferred owner load must honor cancelled setting/topology: '..setting)
    if setting=='spanned' then spanned=true else addon.db[setting]=true end
end
assert(e.Canvas:RequestPersistentPanelLoad('MacroFrame'))
assert(e.Canvas:RequestPersistentPanelLoad('MacroFrame') and loads==1, 'duplicate requests must not reload')
Flush(); assert(shows==1 and restores==1)
-- Cancellation is checked after the owner loads, before any delayed open.
e.MacroFrame.shown=false
assert(e.Canvas:QueuePersistentPanelRestore(e.MacroFrame,'MacroFrame'))
addon.db.openWorkspacePanels.MacroFrame=nil
Flush(); assert(shows==1)
addon.db.openWorkspacePanels.MacroFrame=true
assert(e.Canvas:QueuePersistentPanelRestore(e.MacroFrame,'MacroFrame'))
combat=true; Flush(); assert(#queued==1 and shows==1)
combat=false; queued[1](); queued={}; Flush(); assert(shows==2)
e.MacroFrame.shown=false
assert(e.Canvas:QueuePersistentPanelRestore(e.MacroFrame,'MacroFrame'))
spanned=false; Flush(); assert(shows==2)
spanned=true
assert(not e.Canvas:RequestPersistentPanelLoad('AuctionFrame'))
for _,toc in ipairs({11200,16000,20400,30300,50504,120107}) do
    addon.tocVersion=toc
    assert(not registry.CanLoadPersistentPanel('MacroFrame'))
end
addon.tocVersion=20506
addon.isForever=true; assert(registry.CanLoadPersistentPanel('OtherStandalone'))
addon.isForever=false; addon.isRetail=true
assert(registry.CanLoadPersistentPanel('PlayerSpellsFrame') and not registry.CanLoadPersistentPanel('MacroFrame'))
print('PASS: TBC Macro reload allowlist, load settlement, cancellation, combat and client exclusions')
