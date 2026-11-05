local addon={tocVersion=20506,db={enabled=true,persistentWorkspacePanels=true,savedWorkspacePositions={}},
    Viewport={GetMetrics=function() return {isSpanned=true} end},
    CanvasCompatibility={ShouldYieldFrameToClassicUIForever=function() return false end,
        HasClassicUIForever=function() return false end},
    CanvasBackpackState={IsForeverContainerName=function() return false end,IsRoot=function() return false end},
    CanvasFrameState={IsEvicting=function() return false end,
        SetEvicting=function() error('NPC must not be synthetically evicted') end},
    HasCustomBagAddon=function() return true end}
assert(loadfile('Core/CanvasPanelRegistry.lua'))('Offhand',addon)
assert(loadfile('Core/CanvasPanelLifecycle.lua'))('Offhand',addon)
local combat,reserved,external=false,false,false
InCombatLockdown=function() return combat end
addon.IsBlizzardInputReserved=function() return reserved end
addon.CanvasCompatibility.ShouldYieldWorldMap=function(frame) return external and frame==WorldMapFrame end
UIPanelWindows={}
UISpecialFrames={}
local function Frame(name,workspace,area)
    local f={name=name,workspace=workspace,shown=true,hides=0,area=area or 'left'}
    function f:GetName() return self.name end
    function f:IsShown() return self.shown end
    function f:IsVisible() return self.shown end
    function f:GetAttribute(key) assert(key=='UIPanelLayout-area'); return self.area end
    function f:Hide() self.shown=false; self.hides=self.hides+1 end
    function f:Show() error('cleanup must never reopen a native panel') end
    function f:IsMaximized() return self.maximized end
    _G[name]=f
    UIPanelWindows[name]={area=f.area}
    return f
end
local slots={}
GetUIPanel=function(slot) return slots[slot] end
HideUIPanel=function(f) if f then f:Hide() end end
SetUIPanelAttribute=function() error('NPC policy must not change native layout') end
local services={IsFrameOnWorkspace=function(f) return f.workspace end,
    CanManagePanelsFromAddon=function() return true end,
    RegisterSpecialFrame=function() end,UnregisterSpecialFrame=function() end}
local canvas={}
local evict,demodalize=addon.CanvasPanelLifecycle.InstallModality(canvas,services)
for _,name in ipairs({'AuctionFrame','PetStableFrame','TaxiFrame','GossipFrame','QuestFrame'}) do
    local f=Frame(name,true)
    slots.left=f
    local registration=UIPanelWindows[name]
    assert(addon.CanvasPanelRegistry.IsContextBoundPanel(name))
    assert(not addon.CanvasPanelRegistry.IsBasePersistentCandidate(name))
    demodalize(f)
    assert(not evict(f) and f.hides==0 and UIPanelWindows[name]==registration)
end
assert(addon.CanvasPanelRegistry.IsBasePersistentCandidate('QuestLogFrame'), 'standalone quest log must retain persistence')
local file=assert(io.open('Core/Canvas.lua','rb')); local source=file:read('*a'); file:close()
local openMethod=assert(source:match('(function Canvas:SetWorkspacePanelOpen.-)\r?\nassert%(Offhand.CanvasMapPresentation'))
local saved=0
local openEnv=setmetatable({Canvas={},Offhand=addon,IsContextBoundPanel=addon.CanvasPanelRegistry.IsContextBoundPanel,
    SaveOpenWorkspacePanels=function() saved=saved+1 end},{__index=_G})
local chunk=assert(loadstring(openMethod)); setfenv(chunk,openEnv); chunk()
addon.db.openWorkspacePanels={AuctionFrame=true}
addon.db.savedWorkspacePositions.AuctionFrame={x=40,y=600}
assert(not openEnv.Canvas:SetWorkspacePanelOpen('AuctionFrame',true))
assert(addon.db.openWorkspacePanels.AuctionFrame==nil and saved==1)
assert(addon.db.savedWorkspacePositions.AuctionFrame.x==40, 'positional records must survive intent cleanup')
local map=Frame('WorldMapFrame',true)
local book=Frame('SpellBookFrame',true)
local npc=Frame('GossipFrame',true)
local special=Frame('AuditSpecialMainhand',false)
slots={left=map,center=book,right=npc}
UISpecialFrames={'AuditSpecialMainhand'}
local nativeCalls,lastArgs=0
CloseWindows=function(ignore,frame,context)
    nativeCalls=nativeCalls+1; lastArgs={ignore,frame,context}
    return 'native'
end
CloseAllWindows=function(ignore,context) return CloseWindows(ignore,nil,context) end
local nativeAll=CloseAllWindows
GetUIPanelAttribute=nil -- This helper is local in the pinned native source.
addon.CanvasPanelLifecycle.InstallClosePolicy(canvas,services)
local filter=CloseWindows
addon.CanvasPanelLifecycle.InstallClosePolicy(canvas,services)
assert(filter==CloseWindows and nativeAll==CloseAllWindows, 'install must be idempotent and retain the native dispatcher')
assert(CloseAllWindows()==true)
assert(map.hides==0 and book.hides==0 and npc.hides==1 and special.hides==1,
    'Escape must preserve standalone peers but close real NPC/special interactions')
assert(UIPanelWindows.WorldMapFrame.area=='left' and UIPanelWindows.SpellBookFrame.area=='left')
assert(CloseWindows()==false and nativeCalls==0, 'no synthetic close when only workspace peers remain')
assert(CloseWindows(true,book,'lossOfControl')=='native')
assert(lastArgs[1]==true and lastArgs[2]==book and lastArgs[3]=='lossOfControl')
assert(CloseWindows(false,book)=='native' and lastArgs[2]==book)
combat=true; assert(CloseWindows()=='native'); combat=false
reserved=true; assert(CloseWindows()=='native'); reserved=false
addon.db.enabled=false; assert(CloseWindows()=='native'); addon.db.enabled=true
addon.db.persistentWorkspacePanels=false; assert(CloseWindows()=='native'); addon.db.persistentWorkspacePanels=true
local center=Frame('AuditCenterMainhand',false,'center')
slots.center=center; slots.right=nil
assert(CloseWindows(true)==false and center.hides==0, 'ignoreCenter must honor cached native center area')
assert(CloseWindows(false)==true and center.hides==1)
slots.center=nil
external=true; assert(CloseWindows()=='native'); external=false
map.maximized=true; assert(CloseWindows()=='native'); map.maximized=false
assert(map.hides==0 and book.hides==0)
print('PASS: TBC NPC ownership and Escape filtering preserve native sessions and exceptions')
