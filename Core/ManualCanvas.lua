--[[
    Offhand: Multi-Monitor Workspace Addon
    Core/ManualCanvas.lua: remembered addon-only window geometry
--]]

local _, Offhand = ...

local ManualCanvas = {}
Offhand.ManualCanvas = ManualCanvas

local SCHEMA = 1
local MAX_CANVASES = 8
local MATCH_DIMENSION_RATIO = 0.01
local MATCH_PIXEL_CAP = 48
local MATCH_ASPECT_RATIO = 0.0075
local CLOSE_DIMENSION_RATIO = 0.03
local CLOSE_ASPECT_RATIO = 0.015
local AMBIGUITY_SCORE_GAP = 0.0025

local function Finite(value)
    value = tonumber(value)
    return value and value == value and value > -math.huge and value < math.huge
        and value or nil
end

local function Positive(value)
    value = Finite(value)
    return value and value > 0 and value or nil
end

local function Unit(value)
    value = Finite(value)
    return value and value >= 0 and value <= 1 and value or nil
end

local function ValidNormalizedRect(rect)
    if type(rect) ~= "table" then return false end
    local x, y = Unit(rect.x), Unit(rect.y)
    local width, height = Positive(rect.width), Positive(rect.height)
    return x and y and width and height and width <= 1 and height <= 1
        and x + width <= 1.0001 and y + height <= 1.0001
end

local function Arrangement(db)
    if db and (db.layoutPreset == "STACKED_VERTICAL"
        or db.primaryPosition == "TOP" or db.primaryPosition == "BOTTOM") then
        return "STACKED"
    end
    return "SIDE_BY_SIDE"
end

local function CopyRect(rect)
    return { x = rect.x, y = rect.y, width = rect.width, height = rect.height }
end

function ManualCanvas:Validate(record)
    if type(record) ~= "table" or tonumber(record.schema) ~= SCHEMA then return nil end
    local width, height = Positive(record.referenceWidth), Positive(record.referenceHeight)
    local aspect, uiAspect = Positive(record.referenceAspect), Positive(record.uiCanvasAspect)
    local mode = record.measurementMode
    local arrangement = record.arrangement
    local position = record.primaryPosition
    if not width or not height or not aspect or not uiAspect
        or math.abs(aspect - width / height) > 0.0001
        or (mode ~= "PHYSICAL_CANVAS" and mode ~= "ASPECT_FALLBACK" and mode ~= "UNVERIFIED")
        or (arrangement ~= "SIDE_BY_SIDE" and arrangement ~= "STACKED")
        or (position ~= "LEFT" and position ~= "RIGHT"
            and position ~= "TOP" and position ~= "BOTTOM")
        or not ValidNormalizedRect(record.game)
        or not ValidNormalizedRect(record.workspace)
        or record.confirmed ~= true then
        return nil
    end
    return {
        schema = SCHEMA,
        name = type(record.name) == "string" and record.name or "Remembered canvas",
        source = record.source == "FANCYZONES" and "FANCYZONES" or "MANUAL",
        referenceWidth = width,
        referenceHeight = height,
        referenceAspect = aspect,
        uiCanvasAspect = uiAspect,
        measurementMode = mode,
        arrangement = arrangement,
        primaryPosition = position,
        game = CopyRect(record.game),
        workspace = CopyRect(record.workspace),
        confirmed = true,
        lastConfirmedBuild = record.lastConfirmedBuild,
    }
end
function ManualCanvas:EnsureStorage()
    if type(OffhandDB) ~= "table" then OffhandDB = {} end
    local storedSchema = tonumber(OffhandDB.manualCanvasSchema)
    if storedSchema and storedSchema > SCHEMA then
        self.storageStatus = "FUTURE_SCHEMA"
        return {}
    end
    self.storageStatus = "READY"
    if storedSchema ~= SCHEMA then
        OffhandDB.manualCanvasSchema = SCHEMA
        OffhandDB.manualCanvases = {}
    elseif type(OffhandDB.manualCanvases) ~= "table" then
        OffhandDB.manualCanvases = {}
    end
    local preference = OffhandDB.preferredGeometrySource
    if preference ~= "AUTO" and preference ~= "MANUAL" and preference ~= "EXACT" then
        OffhandDB.preferredGeometrySource = "AUTO"
    end
    return OffhandDB.manualCanvases
end

function ManualCanvas:GetGeometryPreference()
    self:EnsureStorage()
    return OffhandDB.preferredGeometrySource
end

function ManualCanvas:SetGeometryPreference(value)
    if value ~= "AUTO" and value ~= "MANUAL" and value ~= "EXACT" then return false end
    self:EnsureStorage()
    if self.storageStatus == "FUTURE_SCHEMA" then return false end
    OffhandDB.preferredGeometrySource = value
    return true
end

local function Errors(record, width, height, uiAspect)
    local widthPixels = math.abs(width - record.referenceWidth)
    local heightPixels = math.abs(height - record.referenceHeight)
    local widthError = widthPixels / record.referenceWidth
    local heightError = heightPixels / record.referenceHeight
    local aspectError = math.abs((width / height) - record.referenceAspect)
        / record.referenceAspect
    local uiAspectError = math.abs(uiAspect - record.uiCanvasAspect) / record.uiCanvasAspect
    return widthPixels, heightPixels, widthError, heightError, aspectError, uiAspectError
end

