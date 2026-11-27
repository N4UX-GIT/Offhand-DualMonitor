-- Beastfinder bridge (built into Offhand).
-- Beastfinder shows a "new beast found" card when the player meets a beast worth taming. The card
-- (BeastfinderNewBeastCard, a kit panel on UIParent, UI/NewBeastAlert.lua) is placed by A.PlaceToast
-- at TOP -> UIParent TOP 0,-170 (CARD_DEFAULT_Y in UI/Look.lua) every time it is painted, unless the
-- player dragged it somewhere. With Offhand, UIParent spans every monitor, so that spot is the top of
-- the seam between monitors instead of the top of the game monitor.
-- This file moves the card to the same spot of the game rectangle while it still sits at
-- Beastfinder's own default (or where this file last put it), when it shows and on every refresh.
-- A card the player dragged is saved by Beastfinder as a TOPLEFT/BOTTOMLEFT anchor and is left
-- alone, as is every other Beastfinder window (the kit remembers where the player put them).
-- Contributed by Kintrok (@DCtheGeek).

local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local API = type(Offhand) == "table" and Offhand.API
if type(API) ~= "table" or type(API.GetBridgeNamespace) ~= "function" then return end
local Shared = API.GetBridgeNamespace("Shared")
if type(Shared) ~= "table" or type(Shared.Available) ~= "function" or not Shared.Available("Beastfinder") then return end

local fitter = Shared.NewAnchorFitter({
    BeastfinderNewBeastCard = { "TOP", "TOP", 0, -170 },
})
local bridge = {}

function bridge:Refresh(reason)
    fitter:Refresh()
end

function bridge:GetDiagnostics()
    return Shared.Describe("BeastfinderAnchors", fitter)
end

if Shared.Register("Beastfinder", bridge) then bridge:Refresh("load") end
