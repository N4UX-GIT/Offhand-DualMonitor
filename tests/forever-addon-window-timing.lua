-- No ticker is created or advanced in this test. Pass an older source directory
-- as arg[1] to reproduce the delayed-open failures against that snapshot.
local base=arg[1] or '.'
local combat, controller=false,false
UIParent={}; UISpecialFrames={}; SlashCmdList={}
local loaded={Leatrix_Maps=true,Leatrix_Plus=true,Leatrix_Sounds=true,Platynator=true}
C_AddOns={IsAddOnLoaded=function(n) return loaded[n] end}
InCombatLockdown=function() return combat end
hooksecurefunc=function(owner,key,after)
    local before=owner[key]
    owner[key]=function(...) local result=before(...);after(...);return result end
end
local eventCallbacks={}
EventRegistry={RegisterCallback=function(_,key,callback,owner)
    assert(not eventCallbacks[key]);eventCallbacks[key]=function(link) callback(owner,link) end
end}
CreateFrame=function()
    return {RegisterEvent=function() end,SetScript=function() end}
end
local addon={isForever=true,db={enabled=true,hideWorkspaceCloseButtons=true},
    Viewport={GetMetrics=function() return {isSpanned=true} end},
    MainhandCompatibility={IsNativeGamepadInterface=function() return controller end},
    Canvas={IsFrameOnWorkspace=function(f) return f.workspace end}}
local function Has(name)
    for _,n in ipairs(UISpecialFrames) do if n==name then return true end end
    return false
end
local function Escape()
    local copy={unpack(UISpecialFrames)}
    for _,n in ipairs(copy) do if _G[n] then _G[n]:Hide() end end
end
local function Button(parent,source,x)
    local b={alpha=.8,mouse=true,parent=parent,source=source,hookWrites=0}
    function b:GetAlpha() return self.alpha end
    function b:SetAlpha(v) self.alpha=v end
    function b:IsMouseEnabled() return self.mouse end
    function b:EnableMouse(v) self.mouse=v end
    function b:IsForbidden() return self.forbidden end
    function b:IsProtected() return self.protected end
    function b:GetParent() return self.parent end
    function b:GetSourceLocation() return self.source end
    function b:GetObjectType() return 'Button' end
    -- Actual Forever 70862 reading after SetSize(30,30), at this UI scale.
    function b:GetWidth() return self.width or 30.000032424927 end
    function b:GetHeight() return 30.000032424927 end
    function b:GetPoint() return 'TOPRIGHT',self.parent,'TOPRIGHT',x or 0,0 end
    function b:HookScript() self.hookWrites=self.hookWrites+1;error('must not hook buttons') end
    return b
end
local function Root(name,vendor,shape,source)
    local f=shape or {};f.name=name;f.shown=false;f.workspace=true;f.hooks={};f.children={}
    f.source=source or ('Interface/AddOns/'..vendor..'/'..vendor..'.lua:100')
    function f:GetParent() return UIParent end
    function f:IsForbidden() return self.forbidden end
    function f:IsProtected() return self.protected end
    function f:IsShown() return self.shown end
    function f:IsVisible() return self.shown end
    function f:GetSourceLocation() return self.source end
    function f:GetFrameStrata() return 'FULLSCREEN_DIALOG' end
    function f:GetNumChildren() return #self.children end
    function f:GetChildren() return unpack(self.children) end
    function f:HookScript(key,fn)
        assert(not self.protected and not self.forbidden)
        self.hooks[key]=self.hooks[key] or {};table.insert(self.hooks[key],fn)
    end
    function f:Fire(key) for _,fn in ipairs(self.hooks[key] or {}) do fn(self) end end
    function f:Show() self.shown=true;self:Fire('OnShow') end
    function f:Hide() self.shown=false;self:Fire('OnHide') end
    function f:Drag(workspace) self.workspace=workspace;self:Fire('OnDragStop') end
    function f:SetPoint() error('must not move vendor roots') end
    _G[name]=f;table.insert(UISpecialFrames,name)
    return f
end
local maps=Root('F1111111111111111','Leatrix_Maps',{mt={},v={}})
local x=Button(maps,maps.source);local unrelated=Button(maps,maps.source,-40)
local wrongSize=Button(maps,maps.source);wrongSize.width=29
maps.children={unrelated,wrongSize,x}
local unsafe=Root('F2222222222222222','Leatrix_Maps',{mt={},v={},protected=true})
local originalReturns=0
SlashCmdList.Leatrix_Maps=function() maps:Show();originalReturns=originalReturns+1;return 'vendor-result' end
local platy
local function OpenPlaty()
    if not platy then
        platy=Root('PlatynatorCustomiseDialogblizzard','Platynator',{Tabs={}},
            'Interface/AddOns/Platynator/CustomiseDialog/Main.lua:575')
        platy.CloseButton=Button(platy,platy.source)
    end
    platy:Show();return 'lazy-return'
