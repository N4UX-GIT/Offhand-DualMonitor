local function frame(left,bottom,width,height,scale)
    return {GetEffectiveScale=function() return scale or 1 end,
        GetRect=function() return left,bottom,width,height end}
end
UIParent=frame(0,0,4000,1400)
UIParent.GetWidth=function() return 4000 end
UIParent.GetHeight=function() return 1400 end
Enum={EditModeSystem={ActionBar=0,Minimap=1,UnitFrame=2},EditModeActionBarSystemIndices={MainBar=1},
    EditModeUnitFrameSystemIndices={Player=1,Target=2,Focus=3}}
InCombatLockdown=function() return false end
local context={rect={left=2000,right=4000,bottom=0,top=1400,width=2000,height=1400,screenWidth=4000,screenHeight=1400},
    source={systems={}},generated={systems={}}}
local addon={isForever=true,db={enabled=true},Mainhand={GetEllesmereLayoutSource=function() return context end}}
local apiState,dependency='disabled',false
C_AddOns={GetAddOnInfo=function(name) if apiState~='missing' then return name,name,nil,false,apiState=='incarnation-disabled' and 'DISABLED' or nil end end,
    GetAddOnEnableState=function(name) return (apiState=='disabled' or dependency and name=='EllesmereUI') and 0 or 2 end,
    GetAddOnDependencies=function() if dependency then return 'EllesmereUI' end end,
    IsAddOnLoaded=function() return apiState=='loaded' end}
local elements={}
local specKey='262'
local spec={assignedSpells={keep=123},trackedBuffBars={bars={{group=1},{group=1}}},tbbPositions={['9']={x=99}}}
EllesmereUIDB={spellAssignments={profiles={Default={specProfiles={['262']=spec,['263']={untouched=true}}}}}}
local payload
EllesmereUI={_unlockRegisteredElements=elements,IsUnlockAnchored=function() return false end,
    GetActiveProfileName=function() return 'Default' end,GetActiveProfileData=function() return {} end,
    GetProfileKeys=function() return {} end,EncodePayload=function(p) payload=p;return 'encoded' end,
    ImportProfileInteractive=function() return true end,
    SnapshotAllAddons=function() return {addons={EllesmereUICooldownManager={style='keep'},EllesmereUIResourceBars={castBar={enabled=true}}}} end,
    _ModuleNS={EllesmereUICooldownManager={GetActiveSpecKey=function() return specKey end,
        GetTrackedBuffBars=function() return spec.trackedBuffBars end,TBBBarGroupID=function(cfg) return cfg.group end}}}
assert(loadfile('Core/ForeverEllesmereLayout.lua'))('Offhand',addon)
local transfer=addon.EllesmereLayout
local rows=transfer:Preview('fit')
assert(rows[1].reason=='ELLESMERE_HUD_ENABLE_MODULE' and rows[1].reasonArgs[1]=='EllesmereUIActionBars')
apiState='missing';assert(transfer:Preview('fit')[1].reason=='ELLESMERE_HUD_INSTALL_MODULE')
apiState='enabled';assert(transfer:Preview('fit')[1].reason=='ELLESMERE_HUD_RELOAD_MODULE')
apiState='incarnation-disabled';assert(transfer:Preview('fit')[1].reason=='ELLESMERE_HUD_ENABLE_MODULE',
    'the current loader reason must override another character/incarnation enable scope')
apiState='enabled'
dependency=true;rows=transfer:Preview('fit');assert(rows[1].reasonArgs[1]=='EllesmereUI')
dependency=false;apiState='loaded';assert(transfer:Preview('fit')[1].reason=='ELLESMERE_HUD_CHECK_MODULE')
local function element(key,left,bottom,w,h,scale,hidden)
    elements[key]={label=key,getFrame=function() return frame(left,bottom,w,h,scale) end,isHidden=function() return hidden end}
end
element('CDM_cooldowns',1900,200,200,40,.8)
element('CDM_utility',1950,150,100,40,1)
element('ERB_CastBar',1900,500,240,20,1)
element('TBB_1',1900,100,300,24,1)
element('TBB_2',1900,72,300,24,1,true)
local byKey={}
rows=transfer:Preview('ellesmere')
for _,row in ipairs(rows)do byKey[row.map.key]=row end
assert(byKey.CDM_cooldowns.position and byKey.ERB_CastBar.position and byKey.TBB_1.position)
assert(not byKey.TBB_2,'a grouped child must not get an independent row')
assert(byKey.TBB_1.groupProposed.height==52,'fit the complete tracking group')
assert(byKey.TBB_1.groupProposed.left >= context.rect.left + 8,'new placements need a seam inset')
local selected={byKey.CDM_cooldowns,byKey.ERB_CastBar,byKey.TBB_1}
assert(transfer:OpenImport(selected))
assert(payload.data.partialImport and payload.data.layoutExcluded and payload.data.overridesExcluded)
assert(payload.data.addons.EllesmereUICooldownManager.style=='keep')
assert(payload.data.addons.EllesmereUIResourceBars.castBar.enabled)
assert(payload.data.cdmSpells['262'].assignedSpells.keep==123)
assert(payload.data.cdmSpells['262'].tbbPositions['9'].x==99)
assert(payload.data.cdmSpells['262'].tbbPositions['1'].x==payload.data.cdmSpells['262'].tbbPositions['2'].x)
assert(not spec.tbbPositions['1'] and spec.assignedSpells.keep==123,'active spell store must remain untouched')
specKey='263';assert(not transfer:OpenImport(selected),'reject a stale tracking-bar spec')
element('CDM_cooldowns',2200,200,200,40,1)
for _,row in ipairs(transfer:Preview('ellesmere'))do
    if row.map.key=='CDM_cooldowns' then assert(row.reason=='ELLESMERE_HUD_KEEP' and not row.position,
        'repeating the transfer must preserve an EUI-only bar already inside Mainhand') end
end
local empty=frame(nil,nil,100,40,1)
empty.GetWidth=function() return 100 end;empty.GetHeight=function() return 40 end
empty.GetPoint=function() return 'CENTER',UIParent,'CENTER',0,-200 end
elements.CDM_empty={label='Empty cooldowns',getFrame=function() return empty end}
for _,row in ipairs(transfer:Preview('fit'))do
    if row.map.key=='CDM_empty' then assert(row.current.left==1950 and row.position,
        'empty cooldown movers must resolve their public UIParent anchor') end
end
print('PASS: EUI dependency guidance, CDM/cast coverage, tracking group fit and isolated full-spec import')
