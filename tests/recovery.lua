local addon = {db={enabled=true,savedWorkspacePositions={},savedMainPositions={},openWorkspacePanels={}},
    UIControls={CreateFrame=function() end}, isRetail=true}
local combat = false
InCombatLockdown = function() return combat end
UIParent = {GetEffectiveScale=function() return .5 end}
local metrics = {isSpanned=true,gameLeft=1000,gameRight=2000,gameBottom=0,gameTop=800,
    workspaceLeft=0,workspaceRight=1000,workspaceBottom=0,workspaceTop=1200}
addon.Viewport = {GetMetrics=function() return metrics end}
assert(loadfile('Core/Recovery.lua'))('Offhand',addon)
assert(loadfile('Core/CanvasPanelRegistry.lua'))('Offhand',addon)
local function frame(name,x,y,w,h,shown)
    return {name=name,x=x,y=y,w=w or 100,h=h or 100,shown=shown~=false,
        GetName=function(self) return self.name end,
        GetEffectiveScale=function() return .5 end,
        IsShown=function(self) return self.shown end,
        IsVisible=function(self) return self.shown end,
        GetEffectiveAlpha=function() return 1 end,
        GetLeft=function(self) return self.x end,
        GetBottom=function(self) return self.y end,
        GetTop=function(self) return self.y and self.y+self.h end,
        GetWidth=function(self) return self.w end,GetHeight=function(self) return self.h end,
        SetClampedToScreen=function() end, ClearAllPoints=function() end,
        SetPoint=function(self,_,_,_,x,y) self.x=x; self.y=y-self.h end}
end
local inspect = addon.Recovery.Inspect
assert(inspect(frame('partial',995,50),metrics)=='visible','partial overlap must stay put')
assert(inspect(frame('workspace',20,1000),metrics)=='visible')
assert(inspect(frame('void',1100,900),metrics)=='missing')
assert(inspect(frame('unresolved',nil,nil),metrics)=='missing')
assert(inspect(frame('dormant',10,10,100,100,false),metrics)=='hidden')
local forbidden = {IsForbidden=function() return true end,IsShown=function() error('forbidden inspected') end}
assert(inspect(forbidden,metrics)=='forbidden')
local canvas = {}
addon.Canvas = canvas
assert(loadfile('Core/CanvasPanelPlacement.lua'))('Offhand',addon)
local function no() return false end
addon.CanvasPanelPlacement.InstallMainhand(canvas,{
    ShouldYieldFrameToClassicUIForever=no,ShouldYieldWorldMapToMoveAny=no,IsForeverProfessionsPanel=no,
    IsForeverEditModeFrame=function(f) return f.hud end,IsWorldMapMaximized=no,WithWorkspace=function(m) return m end,
    IsForeverSocialPositionRoot=no,IsUnsafeForPanelMutation=function(f) return f.protected end,RegisterSpecialFrame=function() end,
    SaveOpenWorkspacePanels=function() end,SaveForeverPanelOwnership=function() end,
    IsBackpackRoot=no,ClearOtherBackpackRootState=function() end,IsFrameOnWorkspace=function(f) return f.x and f.x<1000 end,
    GetNonMovablePanels=function() return {} end,
})
VisiblePanel=frame('VisiblePanel',100,100)
MissingPanel=frame('MissingPanel',1100,900)
BookPanel=frame('BookPanel',100,100,100,100,false)
MerchantFrame=frame('MerchantFrame',100,100,100,100,false)
UIPanelWindows={VisiblePanel={},MissingPanel={},BookPanel={},MerchantFrame={}}
for name in pairs(UIPanelWindows) do
    addon.db.savedWorkspacePositions[name]={x=100,y=200}
    addon.db.openWorkspacePanels[name]=true
end
ShowUIPanel=function(f) f.shown=true end
GetUIPanel=function() return nil end
local ok,_,moved=canvas:GatherSafeUIToMainhand(true)
assert(ok and moved==2 and VisiblePanel.x==100,'missing-only gather moved a visible panel')
assert(MissingPanel.x>=1000 and BookPanel.shown and BookPanel.x>=1000)
assert(not MerchantFrame.shown,'recovery must not show a dead NPC interaction')
assert(addon.db.savedWorkspacePositions.VisiblePanel,'visible workspace ownership was retired')
BookPanel.shown=false
addon.db.savedWorkspacePositions.BookPanel={x=100,y=200}
addon.db.openWorkspacePanels.BookPanel=true
GetUIPanel=function() return VisiblePanel end
canvas:GatherSafeUIToMainhand(true)
assert(not BookPanel.shown,'hidden panel reopened into an occupied native slot')

