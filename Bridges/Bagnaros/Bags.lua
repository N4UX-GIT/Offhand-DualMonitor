-- Bagnaros bag provider (built into Offhand): the former Bagnaros bag Escape adapter of
-- Core/BagPersistence.lua, moved with unchanged behaviour. In the Forever bag Escape pass
-- (provider order 20) its verified main inventory BagnarosInventoryFrame leaves
-- UISpecialFrames while it is open on the workspace.
-- Registered on every client before Bagnaros exists; the addon's globals are read on each
-- pass. See README.md.

local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local API = type(Offhand) == "table" and Offhand.API
if type(API) ~= "table" or API.BRIDGE_CONTRACT ~= 1 or type(API.RegisterBridge) ~= "function" then return end

local function IsAddOnLoadedCompat(name)
    local checker = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    if not checker then return _G[name] ~= nil end
    local ok, loaded = pcall(checker, name)
    return ok and loaded == true
end

local function RefreshBagnarosEscape(services)
    local frame = _G.BagnarosInventoryFrame
    if not frame or not IsAddOnLoadedCompat("Bagnaros") then return end
    local controller = frame.controller
    -- Bagnaros registers its main inventory in UISpecialFrames and rebuilds
    -- it from the open native bags. A native close can hide and immediately
    -- reopen it during an expanded Spellbook or Game Menu transition.
    services.UpdateEscapeRegistration(frame, "BagnarosInventoryFrame", controller
        and controller.kind == "inventory" and controller.main == frame)
end

API.RegisterBridge("Bagnaros", {
    contract = API.BRIDGE_CONTRACT,
    bagProvider = {
        order = 20,
        RefreshEscape = RefreshBagnarosEscape,
    },
})
