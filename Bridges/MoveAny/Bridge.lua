-- MoveAny data bridge (built into Offhand). Facts only: no frame, hook or timer.
-- Ownership facts only for now; MoveAny's world map and panel handling stay in the core.
-- While a MoveAny or MoveAnything global exists the Edit Mode HUD recovery rebuild stands
-- aside (hud.editModeBlocker, order 40). MoveAny is the first frame mover in the
-- compatibility report when either global exists or either addon is loaded
-- (report.movers, order 10), with its guidance line (order 20). Addon window catalog: its
-- world map, under MoveAny's own geometry and the dedicated map policy.
-- Registered on every client, like the checks it replaces; the globals are read when asked.

local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local API = type(Offhand) == "table" and Offhand.API
if type(API) ~= "table" or API.BRIDGE_CONTRACT ~= 1 or type(API.RegisterAddonData) ~= "function" then return end

API.RegisterAddonData("MoveAny", {
    ownership = {
        { role = "hud.editModeBlocker", name = "MoveAny", order = 40,
            detect = { anyOf = { { global = "MoveAny" }, { global = "MoveAnything" } } } },
        { role = "report.movers", name = "MoveAny", order = 10, detect = { anyOf = {
            { global = "MoveAny" }, { global = "MoveAnything" }, { loaded = "MoveAny" }, { loaded = "MoveAnything" },
        } } },
    },
    guidance = {
        { id = "moveany", order = 20, addon = "MoveAny", when = { movers = "MoveAny" },
            key = "COMPAT_GUIDE_MOVEANY",
            fallback = "MoveAny controls frame movement. Move or unlock frames with /move, or disable an element in MoveAny to let Blizzard Edit Mode or Offhand move it." },
    },
    catalogs = {
        MoveAny = {
            worldMap = {position = "addon", close = "map-adapter"},
        },
    },
})
