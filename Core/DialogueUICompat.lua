-- Dialogue UI positions its presentation frames against UIParent. On a
-- spanned window that is the complete monitor canvas, not the bounded game
-- viewport. Translate only Dialogue UI's own UIParent-relative anchors to the
-- addon-owned Mainhand region while leaving its sizing, animations, camera,
-- interaction scripts, and saved variables under Dialogue UI ownership.
local _, Offhand = ...

local Compat = {}
Offhand.DialogueUICompat = Compat

local observed = setmetatable({}, { __mode = "k" })
local observedTooltips = setmetatable({}, { __mode = "k" })
local rewriting = setmetatable({}, { __mode = "k" })
local abs = math.abs

local function ReadNumber(frame, method)
    if not frame or type(frame[method]) ~= "function" then return nil end
    local ok, value = pcall(frame[method], frame)
    if ok then return tonumber(value) end
end

local function FormatNumber(value)
    return value and string.format("%.2f", value) or "n/a"
end

local function Round(value)
    return math.floor(value + 0.5)
end

local frameSizeMultipliers = {
    [0] = 0.9,
    [1] = 1.0,
    [2] = 1.1,
    [3] = 1.25,
    [4] = 1.4,
}

local function GetDialogueFrameSizeMultiplier()
    local db = _G.DialogueUI_DB
    local index = db and tonumber(db.FrameSize) or nil
    if db and db.MobileDeviceMode then index = 4 end
    return frameSizeMultipliers[index]
end

local function Near(a, b)
    return a and b and abs(a - b) < 0.001
end

local function IsLoaded()
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        local ok, loaded = pcall(C_AddOns.IsAddOnLoaded, "DialogueUI")
        if ok then return loaded == true end
    elseif IsAddOnLoaded then
        local ok, loaded = pcall(IsAddOnLoaded, "DialogueUI")
        if ok then return loaded == true end
    end
    return _G.DUIQuestFrame ~= nil
end

local function CanTouch(frame)
    if not frame or not frame.ClearAllPoints or not frame.SetPoint
        or not frame.GetNumPoints or not frame.GetPoint then return false end
    if frame.IsForbidden then
        local ok, forbidden = pcall(frame.IsForbidden, frame)
        if not ok or forbidden then return false end
    end
    if frame.IsProtected then
        local ok, protected = pcall(frame.IsProtected, frame)
        if not ok or protected then return false end
    end
    return true
end

function Compat:ShouldConstrain()
    if not Offhand.db or not Offhand.db.enabled or not Offhand.Viewport
        or not Offhand.Viewport.GetMetrics or not Offhand.Mainhand
        or not Offhand.Mainhand.CreateAnchor then return false end
    local ok, metrics = pcall(Offhand.Viewport.GetMetrics, Offhand.Viewport)
    return ok and metrics and metrics.isSpanned == true
end

function Compat:GetScaleRatio()
    if not Offhand.Viewport or not Offhand.Viewport.GetMetrics then return 1 end
    local ok, metrics = pcall(Offhand.Viewport.GetMetrics, Offhand.Viewport)
    if not ok or not metrics or metrics.isSpanned ~= true then return 1 end
    local canvasHeight = tonumber(metrics.physicalHeight)
    local gameHeight = tonumber(metrics.gamePixelHeight)
    if not canvasHeight or canvasHeight <= 0 or not gameHeight or gameHeight <= 0 then
        return 1
    end
    return gameHeight / canvasHeight
end

function Compat:ApplyScale(frame, state, constrain)
    if not state.scaleOwner or not frame.GetScale or not frame.SetScale then return false end
    local ok, current = pcall(frame.GetScale, frame)
    if not ok or not current or current <= 0 then return false end

    if constrain then
        -- Keep the first native scale as the stable baseline. Dialogue UI can
        -- reassert SetScale while rebuilding its frame-size setting. Treating
        -- that transient value as a new baseline compounds our viewport ratio
        -- and leaves Large permanently looking like a smaller preset.
        local desired = (state.nativeScale or current) * self:GetScaleRatio()
        if desired > 0 and not Near(current, desired) then
            rewriting[frame] = true
            local applied = pcall(frame.SetScale, frame, desired)
            rewriting[frame] = nil
            if not applied then return false end
        end
        state.appliedScale = desired
        return true
    end

    if state.appliedScale then
        if Near(current, state.appliedScale) and state.nativeScale
            and not Near(current, state.nativeScale) then
            rewriting[frame] = true
            pcall(frame.SetScale, frame, state.nativeScale)
            rewriting[frame] = nil
        end
        state.appliedScale = nil
    else
        state.nativeScale = current
    end
    return false
