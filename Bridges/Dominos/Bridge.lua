-- Dominos data bridge (built into Offhand). Facts only: no frame, hook or timer.
-- Dominos replaces the action and status bars: while its global exists Offhand leaves
-- those Edit Mode systems and frames alone (hud.actionBars, hud.statusBars). It is part of
-- the saved HUD layout ownership signature (hud.layoutSignature, order 90), is listed among
-- action bar owners in the compatibility report when loaded or present (report.actionBars,
-- order 20) and gets the action bar guidance line (order 60).
-- Registered on every client, like the checks it replaces; the global is read when asked.

local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local API = type(Offhand) == "table" and Offhand.API
if type(API) ~= "table" or API.BRIDGE_CONTRACT ~= 1 or type(API.RegisterAddonData) ~= "function" then return end

API.RegisterAddonData("Dominos", {
    ownership = {
        { role = "hud.actionBars", name = "Dominos", order = 20, detect = { global = "Dominos" } },
        { role = "hud.statusBars", name = "Dominos", order = 20, detect = { global = "Dominos" } },
        { role = "hud.layoutSignature", name = "Dominos", order = 90, detect = { present = "Dominos" } },
        { role = "report.actionBars", name = "Dominos", order = 20, detect = { present = "Dominos" } },
    },
    guidance = {
        { id = "ab:Dominos", order = 60, addon = "Dominos", when = { actionBars = "Dominos" },
            key = "COMPAT_GUIDE_ACTIONBARS", args = 2,
            fallback = "%s controls action bars. Unlock and move bars in %s instead of Blizzard Edit Mode." },
    },
})
