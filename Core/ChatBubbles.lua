-- Native speech bubbles can live outside UIParent's scale hierarchy. Accessible
-- bubbles can be scaled directly. Retail instance bubbles are forbidden, so use
-- their shared FontObject while spanned and restore it outside that narrow case.
local _, Offhand = ...
local Bubbles = {}
Offhand.modules.ChatBubbles = Bubbles
local tracked = setmetatable({}, { __mode = "k" })
local instanceFontState

local function Positive(value)
    return type(value) == "number" and value > 0 and value < math.huge
end

local function Accessible(bubble)
    return bubble and bubble.IsForbidden and not bubble:IsForbidden()
        and bubble.IsProtected and not bubble:IsProtected()
end

local function RestoreTrackedBubbles()
    for bubble, state in pairs(tracked) do
        pcall(function()
            if not Accessible(bubble) then return end
            -- Do not undo a subsequent scale change made by another addon.
            if math.abs(bubble:GetScale() - state.applied) < 0.00001 then
                bubble:SetScale(state.original)
            end
            tracked[bubble] = nil
        end)
    end
end

local function FontMatches(file, height, flags, expectedFile, expectedHeight, expectedFlags)
    return file == expectedFile and flags == expectedFlags
        and Positive(height) and Positive(expectedHeight)
        and math.abs(height - expectedHeight) < 0.00001
end

local function RestoreInstanceFont()
    if not instanceFontState then return end
    pcall(function()
        if not ChatBubbleFont or not ChatBubbleFont.GetFont or not ChatBubbleFont.SetFont then return end
        local file, height, flags = ChatBubbleFont:GetFont()
        if FontMatches(file, height, flags, instanceFontState.appliedFile,
            instanceFontState.appliedHeight, instanceFontState.appliedFlags) then
            ChatBubbleFont:SetFont(instanceFontState.originalFile,
                instanceFontState.originalHeight, instanceFontState.originalFlags)
        end
    end)
    instanceFontState = nil
end

local function IsRetailSpannedInstance()
    if not Offhand.isRetail or type(IsInInstance) ~= "function" then return false end
    local inInstance = IsInInstance()
    if not inInstance then return false end
    if not Offhand.Viewport or type(Offhand.Viewport.GetMetrics) ~= "function" then return false end
    local ok, metrics = pcall(Offhand.Viewport.GetMetrics, Offhand.Viewport)
    return ok and metrics and metrics.isSpanned == true or false
end

local function ApplyInstanceFont(target)
    if not ChatBubbleFont or not ChatBubbleFont.GetFont or not ChatBubbleFont.SetFont then return false end
    local ok, file, height, flags = pcall(ChatBubbleFont.GetFont, ChatBubbleFont)
    if not ok or not file or not Positive(height) then return false end
    local state = instanceFontState
    if not state or not FontMatches(file, height, flags,
        state.appliedFile, state.appliedHeight, state.appliedFlags) then
        state = {
            originalFile = file,
            originalHeight = height,
            originalFlags = flags,
        }
    end
    local desired = state.originalHeight * target
    if not Positive(desired) then return false end
    if not FontMatches(file, height, flags, state.originalFile, desired, state.originalFlags) then
        local applied = ChatBubbleFont:SetFont(state.originalFile, desired, state.originalFlags)
        if applied == false then return false end
    end
    state.appliedFile = state.originalFile
    state.appliedHeight = desired
    state.appliedFlags = state.originalFlags
    instanceFontState = state
    return true
end

function Bubbles:ApplyLayout()
    if not Offhand.db then return end
    if not Offhand.db.enabled then
        RestoreTrackedBubbles()
        RestoreInstanceFont()
        return
    end
    local target = UIParent:GetEffectiveScale()
    if not Positive(target) then return end
    if IsRetailSpannedInstance() then
        RestoreTrackedBubbles()
        ApplyInstanceFont(target)
        return
    end
    RestoreInstanceFont()
    if not C_ChatBubbles or not C_ChatBubbles.GetAllChatBubbles then return end
    -- The API excludes forbidden bubbles by default; retain a per-frame guard.
    local ok, bubbles = pcall(C_ChatBubbles.GetAllChatBubbles)
    if not ok or type(bubbles) ~= "table" then return end
    for _, bubble in pairs(bubbles) do
        pcall(function()
            if not Accessible(bubble) or not bubble:IsShown() then return end
            local current, effective = bubble:GetScale(), bubble:GetEffectiveScale()
            if not Positive(current) or not Positive(effective) then return end
            local state = tracked[bubble]
            -- Retain the native/custom relative scale, including pool resets.
            if not state or math.abs(current - state.applied) > 0.00001 then
                state = { original = current }
            end
            -- Derive inherited scale rather than assuming WorldFrame is the parent.
            -- A bubble already inheriting UIParent therefore needs no extra reduction.
            local desired = state.original * target / (effective / current)
            if not Positive(desired) then return end
            if math.abs(current - desired) > 0.00001 then bubble:SetScale(desired) end
            state.applied = desired
            tracked[bubble] = state
        end)
    end
end

function Bubbles:GetDiagnostics()
    local result = {
        supported = C_ChatBubbles and type(C_ChatBubbles.GetAllChatBubbles) == "function",
        visible = 0,
        includingForbidden = 0,
        forbidden = 0,
        protected = 0,
        fontManaged = instanceFontState ~= nil,
        fontOriginal = instanceFontState and instanceFontState.originalHeight or nil,
        fontApplied = instanceFontState and instanceFontState.appliedHeight or nil,
        fontCurrent = nil,
    }
    if ChatBubbleFont and ChatBubbleFont.GetFont then
        local fontOK, _, fontHeight = pcall(ChatBubbleFont.GetFont, ChatBubbleFont)
        if fontOK and Positive(fontHeight) then result.fontCurrent = fontHeight end
    end
    if not result.supported then return result end
    local ok, visible = pcall(C_ChatBubbles.GetAllChatBubbles, false)
    if ok and type(visible) == "table" then result.visible = #visible end
    local allOK, all = pcall(C_ChatBubbles.GetAllChatBubbles, true)
    if not allOK or type(all) ~= "table" then return result end
    result.includingForbidden = #all
    for _, bubble in pairs(all) do
        local forbiddenOK, forbidden = pcall(bubble.IsForbidden, bubble)
        if not forbiddenOK or forbidden then
            result.forbidden = result.forbidden + 1
        else
            local protectedOK, protected = pcall(bubble.IsProtected, bubble)
            if not protectedOK or protected then result.protected = result.protected + 1 end
        end
    end
    return result
end

function Bubbles:Initialize()
    if self.ticker or not C_Timer or not C_Timer.NewTicker
        or not C_ChatBubbles or not C_ChatBubbles.GetAllChatBubbles then return end
    -- There is no bubble-created event. Only enumerate the bubble API, not every
    -- UI frame, and write scale only when it changes. No SetScale hooks/feedback.
    self.ticker = C_Timer.NewTicker(0.1, function() self:ApplyLayout() end)
end
