-- Preserve native map registration instead of detaching its provider lifecycle.
local addon={isRetail=true,db={enabled=true,persistentWorkspacePanels=true}}
assert(loadfile('Core/CanvasPanelRegistry.lua'))('Offhand',addon)
addon.CanvasCompatibility={HasClassicUIForever=function() return false end}
addon.CanvasBackpackState={IsRoot=function() return false end}
addon.CanvasFrameState={IsEvicting=function() return false end,
    SetEvicting=function() error('native map must not enter a hide/show eviction') end,
    SetDragging=function() end}
assert(loadfile('Core/CanvasPanelLifecycle.lua'))('Offhand',addon)
InCombatLockdown=function() return false end
local map={GetName=function() return 'WorldMapFrame' end,
    Show=function() error('map visibility must remain native') end,
    Hide=function() error('map providers must not receive a synthetic hide') end}
WorldMapFrame=map
local registration={area='left',pushable=0,maximizePoint='CENTER'}
UIPanelWindows={WorldMapFrame=registration}
GetUIPanel=function(slot) return slot=='left' and map end
HideUIPanel=function() error('native map must not be evicted') end
SetUIPanelAttribute=function() error('native map attributes must be preserved') end
local evict,demodalize=addon.CanvasPanelLifecycle.InstallModality({}, {
    IsFrameOnWorkspace=function() return true end,
    CanManagePanelsFromAddon=function() return true end,
    RegisterSpecialFrame=function() end,UnregisterSpecialFrame=function() end})
assert(not evict(map), 'workspace placement must not cycle map providers')
demodalize(map)
assert(UIPanelWindows.WorldMapFrame==registration and registration.area=='left'
    and registration.maximizePoint=='CENTER', 'native map layout metadata changed')
assert(addon.CanvasPanelRegistry.IsBasePersistentCandidate('WorldMapFrame'),
    'native lifecycle preservation must not discard saved map open intent')
print('PASS: Retail World Map preserves native registration and avoids provider hide/show eviction')