end
SlashCmdList.Platynator=OpenPlaty
Platynator_AddonCompartmentCallback=OpenPlaty
assert(loadfile(base..'/Core/CanvasAddonEscape.lua'))('Offhand',addon)
assert(loadfile(base..'/Core/WorkspaceChrome.lua'))('Offhand',addon)
local adapter=addon.CanvasAddonEscape
adapter:Refresh() -- hidden roots and public lazy openers are observed at startup
assert(SlashCmdList.Leatrix_Maps()=='vendor-result' and originalReturns==1)
assert(not Has(maps.name),'Escape protection must apply before the opener returns, with no timer')
assert(x.alpha==0 and not x.mouse,'anonymous Leatrix X must hide before first rendering')
assert(unrelated.alpha==.8 and unrelated.mouse,'nearby ordinary controls must remain available')
assert(wrongSize.alpha==.8 and wrongSize.mouse,'a different size control must remain available')
Escape();assert(maps.shown,'immediate native Escape must retain the workspace root')
maps:Drag(false)
assert(Has(maps.name) and x.alpha==.8 and x.mouse,'Mainhand drag must synchronously release both policies')
maps:Drag(true)
assert(not Has(maps.name) and x.alpha==0,'workspace drag must reacquire before Escape')
maps:Hide();assert(not maps.shown and Has(maps.name) and x.alpha==.8,'explicit close must stay closed')
maps:Show();assert(not Has(maps.name) and x.alpha==0,'direct root reopen must not wait for polling')
assert(SlashCmdList.Platynator()=='lazy-return')
assert(not Has(platy.name) and platy.CloseButton.alpha==0,'lazy first Platynator open must protect Escape and X')
Escape();assert(platy.shown,'same-stack Escape must keep lazy settings open')
platy:Hide();Platynator_AddonCompartmentCallback()
assert(not Has(platy.name) and platy.CloseButton.alpha==0,'compartment opening must be synchronous')
platy:Hide();platy=nil;OpenPlaty() -- vendor's link callback creates a replacement root first
eventCallbacks.SetItemRef('addon:platynatorsettings')
assert(not Has(platy.name) and platy.CloseButton.alpha==0,'settings-link discovery must cover first/replacement roots')
local modal=Root('PlatynatorCustomiseDialogImportDialog','Platynator',{},
    'Interface/AddOns/Platynator/CustomiseDialog/ImportDialog.lua:9')
modal:Show();Escape()
assert(not modal.shown and platy.shown and next(modal.hooks)==nil,'modals must retain native dismissal')
for i=1,10 do adapter:Refresh() end
assert(#maps.hooks.OnShow==1 and #maps.hooks.OnHide==1 and #maps.hooks.OnDragStop==1,
    'repeated refreshes must not multiply vendor root observers')
assert(next(unsafe.hooks)==nil and x.hookWrites==0 and platy.CloseButton.hookWrites==0,
    'protected roots and close-button scripts must not be hooked')
addon.db.persistentWorkspacePanels=false;adapter:Refresh();maps:Hide();maps:Show()
assert(Has(maps.name) and x.alpha==0,'X hiding must work independently from Escape preference')
addon.db.hideWorkspaceCloseButtons=false;adapter:Refresh()
assert(x.alpha==.8 and x.mouse and platy.CloseButton.alpha==.8,'opt-out must restore original button states')
addon.db.persistentWorkspacePanels=true
maps:Drag(true);assert(not Has(maps.name))
combat=true;maps:Drag(false);assert(not Has(maps.name),'combat defers mutation')
combat=false;adapter:Refresh();assert(Has(maps.name))
controller=true;adapter:Refresh();assert(Has(platy.name),'controller ownership releases Escape')
controller=false;addon.db.hideWorkspaceCloseButtons=true
local kerzo=Root('KerzosQuestLog','Kerzo')
kerzo.CloseButton=Button(kerzo,kerzo.source)
function kerzo:ActualizarEstadoEscapeModal()
    for i=#UISpecialFrames,1,-1 do if UISpecialFrames[i]==self.name then table.remove(UISpecialFrames,i) end end
    if self.shown then table.insert(UISpecialFrames,self.name) end
end
function kerzo:MemorizarPosicion() end
function kerzo:CalibrarCabeceraYCierre() self.CloseButton:SetAlpha(1);self.CloseButton:EnableMouse(true) end
assert(loadfile(base..'/Core/CanvasKerzoQuestLog.lua'))('Offhand',addon)
addon.CanvasKerzoQuestLog:Refresh()
kerzo:Show();kerzo:CalibrarCabeceraYCierre();kerzo:ActualizarEstadoEscapeModal()
assert(kerzo.CloseButton.alpha==0 and not kerzo.CloseButton.mouse and not Has(kerzo.name),
    'Kerzo open/calibration transactions must hide X before any timer or render')
kerzo:CalibrarCabeceraYCierre()
assert(kerzo.CloseButton.alpha==0,'vendor header redraw must not flash the hidden X')
kerzo.workspace=false;kerzo:MemorizarPosicion()
assert(kerzo.CloseButton.alpha==1 and kerzo.CloseButton.mouse and Has(kerzo.name),
    'Kerzo Mainhand movement must immediately restore X and Escape')
print('PASS: zero-timer addon Escape/chrome, lazy opening, dragging, modal/explicit close and observer ownership')
