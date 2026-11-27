-- MobInfo2 bridge (built into Offhand).
-- MobInfo2 shows its mob tooltip hanging off a small movable "MI" anchor, MI2_TooltipAnchor
-- (Frames/MI2_Tooltip.xml), whose default is TOPRIGHT -> UIParent TOPRIGHT -4,-200; "/mi2 resetpos"
-- (MI2_Slash.lua) puts it back there. With Offhand, UIParent spans every monitor, so that spot is
-- the top right corner of the far monitor instead of the game monitor, and the tooltip that hangs
-- off it (MI2_Tooltip.lua) opens there too.
-- This file moves the anchor to the same spot of the game rectangle while it still sits at
-- MobInfo2's default (or where this file last put it). MobInfo2 saves the anchor's current point
-- when the mouse leaves it, so once the player has hovered it, the bridged spot is also MobInfo2's
-- saved spot and comes back that way at the next login.
-- An anchor the player dragged is left alone. The options help tooltip (which MobInfo2 gives
-- Blizzard's default tooltip anchor) and dropdown lists near the seam are not handled here.
-- Contributed by Kintrok (@DCtheGeek).

local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local API = type(Offhand) == "table" and Offhand.API
if type(API) ~= "table" or type(API.GetBridgeNamespace) ~= "function" then return end
local Shared = API.GetBridgeNamespace("Shared")
if type(Shared) ~= "table" or type(Shared.Available) ~= "function" or not Shared.Available("MobInfo2") then return end

local fitter = Shared.NewAnchorFitter({
    MI2_TooltipAnchor = { "TOPRIGHT", "TOPRIGHT", -4, -200 },
})
local bridge = {}

function bridge:Refresh(reason)
    fitter:Refresh()
end

function bridge:GetDiagnostics()
    return Shared.Describe("MobInfo2Anchors", fitter)
end

if Shared.Register("MobInfo2", bridge, fitter) then bridge:Refresh("load") end
