-- Vendor-shaped roots and a simulated native CloseSpecialWindows transaction.
local combat, gamepad = false, false
UIParent = {}
UISpecialFrames = {}
local loaded = {Leatrix_Maps=true, Leatrix_Plus=true, Leatrix_Sounds=true,
    Platynator=true, ForeverDungeonJournal=true}
C_AddOns = {IsAddOnLoaded=function(name) return loaded[name] end}
InCombatLockdown = function() return combat end
issecretvalue = function(value) return value == 'secret-source' end
local metrics = {isSpanned=true}
local addon = {isForever=true, db={enabled=true},
    Viewport={GetMetrics=function() return metrics end},
    Canvas={IsFrameOnWorkspace=function(frame) return frame.workspace end},
    MainhandCompatibility={IsNativeGamepadInterface=function() return gamepad end}}
local function Root(name, source, fields)
    local f = fields or {}
    f.shown, f.workspace, f.source = true, true, source
    function f:GetParent() return self.parent or UIParent end
    function f:IsForbidden() return self.forbidden end
    function f:IsProtected() return self.protected end
    function f:IsShown() return self.shown end
    function f:GetSourceLocation() return self.source end
    function f:GetFrameStrata() return 'FULLSCREEN_DIALOG' end
    function f:Hide() self.shown=false end
    function f:Show() self.shown=true end
    function f:SetPoint() error('vendor geometry must not be written') end
    function f:SetScript() error('vendor scripts must not be written') end
    function f:HookScript() error('vendor scripts must not be hooked') end
    _G[name]=f; table.insert(UISpecialFrames,name)
    return f
end
local function Has(name)
    for _,n in ipairs(UISpecialFrames) do if n==name then return true end end
    return false
end
local function Escape()
    for _,n in ipairs(UISpecialFrames) do local f=_G[n]; if f then f:Hide() end end
end
local function RandomRoot(name, vendor, fields)
    return Root(name, 'Interface\\AddOns\\'..vendor..'\\'..vendor..'.lua:123', fields)
end
local maps = RandomRoot('F1111111111111111','Leatrix_Maps',{mt={},v={}})
local plus = RandomRoot('F2222222222222222','Leatrix_Plus',{mt={},v={}})
local side = RandomRoot('F3333333333333333','Leatrix_Plus',{c={},r={},b={}})
local sounds = RandomRoot('F4444444444444444','Leatrix_Sounds',{cb={},mainTex={},footTex={}})
local config = Root('OffhandFloatingConfigFrame')
addon.Options={GetConfigFrame=function() return config end}
local platy = Root('PlatynatorCustomiseDialogblizzard',
    '@Interface/AddOns/Platynator/CustomiseDialog/Main.lua:575',{Tabs={},CloseButton={}})
local journal = Root('ForeverDungeonJournalFrame')
local import = Root('PlatynatorCustomiseDialogImportDialog',
    'Interface/AddOns/Platynator/CustomiseDialog/ImportDialog.lua:9')
local confirm = Root('PlatynatorDialog1')
local help = Root('LeaPlusGlobalHelpPanel')
local report = RandomRoot('F5555555555555555','Leatrix_Plus',{})
local spoof = RandomRoot('F6666666666666666','OtherAddon',{mt={},v={}})
local secret = Root('F7777777777777777','secret-source',{mt={},v={}})
local protected = RandomRoot('F8888888888888888','Leatrix_Maps',{mt={},v={},protected=true})
local forbidden = RandomRoot('F9999999999999999','Leatrix_Maps',{mt={},v={},forbidden=true})
local child = RandomRoot('F0000000000000000','Leatrix_Maps',{mt={},v={},parent={}})
local native = Root('EncounterJournal')
local noSource = RandomRoot('Faaaaaaaaaaaaaaaa','Leatrix_Maps',{mt={},v={}})
noSource.GetSourceLocation=false
local throws = RandomRoot('Fbbbbbbbbbbbbbbbb','Leatrix_Maps',{mt={},v={}})
throws.GetSourceLocation=function() error('debug access unavailable') end
local loader=loadfile('Core/CanvasAddonEscape.lua')
if loader then loader('Offhand',addon) end
local adapter=addon.CanvasAddonEscape or {Refresh=function() end}
adapter:Refresh()
assert(not Has('OffhandFloatingConfigFrame'),'Offhand workspace settings must be protected')
for _,name in ipairs({'F1111111111111111','F2222222222222222','F3333333333333333',
    'F4444444444444444','PlatynatorCustomiseDialogblizzard','ForeverDungeonJournalFrame'}) do
    assert(not Has(name),'supported root must be protected: '..name)
