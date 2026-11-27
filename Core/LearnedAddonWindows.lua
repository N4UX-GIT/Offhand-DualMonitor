local _, Offhand = ...
local Windows = {}
Offhand.LearnedAddonWindows = Windows

local MAX_WINDOWS, MAX_CHILDREN = 32, 256
local regions = Offhand.WorkspaceRegions
local active = {}
local selectableStrata = {LOW = true, MEDIUM = true, HIGH = true,
    DIALOG = true, FULLSCREEN = true, FULLSCREEN_DIALOG = true}

local function Plain(value)
    return not issecretvalue or not issecretvalue(value)
end

local function Finite(value)
    return Plain(value) and type(value) == "number" and value > -math.huge and value < math.huge
end

local function ValidName(name)
    return Plain(name) and type(name) == "string" and #name <= 128
        and name:match("^[%a_][%w_]*$") ~= nil
end

local function CanInspect()
    return Offhand.isForever and not (Offhand.Bridges and Offhand.Bridges:HasRole("hud.controller"))
        and not Offhand._displayGeometryTransitionActive
        and not (InCombatLockdown and InCombatLockdown())
        and not (Offhand.IsGamepadUIEnabled and Offhand:IsGamepadUIEnabled())
        and not (EditModeManagerFrame and EditModeManagerFrame:IsShown())
        and not (Offhand.Bridges and Offhand.Bridges:IsEditModeActive())
end

local function Metrics()
    local metrics = Offhand.db and Offhand.db.enabled and Offhand.Viewport
        and Offhand.Viewport:GetMetrics()
    return metrics and metrics.isSpanned and metrics or nil
end

local function Unsafe(frame)
    if not Plain(frame) or not frame or not frame.IsForbidden or not frame.IsProtected then return true end
    local forbidden, protected = frame:IsForbidden(), frame:IsProtected()
    return not Plain(forbidden) or not Plain(protected) or forbidden or protected
end

