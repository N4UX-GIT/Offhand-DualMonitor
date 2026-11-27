-- AdiBags data bridge (built into Offhand). Facts only: no frame, hook or timer.
-- AdiBags replaces the bags while its global exists (hud.bags, order 50) and is a bag owner
-- in the compatibility report when loaded or present (report.bags, order 80). Its names join
-- the bag namespace scans of the reload reopen and the logout open-state capture
-- (bagNamespace.openScan, bagNamespace.logoutScan) and are reload bag roots (bagRestorable).
-- Registered on every client, like the checks it replaces.

local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local API = type(Offhand) == "table" and Offhand.API
if type(API) ~= "table" or API.BRIDGE_CONTRACT ~= 1 or type(API.RegisterAddonData) ~= "function" then return end

API.RegisterAddonData("AdiBags", {
    ownership = {
        { role = "hud.bags", name = "AdiBags", order = 50, detect = { global = "AdiBags" } },
        { role = "report.bags", name = "AdiBags", order = 80, detect = { present = "AdiBags" } },
    },
    frameRules = {
        ["bagNamespace.openScan"] = { { patterns = { "^AdiBags" } } },
        ["bagNamespace.logoutScan"] = { { patterns = { "^AdiBags" } } },
        bagRestorable = { { patterns = { "^AdiBags" } } },
    },
})