end

function Compat:NormalizeQuestFrameSize(frame)
    if not frame or frame ~= _G.DUIQuestFrame or not self:ShouldConstrain() then return false end
    local state = observed[frame]
    local multiplier = GetDialogueFrameSizeMultiplier()
    local rawWidth = tonumber(frame.frameWidth)
    local rawHeight = tonumber(frame.frameHeight)
    if not state or not state.baseFrameHeight or not state.baseFrameRatio or not multiplier
        or not rawWidth or not rawHeight or rawWidth <= 0 or rawHeight <= 0
        or not frame.SetSize then return false end

    -- Capture the correct reload-time viewport once, before Offhand's bounded
    -- WorldFrame can affect Dialogue UI. Live preset changes can then be
    -- rebuilt from Dialogue UI's own selected multiplier without consulting
    -- the now-constrained WorldFrame a second time.
    local height = Round(state.baseFrameHeight * multiplier)
    local width = Round(height * state.baseFrameRatio)
    local correction = height / rawHeight
    if Near(rawWidth, width) and Near(rawHeight, height) then
        state.normalizedCorrection = 1
        return false
    end
    local deltaWidth = width - rawWidth

    state.writingQuestHeight = true
    pcall(frame.SetSize, frame, width, height)
    state.writingQuestHeight = nil
    frame.frameWidth = width
    frame.frameHeight = height
    if tonumber(frame.halfFrameWidth) then
        frame.halfFrameWidth = Round(frame.halfFrameWidth + 0.5 * deltaWidth)
    end
    if tonumber(frame.quarterFrameWidth) then
        frame.quarterFrameWidth = Round(frame.quarterFrameWidth + 0.25 * deltaWidth)
    end
    frame.contentWidth = width
    if frame.ContentFrame and frame.ContentFrame.SetWidth then
        pcall(frame.ContentFrame.SetWidth, frame.ContentFrame, width)
    end
    if frame.ScrollFrame then
        local scrollHeight = ReadNumber(frame.ScrollFrame, "GetHeight")
        if scrollHeight then
            frame.scrollFrameBaseHeight = scrollHeight
            frame.scrollViewHeight = scrollHeight
        end
    end
    state.normalizedCorrection = correction
    return true
end

function Compat:FinishQuestLayout(frame)
    if not frame or frame ~= _G.DUIQuestFrame then return false end
    local state = observed[frame]
    if not state then return false end

    self:ApplyScale(frame, state, self:ShouldConstrain())

    -- The Unfold intro starts at half of Dialogue UI's declared frameHeight.
    -- A live Frame Size rebuild can retain that intermediate height even
    -- though UpdateFrameSize has already calculated the new preset. Complete
    -- the rebuild with Dialogue UI's own target value, without touching its
    -- width, content flow, animation choice, or saved setting.
    local before = ReadNumber(frame, "GetHeight")
    local target = tonumber(frame.frameHeight)
    if target and target > 0 and frame.GetHeight and frame.SetHeight then
        local current = ReadNumber(frame, "GetHeight")
        if current and not Near(current, target) then
            state.writingQuestHeight = true
            pcall(frame.SetHeight, frame, target)
            state.writingQuestHeight = nil
        end
    end
    state.lastFinish = {
        before = before,
        target = target,
        after = ReadNumber(frame, "GetHeight"),
        generation = self.questLayoutGeneration or 0,
    }
    self:RewriteAnchors(frame)
    return true
end

