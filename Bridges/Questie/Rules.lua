-- Questie name rules (built into Offhand). Facts only: no frame, hook or timer.
-- Questie owns TrackerLocation and its Ctrl-drag/lock behaviour. Its reset anchor deliberately
-- uses screen centre and need not be IsUserPlaced, so automatic popup recovery leaves
-- Questie_BaseFrame alone (frame rule preservePopup).
-- Registered on every client through RegisterAddonData, like the check it replaces; the Questie
-- bridge beside it stays limited to Forever with Questie loaded.

local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local API = type(Offhand) == "table" and Offhand.API
if type(API) ~= "table" or API.BRIDGE_CONTRACT ~= 1 or type(API.RegisterAddonData) ~= "function" then return end

API.RegisterAddonData("Questie", {
    frameRules = {
        preservePopup = { "Questie_BaseFrame" },
    },
})
