-- Models the native captured callback and later dynamic cleanup lookup.
-- It cannot simulate the client's taint engine; live acceptance is separate.
local addon={isRetail=true,db={enabled=true,persistentWorkspacePanels=true},
 CanvasCompatibility={ShouldYieldFrameToClassicUIForever=function() return false end},
 CanvasBackpackState={IsForeverContainerName=function() return false end},
 Viewport={GetMetrics=function() return {isSpanned=true} end}}
assert(loadfile('Core/CanvasPanelRegistry.lua'))('Offhand',addon)
assert(loadfile('Core/CanvasPanelLifecycle.lua'))('Offhand',addon)
local combat,casting,reserved=false,false,false
InCombatLockdown=function() return combat end
addon.IsBlizzardInputReserved=function() return reserved end
local function Panel(name,workspace)
 return {name=name,workspace=workspace,shown=true,hides=0,
 GetName=function(self) return self.name end,
 IsShown=function(self) return self.shown end,IsVisible=function(self) return self.shown end,
 Hide=function(self) self.shown=false;self.hides=self.hides+1 end,
 Show=function() error('never reopen a closed native interaction') end}
end
ProfessionsFrame=Panel('ProfessionsFrame',true)
ProfessionsBookFrame=Panel('ProfessionsBookFrame',true)
CharacterFrame=Panel('CharacterFrame',false)
SpecialWorkspace=Panel('SpecialWorkspace',true)
SpecialMainhand=Panel('SpecialMainhand',false)
UIPanelWindows={ProfessionsFrame={area='doublewide'},ProfessionsBookFrame={area='left'},CharacterFrame={area='center'}}
UISpecialFrames={'SpecialWorkspace','SpecialMainhand'}
local slots={doublewide=ProfessionsFrame,left=ProfessionsBookFrame,center=CharacterFrame}
local registration=UIPanelWindows.ProfessionsFrame
GetUIPanel=function(slot) return slots[slot] end
GetUIPanelAttribute=function(frame,key) return UIPanelWindows[frame.name][key] end
HideUIPanel=function(frame) frame:Hide() end
local nativeCloses,menus,castingCalls=0,0,0
CloseWindows=function(ignoreCenter,frameToIgnore,context)
 nativeCloses=nativeCloses+1
 for _,frame in pairs(slots) do if frame.shown then frame:Hide() end end
 return context or true
end
CloseAllBags=function() return false end
CloseAllWindows=function(ignoreCenter,context) return CloseWindows(ignoreCenter,nil,context) end
local capturedNativeClose=CloseAllWindows
RegisterGameMenuEscHandler=function() error('must not mutate the shared native Escape registry') end
CreateFrame=function() error('must not install an Escape registration retry loader') end
SpellStopCasting=function() castingCalls=castingCalls+1;return casting end
securecallfunction=function(fn,...) return fn(...) end
ToggleGameMenu=function()
 if securecallfunction(SpellStopCasting) then return true end
 if securecallfunction(capturedNativeClose) then return true end
 menus=menus+1
end
local nativeToggle,nativeCast,nativeSecure=ToggleGameMenu,SpellStopCasting,securecallfunction
local canvas={}
addon.CanvasPanelLifecycle.InstallClosePolicy(canvas,{IsFrameOnWorkspace=function(frame) return frame.workspace end})
local filter=CloseWindows
addon.CanvasPanelLifecycle.InstallClosePolicy(canvas,{IsFrameOnWorkspace=function(frame) return frame.workspace end})
assert(CloseWindows==filter and canvas.workspaceCloseWindowsInstalled,'idempotent filter installation')
assert(ToggleGameMenu==nativeToggle and SpellStopCasting==nativeCast and securecallfunction==nativeSecure)
ToggleGameMenu()
assert(castingCalls==1 and nativeCloses==0 and menus==0)
assert(ProfessionsFrame.shown and ProfessionsFrame.hides==0 and ProfessionsBookFrame.shown)
assert(SpecialWorkspace.shown and not SpecialMainhand.shown and not CharacterFrame.shown)
assert(UIPanelWindows.ProfessionsFrame==registration and registration.area=='doublewide')
ToggleGameMenu();assert(menus==1 and ProfessionsFrame.hides==0,'native fallback must see no closed windows')
casting=true;ToggleGameMenu();assert(menus==1 and ProfessionsFrame.hides==0,'native casting runs first')
casting=false
assert(CloseWindows(false,nil,'lossOfControl')=='lossOfControl' and not ProfessionsFrame.shown)
ProfessionsFrame.shown=true;combat=true;ToggleGameMenu();assert(not ProfessionsFrame.shown)
combat=false;ProfessionsFrame.shown=true;reserved=true;ToggleGameMenu();assert(not ProfessionsFrame.shown)
reserved=false;ProfessionsFrame.shown=true;addon.db.persistentWorkspacePanels=false
ToggleGameMenu();assert(not ProfessionsFrame.shown)
addon.db.persistentWorkspacePanels=true;ProfessionsFrame.shown=true;ProfessionsFrame.workspace=false
ProfessionsBookFrame.shown=false;ToggleGameMenu();assert(not ProfessionsFrame.shown)
assert(canvas:GetRecoveryPolicyDiagnostics():find('EscapeRoute=panel-cleanup-filter',1,true))
io.write('PASS: captured native Escape uses later cleanup filter; workspace sessions stay open and native exceptions close\n')
