-- Titan Panel data bridge (built into Offhand). Facts only: no frame, hook or timer.
-- Titan's full-width bars derive their size from two anchors, so automatic popup recovery would
-- collapse that rectangle if it replaced them with one point. A bar is the global frame whose
-- TitanBarData entry names it (frame_name); it keeps its position (frame rule preservePopup).
-- Registered on every client, like the check it replaces; the store is read when asked.

local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local API = type(Offhand) == "table" and Offhand.API
if type(API) ~= "table" or API.BRIDGE_CONTRACT ~= 1 or type(API.RegisterAddonData) ~= "function" then return end

API.RegisterAddonData("Titan", {
    frameRules = {
        preservePopup = { { index = { "TitanBarData", "frame_name" } } },
    },
})
