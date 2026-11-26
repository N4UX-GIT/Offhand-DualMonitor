-- SexyMap data bridge (built into Offhand). Facts only: no frame, hook or timer.
-- SexyMap replaces the minimap: while its global exists Offhand yields MinimapCluster and
-- the detached minimap canvas (hud.minimap, order 10). It is the compatibility report's
-- minimap owner after EllesmereUIMinimap (report.minimap, order 20) and leads the minimap
-- visibility diagnostics (segment SexyMap, loaded or present).
-- Registered on every client, like the checks it replaces; the global is read when asked.

local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local API = type(Offhand) == "table" and Offhand.API
if type(API) ~= "table" or API.BRIDGE_CONTRACT ~= 1 or type(API.RegisterAddonData) ~= "function" then return end

API.RegisterAddonData("SexyMap", {
    ownership = {
        { role = "hud.minimap", name = "SexyMap", order = 10, detect = { global = "SexyMap" } },
        { role = "report.minimap", name = "SexyMap", order = 20, detect = { global = "SexyMap" } },
    },
    diagnostics = {
        { slot = "minimap", order = 10, label = "SexyMap", present = "SexyMap" },
    },
})
