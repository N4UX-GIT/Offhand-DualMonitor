-- ArkInventory data bridge (built into Offhand). Facts only: no frame, hook or timer.
-- Addon window catalog: its inventory, under Offhand's dedicated bag Escape handling and
-- kept out of the addon window picker.
-- Bag facts: it replaces the bags while the ArkInventory global exists (hud.bags, order 60)
-- and is a bag owner in the compatibility report when loaded or present (report.bags, order
-- 50). Its names join the bag namespace scans of the reload reopen and the logout open-state
-- capture (bagNamespace.openScan, bagNamespace.logoutScan) and are reload bag roots
-- (bagRestorable). Its bag Escape adapter and toggle binding are in Bags.lua beside this file.
-- Registered on every client, like the catalog entry it replaces.

local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local API = type(Offhand) == "table" and Offhand.API
if type(API) ~= "table" or API.BRIDGE_CONTRACT ~= 1 or type(API.RegisterAddonData) ~= "function" then return end

API.RegisterAddonData("ArkInventory", {
    ownership = {
        { role = "hud.bags", name = "ArkInventory", order = 60, detect = { global = "ArkInventory" } },
        { role = "report.bags", name = "ArkInventory", order = 50, detect = { present = "ArkInventory" } },
    },
    frameRules = {
        ["bagNamespace.openScan"] = { { patterns = { "^ArkInventory" } } },
        ["bagNamespace.logoutScan"] = { { patterns = { "^ArkInventory" } } },
        bagRestorable = { { patterns = { "^ArkInventory" } } },
    },
    catalogs = {
        ArkInventory = {
            inventory = {position = "adapter", close = "bag-adapter"},
        },
    },
})
