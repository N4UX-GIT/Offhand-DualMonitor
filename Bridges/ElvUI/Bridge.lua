-- ElvUI data bridge (built into Offhand). Facts only: no frame, hook or timer.
-- While the ElvUI global exists Offhand leaves its replacement HUD alone: action and status
-- bars (hud.actionBars, hud.statusBars), the minimap (hud.minimap), the Edit Mode unit
-- frame systems including party and raid (hud.unitFrames, hud.groupFrames), and the Edit
-- Mode HUD recovery rebuild (hud.editModeBlocker). It is part of the saved HUD layout
-- ownership signature when loaded or present (hud.layoutSignature, order 100).
-- In the compatibility report it is the minimap owner after EllesmereUIMinimap, SexyMap
-- and Carbonite (report.minimap, order 40), a unit frame owner when ElvUF_Player exists or
-- its unit frame module is enabled (report.unitFrames, order 30), an action bar owner when
-- ElvUI_Bar1 exists (report.actionBars, order 50), and gets the suite guidance line
-- (order 70). Addon window catalog: the ElvUI suite (suite prefix elvui), whose HUD and
-- movers stay out of the addon window picker.
-- Registered on every client, like the checks it replaces; the globals are read when asked.

local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local API = type(Offhand) == "table" and Offhand.API
if type(API) ~= "table" or API.BRIDGE_CONTRACT ~= 1 or type(API.RegisterAddonData) ~= "function" then return end

local GLOBAL = { global = "ElvUI" }

-- The unit frame module counts once ElvUF_Player exists, or while the addon is loaded
-- and its private unitframe settings say enabled.
local function UnitFramesEnabled()
    if rawget(_G, "ElvUF_Player") ~= nil then return true end
    local elv = rawget(_G, "ElvUI")
    local core = type(elv) == "table" and elv[1]
    local uf = type(core) == "table" and type(core.private) == "table" and core.private.unitframe
    return type(uf) == "table" and uf.enable == true
end

API.RegisterAddonData("ElvUI", {
    ownership = {
        { role = "hud.actionBars", name = "ElvUI", order = 30, detect = GLOBAL },
        { role = "hud.statusBars", name = "ElvUI", order = 30, detect = GLOBAL },
        { role = "hud.minimap", name = "ElvUI", order = 30, detect = GLOBAL },
        { role = "hud.unitFrames", name = "ElvUI", order = 20, detect = GLOBAL },
        { role = "hud.groupFrames", name = "ElvUI", detect = GLOBAL },
        { role = "hud.editModeBlocker", name = "ElvUI", order = 20, detect = GLOBAL },
        { role = "hud.layoutSignature", name = "ElvUI", order = 100, detect = { present = "ElvUI" } },
        { role = "report.minimap", name = "ElvUI", order = 40, detect = GLOBAL },
        { role = "report.unitFrames", name = "ElvUI", order = 30, detect = {
            anyOf = { { global = "ElvUF_Player" }, { loaded = "ElvUI", global = "ElvUI" } },
            active = UnitFramesEnabled,
        } },
        { role = "report.actionBars", name = "ElvUI", order = 50, detect = { global = "ElvUI_Bar1" } },
    },
    guidance = {
        { id = "suite:ElvUI", order = 70, addon = "ElvUI", when = { unitFrames = "ElvUI", actionBars = "ElvUI" },
            key = "COMPAT_GUIDE_SUITE", args = 2,
            fallback = "%s controls its enabled HUD and unit frames. Move them with /moveui, or disable individual modules in %s to use Blizzard Edit Mode." },
    },
    catalogs = {
        ElvUI = {
            suitePrefix = "elvui",
            hud = {position = "addon", close = "native"},
        },
    },
})