local function OrdinaryTree(frame)
    local todo = {frame}
    local index = 1
    while index <= #todo do
        local node = todo[index]
        if Unsafe(node) or not node.GetNumChildren or not node.GetChildren then return false end
        local count = node:GetNumChildren()
        if not Finite(count) or count < 0 or count > MAX_CHILDREN - #todo then return false end
        if count > 0 then
            local children = {node:GetChildren()}
            if #children ~= count then return false end
            for _, child in ipairs(children) do todo[#todo + 1] = child end
        end
        index = index + 1
    end
    return true
end

local function Identity(frame)
    if Unsafe(frame) or frame:GetParent() ~= UIParent or frame:GetObjectType() ~= "Frame"
        or not frame:IsMovable() or not frame.GetSourceLocation then return end
    local name = frame:GetName()
    if not ValidName(name) or _G[name] ~= frame or (UIPanelWindows and UIPanelWindows[name])
        or (Offhand.HUDCompatibility and Offhand.HUDCompatibility.ShouldPreservePopupPosition(frame, name, true))
        or (Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions[name])
        or (Offhand.db.savedMainPositions and Offhand.db.savedMainPositions[name]) then return end
    if frame.GetAttribute then
        local panel = frame:GetAttribute("UIPanelLayout-defined")
        if not Plain(panel) or panel then return end
    end

    local location = frame:GetSourceLocation()
    if not Plain(location) or type(location) ~= "string" or #location > 512 then return end
    location = location:gsub("\\", "/")
    local owner, file = location:match("^@?[Ii]nterface/[Aa]dd[Oo]ns/([%w_ %-]+)/([^:]+)")
    if not owner or not file or #file > 256 or not file:match("^[%w_ %./%-]+$") then return end
    file = file:lower()
    if ("/" .. file):match("/libs?/") or ("/" .. file):match("/libraries/") then return end
    local lower = owner:lower()
    if lower == "offhand" or lower:match("^blizzard_") then return end
    for known, entry in pairs(Offhand.AddonWindowCatalog or {}) do
        local prefix = type(entry) == "table" and entry.suitePrefix
        if lower == known:lower() or (type(prefix) == "string" and lower:sub(1, #prefix) == prefix) then
            local adapter = Offhand.CanvasAddonEscape
            if not adapter or not adapter:CanLearnPlacement(frame, name, known, file) then return end
            break
        end
    end
    if not Offhand.CanvasCompatibility.IsAddonLoaded(owner) then return end
    return name, owner, file
end

local function Anchor(frame)
    if frame:GetNumPoints() ~= 1 then return end
    local point, parent, relative, x, y = frame:GetPoint(1)
    if not Plain(parent) or parent ~= UIParent or not Plain(point) or not Plain(relative)
        or type(point) ~= "string" or type(relative) ~= "string" or not Finite(x) or not Finite(y) then return end
    return {point, parent, relative, x, y}
end

local function SameAnchor(a, b)
    return a and b and a[1] == b[1] and a[2] == b[2] and a[3] == b[3]
        and math.abs(a[4] - b[4]) < 0.01 and math.abs(a[5] - b[5]) < 0.01
end

local function SetAnchor(frame, target, rollback)
    local function Apply(anchor)
        frame:ClearAllPoints()
        frame:SetPoint(unpack(anchor))
    end
    local ok = pcall(Apply, target)
    if not ok then pcall(Apply, rollback) end
    return ok
end

local function Rect(frame)
    local x, y, width, height = regions:FrameRect(frame)
    if Finite(x) and Finite(y) and Finite(width) and Finite(height) and width > 0 and height > 0 then
        return x, y, width, height
    end
end

-- "MAINHAND" is the game rectangle. An older Offhand reads a "MAINHAND"
-- record as a missing workspace region and simply does not place the frame.
local function Destination(metrics, id)
    if id == "MAINHAND" then
        local left, bottom = metrics.gameLeft, metrics.gameBottom
        local right, top = metrics.gameRight, metrics.gameTop
        if Finite(left) and Finite(bottom) and Finite(right) and Finite(top) and right > left and top > bottom then
            return left, bottom, right - left, top - bottom, "MAINHAND"
        end
        return
    end
    if id and not regions:Get(metrics, id) then return end
    local bounds = regions:ForRegion(metrics, id)
    local left, bottom, width, height = bounds.workspaceLeft, bounds.workspaceBottom,
        bounds.workspaceWidth, bounds.workspaceHeight
    if Finite(left) and Finite(bottom) and Finite(width) and Finite(height) and width > 0 and height > 0 then
        return left, bottom, width, height, bounds.workspaceRegionID
    end
end

local function CatalogAllowsRecord(owner, file)
    local lower = type(owner) == "string" and owner:lower() or ""
    for known, entry in pairs(Offhand.AddonWindowCatalog or {}) do
        local knownLower = known:lower()
        local prefix = type(entry) == "table" and entry.suitePrefix
        if lower == knownLower or (type(prefix) == "string" and lower:sub(1, #prefix) == prefix) then
            if lower ~= knownLower or type(entry) ~= "table" then return false end
            for _, role in pairs(entry) do
                if type(role) == "table" and role.learnPlacementFile == file then
                    return true
                end
            end
            return false
        end
    end
    return true
end

local function ValidRecord(record)
    return type(record) == "table" and type(record.owner) == "string" and type(record.file) == "string"
        and (record.region == nil or type(record.region) == "string")
        and Finite(record.x) and record.x >= 0 and record.x <= 1
        and Finite(record.y) and record.y >= 0 and record.y <= 1
end

local function Move(frame, record, metrics, state)
    local oldX, oldY, width, height = Rect(frame)
    local left, bottom, availableWidth, availableHeight = Destination(metrics, record.region)
    if not width or not left or width > availableWidth or height > availableHeight then return false end
    local current = Anchor(frame)
    if not current or not OrdinaryTree(frame) then return false end
    local x = left + math.min(record.x * availableWidth, availableWidth - width)
    local y = bottom + math.max(record.y * availableHeight, height)
    local factor = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
    if not Finite(factor) or factor <= 0 then return false end
    local target = {"TOPLEFT", UIParent, "BOTTOMLEFT", x / factor, y / factor}
    if math.abs(x - oldX) < 0.01 and math.abs(y - oldY) < 0.01 then return true end
    local original = SameAnchor(current, state.applied) and state.original or current
    if not SetAnchor(frame, target, current) then return false end
    local applied = Anchor(frame)
    if not SameAnchor(applied, target) then return false end
    state.original, state.applied = original, applied
    return true
end

local function Release(state)
    if not state.applied or Unsafe(state.frame) then return end
    if state.frame:GetParent() ~= UIParent then return end
    local current = Anchor(state.frame)
    if SameAnchor(current, state.applied) and OrdinaryTree(state.frame) then
        SetAnchor(state.frame, state.original, current)
    end
end

-- The generic popup recovery already knows the frame and can cheaply yield to
-- a placement from this session. It does not read identities on its hot path.
function Windows:OwnsPosition(frame, name)
    local state = name and active[name]
    local records = Offhand.db and Offhand.db.enabled and Offhand.db.learnedAddonWindows
    return state ~= nil and state.frame == frame and state.placed
        and type(records) == "table" and records[name] == state.record
end

function Windows:Refresh()
    local records = Offhand.db and Offhand.db.learnedAddonWindows
    if not next(active) and (type(records) ~= "table" or not next(records)) then return end
    if not CanInspect() then return end
    local metrics = Metrics()
    for name, state in pairs(active) do
        if not metrics or type(records) ~= "table" or records[name] ~= state.record or _G[name] ~= state.frame then
            pcall(Release, state)
            active[name] = nil
        end
    end
    if not metrics or type(records) ~= "table" then return end
    local count = 0
    for name, record in pairs(records) do
        count = count + 1
        if count > MAX_WINDOWS then break end
        if ValidName(name) and ValidRecord(record) and not CatalogAllowsRecord(record.owner, record.file) then
            if active[name] then
                pcall(Release, active[name])
                active[name] = nil
            end
            records[name] = nil
        elseif ValidName(name) and ValidRecord(record) then
            pcall(function()
                local frame, state = _G[name], active[name]
                if Unsafe(frame) or not frame:IsVisible() then
                    if state then state.visible = false end
                    return
                end
                if state and state.visible then return end
                local actual, owner, file = Identity(frame)
                if actual ~= name or owner ~= record.owner or file ~= record.file then return end
                state = state or {frame = frame, record = record}
                state.visible = true
                active[name] = state
                state.placed = Move(frame, record, metrics, state)
            end)
        end
    end
end

function Windows:GetSelectionMetrics()
    if CanInspect() and not (GameMenuFrame and GameMenuFrame:IsShown()) then return Metrics() end
end

local function DescribeSelection(frame)
    if Unsafe(frame) or not frame:IsVisible() then return end
    local name, owner, file = Identity(frame)
    if not name or not Anchor(frame) or not OrdinaryTree(frame) then return end
    local x, y, width, height = Rect(frame)
    if not x then return end
    local alpha = frame:GetEffectiveAlpha()
    if not Finite(alpha) or alpha <= 0 then return end
    local strata, level = frame:GetFrameStrata(), frame:GetHighestFrameLevel(true)
    if not Plain(strata) or not selectableStrata[strata] or not Finite(level) or level < 0 or level >= 10000 then
        return
    end
    local records = Offhand.db and Offhand.db.learnedAddonWindows
    local remembered = type(records) == "table" and ValidRecord(records[name]) or false
    return {frame = frame, name = name, owner = owner, file = file, db = Offhand.db,
        remembered = remembered, x = x, y = y, width = width, height = height, strata = strata, level = level + 1}
end

function Windows:DescribeSelection(frame)
    local ok, selection = pcall(DescribeSelection, frame)
    if ok then return selection end
end

function Windows:FindSelections(saved)
    local ok, children = pcall(function()
        local count = UIParent:GetNumChildren()
        if Finite(count) and count > 0 and count <= 4096 then return {UIParent:GetChildren()} end
    end)
    local results = {}
    if not ok or not children then return results end
    for _, frame in ipairs(children) do
        if Plain(frame) and not saved[frame] then
            local selection = self:DescribeSelection(frame)
            if selection then
                results[#results + 1] = selection
                if #results >= MAX_WINDOWS then break end
            end
        end
    end
    return results
end

-- target "MAINHAND" keeps the frame on the game rectangle, moved only as far
-- as it takes to lie wholly inside; without a target it goes to a workspace.
local function Remember(selection, target)
    if not CanInspect() or selection.db ~= Offhand.db then return false end
    local metrics = Metrics()
    if not metrics or not selection.frame:IsVisible() then return false end
    local frame, name = selection.frame, selection.name
    local actual, owner, file = Identity(frame)
    if actual ~= name or owner ~= selection.owner or file ~= selection.file then return false end
    local records = Offhand.db.learnedAddonWindows
    if records ~= nil and type(records) ~= "table" then return false end
    records = records or {}
    if not records[name] then
        local count = 0
        for _ in pairs(records) do count = count + 1 end
        if count >= MAX_WINDOWS then return false end
    end

    local x, y, width, height = Rect(frame)
    if not x then return false end
    local left, bottom, availableWidth, availableHeight, id
    if target == "MAINHAND" then
        left, bottom, availableWidth, availableHeight, id = Destination(metrics, "MAINHAND")
        if not left then return false end
        x = math.max(left, math.min(x, left + availableWidth - width))
        y = math.max(bottom + height, math.min(y, bottom + availableHeight))
    else
        local destination = regions:Destination(metrics, x, y, width, height)
        left, bottom, availableWidth, availableHeight, id =
            Destination(metrics, destination ~= "MAINHAND" and destination or nil)
        if not left then return false end
        if x < left or x + width > left + availableWidth
            or y - height < bottom or y > bottom + availableHeight then
            x, y = left + (availableWidth - width) / 2, bottom + (availableHeight + height) / 2
        end
    end
    local record = {owner = owner, file = file, region = id,
        x = (x - left) / availableWidth, y = (y - bottom) / availableHeight}
    if not ValidRecord(record) then return false end
    local previous = active[name]
    local state = {frame = frame, record = record, visible = true, placed = true}
    if previous and previous.frame == frame then
        state.original, state.applied = previous.original, previous.applied
    end
    if not Move(frame, record, metrics, state) then return false end
    records[name], active[name] = record, state
    Offhand.db.learnedAddonWindows = records
    return true
end

function Windows:RememberSelection(selection)
    local ok, saved = pcall(Remember, selection)
    return ok and saved
end

function Windows:RememberOnMainhand(frame)
    local selection = self:DescribeSelection(frame)
    if not selection then return false end
    local ok, saved = pcall(Remember, selection, "MAINHAND")
    return ok and saved == true
end

-- The region of name's valid record ("WORKSPACE" for one without a region),
-- or nil without a valid record.
function Windows:GetRecordRegion(name)
    local records = Offhand.db and Offhand.db.learnedAddonWindows
    if not ValidName(name) or type(records) ~= "table" or not ValidRecord(records[name]) then return nil end
    return records[name].region or "WORKSPACE"
end

function Windows:ListNames()
    local records = Offhand.db and Offhand.db.learnedAddonWindows
    local names = {}
    for key, record in pairs(type(records) == "table" and records or {}) do
        if ValidName(key) and ValidRecord(record) and CatalogAllowsRecord(record.owner, record.file) then
            names[#names + 1] = key
        end
    end
    table.sort(names)
    return names
end

function Windows:ForgetName(name)
    local records = Offhand.db and Offhand.db.learnedAddonWindows
    if not ValidName(name) or type(records) ~= "table" or not records[name] then return false end
    records[name] = nil
    self:Refresh()
    return true
end

function Windows:Run(input)
    local L = Offhand.L
    local action, name = (input or ""):match("^(%S*)%s*(.-)%s*$")
    action = (action or ""):lower()
    if action == "list" then
        local names = self:ListNames()
        Offhand:Print(L["LEARN_WINDOW_LIST"], #names > 0 and table.concat(names, ", ") or NONE)
    elseif action == "forget" and ValidName(name) then
        if self:ForgetName(name) then
            Offhand:Print(L["LEARN_WINDOW_FORGOTTEN"], name)
        else
            Offhand:Print(L["LEARN_WINDOW_MISSING"], name)
        end
    elseif action == "" or action == "pick" then
        if Offhand.AddonWindowSelection then Offhand.AddonWindowSelection:Toggle() end
    elseif action == "next" or action == "add" or action == "done" then
        local picker = Offhand.AddonWindowSelection
        if picker then
            if action == "next" then picker:Cycle(1)
            elseif action == "add" then picker:AddFocused()
            else picker:Stop() end
        end
    else
        Offhand:Print(L["LEARN_WINDOW_HELP"])
    end
end
