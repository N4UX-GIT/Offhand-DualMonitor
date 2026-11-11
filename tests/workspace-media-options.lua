local function Frame()
    local f={scripts={}}
    function f:SetScript(name,fn)self.scripts[name]=fn end
    function f:SetText(text)self.text=text end
    function f:SetEnabled(value)self.enabled=value end
    function f:SetHeight(value)self.height=value end
    function f:GetHeight()return self.height end
    function f:Show()self.shown=true end
    function f:Hide()self.shown=false end
    function f:CreateFontString()return Frame()end
    function f:CreateTexture()return Frame()end
    return setmetatable(f,{__index=function()return function()end end})
end
local L=setmetatable({WORKSPACE_REGION_NUMBER='Workspace %d',WORKSPACE_PROFILE_ACTIVE='Active: %s',
    WORKSPACE_MISSING_REGION='Missing: %s'},{__index=function(_,key)return key end})
local regions={{id='a'},{id='b'}}
local a={L=L,db={userMediaEnabled=false,userMediaFitMode='FILL'},
    Viewport={GetMetrics=function()return {workspaceRegions=regions}end},
    WorkspaceRouting={GetGroups=function()return {}end},
    UserMedia={GetAssets=function()return {{id='first',name='First image'},{id='second',name='Second image'}}end}}
assert(loadfile('Core/WorkspaceProfiles.lua'))('Offhand',a)
assert(loadfile('UI/Themes.lua'))('Offhand',a)
assert(loadfile('UI/Controls.lua'))('Offhand',a)
a.UIControls.CreateFrame=Frame
assert(loadfile('UI/WorkspaceOptions.lua'))('Offhand',a)
local tabs={panels=Frame(),appearance=Frame(),profiles=Frame()}
local ui=a.WorkspaceOptions.Build(tabs,Frame,{})
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
local expandedHeight=ui.themes:GetHeight()
local resizeCalls=0
ui.themes.onSizingChanged=function()resizeCalls=resizeCalls+1 end
regions={{id='a'}}
a.WorkspaceOptions:Refresh()
local singleHeight=ui.themes:GetHeight()
assert(first.shown and not second.shown and singleHeight<expandedHeight)
regions={}
a.WorkspaceOptions:Refresh()
assert(not first.shown and not second.shown and ui.themes:GetHeight()<singleHeight)
a.WorkspaceOptions:Refresh()
assert(resizeCalls==2,'An unchanged theme height must not restack the workspace page')
regions={{id='a'},{id='b'}}
a.WorkspaceOptions:Refresh()
assert(first.shown and second.shown and ui.themes:GetHeight()==expandedHeight)
print('PASS: region media UI selection, independent choices, missing/malformed saved IDs and global isolation')

-- Build measures the child before the parent subscribes to resize events.
-- The initial settings card must contain Apply/Discard without waiting for
-- a later wrapped status message to change the child's height.
local sizingControl
a.WorkspaceScaleControls={BuildAdvanced=function()
    sizingControl=Frame();sizingControl:SetHeight(470)
    function sizingControl:Refresh()end
    return sizingControl
end}
local measured=a.WorkspaceOptions.Build(tabs,Frame,{})
assert(measured.sizing:GetHeight()==516,'Initial region sizing card overlaps the next settings card')
sizingControl.onResize(510)
assert(measured.sizing:GetHeight()==556,'Region sizing card did not follow wrapped content')
print('PASS: settings sizing card contains initial and resized controls')
