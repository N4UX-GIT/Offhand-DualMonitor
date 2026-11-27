-- Shadowed Unit Frames data bridge (built into Offhand). Facts only: no frame, hook or timer.
-- Listed first among unit frame owners in the compatibility report when the addon is
-- loaded or its ShadowUF global exists (report.unitFrames, order 10), with its guidance
-- line first (order 10).
-- Registered on every client, like the checks it replaces.

local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local API = type(Offhand) == "table" and Offhand.API
if type(API) ~= "table" or API.BRIDGE_CONTRACT ~= 1 or type(API.RegisterAddonData) ~= "function" then return end

API.RegisterAddonData("ShadowedUnitFrames", {
    ownership = {
        { role = "report.unitFrames", name = "ShadowedUnitFrames", order = 10,
            detect = { anyOf = { { loaded = "ShadowedUnitFrames" }, { global = "ShadowUF" } } } },
    },
    guidance = {
        { id = "suf", order = 10, addon = "ShadowedUnitFrames", when = { unitFrames = "ShadowedUnitFrames" },
            key = "COMPAT_GUIDE_SUF",
            fallback = "Shadowed Unit Frames controls Player/Target/Focus frames. Move them with /suf, or disable Shadowed Unit Frames (or specific unit modules) to move them in Blizzard Edit Mode." },
    },
})
