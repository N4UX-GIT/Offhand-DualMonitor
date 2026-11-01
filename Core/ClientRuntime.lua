--[[
    Offhand: Multi-Monitor Setup Addon
    Core/ClientRuntime.lua: Client capabilities and support diagnostics
--]]

local _, Offhand = ...

local function BlizzardEditModeAddonExists()
    if C_AddOns and type(C_AddOns.DoesAddOnExist) == "function" then
        local ok, exists = pcall(C_AddOns.DoesAddOnExist, "Blizzard_EditMode")
        if ok and exists then return true end
    end
    if C_AddOns and type(C_AddOns.GetAddOnInfo) == "function" then
        local ok, info = pcall(C_AddOns.GetAddOnInfo, "Blizzard_EditMode")
        if ok and info ~= nil then return true end
    end
    if type(GetAddOnInfo) == "function" then
        local ok, name = pcall(GetAddOnInfo, "Blizzard_EditMode")
        if ok and name ~= nil then return true end
    end
    return false
end

function Offhand:HasBlizzardEditMode()
    if self.isRetail or self.isForever then return true end
    if C_EditMode ~= nil or EditModeManagerFrame ~= nil then return true end
    return BlizzardEditModeAddonExists()
end

function Offhand:IsGamepadUIEnabled()
    local gamepad = Enum and Enum.InputDeviceInterfaceType
        and Enum.InputDeviceInterfaceType.Gamepad
    local getStyle = C_InputInterfaceStyle and C_InputInterfaceStyle.GetCurrentStyle
    if gamepad ~= nil and type(getStyle) == "function" then
        local ok, current = pcall(getStyle)
        if ok then return current == gamepad end
    end
    if InputUtil and type(InputUtil.IsGamepadUIEnabled) == "function" then
        local ok, enabled = pcall(InputUtil.IsGamepadUIEnabled)
        if ok then return enabled == true end
    end
    return false
end

local function ClientProjectLabel()
    if Offhand.isForever then return "Forever" end
    if Offhand.isLegacyWrath then return "Wrath 3.3.5a" end
    if Offhand.isRetail then return "Retail" end
    if Offhand.isClassicEra then return "Classic Era" end
    if WOW_PROJECT_ID ~= nil then return "Project " .. tostring(WOW_PROJECT_ID) end
    return "unknown"
end

function Offhand:GetVersionDiagnostics(metrics)
    metrics = metrics or {}
    return {
        clientVersion = Offhand.clientVersion or "unknown",
        clientBuild = Offhand.clientBuild or "unknown",
        interfaceVersion = tostring(Offhand.tocVersion or "unknown"),
        clientProject = ClientProjectLabel(),
        addonVersion = Offhand.fullVersion or Offhand.version or "unknown",
        companionWriter = metrics.companionVersion or "not recorded",
        companionPaired = Offhand.companionFullVersion or "unknown",
        companionMinimum = Offhand.companionMinVersion ~= ""
            and Offhand.companionMinVersion or "not specified",
        companionProtocol = Offhand.companionProtocol or "not specified",
        companionStatus = metrics.companionVersionStatus or "unavailable",
    }
end

function Offhand:GetOperatingDiagnostics(metrics)
    metrics = metrics or {}
    local db = Offhand.db or {}
    local setupComplete = db.firstRunComplete == true
    if Offhand.IsSetupComplete then
        local ok, value = pcall(Offhand.IsSetupComplete, Offhand)
        if ok then setupComplete = value == true end
    end

    local topologySource
    if metrics.companionTopology then
        topologySource = "Companion"
    elseif metrics.manualCanvas then
        topologySource = metrics.manualCanvasSource == "FANCYZONES"
            and "FancyZones" or "Remembered manual"
    elseif metrics.isSpanned then
        topologySource = "Manual"
    elseif metrics.topologyStatus == "MISMATCH"
        or metrics.topologyStatus == "INVALID"
        or metrics.topologyStatus == "STALE" then
        topologySource = "Recovery"
    else
        topologySource = "Single-screen"
    end

    return {
        enabled = db.enabled == true,
        spanned = metrics.isSpanned == true,
        topologySource = topologySource,
        layoutPreset = metrics.preset or db.layoutPreset or "unknown",
        mainhandPosition = db.primaryPosition or "unknown",
        inCombat = InCombatLockdown and InCombatLockdown() or false,
        setupComplete = setupComplete,
        mainhandLeft = tonumber(metrics.gamePixelLeft) or 0,
        mainhandBottom = tonumber(metrics.gamePixelBottom) or 0,
        mainhandWidth = tonumber(metrics.gamePixelWidth) or 0,
        mainhandHeight = tonumber(metrics.gamePixelHeight) or 0,
        workspaceLeft = tonumber(metrics.workspacePixelLeft) or 0,
        workspaceBottom = tonumber(metrics.workspacePixelBottom) or 0,
        workspaceWidth = tonumber(metrics.workspacePixelWidth) or 0,
        workspaceHeight = tonumber(metrics.workspacePixelHeight) or 0,
    }
end
