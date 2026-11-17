local addon = { db = { enabled=true, savedWorkspacePositions={} }, Canvas={} }
local queue, tick, onEvent = {}, nil, nil
local combat = false
local inputReserved = false
local targetSelected = false
UnitExists = function(unit) return unit == "target" and targetSelected end
local nativePairs, globalScans = pairs, 0
pairs = function(value)
    if value == _G then globalScans = globalScans + 1 end
    return nativePairs(value)
end
local bagnonLoaded=false
local baganatorLoaded=true
C_AddOns = { IsAddOnLoaded = function(name)
    return (name == "Baganator" and baganatorLoaded) or (name == "Bagnon" and bagnonLoaded)
end }
local baganatorCallbacks = {}
Baganator = { CallbackRegistry = {
    RegisterCallback = function(_, event, callback) baganatorCallbacks[event] = callback end,
} }
InCombatLockdown = function() return combat end
addon.IsBlizzardInputReserved = function() return inputReserved end
C_Timer = {
    After = function(delay, fn) queue[#queue+1] = { delay=delay, fn=fn } end,
    NewTicker = function(_, fn) tick = fn; return {} end,
}
CreateFrame = function() return {
    RegisterEvent=function() end,
    SetScript=function(_, _, fn) onEvent=fn end,
} end
UIParent = { GetEffectiveScale=function() return 0.5 end }
local function flush()
    local count=0
    while #queue>0 do
        count=count+1; assert(count<100, "unbounded restore retry")
        table.sort(queue, function(a,b) return a.delay < b.delay end)
        local item=table.remove(queue,1); item.fn()
    end
end
local name="Baganator_CategoryViewBackpackViewFrameTest"
local bag={shown=false,x=100,y=300,height=100,scripts={}}
function bag:GetName() return name end
function bag:GetParent() return UIParent end
function bag:IsVisible() return self.shown end
function bag:IsShown() return self.shown end
function bag:GetEffectiveScale() return 0.5 end
function bag:GetLeft() return self.x end
function bag:GetTop() return self.y end
function bag:GetBottom() return self.y-self.height end
function bag:GetHeight() return self.height end
function bag:HookScript(s,fn) self.scripts[s]=fn end
function bag:Show() self.shown=true; if self.scripts.OnShow then self.scripts.OnShow() end end
function bag:Hide() self.shown=false; if self.scripts.OnHide then self.scripts.OnHide() end end
local canManagePanels=true
addon.Canvas.CanManagePanelsFromAddon=function() return canManagePanels end
addon.Canvas.IsFrameOnWorkspace=function(f) return f.x < 1440 end
function addon.Canvas:RestoreWorkspacePosition(f)
    local p=addon.db.savedWorkspacePositions[f:GetName()]; f.x=p.x; f.y=p.y
end
_G[name]=bag
local bagnon={shown=false,x=130,y=330,height=110,scripts={},id="inventory"}
setmetatable(bagnon,{__index=bag})
function bagnon:GetName() return "BagnonFrameinventory" end
local bagnonShows=0
Bagnon={Frames={}}
function Bagnon.Frames:Get(id)
    assert(id=="inventory")
    return bagnon
end
function Bagnon.Frames:Show(id)
    assert(id=="inventory")
    bagnonShows=bagnonShows+1
    bagnon:Show()
    return bagnon
end
function Bagnon.Frames:Hide(id)
    assert(id=="inventory")
    bagnon:Hide()
    return bagnon
end
local childName=name.."TitleText"
local child={scripts={}}
function child:GetName() return childName end
function child:GetParent() return bag end
function child:HookScript(s,fn) self.scripts[s]=fn end
_G[childName]=child
addon.db.savedWorkspacePositions[childName]={x=1,y=2}
addon.db.openWorkspacePanels={[childName]=true}
addon.db.baganatorWorkspacePanels={[childName]={x=1,y=2}}
-- An item button remains locally shown even when its parent bag is hidden.
BGRLiveItemButton1={IsShown=function() return true end}
local toggles=0
ToggleAllBags=function() toggles=toggles+1; if bag.shown then bag:Hide() else bag:Show() end end
GameMenuFrame={shown=false}
function GameMenuFrame:IsShown() return self.shown end
function GameMenuFrame:Show() self.shown=true end
function GameMenuFrame:Hide() self.shown=false end
CloseAllBags=function() bag:Hide() end
ShowUIPanel=function(panel) panel:Show() end
HideUIPanel=function(panel) panel:Hide() end
local nativeEscape
ToggleGameMenu=function()
    if nativeEscape and nativeEscape() then return end
    if GameMenuFrame.shown then GameMenuFrame:Hide() else GameMenuFrame:Show() end
end
hooksecurefunc=function(target, methodOrCallback, maybeCallback)
    local owner, name, callback
    if type(target)=="table" then
        owner, name, callback=target,methodOrCallback,maybeCallback
    else
        owner, name, callback=_G,target,methodOrCallback
    end
    local original=owner[name]
    owner[name]=function(...)
        local result=original(...)
        callback(...)
        return result
    end
end
assert(loadfile("Core/CanvasForeverBags.lua"))("Offhand",addon)
assert(loadfile("Core/BagPersistence.lua"))("Offhand",addon)
local tracker=addon.BagPersistence

local function CheckTargetEscape(frame, close)
    local previousEscape = nativeEscape
    local previousForever = addon.isForever
    addon.isForever = true
    targetSelected = true
    GameMenuFrame.shown = false
    frame:Show()
    flush()
    tick()
    local name = frame:GetName()
    local savedPosition = addon.db.savedWorkspacePositions[name]
    assert(addon.db.baganatorWorkspacePanels[name],
        "the test must start with a tracked workspace bag")
    nativeEscape = function()
        if frame:IsShown() then close(); return true end
        if targetSelected then targetSelected = false; return true end
    end
    ToggleGameMenu(); flush()
    assert(not frame:IsShown() and targetSelected and not GameMenuFrame.shown,
        name .. ": the first Escape must leave the bag closed for native target dismissal")
    assert(not addon.db.baganatorWorkspacePanels[name]
            and addon.db.savedWorkspacePositions[name] == savedPosition,
        name .. ": yielding must clear open intent and keep the saved bag position")
    ToggleGameMenu(); flush()
    assert(not frame:IsShown() and not targetSelected and not GameMenuFrame.shown,
        name .. ": the second Escape must reach native target dismissal")
    nativeEscape = previousEscape
    addon.isForever = previousForever
end
addon.isForever = true
onEvent(nil,"PLAYER_LOGIN"); onEvent(nil,"PLAYER_ENTERING_WORLD"); flush()
addon.isForever = false
assert(tracker.frames[name] == bag and tracker.frames[childName] == nil,
    "Baganator child regions must not be mistaken for backpack roots")
assert(tracker.IsBaganatorBackpackRoot(bag, name)
    and not tracker.IsBaganatorBackpackRoot(child, childName),
    "popup ownership must recognize the backpack root without claiming its children")
assert(globalScans == 1,
    "Baganator discovery must scan globals only once during lifecycle initialization")
for _ = 1, 15 do tick() end
assert(globalScans == 1,
    "the persistence ticker must never rescan the global namespace")
assert(type(baganatorCallbacks.BackpackFrameChanged) == "function",
    "Baganator frame replacement discovery must use its lifecycle callback")
assert(type(baganatorCallbacks.BagShow) == "function",
    "Baganator lazy initialization must use its bag-show lifecycle callback")
assert(addon.db.savedWorkspacePositions[childName] == nil
        and addon.db.openWorkspacePanels[childName] == nil
        and addon.db.baganatorWorkspacePanels[childName] == nil,
    "legacy Baganator child-region persistence records must be removed")

-- A newly created character can inherit the account profile's saved-open bag.
-- Do not restore it while Blizzard owns input for the intro; resume only after
-- PLAYER_CONTROL_GAINED so Escape remains the cinematic skip/menu key.
addon.db.baganatorWorkspacePanels={[name]={x=100,y=300,coordinateVersion=2}}
inputReserved=true
onEvent(nil,"PLAYER_CONTROL_LOST")
onEvent(nil,"PLAYER_ENTERING_WORLD"); flush()
assert(not bag.shown and tracker.waitingForInput,
    "intro input ownership must defer inherited replacement-bag restoration")
inputReserved=false
onEvent(nil,"PLAYER_CONTROL_GAINED"); flush()
assert(bag.shown and not tracker.waitingForInput,
    "replacement-bag restoration must resume after Blizzard returns control")
toggles=0
bag:Show(); tick()
assert(addon.db.baganatorWorkspacePanels[name].x==100)
assert(addon.db.baganatorWorkspacePanels[name].y==300
    and addon.db.baganatorWorkspacePanels[name].coordinateVersion==2,
    "addon bag snapshots must store the top edge used by Canvas restoration")

local positionBeforeRelayout = addon.db.savedWorkspacePositions[name]
bag.shown=false; bag.x=2000; bag:Show()
assert(addon.db.savedWorkspacePositions[name] == positionBeforeRelayout,
    "vendor auto-open must not clear the workspace record before Baganator lays out the bag")
bag.x=100; flush()
assert(addon.db.savedWorkspacePositions[name].x == 100,
    "bag show must capture the settled workspace geometry")
positionBeforeRelayout=addon.db.savedWorkspacePositions[name]
local openBeforeRelayout=addon.db.baganatorWorkspacePanels[name]
bag.x=nil; tick()
assert(addon.db.savedWorkspacePositions[name] == positionBeforeRelayout
    and addon.db.baganatorWorkspacePanels[name] == openBeforeRelayout,
    "temporarily unresolved geometry must preserve Baganator's saved anchor and open intent")
bag.x=100; tick()
-- UI teardown hides the bag before leaving; deferred hide must not erase state.
bag:Hide(); onEvent(nil,"PLAYER_LEAVING_WORLD"); flush(); tick()
assert(addon.db.baganatorWorkspacePanels[name])
bag.x=2000
onEvent(nil,"PLAYER_ENTERING_WORLD"); flush()
assert(bag.shown and bag.x==100 and toggles==1, "restore root bag and position despite shown item button")
onEvent(nil,"PLAYER_LEAVING_WORLD"); onEvent(nil,"PLAYER_ENTERING_WORLD"); flush()
assert(toggles==1, "already-open bag must not toggle closed")
bag:Hide(); flush(); assert(not next(addon.db.baganatorWorkspacePanels), "manual close must persist")
onEvent(nil,"PLAYER_LEAVING_WORLD"); onEvent(nil,"PLAYER_ENTERING_WORLD"); flush()
assert(not bag.shown and toggles==1)
bag.x=2000; bag:Show(); tick()
assert(not next(addon.db.baganatorWorkspacePanels) and not addon.db.savedWorkspacePositions[name],
    "a settled move to Mainhand must clear the old workspace placement and open intent")
bag.x=100; tick(); bag:Hide(); onEvent(nil,"PLAYER_LEAVING_WORLD"); flush()
combat=true; onEvent(nil,"PLAYER_ENTERING_WORLD"); flush(); assert(not bag.shown)
combat=false; onEvent(nil,"PLAYER_REGEN_ENABLED"); flush(); assert(bag.shown)
addon.db.restoreWorkspaceOnReload=false; tick()
assert(addon.db.baganatorWorkspacePanels[name],
    "reload preference must not disable the independent Escape snapshot")
onEvent(nil,"PLAYER_LEAVING_WORLD"); bag:Hide(); flush()
onEvent(nil,"PLAYER_ENTERING_WORLD"); flush()
assert(not bag.shown and not next(addon.db.baganatorWorkspacePanels),
    "disabled reload preference must not reopen the bag")
-- Roots can be created after entering the world (lazy addon initialization).
addon.db.restoreWorkspaceOnReload=true
addon.db.baganatorWorkspacePanels={[name]={x=110,y=210}}
bag.shown=false; _G[name]=nil; tracker.frames={}
onEvent(nil,"PLAYER_ENTERING_WORLD")
table.sort(queue, function(a,b) return a.delay < b.delay end)
table.remove(queue,1).fn()
assert(#queue>0 and not bag.shown)
_G[name]=bag; flush(); assert(bag.shown and bag.x==110 and bag.y==310
    and addon.db.baganatorWorkspacePanels[name].coordinateVersion==2,
    "Beta 18 bottom-edge snapshots must migrate to top-edge coordinates")

-- Forever calls CloseAllBags immediately before ToggleGameMenu for Escape.
-- Keep that paired hide distinct from B and close-button intent.
bag.x=100; bag.y=300; tick()
CloseAllBags(); ToggleGameMenu(); flush()
assert(bag.shown and GameMenuFrame.shown and addon.db.baganatorWorkspacePanels[name],
    "Escape must preserve an addon-owned workspace bag while opening the Game Menu")
CloseAllBags(); ToggleGameMenu(); flush()
assert(bag.shown and not GameMenuFrame.shown and addon.db.baganatorWorkspacePanels[name],
    "second Escape must preserve the bag while closing the Game Menu")

-- Baganator is also a UISpecialFrame and can be hidden directly by Escape,
-- bypassing CloseAllBags. Its OnHide/Game Menu pair must use the same repair.
bag:Hide(); ToggleGameMenu(); flush()
assert(bag.shown and GameMenuFrame.shown and addon.db.baganatorWorkspacePanels[name],
    "a direct UISpecialFrame hide paired with ToggleGameMenu must preserve Baganator")
ToggleGameMenu(); flush()
ToggleAllBags(); flush()
assert(not bag.shown and not next(addon.db.baganatorWorkspacePanels),
    "the explicit bag toggle must still close the bag and clear its open snapshot")

-- Baganator retains its native registration when Offhand replays its anchor.
-- Native title drags must retire Offhand's intent before the next Escape,
-- even when it arrives before our regular capture tick.
addon.isForever = true
CheckTargetEscape(bag, CloseAllBags)
CheckTargetEscape(bag, function() bag:Hide() end)
bag.x=100; bag:Show(); flush()
assert(addon.db.baganatorWorkspacePanels[name], "expected a visible Offhand bag")
bag.x=1800
assert(bag.scripts.OnDragStop, "Baganator drag completion must reconcile Escape ownership")
bag.scripts.OnDragStop()
assert(not addon.db.baganatorWorkspacePanels[name] and not addon.db.savedWorkspacePositions[name],
    "native drag to Mainhand must retire Offhand's Escape state in the same turn")
nativeEscape=function() bag:Hide(); return true end
ToggleGameMenu(); flush()
assert(not bag.shown, "Escape immediately after a native Mainhand drag must close the bag")
ToggleAllBags(); flush(); ToggleGameMenu(); flush()
assert(not bag.shown, "opening Baganator with B on Mainhand must not restore old Offhand Escape state")
ToggleAllBags(); flush()
bag.x=100; bag.scripts.OnDragStop()
ToggleGameMenu(); flush()
assert(bag.shown and addon.db.baganatorWorkspacePanels[name],
    "dragging back to Offhand must restore workspace Escape protection")
nativeEscape=nil
bag:Hide(); flush()
GameMenuFrame.shown=false
addon.isForever = false

-- EllesmereUI's bag replacement is a supported root alongside Baganator.
local eui={shown=true,x=120,y=320,scripts={}}
setmetatable(eui,{__index=bag})
function eui:GetName() return "EUI_MainBagFrame" end
EUI_MainBagFrame=eui
EllesmereUIDB={bagsVisible=true}
tracker:Discover(); tick()
assert(tracker.frames.EUI_MainBagFrame and addon.db.baganatorWorkspacePanels.EUI_MainBagFrame,
    "EllesmereUI's main bag root must participate in workspace persistence")

-- EllesmereUI Edit Mode moves its root without invoking Offhand's drag-stop
-- handler. A later map repair must not consume the old workspace position.
addon.db.openWorkspacePanels={EUI_MainBagFrame=true}
addon.db.savedWorkspacePositions.EUI_MainBagFrame={x=120,y=320,coordinateVersion=2}
eui.x=2000
tracker:Capture()
assert(not addon.db.baganatorWorkspacePanels.EUI_MainBagFrame
    and not addon.db.savedWorkspacePositions.EUI_MainBagFrame
    and not addon.db.openWorkspacePanels.EUI_MainBagFrame,
    "moving the EllesmereUI bag to Mainhand must retire every stale workspace record")
eui.x=120
tracker:Capture()

-- EllesmereUI records false only for a deliberate X/bag-key close. Its Escape
-- proxy merely hides the frame, so this signal prevents a stale Offhand open
-- snapshot from undoing the user's explicit close on their next Escape press.
eui:Hide()
EllesmereUIDB.bagsVisible=false
CloseAllBags(); ToggleGameMenu(); flush()
assert(not eui.shown and not addon.db.baganatorWorkspacePanels.EUI_MainBagFrame,
    "an explicit EllesmereUI close must cancel restoration on the next Escape")

-- EllesmereUI owns its Escape proxy and bag visibility state. Offhand must not
-- reopen the root from OnHide: doing so can re-enter Edit Mode/Game Menu state.
EllesmereUIDB.bagsVisible=true
eui:Show(); tick()
eui:Hide(); flush()
assert(not eui.shown,
    "Offhand must not reopen an EllesmereUI bag from its OnHide callback")

-- Bagnon registers its top-level inventory window in UISpecialFrames. Preserve
-- that root when Escape hides it directly, but respect its own X/B hide API.
eui.shown=false
bag.shown=false
bagnonLoaded=true
onEvent(nil,"ADDON_LOADED","Bagnon"); flush()
assert(tracker.frames.BagnonFrameinventory == bagnon,
    "Bagnon's public inventory root must be discovered without a global scan")
assert(tracker.bagnonCallbacksInstalled,
    "Bagnon's lazy root observer must be enabled")
assert(bagnon.scripts.OnShow == nil and bagnon.scripts.OnHide == nil,
    "Offhand must not install scripts in Bagnon's Gamepad focus ancestry")
bagnon.x=130; bagnon.y=330; bagnon:Show(); tick()
assert(addon.db.baganatorWorkspacePanels.BagnonFrameinventory,
    "a visible workspace Bagnon inventory must be captured")
GameMenuFrame.shown=false
bagnon:Hide(); ToggleGameMenu(); flush()
assert(bagnon.shown and GameMenuFrame.shown and bagnonShows==1,
    "Escape must restore Bagnon's inventory through its public frame manager")
ToggleGameMenu(); flush()
onEvent(nil,"PLAYER_LEAVING_WORLD")
bagnon:Hide()
onEvent(nil,"PLAYER_ENTERING_WORLD"); flush()
assert(bagnon.shown and bagnonShows==2,
    "reload restoration must reopen Bagnon through its public frame manager")
Bagnon.Frames:Hide("inventory"); tick(); flush()
assert(not bagnon.shown and not next(addon.db.baganatorWorkspacePanels),
    "Bagnon's explicit close API must clear the independent open snapshot")

baganatorLoaded = false
CheckTargetEscape(bagnon, function() Bagnon.Frames:Hide("inventory") end)
baganatorLoaded = true

-- Forever Gamepad mode owns Bagnon's visibility and Blizzard focus routing.
-- Keep the saved intent but perform no reopen or root lifecycle participation.
addon.db.baganatorWorkspacePanels.BagnonFrameinventory={
    x=130,y=330,coordinateVersion=2,
}
canManagePanels=false
GameMenuFrame.shown=false
ToggleGameMenu(); flush(); tick()
assert(not bagnon.shown and addon.db.baganatorWorkspacePanels.BagnonFrameinventory
        and bagnon.scripts.OnShow == nil and bagnon.scripts.OnHide == nil,
    "Gamepad UI must retain Bagnon intent without reopening or hooking its root")

-- Outside native Gamepad focus, Professions and Options are temporary panel
-- transitions rather than explicit Bagnon closes. Restore through the public
-- manager after both their opening and closing transactions.
canManagePanels=true
local professions={name="ProfessionsFrame",shown=false}
function professions:GetName() return self.name end
function professions:Show() self.shown=true end
function professions:Hide() self.shown=false end
function professions:IsShown() return self.shown end
local settings={name="SettingsPanel",shown=false}
function settings:GetName() return self.name end
function settings:Show() self.shown=true end
function settings:Hide() self.shown=false end
function settings:IsShown() return self.shown end
addon.Canvas.IsForeverBagPreservingPanel=function(_, frame)
    return frame == professions or frame == settings
end
bagnon:Show(); tick()
local transitionShows=bagnonShows
bagnon:Hide(); ShowUIPanel(professions); flush()
assert(bagnon.shown and bagnonShows==transitionShows+1,
    "opening Professions must restore a tracked Offhand Bagnon root")
bagnon:Hide(); HideUIPanel(professions); flush()
assert(bagnon.shown and bagnonShows==transitionShows+2,
    "closing Professions must restore a tracked Offhand Bagnon root")
assert(bagnon.scripts.OnShow == nil and bagnon.scripts.OnHide == nil,
    "panel transition recovery must not hook Bagnon's protected root")

-- Settings intentionally owns the native panel slot while visible. Reopening
-- Bagnon during that transaction produces a visible flash and its audio cue.
-- Hold the saved snapshot until Settings closes, then restore exactly once.
local settingsShows=bagnonShows
bagnon:Hide(); ShowUIPanel(settings); flush()
tick()
assert(not bagnon.shown and bagnonShows==settingsShows,
    "visible Settings must defer Bagnon restoration without an opening cue")
HideUIPanel(settings); flush()
assert(bagnon.shown and bagnonShows==settingsShows+1,
    "closing Settings must restore the previously open Offhand Bagnon root once")

-- Forever's Options button hides the Game Menu and opens Settings. On close,
-- Settings hides its panel and returns to the Game Menu via ToggleGameMenu.
addon.isForever = true
bagnon:Hide(); flush(); tick()
EUI_MainBagFrame = nil
bag:Show(); flush(); tick()
targetSelected = true
GameMenuFrame:Show()
HideUIPanel(GameMenuFrame)
CloseAllBags(); ShowUIPanel(settings); flush(); tick()
assert(not bag.shown and addon.db.baganatorWorkspacePanels[name],
    "Options must keep the hidden Baganator backpack's open intent across visibility samples")
local optionsOpens = toggles
local optionsPosition = addon.db.baganatorWorkspacePanels[name]
HideUIPanel(settings); ToggleGameMenu(); flush()
assert(bag.shown and targetSelected and GameMenuFrame:IsShown() and toggles == optionsOpens + 1,
    "closing Options must restore Baganator without consuming target or changing the menu")
assert(bag.x == optionsPosition.x and bag.y == optionsPosition.y,
    "Options must restore Baganator to the saved workspace position")
targetSelected = false
GameMenuFrame:Hide()
bag:Hide(); flush(); tick()
ShowUIPanel(settings); flush(); tick()
HideUIPanel(settings); ToggleGameMenu(); flush()
assert(not bag.shown, "closing Options must leave an already closed backpack closed")
GameMenuFrame:Hide()
bag:Show(); flush(); tick()
CloseAllBags(); ShowUIPanel(settings); flush()
bag:Show(); flush(); tick()
bag:Hide(); flush(); tick()
HideUIPanel(settings); ToggleGameMenu(); flush()
assert(not bag.shown, "a manual reopen and close while Options is visible must cancel restoration")
GameMenuFrame:Hide()
EUI_MainBagFrame = eui

-- Forever's Escape dispatcher can claim Escape via CloseSpecialWindows
-- without changing menu visibility. It must restore the exact EUI root.
addon.isForever = true
addon.Canvas.IsForeverBagPreservingPanelShown = function() return settings.shown end
bagnon.shown, bagnonLoaded = false, false
eui.scripts = {}
tracker.frames.EUI_MainBagFrame = nil
tracker:Discover(false)
assert(not next(eui.scripts), "Forever Ellesmere bags must be observed outside their frame tree")
local refreshed = 0
function eui:RefreshInventory() refreshed = refreshed + 1 end
function eui:GetNumPoints() return self.positionReady and 1 or 0 end
local reagent = setmetatable({shown=true,x=110,y=320,scripts={}}, {__index=bag})
function reagent:RefreshInventory() self.refreshed = (self.refreshed or 0) + 1 end
EUI_ReagentBagFrame = reagent
CloseSpecialWindows = function()
    if eui.shown then eui:Hide(); reagent:Hide(); return true end
end
nativeEscape = function()
    if not GameMenuFrame.shown then return CloseSpecialWindows() end
end
tracker:InstallEscapeHooks()
GameMenuFrame.shown = false
eui:Show(); bag:Show(); tick()
local beforeToggles = toggles
ToggleGameMenu(); flush()
assert(eui.shown and refreshed == 1 and toggles == beforeToggles and bag.shown
    and GameMenuFrame.shown and reagent.shown and reagent.refreshed == 1,
    "Escape must open the Game Menu and restore the exact workspace Ellesmere root")
ToggleGameMenu(); flush()
assert(eui.shown and refreshed == 1 and not GameMenuFrame.shown,
    "the next Escape must dismiss the menu and leave the Ellesmere bag open")

bag:Hide(); flush()
CheckTargetEscape(eui, CloseSpecialWindows)
eui:Show(); tick()

CloseSpecialWindows(); ShowUIPanel(settings); flush(); tick()
assert(not eui.shown and refreshed == 1 and not GameMenuFrame.shown,
    "Options and other unpaired panel cleanup must not trigger the Escape restore")
HideUIPanel(settings); flush()
eui:Show(); tick()
ToggleGameMenu()
EllesmereUIDB.bagsVisible = false
flush()
assert(not eui.shown and refreshed == 1 and not GameMenuFrame.shown,
    "a deliberate close must win over deferred Escape recovery")

-- A still-open bag retains reload intent. EUI applies its own position when
-- its startup completes. Offhand must not replay stale coordinates over it.
bag.shown, baganatorLoaded = false, false
EllesmereUI = {_bagsDB={profile={enhancedBags=true}}}
EllesmereUIDB.bagsVisible = true
eui:Show(); tick()
onEvent(nil, "PLAYER_LEAVING_WORLD")
eui:Hide()
eui.x, eui.positionReady = 720, false
local reloadToggles = 0
ToggleAllBags = function() reloadToggles = reloadToggles + 1; eui:Show() end
onEvent(nil, "PLAYER_ENTERING_WORLD")
local attempt = table.remove(queue, 1)
attempt.fn()
assert(reloadToggles == 0, "the reload must wait until EllesmereUI has installed the bag layout")
eui.positionReady = true
flush()
assert(eui.shown and eui.x == 720 and reloadToggles == 1,
    "reload must reopen an isolated Ellesmere bag at its native saved anchor")
onEvent(nil, "PLAYER_LEAVING_WORLD")
eui:Hide()
bag:Show()
baganatorLoaded = true
onEvent(nil, "PLAYER_ENTERING_WORLD"); flush()
assert(not eui.shown and reloadToggles == 1 and bag.shown,
    "reload must skip an ambiguous shared toggle and leave the other provider alone")

local scaleRestored = 0
EllesmereUI._ModuleNS = {EllesmereUIBags={_bagsInternals={ApplyBagScale=function()
    scaleRestored = scaleRestored + 1
end}}}
eui:Show(); tick()
onEvent(nil, "PLAYER_LEAVING_WORLD")
eui:Hide()
onEvent(nil, "PLAYER_ENTERING_WORLD"); flush()
assert(eui.shown and refreshed == 2 and eui.x == 720 and reloadToggles == 1
    and scaleRestored == 1 and bag.shown,
    "when both providers are loaded, reload must restore only Ellesmere's saved root")

eui:Show(); tick()
canManagePanels = false
ToggleGameMenu(); flush()
assert(not eui.shown and refreshed == 2,
    "native Gamepad Escape and focus must not be overridden by the replacement-bag path")

local callbacks, registrations = {}, 0
EventRegistry = { RegisterCallback = function(_, event, callback, owner)
    registrations = registrations + 1
    callbacks[event] = function() callback(owner) end
end }
canManagePanels = true
onEvent(nil, "PLAYER_LOGIN")
onEvent(nil, "PLAYER_LOGIN")
flush()
local openTalents = callbacks["PlayerSpellsFrame.OpenFrame"]
assert(openTalents and registrations == 1, "Forever must observe the native Player Spells opening once")
PlayerSpellsFrame = { shown = true, talentTabID = 2, tab = 2,
    IsShown = function(self) return self.shown end,
    GetTab = function(self) return self.tab end }
local function openWorkspaceBags()
    EllesmereUIDB.bagsVisible = true
    eui:Show()
    reagent:Show()
    tick()
end
openWorkspaceBags()
eui:Hide()
reagent:Hide()
local beforeTalents = refreshed
local beforeReagent = reagent.refreshed
openTalents()
assert(not eui.shown, "bag restoration must run outside Blizzard's panel-open stack")
flush()
assert(eui.shown and refreshed == beforeTalents + 1 and reagent.shown
    and reagent.refreshed == beforeReagent + 1 and not GameMenuFrame.shown and reloadToggles == 1,
    "Talents must restore the two previously visible Ellesmere workspace roots without a bag or menu toggle")

for _, exclude in ipairs({"spellbook", "closed-panel", "explicit-close", "combat", "gamepad", "mainhand", "no-open-intent", "loading"}) do
    openWorkspaceBags()
    eui:Hide()
    reagent:Hide()
    if exclude == "spellbook" then PlayerSpellsFrame.tab = 3 end
    if exclude == "mainhand" then eui.x = 2000 end
    if exclude == "no-open-intent" then tick() end
    openTalents()
    if exclude == "closed-panel" then PlayerSpellsFrame.shown = false end
    if exclude == "explicit-close" then EllesmereUIDB.bagsVisible = false end
    if exclude == "combat" then combat = true end
    if exclude == "gamepad" then canManagePanels = false end
    if exclude == "loading" then onEvent(nil, "PLAYER_LEAVING_WORLD") end
    flush()
    assert(not eui.shown and not reagent.shown and refreshed == beforeTalents + 1,
        "Talents must leave bags closed for " .. exclude)
    PlayerSpellsFrame.tab, PlayerSpellsFrame.shown = 2, true
    combat, canManagePanels, eui.x = false, true, 720
end

-- Stock Forever closes registered special frames both before clearing a target
-- on Escape and when opening a centered Settings panel.
EUI_MainBagFrame = nil
bag:Hide(); flush()
onEvent(nil, "PLAYER_ENTERING_WORLD"); flush()
assert(loadfile("Core/CanvasAddonEscape.lua"))("Offhand", addon)
local other = {shown=false}
function other:IsShown() return self.shown end
function other:Hide() self.shown = false end
_G.TestSpecialWindow = other
UISpecialFrames = {"TestSpecialWindow", name}
local function NativeCloseSpecialWindows()
    local closed = false
    for _, key in pairs(UISpecialFrames) do
        local frame = _G[key]
        if frame:IsShown() then frame:Hide(); closed = true end
    end
    return closed
end
nativeEscape = function()
    if NativeCloseSpecialWindows() then return true end
    if targetSelected then targetSelected = false; return true end
end
local hideCalls, hide = 0, bag.Hide
function bag:Hide() hideCalls = hideCalls + 1; hide(self) end
GameMenuFrame:Hide()
bag.x = 100
bag:Show()
assert(#UISpecialFrames == 1, "an already positioned bag must stay open even before deferred capture")
flush(); tick()
targetSelected = true
other.shown = true
ToggleGameMenu(); flush()
assert(not other.shown and targetSelected and bag.shown and hideCalls == 0,
    "Escape must dismiss another special window without hiding Baganator")
ToggleGameMenu(); flush()
assert(not targetSelected and bag.shown and hideCalls == 0,
    "native Escape must clear the target without blinking the workspace backpack")
ToggleGameMenu(); flush()
assert(GameMenuFrame:IsShown() and bag.shown and hideCalls == 0,
    "Escape must open the menu without hiding the backpack")
HideUIPanel(GameMenuFrame)
NativeCloseSpecialWindows(); ShowUIPanel(settings); flush(); tick()
assert(settings.shown and bag.shown and hideCalls == 0,
    "Options must leave the workspace backpack open through native cleanup")
HideUIPanel(settings); ToggleGameMenu(); flush()
assert(bag.shown and hideCalls == 0, "returning to the Game Menu must leave the bag visible")
bag:Hide(); ToggleGameMenu(); flush()
assert(not bag.shown and hideCalls == 1 and UISpecialFrames[2] == name,
    "an explicit bag close must restore its registration and survive immediate Escape")
bag:Show(); flush()
bag.x = 2000; bag.scripts.OnDragStop()
assert(UISpecialFrames[2] == name and UISpecialFrames[1] == "TestSpecialWindow",
    "moving the backpack to Mainhand must restore its own native registration immediately")
ToggleGameMenu(); flush()
assert(not bag.shown and hideCalls == 2, "Escape must still close the Mainhand backpack")
bag.x = 100; bag:Show(); flush()
addon.db.persistentWorkspacePanels = false; tick()
assert(UISpecialFrames[2] == name, "disabling workspace persistence must restore native bag dismissal")
addon.db.persistentWorkspacePanels = true; tick()
canManagePanels = false; tick()
assert(UISpecialFrames[2] == name, "handing off to native Gamepad mode must release the bag registration")
canManagePanels = true; tick()
local shutdownPosition = addon.db.baganatorWorkspacePanels[name]
assert(shutdownPosition and #UISpecialFrames == 1)
bag:Hide(); onEvent(nil, "PLAYER_LEAVING_WORLD"); flush()
assert(addon.db.baganatorWorkspacePanels[name] == shutdownPosition,
    "a hide before the shutdown event must keep the workspace backpack's reopen snapshot")

-- Companion can finish the display span after World has already loaded.
local spanned = false
addon.Viewport = {GetMetrics = function() return {isSpanned=spanned} end}
tracker.frames = {[name] = bag}
addon.db.baganatorWorkspacePanels = {[name] = shutdownPosition}
local coldOpens = 0
ToggleAllBags = function() coldOpens = coldOpens + 1; bag:Show() end
bag.x = 2000
onEvent(nil, "PLAYER_ENTERING_WORLD"); flush(); tick()
assert(coldOpens == 0 and not bag.shown and addon.db.baganatorWorkspacePanels[name] == shutdownPosition,
    "cold login must hold the saved bag while the workspace is unavailable")
spanned = true
tracker:ResumeWhenWorkspaceReady(); tracker:ResumeWhenWorkspaceReady(); flush()
assert(coldOpens == 1 and bag.shown and bag.x == shutdownPosition.x and bag.y == shutdownPosition.y,
    "a late workspace span must reopen the bag once at its saved position")

print("PASS: addon bag reload, Escape, explicit close, Baganator, Bagnon and EllesmereUI roots")

