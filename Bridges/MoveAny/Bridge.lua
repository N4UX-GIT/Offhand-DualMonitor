-- MoveAny data bridge (built into Offhand). Facts only: no frame, hook or timer.
-- While a MoveAny or MoveAnything global exists the Edit Mode HUD recovery rebuild stands
-- aside (hud.editModeBlocker, order 40). MoveAny is the first frame mover in the
-- compatibility report when either global exists or either addon is loaded
-- (report.movers, order 10), with its guidance line (order 20). Addon window catalog: its
-- world map, under MoveAny's own geometry and the dedicated map policy.
-- MoveAny registers and manages WorldMapFrame on every supported modern client, so while it
-- is present (the same test) it is the first World Map owner (map.owner, order 10): Offhand
-- leaves scale, anchor, persistence, drag and post-toggle behavior to it while retaining
-- dormant Offhand coordinates, keeps Escape protection for the map on Forever only
-- (escapeProtection), where MoveAny keeps the map's placement and reopening, and bootstraps
-- only an anchorless shown map (bootstrapsAnchor): MoveAny can yield Retail's WorldMapFrame
-- when another addon made it movable. It also manages the native panels
-- (map.blocksPanelManagement, order 10) and their slots (map.blocksSlotRepair). Diagnostics:
-- "MoveAny=loaded" or "MoveAny=absent" first in the compatibility line (compat.head), and
-- the MoveAny and MoveAnything versions among the map integrations (map.integration, orders
-- 60 and 70).
-- Registered on every client, like the checks it replaces; the globals are read when asked.

local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local API = type(Offhand) == "table" and Offhand.API
if type(API) ~= "table" or API.BRIDGE_CONTRACT ~= 1 or type(API.RegisterAddonData) ~= "function" then return end

local PRESENT = { anyOf = {
    { global = "MoveAny" }, { global = "MoveAnything" }, { loaded = "MoveAny" }, { loaded = "MoveAnything" },
} }

API.RegisterAddonData("MoveAny", {
    ownership = {
        { role = "hud.editModeBlocker", name = "MoveAny", order = 40,
            detect = { anyOf = { { global = "MoveAny" }, { global = "MoveAnything" } } } },
        { role = "report.movers", name = "MoveAny", order = 10, detect = PRESENT },
        { role = "map.owner", name = "MoveAny", order = 10, detect = PRESENT,
            escapeProtection = "forever", bootstrapsAnchor = true },
        { role = "map.blocksPanelManagement", name = "MoveAny", order = 10, detect = PRESENT },
        { role = "map.blocksSlotRepair", name = "MoveAny", order = 10, detect = PRESENT },
        { role = "map.integration", name = "MoveAny", order = 60 },
        { role = "map.integration", name = "MoveAnything", order = 70 },
    },
    guidance = {
        { id = "moveany", order = 20, addon = "MoveAny", when = { movers = "MoveAny" },
            key = "COMPAT_GUIDE_MOVEANY",
            fallback = "MoveAny controls frame movement. Move or unlock frames with /move, or disable an element in MoveAny to let Blizzard Edit Mode or Offhand move it." },
    },
    diagnostics = {
        { slot = "compat.head", order = 10, label = "MoveAny", detect = PRESENT, absent = "absent" },
    },
    catalogs = {
        MoveAny = {
            worldMap = {position = "addon", close = "map-adapter"},
        },
    },
})
