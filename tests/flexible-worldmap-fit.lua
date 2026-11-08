-- Real configuration/restore paths with synthetic frame geometry. This does
-- not emulate native map providers, protected clicks or client lifecycle.
local cases=0
local function boot(ratio,area,inherited,owner)
 local env=setmetatable({},{__index=_G});env._G=env
 local a={isRetail=true,tocVersion=120105,db={enabled=true,persistentWorkspacePanels=true,
  workspaceMapScale=1.1,mainMapScale=1,savedWorkspacePositions={WorldMapFrame={x=18.287,y=1919.048,canvasLeft=0,canvasBottom=0,canvasWidth=1097.143,canvasHeight=1950.476}},savedMainPositions={}},Canvas={}}
 env.InCombatLockdown=function()return env.combat end
 env.GetCVar=function()return '1'end
 env.C_AddOns={IsAddOnLoaded=function(name)return owner and name==owner or false end}
 env.UIParent={GetEffectiveScale=function()return .8 end}
 local m={isSpanned=true,screenWidth=2560*ratio,physicalWidth=2560,gameLeft=512*ratio,gameRight=2048*ratio,gameBottom=0,gameTop=1440*ratio,gameWidth=1536*ratio,gameHeight=1440*ratio,
  workspaceRegions={{id='workspace-a',x=area[1]*ratio,y=area[2]*ratio,width=area[3]*ratio,height=area[4]*ratio}},primaryWorkspaceRegion='workspace-a'}
 a.Viewport={GetMetrics=function()return m end}
 local function load(path)local f=assert(loadfile(path));setfenv(f,env);f('Offhand',a)end
 load('Core/WorkspaceRegions.lua');load('Core/CanvasCompatibility.lua');load('Core/CanvasPanelRegistry.lua');load('Core/CanvasPersistence.lua');load('Core/CanvasPanelPlacement.lua')
 a.CanvasFrameState={IsEvicting=function()return false end}
 load('Core/CanvasMapPresentation.lua')
 local f={scale=.8,x=200,y=1100,w=1000,h=650,writes=0}
 function f:GetName()return 'WorldMapFrame'end
 function f:GetWidth()return self.w end;function f:GetHeight()return self.h end
 function f:GetScale()return self.scale end
 function f:GetEffectiveScale()return self.scale*.8*inherited end
 function f:SetScale(v)self.scale=v;self.writes=self.writes+1 end
 function f:SetIgnoreParentScale()end
 function f:GetLeft()return self.x end;function f:GetTop()return self.y end
 function f:ClearAllPoints()self.writes=self.writes+1 end
 function f:SetPoint(_,_,_,x,y)self.x=x;self.y=y;self.writes=self.writes+1 end
 function f:SetClampedToScreen()end
 env.WorldMapFrame=f
 local services=setmetatable({WithWorkspace=function(metrics)return metrics end,
  IsWorldMapMaximized=function()return env.maximized end,
  ShouldYieldWorldMapToMoveAny=a.CanvasCompatibility.ShouldYieldWorldMap,
  ShouldYieldFrameToClassicUIForever=a.CanvasCompatibility.ShouldYieldFrameToClassicUIForever,
  IsFrameOnWorkspace=function(frame)return a.WorkspaceRegions:ContainsFrame(m,frame,false)end,
  RestoreWorkspacePosition=function(frame)return a.Canvas:RestoreWorkspacePosition(frame)end},
  {__index=function()return function()return false end end})
 a.Canvas.ShouldDeferSecondaryChatRestore=function()return false end
 a.Canvas.PlaceForSingleScreenRecovery=function()end
 a.CanvasPanelPlacement.InstallMainhand(a.Canvas,services)
 a.Canvas.RestoreWorkspacePosition=a.CanvasPersistence.InstallRestore(a.Canvas,services)
 a.CanvasMapPresentation.InstallConfiguration(a.Canvas,services)
 a.CanvasMapPresentation.InstallBootstrap(a.Canvas,services)
 return a,f,env,m
end
for _,ratio in ipairs({.5,1,1.0238095})do
 for _,area in ipairs({{0,0,512,1440},{0,720,640,720},{2048,0,512,640}})do
  for _,inherited in ipairs({1,1.25})do
   local a,f,env,m=boot(ratio,area,inherited)
   a.Canvas:RestoreWorkspacePosition(f)
   local x,y,w,h=a.WorkspaceRegions:FrameRect(f)
   local r=m.workspaceRegions[1]
   assert(x>=r.x+12-.01 and x+w<=r.x+r.width-12+.01 and y<=r.y+r.height-12+.01 and y-h>=r.y+12-.01,'Map escaped selected region')
   assert(a.db.workspaceMapScale==1.1,'Fitting changed the saved scale preference')
   assert(a.db.savedWorkspaceRegionLegacyPositions.WorldMapFrame.canvasWidth==1097.143,'Legacy position backup was lost')
   local writes=f.writes;env.combat=true;a.Canvas:ConfigureWorldMap();a.Canvas:RestoreWorkspacePosition(f);assert(f.writes==writes,'Combat guard lost')
   env.combat=false;env.maximized=true;a.Canvas:ConfigureWorldMap();a.Canvas:RestoreWorkspacePosition(f);assert(f.writes==writes,'Maximized native map was changed')
   for _,owner in ipairs({'OpenMap','MoveAny','ClassicUIForever','Leatrix_Maps'})do
    local ext,map=boot(ratio,area,inherited,owner);local position=ext.db.savedWorkspacePositions.WorldMapFrame
    ext.Canvas:ConfigureWorldMap();ext.Canvas:RestoreWorkspacePosition(map)
    assert(map.writes==0 and map.scale==.8 and map.x==200 and ext.db.savedWorkspacePositions.WorldMapFrame==position,'External geometry ownership lost: '..owner)
   end
   cases=cases+1
  end
 end
end
print('PASS: '..cases..' centered/stacked/corner World Map fits, inherited scaling, legacy preservation and combat/maximized/external-owner guards')
