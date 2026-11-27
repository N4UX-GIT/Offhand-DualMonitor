-- FlareUI data bridge (built into Offhand). Facts only: no frame, hook or timer.
-- Addon window catalog: the FlareUI suite (suite prefix flareui), whose HUD and movers stay
-- out of the addon window picker.
-- Registered on every client, like the catalog entry it replaces.

local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local API = type(Offhand) == "table" and Offhand.API
if type(API) ~= "table" or API.BRIDGE_CONTRACT ~= 1 or type(API.RegisterAddonData) ~= "function" then return end

API.RegisterAddonData("FlareUI", {
    catalogs = {
        FlareUI = {
            suitePrefix = "flareui",
            hud = {position = "addon", close = "native"},
        },
    },
})
