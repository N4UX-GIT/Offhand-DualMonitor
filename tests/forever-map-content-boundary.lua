-- Native pin acquisition reaches protected mouse-input APIs. These tests verify
-- which operations Offhand initiates, not native taint propagation or safety.
local base=arg[1] or '.'
local combat=false
local pending={}
InCombatLockdown=function() return combat end
C_Timer={After=function(_,fn) pending[#pending+1]=fn end}
UIParent={GetEffectiveScale=function() return 1 end}
local owner
local addon={isForever=true,db={enabled=true,persistentWorkspacePanels=true,
    savedWorkspacePositions={WorldMapFrame={x=20,y=600}}},
    CanvasFrameState={IsEvicting=function() return false end},
    CanvasCompatibility={HasLeatrixMaps=function() return false end,
        GetWorldMapExternalOwner=function() return owner end,
        IsExternallyPositionedWorldMap=function() return false end,
        ShouldYieldWorldMap=function() return owner~=nil end}}
local metrics={isSpanned=true,workspaceLeft=0,workspaceRight=1000,
    workspaceBottom=0,workspaceTop=1000,workspaceWidth=1000,workspaceHeight=1000,
    gameLeft=1000,gameRight=2000,gameBottom=0,gameTop=1000}
addon.Viewport={GetMetrics=function() return metrics end}
local contentCalls=0
local map={}
WorldMapFrame=map
function map:IsShown() return true end
function map:IsForbidden() return false end
function map:GetLeft() return nil end
function map:GetTop() return nil end
function map:GetWidth() return 600 end
function map:GetHeight() return 400 end
function map:GetEffectiveScale() return 1 end
function map:GetMapID() return 1 end
function map:ClearAllPoints() end
function map:SetPoint() end
for _,key in ipairs({'SetMapID','ResetZoom','OnCanvasSizeChanged','RefreshAllDataProviders'}) do
    map[key]=function() contentCalls=contentCalls+1 end
end
MapUtil={GetDisplayableMapForPlayer=function() return 2 end}
local canvas={}
assert(loadfile(base..'/Core/CanvasMapPresentation.lua'))('Offhand',addon)
local presentation=addon.CanvasMapPresentation
presentation.InstallBehavior(canvas,{IsFrameOnWorkspace=function() return true end})
presentation.InstallBootstrap(canvas,{IsWorldMapMaximized=function() return false end,
    WithWorkspace=function(m) return m end})
local function flush()
    local work=pending;pending={}
    for _,fn in ipairs(work) do fn() end
end
if arg[2]~='bootstrap' then
    assert(canvas:RefocusPersistentWorldMap()==false and contentCalls==0,
        'Forever must not initiate protected map content rebuilds through SetMapID/ResetZoom')
    canvas:RequestPersistentWorldMapRefocus()
    assert(#pending==0,'Forever must not schedule addon-driven content refocusing')
end
owner='MoveAny'
assert(canvas:RepairYieldedWorldMapAnchor(map),'geometry-only bootstrap must remain available')
flush()
assert(contentCalls==0,'Forever bootstrap must not run native provider/zoom/canvas refreshes')
-- Other clients retain their existing public refresh path.
addon.isForever=false;owner=nil
assert(canvas:RefocusPersistentWorldMap()==true and contentCalls==2)
owner='MoveAny';contentCalls=0
assert(canvas:RepairYieldedWorldMapAnchor(map));flush()
assert(contentCalls==3,'non-Forever bootstrap content refresh must remain available')
contentCalls=0
assert(canvas:RepairYieldedWorldMapAnchor(map));combat=true;flush()
assert(contentCalls==0,'deferred bootstrap must recheck combat before entering native content')
print('PASS: Forever geometry/content isolation and delayed bootstrap combat boundary')
