local combat, external, writes = false, false, 0
local metrics={isSpanned=true}
local addon={tocVersion=20506,db={enabled=true,independentWorkspacePanels=true,persistentWorkspacePanels=true,
    savedWorkspacePositions={WorldMapFrame={x=20,y=600},SpellBookFrame={x=400,y=600}}},
    Viewport={GetMetrics=function() return metrics end},
    CanvasCompatibility={ShouldYieldWorldMap=function() return external end}}
InCombatLockdown=function() return combat end
local function Make(name,allow)
    local frame={name=name,attrs={}}
    function frame:GetAttribute(key) return self.attrs[key] end
    function frame:IsMaximized() return self.maximized end
    function frame:Show() self.shown=true end
    function frame:Hide() error('slot policy must never synthesize a hide') end
    return frame,{area='left',pushable=0,allowOtherPanels=allow}
end
WorldMapFrame,SpellBookFrame=Make('WorldMapFrame',0),Make('SpellBookFrame')
UIPanelWindows={WorldMapFrame={area='left',pushable=0,allowOtherPanels=0},SpellBookFrame={area='left',pushable=0}}
SetUIPanelAttribute=function(frame,key,value)
    assert(not combat and (key=='pushable' or key=='allowOtherPanels'), 'only native coexistence attributes may change')
    if not frame.attrs['UIPanelLayout-defined'] then
        for k,v in pairs(UIPanelWindows[frame.name]) do frame.attrs['UIPanelLayout-'..k]=v end
        frame.attrs['UIPanelLayout-defined']=true
    end
    frame.attrs['UIPanelLayout-'..key]=value
    writes=writes+1
end
assert(loadfile('Core/CanvasPanelLifecycle.lua'))('Offhand',addon)
local sync=addon.CanvasPanelLifecycle.UpdateTBCWorkspacePanelSlots
local function Read(frame,key) return frame:GetAttribute('UIPanelLayout-'..key) end
-- Native single-left-slot decision, as declared in 2.5.6.70577's manager.
local function CanCoexist(left,incoming)
    local lp,ip=Read(left,'pushable') or 0,Read(incoming,'pushable') or 0
    local la,ia=Read(left,'allowOtherPanels') or 1,Read(incoming,'allowOtherPanels') or 1
    return not (la==0 or ia==0 or (lp==0 and ip==0))
end
sync()
assert(CanCoexist(WorldMapFrame,SpellBookFrame) and CanCoexist(SpellBookFrame,WorldMapFrame),
    'both native opening orders must keep the workspace peer')
assert(Read(WorldMapFrame,'area')=='left' and Read(SpellBookFrame,'area')=='left')
assert(UIPanelWindows.WorldMapFrame.pushable==0 and UIPanelWindows.WorldMapFrame.allowOtherPanels==0,
    'registry defaults must remain native')
local initialWrites=writes
sync(); assert(writes==initialWrites, 'no repeated writes for settled policy')
WorldMapFrame.attrs['UIPanelLayout-pushable']=5
sync()
assert(Read(WorldMapFrame,'pushable')==5 and Read(WorldMapFrame,'allowOtherPanels')==0,
    'active divergence must yield and restore only the attribute still owned')
local yieldedWrites=writes
sync(); assert(writes==yieldedWrites, 'yield must last through the workspace ownership session')
addon.db.enabled=false; sync()
WorldMapFrame.attrs['UIPanelLayout-pushable']=0
addon.db.enabled=true; sync()
initialWrites=writes
combat=true
addon.db.enabled=false
sync(); assert(writes==initialWrites, 'combat must defer restoration')
combat=false
sync()
assert(Read(WorldMapFrame,'allowOtherPanels')==0 and Read(SpellBookFrame,'allowOtherPanels')==nil)
assert(Read(WorldMapFrame,'pushable')==0 and Read(SpellBookFrame,'pushable')==0)
addon.db.enabled=true
sync()
WorldMapFrame.maximized=true
sync(); assert(Read(WorldMapFrame,'allowOtherPanels')==0, 'maximized map must regain native exclusivity')
WorldMapFrame.maximized=false
sync()
addon.db.savedWorkspacePositions.SpellBookFrame=nil
sync(); assert(Read(SpellBookFrame,'pushable')==0, 'Mainhand book must regain native priority')
addon.db.savedWorkspacePositions.SpellBookFrame={x=400,y=600}
sync()
SpellBookFrame.attrs['UIPanelLayout-pushable']=5
addon.db.persistentWorkspacePanels=false
sync(); assert(Read(SpellBookFrame,'pushable')==5, 'cleanup must preserve later external changes')
addon.db.persistentWorkspacePanels=true
external=true
sync(); assert(Read(WorldMapFrame,'allowOtherPanels')==0, 'external map ownership must stay native')
external=false
sync()
metrics.isSpanned=false
sync(); assert(Read(WorldMapFrame,'allowOtherPanels')==0, 'unspan must restore policy')
metrics.isSpanned=true
addon.db.independentWorkspacePanels=false
sync(); assert(Read(WorldMapFrame,'allowOtherPanels')==0)
addon.db.independentWorkspacePanels=true
sync(SpellBookFrame)
assert(Read(SpellBookFrame,'pushable')==5, 'explicit remodalization must restore prior book state')
addon.db.enabled=false
sync()
addon.db.enabled=true
for _,toc in ipairs({11200,16000,20400,30300,50504,120107}) do
    addon.tocVersion=toc
    local before=writes
    sync(); assert(before==writes, 'other clients must stay untouched')
end
print('PASS: TBC workspace map/book coexist in both orders with reversible native slot attributes')
