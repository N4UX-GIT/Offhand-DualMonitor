--[[
    Offhand: Multi-Monitor Workspace Addon
    Core/Config.lua: SavedVariables management and defaults
--]]

local _, Offhand = ...
_G.Offhand = Offhand

local defaultSettings = {
    enabled = true,
    layoutPreset = "PORTRAIT_LEFT_LANDSCAPE_RIGHT", -- "PORTRAIT_LEFT_LANDSCAPE_RIGHT", "LANDSCAPE_DUAL", "CUSTOM"
    primaryPosition = "RIGHT",      -- "LEFT" or "RIGHT" (In Portrait Left, Primary 3D Game is on the RIGHT!)
    primaryWidthMode = "AUTO",      -- "AUTO", "CUSTOM"
    customPrimaryWidth = 2560,      -- 16:9 width
    deckWidthRatio = 0.36,          -- 1440 / 4000; saved manual calibration takes precedence
    gameHeightRatio = 0.5625,       -- 1440 / 2560 for the default portrait/landscape canvas
    gameBottomPixels = 0,          -- Primary monitor bottom inset within the spanned client
    bezelGap = 0,                   -- Pixels gap between monitors
    theme = "CLASSIC",              -- "CLASSIC", "BLIZZARD_SLATE", "OBSIDIAN", "PITCH_BLACK"
    trimColor = "GOLD",             -- "GOLD", "SILVER", "BRONZE", "EMERALD", "CRIMSON", "CUSTOM"
    customTrimColor = { r = 1.0, g = 0.82, b = 0.0 }, -- User-selected custom accent
    canvasColor = "CHARCOAL",       -- "CHARCOAL", "WARM_NIGHT", "PURE_BLACK", "DEEP_BLUE", "CUSTOM"
    customCanvasColor = { r = 0.12, g = 0.22, b = 0.35 }, -- User-selected custom workspace background
    canvasAlpha = 0.95,             -- Alpha of the secondary monitor background
    workspaceMapScale = "AUTO",     -- "AUTO" (fits deck width) or number (0.50 to 1.50)
    mainMapScale = 1.0,             -- Map scale when placed on the main gaming monitor
    showMinimapIcon = true,
    debugMode = false,
    forceDualOnSingle = false,      -- For testing
    hudScale = 0.70,                -- Global UI size multiplier relative to the game viewport (default 70%)
    chatPosition = "GAME",          -- "GAME" (bottom-left of 3D curved monitor) or "DECK" (bottom bay of vertical monitor)
    dockChat = true,                -- Enable managed chat positioning

    -- Feature toggles
    seamRedirect = true,            -- Redirect popups and errors away from center bezel
    preventMapCloseOnMove = true,   -- Keep WorldMap open while running/walking
    independentWorkspacePanels = true, -- Panels placed on the secondary workspace stay open independently
    persistentWorkspacePanels = true,  -- Keep workspace panels and maps open when pressing Escape
    savedWorkspacePositions = {},   -- Persisted coordinates for frames placed on the secondary workspace
    savedMainPositions = {},        -- Persisted coordinates for movable frames on the main screen
}

local function CopyDefaults(src, dst)
    if type(src) ~= "table" then return {} end
    if type(dst) ~= "table" then dst = {} end
    for k, v in pairs(src) do
        if type(v) == "table" then
            dst[k] = CopyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
    return dst
end

-- Some Forever Beta transitions fail to reload normal SavedVariables. Custom
-- CVars survive relog/reload within the running client, so mirror movable frame
-- state there as a narrowly scoped, Forever-only session fallback. They do not
-- survive closing the executable; a cold launch must retain any SavedVariables
-- the client successfully loaded instead of replacing them with empty CVars.
-- Other clients never register, read, or write these CVars.
local ForeverPersistence = {}
Offhand.ForeverPersistence = ForeverPersistence

local FOREVER_INDEX_CVAR = "offhandForeverPositionIndex"
local FOREVER_POSITION_PREFIX = "offhandForeverPosition_"
local FOREVER_OPEN_PANELS_CVAR = "offhandForeverOpenPanels"
local FOREVER_RECOVERY_VERSION_CVAR = "offhandForeverRecoveryVersion"

