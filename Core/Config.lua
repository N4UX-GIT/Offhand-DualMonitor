--[[
    Offhand: Multi-Monitor Workspace Addon
    Core/Config.lua: SavedVariables management and defaults
--]]

local _, Offhand = ...
_G.Offhand = Offhand

local defaultSettings = {
    -- First launch is intentionally inert. The wizard enables Offhand only
    -- after the user has reviewed the Companion's detected display topology.
    enabled = false,
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
    rawMouseInput = true,           -- Prevent hidden cursor exhaustion during camera look across shaped spans
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

local RawMouse = {}
Offhand.RawMouse = RawMouse

local function ReadRawMouse()
    local getter = GetCVar or (C_CVar and C_CVar.GetCVar)
    if not getter then return nil end
    local ok, value = pcall(getter, "rawMouseEnable")
    if not ok or value == nil then return nil end
    return tostring(value)
end

local function WriteRawMouse(value)
    local setter = SetCVar or (C_CVar and C_CVar.SetCVar)
    if not setter then return false end
    return pcall(setter, "rawMouseEnable", tostring(value))
end

function RawMouse:Restore()
    local db = Offhand.db
    if not db or not db.rawMouseManaged then return end
    local original = db.originalRawMouseEnable
    if original ~= nil and ReadRawMouse() ~= tostring(original) then
        WriteRawMouse(original)
    end
    db.rawMouseManaged = nil
    db.originalRawMouseEnable = nil
end

function RawMouse:Update(metrics)
    local db = Offhand.db
    if not db then return end
    local shouldManage = db.enabled and db.rawMouseInput ~= false
        and metrics and metrics.isSpanned
    if not shouldManage then
        self:Restore()
        return
    end

    local current = ReadRawMouse()
    if current == nil then return end
    if not db.rawMouseManaged then
        db.originalRawMouseEnable = current
        db.rawMouseManaged = true
    end
    if current ~= "1" then WriteRawMouse("1") end
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
local FOREVER_ONBOARDING_CVAR = "offhandForeverOnboarding"
local FOREVER_DISPLAY_FLAGS_CVAR = "offhandForeverDisplayFlags"
local FOREVER_PROFILE_MANIFEST_CVAR = "offhandForeverProfileManifest"
local FOREVER_PROFILE_CHUNK_PREFIX = "offhandForeverProfileChunk_"
local FOREVER_PROFILE_CHUNK_BYTES = 180
local FOREVER_PROFILE_MAX_BYTES = 128 * 1024
local FOREVER_PROFILE_MAX_CHUNKS = math.ceil(FOREVER_PROFILE_MAX_BYTES / FOREVER_PROFILE_CHUNK_BYTES)

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

local SNAPSHOT_INVALID = {}
local SNAPSHOT_TRANSIENT_KEYS = {
    rawMouseManaged = true,
    originalRawMouseEnable = true,
    originalUiScale = true,
    originalUseUiScale = true,
    lastGeometryCheck = true,
}

local function SnapshotCopy(value, depth, budget, topLevel)
    local valueType = type(value)
    if valueType == "boolean" or valueType == "number" or valueType == "string" then
        if valueType == "string" and #value > 8192 then return SNAPSHOT_INVALID end
        return value
    end
    if valueType ~= "table" or depth > 12 then return SNAPSHOT_INVALID end
    if budget.tables[value] then return SNAPSHOT_INVALID end
    budget.tables[value] = true
    local copy = {}
    for key, child in pairs(value) do
        local keyType = type(key)
        if (keyType == "string" or keyType == "number")
            and not (topLevel and SNAPSHOT_TRANSIENT_KEYS[key]) then
            budget.entries = budget.entries + 1
            if budget.entries > 5000 then
                budget.tables[value] = nil
                return SNAPSHOT_INVALID
            end
            local childCopy = SnapshotCopy(child, depth + 1, budget, false)
            if childCopy ~= SNAPSHOT_INVALID then copy[key] = childCopy end
        end
    end
    budget.tables[value] = nil
    return copy
end

local function SnapshotAccountState(accountDB)
    local budget = { entries = 0, tables = {} }
    local copy = {}
    for key, value in pairs(accountDB) do
        if key == "profiles" and type(value) == "table" then
            local profiles = {}
            for profileName, profile in pairs(value) do
                if type(profileName) == "string" and type(profile) == "table" then
                    local profileCopy = SnapshotCopy(profile, 0, budget, true)
                    if profileCopy == SNAPSHOT_INVALID then return SNAPSHOT_INVALID end
                    profiles[profileName] = profileCopy
                end
            end
            copy.profiles = profiles
        else
            local childCopy = SnapshotCopy(value, 0, budget, false)
            if childCopy ~= SNAPSHOT_INVALID then copy[key] = childCopy end
        end
    end
    return copy
end

local function EncodeLengthValue(tag, value)
    value = tostring(value)
    return tag .. tostring(#value) .. ":" .. value
end

local function EncodeSnapshotValue(value)
    local valueType = type(value)
    if valueType == "boolean" then return value and "B1" or "B0" end
    if valueType == "number" then return EncodeLengthValue("N", value) end
    if valueType == "string" then return EncodeLengthValue("S", value) end
    if valueType ~= "table" then return nil end

    local keys = {}
    for key in pairs(value) do table.insert(keys, key) end
    table.sort(keys, function(a, b)
        local ta, tb = type(a), type(b)
        if ta ~= tb then return ta < tb end
        if ta == "number" then return a < b end
        return tostring(a) < tostring(b)
    end)
    local parts = { "T", tostring(#keys), ":" }
    for _, key in ipairs(keys) do
        local encodedKey = EncodeSnapshotValue(key)
        local encodedValue = EncodeSnapshotValue(value[key])
        if not encodedKey or not encodedValue then return nil end
        table.insert(parts, encodedKey)
        table.insert(parts, encodedValue)
    end
    return table.concat(parts)
end

local function ReadLength(encoded, index)
    local colon = encoded:find(":", index, true)
    if not colon then return nil end
    local length = tonumber(encoded:sub(index, colon - 1))
    if not length or length < 0 or length > FOREVER_PROFILE_MAX_BYTES then return nil end
    return length, colon + 1
end

local function DecodeSnapshotValue(encoded, index, depth, budget)
    if depth > 12 or index > #encoded then return nil end
    local tag = encoded:sub(index, index)
    if tag == "B" then
        local flag = encoded:sub(index + 1, index + 1)
        if flag ~= "0" and flag ~= "1" then return nil end
        return flag == "1", index + 2
    end
    if tag == "N" or tag == "S" then
        local length, startIndex = ReadLength(encoded, index + 1)
        if not length then return nil end
        local endIndex = startIndex + length - 1
        if endIndex > #encoded then return nil end
        local raw = encoded:sub(startIndex, endIndex)
        if tag == "N" then
            raw = tonumber(raw)
            if not raw then return nil end
        end
        return raw, endIndex + 1
    end
    if tag ~= "T" then return nil end
    local count, childIndex = ReadLength(encoded, index + 1)
    if not count or count > 5000 then return nil end
    local result = {}
    for _ = 1, count do
        budget.entries = budget.entries + 1
        if budget.entries > 5000 then return nil end
        local key, nextIndex = DecodeSnapshotValue(encoded, childIndex, depth + 1, budget)
        if key == nil then return nil end
        local child
        child, childIndex = DecodeSnapshotValue(encoded, nextIndex, depth + 1, budget)
        if child == nil then return nil end
        if type(key) ~= "string" and type(key) ~= "number" then return nil end
        result[key] = child
    end
    return result, childIndex
end

local function SnapshotChecksum(value)
    local a, b = 1, 0
    for index = 1, #value do
        a = (a + value:byte(index)) % 65521
        b = (b + a) % 65521
    end
    return tostring(a) .. "-" .. tostring(b)
end

function ForeverPersistence:SaveProfileSnapshot(incrementRevision)
    if not self:IsAvailable() or not Offhand.db then return false end
    if type(OffhandDB) ~= "table" then return false end
    local revision = (tonumber(OffhandDB.foreverPersistenceRevision) or 0) + (incrementRevision and 1 or 0)
    local account = SnapshotAccountState(OffhandDB)
    local character = SnapshotCopy(OffhandCharDB, 0, { entries = 0, tables = {} }, false)
    if account == SNAPSHOT_INVALID or character == SNAPSHOT_INVALID then return false end
    account.foreverPersistenceRevision = revision
    local encoded = EncodeSnapshotValue({
        revision = revision,
        account = account,
        character = character,
    })
    if not encoded or #encoded > FOREVER_PROFILE_MAX_BYTES then return false end

    OffhandDB.foreverPersistenceRevision = revision

    local count = math.max(1, math.ceil(#encoded / FOREVER_PROFILE_CHUNK_BYTES))
    local oldCount = tonumber(tostring(ReadPersistentCVar(FOREVER_PROFILE_MANIFEST_CVAR) or ""):match(
        "^V1|%d+|(%d+)|%d+|[%d%-]+$")) or 0
    for index = 1, count do
        local first = ((index - 1) * FOREVER_PROFILE_CHUNK_BYTES) + 1
        WritePersistentCVar(FOREVER_PROFILE_CHUNK_PREFIX .. index,
            encoded:sub(first, first + FOREVER_PROFILE_CHUNK_BYTES - 1))
    end
    for index = count + 1, math.min(oldCount, FOREVER_PROFILE_MAX_CHUNKS) do
        WritePersistentCVar(FOREVER_PROFILE_CHUNK_PREFIX .. index, "")
    end
    WritePersistentCVar(FOREVER_PROFILE_MANIFEST_CVAR, table.concat({
        "V1", tostring(revision), tostring(count), tostring(#encoded), SnapshotChecksum(encoded),
    }, "|"))
    return true
end

function ForeverPersistence:RestoreProfileSnapshot(accountDB, characterDB)
    if not self:IsAvailable() or type(accountDB) ~= "table" or type(characterDB) ~= "table" then return "none" end
    RegisterPersistentCVar(FOREVER_PROFILE_MANIFEST_CVAR)
    local revision, count, length, checksum = tostring(ReadPersistentCVar(FOREVER_PROFILE_MANIFEST_CVAR) or ""):match(
        "^V1|(%d+)|(%d+)|(%d+)|([%d%-]+)$")
    revision, count, length = tonumber(revision), tonumber(count), tonumber(length)
    if not revision or not count or not length or count < 1 or count > FOREVER_PROFILE_MAX_CHUNKS
        or length > FOREVER_PROFILE_MAX_BYTES then return "none" end

    local parts = {}
    for index = 1, count do
        RegisterPersistentCVar(FOREVER_PROFILE_CHUNK_PREFIX .. index)
        local chunk = tostring(ReadPersistentCVar(FOREVER_PROFILE_CHUNK_PREFIX .. index) or "")
        if chunk == "" then return "none" end
        table.insert(parts, chunk)
    end
    local encoded = table.concat(parts)
    if #encoded ~= length or SnapshotChecksum(encoded) ~= checksum then return "none" end
    local snapshot, nextIndex = DecodeSnapshotValue(encoded, 1, 0, { entries = 0 })
    if type(snapshot) ~= "table" or nextIndex ~= #encoded + 1
        or tonumber(snapshot.revision) ~= revision
        or type(snapshot.account) ~= "table" or type(snapshot.account.profiles) ~= "table"
        or type(snapshot.character) ~= "table" then return "none" end

    local standardRevision = tonumber(accountDB.foreverPersistenceRevision) or 0
    if standardRevision >= revision then return "standard" end
    for key in pairs(accountDB) do accountDB[key] = nil end
    for key, value in pairs(snapshot.account) do accountDB[key] = value end
    for key in pairs(characterDB) do characterDB[key] = nil end
    for key, value in pairs(snapshot.character) do characterDB[key] = value end
    return "fallback"
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
    local canvasWidth = tonumber(position.canvasWidth) or 0
    local canvasHeight = tonumber(position.canvasHeight) or 0
    local canvasLeft = tonumber(position.canvasLeft) or 0
    local canvasBottom = tonumber(position.canvasBottom) or 0
    local value = table.concat({ "W4", tostring(x), tostring(y), tostring(tonumber(width) or 0),
        tostring(tonumber(height) or 0), tostring(canvasWidth), tostring(canvasHeight),
        tostring(canvasLeft), tostring(canvasBottom) }, "|")
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
        local kind, x, y, width, height, canvasWidth, canvasHeight, canvasLeft, canvasBottom = tostring(value or ""):match(
            "^(W4)|([%+%-%.%d]+)|([%+%-%.%d]+)|([%+%-%.%d]+)|([%+%-%.%d]+)|([%+%-%.%d]+)|([%+%-%.%d]+)|([%+%-%.%d]+)|([%+%-%.%d]+)$")
        if not kind then
            kind, x, y, width, height, canvasHeight, canvasBottom = tostring(value or ""):match(
            "^(W3)|([%+%-%.%d]+)|([%+%-%.%d]+)|([%+%-%.%d]+)|([%+%-%.%d]+)|([%+%-%.%d]+)|([%+%-%.%d]+)$")
        end
        if not kind then
            kind, x, y, width, height, canvasHeight = tostring(value or ""):match(
            "^(W2)|([%+%-%.%d]+)|([%+%-%.%d]+)|([%+%-%.%d]+)|([%+%-%.%d]+)|([%+%-%.%d]+)$")
        end
        if not kind then
            kind, x, y, width, height = tostring(value or ""):match(
                "^(W)|([%+%-%.%d]+)|([%+%-%.%d]+)|([%+%-%.%d]+)|([%+%-%.%d]+)$")
        end
        x, y, width, height = tonumber(x), tonumber(y), tonumber(width), tonumber(height)
        canvasWidth, canvasHeight = tonumber(canvasWidth), tonumber(canvasHeight)
        canvasLeft, canvasBottom = tonumber(canvasLeft), tonumber(canvasBottom)
        if (kind == "W" or kind == "W2" or kind == "W3" or kind == "W4") and x and y then
            Offhand.db.savedWorkspacePositions[name] = {
                x = x,
                y = y,
                width = width and width > 0 and width or nil,
                height = height and height > 0 and height or nil,
                canvasWidth = canvasWidth and canvasWidth > 0 and canvasWidth or nil,
                canvasHeight = canvasHeight and canvasHeight > 0 and canvasHeight or nil,
                canvasLeft = canvasLeft,
                canvasBottom = canvasBottom,
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

function ForeverPersistence:SaveOnboarding(onboarding)
    if not self:IsAvailable() or type(onboarding) ~= "table" then return end
    local function Flag(value) return value and "1" or "0" end
    WritePersistentCVar(FOREVER_ONBOARDING_CVAR, table.concat({
        "V1", Flag(onboarding.welcomeDismissed), Flag(onboarding.setupComplete),
        Flag(onboarding.suppressCompanionWarning),
    }, "|"))
end

function ForeverPersistence:SaveDisplayFlags(db)
    if not self:IsAvailable() or type(db) ~= "table" then return end
    local function Flag(value) return value and "1" or "0" end
    WritePersistentCVar(FOREVER_DISPLAY_FLAGS_CVAR, table.concat({
        "V1", Flag(db.enabled), Flag(db.rawMouseInput ~= false),
    }, "|"))
end

function ForeverPersistence:RestoreDisplayFlags(db)
    if not self:IsAvailable() or type(db) ~= "table" then return false end
    RegisterPersistentCVar(FOREVER_DISPLAY_FLAGS_CVAR)
    local enabled, rawMouse = tostring(ReadPersistentCVar(FOREVER_DISPLAY_FLAGS_CVAR) or ""):match(
        "^V1|([01])|([01])$")
    if not enabled then return false end
    db.enabled = enabled == "1"
    db.rawMouseInput = rawMouse == "1"
    return true
end

function ForeverPersistence:RestoreOnboarding(onboarding)
    if not self:IsAvailable() or type(onboarding) ~= "table" then return false end
    RegisterPersistentCVar(FOREVER_ONBOARDING_CVAR)
    local welcome, setup, suppress = tostring(ReadPersistentCVar(FOREVER_ONBOARDING_CVAR) or ""):match(
        "^V1|([01])|([01])|([01])$")
    if not welcome then return false end
    onboarding.welcomeDismissed = welcome == "1"
    onboarding.setupComplete = setup == "1"
    onboarding.suppressCompanionWarning = suppress == "1"
    return true
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
    self:SaveProfileSnapshot(false)
    for name, position in pairs(Offhand.db.savedWorkspacePositions or {}) do
        self:SaveWorkspacePosition(name, position, position.width, position.height)
    end
    self:SaveOpenPanels(Offhand.db.openWorkspacePanels)
    self:SaveOnboarding(OffhandDB and OffhandDB.onboarding)
    self:SaveDisplayFlags(Offhand.db)
end

function Offhand:SetEnabled(enabled)
    if not Offhand.db then return end
    Offhand.db.enabled = enabled == true
    ForeverPersistence:SaveDisplayFlags(Offhand.db)
end

function Offhand:SetRawMouseInput(enabled)
    if not Offhand.db then return end
    Offhand.db.rawMouseInput = enabled == true
    ForeverPersistence:SaveDisplayFlags(Offhand.db)
end

local function EnsureOnboarding()
    if type(OffhandDB) ~= "table" then OffhandDB = {} end
    if type(OffhandDB.onboarding) ~= "table" then OffhandDB.onboarding = {} end
    return OffhandDB.onboarding
end

local function SyncLegacyOnboarding()
    local onboarding = EnsureOnboarding()
    if Offhand.db then
        Offhand.db.firstRunComplete = onboarding.setupComplete == true
        Offhand.db.suppressCompanionWarning = onboarding.suppressCompanionWarning == true
    end
    return onboarding
end

local function SaveOnboarding()
    local onboarding = SyncLegacyOnboarding()
    ForeverPersistence:SaveOnboarding(onboarding)
end

function Offhand:IsWelcomeDismissed()
    return EnsureOnboarding().welcomeDismissed == true
end

function Offhand:IsSetupComplete()
    return EnsureOnboarding().setupComplete == true
end

function Offhand:IsCompanionWarningSuppressed()
    return EnsureOnboarding().suppressCompanionWarning == true
end

function Offhand:MarkWelcomeDismissed()
    EnsureOnboarding().welcomeDismissed = true
    SaveOnboarding()
end

function Offhand:MarkSetupComplete()
    local onboarding = EnsureOnboarding()
    onboarding.welcomeDismissed = true
    onboarding.setupComplete = true
    SaveOnboarding()
end

function Offhand:SetCompanionWarningSuppressed(suppressed)
    EnsureOnboarding().suppressCompanionWarning = suppressed == true
    SaveOnboarding()
end

function Offhand:InitializeConfig()
    -- ForeverState.lua is loaded immediately before this module. A new bridge
    -- version is authoritative once after a cold launch; an already-consumed
    -- version must yield to the fresher SavedVariables captured by Init.lua.
    local useForeverBridge = ForeverPersistence:BeginRecoverySnapshot()
    local diskState = Offhand.foreverDiskSavedVariables
    if Offhand.isForever and not useForeverBridge and type(diskState) == "table" then
        if type(diskState.account) == "table" then OffhandDB = diskState.account end
        if type(diskState.character) == "table" then OffhandCharDB = diskState.character end
    end

    if type(OffhandDB) ~= "table" then OffhandDB = {} end
    if type(OffhandCharDB) ~= "table" then OffhandCharDB = {} end

    -- Migrate legacy flat config to Profiles
    if type(OffhandDB.profiles) ~= "table" then
        OffhandDB.profiles = {}
        OffhandDB.profiles["Default"] = {}
        for k, v in pairs(OffhandDB) do
            if k ~= "profiles" and k ~= "onboarding" then
                OffhandDB.profiles["Default"][k] = v
                OffhandDB[k] = nil
            end
        end
    end

    local profileSnapshotState = "none"
    if Offhand.isForever and not useForeverBridge then
        profileSnapshotState = ForeverPersistence:RestoreProfileSnapshot(OffhandDB, OffhandCharDB)
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

    local onboarding = EnsureOnboarding()
    -- Migrate the former profile-scoped flags into account-wide onboarding.
    -- A completed setup always implies that the welcome guide was acknowledged.
    if Offhand.db.firstRunComplete then
        onboarding.setupComplete = true
        onboarding.welcomeDismissed = true
    end
    if Offhand.db.suppressCompanionWarning then
        onboarding.suppressCompanionWarning = true
    end

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
    if useForeverBridge then
        ForeverPersistence:SeedSessionFallback()
    else
        -- The older field-specific CVars remain an upgrade path only. A complete
        -- profile fallback already contains these values, while a standard table
        -- with an equal/newer revision must remain authoritative after Blizzard
        -- repairs SavedVariables loading.
        if profileSnapshotState == "none" then
            ForeverPersistence:RestoreDisplayFlags(Offhand.db)
            ForeverPersistence:RestorePositions()
            ForeverPersistence:RestoreOpenPanels()
            ForeverPersistence:RestoreOnboarding(onboarding)
        elseif profileSnapshotState == "fallback" then
            -- Account-wide onboarding is intentionally outside the profile.
            ForeverPersistence:RestoreOnboarding(onboarding)
        end
    end
    SyncLegacyOnboarding()
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
    ForeverPersistence:SaveDisplayFlags(Offhand.db)
    
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
    ForeverPersistence:SaveDisplayFlags(Offhand.db)
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
    ForeverPersistence:SaveDisplayFlags(Offhand.db)
    
    Offhand:ApplyFullLayout()
    if self.Options and self.Options.RefreshPanel then self.Options:RefreshPanel() end
    Offhand:Print(L["MSG_PROFILE_RESET"])
end


