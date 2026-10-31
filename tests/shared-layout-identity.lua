-- Actual layout transaction and config identity code, with native storage mocked.
local player, guid = "Tester", "Player-first"
UnitName=function() return player end
UnitGUID=function() return guid end
InCombatLockdown=function() return false end
local addon={isRetail=true,db={enabled=true},Mainhand={},MainhandGeometry={},MainhandCompatibility={
    IsNativeGamepadInterface=function() return false end,IsControllerMode=function() return false end}}
addon.Mainhand.GetRect=function() return {isSpanned=true} end
addon.Mainhand.GetGeometrySignature=function() return "geometry" end
local presets={{layoutName="Modern",systems={}},{layoutName="Classic",systems={}}}
EditModePresetLayoutManager={GetCopyOfPresetLayouts=function() return presets end}
Constants={EditModeConsts={EditModeMaxLayoutsPerType=5}}
local legacy={layoutName="Offhand - Mainhand - Tester",systems={
    {system=1,anchorInfo={point="BOTTOM",relativeTo="UIParent",relativePoint="BOTTOM",offsetX=123,offsetY=456}}}}
local shared={layoutName="Offhand",systems={{system=1,anchorInfo={offsetX=-900}}}}
local data={activeLayout=3,layouts={legacy,shared}}
local saves=0
C_EditMode={GetLayouts=function() return data end,SaveLayouts=function(value) data=value;saves=saves+1 end,
    SetActiveLayout=function(id) data.activeLayout=id end}
OffhandDB={sharedMainhandLayouts={
    Offhand={version=1,client="retail",ownershipSignature="",geometrySignature="geometry",sourceName="Modern"}}}
OffhandCharDB={mainhandLayout={version=1,generatedName=legacy.layoutName,ownerName=player,ownerGUID=guid,
    geometrySignature="geometry",sourceName="Modern",sourceID=1,sourcePreset=true,movedSystems=1}}
assert(loadfile("Core/MainhandEditMode.lua"))("Offhand",addon)
local ok,name=addon.Mainhand:CreateOrUpdateEditModeLayout()
assert(ok and name=="Offhand" and #data.layouts==2 and data.activeLayout==4)
assert(data.layouts[2].systems[1].anchorInfo.offsetX==123 and data.layouts[2].systems[1].anchorInfo.offsetY==456,
    "legacy promotion must preserve exact tuned anchors, not translate twice")
assert(data.layouts[1].layoutName==legacy.layoutName and data.layouts[1].systems[1].anchorInfo.offsetX==123
    and OffhandDB.sharedMainhandLayoutBackups.Offhand.systems[1].anchorInfo.offsetX==-900,
    "promotion must preserve legacy row and previous shared layout")
assert(OffhandCharDB.mainhandLayout.ownerGUID==guid and OffhandCharDB.editModeLayoutName=="Offhand")

-- A polluted registry must never authorize another character's generated row.
legacy.layoutName="Offhand - Mainhand - OtherCharacter"
data.layouts={legacy,data.layouts[2]};data.activeLayout=1
OffhandDB.sharedMainhandLayouts[legacy.layoutName]={version=1,client="retail",ownershipSignature="",
    geometrySignature="geometry",sourceName="Modern",sourcePreset=true,sourceID=1}
player,guid="NewCharacter","Player-second"
OffhandCharDB={}
local before=saves
ok,name=addon.Mainhand:CreateOrUpdateEditModeLayout()
assert(ok and name=="Offhand" and data.activeLayout==4 and saves==before,
    "new characters must adopt the genuine shared row, never a foreign legacy entry")
assert(not addon.Mainhand:IsCharacterEditModeLayoutAllowed(legacy.layoutName))
OffhandDB.sharedMainhandLayouts[legacy.layoutName]=nil
OffhandCharDB={};data.activeLayout=3
ok,name=addon.Mainhand:CreateOrUpdateEditModeLayout()
assert(ok and name=="Offhand" and OffhandCharDB.mainhandLayout.sourceName=="Modern",
    "an unknown active legacy row must not become this character's rollback source")
assert(addon.Mainhand:IsCharacterEditModeLayoutAllowed("Offhand - Mainhand - NewCharacter (2)"))
assert(addon.Mainhand:IsCharacterEditModeLayoutAllowed("My custom layout"))
addon.HUDCompatibility={UsesForeverEditMode=function() return false end}
assert(loadfile("Core/HUDRecovery.lua"))("Offhand",addon)
local recovery=addon.HUDRecovery.Install({})
EditModeManagerFrame={GetActiveLayoutInfo=function() return legacy end}
local remembered=OffhandCharDB.editModeLayoutName
assert(not recovery.RememberCharacterEditModeLayout() and OffhandCharDB.editModeLayoutName==remembered,
    "closing Edit Mode must not remember another character's generated layout")
EditModeManagerFrame=nil
local record=OffhandCharDB.mainhandLayout
record.ownerGUID="Player-deleted"
assert(not addon.Mainhand:GetLayoutStatus().configured,
    "same-name replacement GUID must invalidate prior character HUD state")

assert(loadfile("Core/Config.lua"))("Offhand",addon)
OffhandDB.onboarding={setupComplete=true}
OffhandCharDB={characterGUID="Player-deleted",mainhandLayout=record,
    editModeLayoutName=legacy.layoutName,hudSetupReminderDeclined=true,activeProfile="Kept"}
assert(addon:EnsureCharacterIdentity())
assert(OffhandCharDB.characterGUID==guid and not OffhandCharDB.mainhandLayout
    and not OffhandCharDB.editModeLayoutName and OffhandCharDB.hudSetupReminder
    and not OffhandCharDB.hudSetupReminderDeclined)
assert(OffhandCharDB.previousHUDIdentity.mainhandLayout==record
    and OffhandCharDB.activeProfile=="Kept" and OffhandDB.onboarding.setupComplete,
    "character identity must preserve account setup, profile and old HUD provenance")
OffhandCharDB.hudSetupReminder=nil
assert(not addon:EnsureCharacterIdentity() and not OffhandCharDB.hudSetupReminder,
    "same character reload must not repeat setup")
OffhandCharDB={mainhandLayout={ownerName=player,generatedName="Offhand"},editModeLayoutName=legacy.layoutName}
assert(not addon:EnsureCharacterIdentity() and OffhandCharDB.mainhandLayout and not OffhandCharDB.hudSetupReminder,
    "legacy GUID migration must not invent evidence of character recreation")
assert(OffhandCharDB.editModeLayoutName=="Offhand",
    "identity migration must repair a foreign preference before login layout transitions")
print("PASS: accurate shared promotion, foreign registry rejection, GUID recreation and legacy migration")
