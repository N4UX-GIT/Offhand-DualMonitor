-- One-time handoffs between Forever Edit Mode and EllesmereUI profiles.
local _, Offhand = ...
if not Offhand.isForever then return end
local Transfer = {}
Offhand.EllesmereLayout = Transfer

local actionBars = "EllesmereUIActionBars"
local minimap = "EllesmereUIMinimap"
local units = "EllesmereUIUnitFrames"
local mappings = {
    {system = "ActionBar", indices = "EditModeActionBarSystemIndices", index = "MainBar",
        label = "ELLESMERE_HUD_MAIN_BAR", folder = actionBars, key = "MainBar",
        positionTable = "barPositions", positionKey = "MainBar", nativeReference = "MicroMenuContainer"},
    {system = "Minimap", label = "ELLESMERE_HUD_MINIMAP", folder = minimap,
        key = "EBS_Minimap", positionTable = "minimap", positionKey = "position"},
    {system = "UnitFrame", indices = "EditModeUnitFrameSystemIndices", index = "Player",
        label = "ELLESMERE_HUD_PLAYER", folder = units, key = "player",
        positionTable = "positions", positionKey = "player"},
    {system = "UnitFrame", indices = "EditModeUnitFrameSystemIndices", index = "Target",
        label = "ELLESMERE_HUD_TARGET", folder = units, key = "target",
        positionTable = "positions", positionKey = "target"},
    {system = "UnitFrame", indices = "EditModeUnitFrameSystemIndices", index = "Focus",
        label = "ELLESMERE_HUD_FOCUS", folder = units, key = "focus",
        positionTable = "positions", positionKey = "focus"},
}
for number, index in ipairs({"Bar2", "Bar3", "RightBar1", "RightBar2", "ExtraBar1", "ExtraBar2", "ExtraBar3"}) do
    local key = "Bar" .. (number + 1)
    mappings[#mappings + 1] = {system = "ActionBar", indices = "EditModeActionBarSystemIndices", index = index,
        label = "ELLESMERE_HUD_NUMBERED_BAR", number = number + 1, folder = actionBars, key = key,
        positionTable = "barPositions", positionKey = key, optional = true}
end

local points = {
    TOPLEFT = true, TOP = true, TOPRIGHT = true, LEFT = true, CENTER = true,
    RIGHT = true, BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true,
}

local function PublicNumber(value)
    return (not issecretvalue or not issecretvalue(value)) and type(value) == "number"
        and value == value and math.abs(value) < math.huge
end

local function FindSystem(layout, map)
    local system = Enum.EditModeSystem and Enum.EditModeSystem[map.system]
    local indices = map.indices and Enum[map.indices]
    local index = indices and indices[map.index]
    if not layout or system == nil or (map.index and index == nil) then return nil end
    for _, entry in ipairs(layout.systems or {}) do
        if entry.system == system and (not map.index or entry.systemIndex == index) then return entry end
    end
end

local function SameAnchor(a, b)
    return a and b and a.point == b.point and a.relativePoint == b.relativePoint
        and a.relativeTo == b.relativeTo and PublicNumber(a.offsetX) and PublicNumber(a.offsetY)
        and PublicNumber(b.offsetX) and PublicNumber(b.offsetY)
        and a.offsetX == b.offsetX and a.offsetY == b.offsetY
end

local function PointOrigin(point, left, bottom, right, top)
    return point:find("LEFT") and left or point:find("RIGHT") and right or (left + right) / 2,
        point:find("BOTTOM") and bottom or point:find("TOP") and top or (bottom + top) / 2
end

local function Scale(frame)
    if not frame or not frame.GetEffectiveScale or (frame.IsForbidden and frame:IsForbidden()) then return end
    local value = frame:GetEffectiveScale()
    if PublicNumber(value) and value > 0 then return value end
end

local function FrameBounds(frame, uiScale)
    local scale = Scale(frame)
    if not scale or not frame.GetRect then return end
    local left, bottom, width, height = frame:GetRect()
    if not PublicNumber(left) or not PublicNumber(bottom) or not PublicNumber(width)
        or not PublicNumber(height) or width <= 0 or height <= 0 then return end
    local ratio = scale / uiScale
    return {left = left * ratio, bottom = bottom * ratio, width = width * ratio, height = height * ratio}
end

