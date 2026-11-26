-- Baganator data bridge (built into Offhand). Facts only: no frame, hook or timer.
-- Baganator owns its backpack anchor and also clears IsUserPlaced on drag, so automatic popup
-- recovery leaves its backpack roots alone (frame rule preservePopup). Baganator derives the
-- names of every child region from the backpack root, so a prefix match alone also catches
-- title text, textures and buttons; its actual backpack roots are direct UIParent children.
-- Addon window catalog: its backpack, under Offhand's dedicated bag position, close and
-- reload handling. Its bag persistence stays in the core for now.
-- Bag facts: it replaces the bags while the Baganator or Baginator global exists (hud.bags,
-- order 30), is a bag owner in the compatibility report when loaded or present (report.bags,
-- order 30, part of the bags-conflict id), and restores its own roots, so the generic reload
-- bag reopen stands aside while its global exists (bags.selfRestoring). Its root and child
-- names (also the Baginator and BGR spellings) join the bag namespace scans of the reload
-- reopen (bagNamespace.openScan), the logout open-state capture (bagNamespace.logoutScan,
-- without BGR) and the single-screen recovery anchor (bagNamespace.recoveryAnchor,
-- unanchored); its backpack roots, Baginator and BGR are reload bag roots (bagRestorable),
-- and its backpack roots keep their open state in the custom bag workspace record
-- (customBagRoot). That record keeps its stored key baganatorWorkspacePanels (setting
-- customBagWorkspacePanels), which the EllesmereUI bag shares.
-- Registered on every client, like the check it replaces.

local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local API = type(Offhand) == "table" and Offhand.API
if type(API) ~= "table" or API.BRIDGE_CONTRACT ~= 1 or type(API.RegisterAddonData) ~= "function" then return end

API.RegisterAddonData("Baganator", {
    ownership = {
        { role = "hud.bags", name = "Baganator", order = 30,
            detect = { anyOf = { { global = "Baganator" }, { global = "Baginator" } } } },
        { role = "report.bags", name = "Baganator", order = 30, detect = { present = "Baganator" } },
        { role = "bags.selfRestoring", name = "Baganator", detect = { global = "Baganator" } },
    },
    frameRules = {
        preservePopup = {
            { patterns = { "^Baganator_SingleViewBackpackViewFrame", "^Baganator_CategoryViewBackpackViewFrame" },
                parent = "UIParent" },
        },
        ["bagNamespace.openScan"] = { { patterns = { "^Baganator", "^Baginator", "^BGR" } } },
        ["bagNamespace.logoutScan"] = { { patterns = { "^Baganator", "^Baginator" } } },
        ["bagNamespace.recoveryAnchor"] = { { patterns = { "Baganator", "Baginator" } } },
        bagRestorable = {
            { patterns = { "^Baganator_SingleViewBackpackViewFrame", "^Baganator_CategoryViewBackpackViewFrame",
                "^Baginator", "^BGR" } },
        },
        customBagRoot = { { patterns = { "^Baganator_.*BackpackViewFrame" } } },
    },
    settings = {
        customBagWorkspacePanels = { store = "profile", legacyKey = "baganatorWorkspacePanels" },
    },
    catalogs = {
        Baganator = {
            backpack = {position = "adapter", close = "bag-adapter", restoreOpen = "adapter"},
        },
    },
})
