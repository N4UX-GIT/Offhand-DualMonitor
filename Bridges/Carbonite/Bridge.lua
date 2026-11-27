-- Carbonite data bridge (built into Offhand). Facts only: no frame, hook or timer.
-- Carbonite replaces the minimap: while its global exists Offhand yields MinimapCluster and
-- the detached minimap canvas (hud.minimap, order 20). It is the compatibility report's
-- minimap owner after EllesmereUIMinimap and SexyMap (report.minimap, order 30).
-- Registered on every client, like the checks it replaces; the global is read when asked.

local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local API = type(Offhand) == "table" and Offhand.API
if type(API) ~= "table" or API.BRIDGE_CONTRACT ~= 1 or type(API.RegisterAddonData) ~= "function" then return end

API.RegisterAddonData("Carbonite", {
    ownership = {
        { role = "hud.minimap", name = "Carbonite", order = 20, detect = { global = "Carbonite" } },
        { role = "report.minimap", name = "Carbonite", order = 30, detect = { global = "Carbonite" } },
    },
})