local function RegisterPersistentCVar(name)
    local register = RegisterCVar or (C_CVar and C_CVar.RegisterCVar)
    if not register then return false end
    return pcall(register, name, "")
end

local function ReadPersistentCVar(name)
    local getter = GetCVar or (C_CVar and C_CVar.GetCVar)
    if not getter then return nil end
    local ok, value = pcall(getter, name)
    if not ok then return nil end
    return value
end

local function WritePersistentCVar(name, value)
    local setter = SetCVar or (C_CVar and C_CVar.SetCVar)
    if not setter then return false end
    RegisterPersistentCVar(name)
    value = value or ""
    if tostring(ReadPersistentCVar(name) or "") == tostring(value) then return true end
    return pcall(setter, name, value)
end

local function IsSafeFrameName(name)
    return type(name) == "string" and name ~= "" and name:match("^[%w_]+$") ~= nil
end

local function PositionCVar(name)
    return FOREVER_POSITION_PREFIX .. name
end

function ForeverPersistence:IsAvailable()
    return Offhand.isForever and (RegisterCVar or (C_CVar and C_CVar.RegisterCVar))
        and (GetCVar or (C_CVar and C_CVar.GetCVar))
        and (SetCVar or (C_CVar and C_CVar.SetCVar))
end

function ForeverPersistence:GetIndex()
    if not self:IsAvailable() then return {}, {} end
    RegisterPersistentCVar(FOREVER_INDEX_CVAR)
    local names, seen = {}, {}
    for name in tostring(ReadPersistentCVar(FOREVER_INDEX_CVAR) or ""):gmatch("[^,]+") do
        if IsSafeFrameName(name) and not seen[name] then
            seen[name] = true
            table.insert(names, name)
        end
    end
    return names, seen
end

function ForeverPersistence:RememberFrame(name)
    if not self:IsAvailable() or not IsSafeFrameName(name) then return end
    local names, seen = self:GetIndex()
    if seen[name] then return end
    table.insert(names, name)
    WritePersistentCVar(FOREVER_INDEX_CVAR, table.concat(names, ","))
end

function ForeverPersistence:SaveWorkspacePosition(name, position, width, height)
    if not self:IsAvailable() or not IsSafeFrameName(name) or type(position) ~= "table" then return end
    local x, y = tonumber(position.x), tonumber(position.y)
    if not x or not y then return end
    self:RememberFrame(name)
    local canvasHeight = tonumber(position.canvasHeight) or 0
    local value = table.concat({ "W2", tostring(x), tostring(y), tostring(tonumber(width) or 0),
        tostring(tonumber(height) or 0), tostring(canvasHeight) }, "|")
    WritePersistentCVar(PositionCVar(name), value)
end

function ForeverPersistence:ClearPosition(name)
    if not self:IsAvailable() or not IsSafeFrameName(name) then return end
    self:RememberFrame(name)
    WritePersistentCVar(PositionCVar(name), "")
end

function ForeverPersistence:RestorePositions()
    if not self:IsAvailable() or not Offhand.db then return end
    Offhand.db.savedWorkspacePositions = Offhand.db.savedWorkspacePositions or {}
    local names = self:GetIndex()
    for _, name in ipairs(names) do
        RegisterPersistentCVar(PositionCVar(name))
        local value = ReadPersistentCVar(PositionCVar(name))
        local kind, x, y, width, height, canvasHeight = tostring(value or ""):match(
            "^(W2)|([%+%-%.%d]+)|([%+%-%.%d]+)|([%+%-%.%d]+)|([%+%-%.%d]+)|([%+%-%.%d]+)$")
        if not kind then
            kind, x, y, width, height = tostring(value or ""):match(
                "^(W)|([%+%-%.%d]+)|([%+%-%.%d]+)|([%+%-%.%d]+)|([%+%-%.%d]+)$")
        end
        x, y, width, height, canvasHeight = tonumber(x), tonumber(y), tonumber(width), tonumber(height), tonumber(canvasHeight)
        if (kind == "W" or kind == "W2") and x and y then
            Offhand.db.savedWorkspacePositions[name] = {
                x = x,
                y = y,
                width = width and width > 0 and width or nil,
                height = height and height > 0 and height or nil,
                canvasHeight = canvasHeight and canvasHeight > 0 and canvasHeight or nil,
            }
        end
    end
