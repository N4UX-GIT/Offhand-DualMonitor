-- Bagnon data bridge (built into Offhand). Facts only: no frame, hook or timer.
-- Addon window catalog: its inventory, under Offhand's dedicated bag position, close and
-- reload handling with Bagnon's inventory manager. Its bag persistence stays in the core
-- for now.
-- Bag facts: it replaces the bags while the Bagnon global exists (hud.bags, order 40) and is
-- a bag owner in the compatibility report when loaded or present (report.bags, order 40).
-- Its names join the bag namespace scans of the reload reopen, the logout open-state capture
-- and the single-screen recovery anchor (bagNamespace.openScan, bagNamespace.logoutScan,
-- bagNamespace.recoveryAnchor) and are reload bag roots (bagRestorable). Its inventory
-- toggle binding is in Bags.lua beside this file.
-- Registered on every client, like the catalog entry it replaces.

local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local API = type(Offhand) == "table" and Offhand.API
if type(API) ~= "table" or API.BRIDGE_CONTRACT ~= 1 or type(API.RegisterAddonData) ~= "function" then return end

API.RegisterAddonData("Bagnon", {
    ownership = {
        { role = "hud.bags", name = "Bagnon", order = 40, detect = { global = "Bagnon" } },
        { role = "report.bags", name = "Bagnon", order = 40, detect = { present = "Bagnon" } },
    },
    frameRules = {
        ["bagNamespace.openScan"] = { { patterns = { "^Bagnon" } } },
        ["bagNamespace.logoutScan"] = { { patterns = { "^Bagnon" } } },
        ["bagNamespace.recoveryAnchor"] = { { patterns = { "Bagnon" } } },
        bagRestorable = { { patterns = { "^Bagnon" } } },
    },
    catalogs = {
        Bagnon = {
            inventory = {position = "adapter", close = "bag-adapter", restoreOpen = "adapter"},
        },
    },
})