PVEFrame=frame('PVEFrame',200,100)
GroupFinderFrame=frame('GroupFinderFrame',200,100)
GroupFinderFrame.GetParent=function() return PVEFrame end
GroupFinderFrame.SetPoint=function() error('gather moved a native Group Finder child') end
UIPanelWindows.PVEFrame={};UIPanelWindows.GroupFinderFrame={}
addon.db.savedWorkspacePositions.GroupFinderFrame={x=200,y=200}
local writes, point = 0,PVEFrame.SetPoint
PVEFrame.SetPoint=function(self,...) writes=writes+1;point(self,...) end
local untracked=frame('UntrackedMenu',300,100)
UntrackedMenu=untracked
local unsupported=frame('UnsupportedProtected',400,100);unsupported.protected=true
unsupported.IsProtected=function() return true end
local hudRoot=frame('NativeHUD',500,100);hudRoot.hud=true
for _, f in ipairs({untracked,unsupported,hudRoot}) do f.IsMovable=function() return true end end
UIParent.GetChildren=function() return untracked,unsupported,hudRoot end
local gathered,_,_,skipped=canvas:GatherSafeUIToMainhand()
assert(gathered and writes==1,'gather must deduplicate Group Finder content to one outer root')
assert(untracked.x>=1000,'broad gather missed an untracked movable top-level window')
assert(unsupported.x==400 and hudRoot.x==500 and skipped>=2,'unsupported roots must stay put and be counted')
local reasons=table.concat(canvas.lastGatherReport,',')
assert(reasons:find('UnsupportedProtected=protected-unregistered',1,true)
    and reasons:find('NativeHUD=native-HUD-or-EditMode',1,true),'gather must report the actual exclusion reasons')
UIParent.GetChildren=nil

-- Hidden Extra Abilities is actionable only while the native action exists;
-- visible or dormant HUD systems never become layout-repair requests.
Enum={EditModeSystem={ExtraAbilities=7,Minimap=8}}
ExtraAbilityContainer=frame('ExtraAbilityContainer',1200,40,250,120,false)
MinimapCluster=frame('MinimapCluster',900,700) -- visible on both displays
local available=true
C_ActionBar={HasExtraActionBar=function() return available end}
local requests
addon.Mainhand={CreateOrUpdateEditModeLayout=function(_,options)
    requests=options.repairSystems; return true,'Test layout',#requests,'active'
end}
ok=addon.Recovery:Run()
assert(ok and #requests==1 and requests[1].system==7,'missing HUD repair included a visible system')
assert(requests[1].anchorInfo.offsetX>1000 and requests[1].anchorInfo.offsetX<2000)
requests=nil;available=false
assert(addon.Recovery:Run() and requests==nil,'inactive ability was treated as missing')
ExtraAbilityContainer.shown=true;ExtraAbilityContainer.x=1100
available=true
assert(addon.Recovery:Run() and requests==nil,'visible ability must remain where the player placed it')
combat=true
local success,why=addon.Recovery:Run()
assert(not success and why=='combat')
combat=false

-- Confirmation is inert until acceptance, cancellable by doing nothing, and
-- a second acceptance cannot run the same layout-changing action twice.
StaticPopupDialogs={};ACCEPT='Accept';CANCEL='Cancel'
local popupData
addon.ShowPopup=function(_,key,_,_,data) popupData=data end
assert(loadfile('UI/OptionsActions.lua'))('Offhand',addon)
local calls=0
addon.OptionsActions.ConfirmRecovery('warning',function() calls=calls+1 end)
assert(calls==0 and StaticPopupDialogs.OFFHAND_CONFIRM_RECOVERY.button2=='Cancel')
StaticPopupDialogs.OFFHAND_CONFIRM_RECOVERY.OnAccept(nil,popupData)
StaticPopupDialogs.OFFHAND_CONFIRM_RECOVERY.OnAccept(nil,popupData)
assert(calls==1,'confirmation did not gate the recovery action exactly once')
print('PASS: missing-only recovery preserves visible UI, respects native visibility, and confirms before mutations')
