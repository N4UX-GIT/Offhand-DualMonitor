-- Chattynator data bridge (built into Offhand). Facts only: no frame, hook or timer.
-- Chattynator owns the complete chat layout, including Blizzard's shared ChatFrame1EditBox,
-- which it anchors to an unnamed Chattynator window, and the native Combat Log (ChatFrame2),
-- which it reparents into its own holder. While it is loaded or present Offhand leaves chat
-- frames, the edit box and chat persistence alone (hud.chat, order 10). It is part of the
-- saved HUD layout ownership signature (hud.layoutSignature, order 120), a chat owner in
-- the compatibility report when loaded (report.chat, order 10), and listed among the chat
-- providers of the chat diagnostics after EllesmereUIChat (segment Chattynator).
-- Registered on every client, like the checks it replaces.

local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local API = type(Offhand) == "table" and Offhand.API
if type(API) ~= "table" or API.BRIDGE_CONTRACT ~= 1 or type(API.RegisterAddonData) ~= "function" then return end

API.RegisterAddonData("Chattynator", {
    ownership = {
        { role = "hud.chat", name = "Chattynator", order = 10, detect = { present = "Chattynator" } },
        { role = "hud.layoutSignature", name = "Chattynator", order = 120, detect = { present = "Chattynator" } },
        { role = "report.chat", name = "Chattynator", order = 10, detect = { loaded = "Chattynator" } },
    },
    diagnostics = {
        { slot = "chat", order = 20, label = "Chattynator", present = "Chattynator" },
    },
})
