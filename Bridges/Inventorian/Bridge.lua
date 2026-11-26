-- Inventorian data bridge (built into Offhand). Facts only: no frame, hook or timer.
-- Inventorian replaces the bags while its global exists (hud.bags, order 80) and is a bag
-- owner in the compatibility report when loaded or present (report.bags, order 90).
-- Registered on every client, like the checks it replaces.

local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local API = type(Offhand) == "table" and Offhand.API
if type(API) ~= "table" or API.BRIDGE_CONTRACT ~= 1 or type(API.RegisterAddonData) ~= "function" then return end

API.RegisterAddonData("Inventorian", {
    ownership = {
        { role = "hud.bags", name = "Inventorian", order = 80, detect = { global = "Inventorian" } },
        { role = "report.bags", name = "Inventorian", order = 90, detect = { present = "Inventorian" } },
    },
})
