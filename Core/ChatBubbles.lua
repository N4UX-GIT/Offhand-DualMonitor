-- Speech bubbles normally live outside UIParent's scale hierarchy. Most clients
-- can compensate by scaling the accessible native root. Forever's mixed-height
-- spans are different: scaling that root also moves its engine-owned world
-- attachment. On that one topology Offhand leaves every native point, size,
-- texture, scale and FontString untouched, and draws a UIParent-owned classic
-- bubble over the native frame that Blizzard continues to position.
local _, Offhand = ...
local Bubbles = {}
Offhand.modules.ChatBubbles = Bubbles

local tracked = setmetatable({}, { __mode = "k" })
local instanceFontState

local replacementByOuter = setmetatable({}, { __mode = "k" })
local pendingRestore = setmetatable({}, { __mode = "k" })
local hookedOuter = setmetatable({}, { __mode = "k" })
local replacementPool = {}
local replacementCount = 0
local replacementMode = "native"
local replacementConflict = "none"
local immediateSweepScheduled = false

local CHAT_BUBBLE_EVENTS = {
    "CHAT_MSG_SAY",
    "CHAT_MSG_YELL",
    "CHAT_MSG_EMOTE",
    "CHAT_MSG_MONSTER_SAY",
    "CHAT_MSG_MONSTER_YELL",
    "CHAT_MSG_MONSTER_EMOTE",
    "CHAT_MSG_MONSTER_PARTY",
    "CHAT_MSG_MONSTER_WHISPER",
    "CHAT_MSG_PARTY",
    "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_RAID",
    "CHAT_MSG_RAID_LEADER",
    "CHAT_MSG_INSTANCE_CHAT",
    "CHAT_MSG_INSTANCE_CHAT_LEADER",
}

local BASE_FONT_SIZE = 13
local MAX_TEXT_WIDTH = 220
local MIN_BUBBLE_WIDTH = 48
local MIN_BUBBLE_HEIGHT = 34
local HORIZONTAL_PADDING = 16
local VERTICAL_PADDING = 10
local EPSILON = 0.00001

-- Use the engine's clamp rectangle rather than fighting world-space anchors.
-- Forbidden/protected native bubbles remain entirely under client ownership.
local clampStates = setmetatable({}, { __mode = "k" })
local function SameClamp(a, b)
    if not a or not b then return false end
    for i = 1, 4 do if math.abs(a[i] - b[i]) > 0.01 then return false end end
    return true
end
local function RestoreClamp(frame)
    local state = clampStates[frame]
    if not state or (InCombatLockdown and InCombatLockdown()) then return end
    if (frame.IsForbidden and frame:IsForbidden()) or (frame.IsProtected and frame:IsProtected()) then return end
    clampStates[frame] = nil
    if SameClamp({frame:GetClampRectInsets()}, state.applied) then
        frame:SetClampRectInsets(unpack(state.original))
        if state.enabled and frame:IsClampedToScreen() then frame:SetClampedToScreen(false) end
    end
end
local function ConstrainBubble(frame)
    if not frame or not frame.GetClampRectInsets or not frame.SetClampRectInsets
        or not frame.IsClampedToScreen or not frame.SetClampedToScreen then return end
    if (InCombatLockdown and InCombatLockdown())
        or (frame.IsForbidden and frame:IsForbidden()) or (frame.IsProtected and frame:IsProtected()) then return end
    local metrics = Offhand.Viewport and Offhand.Viewport:GetMetrics()
    if not Offhand.db or not Offhand.db.enabled or not metrics or not metrics.isSpanned
        or Offhand.db.speechBubbleCompensation == false then RestoreClamp(frame); return end
    for _, key in ipairs({"gameLeft", "gameRight", "gameBottom", "gameTop"}) do
        if type(metrics[key]) ~= "number" then RestoreClamp(frame); return end
    end
    local uiScale, scale = UIParent:GetEffectiveScale(), frame:GetEffectiveScale()
    if not scale or scale <= 0 or not uiScale or uiScale <= 0 then return end
    local current, state = {frame:GetClampRectInsets()}, clampStates[frame]
    if state and not SameClamp(current, state.applied) then
        clampStates[frame] = nil -- Another owner has supplied a newer policy.
        return
    end
    state = state or {original=current, enabled=not frame:IsClampedToScreen()}
    local factor = uiScale / scale
    local desired = {math.min(state.original[1], -metrics.gameLeft * factor),
        math.max(state.original[2], (UIParent:GetWidth() - metrics.gameRight) * factor),
        math.max(state.original[3], (UIParent:GetHeight() - metrics.gameTop) * factor),
        math.min(state.original[4], -metrics.gameBottom * factor)}
    if not SameClamp(current, desired) then frame:SetClampRectInsets(unpack(desired)) end
    if not frame:IsClampedToScreen() then frame:SetClampedToScreen(true) end
    state.applied = desired
    clampStates[frame] = state
