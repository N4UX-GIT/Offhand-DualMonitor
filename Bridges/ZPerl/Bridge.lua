-- ZPerl data bridge (built into Offhand). Facts only: no frame, hook or timer.
-- Listed among unit frame owners in the compatibility report when loaded or present
-- (report.unitFrames, order 70), with the unit frame guidance line (order 110).
-- Registered on every client, like the checks it replaces.

local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local API = type(Offhand) == "table" and Offhand.API
if type(API) ~= "table" or API.BRIDGE_CONTRACT ~= 1 or type(API.RegisterAddonData) ~= "function" then return end

API.RegisterAddonData("ZPerl", {
    ownership = {
        { role = "report.unitFrames", name = "ZPerl", order = 70, detect = { present = "ZPerl" } },
    },
    guidance = {
        { id = "uf:ZPerl", order = 110, addon = "ZPerl", when = { unitFrames = "ZPerl" },
            key = "COMPAT_GUIDE_UNITFRAMES", args = 2,
            fallback = "%s controls its unit frames. Move them in %s's own settings instead of Blizzard Edit Mode." },
    },
})
