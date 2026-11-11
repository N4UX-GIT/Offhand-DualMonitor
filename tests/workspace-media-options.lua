local function Frame()
    local f={scripts={}}
    function f:SetScript(name,fn)self.scripts[name]=fn end
    function f:SetText(text)self.text=text end
    function f:SetEnabled(value)self.enabled=value end
    function f:CreateFontString()return Frame()end
    return setmetatable(f,{__index=function()return function()end end})
end
local L=setmetatable({WORKSPACE_REGION_NUMBER='Workspace %d',WORKSPACE_PROFILE_ACTIVE='Active: %s',
    WORKSPACE_MISSING_REGION='Missing: %s'},{__index=function(_,key)return key end})
local a={L=L,db={userMediaEnabled=false,userMediaFitMode='FILL'},UIControls={CreateFrame=Frame},
    Viewport={GetMetrics=function()return {workspaceRegions={{id='a'},{id='b'}}}end},
    WorkspaceRouting={GetGroups=function()return {}end},
    UserMedia={GetAssets=function()return {{id='first',name='First image'},{id='second',name='Second image'}}end}}
assert(loadfile('Core/WorkspaceProfiles.lua'))('Offhand',a)
assert(loadfile('UI/Themes.lua'))('Offhand',a)
assert(loadfile('UI/WorkspaceOptions.lua'))('Offhand',a)
local ui=a.WorkspaceOptions.Build({profiles=Frame(),workspace=Frame(),themes=Frame()},Frame,{})
local first,second=ui.regions[1].media,ui.regions[2].media
assert(first.text:find('WORKSPACE_MEDIA_INHERIT',1,true))
first.scripts.OnClick();assert(a.db.workspaceRegionThemes.a.userMediaMode=='THEME')
first.scripts.OnClick();assert(a.db.workspaceRegionThemes.a.userMediaMode=='IMAGE' and not a.db.workspaceRegionThemes.a.userMediaAssetID)
first.scripts.OnClick();assert(a.db.workspaceRegionThemes.a.userMediaAssetID=='first' and first.text:find('First image',1,true))
first.scripts.OnClick();assert(a.db.workspaceRegionThemes.a.userMediaAssetID=='second')
assert(not a.db.workspaceRegionThemes.b and second.text:find('INHERIT',1,true),'Region UI choice leaked')
assert(a.db.userMediaEnabled==false and a.db.userMediaFitMode=='FILL','Region UI changed globals')
a.db.workspaceRegionThemes.a.userMediaAssetID='removed';a.WorkspaceOptions:Refresh()
assert(first.text:find('WORKSPACE_MEDIA_MISSING',1,true),'Missing asset showed a different image name')
a.db.workspaceRegionThemes.a.userMediaAssetID={malformed=true};a.WorkspaceOptions:Refresh()
assert(first.text:find('WORKSPACE_MEDIA_MISSING',1,true),'Malformed saved ID did not fall back safely')
first.scripts.OnClick();assert(not a.db.workspaceRegionThemes.a,'Cycling missing image did not return to inheritance')
print('PASS: region media UI selection, independent choices, missing/malformed saved IDs and global isolation')
