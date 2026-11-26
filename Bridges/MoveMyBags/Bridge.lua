-- MoveMyBags data bridge (built into Offhand). Facts only: no frame, hook or timer.
-- Ownership facts only for now; MoveMyBags' bag handling stays in the core. It is listed
-- among frame movers in the compatibility report when loaded or present, after MoveAny and
-- BlizzMove (report.movers, order 30), with its guidance line (order 30). On the Forever
-- client that line also names the layers option unless MoveMyBagsDB.layers is false.
-- Registered on every client, like the checks it replaces.

local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local API = type(Offhand) == "table" and Offhand.API
if type(API) ~= "table" or API.BRIDGE_CONTRACT ~= 1 or type(API.RegisterAddonData) ~= "function" then return end

-- The layers option is on unless MoveMyBags saved it as off.
local function LayersEnabled()
    local db = rawget(_G, "MoveMyBagsDB")
    return type(db) ~= "table" or db.layers ~= false
end

API.RegisterAddonData("MoveMyBags", {
    ownership = {
        { role = "report.movers", name = "MoveMyBags", order = 30, detect = { present = "MoveMyBags" } },
    },
    guidance = {
        { id = "movemybags", order = 30, addon = "MoveMyBags", when = { movers = "MoveMyBags" },
            key = "COMPAT_GUIDE_MOVEMYBAGS",
            fallback = "MoveMyBags controls Blizzard bag positions. Drag or reset bags with /movemybags reset, or disable MoveMyBags to let Offhand manage bag placement.",
            suffixWhen = { forever = true, active = LayersEnabled },
            suffixKey = "COMPAT_GUIDE_MOVEMYBAGS_LAYERS",
            suffixFallback = "If a reagent or specialty bag turns grey while dragging, uncheck 'Keep the window you are using in front' in Options > AddOns > MoveMyBags." },
    },
})