end
for _,name in ipairs({'PlatynatorCustomiseDialogImportDialog','PlatynatorDialog1',
    'LeaPlusGlobalHelpPanel','F5555555555555555','F6666666666666666','F7777777777777777',
    'F8888888888888888','F9999999999999999','F0000000000000000','EncounterJournal'}) do
    assert(Has(name),'modal, unrelated or unsafe root must retain native Escape: '..name)
end
assert(Has('Faaaaaaaaaaaaaaaa') and Has('Fbbbbbbbbbbbbbbbb'),
    'missing or inaccessible source metadata must fail closed')
Escape()
assert(config.shown and maps.shown and plus.shown and side.shown and sounds.shown
    and platy.shown and journal.shown,'Escape must retain supported workspace windows')
assert(not import.shown and not confirm.shown and not help.shown and not native.shown,
    'Escape must still dismiss modals and native windows')
local peers={maps,plus,side,sounds,config,platy,journal}
for _,f in ipairs(peers) do f:Hide() end
adapter:Refresh()
assert(Has('OffhandFloatingConfigFrame') and not config.shown,
    'explicit close must remain closed and restore vendor registration')
for _,f in ipairs(peers) do f:Show() end
adapter:Refresh()
assert(not Has('OffhandFloatingConfigFrame'),'manual reopening must reacquire protection')
maps.workspace=false; adapter:Refresh()
assert(Has('F1111111111111111'),'moving to Mainhand must release registration')
maps.workspace=true; adapter:Refresh()
for _,gate in ipairs({'option','disable','unspan','controller','consoleport','transition','client'}) do
    if gate=='option' then addon.db.persistentWorkspacePanels=false
    elseif gate=='disable' then addon.db.enabled=false
    elseif gate=='unspan' then metrics.isSpanned=false
    elseif gate=='controller' then gamepad=true
    elseif gate=='consoleport' then ConsolePort={}
    elseif gate=='transition' then addon._displayGeometryTransitionActive=true
    else addon.isForever=false end
    adapter:Refresh()
    assert(Has('OffhandFloatingConfigFrame') and Has('F1111111111111111'),gate..' must release')
    addon.db.persistentWorkspacePanels=true; addon.db.enabled=true; metrics.isSpanned=true
    gamepad=false; ConsolePort=nil; addon._displayGeometryTransitionActive=false; addon.isForever=true
    adapter:Refresh()
    assert(not Has('OffhandFloatingConfigFrame'),gate..' must allow reacquisition')
end
combat=true; maps.workspace=false; adapter:Refresh()
assert(not Has('F1111111111111111'),'combat must defer mutations')
combat=false; adapter:Refresh()
assert(Has('F1111111111111111'),'post-combat release must settle')
loaded.Leatrix_Maps=false; maps.workspace=true; adapter:Refresh()
assert(Has('F1111111111111111'),'missing vendor must not be acquired')
loaded.Leatrix_Maps=true; adapter:Refresh()
assert(not Has('F1111111111111111'),'late vendor must be discovered')
table.insert(UISpecialFrames,'F1111111111111111'); adapter:Refresh()
assert(not Has('F1111111111111111'),'vendor reinsertion must be filtered idempotently')
addon.db.enabled=false; adapter:Refresh()
local count=0
for _,n in ipairs(UISpecialFrames) do if n=='F1111111111111111' then count=count+1 end end
assert(count==1,'release must not duplicate registrations')
-- A pathological external registry must not turn the periodic adapter into a
-- global discovery scan. Leave previously unseen roots under native ownership.
addon.db.enabled=true
local late=RandomRoot('Fcccccccccccccccc','Leatrix_Maps',{mt={},v={}})
for i=1,300 do table.insert(UISpecialFrames,'Unrelated'..i) end
adapter:Refresh()
assert(Has('Fcccccccccccccccc'),'oversized registry must defer discovery')
UISpecialFrames={}
addon.isForever=false
addon.Viewport.GetMetrics=function() error('inactive adapter must not inspect viewport') end
adapter:Refresh()
addon.isForever=true;addon.db=nil
adapter:Refresh()
print('PASS: Forever addon settings Escape, vendor ownership, modals, release and fail-closed discovery')
