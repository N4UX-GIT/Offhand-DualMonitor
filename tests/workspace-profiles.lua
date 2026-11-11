local addon={db={enabled=true,hudScale=0.7,deckWidthRatio=.36,
    savedWorkspacePositions={WorldMapFrame={x=12,y=900,regionId="a",regionX=.1,regionY=.9}},
    savedMainPositions={},openWorkspacePanels={WorldMapFrame=true},
    workspacePanelRoutes={spells="b"},workspaceRegionThemes={b={theme="OBSIDIAN"}}}}
local combat=false
InCombatLockdown=function()return combat end
assert(loadfile('Core/WorkspaceProfiles.lua'))('Offhand',addon)
local p=addon.WorkspaceProfiles
local list,id=p:List();assert(#list==1 and id=='default')
local original=addon.db.savedWorkspacePositions
assert(p:Create(' Raid '));local _,raid=p:List()
assert(raid~='default' and addon.db.savedWorkspacePositions~=original)
addon.db.savedWorkspacePositions.WorldMapFrame.x=77
addon.db.workspaceRegionThemes.b.theme='PITCH_BLACK'
assert(p:Activate('default'))
assert(addon.db.savedWorkspacePositions.WorldMapFrame.x==12 and addon.db.workspaceRegionThemes.b.theme=='OBSIDIAN')
assert(p:Activate(raid))
assert(addon.db.savedWorkspacePositions.WorldMapFrame.x==77 and addon.db.workspaceRegionThemes.b.theme=='PITCH_BLACK')
assert(addon.db.hudScale==.7 and addon.db.deckWidthRatio==.36,'Workspace selection changed calibration')
assert(not p:Create('Raid') and not p:Create('|cffff0000bad') and not p:Create(string.rep('a',49)))
assert(p:Rename(raid,'Gathering') and p:Save())
combat=true
local before=addon.db.savedWorkspacePositions
assert(not p:Activate('default') and not p:Create('Combat') and not p:Rename(raid,'Combat') and not p:Delete('default'))
assert(addon.db.savedWorkspacePositions==before,'Combat rejection mutated active data')
combat=false
assert(not p:Delete(raid) and not p:Delete('default'))
assert(p:Activate('default') and p:Delete(raid))
assert(p:Create(string.rep('界',48)),'Valid Unicode name was rejected')

local raw={schema=2,workspaceProfileID=string.rep('a',32),workspaceProfileName='Desktop'}
OffhandCompanionTopology=raw
local metrics={topologySchema=2,isSpanned=true}
p:SyncCompanion(metrics)
local _,linked=p:List();assert(linked=='companion_'..raw.workspaceProfileID)
addon.db.savedWorkspacePositions.WorldMapFrame.x=101
assert(p:Create('Manual choice'));local _,manual=p:List()
p:SyncCompanion(metrics);assert(select(2,p:List())==manual,'Repeated bridge synchronization overrode an in-game choice')
-- Simulate addon module recreation with the same saved DB on /reload.
assert(loadfile('Core/WorkspaceProfiles.lua'))('Offhand',addon);p=addon.WorkspaceProfiles
p:SyncCompanion(metrics);assert(select(2,p:List())==manual,'Cold module load overrode the saved manual choice')
raw.workspaceProfileID=string.rep('b',32);raw.workspaceProfileName='Second plan'
p:SyncCompanion(metrics);assert(select(2,p:List())=='companion_'..raw.workspaceProfileID)
raw.workspaceProfileName='Renamed plan';p:SyncCompanion(metrics)
assert(addon.db.workspaceProfiles.items['companion_'..raw.workspaceProfileID].name=='Renamed plan')
raw.workspaceProfileID=string.rep('c',32);p:SyncCompanion({topologySchema=2,isSpanned=false})
assert(select(2,p:List())~='companion_'..raw.workspaceProfileID,'Disconnected geometry switched a layout')
local store=addon.db.workspaceProfiles
assert(p:Activate('default'))
addon.db.userMediaEnabled=true;addon.db.userMediaFitMode='FIT'
assert(p:Create('Background desk'));local _,mediaID=p:List()
addon.db.userMediaEnabled=false;addon.db.userMediaFitMode='STRETCH'
assert(p:Activate('default'))
assert(addon.db.userMediaEnabled and addon.db.userMediaFitMode=='FIT','Workspace lost global image preferences')
assert(p:Activate(mediaID))
assert(addon.db.userMediaEnabled==false and addon.db.userMediaFitMode=='STRETCH','Workspace image preferences leaked')
-- Profiles written before image preferences were included preserve current global choices.
store.items.default.state.mediaSettingsVersion=nil
store.items.default.state.userMediaEnabled=nil;store.items.default.state.userMediaFitMode=nil
assert(p:Activate('default'))
assert(addon.db.userMediaEnabled==false and addon.db.userMediaFitMode=='STRETCH','Legacy profile reset image preferences')
store.items[mediaID].state.mediaSettingsVersion=99
assert(not p:Activate(mediaID) and store.items[mediaID].state.mediaSettingsVersion==99,'Future image state was replaced')
store.items[mediaID].state.mediaSettingsVersion=1
store.version=99
assert(#p:List()==0 and not p:Create('Future') and addon.db.workspaceProfiles==store,'Future profile data was replaced')
store.version=1
local active=store.items[store.active]
active.state.savedWorkspacePositions='malformed'
assert(not p:Activate('default'),'Malformed profile data was accepted')
print('PASS: named workspace isolation, switching, Unicode, combat refusal, bridge identity, reload and malformed/future preservation')
