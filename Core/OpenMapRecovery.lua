-- Explicit, version-scoped recovery. No startup work, frame hooks or recurring mover.
local _, Offhand = ...
local Recovery = {}
Offhand.OpenMapRecovery = Recovery

local function Number(value)
    if type(issecretvalue) == "function" and issecretvalue(value) then return nil end
    if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then return nil end
    return value
end

local function Inspect(workspace)
    local compatibility = Offhand.CanvasCompatibility
    if not Offhand.db or not Offhand.db.enabled or not compatibility then return end
    if Offhand.IsGamepadUIEnabled and Offhand:IsGamepadUIEnabled() then return end
    if IsMouseButtonDown and IsMouseButtonDown("LeftButton") then return end
    local _, db = compatibility.GetOpenMapWindowModule()
    if not db or not Number(db.windowScale) or db.windowScale <= 0
        or (db.window ~= false and type(db.window) ~= "table") then return end
    if type(db.window) == "table" and (type(db.window[1]) ~= "string" or type(db.window[2]) ~= "string"
        or not Number(db.window[3]) or not Number(db.window[4])) then return end
    local map = _G.WorldMapFrame
    if not map or (map.IsForbidden and map:IsForbidden()) or not map:IsShown()
        or not map:IsVisible() or map:IsMaximized() then return end
    -- A SetPoint post-hook can also reapply the owner's saved size/scale. Refuse
    -- unsettled or malformed state rather than implicitly changing those values.
    local localScale, mapWidth, mapHeight = Number(map:GetScale()), Number(map:GetWidth()), Number(map:GetHeight())
    if not localScale or math.abs(localScale - db.windowScale) > .001
        or not mapWidth or not mapHeight or mapWidth <= 0 or mapHeight <= 0 then return end
    local size = db.windowSize
    if size ~= false and (type(size) ~= "table" or not Number(size[1]) or not Number(size[2])
        or math.abs(size[1] - mapWidth) > .5 or math.abs(size[2] - mapHeight) > .5) then return end
    local scale, parentScale = Number(map:GetEffectiveScale()), Number(UIParent:GetEffectiveScale())
    local width, height = Number(UIParent:GetWidth()), Number(UIParent:GetHeight())
    if not scale or not parentScale or scale <= 0 or parentScale <= 0
        or not width or not height or width <= 0 or height <= 0 then return end
    local factor = Number(scale / parentScale)
    if not factor or factor <= 0 then return end
    local metrics = Offhand.Viewport and Offhand.Viewport:GetMetrics()
    if not metrics then return end
    local left, right, bottom, top
    if workspace then
        if not metrics.isSpanned then return end
        local region = Offhand.WorkspaceRegions and Offhand.WorkspaceRegions:Get(metrics)
        if region then
            left, bottom = Number(region.x), Number(region.y)
            local regionWidth, regionHeight = Number(region.width), Number(region.height)
            if not left or not bottom or not regionWidth or not regionHeight then return end
            right, top = left + regionWidth, bottom + regionHeight
        else
            left, right = Number(metrics.workspaceLeft), Number(metrics.workspaceRight)
            bottom, top = Number(metrics.workspaceBottom), Number(metrics.workspaceTop)
        end
    else
        left, right = Number(metrics.gameLeft), Number(metrics.gameRight)
        bottom, top = Number(metrics.gameBottom), Number(metrics.gameTop)
    end
    if not left or not right or not bottom or not top then return end
    -- Metrics are UIParent units. Intersect with the current canvas; never use a
    -- stale saved desktop rectangle or the center of a span's physical void.
    left, right = math.max(0, left), math.min(width, right)
    bottom, top = math.max(0, bottom), math.min(height, top)
    if right - left < 160 or top - bottom < 100 then return end
    if workspace and (mapWidth * factor > right - left or mapHeight * factor > top - bottom) then
        return nil, "workspace-fit"
    end
    local count = Number(map:GetNumPoints())
    if not count or count < 1 or count > 16 or count % 1 ~= 0 then return end
    local points = {}
    for i = 1, count do points[i] = {map:GetPoint(i)} end
    local inset = workspace and math.min(24, top - bottom - mapHeight * factor) or 24
    return {map=map, db=db, points=points, factor=factor,
        left=left, right=right, bottom=bottom, top=top,
        anchor={"TOP", "BOTTOMLEFT", (left + right) / 2 / factor, (top - inset) / factor}}
end

function Recovery:Run(workspace)
    if InCombatLockdown and InCombatLockdown() then return false, "combat" end
    local read, state, reason = pcall(Inspect, workspace)
    if not read or not state then return false, read and reason or "unavailable" end
    local map, db, anchor = state.map, state.db, state.anchor
    local previous = db.window
    -- Set the owner's saved anchor BEFORE touching the root. Its existing Hold
    -- hook now agrees with the recovery instead of restoring the hidden anchor.
    local moved = pcall(function()
        db.window = anchor
        map:ClearAllPoints()
        map:SetPoint(anchor[1], UIParent, anchor[2], anchor[3], anchor[4])
        local point, relative, relativePoint, x, y = map:GetPoint(1)
        if map:GetNumPoints() ~= 1 or point ~= anchor[1] or relative ~= UIParent
            or relativePoint ~= anchor[2] or not Number(x) or not Number(y)
            or math.abs(x - anchor[3]) > .5 or math.abs(y - anchor[4]) > .5 then error("anchor rejected") end
        local titleTop = Number(map:GetTop())
        local mapLeft, mapWidth = Number(map:GetLeft()), Number(map:GetWidth())
        if not titleTop or not mapLeft or not mapWidth or mapWidth <= 0 then error("bounds unavailable") end
        local titleX, titleY = (mapLeft + mapWidth / 2) * state.factor, titleTop * state.factor
        if workspace then
            local mapHeight = Number(map:GetHeight())
            if not mapHeight or mapLeft * state.factor < state.left - .5
                or (mapLeft + mapWidth) * state.factor > state.right + .5
                or titleY > state.top + .5 or titleY - mapHeight * state.factor < state.bottom - .5 then
                error("map outside workspace")
            end
        elseif titleX < state.left + 12 or titleX > state.right - 12
            or titleY < state.bottom + 24 or titleY > state.top - 12 then error("title unreachable") end
    end)
    if not moved then
        db.window = previous
        pcall(function()
            map:ClearAllPoints()
            for _, point in ipairs(state.points) do map:SetPoint(unpack(point)) end
        end)
        return false, "unavailable"
    end
    return true
end

function Recovery:RunAndReport(workspace)
    local ok, reason = self:Run(workspace)
    local key = ok and (workspace and "OPENMAP_WORKSPACE_DONE" or "OPENMAP_RECOVERY_DONE")
        or (reason == "workspace-fit" and "OPENMAP_WORKSPACE_FIT")
        or (reason == "combat" and "OPENMAP_RECOVERY_COMBAT" or "OPENMAP_RECOVERY_UNAVAILABLE")
    Offhand:Print(Offhand.L[key])
    return ok, reason
end
