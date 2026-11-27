-- Seam scan: a slow background pass that records third-party addon frames
-- that are visible but not wholly inside the game display, who owns them and
-- whether something already handles them. It never moves, hides, re-parents
-- or hooks a frame; only KeepOnMainhand, on the player's click, asks the
-- learned windows service to place one.
local _, Offhand = ...
local Scan = {}
Offhand.SeamScan = Scan

local MAX_ENTRIES, MAX_CHILDREN, MIN_SIZE, LIST_LINES = 200, 4096, 24, 20
local regions = Offhand.WorkspaceRegions
local CLASSES = {seam = 1, away = 2}
local STATES = {learnable = 1, manual = 2, learned = 3, bridged = 4, owned = 5}

-- Session-only data, never saved: the last frame seen for a key, the keys
-- seen this session and the pass counters.
local frames = setmetatable({}, {__mode = "v"})
local session = {seen = {}, passes = 0, faults = 0, children = 0, overflow = false}

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

local function Now()
    local now = type(time) == "function" and time() or 0
    return Finite(now) and now or 0
end

local function InCombat()
    return InCombatLockdown and InCombatLockdown() and true or false
end

-- The addon folder, lower-case file and line ("0" when unknown) of a frame's
-- source location, by the learned windows' rule but keeping library files.
local function Source(frame)
    if not frame.GetSourceLocation then return end
    local location = frame:GetSourceLocation()
    if not Plain(location) or type(location) ~= "string" or #location > 512 then return end
    location = location:gsub("\\", "/")
    local owner, file, line = location:match("^@?[Ii]nterface/[Aa]dd[Oo]ns/([%w_ %-]+)/([^:]+):?(%d*)")
    if not owner or not file or #file > 256 or not file:match("^[%w_ %./%-]+$") then return end
    local lower = owner:lower()
    if lower == "offhand" or lower:match("^blizzard_") then return end
    return owner, file:lower(), line ~= "" and line or "0"
end

local function GameRect(metrics)
    local left, bottom, right, top = metrics.gameLeft, metrics.gameBottom, metrics.gameRight, metrics.gameTop
    if Finite(left) and Finite(bottom) and Finite(right) and Finite(top) and right > left and top > bottom then
        return {left = left, bottom = bottom, right = right, top = top, width = right - left}
    end
end

local function AnchorKind(frame)
    local ok, kind = pcall(function()
        local count = frame:GetNumPoints()
        if not Finite(count) or count < 0 then return "unknown" end
        if count == 0 then return "none" end
        if count > 1 then return "multi" end
        local _, relative = frame:GetPoint(1)
        if not Plain(relative) then return "unknown" end
        if relative == nil or relative == UIParent then return "screen" end
        return "frame"
    end)
    return ok and kind or "unknown"
end

local function VisibleNow(frame)
    if frame == nil then return false end
    local ok, visible = pcall(frame.IsVisible, frame)
    return ok and Plain(visible) and visible == true
end

-- A window the player dragged counts as owned only when it sits wholly on the
-- other display; nobody parks a window across the seam on purpose, so there it
-- is offered like any other.
local function Classify(frame, name, anchor, class)
    local learned, bridges, hud, db = Offhand.LearnedAddonWindows, Offhand.Bridges, Offhand.HUDCompatibility, Offhand.db
    if name and learned and learned:GetRecordRegion(name) then return "learned" end
    if name and bridges and bridges:GetPlacedFrameOwner(name) then return "bridged" end
    if hud and (hud.IsExternallyOwnedHUDFrame(frame, name) or hud.ShouldPreservePopupPosition(frame, name, class == "seam")) then
        return "owned"
    end
    if name and ((type(db.savedWorkspacePositions) == "table" and db.savedWorkspacePositions[name])
        or (type(db.savedMainPositions) == "table" and db.savedMainPositions[name])) then return "owned" end
    if learned and learned:DescribeSelection(frame) then return "learnable" end
    local protected = frame:IsProtected()
    if not Plain(protected) or protected then return "manual", "protected" end
    if not name then return "manual", "unnamed" end
    if anchor ~= "screen" then return "manual", "anchor" end
    return "manual", "fixed"
end

local function Optional(value)
    return value == nil or type(value) == "string"
end

