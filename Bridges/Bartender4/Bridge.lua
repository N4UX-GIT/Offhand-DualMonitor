-- Bartender4 data bridge (built into Offhand). Facts only: no frame, hook or timer.
-- Bartender4 replaces the action and status bars: while its global exists Offhand leaves
-- those Edit Mode systems and frames alone (hud.actionBars, hud.statusBars). It is part of
-- the saved HUD layout ownership signature (hud.layoutSignature, order 80), is listed among
-- action bar owners in the compatibility report when loaded or present (report.actionBars,
-- order 10) and gets the action bar guidance line (order 50).
-- Registered on every client, like the checks it replaces; the global is read when asked.

local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local API = type(Offhand) == "table" and Offhand.API
if type(API) ~= "table" or API.BRIDGE_CONTRACT ~= 1 or type(API.RegisterAddonData) ~= "function" then return end

API.RegisterAddonData("Bartender4", {
    ownership = {
        { role = "hud.actionBars", name = "Bartender4", order = 10, detect = { global = "Bartender4" } },
        { role = "hud.statusBars", name = "Bartender4", order = 10, detect = { global = "Bartender4" } },
        { role = "hud.layoutSignature", name = "Bartender4", order = 80, detect = { present = "Bartender4" } },
        { role = "report.actionBars", name = "Bartender4", order = 10, detect = { present = "Bartender4" } },
    },
    guidance = {
        { id = "ab:Bartender4", order = 50, addon = "Bartender4", when = { actionBars = "Bartender4" },
            key = "COMPAT_GUIDE_ACTIONBARS", args = 2,
            fallback = "%s controls action bars. Unlock and move bars in %s instead of Blizzard Edit Mode." },
    },
})