end

function ForeverPersistence:SaveOpenPanels(openPanels)
    if not self:IsAvailable() then return end
    local names = {}
    for name, isOpen in pairs(type(openPanels) == "table" and openPanels or {}) do
        if isOpen and IsSafeFrameName(name) then table.insert(names, name) end
    end
    table.sort(names)
    -- The marker distinguishes an intentionally empty snapshot ("V1|") from
    -- an uninitialized CVar after a cold client launch ("").
    WritePersistentCVar(FOREVER_OPEN_PANELS_CVAR, "V1|" .. table.concat(names, ","))
end

function ForeverPersistence:RestoreOpenPanels()
    if not self:IsAvailable() or not Offhand.db then return end
    RegisterPersistentCVar(FOREVER_OPEN_PANELS_CVAR)
    local value = tostring(ReadPersistentCVar(FOREVER_OPEN_PANELS_CVAR) or "")
    local payload = value:match("^V1|(.*)$")
    if payload == nil then
        -- Backward compatibility for earlier non-empty session snapshots. An
        -- empty value means this is a cold launch, so preserve disk-loaded data.
        if value == "" then return end
        payload = value
    end
    local openPanels = {}
    for name in payload:gmatch("[^,]+") do
        if IsSafeFrameName(name) then openPanels[name] = true end
    end
    Offhand.db.openWorkspacePanels = openPanels
end

function ForeverPersistence:BeginRecoverySnapshot()
    if not self:IsAvailable() then return false end
    local version = type(_G.OffhandForeverStateBridgeVersion) == "string"
        and _G.OffhandForeverStateBridgeVersion or ""
    if version == "" then return false end

    RegisterPersistentCVar(FOREVER_RECOVERY_VERSION_CVAR)
    if tostring(ReadPersistentCVar(FOREVER_RECOVERY_VERSION_CVAR) or "") == version then
        return false
    end

    -- A bridge snapshot is the durable cold-start source. Mark it consumed for
    -- this client session, then seed the session CVars from it below. This lets
    -- later /reload changes win without allowing stale empty CVars from startup
    -- to erase the recovered layout.
    WritePersistentCVar(FOREVER_RECOVERY_VERSION_CVAR, version)
    return true
end

function ForeverPersistence:SeedSessionFallback()
    if not self:IsAvailable() or not Offhand.db then return end
    for name, position in pairs(Offhand.db.savedWorkspacePositions or {}) do
        self:SaveWorkspacePosition(name, position, position.width, position.height)
    end
    self:SaveOpenPanels(Offhand.db.openWorkspacePanels)
end

function Offhand:InitializeConfig()
    if type(OffhandDB) ~= "table" then OffhandDB = {} end
    if type(OffhandCharDB) ~= "table" then OffhandCharDB = {} end

    -- Migrate legacy flat config to Profiles
    if type(OffhandDB.profiles) ~= "table" then
        OffhandDB.profiles = {}
        OffhandDB.profiles["Default"] = {}
        for k, v in pairs(OffhandDB) do
            if k ~= "profiles" then
                OffhandDB.profiles["Default"][k] = v
                OffhandDB[k] = nil
            end
        end
    end

        -- Scrub any rogue hijacked Focused frames so native placement takes back control
    for profileName, profileData in pairs(OffhandDB.profiles) do
        if type(profileData.savedWorkspacePositions) == "table" then
            profileData.savedWorkspacePositions["FocusedRosterFrame"] = nil
        end
        if type(profileData.savedMainPositions) == "table" then
            profileData.savedMainPositions["FocusedRosterFrame"] = nil
        end
    end

    local current = OffhandCharDB.activeProfile or "Default"
    if not OffhandDB.profiles[current] then
        OffhandDB.profiles[current] = {}
        OffhandCharDB.activeProfile = current
    end

    Offhand.db = OffhandDB.profiles[current]

    -- Auto-migrate to vertical portrait setup if preset is unset or old default
    if not Offhand.db.layoutPreset or Offhand.db.layoutPreset == "AUTO" then
        Offhand.db.layoutPreset = "PORTRAIT_LEFT_LANDSCAPE_RIGHT"
        Offhand.db.primaryPosition = Offhand.db.primaryPosition or "RIGHT"
    end
    -- Fill missing settings without overwriting a player's calibration.
    if not Offhand.db.chatPosition then
        Offhand.db.chatPosition = "GAME"
    end
    -- Purge legacy panelPositions from earlier docking modules
    if Offhand.db.panelPositions then
        Offhand.db.panelPositions = nil
    end

    CopyDefaults(defaultSettings, Offhand.db)
    if ForeverPersistence:BeginRecoverySnapshot() then
        ForeverPersistence:SeedSessionFallback()
    else
        ForeverPersistence:RestorePositions()
        ForeverPersistence:RestoreOpenPanels()
    end
