-- BetterBags data bridge (built into Offhand). Facts only: no frame, hook or timer.
-- BetterBags positions its own bag and bank roots, so automatic popup recovery leaves them alone
-- (frame rule preservePopup): the Classic roots and their anchors, and the Next roots. Next
-- persists its own panel placement and deliberately clears the native user-placed flag after
-- dragging. It has no Classic anchor roots.
-- Its bag handling stays in the core for now.
-- Registered on every client, like the check it replaces.

local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local API = type(Offhand) == "table" and Offhand.API
if type(API) ~= "table" or API.BRIDGE_CONTRACT ~= 1 or type(API.RegisterAddonData) ~= "function" then return end

API.RegisterAddonData("BetterBags", {
    frameRules = {
        preservePopup = {
            { names = {
                "BetterBagsBagBackpack", "BetterBagsBagBank",
                "BetterBagsBagBackpackAnchor", "BetterBagsBagBankAnchor",
                "BetterBagsNextBackpack", "BetterBagsNextBank",
                "BetterBagsNextVendor", "BetterBagsNextGuildBank",
            } },
        },
    },
})
