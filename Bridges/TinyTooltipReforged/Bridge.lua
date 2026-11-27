-- TinyTooltipReforged data bridge (built into Offhand). Facts only: no frame, hook or timer.
-- TinyTooltipReforged positions tooltips itself, so while its global exists Offhand's popup bounds
-- pass leaves tooltip anchoring to it and names it as the tooltip owner (tooltip.owner, order 30,
-- after TipTac and TinyTooltip).
-- Registered on every client, like the check it replaces; the global is read when asked.

local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local API = type(Offhand) == "table" and Offhand.API
if type(API) ~= "table" or API.BRIDGE_CONTRACT ~= 1 or type(API.RegisterAddonData) ~= "function" then return end

API.RegisterAddonData("TinyTooltipReforged", {
    ownership = {
        { role = "tooltip.owner", name = "TinyTooltipReforged", order = 30,
            detect = { global = "TinyTooltipReforged" } },
    },
})
