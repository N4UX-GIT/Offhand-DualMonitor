local addon = {
    isRetail = false,
    isForever = false,
    tocVersion = 30300,
}

local loaded = {}
C_AddOns = {
    IsAddOnLoaded = function(name)
        return loaded[name] == true
    end,
}

assert(loadfile("Core/HUDCompatibility.lua"))("Offhand", addon)
local compatibility = assert(addon.HUDCompatibility)

MainMenuBar = {}
ContainerFrame1 = {}
MinimapCluster = {
    IsUserPlaced = function() return false end,
}
assert(not compatibility.HasCustomActionBarAddon(),
    "stock action bars must remain available")
assert(not compatibility.HasCustomBagAddon(),
    "stock bags must remain available")
assert(not compatibility.HasCustomMinimapAddon(),
    "the stock Minimap must remain available")

Bartender4 = {}
Bagnon = {}
SexyMap = {}
assert(compatibility.HasCustomActionBarAddon(),
    "Bartender ownership was not detected")
assert(compatibility.HasCustomBagAddon(),
    "Bagnon ownership was not detected")
assert(compatibility.HasCustomMinimapAddon(),
    "SexyMap ownership was not detected")
Bartender4, Bagnon, SexyMap = nil, nil, nil
loaded.EllesmereUIActionBars, loaded.EllesmereUIMinimap, loaded.EllesmereUIChat = true, true, true
assert(compatibility.HasCustomActionBarAddon() and compatibility.HasCustomMinimapAddon()
        and compatibility.HasCustomChatAddon(), "Ellesmere modules must own their actual frame families")
loaded.EllesmereUIActionBars, loaded.EllesmereUIMinimap, loaded.EllesmereUIChat = nil, nil, nil
loaded.EllesmereUIBags = true
assert(compatibility.HasCustomBagAddon(),
    "Ellesmere bags must own native bag layout even when ContainerFrame1 still exists")
loaded.EllesmereUIBags = nil
local previousEnum = Enum
Enum = { EditModeSystem = {ActionBar=1, StatusTrackingBar=2} }
loaded.EllesmereUIDataBars = true
assert(not compatibility.IsExternallyOwnedEditModeSystem({system=2})
        and not compatibility.IsExternallyOwnedEditModeSystem({system=1}),
    "standalone Ellesmere DataBars must not claim native XP/Rep or action bars")
loaded.EllesmereUIDataBars = nil
loaded.EllesmereUIActionBars = true
local blizzardDataBars = false
EllesmereUI = {Lite={GetAddon=function(name, silent)
    assert(name == "EllesmereUIActionBars" and silent)
    return {db={profile={useBlizzardDataBars=blizzardDataBars}}}
end}}
assert(compatibility.IsExternallyOwnedEditModeSystem({system=2}),
    "Ellesmere custom XP/Rep bars must retain ownership")
blizzardDataBars = true
assert(not compatibility.IsExternallyOwnedEditModeSystem({system=2})
    and compatibility.IsExternallyOwnedEditModeSystem({system=1}),
    "Blizzard XP/Rep override must yield status systems without yielding action bars")
EllesmereUI.Lite.GetAddon = function() error("unavailable") end
assert(compatibility.IsExternallyOwnedEditModeSystem({system=2}),
    "unknown Ellesmere profile state must conservatively preserve external ownership")
EllesmereUI, loaded.EllesmereUIActionBars = nil, nil
Enum = previousEnum

loaded.EllesmereUIRaidFrames = true
loaded.Chattynator = true
assert(compatibility.HasEllesmerePartyFrames(),
    "EllesmereUI party-frame ownership was not detected")
assert(compatibility.HasChattynator(),
    "Chattynator ownership was not detected")

local managed = { isManagedFrame = true }
assert(compatibility.IsBlizzardEditModeOwnedFrame(managed),
    "native managed-frame ownership was not detected")
assert(compatibility.IsBlizzardEditModeOwnedFrame(nil, "DamageMeterFrame"),
    "native Damage Meter ownership was not detected")

addon.isForever = true
addon.HasBlizzardEditMode = function() return true end
local chat = {
    OnEditModeEnter = function() end,
    OnEditModeExit = function() end,
}
ChatFrame1 = chat
assert(compatibility.UsesForeverEditMode(),
    "Forever Edit Mode detection changed during extraction")
assert(compatibility.IsForeverEditModeFrame(chat, "ChatFrame1"),
    "Forever's native primary chat ownership was not detected")

addon.isForever = false
chat.isStaticDocked = true
assert(compatibility.RetailEditModeOwnsPrimaryChat(chat),
    "Retail primary chat ownership was not detected")

addon.Mainhand = {
    IsNativeGamepadInterface = function() return true end,
    IsControllerLayout = function() return true end,
}
assert(compatibility.UsesNativeGamepadInterface()
        and compatibility.UsesControllerInterface(),
    "Mainhand controller capability delegation changed during extraction")

print("PASS: HUD compatibility ownership and client capability policy")
