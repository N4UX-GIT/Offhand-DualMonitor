local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local ns = shared
if type(shared) == "table" and shared.API and shared.API.GetBridgeNamespace then
    ns = shared.API.GetBridgeNamespace("DaylightUI")
end
if type(ns) ~= "table" or ns.contract == false then return end

-- DaylightUI_Bags' backpack and Escape. Offhand keeps a visible backpack on
-- its workspace out of UISpecialFrames (services: the bag Escape helpers of
-- the bridge contract); DaylightUI's window registers an Escape proxy frame
-- instead of itself, and parks the game's bags under a hidden holder.
local Bags = {}
ns.Bags = Bags

local escapeProxy, held, hookedOpenClose
local latest              -- the services table of the latest Refresh

local function IsAddOnLoaded(name)
    local checker = C_AddOns and C_AddOns.IsAddOnLoaded or _G.IsAddOnLoaded
    if not checker then return _G[name] ~= nil end
    local ok, loaded = pcall(checker, name)
    return ok and loaded == true
end

function Bags.Refresh(services)
    if InCombatLockdown() or type(debugstack) ~= "function" then return end
    if type(services) ~= "table" then return end
    latest = services
    local vendor = IsAddOnLoaded("DaylightUI_Bags") and _G.DaylightUI
    local module = vendor and vendor.GetModule and vendor:GetModule("Bags")
    local namespace = module and module.enabled and module.ns
    local frame = namespace and namespace.window
    local openClose = namespace and namespace.OpenClose
    local proxy = frame and frame == _G.DaylightUIBag and frame.__duiEsc
    local name = proxy and proxy:GetName()
    local previous = escapeProxy
    if previous and previous ~= proxy then
        services.UpdateEscapeRegistration(previous, previous:GetName(), false)
    end
    escapeProxy = proxy
    if not name or not name:match("^DaylightUIEscape%d+$") or not openClose
        or type(openClose.Follow) ~= "function" or type(openClose.AnyOpen) ~= "function"
        or type(openClose.GameWindows) ~= "function" or type(openClose.CloseGame) ~= "function" then return end

    local parked = openClose.hidden
    local supported = parked and not parked:IsShown() and not frame.__duiVanishing
        and (not openClose.held or held == openClose)
    services.UpdateEscapeRegistration(frame, name, supported, nil, proxy)
    if not services.IsEscapeRegistered(proxy) or openClose.held or not openClose.AnyOpen() then return end
    for _, container in ipairs(openClose.GameWindows()) do
        if container:IsShown() and container:GetParent() ~= parked then
            services.UpdateEscapeRegistration(frame, name, false, nil, proxy)
            return
        end
    end
    if hookedOpenClose ~= openClose then
        hookedOpenClose = openClose
        local follow = openClose.Follow
        openClose.Follow = function(...)
            if held == openClose and not openClose.held then
                if latest.CanSuppressVendorClose(frame, proxy) and latest.IsGameMenuBagClose(debugstack(2, 24, 0)) then
                    openClose.held = true
                else
                    held = nil
                end
            end
            return follow(...)
        end
    end
    -- Use DaylightUI's held-bag mode so Blizzard sees the parked bags closed.
    -- Its normal toggle releases the hold and closes any bags opened by B.
    held = openClose
    openClose.held = true
    openClose.CloseGame()
end

function Bags.GetFrames()
    return { _G.DaylightUIBag }
end