function ManualCanvas:Score(record, width, height, uiAspect, db)
    record = self:Validate(record)
    width, height, uiAspect = Positive(width), Positive(height), Positive(uiAspect)
    if not record or not width or not height or not uiAspect then return nil end
    local wp, hp, we, he, ae, ue = Errors(record, width, height, uiAspect)
    local state = "MISMATCH"
    if record.measurementMode == "UNVERIFIED" then
        state = "UNVERIFIED"
    elseif we <= MATCH_DIMENSION_RATIO and he <= MATCH_DIMENSION_RATIO
        and wp <= MATCH_PIXEL_CAP and hp <= MATCH_PIXEL_CAP
        and ae <= MATCH_ASPECT_RATIO and ue <= MATCH_ASPECT_RATIO then
        state = "MATCH"
    elseif we <= CLOSE_DIMENSION_RATIO and he <= CLOSE_DIMENSION_RATIO
        and ae <= CLOSE_ASPECT_RATIO and ue <= CLOSE_ASPECT_RATIO then
        state = "CLOSE"
    end
    return {
        record = record,
        state = state,
        score = we + he + ae + ue,
        widthError = we,
        heightError = he,
        aspectError = ae,
        uiAspectError = ue,
    }
end

function ManualCanvas:Match(width, height, uiAspect, db)
    local candidates = {}
    for id, raw in pairs(self:EnsureStorage()) do
        local candidate = self:Score(raw, width, height, uiAspect, db)
        if candidate and candidate.state ~= "MISMATCH" then
            candidate.id = id
            candidates[#candidates + 1] = candidate
        end
    end
    table.sort(candidates, function(a, b) return a.score < b.score end)
    if #candidates == 0 then
        return { state = "MISMATCH", candidateCount = 0 }
    end
    if #candidates > 1
        and math.abs(candidates[2].score - candidates[1].score) <= AMBIGUITY_SCORE_GAP then
        return { state = "AMBIGUOUS", candidateCount = #candidates,
            first = candidates[1], second = candidates[2] }
    end
    local winner = candidates[1]
    winner.candidateCount = #candidates
    return winner
end

local function NextID(canvases)
    for index = 1, MAX_CANVASES do
        local id = "manual-" .. index
        if canvases[id] == nil then return id end
    end
end

function ManualCanvas:RememberFromMetrics(metrics, name, source)
    if type(metrics) ~= "table" then return false, "unavailable" end
    local width, height = Positive(metrics.physicalWidth), Positive(metrics.physicalHeight)
    local sw, sh = Positive(metrics.screenWidth), Positive(metrics.screenHeight)
    if not width or not height or not sw or not sh then return false, "unavailable" end
    local canvases = self:EnsureStorage()
    if self.storageStatus == "FUTURE_SCHEMA" then return false, "future-schema" end
    local current = self:Match(width, height, sw / sh, Offhand.db)
    if current.state == "AMBIGUOUS" then return false, "ambiguous" end
    local id = (current.state == "MATCH" or current.state == "CLOSE") and current.id
        or NextID(canvases)
    if not id then return false, "limit" end
    local function normalize(x, y, w, h)
        return { x = x / width, y = y / height, width = w / width, height = h / height }
    end
    local build
    if GetBuildInfo then
        local ok, version, number, _, interfaceVersion = pcall(GetBuildInfo)
        if ok then build = table.concat({tostring(version or ""), tostring(number or ""),
            tostring(interfaceVersion or "")}, ":") end
    end
    local record = {
        schema = SCHEMA,
        name = type(name) == "string" and name ~= "" and name
            or (canvases[id] and canvases[id].name)
            or string.format("%dx%d %s", width, height, Arrangement(Offhand.db)),
        source = source == "FANCYZONES" and "FANCYZONES" or "MANUAL",
        referenceWidth = width,
        referenceHeight = height,
        referenceAspect = width / height,
        uiCanvasAspect = sw / sh,
        measurementMode = "PHYSICAL_CANVAS",
        arrangement = Arrangement(Offhand.db),
        primaryPosition = Offhand.db and Offhand.db.primaryPosition or "RIGHT",
        game = normalize(metrics.gamePixelLeft, metrics.gamePixelBottom,
            metrics.gamePixelWidth, metrics.gamePixelHeight),
        workspace = normalize(metrics.workspacePixelLeft, metrics.workspacePixelBottom,
            metrics.workspacePixelWidth, metrics.workspacePixelHeight),
        confirmed = true,
        lastConfirmedBuild = build,
    }
    if not self:Validate(record) then return false, "invalid" end
    canvases[id] = record
    -- Remembering the current window explicitly hands geometry ownership from
    -- any loaded Companion bridge to the confirmed manual canvas. Keep that
    -- choice active so stale exact topology cannot retake priority on the next
    -- metrics read. Selecting Companion changes the preference back to AUTO.
    OffhandDB.preferredGeometrySource = "MANUAL"
    self.lastMatch = nil
    return true, id, record
end

function ManualCanvas:Forget(id)
    local canvases = self:EnsureStorage()
    if self.storageStatus == "FUTURE_SCHEMA" then return false end
    if type(id) ~= "string" or canvases[id] == nil then return false end
    canvases[id] = nil
    self.lastMatch = nil
    return true
end

function ManualCanvas:GetDiagnostics()
    local count = 0
    for _ in pairs(self:EnsureStorage()) do count = count + 1 end
    local match = self.lastMatch or {}
    return {
        schema = SCHEMA,
        preference = self:GetGeometryPreference(),
        count = count,
        state = self.storageStatus == "FUTURE_SCHEMA" and "FUTURE_SCHEMA"
            or match.state or "UNEVALUATED",
        id = match.id,
        name = match.record and match.record.name or nil,
        source = match.record and match.record.source or nil,
        candidateCount = match.candidateCount or 0,
    }
end