local function NativeReferenceOrigin(frame, point, uiScale)
    if not frame or not frame.IsVisible or not frame:IsVisible() then return end
    local b = FrameBounds(frame, uiScale)
    if b then return PointOrigin(point, b.left, b.bottom, b.left + b.width, b.bottom + b.height) end
end

local function ProfileOffsetScale(map, targetScale, uiScale)
    -- Unit Frames stores UIParent offsets and compensates for its own scale
    -- when applying them. Action Bars and Minimap store frame-local offsets.
    return map.folder == units and 1 or uiScale / targetScale
end

local function SerializedMenuOrigin(context, point, uiScale)
    local entry = FindSystem(context.transferLayout or context.generated, {system = "MicroMenu"})
    local anchor = entry and entry.anchorInfo
    if not anchor or entry.anchorInfo2 or (anchor.relativeTo and anchor.relativeTo ~= "UIParent")
        or not points[anchor.point] or not points[anchor.relativePoint]
        or not PublicNumber(anchor.offsetX) or not PublicNumber(anchor.offsetY) then return end
    local frame = _G.MicroMenuContainer
    local scale = Scale(frame)
    if not scale or not frame.GetWidth or not frame.GetHeight then return end
    local width, height = frame:GetWidth(), frame:GetHeight()
    if not PublicNumber(width) or not PublicNumber(height) or width <= 0 or height <= 0 then return end
    width, height = width * scale / uiScale, height * scale / uiScale
    local x, y = PointOrigin(anchor.relativePoint, 0, 0, context.rect.screenWidth, context.rect.screenHeight)
    local dx, dy = PointOrigin(anchor.point, 0, 0, width, height)
    return PointOrigin(point, x + anchor.offsetX - dx, y + anchor.offsetY - dy,
        x + anchor.offsetX - dx + width, y + anchor.offsetY - dy + height)
end

local function Position(context, map, target)
    local raw = FindSystem(context.source, map)
    local generated = FindSystem(context.generated, map)
    -- Offhand leaves EUI-owned rows equal to their source. Project those
    -- rows once, even when a generated layout already exists.
    local original = raw and raw.anchorInfo
    local relative = original and original.relativeTo
    local projected = raw and raw.isInDefaultPosition ~= false and (not generated or ((not relative or relative == "UIParent")
        and SameAnchor(original, generated.anchorInfo)))
    local entry = FindSystem(context.transferLayout, map) or (projected and raw or generated)
    if context.transferLayout then projected = false end
    local anchor = entry and entry.anchorInfo
    if not anchor or entry.anchorInfo2
        or not points[anchor.point] or not points[anchor.relativePoint]
        or not PublicNumber(anchor.offsetX) or not PublicNumber(anchor.offsetY) then return end

    local targetScale, uiScale = Scale(target), Scale(UIParent)
    if not targetScale or not uiScale then return end
    local rect = context.rect
    local relativePoint = anchor.relativePoint
    local screenX, screenY = PointOrigin(relativePoint, 0, 0, rect.screenWidth, rect.screenHeight)
    -- Blizzard divides serialized offsets by its system scale on apply.
    -- UIParent-relative layout offsets are therefore already in UIParent units.
    local x, y = anchor.offsetX, anchor.offsetY
    if anchor.relativeTo and anchor.relativeTo ~= "UIParent" then
        -- This Forever layout places Action Bar 1 beside the Micro Menu.
        -- Resolve that reference only while this generated layout is active.
        if projected or anchor.relativeTo ~= map.nativeReference then return end
        local refX, refY = SerializedMenuOrigin(context, relativePoint, uiScale)
        if not refX and context.generatedActive then
            refX, refY = NativeReferenceOrigin(_G[anchor.relativeTo], relativePoint, uiScale)
        end
        if not refX then return end
        x, y = x + refX, y + refY
        relativePoint, screenX, screenY = "BOTTOMLEFT", 0, 0
    elseif projected then
        local gameX, gameY = PointOrigin(relativePoint, rect.left, rect.bottom, rect.right, rect.top)
        x, y = x + gameX - screenX, y + gameY - screenY
    end
    if x + screenX < rect.left or x + screenX > rect.right
        or y + screenY < rect.bottom or y + screenY > rect.top then return end
    local ratio = ProfileOffsetScale(map, targetScale, uiScale)
    return {point = anchor.point, relPoint = relativePoint, x = x * ratio, y = y * ratio}, x + screenX, y + screenY
end