local function ValidEntry(key, entry)
    return type(key) == "string" and #key <= 512 and type(entry) == "table"
        and type(entry.owner) == "string" and type(entry.file) == "string"
        and CLASSES[entry.class] ~= nil and STATES[entry.state] ~= nil and type(entry.anchor) == "string"
        and Optional(entry.name) and Optional(entry.reason) and Optional(entry.bridge)
        and Finite(entry.sessions) and entry.sessions >= 1 and entry.sessions == math.floor(entry.sessions)
        and Finite(entry.first) and Finite(entry.last)
end

-- The saved log; a non-table one is replaced and malformed entries are
-- dropped the first time a session reads a profile's log.
local function Log()
    local db = Offhand.db
    local log = db.seamScanLog
    if type(log) ~= "table" then
        log = {}
        db.seamScanLog = log
    end
    if session.checked ~= log then
        session.checked = log
        for key, entry in pairs(log) do
            if not ValidEntry(key, entry) then log[key] = nil end
        end
    end
    return log
end

-- A new key in a full log replaces the entry with the smallest last that was
-- not seen this session; when every entry was seen, it is not recorded.
local function MakeRoom(log)
    local count, oldest = 0, nil
    for key, entry in pairs(log) do
        count = count + 1
        if not session.seen[key] and (oldest == nil or entry.last < log[oldest].last) then oldest = key end
    end
    if count < MAX_ENTRIES then return true end
    if oldest == nil then return false end
    log[oldest], frames[oldest] = nil, nil
    return true
end

local function Record(key, fields, frame, now)
    local log = Log()
    local entry, created = log[key], false
    if not entry then
        if not MakeRoom(log) then return end
        entry, created = {first = now, sessions = 0}, true
        log[key] = entry
    end
    if not session.seen[key] then
        session.seen[key] = true
        entry.sessions = (tonumber(entry.sessions) or 0) + 1
    end
    for field, value in pairs(fields) do entry[field] = value end
    entry.reason, entry.bridge = fields.reason, fields.bridge
    entry.name = fields.name
    entry.last = now
    frames[key] = frame
    return entry, created
end

-- Records one UIParent child when it is a visible third-party addon frame
-- that is not wholly inside the game rectangle. Cheapest tests first.
local function Observe(frame, metrics, game, now)
    if not Plain(frame) or type(frame) ~= "table" or frame == WorldFrame or regions:IsCanvas(frame)
        or not frame.IsForbidden then return end
    local forbidden = frame:IsForbidden()
    if not Plain(forbidden) or forbidden then return end
    local shown, visible = frame:IsShown(), frame:IsVisible()
    if not Plain(shown) or not Plain(visible) or not shown or not visible then return end
    local alpha = frame:GetEffectiveAlpha()
    if not Finite(alpha) or alpha <= 0 then return end
    local left, top, width, height = regions:FrameRect(frame)
    if not (Finite(left) and Finite(top) and Finite(width) and Finite(height)) then return end
    if width < MIN_SIZE or height < MIN_SIZE or width > game.width + 2 then return end
    local right, bottom = left + width, top - height
    if left >= game.left - 1 and right <= game.right + 1
        and bottom >= game.bottom - 1 and top <= game.top + 1 then return end
    local owner, file, line = Source(frame)
    local compatibility = Offhand.CanvasCompatibility
    if not owner or not compatibility or not compatibility.IsAddonLoaded(owner) then return end

    local name = frame.GetName and frame:GetName()
    if not ValidName(name) or _G[name] ~= frame then name = nil end
    local overlapX = math.min(right, game.right) - math.max(left, game.left)
    local overlapY = math.min(top, game.top) - math.max(bottom, game.bottom)
    local anchor = AnchorKind(frame)
    local class = (overlapX > 1 and overlapY > 1) and "seam" or "away"
    local state, reason = Classify(frame, name, anchor, class)
    local bridges = Offhand.Bridges
    return Record(name or (owner .. "/" .. file .. ":" .. line), {
        owner = owner, file = file, name = name, anchor = anchor, state = state, reason = reason,
        class = class,
        bridge = bridges and bridges:GetAddonBridge(owner) or nil,
    }, frame, now)
end

