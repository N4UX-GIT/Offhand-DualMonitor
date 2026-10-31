-- TBC Anniversary 2.5.6.70577 opens/minimizes its map through native panels.
local addon = {tocVersion=20506, db={enabled=true,persistentWorkspacePanels=true}}
assert(loadfile('Core/CanvasPanelRegistry.lua'))('Offhand', addon)
local registry = addon.CanvasPanelRegistry
assert(registry.RequiresNativePanelRegistration('WorldMapFrame'))
assert(not registry.IsContextBoundPanel('WorldMapFrame'))
assert(registry.IsBasePersistentCandidate('WorldMapFrame'))
assert(not registry.RequiresNativePanelRegistration('CharacterFrame'))
for _, toc in ipairs({11200, 16000, 20400, 30300, 50504}) do
    addon.tocVersion = toc
    assert(not registry.RequiresNativePanelRegistration('WorldMapFrame'),
        'TBC exemption must not change other client adapters')
end
addon.tocVersion, addon.isForever = 20506, true
assert(not registry.RequiresNativePanelRegistration('WorldMapFrame'))
addon.isForever = nil

addon.CanvasCompatibility = {HasClassicUIForever=function() return false end}
addon.CanvasBackpackState = {IsRoot=function() return false end}
addon.CanvasFrameState = {
    IsEvicting=function() return false end,
    SetEvicting=function() error('map must not enter synthetic eviction') end,
    SetDragging=function() end,
}
assert(loadfile('Core/CanvasPanelLifecycle.lua'))('Offhand', addon)
InCombatLockdown = function() return false end
local registration = {area='left', pushable=0, maximizePoint='top'}
local map = {GetName=function() return 'WorldMapFrame' end}
WorldMapFrame, UIPanelWindows = map, {WorldMapFrame=registration}
GetUIPanel = function(slot) return slot=='left' and map end
HideUIPanel = function() error('map providers must not be synthetically hidden') end
SetUIPanelAttribute = function() error('native map area must remain intact') end
local evict, demodalize = addon.CanvasPanelLifecycle.InstallModality({}, {
    IsFrameOnWorkspace=function() return true end,
    CanManagePanelsFromAddon=function() return true end,
    RegisterSpecialFrame=function() end, UnregisterSpecialFrame=function() end,
})
for _ = 1, 3 do
    assert(not evict(map))
    demodalize(map)
    assert(UIPanelWindows.WorldMapFrame==registration and registration.area=='left'
        and registration.maximizePoint=='top')
end
print('PASS: TBC Anniversary map retains native panel registration and lifecycle')