local function Fits(b, rect)
    return rect and b.left >= rect.left and b.bottom >= rect.bottom
        and b.left + b.width <= rect.right and b.bottom + b.height <= rect.top
end

local function HasOverrides(profile)
    return profile and (profile.specOverrides or profile.condOverrides
        or profile.specOverrideGroups or profile.condOverrideGroups)
end

local function ElementFrame(eui, key)
    local element = eui._unlockRegisteredElements and eui._unlockRegisteredElements[key]
    if element and type(element.getFrame) == "function" then
        local ok, frame = pcall(element.getFrame, key)
        if ok then return frame end
    end
end

local function ElementHidden(eui, key)
    local element = eui._unlockRegisteredElements and eui._unlockRegisteredElements[key]
    if element and type(element.isHidden) == "function" then
        local ok, hidden = pcall(element.isHidden, key)
        return ok and hidden == true
    end
end

local function GroupBounds(eui, key, bounds, uiScale)
    if not bounds or eui.IsUnlockAnchored(key) then return end
    local group = {left = bounds.left, bottom = bounds.bottom, width = bounds.width, height = bounds.height}
    local keys, members = {key}, {[key] = true}
    local anchors = EllesmereUIDB and EllesmereUIDB.unlockAnchors
    if type(anchors) == "table" then
        local i = 1
        while i <= #keys do
            for child, link in pairs(anchors) do
                if type(link) == "table" and link.target == keys[i] then
                    if members[child] or #keys >= 100 then return end
                    members[child], keys[#keys + 1] = true, child
                    local b = FrameBounds(ElementFrame(eui, child), uiScale)
                    if b then
                        local right = math.max(group.left + group.width, b.left + b.width)
                        local top = math.max(group.bottom + group.height, b.bottom + b.height)
                        group.left, group.bottom = math.min(group.left, b.left), math.min(group.bottom, b.bottom)
                        group.width, group.height = right - group.left, top - group.bottom
                    elseif not ElementHidden(eui, child) then
                        return
                    end
                end
            end
            i = i + 1
        end
    end
    return group, #keys > 1, members
end

local function GamepadMinimapObstacles(eui, uiScale)
    local obstacles = {}
    for _, map in ipairs(mappings) do
        if map.folder == actionBars and not ElementHidden(eui, map.key) then
            local bounds = FrameBounds(ElementFrame(eui, map.key), uiScale)
            if bounds then
                bounds.key = map.key
                obstacles[#obstacles + 1] = bounds
            end
        end
    end
    for _, name in ipairs({"BuffFrame", "DebuffFrame"}) do
        local frame = _G[name]
        if frame and frame.IsVisible and not (frame.IsForbidden and frame:IsForbidden()) and frame:IsVisible() then
            local bounds = FrameBounds(frame, uiScale)
            if bounds then obstacles[#obstacles + 1] = bounds end
        end
    end
    return obstacles
end

local frameClearance = 8

local function Overlaps(left, bottom, group, obstacle)
    return left < obstacle.left + obstacle.width + frameClearance and left > obstacle.left - group.width - frameClearance
        and bottom < obstacle.bottom + obstacle.height + frameClearance
        and bottom > obstacle.bottom - group.height - frameClearance
end

local function ClearsObstacles(left, bottom, group, obstacles, members)
    for _, obstacle in ipairs(obstacles) do
        if not members[obstacle.key] and Overlaps(left, bottom, group, obstacle) then
            return false
        end
    end
    return true
end

local function ClearPosition(left, bottom, group, rect, obstacles, members)
    if ClearsObstacles(left, bottom, group, obstacles, members) then return left, bottom end
    local xs, ys = {left}, {bottom}
    -- Any nearest clear position keeps a preferred axis or touches a padded
    -- obstacle edge. Check combinations to fit between several frames.
    for _, obstacle in ipairs(obstacles) do
        if not members[obstacle.key] then
            xs[#xs + 1] = obstacle.left - group.width - frameClearance
            xs[#xs + 1] = obstacle.left + obstacle.width + frameClearance
            ys[#ys + 1] = obstacle.bottom - group.height - frameClearance
            ys[#ys + 1] = obstacle.bottom + obstacle.height + frameClearance
        end
    end
    local bestX, bestY, bestDistance
    for _, x in ipairs(xs) do
        if x >= rect.left and x <= rect.right - group.width then
            for _, y in ipairs(ys) do
                local distance = (x - left) ^ 2 + (y - bottom) ^ 2
                if y >= rect.bottom and y <= rect.top - group.height and (not bestDistance or distance < bestDistance)
                    and ClearsObstacles(x, y, group, obstacles, members) then
                    bestX, bestY, bestDistance = x, y, distance
                end
            end
        end
    end
    return bestX or left, bestY or bottom
end

local function PlaceGroup(row, bounds, group, rect, ratio, obstacles, members)
    if group.width > rect.width or group.height > rect.height then
        row.position, row.proposed = nil, nil
        return
    end
    local dx, dy = row.proposed.left - bounds.left, row.proposed.bottom - bounds.bottom
    local left = math.max(rect.left, math.min(group.left + dx, rect.right - group.width))
    local bottom = math.max(rect.bottom, math.min(group.bottom + dy, rect.top - group.height))
    if obstacles then left, bottom = ClearPosition(left, bottom, group, rect, obstacles, members) end
    dx, dy = left - group.left, bottom - group.bottom
    row.position.x = row.position.x + (bounds.left + dx - row.proposed.left) * ratio
    row.position.y = row.position.y + (bounds.bottom + dy - row.proposed.bottom) * ratio
    row.proposed.left, row.proposed.bottom = bounds.left + dx, bounds.bottom + dy
    row.groupProposed = {left = left, bottom = bottom, width = group.width, height = group.height}
end

local function FitDefaultFocus(row, targetRow, rect)
    local focus = row.groupProposed
    local target = targetRow and (targetRow.groupProposed or targetRow.groupCurrent or targetRow.current)
    if not focus or not target or not Overlaps(focus.left, focus.bottom, focus, target) then return end
    -- Keep the stock horizontal relationship if the wider replacement fits.
    local left, bottom = target.left + target.width + frameClearance, focus.bottom
    if left + focus.width > rect.right then
        left, bottom = focus.left, target.bottom + target.height + frameClearance
    end
    if left < rect.left or left + focus.width > rect.right or bottom + focus.height > rect.top then return end
    local dx, dy = left - focus.left, bottom - focus.bottom
    row.position.x, row.position.y = row.position.x + dx, row.position.y + dy
    row.proposed.left, row.proposed.bottom = row.proposed.left + dx, row.proposed.bottom + dy
    focus.left, focus.bottom = left, bottom
end

local function GetWorkspaceRect()
    local metrics = Offhand.Viewport and Offhand.Viewport:GetMetrics()
    if metrics and metrics.isSpanned and metrics.workspaceRight > metrics.workspaceLeft
        and metrics.workspaceTop > metrics.workspaceBottom then
        return {left = metrics.workspaceLeft, bottom = metrics.workspaceBottom,
            right = metrics.workspaceRight, top = metrics.workspaceTop}
    end
end

function Transfer:IsAvailable()
    local eui = _G.EllesmereUI
    return Offhand.db and Offhand.db.enabled and eui and type(eui.IsUnlockAnchored) == "function"
end

function Transfer:Preview(direction)
    direction = direction or "fit"
    local eui = _G.EllesmereUI
    if not self:IsAvailable() or not Enum then return nil, "ELLESMERE_HUD_UNAVAILABLE" end
    local manager = _G.EditModeManagerFrame
    if InCombatLockdown() or (manager and (manager.editModeActive or (manager.IsShown and manager:IsShown())))
        or (eui.IsUnlockModeActive and eui:IsUnlockModeActive())
        or (eui.SpecOverrides_EditSessionActive and eui.SpecOverrides_EditSessionActive())
        or (Offhand.IsBlizzardInputReserved and Offhand:IsBlizzardInputReserved()) then
        return nil, "ELLESMERE_HUD_BUSY"
    end
    local targetSizes = {}
    local uiScale = Scale(UIParent)
    for _, map in ipairs(mappings) do
        if map.index == "RightBar1" or map.index == "RightBar2" then
            local bounds = uiScale and FrameBounds(ElementFrame(eui, map.key), uiScale)
            local index = Enum.EditModeActionBarSystemIndices and Enum.EditModeActionBarSystemIndices[map.index]
            if bounds and index then targetSizes[index] = {width = bounds.width, height = bounds.height} end
        end
    end
    local context = Offhand.Mainhand:GetEllesmereLayoutSource(direction == "fit", targetSizes)
    if not context and direction ~= "fit" then
        context = Offhand.Mainhand:GetEllesmereLayoutSource(true)
    end
    if not context then return nil, "ELLESMERE_HUD_NO_LAYOUT" end
    local rect = context.rect
    context.workspace = GetWorkspaceRect()
    context.profileName = eui.GetActiveProfileName and eui.GetActiveProfileName()
    local profile = eui.GetActiveProfileData and eui.GetActiveProfileData()
    if HasOverrides(profile) then context.block = "ELLESMERE_HUD_OVERRIDES" end
    if (direction == "ellesmere" or direction == "blizzard") and not context.generated then
        context.block = "ELLESMERE_HUD_NEED_NATIVE"
    end
    local minimapObstacles = context.controller and direction ~= "blizzard" and uiScale and GamepadMinimapObstacles(eui, uiScale)
    local rows, targetRow = {}
    for _, map in ipairs(mappings) do
        local row = {map = map}
        local frame = ElementFrame(eui, map.key)
        if not map.optional or (frame and not ElementHidden(eui, map.key)) then
            local bounds = uiScale and FrameBounds(frame, uiScale)
            row.current = bounds
            local group, members
            if direction ~= "blizzard" then
                group, row.linkedGroup, members = GroupBounds(eui, map.key, bounds, uiScale)
                if row.linkedGroup then row.groupCurrent = group end
            end
            local obstacles = map.folder == minimap and minimapObstacles
            if context.controller and map.folder == actionBars then
                row.reason = "ELLESMERE_HUD_NATIVE_PAD"
            elseif not frame then
                row.reason = "ELLESMERE_HUD_MODULE_MISSING"
            elseif direction ~= "blizzard" and not group then
                row.reason = "ELLESMERE_HUD_LINKED"
            elseif direction == "fit" and bounds then
                local fits = Fits(group, rect)
                if fits and (not obstacles or ClearsObstacles(group.left, group.bottom, group, obstacles, members)) then
                    row.reason = "ELLESMERE_HUD_KEEP"
                elseif group.width <= rect.width and group.height <= rect.height then
                    local left = math.max(rect.left, math.min(bounds.left, rect.right - bounds.width))
                    local bottom = math.max(rect.bottom, math.min(bounds.bottom, rect.top - bounds.height))
                    row.proposed = {left = left, bottom = bottom, width = bounds.width, height = bounds.height}
                    local ratio = ProfileOffsetScale(map, Scale(frame), uiScale)
                    row.position = {point = "BOTTOMLEFT", relPoint = "BOTTOMLEFT", x = left * ratio, y = bottom * ratio}
                    PlaceGroup(row, bounds, group, rect, ratio, obstacles, members)
                    if fits and row.proposed.left == bounds.left and row.proposed.bottom == bounds.bottom then
                        row.position, row.proposed, row.groupProposed = nil, nil, nil
                    end
                end
            elseif direction == "blizzard" and bounds then
                local entry = FindSystem(context.generated, map)
                if entry and not entry.anchorInfo2 and (Fits(bounds, rect) or Fits(bounds, context.workspace)) then
                    local x, y = bounds.left + bounds.width / 2, bounds.bottom + bounds.height / 2
                    row.system, row.systemIndex = entry.system, entry.systemIndex
                    row.anchor = {point = "CENTER", relativePoint = "BOTTOMLEFT", relativeTo = "UIParent",
                        offsetX = x, offsetY = y}
                    -- The native frame can have a different size. Show the destination anchor.
                    row.proposed = {left = x, bottom = y, width = 0, height = 0}
                end
            elseif direction == "ellesmere" and not context.block then
                local x, y
                row.position, x, y = Position(context, map, frame)
                if row.position then
                    local width, height = bounds and bounds.width or 0, bounds and bounds.height or 0
                    local dx, dy = PointOrigin(row.position.point, 0, 0, width, height)
                    row.proposed = {left = x - dx, bottom = y - dy, width = width, height = height}
                    PlaceGroup(row, bounds, group, rect, ProfileOffsetScale(map, Scale(frame), uiScale), obstacles, members)
                    if context.controller and map.key == "focus" and context.transferDefaults
                        and context.transferDefaults[FindSystem(context.transferLayout, map)] then
                        FitDefaultFocus(row, targetRow, rect)
                    end
                end
            end
            if not (row.position or row.anchor or row.reason) then row.reason = "ELLESMERE_HUD_NO_ANCHOR" end
            if map.key == "target" then targetRow = row end
            rows[#rows + 1] = row
        end
    end
    -- A mapped child follows the selected root rather than receiving its own
    -- saved position. Show that movement even when the child is not selectable.
    local roots = {}
    for _, row in ipairs(rows) do
        if row.position then roots[row.map.key] = row end
    end
    local links = EllesmereUIDB and EllesmereUIDB.unlockAnchors
    for _, row in ipairs(rows) do
        if direction ~= "blizzard" and not row.position and row.current and type(links) == "table" then
            local key, seen = row.map.key, {}
            while type(links[key]) == "table" and links[key].target and not seen[key] do
                seen[key], key = true, links[key].target
                local root = roots[key]
                if root then
                    row.followKey, row.reason = key, "ELLESMERE_HUD_MOVE_GROUP"
                    row.proposed = {left = row.current.left + root.proposed.left - root.current.left,
                        bottom = row.current.bottom + root.proposed.bottom - root.current.bottom,
                        width = row.current.width, height = row.current.height}
                    break
                end
            end
        end
    end
    local native = context.generated or context.source
    return rows, native and native.layoutName, context
end

function Transfer:HasPendingReload()
    local eui = _G.EllesmereUI
    return self.reloadProfile ~= nil and eui and eui.GetActiveProfileName
        and eui.GetActiveProfileName() == self.reloadProfile
end

function Transfer:OpenImport(rows, onComplete)
    local eui = _G.EllesmereUI
    if not (eui.SnapshotAllAddons and eui.EncodePayload and eui.ImportProfileInteractive
        and eui.GetActiveProfileData and eui.GetProfileKeys) then return false end
    local snapshot = eui.SnapshotAllAddons()
    if not snapshot or not snapshot.addons then return false end
    if HasOverrides(snapshot) then
        return false, "ELLESMERE_HUD_OVERRIDES"
    end
    local addons = {}
    for _, row in ipairs(rows) do
        if row.position then
            local map = row.map
            local profile = snapshot.addons[map.folder]
            if type(profile) ~= "table" then return false end
            local positions = profile[map.positionTable]
            if not positions then positions = {}; profile[map.positionTable] = positions end
            if type(positions) ~= "table" then return false end
            positions[map.positionKey] = row.position
            addons[map.folder] = profile
        end
    end
    if not next(addons) then return false, "ELLESMERE_HUD_NO_CHANGES" end
    local base = eui.GetActiveProfileData()
    local payload = {version = 3, type = "full", data = {
        addons = addons, partialImport = true, layoutExcluded = true, overridesExcluded = true,
        windowSkinLook = base and base.windowSkinLook,
    }}
    if eui.StampPayloadClient then eui.StampPayloadClient(payload) end
    local encoded = eui.EncodePayload(payload)
    if not encoded then return false end

    local name = "Offhand HUD"
    local existing = {}
    for key in pairs(eui.GetProfileKeys()) do existing[key:lower()] = true end
    local suffix = 1
    while existing[name:lower()] do
        suffix = suffix + 1
        name = "Offhand HUD (" .. suffix .. ")"
    end
    local activeBefore = eui.GetActiveProfileName and eui.GetActiveProfileName()
    return eui.ImportProfileInteractive({
        importString = encoded, profileName = name, source = "Offhand",
        callback = function(accepted)
            local result
            if accepted then
                -- The review allows renaming the new profile. Compare against
                -- the outgoing profile rather than the suggested import name.
                local activeAfter = eui.GetActiveProfileName and eui.GetActiveProfileName()
                if activeBefore and activeAfter and activeAfter ~= activeBefore then
                    self.reloadProfile = activeAfter
                    result = "reload"
                else
                    result = "inactive"
                end
                Offhand:Print(Offhand.L[result == "reload" and "ELLESMERE_HUD_RELOAD" or "ELLESMERE_HUD_SAVED_INACTIVE"])
            end
            if onComplete then onComplete(result) end
        end,
    })
end

function Transfer:Run(action)
    local L = Offhand.L
    if action ~= "" and action ~= "preview" and action ~= "import" and action ~= "fallback" then
        Offhand:Print(L["ELLESMERE_HUD_HELP"])
        return
    end
    if self.ShowPreview then
        self:ShowPreview(action == "import" and "ellesmere" or action == "fallback" and "blizzard" or "fit")
    else
        Offhand:Print(L["ELLESMERE_HUD_UNAVAILABLE"])
    end
end
