local addon={tocVersion=20506,db={savedWorkspacePositions={SpellBookFrame={x=40,y=700}}}}
assert(loadfile('Core/CanvasPanelRegistry.lua'))('Offhand',addon)
local registry=addon.CanvasPanelRegistry
assert(registry.RequiresNativePanelRegistration('SpellBookFrame'))
assert(registry.IsBasePersistentCandidate('SpellBookFrame'))
assert(not registry.IsContextBoundPanel('SpellBookFrame'))
for _,toc in ipairs({11200,16000,20400,30300,50504,120107}) do
    addon.tocVersion=toc
    assert(not registry.RequiresNativePanelRegistration('SpellBookFrame'))
end
addon.tocVersion=20506
addon.CanvasCompatibility={HasClassicUIForever=function() return false end}
addon.CanvasBackpackState={IsRoot=function() return false end}
addon.CanvasFrameState={IsEvicting=function() return false end,
    SetEvicting=function() error('secure spellbook must not be synthetically evicted') end}
assert(loadfile('Core/CanvasPanelLifecycle.lua'))('Offhand',addon)
InCombatLockdown=function() return false end
local book={GetName=function() return 'SpellBookFrame' end,IsProtected=function() return true end}
SpellBookFrame=book
local registration={area='left',pushable=0}
UIPanelWindows={SpellBookFrame=registration}
GetUIPanel=function(slot) return slot=='left' and book end
HideUIPanel=function() error('spellbook secure descendant lifecycle must remain native') end
SetUIPanelAttribute=function() error('spellbook registration must remain native') end
local evict,demodalize=addon.CanvasPanelLifecycle.InstallModality({}, {
    IsFrameOnWorkspace=function() return true end,CanManagePanelsFromAddon=function() return true end,
    RegisterSpecialFrame=function() end,UnregisterSpecialFrame=function() end})
for _=1,3 do
    demodalize(book)
    assert(not evict(book))
    -- This is the eligibility condition consumed by Canvas's protected-root
    -- guard. Generic demodalization used to delete this entry and strand restores.
    assert(not (book:IsProtected() and not UIPanelWindows.SpellBookFrame))
    assert(UIPanelWindows.SpellBookFrame==registration and registration.area=='left')
end
assert(loadfile('Core/CanvasCompatibility.lua'))('Offhand',addon)
local compatibility=addon.CanvasCompatibility
book.IsShown=function() return true end
book.IsVisible=function() return true end
book.GetEffectiveAlpha=function() return 1 end
book.GetLeft=function() return nil end
book.GetBottom=function() return nil end
book.GetWidth=function() return 384 end
book.GetHeight=function() return 512 end
book.GetEffectiveScale=function() return 0.698 end
book.GetNumPoints=function() return 0 end
GetUIPanelAttribute=function() error('diagnostics must not invoke panel-manager helpers') end
book.GetAttribute=function(_,key) assert(key=='UIPanelLayout-area'); return 'left' end
local report=compatibility.GetTBCSpellbookDiagnostics()
assert(report:find('shown=true,visible=true,protected=true',1,true))
assert(report:find('rect=nil/nil/384/512',1,true))
assert(report:find('points=0,registered=true,area=left,saved=workspace',1,true))
book.IsShown=function() error('bad getter') end
assert(compatibility.GetTBCSpellbookDiagnostics():find('shown=unresolved',1,true))
InCombatLockdown=function() return true end
assert(compatibility.GetTBCSpellbookDiagnostics()==' | Spellbook=combat-deferred')
addon.tocVersion=120107
assert(compatibility.GetTBCSpellbookDiagnostics()=='')
print('PASS: TBC secure spellbook retains restore eligibility and reports missing geometry')