function Scan:CanScan()
    local db = Offhand.db
    if not Offhand.isForever or type(db) ~= "table" or not db.enabled or db.seamScan == false then return false end
    local metrics = Offhand.Viewport and Offhand.Viewport:GetMetrics()
    if not metrics or not metrics.isSpanned then return false end
    if InCombat() or Offhand._displayGeometryTransitionActive then return false end
    if EditModeManagerFrame and EditModeManagerFrame:IsShown() then return false end
    if Offhand.Bridges and Offhand.Bridges:IsEditModeActive() then return false end
    if not (UIParent and UIParent.GetSourceLocation) then return false end
    return true, metrics
end

local function Summarize(entries)
    local summary = {seen = 0, seam = 0, away = 0, bridged = 0, owned = 0, learned = 0,
        learnable = 0, manual = 0, gaps = 0}
    for _, entry in ipairs(entries) do
        summary.seen = summary.seen + 1
        summary[entry.class] = summary[entry.class] + 1
        summary[entry.state] = summary[entry.state] + 1
        if entry.bridge and (entry.state == "learnable" or entry.state == "manual") then
            summary.gaps = summary.gaps + 1
        end
    end
    return summary
end

function Scan:Pass()
    local can, metrics = self:CanScan()
    if not can then return nil end
    session.passes = session.passes + 1
    local game = GameRect(metrics)
    if not game then return 0 end
    local okCount, count = pcall(UIParent.GetNumChildren, UIParent)
    if not okCount or not Finite(count) or count > MAX_CHILDREN then
        session.overflow = true
        return 0
    end
    local okChildren, children = pcall(function() return {UIParent:GetChildren()} end)
    if not okChildren or type(children) ~= "table" then
        session.overflow = true
        return 0
    end
    session.overflow, session.children = false, #children
    Log()
    local now, touched, fresh = Now(), 0, 0
    for _, child in ipairs(children) do
        local ok, entry, created = pcall(Observe, child, metrics, game, now)
        if not ok then
            session.faults = session.faults + 1
        elseif entry then
            touched = touched + 1
            if created and (entry.state == "learnable" or entry.state == "manual") then fresh = fresh + 1 end
        end
    end
    if fresh > 0 and not session.noticed and not InCombat() then
        session.noticed = true
        local summary = Summarize(self:GetEntries())
        Offhand:Print(Offhand.L["SEAM_SCAN_NOTICE"], summary.learnable + summary.manual)
    end
    return touched
end

