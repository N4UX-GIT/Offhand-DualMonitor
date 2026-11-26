-- Bagnon bag provider (built into Offhand): the former Bagnon branches of Core/BagPersistence.lua,
-- moved with unchanged behaviour. Its inventory toggle binding BAGNON_TOGGLE is kept open while
-- the inventory window from Bagnon's frame manager is on the workspace.
-- Persistent root: the inventory window of Bagnon's frame manager (Frames:Get("inventory"), a
-- direct UIParent child with id "inventory") is the second root the bag persistence engine
-- tries (provider order 80). Its manager provides a constant-time identity lookup after the lazy
-- root is built, so discovery never scans its child regions or depends on skin-generated global
-- names, and no Bagnon callback is installed. The root gets no scripts (taint boundary, see
-- README.md); it keeps its own native Escape registration (second in escape order, source
-- label bagnon_toggle_observer), it is preserved through every panel transition, it reopens
-- through the manager's Show("inventory"), and the player bags Bagnon parks are closed while
-- Offhand protects it.
-- Registered on every client before Bagnon exists; the addon's global is read when asked.
-- See README.md.

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

local function GetBagnonInventoryRoot()
    if not IsAddOnLoadedCompat("Bagnon") then return nil end
    local manager = Bagnon and Bagnon.Frames
    if not manager or type(manager.Get) ~= "function" then return nil end
    local ok, frame = pcall(manager.Get, manager, "inventory")
    if not ok or type(frame) ~= "table" or not frame.GetName then return nil end
    return frame
end

local function IsBagnonInventoryRoot(name, frame)
    if not frame or not frame.GetParent
        or frame:GetParent() ~= UIParent or frame.id ~= "inventory" then
        return false
    end
    return GetBagnonInventoryRoot() == frame
end

-- The lazy inventory root, through the manager's identity lookup.
local function DiscoverBagnonRoot(register)
    local bagnonRoot = GetBagnonInventoryRoot()
    if bagnonRoot then return register(bagnonRoot:GetName(), bagnonRoot) end
    return false
end

-- Deliberately no Bagnon callbacks. Its root and manager can participate in
-- Forever's Gamepad focus path. Constant-time polling of Frames:Get from
-- the addon-owned observer discovers the lazy inventory root without
-- inserting Offhand code into Bagnon's call chain.
local function InstallBagnonCallbacks()
    return IsAddOnLoadedCompat("Bagnon") or nil
end

-- Reopens the saved inventory root through the public frame manager; nil
-- when it is not that root or the manager failed, so the engine continues.
local function ShowBagnonRoot(savedName, frame, services)
    if frame and IsBagnonInventoryRoot(savedName, frame) then
        local manager = Bagnon and Bagnon.Frames
        if manager and type(manager.Show) == "function" then
            local ok = pcall(manager.Show, manager, "inventory")
            if ok then
                services.Discover(false)
                return true
            end
        end
    end
    return nil
end

local function CloseBagnonParkedBags(services)
    local vendor = _G.Bagnon
    if type(vendor) == "table" and vendor.Overrides and type(vendor.NumBags) == "number" then
        services.CloseParkedNativeBags(vendor.Overrides.Disabled, NUM_CONTAINER_FRAMES or 13, vendor.NumBags)
    end
end

API.RegisterBridge("Bagnon", {
    contract = API.BRIDGE_CONTRACT,
    bagProvider = {
        order = 80,
        toggleActions = { "BAGNON_TOGGLE" },
        GetToggleFrame = function(action)
            if action ~= "BAGNON_TOGGLE" then return nil end
            return Bagnon and Bagnon.Frames and Bagnon.Frames:Get("inventory")
        end,
        IsRoot = IsBagnonInventoryRoot,
        Discover = DiscoverBagnonRoot,
        hookScripts = false,
        IsDirectEscapeRoot = IsBagnonInventoryRoot,
        escapeOrder = 20,
        escapeSource = "bagnon_toggle_observer",
        CloseParkedBags = CloseBagnonParkedBags,
        panelTransitions = "all",
        Show = ShowBagnonRoot,
        loadAddon = "Bagnon",
        InstallCallbacks = InstallBagnonCallbacks,
    },
})
