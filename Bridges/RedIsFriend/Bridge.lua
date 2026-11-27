-- RedIsFriend data bridge (built into Offhand). Facts only: no frame, hook or timer.
-- Its window is an ordinary menu: Offhand centres it on Mainhand like the Blizzard menus and
-- settings panels (frame rule menuFrame, after the Blizzard names and BugSack).
-- Registered on every client, like the list entry it replaces.

local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local API = type(Offhand) == "table" and Offhand.API
if type(API) ~= "table" or API.BRIDGE_CONTRACT ~= 1 or type(API.RegisterAddonData) ~= "function" then return end

API.RegisterAddonData("RedIsFriend", {
    frameRules = {
        menuFrame = { "RedIsFriendFrame" },
    },
})