end

function Offhand:GetProfiles()
    local list = {}
    if OffhandDB and OffhandDB.profiles then
        for k in pairs(OffhandDB.profiles) do
            table.insert(list, k)
        end
        table.sort(list)
    end
    return list
end

function Offhand:SetProfile(name)
    if not OffhandDB.profiles[name] then
        OffhandDB.profiles[name] = CopyDefaults(defaultSettings, {})
    end
    OffhandCharDB.activeProfile = name
    Offhand.db = OffhandDB.profiles[name]
    CopyDefaults(defaultSettings, Offhand.db)
    
    local L = Offhand.L or setmetatable({}, { __index = function(t, k) return k end })
    Offhand:ApplyFullLayout()
    if self.Options and self.Options.RefreshPanel then self.Options:RefreshPanel() end
    Offhand:Print(L["MSG_PROFILE_LOADED"]:format(name))
end

function Offhand:CreateProfile(name)
    local L = Offhand.L or setmetatable({}, { __index = function(t, k) return k end })
    if not name or strtrim(name) == "" then return false, L["PROFILES_WARN_EMPTY_NAME"] end
    name = strtrim(name)
    if OffhandDB.profiles[name] then return false, L["PROFILES_WARN_EXISTS"] end
    
    OffhandDB.profiles[name] = CopyDefaults(Offhand.db, {})
    self:SetProfile(name)
    Offhand:Print(L["MSG_PROFILE_CREATED"]:format(name))
    return true
end

function Offhand:DeleteProfile(name)
    local L = Offhand.L or setmetatable({}, { __index = function(t, k) return k end })
    if name == "Default" then return false, L["PROFILES_WARN_DEFAULT"] end
    if name == OffhandCharDB.activeProfile then return false, L["PROFILES_WARN_DELETE_ACTIVE"] end
    
    OffhandDB.profiles[name] = nil
    if self.Options and self.Options.RefreshPanel then self.Options:RefreshPanel() end
    Offhand:Print(L["MSG_PROFILE_DELETED"]:format(name))
    return true
end

function Offhand:CopyProfile(sourceName)
    local L = Offhand.L or setmetatable({}, { __index = function(t, k) return k end })
    if not OffhandDB.profiles[sourceName] then return false end
    
    local dest = OffhandCharDB.activeProfile
    OffhandDB.profiles[dest] = {}
    for k, v in pairs(OffhandDB.profiles[sourceName]) do
        if type(v) == "table" then
            OffhandDB.profiles[dest][k] = CopyDefaults(v, {})
        else
            OffhandDB.profiles[dest][k] = v
        end
    end
    
    Offhand.db = OffhandDB.profiles[dest]
    CopyDefaults(defaultSettings, Offhand.db)
    Offhand:ApplyFullLayout()
    if self.Options and self.Options.RefreshPanel then self.Options:RefreshPanel() end
    Offhand:Print(L["MSG_PROFILE_COPIED"]:format(sourceName))
    return true
end

function Offhand:ResetConfig()
    local L = Offhand.L or setmetatable({}, { __index = function(t, k) return k end })
    local current = (OffhandCharDB and OffhandCharDB.activeProfile) or "Default"
    OffhandDB.profiles[current] = CopyDefaults(defaultSettings, {})
    Offhand.db = OffhandDB.profiles[current]
    
    Offhand:ApplyFullLayout()
    if self.Options and self.Options.RefreshPanel then self.Options:RefreshPanel() end
    Offhand:Print(L["MSG_PROFILE_RESET"])
end


