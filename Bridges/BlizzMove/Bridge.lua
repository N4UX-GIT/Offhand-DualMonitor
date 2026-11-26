-- BlizzMove data bridge (built into Offhand). Facts only: no frame, hook or timer.
-- Listed among frame movers in the compatibility report when loaded or present, after
-- MoveAny (report.movers, order 20), with its guidance line (order 40). Its version is listed
-- among the map integrations while loaded (map.integration, order 50).
-- Registered on every client, like the checks it replaces.

local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local API = type(Offhand) == "table" and Offhand.API
if type(API) ~= "table" or API.BRIDGE_CONTRACT ~= 1 or type(API.RegisterAddonData) ~= "function" then return end

API.RegisterAddonData("BlizzMove", {
    ownership = {
        { role = "report.movers", name = "BlizzMove", order = 20, detect = { present = "BlizzMove" } },
        { role = "map.integration", name = "BlizzMove", order = 50 },
    },
    guidance = {
        { id = "blizzmove", order = 40, addon = "BlizzMove", when = { movers = "BlizzMove" },
            key = "COMPAT_GUIDE_BLIZZMOVE",
            fallback = "BlizzMove controls window dragging and scaling. Check /bm if a panel snaps back or resists Offhand placement." },
    },
})