end

local function Positive(value)
    return type(value) == "number" and value > 0 and value < math.huge
end

local function Accessible(bubble)
    if not bubble then return false end
    local ok, forbidden, protected = pcall(function()
        return bubble:IsForbidden(), bubble:IsProtected()
    end)
    return ok and not forbidden and not protected
end

local function IsSecret(value)
    if type(issecretvalue) ~= "function" then return false end
    local ok, secret = pcall(issecretvalue, value)
    return ok and secret == true
end

local function SafeValue(object, methodName)
    local method, value
    local ok = pcall(function()
        method = object and object[methodName]
        if type(method) == "function" then value = method(object) end
    end)
    return ok and value or nil
end

local function RestoreTrackedBubbles()
    for bubble, state in pairs(tracked) do
        pcall(function()
            if not Accessible(bubble) then return end
            -- Do not undo a subsequent scale change made by another addon.
            if math.abs(bubble:GetScale() - state.applied) < EPSILON then
                bubble:SetScale(state.original)
            end
            tracked[bubble] = nil
        end)
    end
end

local function FontMatches(file, height, flags, expectedFile, expectedHeight, expectedFlags)
    return file == expectedFile and flags == expectedFlags
        and Positive(height) and Positive(expectedHeight)
        and math.abs(height - expectedHeight) < EPSILON
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

local function UsesForeverNativeWorldTextScale()
    if not Offhand.isForever or not Offhand.Viewport
        or type(Offhand.Viewport.GetWorldTextScaleControl) ~= "function" then
        return false
    end
    local ok, name = pcall(Offhand.Viewport.GetWorldTextScaleControl, Offhand.Viewport)
    return ok and name == "WorldTextScale_v2"
end

local function RestoreForeverNativeBubbleFont()
    RestoreInstanceFont()
    if not ChatBubbleFont or not ChatBubbleFont.GetFont
        or not ChatBubbleFont.SetFont then return end
    local ok, file, height, flags = pcall(ChatBubbleFont.GetFont, ChatBubbleFont)
    if not ok or not file or not Positive(height) then return end
    local savedHeight = Offhand.db
        and tonumber(Offhand.db.originalChatBubbleFontHeight) or nil
    local nativeHeight = Positive(savedHeight) and savedHeight >= 10
        and savedHeight or BASE_FONT_SIZE
    if math.abs(height - nativeHeight) > EPSILON then
        ChatBubbleFont:SetFont(file, nativeHeight, flags)
    end
    if Offhand.db then Offhand.db.originalChatBubbleFontHeight = nativeHeight end
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
        state = { originalFile = file, originalHeight = height, originalFlags = flags }
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

local function InInstance()
    if type(IsInInstance) ~= "function" then return false end
    local ok, inside, instanceType = pcall(IsInInstance)
    return ok and inside == true and instanceType ~= "none"
end

local function EllesmereOwnsChatBubbles()
    -- Compatibility-only, read-only ownership probe. Offhand does not call the
    -- other addon's layout, refresh or mutation paths. A missing or changed
    -- interface fails open; the native-child alpha gate below remains the
    -- final authority before Offhand claims a bubble.
    local eui = _G and _G.EllesmereUI
    if not eui or type(eui.GetActiveProfileData) ~= "function" then return false end
    local ok, profile = pcall(eui.GetActiveProfileData)
    local config = ok and type(profile) == "table" and profile.chatBubbles or nil
    return ok and type(config) == "table" and config.enabled == true
end

