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
local hookedBagFrames = setmetatable({}, { __mode = "k" })
local transitioning, singleScreenPaused, restoring, sessionReady = false, false, false, false

local function IsAddOnLoaded(name)
    local checker = C_AddOns and C_AddOns.IsAddOnLoaded or _G.IsAddOnLoaded
    if not checker then return _G[name] ~= nil end
    local ok, loaded = pcall(checker, name)
    return ok and loaded == true
end

local function IsSpanned()
    local api = Offhand and Offhand.API
    local rect = api and type(api.GetGameRect) == "function" and api.GetGameRect()
    return type(rect) == "table" and rect.isSpanned == true
end

local function IsOnWorkspace(frame)
    local api = Offhand and Offhand.API
    if not frame or not api or type(api.IsFrameOnWorkspace) ~= "function" then return false end
    return api.IsFrameOnWorkspace(frame) == true
end

local function PersistenceEnabled()
    local api = Offhand and Offhand.API
    if not api or type(api.IsWorkspacePersistenceEnabled) ~= "function" then return true end
    return api.IsWorkspacePersistenceEnabled() == true
end

local function GetBagContext()
    local vendor = IsAddOnLoaded("DaylightUI_Bags") and _G.DaylightUI
    local module = vendor and vendor.GetModule and vendor:GetModule("Bags")
    local namespace = module and module.enabled and module.ns
    local frame = namespace and namespace.window
    local openClose = namespace and namespace.OpenClose
    if frame and frame == _G.DaylightUIBag and type(openClose) == "table" then
        return frame, openClose
    end
    return nil, nil
end

local function IsBagVisiblyOpen(frame)
    return frame ~= nil and frame.IsShown and frame:IsShown() == true and not frame.__duiVanishing
end

local function SyncOpenState(frame)
    if transitioning or singleScreenPaused or restoring or not IsSpanned() then return end
    local db = ns.DB and ns.DB()
    if type(db) ~= "table" then return end
    if IsBagVisiblyOpen(frame) and IsOnWorkspace(frame) then
        db.openBags = true
    elseif sessionReady then
        db.openBags = nil
    end
end

local function HookBagVisibility(frame)
    if not frame or hookedBagFrames[frame] or type(frame.HookScript) ~= "function" then return end
    hookedBagFrames[frame] = true
    frame:HookScript("OnShow", function(self) SyncOpenState(self) end)
    frame:HookScript("OnHide", function(self)
        if not sessionReady or transitioning or singleScreenPaused or restoring or not IsSpanned() then return end
        local db = ns.DB and ns.DB()
        if type(db) == "table" then db.openBags = nil end
    end)
end

function Bags.Tick()
    local frame = GetBagContext()
    if not frame then return end
    HookBagVisibility(frame)
    SyncOpenState(frame)
end

function Bags.CaptureWorkspaceState()
    transitioning = true
    local frame = GetBagContext()
    if not frame or not IsSpanned() then return end
    local db = ns.DB and ns.DB()
    if type(db) ~= "table" then return end
    if IsBagVisiblyOpen(frame) and IsOnWorkspace(frame) then
        db.openBags = true
    end
end

function Bags.PrepareSingleScreenRecovery()
    local frame, openClose = GetBagContext()
    if not frame or not openClose then return end
    local db = ns.DB and ns.DB()
    if IsBagVisiblyOpen(frame) and IsOnWorkspace(frame) then
        if type(db) == "table" then db.openBags = true end
        singleScreenPaused = true
        sessionReady = false
        if not InCombatLockdown() and type(openClose.CloseAll) == "function" then
            held = nil
            pcall(openClose.CloseAll)
        end
    end
end

function Bags.RestoreWorkspaceState()
    transitioning = false
    singleScreenPaused = false
    if restoring then return end
    if InCombatLockdown() or not IsSpanned() then return end
    if not PersistenceEnabled() then
        sessionReady = true
        return
    end
    local db = ns.DB and ns.DB()
    if type(db) ~= "table" or not db.openBags then
        sessionReady = true
        return
    end
    restoring = true
    local function reopen()
        if InCombatLockdown() or not IsSpanned() then
            restoring = false
            return
        end
        if not PersistenceEnabled() then
            restoring = false
            sessionReady = true
            return
        end
        local currentDB = ns.DB and ns.DB()
        if type(currentDB) ~= "table" or not currentDB.openBags then
            restoring = false
            sessionReady = true
            return
        end
        local frame, openClose = GetBagContext()
        if not frame or not openClose or type(openClose.Hold) ~= "function" then
            restoring = false
            sessionReady = true
            return
        end
        HookBagVisibility(frame)
        if not IsBagVisiblyOpen(frame) then
            held = openClose
            pcall(openClose.Hold)
        end
        local function verify()
            restoring = false
            sessionReady = true
            if latest then Bags.Refresh(latest) end
            if IsBagVisiblyOpen(frame) and not IsOnWorkspace(frame) then
                if type(openClose.CloseAll) == "function" and not InCombatLockdown() then
                    held = nil
                    pcall(openClose.CloseAll)
                end
                if type(currentDB) == "table" then currentDB.openBags = nil end
            else
                SyncOpenState(frame)
            end
        end
        if C_Timer and C_Timer.After then
            C_Timer.After(0.25, verify)
        else
            verify()
        end
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(0.30, reopen)
    else
        reopen()
    end
end

function Bags.Refresh(services)
    if InCombatLockdown() or type(debugstack) ~= "function" then return end
    if type(services) ~= "table" then return end
    latest = services
    local frame, openClose = GetBagContext()
    if frame then
        HookBagVisibility(frame)
        SyncOpenState(frame)
    end
    local proxy = frame and frame.__duiEsc
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
