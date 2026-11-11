-- Layout selection only: no native frame edits or SaveLayouts on transitions.
local combat, editOpen, cinematic, gamepad = false, false, false, false
local signature='geometry'
UnitName=function() return 'Tester' end
local addon={db={enabled=true},Mainhand={},MainhandGeometry={
    IsPlayerCombatRestricted=function() return combat end},MainhandCompatibility={
    IsNativeGamepadInterface=function() return gamepad end,
    IsControllerMode=function() return gamepad end},
    IsCinematicOrMovieActive=function() return cinematic end}
addon.Mainhand.GetGeometrySignature=function() return signature end
local m={isSpanned=true}
addon.Viewport={GetMetrics=function() return m end}
local data,presets,calls,reject,unconfirmed
local name='Offhand - Mainhand - Tester'
local function reset(count)
    combat,editOpen,cinematic,gamepad=false,false,false,false
    addon.isForever,addon.isLegacyWrath=false,false
    addon.db.enabled=true; signature='geometry'; m={isSpanned=true}
    reject,unconfirmed=false,false
    presets={{layoutName='Modern',layoutIndex=0},{layoutName='Classic',layoutIndex=1}}
    if count==3 then presets[3]={layoutName='Internal',layoutIndex=2} end
    data={activeLayout=count+1,layouts={{layoutName=name,systems={{sentinel='generated'}}},
        {layoutName='Other',systems={{sentinel='other'}}}}}
    calls={}
    OffhandCharDB={editModeLayoutName=name,mainhandLayout={version=1,generatedName=name,
        sourceName='Modern',sourceID=1,sourcePreset=true,geometrySignature='geometry'}}
    EditModePresetLayoutManager={GetCopyOfPresetLayouts=function() return presets end}
    EditModeManagerFrame={IsShown=function() return editOpen end}
    C_EditMode={GetLayouts=function() return data end,
        SetActiveLayout=function(id)
            assert(not combat and not editOpen and not cinematic)
            calls[#calls+1]=id
            if reject then return false end
            if not unconfirmed then data.activeLayout=id end
        end,
        SaveLayouts=function() error('transition must never rewrite saved layouts') end}
    assert(loadfile('Core/MainhandEditMode.lua'))('Offhand',addon)
end
local function update(spanned)
    m.isSpanned=spanned
    return addon.Mainhand:UpdateWindowModeLayout(m)
end
for _,count in ipairs({2,3}) do
    reset(count); addon.isRetail=count==3
    local managed,why=update(false)
    assert(managed and why=='restored' and data.activeLayout==1 and #calls==1)
    assert(OffhandCharDB.editModeLayoutName=='Modern' and OffhandCharDB.mainhandWindowedLayout)
    update(false); assert(#calls==1,'idle window mode must not repeat API calls')
    assert(loadfile('Core/MainhandEditMode.lua'))('Offhand',addon) -- /reload keeps the ticket.
    managed,why=update(true)
    assert(managed and why=='resumed' and data.activeLayout==count+1 and #calls==2)
    assert(OffhandCharDB.editModeLayoutName==name and not OffhandCharDB.mainhandWindowedLayout)
    update(true); assert(#calls==2)
    assert(#data.layouts==2 and data.layouts[1].systems[1].sentinel=='generated'
        and data.layouts[2].systems[1].sentinel=='other','layouts must not be mutated')
    update(false); data.activeLayout=count+2
    update(true); assert(data.activeLayout==count+2 and #calls==3
        and not OffhandCharDB.mainhandWindowedLayout,'manual windowed choice must cancel resume')
end
-- Preset enums are not selection IDs. Both presets must round-trip by list position.
for _,count in ipairs({2,3}) do
    reset(count)
    OffhandCharDB.mainhandLayout.sourceName='Classic'
    local _,why=update(false)
    assert(why=='restored' and data.activeLayout==2 and calls[1]==2)
    update(true)
    assert(data.activeLayout==count+1 and calls[2]==count+1)
end
reset(3); combat=true; update(false); assert(#calls==0)
combat=false; update(false); assert(data.activeLayout==1)
combat=true; update(true); assert(data.activeLayout==1 and #calls==1)
combat=false; update(true); assert(data.activeLayout==4)
reset(2); editOpen=true; update(false); assert(#calls==0)
editOpen=false; update(false); assert(data.activeLayout==1)
reset(3); cinematic=true; update(false); assert(#calls==0)
cinematic=false; update(false); assert(data.activeLayout==1)
reset(3); reject=true; update(false)
assert(data.activeLayout==4 and not OffhandCharDB.mainhandWindowedLayout and OffhandCharDB.editModeLayoutName==name)
reset(3); unconfirmed=true; update(false)
assert(not OffhandCharDB.mainhandWindowedLayout,'unconfirmed API result must not commit a transition')
reset(3); update(false); signature='changed'; update(true); assert(data.activeLayout==1 and #calls==1)
reset(3); OffhandCharDB.mainhandLayout.sourceName='Deleted'; update(false); assert(#calls==0)
reset(3); OffhandCharDB.mainhandLayout.generatedName='Offhand - Mainhand - SomeoneElse'
update(false); assert(#calls==0,'another character record must not drive a selection')
reset(3); data.layouts[3]={layoutName='My source'}
OffhandCharDB.mainhandLayout.sourceName='My source'; OffhandCharDB.mainhandLayout.sourcePreset=false
update(false); assert(data.activeLayout==6)
data.layouts[1],data.layouts[2]=data.layouts[2],data.layouts[1]
update(true); assert(data.activeLayout==5,'resolve generated layout by name after custom rows move')
reset(3); update(false); data.layouts[1]=nil
update(true); assert(data.activeLayout==1 and #calls==1,'missing generated layout must not select an unrelated numeric ID')
reset(2); addon.db.enabled=false; update(true); assert(data.activeLayout==1)
addon.db.enabled=true; update(true); assert(data.activeLayout==3)
reset(2); m.isSpanned=false
addon.Mainhand:RememberWindowModeLayoutSelection(name)
update(false); assert(#calls==0,'explicit selection of generated layout while windowed must be respected')
reset(3); update(false); m.isSpanned=false
addon.Mainhand:RememberWindowModeLayoutSelection('Classic'); data.activeLayout=2
update(true); assert(data.activeLayout==2 and #calls==1)
for _,flag in ipairs({'isForever','isLegacyWrath'}) do
    reset(3); addon[flag]=true; update(false); assert(#calls==0)
end
reset(3); gamepad=true; update(false); assert(#calls==0)
reset(3); ConsolePort={}; update(false); assert(#calls==0); ConsolePort=nil
reset(3); presets={}; update(false); assert(#calls==0)
-- Integrate the existing Edit Mode observer: closing without changing layout
-- reconciles a deferred restore; a genuine selection cancels the return ticket.
reset(3)
addon.HUDCompatibility={UsesForeverEditMode=function() return false end}
assert(loadfile('Core/HUDRecovery.lua'))('Offhand',addon)
local observers,queued={},{}
EditModeManagerFrame.HookScript=function(_,event,callback) observers[event]=callback end
EditModeManagerFrame.GetActiveLayoutInfo=function()
    return presets[data.activeLayout] or data.layouts[data.activeLayout-#presets]
end
C_Timer={After=function(_,callback) queued[#queued+1]=callback end}
addon.ApplyFullLayout=function() addon.Mainhand:UpdateWindowModeLayout(m) end
local recovery=addon.HUDRecovery.Install({})
recovery.HookCharacterEditModeSelection()
m.isSpanned=false; editOpen=true; observers.OnShow()
update(false); assert(#calls==0)
editOpen=false; observers.OnHide(); assert(#calls==0)
for _,callback in ipairs(queued) do callback() end
assert(data.activeLayout==1 and OffhandCharDB.mainhandWindowedLayout,
    'closing unchanged Edit Mode must complete the deferred window restore')
queued={}; editOpen=true; observers.OnShow(); data.activeLayout=2
editOpen=false; observers.OnHide()
for _,callback in ipairs(queued) do callback() end
assert(not OffhandCharDB.mainhandWindowedLayout and data.activeLayout==2)
update(true); assert(data.activeLayout==2,'manual choice observed at close must survive re-span')
print('PASS: Retail/Anniversary restore-span layout selection, persistence, ownership, combat and API failures')

reset(2)
name = 'Offhand'
addon.isRetail = false
data.layouts[1].layoutName = name
OffhandCharDB.mainhandLayout.generatedName = name
OffhandCharDB.editModeLayoutName = name
OffhandDB = {sharedMainhandLayouts={[name]={version=1,client='classic',ownershipSignature='',
    geometrySignature='geometry'}}}
-- Current geometry necessarily changes when the native window is restored.
signature = 'single-window'
local sharedManaged, sharedWhy = update(false)
assert(sharedManaged and sharedWhy == 'restored' and data.activeLayout == 1,
    'shared layout ownership must use saved span geometry when restoring the native window')
signature = 'geometry'
update(true)
assert(data.activeLayout == 3 and not OffhandCharDB.mainhandWindowedLayout,
    'the shared account layout must resume by name on the matching span')
print('PASS: shared layout restore/span round trip across geometry changes')
