-- Bagnaros data bridge (built into Offhand). Facts only: no frame, hook or timer.
-- Addon window catalog: its inventory, under Offhand's dedicated bag Escape handling and
-- kept out of the addon window picker.
-- Bag facts: it replaces the bags while loaded or present (hud.bags, order 110) and is a bag
-- owner in the compatibility report when loaded or present (report.bags, order 70). Its bag
-- Escape adapter is in Bags.lua beside this file.
-- Registered on every client, like the catalog entry it replaces.

local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local API = type(Offhand) == "table" and Offhand.API
if type(API) ~= "table" or API.BRIDGE_CONTRACT ~= 1 or type(API.RegisterAddonData) ~= "function" then return end

API.RegisterAddonData("Bagnaros", {
    ownership = {
        { role = "hud.bags", name = "Bagnaros", order = 110, detect = { present = "Bagnaros" } },
        { role = "report.bags", name = "Bagnaros", order = 70, detect = { present = "Bagnaros" } },
    },
    catalogs = {
        Bagnaros = {
            inventory = {position = "adapter", close = "bag-adapter"},
        },
    },
})
