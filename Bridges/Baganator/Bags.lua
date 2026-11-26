-- Baganator bag provider (built into Offhand): the former Baganator branches of
-- Core/BagPersistence.lua and Core/CanvasPersistence.lua, moved with unchanged behaviour.
-- Persistent roots: its backpack roots (the backpackRoots name patterns Data.lua beside this
-- file shares, as direct UIParent children) are the third roots the bag persistence engine
-- tries (provider order 90). Persisted root names resolve directly, which is enough for reload
-- restoration before Baganator announces a frame replacement; the one global-table scan runs
-- only in a deep discovery pass (deepDiscovery, after Baganator's own load and after login),
-- and its BackpackFrameChanged and BagShow callbacks carry the ongoing changes. Its roots keep
-- their own native Escape registration and anchor (first in escape order, source label
-- baganator_toggle_observer, selfAnchored), get a drag-stop capture on Forever, are preserved
-- through the Options panel, open through the shared bag toggle it claims, and while Offhand
-- protects one the native bags it parks are closed.
-- Registered on every client before Baganator exists; the addon's global is read when asked.
-- See README.md.

local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local API = type(Offhand) == "table" and Offhand.API
if type(API) ~= "table" or API.BRIDGE_CONTRACT ~= 1 or type(API.RegisterBridge) ~= "function"
    or type(API.GetBridgeNamespace) ~= "function" then return end
local BACKPACK_ROOTS = API.GetBridgeNamespace("Baganator").backpackRoots
if type(BACKPACK_ROOTS) ~= "table" then return end

-- Baganator derives the names of every child region from the backpack root,
-- so this name test alone also catches title text, textures and buttons.
local function IsBaganatorRootName(name)
    if type(name) ~= "string" then return false end
    for _, pattern in ipairs(BACKPACK_ROOTS) do
        if name:match(pattern) then return true end
    end
    return false
end

-- Its actual backpack roots are direct UIParent children.
local function IsBaganatorBackpackRoot(name, frame)
    return IsBaganatorRootName(name) and frame and frame.GetParent
        and frame:GetParent() == UIParent and true or false
end

local function IsAddOnLoadedCompat(name)
    local checker = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    if not checker then return _G[name] ~= nil end
    local ok, loaded = pcall(checker, name)
    return ok and loaded == true
end

local function DiscoverBaganatorRoots(register, deep, services)
    local discovered = false
    -- Persisted Baganator root names can also be resolved directly. This is
    -- enough for reload restoration even before Baganator announces a frame
    -- replacement through its callback registry.
    for _, record in ipairs(services.GetSavedRecords()) do
        if type(record) == "table" then
            for name in pairs(record) do
                if IsBaganatorRootName(name) and _G[name] then
                    discovered = register(name, _G[name]) or discovered
                end
            end
        end
    end
    if not deep or not IsAddOnLoadedCompat("Baganator") then
        return discovered
    end

    -- Baganator derives root names from its active skin/frame group. A single
    -- lifecycle scan finds roots that predate Offhand's callback subscription;
    -- ongoing changes arrive through BackpackFrameChanged below.
    for name, frame in pairs(_G) do
        if type(name) == "string" and IsBaganatorRootName(name) then
            discovered = register(name, frame) or discovered
        end
    end
    return discovered
end

local callbacksInstalled

local function InstallBaganatorCallbacks(services)
    if callbacksInstalled or not IsAddOnLoadedCompat("Baganator") then return callbacksInstalled end
    local vendor = _G.Baganator
    local registry = type(vendor) == "table" and vendor.CallbackRegistry
    if not registry or not registry.RegisterCallback then return nil end
    callbacksInstalled = true
    registry:RegisterCallback("BackpackFrameChanged", function(_, frame)
        if not services.TrackEnabled() or not frame or not frame.GetName then return end
        services.RegisterRoot(frame:GetName(), frame)
    end)
    registry:RegisterCallback("BagShow", function()
        if not services.TrackEnabled() then return end
        for name in pairs(services.GetRoots()) do
            if IsBaganatorRootName(name) then return end
        end
        -- Fallback for load orders where Baganator creates its first frame
        -- after Offhand's PLAYER_LOGIN handler. This runs at most until the
        -- first root is found, never on a timer.
        C_Timer.After(0, function() services.Discover(true) end)
    end)
    return true
end

local function CloseBaganatorParkedBags(services)
    if not IsAddOnLoadedCompat("Baganator") then return end
    local combined = _G.ContainerFrameCombinedBags
    if combined and not (combined.IsForbidden and combined:IsForbidden()) then
        services.CloseParkedNativeBags(combined:GetParent(), 6)
    end
end

API.RegisterBridge("Baganator", {
    contract = API.BRIDGE_CONTRACT,
    bagProvider = {
        order = 90,
        IsRoot = IsBaganatorBackpackRoot,
        IsRootName = IsBaganatorRootName,
        Discover = DiscoverBaganatorRoots,
        loadAddon = "Baganator",
        deepDiscovery = true,
        InstallCallbacks = InstallBaganatorCallbacks,
        -- Baganator owns its native Escape registration and its anchor.
        IsDirectEscapeRoot = IsBaganatorRootName,
        escapeOrder = 10,
        escapeSource = "baganator_toggle_observer",
        selfAnchored = true,
        dragStopCapture = true,
        CloseParkedBags = CloseBaganatorParkedBags,
        panelTransitions = "options",
        -- Baganator replaces the shared bag toggle global.
        ClaimsSharedToggle = function() return IsAddOnLoadedCompat("Baganator") end,
    },
})
