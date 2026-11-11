local addon={db={enabled=true,savedWorkspacePositions={},savedMainPositions={},workspacePanelRoutes={}}}
local combat=false
InCombatLockdown=function()return combat end
UIParent={GetEffectiveScale=function()return 1 end}
assert(loadfile('Core/WorkspaceRegions.lua'))('Offhand',addon)
assert(loadfile('Core/WorkspaceRouting.lua'))('Offhand',addon)
local m={isSpanned=true,gameLeft=1000,gameRight=3000,gameBottom=0,gameTop=1400,
    workspaceRegions={{id='a',x=0,y=0,width=800,height=1400},{id='b',x=3000,y=0,width=700,height=1200}},primaryWorkspaceRegion='a'}
local r=addon.WorkspaceRouting
local frame={GetName=function()return 'WorldMapFrame' end}
assert(r:SetRule('map','b') and r:HasRule('WorldMapFrame',m))
r:Resolve(frame,m)
local pos=addon.db.savedWorkspacePositions.WorldMapFrame
assert(pos.regionId=='b' and pos.autoRoute=='map' and pos.x==3012)
r:Resolve(frame,m);assert(addon.db.savedWorkspacePositions.WorldMapFrame==pos,'Repeated show replaced saved normalized geometry')
local missing={isSpanned=true,workspaceRegions={m.workspaceRegions[1]},primaryWorkspaceRegion='a'}
r:Resolve(frame,missing);assert(addon.db.savedWorkspacePositions.WorldMapFrame==pos,'Missing monitor erased destination intent')
assert(r:SetRule('map','a'));r:Resolve(frame,m)
assert(addon.db.savedWorkspacePositions.WorldMapFrame.regionId=='a')
-- Real drag records have no autoRoute marker and take priority over rules.
local manual={x=500,y=800,regionId='a'}
addon.db.savedWorkspacePositions.WorldMapFrame=manual
assert(r:SetRule('map','b'));r:Resolve(frame,m)
assert(addon.db.savedWorkspacePositions.WorldMapFrame==manual,'Rule edit overwrote a manual move')
assert(r:ResetManual('map'));r:Resolve(frame,m)
assert(addon.db.savedWorkspacePositions.WorldMapFrame.regionId=='b')
assert(r:SetRule('map','MAINHAND'));assert(r:Resolve(frame,m)=='MAINHAND')
assert(not addon.db.savedWorkspacePositions.WorldMapFrame and addon.db.savedMainPositions.WorldMapFrame.autoRoute=='map')
assert(r:SetRule('map',nil));assert(r:Resolve(frame,m)=='MAINHAND')
assert(not addon.db.savedMainPositions.WorldMapFrame)
assert(r:SetRule('map','b'));combat=true
r:Resolve(frame,m);assert(not addon.db.savedWorkspacePositions.WorldMapFrame and not r:SetRule('map','a'))
combat=false
r:Resolve(frame,{isSpanned=true});assert(not addon.db.savedWorkspacePositions.WorldMapFrame,'Legacy layout routed a custom region')
r:Resolve({GetName=function()return 'MerchantFrame' end},m)
assert(not addon.db.savedWorkspacePositions.MerchantFrame,'Interaction panel was routed')
assert(not r:SetRule('map','bad|id') and not r:SetRule('unknown','a'))
print('PASS: routing destinations, missing-region intent, manual priority, reset, Mainhand, combat, legacy and interaction exclusion')
