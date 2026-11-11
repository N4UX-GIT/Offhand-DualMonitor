local a={db={enabled=true,workspaceMapScale='AUTO',savedWorkspacePositions={},savedMainPositions={},
    persistentWorkspacePanels=false},Canvas={},CanvasFrameState={IsEvicting=function()return false end}}
InCombatLockdown=function()return false end
GetCVar=function()return '1'end
C_AddOns={IsAddOnLoaded=function()return false end}
UIParent={GetEffectiveScale=function()return 1 end}
assert(loadfile('Core/WorkspaceRegions.lua'))('Offhand',a)
assert(loadfile('Core/WorkspaceScale.lua'))('Offhand',a)
assert(loadfile('Core/CanvasCompatibility.lua'))('Offhand',a)
assert(loadfile('Core/CanvasPanelRegistry.lua'))('Offhand',a)
assert(loadfile('Core/CanvasPersistence.lua'))('Offhand',a)
assert(loadfile('Core/CanvasMapPresentation.lua'))('Offhand',a)
local m={isSpanned=true,workspaceScaleLayout='map-desktop',screenWidth=3000,physicalWidth=3000,
    gameLeft=0,gameRight=1000,gameBottom=0,gameTop=1000,gameWidth=1000,gameHeight=1000,
    primaryWorkspaceRegion='a',workspaceRegions={{id='a',x=1000,y=0,width=1000,height=1000},
        {id='b',x=2000,y=0,width=1000,height=1000}},
    workspaceLeft=1000,workspaceRight=2000,workspaceBottom=0,workspaceTop=1000,workspaceWidth=1000,workspaceHeight=1000}
a.Viewport={GetMetrics=function()return m end}
local map={scale=1,w=600,h=300}
function map:GetName()return 'WorldMapFrame'end
function map:GetWidth()return self.w end;function map:GetHeight()return self.h end
function map:GetScale()return self.scale end;function map:GetEffectiveScale()return self.scale end
function map:SetScale(v)self.scale=v end
function map:IsShown()return true end
function map:SetIgnoreParentScale()end
function map:GetLeft()return 1100/self.scale end;function map:GetTop()return 900/self.scale end
WorldMapFrame=map
local owner=true
function a.Canvas:CanScaleWorkspacePanel()return owner end
function a.Canvas:RestoreWorkspacePosition(f)self:ConfigureWorldMap()end
local services=setmetatable({WithWorkspace=function(x)return x end,IsFrameOnWorkspace=function()return true end},
    {__index=function()return function()return false end end})
a.CanvasMapPresentation.InstallConfiguration(a.Canvas,services)
local S=a.WorkspaceScale
local base=(1000-24)/600
a.Canvas:ConfigureWorldMap();assert(math.abs(map.scale-base)<.0001)
assert(S:SetSetting(m,'a',.5)) -- unsaved, visible workspace map refreshes too
assert(math.abs(map.scale-base*.5)<.0001,'Visible Auto map did not refresh from settings')
assert(S:SetSetting(m,'b',.8));assert(math.abs(map.scale-base*.5)<.0001,'Another region changed this map')
a.db.savedWorkspacePositions.WorldMapFrame={x=2100,y=900,regionId='b'}
a.Canvas:ConfigureWorldMap();assert(math.abs(map.scale-base*.8)<.0001)
assert(S:SetSetting(m,'b',1.5));assert(map.scale*map.w<=976.001,'Auto map enlargement escaped width fit')
map.h=900;assert(S:SetSetting(m,'b',1.4));assert(map.scale*map.h<=976.001,'Auto map escaped height fit')
map.h=300;a.db.workspaceMapScale=1.1
S:Refresh();assert(map.scale==1.1 and not S.maps[map],'Explicit map size was overridden or retained stale ownership')
a.db.workspaceMapScale='AUTO';map.h=300
assert(S:SetSetting(m,'b',.5));assert(S.maps[map])
owner=false;a.db.enabled=false;local old=map.scale;S:RestoreAll();assert(map.scale==old,'Disable wrote over an external map owner')
owner=true;a.db.enabled=true
assert(S:SetSetting(m,'b',.6));a.db.enabled=false;S:RestoreAll()
assert(math.abs(map.scale-base)<.0001,'Disable did not release the Auto map multiplier')
print('PASS: settings refresh routes through the map owner, per-region Auto fitting, explicit sizes and conditional release')
