-- RareScanner bridge (built into Offhand).
-- RareScanner places several frames on UIParent's centre, top or bottom. With Offhand, UIParent
-- spans every monitor, so those spots land on the seam between monitors instead of the game monitor:
-- - the rare-found button RARESCANNER_BUTTON (RareScanner.lua: secure, ignores its parent's scale,
--   BOTTOM -> UIParent BOTTOM 0,128),
-- - the explorer window RSExplorerFrame (RSExplorerTemplate.xml: CENTER),
-- - its bundled LibDialog dialogs LibDialog-1.0RS_Dialog1..4 (LibDialog-1.0.lua: the first at
--   TOP -> UIParent TOP 0,-135, the rest hang under it; re-anchored on every spawn and dismiss).
-- This file moves each of them to the same spot of the game rectangle while it still sits at
-- RareScanner's default (or where this file last put it). The secure button waits for combat to end.
-- RareScanner also saves the button's spot: RareScanner:ResetPosition() puts the button at the
-- default and at once saves GetLeft(), GetBottom() into the profile (RSGeneralDB.lua), and at the
-- next login OnPlayerLogin (RSEventHandler.lua) restores it as BOTTOMLEFT x,y, i.e. on the seam.
-- So after a reset this file saves the moved spot instead, and once per session it repairs a saved
-- spot that is exactly the old seam default ("legacy seam").
-- A frame the player dragged is left alone. Map pin tooltips (their side is picked by the bundled
-- LibQTip from thirds of the whole UIParent) and the chat-link tooltip are not handled here.
-- Contributed by Kintrok (@DCtheGeek).

local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local API = type(Offhand) == "table" and Offhand.API
if type(API) ~= "table" or type(API.GetBridgeNamespace) ~= "function" then return end
local Shared = API.GetBridgeNamespace("Shared")
if type(Shared) ~= "table" or type(Shared.Available) ~= "function" or not Shared.Available("RareScanner") then return end

local BUTTON = "RARESCANNER_BUTTON"

local fitter = Shared.NewAnchorFitter({
    RARESCANNER_BUTTON = { "BOTTOM", "BOTTOM", 0, 128 },
    RSExplorerFrame = { "CENTER", "CENTER", 0, 0 },
    ["LibDialog-1.0RS_Dialog1"] = { "TOP", "TOP", 0, -135 },
    ["LibDialog-1.0RS_Dialog2"] = { "TOP", "TOP", 0, -135 },
    ["LibDialog-1.0RS_Dialog3"] = { "TOP", "TOP", 0, -135 },
    ["LibDialog-1.0RS_Dialog4"] = { "TOP", "TOP", 0, -135 },
})
local bridge = {}

-- ---------------------------------------------------------------------
-- The button's saved spot
-- ---------------------------------------------------------------------

local hooked, pendingSave, legacyDone = false, false, false
local saves = 0

local function addon()
    local lib = LibStub and LibStub("AceAddon-3.0", true)
    if type(lib) ~= "table" or type(lib.GetAddon) ~= "function" then return nil end
    local ok, rs = pcall(lib.GetAddon, lib, "RareScanner", true)
    if ok and type(rs) == "table" then return rs end
    return nil
end

local function profile()
    local rs = addon()
    local db = rs and rs.db
    if type(db) == "table" and type(db.profile) == "table" then return db.profile end
    return nil
end

-- Writes the button's current spot, in the button's own units, as RareScanner does.
local function writeSpot(button, data)
    local x, y = button:GetLeft(), button:GetBottom()
    if type(x) ~= "number" or type(y) ~= "number" then return false end
    data.scannerXPos, data.scannerYPos = x, y
    saves = saves + 1
    return true
end

local function saveSpot()
    if InCombatLockdown() then return end
    local button = _G[BUTTON]
    if type(button) ~= "table" or not fitter:Holds(BUTTON) then return end
    local data = profile()
    if not data then return end
    if writeSpot(button, data) then pendingSave = false end
end

local function hookReset()
    local rs = addon()
    if not rs or type(rs.ResetPosition) ~= "function" then return end
    hooksecurefunc(rs, "ResetPosition", function()
        pendingSave = true
        fitter:Fit(BUTTON)
        pcall(saveSpot)
    end)
    hooked = true
end

-- A spot saved before this bridge existed: RareScanner restores it at login as one BOTTOMLEFT
-- anchor exactly where its BOTTOM 0,128 default sits. The default BOTTOM anchor itself does not end
-- the search, because the saved spot is restored only at login, after this file has loaded.
local function repairLegacy()
    local button = _G[BUTTON]
    if type(button) ~= "table" or type(button.GetPoint) ~= "function" then return end
    if not Shared.IsSpanned() or InCombatLockdown() then return end
    if button:GetNumPoints() ~= 1 then legacyDone = true return end
    local point, rel, relPoint, x, y = button:GetPoint(1)
    if point == "BOTTOM" and relPoint == "BOTTOM" then return end
    if point ~= "BOTTOMLEFT" or relPoint ~= "BOTTOMLEFT" or (rel ~= nil and rel ~= UIParent) then
        legacyDone = true
        return
    end
    local scale, base, width = button:GetEffectiveScale(), UIParent:GetEffectiveScale(), button:GetWidth()
    if type(scale) ~= "number" or scale <= 0 or type(base) ~= "number" or base <= 0
        or type(width) ~= "number" or type(x) ~= "number" then return end
    local k = base / scale                           -- the button ignores its parent's scale
    local _, _, _, _, sw = Shared.GameRect()
    if not Shared.Near(y, 128) or not Shared.Near(x + width / 2, (sw / 2) * k) then return end
    local dx, dy = Shared.PointDelta("BOTTOM")
    if dx == 0 and dy == 0 then return end
    button:ClearAllPoints()
    button:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x + dx * k, y + dy * k)
    legacyDone = true
    local data = profile()
    if data then writeSpot(button, data) end
end

-- ---------------------------------------------------------------------
-- Bridge
-- ---------------------------------------------------------------------

function bridge:Refresh(reason)
    fitter:Refresh()
    if not hooked then pcall(hookReset) end
    if pendingSave then pcall(saveSpot) end
    if not legacyDone then pcall(repairLegacy) end
end

function bridge:GetDiagnostics()
    return Shared.Describe("RareScannerAnchors", fitter) .. " RareScannerSaves=" .. tostring(saves)
end

if Shared.Register("RareScanner", bridge, fitter) then bridge:Refresh("load") end
