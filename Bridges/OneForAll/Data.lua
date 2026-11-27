-- OneForAll data bridge (built into Offhand). Facts only: no frame, hook or timer.
-- OneForAll marks each window it can move with frame.ofaMovable = true and sets frame.ofaMoving
-- while it drags one (moverFields). Offhand's panel anchor repair, workspace repair and Forever
-- Game Menu placement read those marks: a movable frame's TOPLEFT/UIParent/BOTTOMLEFT write is
-- repaired before render, and a moving frame is never repaired.
-- Its conflict report and diagnostics are in Bridge.lua beside it.
-- Registered on every client, like the field reads it replaces.

local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local API = type(Offhand) == "table" and Offhand.API
if type(API) ~= "table" or API.BRIDGE_CONTRACT ~= 1 or type(API.RegisterAddonData) ~= "function" then return end

API.RegisterAddonData("OneForAll", {
    moverFields = {
        movable = { "ofaMovable" },
        moving = { "ofaMoving" },
    },
})
