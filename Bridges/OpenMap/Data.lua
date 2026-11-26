-- OpenMap data bridge (built into Offhand). Facts only: no frame, hook or timer.
-- Addon window catalog: its world map, under OpenMap's own geometry and the dedicated map
-- policy. Its map handling stays in the core for now.
-- Registered on every client, like the catalog entry it replaces.

local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local API = type(Offhand) == "table" and Offhand.API
if type(API) ~= "table" or API.BRIDGE_CONTRACT ~= 1 or type(API.RegisterAddonData) ~= "function" then return end

API.RegisterAddonData("OpenMap", {
    catalogs = {
        OpenMap = {
            worldMap = {position = "addon", close = "map-adapter"},
        },
    },
})
