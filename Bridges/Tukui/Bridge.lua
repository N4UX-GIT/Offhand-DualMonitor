-- Tukui data bridge (built into Offhand). Facts only: no frame, hook or timer.
-- While the Tukui global exists Offhand leaves its action and status bars alone
-- (hud.actionBars, hud.statusBars) and skips the Edit Mode HUD recovery rebuild
-- (hud.editModeBlocker). It is part of the saved HUD layout ownership signature when loaded
-- or present (hud.layoutSignature, order 110). In the compatibility report it is a unit
-- frame owner when TukuiPlayerFrame or TukuiUnitFrames exists (report.unitFrames, order 40),
-- an action bar owner when TukuiActionBars exists (report.actionBars, order 60), and gets
-- the suite guidance line (order 80).
-- Bag facts: it replaces the bags while the Tukui global exists (hud.bags, order 100) and is
-- a bag owner in the compatibility report while TukuiBag exists or its bag settings say
-- enabled (report.bags, order 120).
-- Registered on every client, like the checks it replaces; the globals are read when asked.

local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local API = type(Offhand) == "table" and Offhand.API
if type(API) ~= "table" or API.BRIDGE_CONTRACT ~= 1 or type(API.RegisterAddonData) ~= "function" then return end

local GLOBAL = { global = "Tukui" }

-- The bag module counts once TukuiBag exists, or while its bag settings say enabled.
local function BagsEnabled()
    local tuk = rawget(_G, "Tukui")
    if tuk == nil then return false end
    if rawget(_G, "TukuiBag") ~= nil then return true end
    local cfg = type(tuk) == "table" and tuk[2]
    local bags = type(cfg) == "table" and cfg.Bags
    return type(bags) == "table" and bags.Enable == true
end

API.RegisterAddonData("Tukui", {
    ownership = {
        { role = "hud.bags", name = "Tukui", order = 100, detect = GLOBAL },
        { role = "report.bags", name = "Tukui", order = 120, detect = { global = "Tukui", active = BagsEnabled } },
        { role = "hud.actionBars", name = "Tukui", order = 40, detect = GLOBAL },
        { role = "hud.statusBars", name = "Tukui", order = 40, detect = GLOBAL },
        { role = "hud.editModeBlocker", name = "Tukui", order = 30, detect = GLOBAL },
        { role = "hud.layoutSignature", name = "Tukui", order = 110, detect = { present = "Tukui" } },
        { role = "report.unitFrames", name = "Tukui", order = 40,
            detect = { anyOf = { { global = "TukuiPlayerFrame" }, { global = "TukuiUnitFrames" } } } },
        { role = "report.actionBars", name = "Tukui", order = 60, detect = { global = "TukuiActionBars" } },
    },
    guidance = {
        { id = "suite:Tukui", order = 80, addon = "Tukui", when = { unitFrames = "Tukui", actionBars = "Tukui" },
            key = "COMPAT_GUIDE_SUITE", args = 2,
            fallback = "%s controls its enabled HUD and unit frames. Move them with /moveui, or disable individual modules in %s to use Blizzard Edit Mode." },
    },
})
