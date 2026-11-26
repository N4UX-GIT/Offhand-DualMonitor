-- EllesmereUI data bridge (built into Offhand). Facts only: no frame, hook or timer.
-- Ownership facts only for now; the layout transfer, scale and bag handling stay in the core.
-- EllesmereUI ships one addon folder per module; each module owns its frame family while
-- loaded or present: ActionBars the action bars (hud.actionBars) and, unless the player opts
-- back into Blizzard's XP/Rep bars, the status bars (hud.statusBars); Minimap the minimap
-- (hud.minimap); Chat the chat frames (hud.chat); RaidFrames the party and raid frames, which
-- the player positions in EllesmereUI Unlock Mode (hud.partyFrames, notice
-- COMPAT_ELLESMERE_PARTY); UnitFrames, CooldownManager and QuestTracker their Edit Mode
-- systems (hud.unitFrames, hud.cooldownViewer, hud.objectiveTracker).
-- The seven modules lead the saved HUD layout ownership signature (hud.layoutSignature,
-- orders 10 to 70). ActionBars is the status owner there ("native-status" marks Blizzard's
-- XP/Rep bars), and a new owner matching ^EllesmereUI counts as the suite gaining ownership.
-- In the compatibility report: ActionBars (report.actionBars, order 30, loaded or present),
-- Chat (report.chat, order 20, loaded), Minimap first (report.minimap, order 10, loaded),
-- UnitFrames (report.unitFrames, order 20, loaded), and the EllesmereUI guidance line
-- (order 90). Diagnostics: EllesmereUIChat leads the chat providers, and the minimap
-- visibility report names the core, Minimap and Options folders, the unlock mover and the
-- minimap profile switch after SexyMap.
-- Registered on every client, like the checks it replaces.

local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local API = type(Offhand) == "table" and Offhand.API
if type(API) ~= "table" or API.BRIDGE_CONTRACT ~= 1 or type(API.RegisterAddonData) ~= "function" then return end

local SUITE = "^EllesmereUI"

local function Present(name) return { present = name } end

-- DataBars is a separate information-panel module, not the native XP/Rep
-- replacement. ActionBars owns that replacement unless the player opts back
-- into Blizzard's bars. Read its cross-addon accessor without changing state.
local function OwnsStatusBars()
    local lite = _G.EllesmereUI and _G.EllesmereUI.Lite
    if lite and type(lite.GetAddon) == "function" then
        local ok, addon = pcall(lite.GetAddon, "EllesmereUIActionBars", true)
        local profile = ok and addon and addon.db and addon.db.profile
        if profile and profile.useBlizzardDataBars == true then return false end
    end
    return true
end

local function MinimapMover()
    local eui = _G.EllesmereUI
    local registered = eui and eui._unlockRegisteredElements and eui._unlockRegisteredElements.EBS_Minimap
    return registered and "registered" or "missing"
end

local function MinimapProfileEnabled()
    local eui = _G.EllesmereUI
    local get = eui and eui.Lite and eui.Lite.GetAddon
    local module = type(get) == "function" and get("EllesmereUIMinimap", true)
    return module and module.db and module.db.profile and module.db.profile.minimap
        and module.db.profile.minimap.enabled
end

API.RegisterAddonData("EllesmereUI", {
    ownership = {
        { role = "hud.actionBars", name = "EllesmereUIActionBars", order = 60, detect = Present("EllesmereUIActionBars") },
        { role = "hud.statusBars", name = "EllesmereUIActionBars", order = 60,
            detect = { present = "EllesmereUIActionBars", active = OwnsStatusBars } },
        { role = "hud.minimap", name = "EllesmereUIMinimap", order = 40, detect = Present("EllesmereUIMinimap") },
        { role = "hud.chat", name = "EllesmereUIChat", order = 20, detect = Present("EllesmereUIChat") },
        { role = "hud.partyFrames", name = "EllesmereUIRaidFrames", detect = Present("EllesmereUIRaidFrames"),
            noticeKey = "COMPAT_ELLESMERE_PARTY" },
        { role = "hud.unitFrames", name = "EllesmereUIUnitFrames", order = 10, detect = Present("EllesmereUIUnitFrames") },
        { role = "hud.cooldownViewer", name = "EllesmereUICooldownManager", detect = Present("EllesmereUICooldownManager") },
        { role = "hud.objectiveTracker", name = "EllesmereUIQuestTracker", detect = Present("EllesmereUIQuestTracker") },
        { role = "hud.layoutSignature", name = "EllesmereUIActionBars", order = 10, detect = Present("EllesmereUIActionBars"),
            suitePattern = SUITE, statusOwner = true },
        { role = "hud.layoutSignature", name = "EllesmereUIMinimap", order = 20, detect = Present("EllesmereUIMinimap"),
            suitePattern = SUITE },
        { role = "hud.layoutSignature", name = "EllesmereUIChat", order = 30, detect = Present("EllesmereUIChat"),
            suitePattern = SUITE },
        { role = "hud.layoutSignature", name = "EllesmereUICooldownManager", order = 40,
            detect = Present("EllesmereUICooldownManager"), suitePattern = SUITE },
        { role = "hud.layoutSignature", name = "EllesmereUIQuestTracker", order = 50,
            detect = Present("EllesmereUIQuestTracker"), suitePattern = SUITE },
        { role = "hud.layoutSignature", name = "EllesmereUIUnitFrames", order = 60,
            detect = Present("EllesmereUIUnitFrames"), suitePattern = SUITE },
        { role = "hud.layoutSignature", name = "EllesmereUIRaidFrames", order = 70,
            detect = Present("EllesmereUIRaidFrames"), suitePattern = SUITE },
        { role = "report.actionBars", name = "EllesmereUIActionBars", order = 30, detect = Present("EllesmereUIActionBars") },
        { role = "report.chat", name = "EllesmereUIChat", order = 20, detect = { loaded = "EllesmereUIChat" } },
        { role = "report.minimap", name = "EllesmereUIMinimap", order = 10, detect = { loaded = "EllesmereUIMinimap" } },
        { role = "report.unitFrames", name = "EllesmereUIUnitFrames", order = 20, detect = { loaded = "EllesmereUIUnitFrames" } },
    },
    guidance = {
        { id = "ellesmere", order = 90, addon = "EllesmereUI",
            when = { unitFrames = "EllesmereUIUnitFrames", actionBars = "EllesmereUIActionBars", chat = "EllesmereUIChat" },
            key = "COMPAT_GUIDE_ELLESMERE",
            fallback = "EllesmereUI controls its enabled HUD modules. Position them in EllesmereUI's own unlock/layout settings instead of Blizzard Edit Mode." },
    },
    diagnostics = {
        { slot = "chat", order = 10, label = "EllesmereUIChat", present = "EllesmereUIChat" },
        { slot = "minimap", order = 20, label = "EllesmereCore", present = "EllesmereUI" },
        { slot = "minimap", order = 30, label = "EllesmereMinimap", present = "EllesmereUIMinimap" },
        { slot = "minimap", order = 40, label = "EllesmereOptions", present = "EllesmereUIOptions" },
        { slot = "minimap", order = 50, label = "EllesmereMover", value = MinimapMover },
        { slot = "minimap", order = 60, label = "EllesmereProfileEnabled", value = MinimapProfileEnabled },
    },
})
