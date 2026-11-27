-- Details! data bridge (built into Offhand). Facts only: no frame, hook or timer.
-- Details owns each numbered meter window through its instance/LibWindow store, and its drag
-- completion clears IsUserPlaced, so automatic popup recovery leaves DetailsBaseFrame<n> alone
-- (frame rule preservePopup). Its configuration dialogs are separate frames and are not matched.
-- Registered on every client, like the check it replaces.

local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local API = type(Offhand) == "table" and Offhand.API
if type(API) ~= "table" or API.BRIDGE_CONTRACT ~= 1 or type(API.RegisterAddonData) ~= "function" then return end

API.RegisterAddonData("Details", {
    frameRules = {
        preservePopup = { { patterns = { "^DetailsBaseFrame%d+$" } } },
    },
})
