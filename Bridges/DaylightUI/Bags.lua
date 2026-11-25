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
local optionsPaused, optionsOpeningAt, lastWorkspaceHideAt, wasVisibleOnWorkspace = false, nil, nil, false
local wasOptionsOpen, optionsHooksInstalled = false, false
local OPTIONS_PANEL_NAMES = {
    SettingsPanel = true,
    InterfaceOptionsFrame = true,
    VideoOptionsFrame = true,
    AudioOptionsFrame = true,
}

local function Now()
    return type(GetTime) == "function" and GetTime() or 0
end

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

local function EscapeProtectionEnabled()
    local api = Offhand and Offhand.API
    if api and type(api.IsEscapeProtectionEnabled) == "function" then
        return api.IsEscapeProtectionEnabled() == true
    end
    return PersistenceEnabled()
end

local function IsOptionsPanel(panel)
    if type(panel) ~= "table" or type(panel.GetName) ~= "function" then return false end
    local ok, name = pcall(panel.GetName, panel)
    return ok and type(name) == "string" and OPTIONS_PANEL_NAMES[name] == true
end

local function IsOptionsOpen()
    for name in pairs(OPTIONS_PANEL_NAMES) do
        local panel = _G[name]
        if panel and panel.IsShown and panel:IsShown() then return true end
    end
    if type(IsOptionFrameOpen) == "function" then
        local ok, open = pcall(IsOptionFrameOpen)
        if ok and open then return true end
    end
    return false
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
        wasVisibleOnWorkspace = true
        optionsPaused = false
        db.openBags = true
    elseif sessionReady and not optionsPaused then
        wasVisibleOnWorkspace = false
        db.openBags = nil
    end
end

local function RestoreBagAfterOptions()
    if not optionsPaused or IsOptionsOpen() or InCombatLockdown() then return end
    optionsPaused = false
    optionsOpeningAt = nil
    if not EscapeProtectionEnabled() or not IsSpanned() then return end
    local frame, openClose = GetBagContext()
    if not frame or not openClose or IsBagVisiblyOpen(frame) then return end
    if type(openClose.Hold) ~= "function" then return end
    held = openClose
    pcall(openClose.Hold)
    if latest then Bags.Refresh(latest) end
    SyncOpenState(frame)
end

local function ObserveOptionsOpening()
    if not EscapeProtectionEnabled() or not IsSpanned() or InCombatLockdown() then return end
    if transitioning or singleScreenPaused or restoring then return end
    local frame = GetBagContext()
    if not frame then return end
    local now = Now()
    if IsBagVisiblyOpen(frame) and IsOnWorkspace(frame) then
        optionsOpeningAt = now
        wasVisibleOnWorkspace = true
    elseif lastWorkspaceHideAt and (now - lastWorkspaceHideAt) <= 0.5 then
        optionsPaused = true
        optionsOpeningAt = now
        local db = ns.DB and ns.DB()
        if type(db) == "table" then db.openBags = true end
    end
end

local function InstallOptionsObservers()
    if optionsHooksInstalled or type(hooksecurefunc) ~= "function" then return end
    optionsHooksInstalled = true
    if type(Settings) == "table" and type(Settings.OpenToCategory) == "function" then
        hooksecurefunc(Settings, "OpenToCategory", ObserveOptionsOpening)
    end
    if type(C_SettingsUtil) == "table" and type(C_SettingsUtil.OpenSettingsPanel) == "function" then
        hooksecurefunc(C_SettingsUtil, "OpenSettingsPanel", ObserveOptionsOpening)
    end
    if type(InterfaceOptionsFrame_OpenToCategory) == "function" then
        hooksecurefunc("InterfaceOptionsFrame_OpenToCategory", ObserveOptionsOpening)
    end
    if type(ShowUIPanel) == "function" then
        hooksecurefunc("ShowUIPanel", function(panel)
            if IsOptionsPanel(panel) then ObserveOptionsOpening() end
        end)
    end
    if type(HideUIPanel) == "function" then
        hooksecurefunc("HideUIPanel", function(panel)
            if not IsOptionsPanel(panel) or not optionsPaused then return end
            if C_Timer and C_Timer.After then
                C_Timer.After(0, RestoreBagAfterOptions)
            else
                RestoreBagAfterOptions()
            end
        end)
    end
end

local function HookBagVisibility(frame)
    if not frame or hookedBagFrames[frame] or type(frame.HookScript) ~= "function" then return end
    hookedBagFrames[frame] = true
    frame:HookScript("OnShow", function(self)
        lastWorkspaceHideAt = nil
        SyncOpenState(self)
    end)
    frame:HookScript("OnHide", function(self)
        local wasWorkspace = wasVisibleOnWorkspace or IsOnWorkspace(self)
        wasVisibleOnWorkspace = false
        if wasWorkspace then
            local now = Now()
            lastWorkspaceHideAt = now
            if EscapeProtectionEnabled() and IsSpanned() and not InCombatLockdown()
                and not transitioning and not singleScreenPaused and not restoring then
                local recentOptions = optionsOpeningAt ~= nil and (now - optionsOpeningAt) <= 0.5
                local stack = type(debugstack) == "function" and debugstack(2, 24, 0) or ""
                local settingsStack = latest and type(latest.IsSettingsBagClose) == "function"
                    and latest.IsSettingsBagClose(stack)
                if recentOptions or settingsStack then
                    optionsPaused = true
                    local db = ns.DB and ns.DB()
                    if type(db) == "table" then db.openBags = true end
                    return
                end
            end
        end
        if not sessionReady or transitioning or singleScreenPaused or restoring or optionsPaused or not IsSpanned() then return end
        local db = ns.DB and ns.DB()
        if type(db) == "table" then db.openBags = nil end
    end)
end

function Bags.Tick()
    InstallOptionsObservers()
    local optionsOpen = IsOptionsOpen()
    if optionsOpen and not wasOptionsOpen then
        ObserveOptionsOpening()
    elseif not optionsOpen and optionsPaused then
        RestoreBagAfterOptions()
    end
    wasOptionsOpen = optionsOpen
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
    optionsPaused, optionsOpeningAt, wasOptionsOpen = false, nil, false
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
    optionsPaused, optionsOpeningAt, wasOptionsOpen = false, nil, false
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
    InstallOptionsObservers()
    if not IsOptionsOpen() and optionsPaused then
        RestoreBagAfterOptions()
    end
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
    if not services.IsEscapeRegistered(proxy) then return end
    if hookedOpenClose ~= openClose then
        hookedOpenClose = openClose
        local follow = openClose.Follow
        openClose.Follow = function(...)
            if held == openClose and not openClose.held then
                local curFrame = _G.DaylightUIBag or frame
                local curProxy = (curFrame and curFrame.__duiEsc) or proxy
                local stack = debugstack(2, 24, 0)
                local suppress = latest and latest.CanSuppressVendorClose(curFrame, curProxy)
                    and (latest.IsGameMenuBagClose(stack)
                        or (type(latest.IsSettingsBagClose) == "function" and latest.IsSettingsBagClose(stack))
                        or (optionsOpeningAt ~= nil and (Now() - optionsOpeningAt) <= 0.5))
                if suppress then
                    openClose.held = true
                else
                    held = nil
                end
            end
            return follow(...)
        end
    end
    if openClose.held or not openClose.AnyOpen() then return end
    for _, container in ipairs(openClose.GameWindows()) do
        if container:IsShown() and container:GetParent() ~= parked then
            services.UpdateEscapeRegistration(frame, name, false, nil, proxy)
            return
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
