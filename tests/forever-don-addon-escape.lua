-- Don addons (Questdon 1.7.0, Leveldon 0.3.4-beta, DonMap 1.3.6): DonCore's
-- Kit.Window adds every window to UISpecialFrames. On the workspace, the quest
-- book and the shared options window stay open on Escape; dialogs, menus and
-- anything not built by DonCore keep closing.
UIParent = {}
UISpecialFrames = {}
local loaded = {Questdon=true, Leveldon=true, DonMap=true}
C_AddOns = {IsAddOnLoaded=function(name) return loaded[name] end}
InCombatLockdown = function() return false end
local metrics = {isSpanned=true}
local addon = {isForever=true, db={enabled=true},
    Viewport={GetMetrics=function() return metrics end},
    Canvas={IsFrameOnWorkspace=function(frame) return frame.workspace end}}
local KIT = 'Interface/AddOns/DonMap/Libs/DonCore/Kit.lua:2254'
local function Root(name, source, fields)
    local f = fields or {}
    f.shown, f.workspace, f.source = true, true, source
    function f:GetParent() return UIParent end
    function f:IsShown() return self.shown end
    function f:GetSourceLocation() return self.source end
    function f:Hide() self.shown=false end
    function f:Show() self.shown=true end
    _G[name]=f; table.insert(UISpecialFrames,name)
    return f
end
local function Window(name, source) return Root(name, source or KIT, {header={}, close={}}) end
local function Has(name)
    for _,n in ipairs(UISpecialFrames) do if n==name then return true end end
    return false
end
local function Escape()
    for _,n in ipairs(UISpecialFrames) do local f=_G[n]; if f then f:Hide() end end
end

local book = Window('QuestdonQuestBook')
local options = Window('DonCoreOptions', 'Interface\\AddOns\\Leveldon\\Libs\\DonCore\\Kit.lua:2254')
local setup = Root('QuestdonSetup', 'Interface/AddOns/DonMap/Libs/DonCore/Kit.lua:3540', {})
local profs = Root('LeveldonProfs', 'Interface/AddOns/DonMap/Libs/DonCore/Kit.lua:3540', {})
local menu = Root('DonKitMenu', KIT, {})
local album = Root('QuestdonAlbumView', 'Interface/AddOns/Questdon/QuestBook.lua:930', {})
local spoof = Window('QuestdonQuestBook2')
assert(loadfile('Core/AddonWindowCatalog.lua'))('Offhand', addon)
assert(loadfile('Core/CanvasAddonEscape.lua'))('Offhand', addon)
dofile('tests/support/core-bridges.lua').Load(addon, {'Bridges/DonCore/Bridge.lua'})
local adapter = addon.CanvasAddonEscape
adapter:Refresh()

assert(not Has('QuestdonQuestBook'), 'the quest book on the workspace must stay open on Escape')
for _, name in ipairs({'QuestdonSetup', 'LeveldonProfs', 'DonKitMenu', 'QuestdonAlbumView', 'QuestdonQuestBook2'}) do
    assert(Has(name), 'dialogs, menus and other windows keep native Escape: '..name)
end
assert(#adapter:GetCloseButtons(book) == 1 and adapter:GetCloseButtons(book)[1] == book.close,
    'the quest book close button is DonCore\'s close button')
Escape()
assert(book.shown, 'Escape must leave the workspace quest book open')
assert(not setup.shown and not profs.shown and not menu.shown and not album.shown,
    'Escape must still close Don dialogs and menus')

-- moved to the game screen: Escape closes it again
book.shown, book.workspace = true, false
adapter:Refresh()
assert(Has('QuestdonQuestBook'), 'a quest book on Mainhand must close with Escape again')

-- the Don addons unloaded: the book is released back to native Escape
loaded.Questdon = nil
book.workspace = true
adapter:Refresh()
assert(Has('QuestdonQuestBook'), 'without Questdon loaded nothing is held')
print('forever-don-addon-escape: ok')
