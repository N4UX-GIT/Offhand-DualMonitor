-- BetterBags data bridge (built into Offhand). Facts only: no frame, hook or timer.
-- BetterBags positions its own bag and bank roots, so automatic popup recovery leaves them alone
-- (frame rule preservePopup): the Classic roots and their anchors, and the Next roots. Next
-- persists its own panel placement and deliberately clears the native user-placed flag after
-- dragging. It has no Classic anchor roots.
-- Addon window catalog: its backpack and bank, which it places and closes itself.
-- Bag facts: it replaces the bags while loaded or present (hud.bags, order 70) and is a bag
-- owner in the compatibility report when loaded or present (report.bags, order 60). Its
-- names join the bag namespace scans of the reload reopen, the logout open-state capture and
-- the single-screen recovery anchor (bagNamespace.openScan, bagNamespace.logoutScan,
-- bagNamespace.recoveryAnchor) and are reload bag roots (bagRestorable). Its bag Escape
-- adapter and toggle binding are in Bags.lua beside this file.
-- Registered on every client, like the check it replaces.

local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local API = type(Offhand) == "table" and Offhand.API
if type(API) ~= "table" or API.BRIDGE_CONTRACT ~= 1 or type(API.RegisterAddonData) ~= "function" then return end

API.RegisterAddonData("BetterBags", {
    ownership = {
        { role = "hud.bags", name = "BetterBags", order = 70, detect = { present = "BetterBags" } },
        { role = "report.bags", name = "BetterBags", order = 60, detect = { present = "BetterBags" } },
    },
    frameRules = {
        ["bagNamespace.openScan"] = { { patterns = { "^BetterBags" } } },
        ["bagNamespace.logoutScan"] = { { patterns = { "^BetterBags" } } },
        ["bagNamespace.recoveryAnchor"] = { { patterns = { "BetterBags" } } },
        bagRestorable = { { patterns = { "^BetterBags" } } },
        preservePopup = {
            { names = {
                "BetterBagsBagBackpack", "BetterBagsBagBank",
                "BetterBagsBagBackpackAnchor", "BetterBagsBagBankAnchor",
                "BetterBagsNextBackpack", "BetterBagsNextBank",
                "BetterBagsNextVendor", "BetterBagsNextGuildBank",
            } },
        },
    },
    catalogs = {
        BetterBags = {
            backpack = {position = "addon", close = "native"},
            bank = {position = "addon", close = "native"},
        },
    },
})