local function ScheduleImmediateSweep()
    if immediateSweepScheduled or not C_Timer or not C_Timer.After then return end
    immediateSweepScheduled = true
    C_Timer.After(0, function()
        immediateSweepScheduled = false
        Bubbles:ApplyLayout()
    end)
end

local function ReplacementDecision()
    replacementConflict = "none"
    if not UsesForeverNativeWorldTextScale() then return false, "native-client" end
    if not Offhand.db or Offhand.db.enabled ~= true then return false, "offhand-disabled" end
    if Offhand.db.speechBubbleCompensation == false then return false, "user-disabled" end
    if InInstance() then return false, "instance-native" end
    if EllesmereOwnsChatBubbles() then
        replacementConflict = "EllesmereUI"
        return false, "yielding"
    end
    if not Offhand.Viewport or type(Offhand.Viewport.GetMetrics) ~= "function" then
        return false, "metrics-unavailable"
    end
    local ok, metrics = pcall(Offhand.Viewport.GetMetrics, Offhand.Viewport)
    if not ok or type(metrics) ~= "table" or metrics.isSpanned ~= true then
        return false, "unspanned"
    end
    local physicalHeight = math.max(1, tonumber(metrics.physicalHeight) or 1)
    local gameHeight = math.max(0, tonumber(metrics.gamePixelHeight) or 0)
    local heightRatio = gameHeight / physicalHeight
    -- Equal-height horizontal spans have not exhibited enlarged bubbles. The
    -- replacement is deliberately limited to a materially shorter Mainhand so
    -- unaffected players retain Blizzard's native bubble and styling.
    if not Positive(heightRatio) or math.abs(heightRatio - 1) <= 0.01 then
        return false, "equal-height-native"
    end
    return true, "mixed-height-replacement"
end

local function FindNativeParts(outer)
    if not Accessible(outer) then return nil, nil end
    local resolvedChild, resolvedFont
    local ok = pcall(function()
        if type(outer.GetChildren) ~= "function" then return end
        local children = { outer:GetChildren() }
        for _, child in ipairs(children) do
            if child and type(child.GetRegions) == "function" then
                local regions = { child:GetRegions() }
                local fontString = SafeValue(child, "GetObjectType") == "FontString" and child or nil
                for _, region in ipairs(regions) do
                    if not fontString and SafeValue(region, "GetObjectType") == "FontString" then
                        fontString = region
                    end
                end
                if not fontString then
                    local direct = child.String
                    if direct and SafeValue(direct, "GetObjectType") == "FontString" then
                        fontString = direct
                    end
                end
                if fontString then
                    resolvedChild, resolvedFont = child, fontString
                    return
                end
            end
        end
    end)
    if ok then return resolvedChild, resolvedFont end
end

local function ReadNativeText(fontString)
    local text = SafeValue(fontString, "GetText")
    if type(text) ~= "string" or IsSecret(text) or text == "" then return nil end
    return text
end

local function ReadNativeColor(fontString)
    if not fontString then return 1, 1, 1 end
    local ok, r, g, b = pcall(function()
        if type(fontString.GetTextColor) ~= "function" then error("GetTextColor unavailable") end
        return fontString:GetTextColor()
    end)
    if not ok or type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number"
        or IsSecret(r) or IsSecret(g) or IsSecret(b) then
        return 1, 1, 1
    end
    return r, g, b
end

local function SetNativeAlpha(child, alpha)
    if not child then return false end
    return pcall(function()
        if type(child.SetAlpha) ~= "function" then error("SetAlpha unavailable") end
        child:SetAlpha(alpha)
    end)
end

local function RestoreNativeChild(child, state)
    if not child or not state then return true end
    local current = SafeValue(child, "GetAlpha")
    if type(current) ~= "number" then return false end
    -- Another addon changing alpha after our claim takes ownership from us.
    if math.abs(current - state.appliedAlpha) > EPSILON then return true end
    return SetNativeAlpha(child, state.originalAlpha)
end

local function RetryNativeRestores()
    for child, state in pairs(pendingRestore) do
        if RestoreNativeChild(child, state) then pendingRestore[child] = nil end
    end
end

