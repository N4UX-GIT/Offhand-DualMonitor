-- ProcDoc data bridge (built into Offhand). Facts only: no frame, hook or timer.
-- ProcDocAlertFrame is a one-unit presentation anchor that belongs to ProcDoc, including while
-- Offhand's optional Mainhand centering is off. Automatic popup recovery leaves it alone (frame
-- rule preservePopup): it must not supply an offset that the centering adapter would then apply
-- again.
-- The centering adapter itself stays in the core for now.
-- Registered on every client, like the check it replaces.

local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local API = type(Offhand) == "table" and Offhand.API
if type(API) ~= "table" or API.BRIDGE_CONTRACT ~= 1 or type(API.RegisterAddonData) ~= "function" then return end

API.RegisterAddonData("ProcDoc", {
    frameRules = {
        preservePopup = { "ProcDocAlertFrame" },
    },
})
