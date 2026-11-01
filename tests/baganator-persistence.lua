local addon = { db = { enabled=true, savedWorkspacePositions={} }, Canvas={} }
local queue, tick, onEvent = {}, nil, nil
local combat = false
local inputReserved = false
local nativePairs, globalScans = pairs, 0
pairs = function(value)
    if value == _G then globalScans = globalScans + 1 end
    return nativePairs(value)
end
local bagnonLoaded=false
C_AddOns = { IsAddOnLoaded = function(name)
    return name == "Baganator" or (name == "Bagnon" and bagnonLoaded)
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
ToggleGameMenu=function()
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
assert(loadfile("Core/BagPersistence.lua"))("Offhand",addon)
local tracker=addon.BagPersistence
onEvent(nil,"PLAYER_LOGIN"); onEvent(nil,"PLAYER_ENTERING_WORLD"); flush()
assert(tracker.frames[name] == bag and tracker.frames[childName] == nil,
    "Baganator child regions must not be mistaken for backpack roots")
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
assert(not next(addon.db.baganatorWorkspacePanels), "game-view bags must not be restored")
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
assert(not bagnon.shown and bagnonShows==settingsShows,
    "visible Settings must defer Bagnon restoration without an opening cue")
HideUIPanel(settings); flush()
assert(bagnon.shown and bagnonShows==settingsShows+1,
    "closing Settings must restore the previously open Offhand Bagnon root once")

print("PASS: addon bag reload, Escape, explicit close, Baganator, Bagnon and EllesmereUI roots")

