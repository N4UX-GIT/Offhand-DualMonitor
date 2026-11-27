-- XPerl data bridge (built into Offhand). Facts only: no frame, hook or timer.
-- Listed among unit frame owners in the compatibility report when loaded or present
-- (report.unitFrames, order 80), with the unit frame guidance line (order 120).
-- Registered on every client, like the checks it replaces.

local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local API = type(Offhand) == "table" and Offhand.API
if type(API) ~= "table" or API.BRIDGE_CONTRACT ~= 1 or type(API.RegisterAddonData) ~= "function" then return end

API.RegisterAddonData("XPerl", {
    ownership = {
        { role = "report.unitFrames", name = "XPerl", order = 80, detect = { present = "XPerl" } },
    },
    guidance = {
        { id = "uf:XPerl", order = 120, addon = "XPerl", when = { unitFrames = "XPerl" },
            key = "COMPAT_GUIDE_UNITFRAMES", args = 2,
            fallback = "%s controls its unit frames. Move them in %s's own settings instead of Blizzard Edit Mode." },
    },
})
