--[[
    Offhand: Multi-Monitor Workspace Addon
    Core/CanvasPersistence.lua: Saved Canvas position normalization
--]]

local _, Offhand = ...

local Persistence = {}
Offhand.CanvasPersistence = Persistence

local function PositiveDimension(value, fallback)
    value = tonumber(value)
    if value and value > 0 then return value end
    return fallback
end

function Persistence.EnsurePositionTables(db)
    if type(db) ~= "table" then return false end
    db.savedWorkspacePositions = db.savedWorkspacePositions or {}
    db.savedMainPositions = db.savedMainPositions or {}
    return true
end

function Persistence.IsPosition(position)
    return type(position) == "table"
        and tonumber(position.x) ~= nil
        and tonumber(position.y) ~= nil
end

function Persistence.ClampWorkspacePoint(metrics, x, y, frameWidth, frameHeight, isChat)
    if type(metrics) ~= "table" then return nil end
    x, y = tonumber(x), tonumber(y)
    if not x or not y then return nil end

    frameWidth = PositiveDimension(frameWidth, 192)
    frameHeight = PositiveDimension(frameHeight, 192)
    local inset = isChat and 48 or 12
    local minX = metrics.workspaceLeft + inset
    local maxX = math.max(minX, metrics.workspaceRight - frameWidth - 12)
    local minY = metrics.workspaceBottom + frameHeight + 12
    local maxY = math.max(minY, metrics.workspaceTop - 12)
    return math.max(minX, math.min(x, maxX)),
        math.max(minY, math.min(y, maxY))
end

function Persistence.CreateWorkspacePosition(metrics, x, y, frameWidth, frameHeight, isChat,
        fallbackHeight)
    local clampedX, clampedY = Persistence.ClampWorkspacePoint(
        metrics, x, y, frameWidth, frameHeight, isChat
    )
    if not clampedX then return nil end
    local canvasHeight = PositiveDimension(metrics.workspaceHeight,
        PositiveDimension(metrics.screenHeight, fallbackHeight or 1080))
    return {
        x = clampedX,
        y = clampedY,
        canvasWidth = metrics.workspaceWidth,
        canvasHeight = canvasHeight,
        canvasLeft = metrics.workspaceLeft,
        canvasBottom = metrics.workspaceBottom,
    }
end

function Persistence.ResolveWorkspacePosition(metrics, position, frameWidth, frameHeight, isChat,
        fallbackHeight)
    if type(metrics) ~= "table" or not Persistence.IsPosition(position) then return nil end

    local targetX = tonumber(position.x)
    local savedCanvasWidth = tonumber(position.canvasWidth)
    local savedCanvasLeft = tonumber(position.canvasLeft) or 0
    if savedCanvasWidth and savedCanvasWidth > 0 and metrics.workspaceWidth > 0 then
        targetX = metrics.workspaceLeft
            + (targetX - savedCanvasLeft) * metrics.workspaceWidth / savedCanvasWidth
    end

    local canvasHeight = PositiveDimension(metrics.workspaceHeight,
        PositiveDimension(metrics.screenHeight, fallbackHeight or 1080))
    local targetY = tonumber(position.y)
    local savedCanvasHeight = tonumber(position.canvasHeight)
    local savedCanvasBottom = tonumber(position.canvasBottom) or 0
    if savedCanvasHeight and savedCanvasHeight > 0 and canvasHeight > 0 then
        targetY = metrics.workspaceBottom
            + (targetY - savedCanvasBottom) * canvasHeight / savedCanvasHeight
    end

    return Persistence.ClampWorkspacePoint(
        metrics, targetX, targetY, frameWidth, frameHeight, isChat
    )
end

