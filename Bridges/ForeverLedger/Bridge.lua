-- ForeverLedger bridge (built into Offhand).
-- ForeverLedger opens its windows with one anchor on UIParent: UI.lua's
-- ns.ThemedWindow centres every named window, Customers.lua then pins the
-- customers window to UIParent's top-right corner (it opens by itself on a
-- trade-chat request), QuickDisenchant.lua puts the disenchant window right of
-- the centre, and Sessions.lua hangs the session tracker from UIParent's top
-- unless a spot was saved. With Offhand spanning UIParent across monitors, the
-- centre and top are the seam between monitors and the top-right corner is the
-- far monitor. BuyQueue.lua re-centres the side panel on UIParent with
-- SetPoint("CENTER") every time it opens away from the auction house.
--
-- This file moves each of those windows, while it still sits at ForeverLedger's
-- own default spot, to the same spot of the game rectangle. The session window
-- (SessionWindow.lua) hangs under the tracker until dragged, so it follows the
-- tracker by itself. A window the player dragged is left alone, and so is the
-- side panel while it is docked beside the auction house (two anchors on the
-- auction house frame). The disenchant window's secure child button moves with
-- its window, which this file never touches in combat.
-- Contributed by Kintrok (@DCtheGeek).

local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local API = type(Offhand) == "table" and Offhand.API
if type(API) ~= "table" or type(API.GetBridgeNamespace) ~= "function" then return end
local Shared = API.GetBridgeNamespace("Shared")
if type(Shared) ~= "table" or type(Shared.Available) ~= "function" or not Shared.Available("ForeverLedger") then return end

-- frame name -> { point, relativePoint, x, y }: ForeverLedger's own default anchor on UIParent.
local fitter = Shared.NewAnchorFitter({
    ForeverLedgerCustomers = { "TOPRIGHT", "TOPRIGHT", -260, -160 },   -- Customers.lua
    ForeverLedgerDisenchant = { "CENTER", "CENTER", 220, 0 },          -- QuickDisenchant.lua
    ForeverLedgerSessionTracker = { "TOP", "TOP", 0, -140 },           -- Sessions.lua, when no spot is saved
    ForeverLedgerSidePanel = { "CENTER", "CENTER", 0, 0 },             -- BuyQueue.lua place(), away from the auction house
})
local bridge = {}

function bridge:Refresh(reason)
    fitter:Refresh()
end

function bridge:GetDiagnostics()
    return Shared.Describe("ForeverLedgerAnchors", fitter)
end

if Shared.Register("ForeverLedger", bridge) then bridge:Refresh("load") end
