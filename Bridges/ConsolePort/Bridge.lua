-- ConsolePort data bridge (built into Offhand). Facts only: no frame, hook or timer.
-- ConsolePort replaces the controller HUD with its own protected bars, so while its global
-- exists Offhand's controller sites stand aside (role hud.controller): no native Gamepad
-- panel anchors, reticle or loot placement, no controller Edit Mode layout or window-mode
-- layout switch, no character setup layout, no learned addon windows, no addon window or
-- Kerzo quest log Escape handling, no gamepad workspace Back or toggle key keep-open. Its
-- secure ring can make the stock Game Menu protected; the Forever Game Menu placement then
-- repairs only the native centre, after ShowUIPanel, through the secure writer.
-- It also owns the action and status bars (hud.actionBars, hud.statusBars), blocks the Edit
-- Mode HUD recovery rebuild (hud.editModeBlocker), is listed among action bar owners in the
-- compatibility report when loaded or present (report.actionBars, after Bartender4, Dominos
-- and EllesmereUIActionBars), and names its crosshair for the panel placement diagnostics
-- (frame rule diagnosticFrame).
-- Registered on every client, like the checks it replaces; the global is read when asked.

local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local API = type(Offhand) == "table" and Offhand.API
if type(API) ~= "table" or API.BRIDGE_CONTRACT ~= 1 or type(API.RegisterAddonData) ~= "function" then return end

local GLOBAL = { global = "ConsolePort" }

API.RegisterAddonData("ConsolePort", {
    ownership = {
        { role = "hud.controller", name = "ConsolePort", detect = GLOBAL },
        { role = "hud.actionBars", name = "ConsolePort", order = 50, detect = GLOBAL },
        { role = "hud.statusBars", name = "ConsolePort", order = 50, detect = GLOBAL },
        { role = "hud.editModeBlocker", name = "ConsolePort", order = 10, detect = GLOBAL },
        { role = "report.actionBars", name = "ConsolePort", order = 40, detect = { present = "ConsolePort" } },
    },
    frameRules = {
        diagnosticFrame = { "ConsolePortCrosshair" },
    },
})
