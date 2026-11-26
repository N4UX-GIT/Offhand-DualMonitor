--[[
    Offhand: Multi-Monitor Setup Addon
    Bridges/OpenMap/Init.lua: registers the built-in OpenMap bridge

    One bridge object (id OpenMap) carries OpenMap's map provider (Map.lua),
    its movement fade entry (map.fade, order 10, read at runtime), the
    /offhand recovermap command and the World Map card controls the Options
    panel showed for OpenMap: the "(OpenMap)" scale title and its help, the
    workspace help ahead of the map description, and on Forever the two
    recovery buttons, all shown only while OpenMap is loaded, enabled and the
    World Map owner.

    Registered on every client, like the core code it replaces, so an OpenMap
    that loads after Offhand is still handled.
--]]

local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local API = type(Offhand) == "table" and Offhand.API
if type(API) ~= "table" or API.BRIDGE_CONTRACT ~= 1 or type(API.RegisterBridge) ~= "function"
    or type(API.GetBridgeNamespace) ~= "function" then return end

local namespace = API.GetBridgeNamespace("OpenMap")
local Recovery, Provider = namespace.Recovery, namespace.Provider
if type(Recovery) ~= "table" or type(Provider) ~= "table" then return end

local bridge = {
    contract = API.BRIDGE_CONTRACT,
    mapProvider = Provider,
    data = {
        ownership = {
            -- OpenMap holds mapFade itself while its world map is active; its
            -- existing update path applies a changed preference to the map.
            { role = "map.fade", name = "OpenMap", order = 10, detect = { loaded = "OpenMap" },
                read = namespace.ReadFade, key = "moveFade", opaque = 0,
                refresh = namespace.RefreshReleasedFade, helpKey = "MAP_MOVEMENT_OPENMAP" },
        },
    },
    slashCommands = {
        recovermap = function(arg) Recovery:RunAndReport(strtrim(arg or "") == "offhand") end,
    },
}

function bridge:GetSettingsContributions(slot)
    if slot == "mapScaleTitle" then
        return {
            { id = "openmap.scale", kind = "suffix", owner = "OpenMap", addon = "OpenMap", text = " (OpenMap)",
                help = API.GetText("MAP_SCALE_OPENMAP_HELP") },
        }
    elseif slot == "mapDescription" then
        return {
            { id = "openmap.workspace-help", kind = "prefix", owner = "OpenMap", addon = "OpenMap",
                text = API.GetText("OPENMAP_WORKSPACE_HELP") },
        }
    elseif slot == "map" and API.IsForeverClient() then
        return {
            { id = "openmap.recover", kind = "button", owner = "OpenMap", addon = "OpenMap", height = 30,
                text = API.GetText("OPENMAP_RECOVERY_BUTTON"), tooltip = API.GetText("OPENMAP_RECOVERY_TIP"),
                onClick = function() Recovery:RunAndReport() end },
            { id = "openmap.workspace", kind = "button", owner = "OpenMap", addon = "OpenMap", height = 36,
                text = API.GetText("OPENMAP_WORKSPACE_BUTTON"),
                onClick = function() Recovery:RunAndReport(true) end },
        }
    end
end

API.RegisterBridge("OpenMap", bridge)
