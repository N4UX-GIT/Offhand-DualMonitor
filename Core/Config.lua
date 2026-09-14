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
