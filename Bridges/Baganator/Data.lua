-- Baganator data bridge (built into Offhand). Facts only: no frame, hook or timer.
-- Baganator owns its backpack anchor and also clears IsUserPlaced on drag, so automatic popup
-- recovery leaves its backpack roots alone (frame rule preservePopup). Baganator derives the
-- names of every child region from the backpack root, so a prefix match alone also catches
-- title text, textures and buttons; its actual backpack roots are direct UIParent children.
-- Addon window catalog: its backpack, under Offhand's dedicated bag position, close and
-- reload handling. Its bag persistence stays in the core for now.
-- Registered on every client, like the check it replaces.

local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local API = type(Offhand) == "table" and Offhand.API
if type(API) ~= "table" or API.BRIDGE_CONTRACT ~= 1 or type(API.RegisterAddonData) ~= "function" then return end

API.RegisterAddonData("Baganator", {
    frameRules = {
        preservePopup = {
            { patterns = { "^Baganator_SingleViewBackpackViewFrame", "^Baganator_CategoryViewBackpackViewFrame" },
                parent = "UIParent" },
        },
    },
    catalogs = {
        Baganator = {
            backpack = {position = "adapter", close = "bag-adapter", restoreOpen = "adapter"},
        },
    },
})
