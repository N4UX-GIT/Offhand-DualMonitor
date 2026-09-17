-- Native speech bubbles can live outside UIParent's scale hierarchy.
-- Scale the bubble itself; never alter WorldFrame, bubble anchors or font sizes.
local _, Offhand = ...
local Bubbles = {}
Offhand.modules.ChatBubbles = Bubbles
local tracked = setmetatable({}, { __mode = "k" })

local function Positive(value)
    return type(value) == "number" and value > 0 and value < math.huge
end

local function Accessible(bubble)
    return bubble and bubble.IsForbidden and not bubble:IsForbidden()
        and bubble.IsProtected and not bubble:IsProtected()
end

function Bubbles:ApplyLayout()
    if not Offhand.db then return end
    if not Offhand.db.enabled then
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
        return
    end
    if not C_ChatBubbles or not C_ChatBubbles.GetAllChatBubbles then return end
    local target = UIParent:GetEffectiveScale()
    if not Positive(target) then return end
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

function Bubbles:Initialize()
    if self.ticker or not C_Timer or not C_Timer.NewTicker
        or not C_ChatBubbles or not C_ChatBubbles.GetAllChatBubbles then return end
    -- There is no bubble-created event. Only enumerate the bubble API, not every
    -- UI frame, and write scale only when it changes. No SetScale hooks/feedback.
    self.ticker = C_Timer.NewTicker(0.1, function() self:ApplyLayout() end)
end
