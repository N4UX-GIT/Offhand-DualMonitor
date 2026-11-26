-- ArkInventory bag provider (built into Offhand): the former ArkInventory bag Escape adapter
-- of Core/BagPersistence.lua, moved with unchanged behaviour. In the Forever bag Escape pass
-- (provider order 10, first) its bag inventory ARKINV_Frame1 leaves UISpecialFrames while it
-- is open on the workspace. Its toggle binding ARKINV_TOGGLE_BAG, and the generic inventory
-- toggles, are kept open while ARKINV_Frame1 is on the workspace.
-- Registered on every client before ArkInventory exists; the addon's globals are read on
-- each pass. See README.md.

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

local function RefreshArkInventoryEscape(services)
    local ark = _G.ArkInventory
    local frame = _G.ARKINV_Frame1
    if not (ark and frame and IsAddOnLoadedCompat("ArkInventory")) then return end
    local location = ark.Const and ark.Const.Location
    local owned = location and frame.ARK_Data and frame.ARK_Data.loc_id == location.Bag
    services.UpdateEscapeRegistration(frame, "ARKINV_Frame1", owned)
end

API.RegisterBridge("ArkInventory", {
    contract = API.BRIDGE_CONTRACT,
    bagProvider = {
        order = 10,
        RefreshEscape = RefreshArkInventoryEscape,
        toggleActions = { "ARKINV_TOGGLE_BAG" },
        GetToggleFrame = function() return _G.ARKINV_Frame1 end,
    },
})
