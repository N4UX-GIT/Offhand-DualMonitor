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

local function Position(context, map, target)
    local raw = FindSystem(context.source, map)
    local generated = FindSystem(context.generated, map)
    -- Offhand leaves EUI-owned rows equal to their source. Project those
    -- rows once, even when a generated layout already exists.
    local original = raw and raw.anchorInfo
    local relative = original and original.relativeTo
    local projected = raw and (not generated or ((not relative or relative == "UIParent")
        and SameAnchor(original, generated.anchorInfo)))
    local entry = projected and raw or generated
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
        if projected or not context.generatedActive or anchor.relativeTo ~= map.nativeReference then return end
        local refX, refY = NativeReferenceOrigin(_G[anchor.relativeTo], relativePoint, uiScale)
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

local function HasAnchorLink(eui, key)
    if eui.IsUnlockAnchored(key) then return true end
    -- An anchor target also moves its children. Exclude it until the preview
    -- can show the entire linked group.
    local anchors = EllesmereUIDB and EllesmereUIDB.unlockAnchors
    if type(anchors) == "table" then
        for _, link in pairs(anchors) do
            if type(link) == "table" and link.target == key then return true end
        end
    end
    return false
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
    local context = Offhand.Mainhand:GetEllesmereLayoutSource(direction == "fit")
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
    local uiScale = Scale(UIParent)
    local rows = {}
    for _, map in ipairs(mappings) do
        local element = eui._unlockRegisteredElements and eui._unlockRegisteredElements[map.key]
        local row = {map = map}
        local frame
        if element and type(element.getFrame) == "function" then
            local read, value = pcall(element.getFrame, map.key)
            if read then frame = value end
        end
        local bounds = uiScale and FrameBounds(frame, uiScale)
        row.current = bounds
        if context.controller and map.folder == actionBars then
            row.reason = "ELLESMERE_HUD_NATIVE_PAD"
        elseif not frame then
            row.reason = "ELLESMERE_HUD_MODULE_MISSING"
        elseif HasAnchorLink(eui, map.key) then
            row.reason = "ELLESMERE_HUD_LINKED"
        elseif direction == "fit" and bounds then
            if Fits(bounds, rect) or Fits(bounds, context.workspace) then
                row.reason = "ELLESMERE_HUD_KEEP"
            elseif bounds.width <= rect.width and bounds.height <= rect.height then
                local left = math.max(rect.left, math.min(bounds.left, rect.right - bounds.width))
                local bottom = math.max(rect.bottom, math.min(bounds.bottom, rect.top - bounds.height))
                row.proposed = {left = left, bottom = bottom, width = bounds.width, height = bounds.height}
                local ratio = ProfileOffsetScale(map, Scale(frame), uiScale)
                row.position = {point = "BOTTOMLEFT", relPoint = "BOTTOMLEFT", x = left * ratio, y = bottom * ratio}
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
                if bounds and not Fits(row.proposed, rect) then row.position, row.proposed = nil, nil end
            end
        end
        if not (row.position or row.anchor or row.reason) then row.reason = "ELLESMERE_HUD_NO_ANCHOR" end
        rows[#rows + 1] = row
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
