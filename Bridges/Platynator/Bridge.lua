--[[
    Offhand: Multi-Monitor Setup Addon
    Bridges/Platynator/Bridge.lua: built-in bridge for Platynator

    The Platynator parts of Core/CanvasAddonEscape.lua moved behind the bridge
    contract; their behaviour is unchanged. Its window index names the
    customise dialog for the addon window Escape adapter, with its catalog
    entry (the picker may learn its placement), its openers (the slash
    command, the addon compartment callback and the settings link) and its
    close button. Its import and confirmation dialogs are not matched.

    Registered on every client, like the core code it replaces; the adapter
    itself runs on the Forever client only, and Platynator is read when asked.
--]]

local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local API = type(Offhand) == "table" and Offhand.API
if type(API) ~= "table" or API.BRIDGE_CONTRACT ~= 1 or type(API.RegisterBridge) ~= "function" then return end

local function Loaded(name)
    local query = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    return type(query) == "function" and query(name) and true or false
end

local bridge = {
    contract = API.BRIDGE_CONTRACT,
    data = {
        catalogs = {
            Platynator = {
                settings = {position = "addon", close = "workspace-special-windows", opener = "Platynator",
                    learnPlacementFile = "customisedialog/main.lua"},
            },
        },
        windows = {
            patterns = {"^PlatynatorCustomiseDialog[%w_]+$"},
            owners = {"Platynator"},
            openers = {
                globals = {"Platynator_AddonCompartmentCallback"},
                links = {{link = "addon:platynatorsettings", when = {loaded = "Platynator"}}},
            },
        },
    },
}

function bridge:IdentifyWindow(frame, name, source)
    if Loaded("Platynator")
        and source:find("/platynator/customisedialog/main.lua:", 1, true)
        and frame.Tabs and frame.CloseButton then return "Platynator", "settings" end
    return nil
end

function bridge:GetWindowCloseButtons(frame)
    return {frame.CloseButton}
end

API.RegisterBridge("Platynator", bridge)