local function ConfigureClassicBackdrop(frame)
    if type(frame.SetBackdrop) ~= "function" then return false end
    local ok = pcall(frame.SetBackdrop, frame, {
        bgFile = "Interface\\Tooltips\\ChatBubble-Background",
        edgeFile = "Interface\\Tooltips\\ChatBubble-Backdrop",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 16, right = 16, top = 16, bottom = 16 },
    })
    if not ok then return false end
    if frame.SetBackdropColor then frame:SetBackdropColor(1, 1, 1, 1) end
    if frame.SetBackdropBorderColor then frame:SetBackdropBorderColor(1, 1, 1, 1) end
    return true
end

local function NewReplacement()
    if type(CreateFrame) ~= "function" or not UIParent then return nil end
    local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    if not frame or not ConfigureClassicBackdrop(frame) then return nil end
    frame:SetFrameStrata("HIGH")
    frame:SetFrameLevel(150)
    frame:EnableMouse(false)
    frame:Hide()

    frame.text = frame:CreateFontString(nil, "ARTWORK")
    if not frame.text then return nil end
    frame.text:SetFont("Fonts\\FRIZQT__.TTF", BASE_FONT_SIZE, "")
    frame.text:SetTextColor(1, 1, 1, 1)
    frame.text:SetJustifyH("CENTER")
    frame.text:SetJustifyV("MIDDLE")
    frame.text:SetWordWrap(true)
    if frame.text.SetNonSpaceWrap then frame.text:SetNonSpaceWrap(true) end
    frame.text:SetPoint("CENTER", frame, "CENTER", 0, 1)

    frame.tail = frame:CreateTexture(nil, "ARTWORK")
    if frame.tail then
        local atlasOK = false
        if type(frame.tail.SetAtlas) == "function" then
            atlasOK = pcall(frame.tail.SetAtlas, frame.tail, "ChatBubble-NineSlice-Tail", true)
        end
        if not atlasOK and type(frame.tail.SetTexture) == "function" then
            frame.tail:SetTexture("Interface\\Tooltips\\ChatBubble-Tail")
            frame.tail:SetSize(16, 16)
        end
        frame.tail:ClearAllPoints()
        frame.tail:SetPoint("TOP", frame, "BOTTOM", -8, 5)
        frame.tail:Show()
    end
    return frame
end

local function AcquireReplacement()
    local frame = table.remove(replacementPool)
    if not frame then frame = NewReplacement() end
    if not frame then return nil end
    frame.inUse = true
    return frame
end

local function LayoutReplacement(frame, text, nativeFont)
    local fineTune = math.max(0.50, math.min(1.50,
        tonumber(Offhand.db and Offhand.db.speechBubbleScale) or 1))
    frame:SetScale(fineTune)

    local file, flags
    if nativeFont and type(nativeFont.GetFont) == "function" then
        local ok, ignoredHeight
        ok, file, ignoredHeight, flags = pcall(nativeFont.GetFont, nativeFont)
        if not ok then file, flags = nil, nil end
    end
    if type(file) ~= "string" or file == "" then file = "Fonts\\FRIZQT__.TTF" end
    if type(flags) ~= "string" then flags = "" end
    if frame.text:SetFont(file, BASE_FONT_SIZE, flags) == false then
        frame.text:SetFont("Fonts\\FRIZQT__.TTF", BASE_FONT_SIZE, "")
    end
    local r, g, b = ReadNativeColor(nativeFont)
    frame.text:SetTextColor(r, g, b, 1)
    frame.text:SetWidth(MAX_TEXT_WIDTH)
    frame.text:SetText(text)

    local width = SafeValue(frame.text, "GetUnboundedStringWidth")
        or SafeValue(frame.text, "GetStringWidth") or MAX_TEXT_WIDTH
    width = math.max(1, math.min(MAX_TEXT_WIDTH, tonumber(width) or MAX_TEXT_WIDTH))
    frame.text:SetWidth(width)
    local height = SafeValue(frame.text, "GetStringHeight") or BASE_FONT_SIZE
    height = math.max(BASE_FONT_SIZE, tonumber(height) or BASE_FONT_SIZE)
    frame:SetSize(math.max(MIN_BUBBLE_WIDTH, width + HORIZONTAL_PADDING * 2),
        math.max(MIN_BUBBLE_HEIGHT, height + VERTICAL_PADDING * 2))
    frame.lastText = text
    frame.lastFineTune = fineTune
