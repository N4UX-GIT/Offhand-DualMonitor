-- MapWise data bridge (built into Offhand). Facts only: no frame, hook or timer.
-- MapWise's version, read from the MapWiseAPI table first, is listed among the map
-- integrations (map.integration, order 20). While MapWiseAPI exists the Forever map observer
-- installs the MapWise position guard of Bridge.lua (map.layoutGuard), and while MapWise is
-- loaded Offhand leaves the compact map's combat anchor to it (map.blocksCombatAnchorRepair).
-- Its movement fade entry (map.fade, order 30) is registered by Bridge.lua.
-- Registered on every client, like the checks it replaces.

local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local API = type(Offhand) == "table" and Offhand.API
if type(API) ~= "table" or API.BRIDGE_CONTRACT ~= 1 or type(API.RegisterAddonData) ~= "function" then return end

API.RegisterAddonData("MapWise", {
    ownership = {
        { role = "map.integration", name = "MapWise", order = 20, versionNamespace = "MapWiseAPI" },
        { role = "map.layoutGuard", name = "MapWise", order = 10, detect = { global = "MapWiseAPI" } },
        { role = "map.blocksCombatAnchorRepair", name = "MapWise", order = 10, detect = { loaded = "MapWise" } },
    },
})
