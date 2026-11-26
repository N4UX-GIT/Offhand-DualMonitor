-- RestedXP Guides data bridge (built into Offhand). Facts only: no frame, hook or timer.
-- RestedXP saves its own anchors on logout and reload, so automatic popup recovery leaves RXPFrame,
-- RXPItemFrame and the V2 guide window alone (frame rule preservePopup). V2 exposes an AceGUI
-- widget, RXPV2GuideWindow, whose actual UIParent child (its frame field) is anonymous. That frame
-- is also the anonymous root the missing-window recovery may bring back, reported under the
-- widget's name (frame rule recoverableGuide).
-- Its Escape handling and window catalog stay in the core for now.
-- Registered on every client, like the checks it replaces; the widget is read when asked.

local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local API = type(Offhand) == "table" and Offhand.API
if type(API) ~= "table" or API.BRIDGE_CONTRACT ~= 1 or type(API.RegisterAddonData) ~= "function" then return end

local GUIDE = { widget = { "RXPV2GuideWindow", "frame" } }

API.RegisterAddonData("RestedXP", {
    frameRules = {
        preservePopup = { { names = { "RXPFrame", "RXPItemFrame" } }, GUIDE },
        recoverableGuide = { GUIDE },
    },
})