end

local function ReleaseOuter(outer)
    local frame = replacementByOuter[outer]
    if not frame then return end
    RestoreClamp(frame)
    replacementByOuter[outer] = nil
    replacementCount = math.max(0, replacementCount - 1)

    if frame.nativeChild and frame.nativeState then
        if not RestoreNativeChild(frame.nativeChild, frame.nativeState) then
            pendingRestore[frame.nativeChild] = frame.nativeState
        end
    end
    frame.nativeChild, frame.nativeState, frame.outer = nil, nil, nil
    frame.lastText, frame.lastFineTune = nil, nil
    frame:ClearAllPoints()
    frame:Hide()
    frame.inUse = false
    replacementPool[#replacementPool + 1] = frame
end

local function ReleaseAllReplacements()
    for outer in pairs(replacementByOuter) do ReleaseOuter(outer) end
    RetryNativeRestores()
end

local function HookOuter(outer)
    if hookedOuter[outer] or not outer then return end
    hookedOuter[outer] = true
    pcall(function()
        if type(outer.HookScript) ~= "function" then return end
        outer:HookScript("OnHide", function(hiddenOuter)
            ReleaseOuter(hiddenOuter)
        end)
        outer:HookScript("OnShow", function()
            if C_Timer and C_Timer.After then
                C_Timer.After(0, function() Bubbles:ApplyLayout() end)
            end
        end)
    end)
end

local function ClaimOrRefresh(outer, child, nativeFont, text)
    local frame = replacementByOuter[outer]
    if frame then
        local currentAlpha = SafeValue(child, "GetAlpha")
        if child ~= frame.nativeChild or type(currentAlpha) ~= "number"
            or math.abs(currentAlpha - frame.nativeState.appliedAlpha) > EPSILON then
            ReleaseOuter(outer)
            return false
        end
        local fineTune = math.max(0.50, math.min(1.50,
            tonumber(Offhand.db and Offhand.db.speechBubbleScale) or 1))
        if frame.lastText ~= text or math.abs((frame.lastFineTune or 0) - fineTune) > EPSILON then
            LayoutReplacement(frame, text, nativeFont)
        end
        ConstrainBubble(frame)
        return true
    end

    local originalAlpha = SafeValue(child, "GetAlpha")
    -- A child already hidden or fading is owned by another addon (or is ending).
    -- Never place a second replacement over it.
    if type(originalAlpha) ~= "number" or originalAlpha < 0.95 then return false end

    frame = AcquireReplacement()
    if not frame then return false end
    frame.outer, frame.nativeChild = outer, child
    frame.nativeState = { originalAlpha = originalAlpha, appliedAlpha = 0 }
    replacementByOuter[outer] = frame
    replacementCount = replacementCount + 1

    frame:SetAlpha(0)
    frame:Show()
    LayoutReplacement(frame, text, nativeFont)
    frame:ClearAllPoints()
    local anchored = pcall(frame.SetPoint, frame, "CENTER", outer, "CENTER", 0, 0)
    if not anchored or not SetNativeAlpha(child, 0) then
        ReleaseOuter(outer)
        return false
    end
    frame:SetAlpha(1)
    ConstrainBubble(frame)
    HookOuter(outer)
    return true
end

local function UpdateReplacements()
    RetryNativeRestores()
    if not C_ChatBubbles or type(C_ChatBubbles.GetAllChatBubbles) ~= "function" then
        ReleaseAllReplacements()
        replacementMode = "api-unavailable"
        return
    end
    local ok, list = pcall(C_ChatBubbles.GetAllChatBubbles)
    if not ok or type(list) ~= "table" then
        ReleaseAllReplacements()
        replacementMode = "api-failed"
        return
    end

    local visible = setmetatable({}, { __mode = "k" })
    for _, outer in pairs(list) do
        pcall(function()
            if not Accessible(outer) or not outer:IsShown() then return end
            visible[outer] = true
            HookOuter(outer)
            local child, nativeFont = FindNativeParts(outer)
            local text = ReadNativeText(nativeFont)
            if child and text then ClaimOrRefresh(outer, child, nativeFont, text) end
        end)
    end
    for outer in pairs(replacementByOuter) do
        if not visible[outer] then ReleaseOuter(outer) end
    end
end

local function ObjectLabel(object)
    if not object then return "nil" end
    return tostring(SafeValue(object, "GetName") or SafeValue(object, "GetObjectType") or "Object")
end

local function DescribePoints(object)
    local count = SafeValue(object, "GetNumPoints")
    if type(count) ~= "number" or count < 1 then return "none" end
    local descriptions = {}
    for index = 1, math.min(count, 4) do
        local ok, point, relativeTo, relativePoint, x, y = pcall(object.GetPoint, object, index)
        if ok then
            descriptions[#descriptions + 1] = string.format("%s>%s:%s:%.2f,%.2f",
                tostring(point), ObjectLabel(relativeTo), tostring(relativePoint),
                tonumber(x) or 0, tonumber(y) or 0)
        end
    end
    return #descriptions > 0 and table.concat(descriptions, ";") or "none"
end

local function DescribeObject(object)
    if not object then return "nil" end
    local objectType = SafeValue(object, "GetObjectType") or "Object"
    local name = SafeValue(object, "GetName") or "anon"
    local width, height = SafeValue(object, "GetWidth"), SafeValue(object, "GetHeight")
    local scale, effective = SafeValue(object, "GetScale"), SafeValue(object, "GetEffectiveScale")
    return string.format("%s:%s:%s:s%s:e%s", tostring(objectType), tostring(name),
        Positive(width) and Positive(height) and string.format("%.1fx%.1f", width, height) or "?x?",
        Positive(scale) and string.format("%.3f", scale) or "?",
        Positive(effective) and string.format("%.3f", effective) or "?")
end

local function CaptureBubbleStructure(outer)
    local child, font = FindNativeParts(outer)
    Bubbles.lastStructure = string.format("Root=%s | Parent=%s | Child=%s | Font=%s",
        DescribeObject(outer), DescribeObject(SafeValue(outer, "GetParent")),
        DescribeObject(child), DescribeObject(font))
    Bubbles.lastAnchors = string.format("Root=%s | Parent=%s | Child=%s | Replacement=%s",
        DescribePoints(outer), DescribePoints(SafeValue(outer, "GetParent")),
        DescribePoints(child), replacementByOuter[outer] and DescribePoints(replacementByOuter[outer]) or "none")
end

function Bubbles:ApplyLayout()
    if not Offhand.db then return end
    for frame in pairs(clampStates) do
        if not Offhand.db.enabled or (frame.IsShown and not frame:IsShown()) then RestoreClamp(frame) end
    end
    if UsesForeverNativeWorldTextScale() then
        -- Clean up every mutation made by earlier Beta 21 experiments before
        -- entering the replacement path. These are one-time ownership handbacks.
        RestoreTrackedBubbles()
        RestoreForeverNativeBubbleFont()
        local replace, mode = ReplacementDecision()
        replacementMode = mode
        if replace then UpdateReplacements() else ReleaseAllReplacements() end
        return
    end

    ReleaseAllReplacements()
    if EllesmereOwnsChatBubbles() then
        RestoreTrackedBubbles()
        RestoreInstanceFont()
        for frame in pairs(clampStates) do RestoreClamp(frame) end
        return
    end
    if not Offhand.db.enabled then
        RestoreTrackedBubbles()
        RestoreInstanceFont()
        return
    end
    local target = UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()
    if not Positive(target) then return end
    if IsRetailSpannedInstance() then
        for frame in pairs(clampStates) do RestoreClamp(frame) end
        RestoreTrackedBubbles()
        ApplyInstanceFont(target)
        return
    end
    RestoreInstanceFont()
    if not C_ChatBubbles or not C_ChatBubbles.GetAllChatBubbles then return end
    local ok, bubbles = pcall(C_ChatBubbles.GetAllChatBubbles)
    if not ok or type(bubbles) ~= "table" then return end
    for _, bubble in pairs(bubbles) do
        pcall(function()
            if not Accessible(bubble) or not bubble:IsShown() then return end
            local current, effective = bubble:GetScale(), bubble:GetEffectiveScale()
            if not Positive(current) or not Positive(effective) then return end
            local state = tracked[bubble]
            if not state or math.abs(current - state.applied) > EPSILON then
                state = { original = current }
            end
            local desired = state.original * target / (effective / current)
            if not Positive(desired) then return end
            if math.abs(current - desired) > EPSILON then bubble:SetScale(desired) end
            state.applied = desired
            tracked[bubble] = state
            ConstrainBubble(bubble)
        end)
    end
end

function Bubbles:GetDiagnostics()
    local replace, decision = ReplacementDecision()
    local result = {
        supported = C_ChatBubbles and type(C_ChatBubbles.GetAllChatBubbles) == "function",
        visible = 0, includingForbidden = 0, forbidden = 0, protected = 0,
        fontManaged = instanceFontState ~= nil,
        fontOriginal = instanceFontState and instanceFontState.originalHeight or nil,
        fontApplied = instanceFontState and instanceFontState.appliedHeight or nil,
        fontCurrent = nil,
        nativeWorldTextOwned = UsesForeverNativeWorldTextScale(),
        rootManaged = 0,
        foreverTarget = nil,
        foreverEnabled = Offhand.db and Offhand.db.speechBubbleCompensation ~= false or false,
        foreverFineTune = math.max(0.50, math.min(1.50,
            tonumber(Offhand.db and Offhand.db.speechBubbleScale) or 1)),
        visualManaged = replacementCount,
        visualRatio = replacementCount > 0 and math.max(0.50, math.min(1.50,
            tonumber(Offhand.db and Offhand.db.speechBubbleScale) or 1)) or nil,
        visualNativeAnchors = replacementCount > 0,
        replacementEligible = replace,
        replacementMode = replacementMode ~= "native" and replacementMode or decision,
        replacementConflict = replacementConflict,
        structure = Bubbles.lastStructure,
        anchors = Bubbles.lastAnchors,
    }
    for _ in pairs(tracked) do result.rootManaged = result.rootManaged + 1 end
    if ChatBubbleFont and ChatBubbleFont.GetFont then
        local fontOK, _, fontHeight = pcall(ChatBubbleFont.GetFont, ChatBubbleFont)
        if fontOK and Positive(fontHeight) then result.fontCurrent = fontHeight end
    end
    if not result.supported then return result end
    local ok, visible = pcall(C_ChatBubbles.GetAllChatBubbles, false)
    if ok and type(visible) == "table" then
        result.visible = #visible
        for _, outer in pairs(visible) do
            if Accessible(outer) then CaptureBubbleStructure(outer); break end
        end
    end
    local allOK, all = pcall(C_ChatBubbles.GetAllChatBubbles, true)
    if not allOK or type(all) ~= "table" then return result end
    result.includingForbidden = #all
    for _, bubble in pairs(all) do
        local forbiddenOK, forbidden = pcall(function() return bubble:IsForbidden() end)
        if not forbiddenOK or forbidden then
            result.forbidden = result.forbidden + 1
        else
            local protectedOK, protected = pcall(function() return bubble:IsProtected() end)
            if not protectedOK or protected then result.protected = result.protected + 1 end
        end
    end
    return result
end

function Bubbles:Initialize()
    if self.ticker or not C_Timer or not C_Timer.NewTicker
        or not C_ChatBubbles or not C_ChatBubbles.GetAllChatBubbles then return end
    self.ticker = C_Timer.NewTicker(0.1, function() self:ApplyLayout() end)
    if type(CreateFrame) == "function" then
        self.events = CreateFrame("Frame")
        self.events:RegisterEvent("PLAYER_ENTERING_WORLD")
        self.events:RegisterEvent("PLAYER_LOGOUT")
        for _, event in ipairs(CHAT_BUBBLE_EVENTS) do
            self.events:RegisterEvent(event)
        end
        self.events:SetScript("OnEvent", function(_, event)
            if event == "PLAYER_LOGOUT" then
                ReleaseAllReplacements()
            else
                self:ApplyLayout()
                if event ~= "PLAYER_ENTERING_WORLD" then ScheduleImmediateSweep() end
            end
        end)
    end
end