-- Copies of the log entries with key and visible, sorted for display. The
-- state is refreshed where it can change without the frame being seen again.
function Scan:GetEntries()
    local db = Offhand.db
    local log = type(db) == "table" and type(db.seamScanLog) == "table" and db.seamScanLog or {}
    local learned = Offhand.LearnedAddonWindows
    local entries = {}
    for key, stored in pairs(log) do
        if ValidEntry(key, stored) then
            local entry = {key = key}
            for field, value in pairs(stored) do entry[field] = value end
            local frame = frames[key]
            entry.visible = VisibleNow(frame)
            if entry.name and learned and learned:GetRecordRegion(entry.name) then
                entry.state, entry.reason = "learned", nil
            elseif entry.state == "learned" then
                if entry.visible and learned and learned:DescribeSelection(frame) then
                    entry.state, entry.reason = "learnable", nil
                else
                    entry.state, entry.reason = "manual", "closed"
                end
            end
            entries[#entries + 1] = entry
        end
    end
    table.sort(entries, function(a, b)
        if a.class ~= b.class then return CLASSES[a.class] < CLASSES[b.class] end
        if a.state ~= b.state then return STATES[a.state] < STATES[b.state] end
        if a.owner ~= b.owner then return a.owner < b.owner end
        return a.key < b.key
    end)
    return entries
end

function Scan:GetSummary()
    return Summarize(self:GetEntries())
end

function Scan:GetDiagnostics()
    local db = Offhand.db
    local state = "on"
    if type(db) == "table" and db.seamScan == false then
        state = "off"
    elseif not self:CanScan() then
        state = "idle"
    end
    local summary = self:GetSummary()
    return string.format("state=%s | passes=%d | children=%s | faults=%d | seen=%d | seam=%d | away=%d"
        .. " | bridged=%d | owned=%d | learned=%d | learnable=%d | manual=%d | bridgeGaps=%d",
        state, session.passes, session.overflow and "overflow" or tostring(session.children), session.faults,
        summary.seen, summary.seam, summary.away, summary.bridged, summary.owned, summary.learned,
        summary.learnable, summary.manual, summary.gaps)
end

-- The window's name, or file:line for an unnamed frame.
function Scan:Label(entry)
    if entry.name then return entry.name end
    local key = entry.key or ""
    return key:sub(#entry.owner + 2)
end

function Scan:Describe(entry)
    local state = entry.reason and (entry.state .. ":" .. entry.reason) or entry.state
    local bridge = entry.bridge and (" | bridge=" .. entry.bridge) or ""
    return string.format("%s: %s | %s | anchor=%s | %s%s | sessions=%d", entry.owner, self:Label(entry),
        entry.class, entry.anchor, state, bridge, entry.sessions)
end

function Scan:KeepOnMainhand(key)
    local frame = type(key) == "string" and frames[key] or nil
    local learned = Offhand.LearnedAddonWindows
    if not VisibleNow(frame) or not learned or not learned:RememberOnMainhand(frame) then return false end
    local log = Offhand.db and Offhand.db.seamScanLog
    local entry = type(log) == "table" and log[key]
    if type(entry) == "table" then entry.state, entry.reason = "learned", nil end
    return true
end

function Scan:Forget(key)
    local log = Offhand.db and Offhand.db.seamScanLog
    local entry = type(log) == "table" and type(key) == "string" and log[key]
    local learned = Offhand.LearnedAddonWindows
    if type(entry) ~= "table" or type(entry.name) ~= "string" or not learned
        or not learned:GetRecordRegion(entry.name) then return false end
    return learned:ForgetName(entry.name)
end

function Scan:Clear()
    if type(Offhand.db) == "table" then Offhand.db.seamScanLog = {} end
    for key in pairs(frames) do frames[key] = nil end
    session.seen = {}
end

function Scan:SetEnabled(flag)
    if type(Offhand.db) ~= "table" then return end
    if flag then
        Offhand.db.seamScan = nil
    else
        Offhand.db.seamScan = false
    end
end

local function List()
    local L = Offhand.L
    local entries = Scan:GetEntries()
    if #entries == 0 then
        Offhand:Print(L["SEAM_SCAN_EMPTY"])
        return
    end
    local summary = Summarize(entries)
    Offhand:Print(L["SEAM_SCAN_SUMMARY"], summary.seen, summary.learnable + summary.manual,
        summary.bridged + summary.owned + summary.learned)
    for index = 1, math.min(LIST_LINES, #entries) do Offhand:Print("%s", Scan:Describe(entries[index])) end
    if #entries > LIST_LINES then Offhand:Print(L["SEAM_SCAN_MORE"], #entries - LIST_LINES) end
end

function Scan:Run(input)
    local L = Offhand.L
    local action = ((input or ""):match("^%s*(%S*)") or ""):lower()
    if action == "" or action == "list" then
        List()
    elseif action == "now" then
        if self:Pass() == nil then Offhand:Print(L["SEAM_SCAN_UNAVAILABLE"]) end
        List()
    elseif action == "review" then
        if Offhand.SeamScanReview then Offhand.SeamScanReview:Toggle() end
    elseif action == "clear" then
        self:Clear()
        Offhand:Print(L["SEAM_SCAN_CLEARED"])
    elseif action == "on" or action == "off" then
        self:SetEnabled(action == "on")
        Offhand:Print(L[action == "on" and "SEAM_SCAN_ON" or "SEAM_SCAN_OFF"])
    else
        Offhand:Print(L["SEAM_SCAN_HELP"])
    end
end

local function Tick()
    local probe = Offhand.PerformanceMaintenanceProbe
    if probe and type(probe.Run) == "function" then
        probe:Run("seam-scan", Scan.Pass, Scan)
        return
    end
    Scan:Pass()
end

-- One 5 second ticker from PLAYER_LOGIN, on Forever only (CanScan is false
-- on every other client).
local events = CreateFrame and CreateFrame("Frame")
if events then
    events:RegisterEvent("PLAYER_LOGIN")
    events:SetScript("OnEvent", function(self)
        self:UnregisterEvent("PLAYER_LOGIN")
        if Scan.ticker or not Offhand.isForever or not (C_Timer and C_Timer.NewTicker) then return end
        Scan.ticker = C_Timer.NewTicker(5, Tick)
    end)
end
