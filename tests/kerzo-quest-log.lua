-- Vendor-shaped Escape registration, with no vendor source execution.
local combat, gamepad, workspace = false, false, true
local hooks, shown, modal = 0, true, false
local addon={isForever=true,db={enabled=true,persistentWorkspacePanels=true},
    Canvas={IsFrameOnWorkspace=function(frame) assert(frame==KerzosQuestLog); return workspace end},
    MainhandCompatibility={IsNativeGamepadInterface=function() return gamepad end},
}
local metrics={isSpanned=true}
addon.Viewport={GetMetrics=function() return metrics end}
UIParent={}
UISpecialFrames={'UnrelatedWindow','KerzosQuestLog','TailWindow'}
InCombatLockdown=function() return combat end
hooksecurefunc=function(owner, method, callback)
    hooks=hooks+1
    local original=owner[method]
    owner[method]=function(...)
        local result=original(...)
        callback(...)
        return result
    end
end
local function Remove(name)
    for i=#UISpecialFrames,1,-1 do
        if UISpecialFrames[i]==name then table.remove(UISpecialFrames,i) end
    end
end
local function Has(name)
    for _,entry in ipairs(UISpecialFrames) do if entry==name then return true end end
    return false
end
KerzosQuestLog={
    GetParent=function() return UIParent end,
    IsShown=function() return shown end,
    IsForbidden=function(self) return self.forbidden end,
    IsProtected=function(self) return self.protected end,
    ActualizarEstadoEscapeModal=function()
        Remove('KerzosQuestLog'); Remove('KQLModalAjustes')
        if modal then table.insert(UISpecialFrames,'KQLModalAjustes')
        elseif shown then table.insert(UISpecialFrames,'KerzosQuestLog') end
        return 'vendor-return'
    end,
    MemorizarPosicion=function() return 'vendor-position' end,
    Show=function(self) shown=true; self:ActualizarEstadoEscapeModal() end,
    Hide=function(self) shown=false; self:ActualizarEstadoEscapeModal() end,
    SetPoint=function() error('adapter must not own vendor anchors') end,
    SetScript=function() error('adapter must not replace vendor input scripts') end,
}
local function PressEscape()
    if Has('KQLModalAjustes') then
        modal=false; KerzosQuestLog:ActualizarEstadoEscapeModal()
    elseif Has('KerzosQuestLog') then KerzosQuestLog:Hide() end
end
PressEscape()
assert(not shown,'baseline: native Escape closes the vendor-registered root')
KerzosQuestLog:Show()
local vendorRoot=KerzosQuestLog
KerzosQuestLog=nil
assert(loadfile('Core/CanvasKerzoQuestLog.lua'))('Offhand',addon)
local adapter=addon.CanvasKerzoQuestLog
assert(not adapter:Refresh() and hooks==0,'late vendor load must not require a root at initialization')
KerzosQuestLog=vendorRoot
local originalRegistry=table.concat(UISpecialFrames,',')
addon.isForever=false
assert(not adapter:Refresh() and hooks==0,'new support is scoped to Forever')
addon.isForever=true
gamepad=true
assert(not adapter:Refresh() and hooks==0 and table.concat(UISpecialFrames,',')==originalRegistry,
    'initial native Gamepad mode must not install hooks or alter Escape')
gamepad=false
KerzosQuestLog.protected=true
assert(not adapter:Refresh() and hooks==0 and table.concat(UISpecialFrames,',')==originalRegistry)
KerzosQuestLog.protected=false
assert(adapter:Refresh() and not Has('KerzosQuestLog') and hooks==2)
PressEscape()
assert(shown,'native Escape must leave the protected workspace root open')
assert(Has('UnrelatedWindow') and Has('TailWindow'),'other addon/native entries must be preserved')
for i=1,10 do adapter:Refresh() end
assert(hooks==2,'repeated Canvas refreshes must not multiply hooks')
assert(KerzosQuestLog:ActualizarEstadoEscapeModal()=='vendor-return' and not Has('KerzosQuestLog'),
    'vendor redraw must not reenroll the workspace root or lose its return value')
modal=true; KerzosQuestLog:ActualizarEstadoEscapeModal()
assert(Has('KQLModalAjustes') and not Has('KerzosQuestLog'),'modal Escape priority must remain vendor-owned')
PressEscape()
assert(not modal and shown,'Escape must close the modal and preserve the quest log')
assert(not Has('KQLModalAjustes') and not Has('KerzosQuestLog'),
    'closing a modal must reapply workspace root protection')
workspace=false
assert(KerzosQuestLog:MemorizarPosicion()=='vendor-position' and Has('KerzosQuestLog'),
    'native drag/save onto Mainhand must immediately restore ordinary Escape')
workspace=true; KerzosQuestLog:MemorizarPosicion()
assert(not Has('KerzosQuestLog'))
KerzosQuestLog:Hide()
adapter:Refresh()
assert(not shown and not Has('KerzosQuestLog'),'explicit X/toggle close must never reopen the quest log')
KerzosQuestLog:Show()
assert(not Has('KerzosQuestLog'),'manual reopen must apply workspace protection')
-- Feature release asks the vendor to choose the correct current modal state.
modal=true; KerzosQuestLog:ActualizarEstadoEscapeModal()
addon.db.persistentWorkspacePanels=false; adapter:Refresh()
assert(Has('KQLModalAjustes') and not Has('KerzosQuestLog'))
modal=false; KerzosQuestLog:ActualizarEstadoEscapeModal()
assert(Has('KerzosQuestLog'))
addon.db.persistentWorkspacePanels=true; adapter:Refresh()
assert(not Has('KerzosQuestLog'))
for _,release in ipairs({'unspan','disable','controller','transition'}) do
    if release=='unspan' then metrics.isSpanned=false
    elseif release=='disable' then addon.db.enabled=false
    elseif release=='controller' then gamepad=true
    else addon._displayGeometryTransitionActive=true end
    adapter:Refresh()
    assert(Has('KerzosQuestLog'),release..' must release the root to Kerzo')
    metrics.isSpanned=true; addon.db.enabled=true; gamepad=false
    addon._displayGeometryTransitionActive=false
    adapter:Refresh()
    assert(not Has('KerzosQuestLog'))
end
combat=true
workspace=false; adapter:Refresh()
assert(not Has('KerzosQuestLog'),'combat must defer release writes')
combat=false; adapter:Refresh()
assert(Has('KerzosQuestLog'))
combat=true; workspace=true; adapter:Refresh()
assert(Has('KerzosQuestLog'),'combat must defer acquisition writes')
combat=false; adapter:Refresh()
assert(not Has('KerzosQuestLog'))
KerzosQuestLog=nil
assert(not adapter:Refresh(),'missing/late vendor must be harmless')
print('PASS: Kerzo workspace Escape, modal priority, explicit close, placement, release, combat and hook ownership')