function Compat:RecordQuestGeometry(frame, kind, width, height)
    local state = observed[frame]
    if not state then return end
    state.geometryWrites = state.geometryWrites or {}
    local entry = string.format("%s:%sx%s%s", kind,
        FormatNumber(width), FormatNumber(height),
        state.writingQuestHeight and "*" or "")
    state.geometryWrites[#state.geometryWrites + 1] = entry
    while #state.geometryWrites > 8 do table.remove(state.geometryWrites, 1) end
end

function Compat:QueueQuestLayoutFinish(frame)
    self.questLayoutGeneration = (self.questLayoutGeneration or 0) + 1
    local generation = self.questLayoutGeneration
    local function finish()
        if generation ~= Compat.questLayoutGeneration then return end
        Compat:FinishQuestLayout(frame)
    end
    if C_Timer and C_Timer.After then
        -- The zero-delay pass follows Dialogue UI's deferred content reflow.
        -- The bounded second pass follows its 0.75 second Unfold animation.
        C_Timer.After(0, finish)
        C_Timer.After(0.8, finish)
    else
        finish()
    end
end

local function CapturePoints(frame)
    local points = {}
    local ok, count = pcall(frame.GetNumPoints, frame)
    if not ok then return points end
    for index = 1, count do
        local point = { pcall(frame.GetPoint, frame, index) }
        if point[1] then
            points[#points + 1] = {
                point = point[2], relativeTo = point[3], relativePoint = point[4],
                x = point[5] or 0, y = point[6] or 0,
            }
        end
    end
    return points
end

function Compat:RewriteAnchors(frame)
    if rewriting[frame] or not CanTouch(frame) then return false end
    local state = observed[frame]
    if not state then return false end
    local mainhand = Offhand.Mainhand and Offhand.Mainhand:CreateAnchor() or nil
    if not mainhand then return false end

    local constrain = self:ShouldConstrain()
    self:ApplyScale(frame, state, constrain)
    local points = CapturePoints(frame)
    local changed = false
    for _, point in ipairs(points) do
        local relativeTo = point.relativeTo
        if constrain and (relativeTo == nil or relativeTo == UIParent) then
            point.relativeTo = mainhand
            changed = true
        elseif not constrain and relativeTo == mainhand then
            point.relativeTo = UIParent
            changed = true
        end
    end
    if not changed then return false end

    rewriting[frame] = true
    local ok = pcall(function()
        frame:ClearAllPoints()
        for _, point in ipairs(points) do
            frame:SetPoint(point.point, point.relativeTo, point.relativePoint, point.x, point.y)
        end
    end)
    rewriting[frame] = nil
    return ok
end

function Compat:Observe(frame, scaleOwner)
    if not frame or not CanTouch(frame) then return false end
    local state = observed[frame]
    if state then
        if scaleOwner then state.scaleOwner = true end
        self:RewriteAnchors(frame)
        return true
    end
    state = { scaleOwner = scaleOwner == true }
    if scaleOwner and frame.GetScale then
        local ok, scale = pcall(frame.GetScale, frame)
        if ok and scale and scale > 0 then state.nativeScale = scale end
    end
    if frame == _G.DUIQuestFrame then
        local multiplier = GetDialogueFrameSizeMultiplier()
        local frameWidth = tonumber(frame.frameWidth)
        local frameHeight = tonumber(frame.frameHeight)
        if multiplier and frameWidth and frameHeight and frameHeight > 0 then
            state.baseFrameHeight = frameHeight / multiplier
            state.baseFrameRatio = frameWidth / frameHeight
        end
    end
    observed[frame] = state
    if hooksecurefunc then
        hooksecurefunc(frame, "SetPoint", function()
            Compat:RewriteAnchors(frame)
        end)
        if scaleOwner and frame.SetScale then
            hooksecurefunc(frame, "SetScale", function()
                Compat:RewriteAnchors(frame)
            end)
        end
        if frame == _G.DUIQuestFrame and type(frame.UpdateFrameSize) == "function" then
            if frame.SetHeight then
                hooksecurefunc(frame, "SetHeight", function(self, height)
                    Compat:RecordQuestGeometry(self, "H", ReadNumber(self, "GetWidth"), tonumber(height))
                end)
            end
            if frame.SetSize then
                hooksecurefunc(frame, "SetSize", function(self, width, height)
                    Compat:RecordQuestGeometry(self, "S", tonumber(width), tonumber(height))
                end)
            end
            hooksecurefunc(frame, "UpdateFrameSize", function(self)
                Compat:NormalizeQuestFrameSize(self)
                Compat:FinishQuestLayout(self)
                Compat:QueueQuestLayoutFinish(self)
            end)
        end
    end
    self:RewriteAnchors(frame)
    return true
end

local function IsDialogueTooltip(frame)
    return frame and type(frame.ProcessInfo) == "function"
        and type(frame.ProcessItemExternal) == "function"
        and type(frame.ToggleAlternateInfo) == "function"
        and type(frame.ReprocessInfo) == "function"
end

function Compat:QueueTooltip(frame)
    local bounds = Offhand.PopupBounds
    if bounds and bounds.Queue then bounds:Queue(frame) end
end

function Compat:ObserveTooltip(frame)
    if not IsDialogueTooltip(frame) or observedTooltips[frame] then return false end
    observedTooltips[frame] = true

    -- Dialogue UI's custom reward tooltip is an anonymous top-level Frame, so
    -- Offhand's normal named GameTooltip discovery cannot see it. Clamp only
    -- this distinctive private tooltip after Dialogue UI completes each
    -- anchor and layout transaction. Its content, comparison mode, styling,
    -- and owner remain entirely under Dialogue UI control.
    if frame.HookScript then
        frame:HookScript("OnShow", function(self) Compat:QueueTooltip(self) end)
    end
    if hooksecurefunc then
        if frame.SetPoint then
            hooksecurefunc(frame, "SetPoint", function(self)
                Compat:QueueTooltip(self)
            end)
        end
        if type(frame.Layout) == "function" then
            hooksecurefunc(frame, "Layout", function(self)
                Compat:QueueTooltip(self)
            end)
        end
    end
    self:QueueTooltip(frame)
    return true
end

function Compat:FindDialogueTooltip()
    if not UIParent or not UIParent.GetChildren then return nil end
    local children = { pcall(UIParent.GetChildren, UIParent) }
    if not table.remove(children, 1) then return nil end
    for _, child in ipairs(children) do
        if IsDialogueTooltip(child) then return child end
    end
end

local function ObserveChildren(frame)
    if not frame or not frame.GetChildren then return end
    local children = { pcall(frame.GetChildren, frame) }
    if not table.remove(children, 1) then return end
    for _, child in ipairs(children) do Compat:Observe(child) end
end

function Compat:Attach()
    if not IsLoaded() then return false end
    local quest = _G.DUIQuestFrame
    if quest then
        self:Observe(quest, true)
        -- Dialogue UI reparents its banner, alert, chat, friendship, and status
        -- frames directly under the quest root. Only their UIParent-relative
        -- points are translated; ordinary child-to-owner anchors are retained.
        ObserveChildren(quest)
    end
    self:Observe(_G.DUIBookFrame, true)
    self:Observe(_G.DUIDialogSettings, true)
    self:ObserveTooltip(self:FindDialogueTooltip())
    return quest ~= nil
end

function Compat:Refresh()
    self:Attach()
    for frame in pairs(observed) do self:RewriteAnchors(frame) end
end

function Compat:GetDiagnostics()
    local count = 0
    for _ in pairs(observed) do count = count + 1 end
    local tooltipCount = 0
    for _ in pairs(observedTooltips) do tooltipCount = tooltipCount + 1 end
    local quest = _G.DUIQuestFrame
    local state = quest and observed[quest] or nil
    local finish = state and state.lastFinish or nil
    local onUpdate = quest and quest.GetScript and quest:GetScript("OnUpdate") or nil
    local clips = quest and quest.GetClipsChildren and quest:GetClipsChildren() or nil
    local writes = state and state.geometryWrites and table.concat(state.geometryWrites, ",") or "none"
    return string.format("DialogueUI=%s | MainhandConfinement=%s | ObservedFrames=%d | Tooltips=%d | QuestScale=%s | QuestEffectiveScale=%s | QuestSize=%sx%s | Declared=%sx%s | Baseline=%s | Preset=%s | Normalize=%sx | FromHeight=%s | IntroT=%s | OnUpdate=%s | Clips=%s | Finish=%s>%s>%s@g%d | Writes=%s",
        IsLoaded() and "loaded" or "absent",
        self:ShouldConstrain() and "active" or "inactive", count, tooltipCount,
        FormatNumber(ReadNumber(quest, "GetScale")),
        FormatNumber(ReadNumber(quest, "GetEffectiveScale")),
        FormatNumber(ReadNumber(quest, "GetWidth")),
        FormatNumber(ReadNumber(quest, "GetHeight")),
        FormatNumber(quest and tonumber(quest.frameWidth)),
        FormatNumber(quest and tonumber(quest.frameHeight)),
        FormatNumber(state and state.baseFrameHeight),
        FormatNumber(GetDialogueFrameSizeMultiplier()),
        FormatNumber(state and state.normalizedCorrection),
        FormatNumber(quest and tonumber(quest.fromHeight)),
        FormatNumber(quest and tonumber(quest.t)),
        onUpdate and "active" or "none",
        clips == nil and "n/a" or (clips and "yes" or "no"),
        FormatNumber(finish and finish.before),
        FormatNumber(finish and finish.target),
        FormatNumber(finish and finish.after),
        finish and finish.generation or 0,
        writes)
end

local loader = CreateFrame and CreateFrame("Frame") or nil
if loader then
    loader:RegisterEvent("ADDON_LOADED")
    loader:RegisterEvent("PLAYER_ENTERING_WORLD")
    loader:RegisterEvent("DISPLAY_SIZE_CHANGED")
    loader:RegisterEvent("UI_SCALE_CHANGED")
    loader:SetScript("OnEvent", function(_, event, addonName)
        if event ~= "ADDON_LOADED" or addonName == "DialogueUI" or addonName == "Offhand" then
            Compat:Refresh()
        end
    end)
end

Compat:Attach()
