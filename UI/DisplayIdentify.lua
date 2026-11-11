-- Temporary addon-owned labels. Never enumerate or draw outside the WoW canvas.
local _, Offhand = ...
local L = Offhand.L
local Identify = {}
Offhand.DisplayIdentify = Identify
local cards = {}
local controller

function Identify:Hide()
    for _, card in ipairs(cards) do card:Hide() end
    if controller then controller:SetScript("OnUpdate", nil) end
end

local function Positive(value)
    return type(value) == "number" and value == value and value > 0 and value < math.huge
end

-- Use physical rectangles for both axes, including unequal display heights.
function Identify:GetRegions(m)
    local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
    if not m or not m.isSpanned or not Positive(m.physicalWidth)
        or not Positive(m.physicalHeight) then
        local method = Offhand.GetOnboardingSetupMethod and Offhand:GetOnboardingSetupMethod()
        return {{ x = 0, y = 0, width = sw, height = sh, unspanned = true,
            title = L["IDENTIFY_WINDOW"],
            detail = L[method == "COMPANION" and "IDENTIFY_UNSPANNED_COMPANION" or "IDENTIFY_UNSPANNED"] }}
    end
    local result = {}
    for _, entry in ipairs({{"game", "IDENTIFY_MAINHAND"}, {"workspace", "IDENTIFY_OFFHAND"}}) do
        local prefix = entry[1]
        local x, y = m[prefix .. "PixelLeft"], m[prefix .. "PixelBottom"]
        local w, h = m[prefix .. "PixelWidth"], m[prefix .. "PixelHeight"]
        if type(x) == "number" and type(y) == "number" and x >= 0 and y >= 0
            and Positive(w) and Positive(h) and x + w <= m.physicalWidth + 2
            and y + h <= m.physicalHeight + 2 then
            result[#result + 1] = {x = x * sw / m.physicalWidth,
                y = y * sh / m.physicalHeight, width = w * sw / m.physicalWidth,
                height = h * sh / m.physicalHeight, title = L[entry[2]],
                detail = L[m.companionTopology and "IDENTIFY_EXACT" or "IDENTIFY_CONFIGURED"]}
        end
    end
    if #result ~= 2 then
        return self:GetRegions(nil)
    end
    return result
end

local function Card(index)
    if cards[index] then return cards[index] end
    local f = CreateFrame("Frame", nil, UIParent,
        not Offhand.isLegacyWrath and "BackdropTemplate" or nil)
    f:SetSize(360, 180)
    f:SetFrameStrata("TOOLTIP")
    f:EnableMouse(false)
    Offhand.UIControls.StyleSurface(f, "card")
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetPoint("TOPRIGHT", -16, -16)
    title:SetWordWrap(true)
    f.title = title
    local detail = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    detail:SetPoint("TOPLEFT", 16, -52)
    detail:SetPoint("TOPRIGHT", -16, -52)
    detail:SetWordWrap(true)
    f.detail = detail
    local close = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    close:SetSize(150, 26)
    close:SetPoint("BOTTOM", 0, 12)
    close:SetText(L["IDENTIFY_CLOSE"])
    close:SetScript("OnClick", function() Identify:Hide() end)
    f.closeButton = close
    cards[index] = f
    return f
end

function Identify:Show()
    self:Hide()
    if InCombatLockdown and InCombatLockdown() then
        Offhand:Print(L["IDENTIFY_COMBAT"])
        return false
    end
    local m = Offhand.Viewport and Offhand.Viewport:GetMetrics()
    if Offhand._displayGeometryTransitionActive then m = nil end
    local regions = self:GetRegions(m)
    for index, region in ipairs(regions) do
        local card = Card(index)
        card.title:SetText(region.title)
        card.detail:SetText(region.detail)
        card.closeButton:SetText(L[region.unspanned and "IDENTIFY_BACK_TO_SETUP" or "IDENTIFY_CLOSE"])
        local height = 180
        if Offhand.UIControls.MeasurePopupText then
            if card.detail.SetHeight then card.detail:SetHeight(0) end
            local detailHeight = Offhand.UIControls.MeasurePopupText(card.detail, region.detail, 328)
            if card.detail.SetHeight then card.detail:SetHeight(detailHeight) end
            height = math.max(height, 52 + detailHeight + 56)
        end
        card:SetSize(360, height)
        local scale = math.min(1, (region.width - 12) / 360, (region.height - 12) / height)
        if scale > 0 then
            card:SetScale(scale)
            card:ClearAllPoints()
            card:SetPoint("CENTER", UIParent, "BOTTOMLEFT",
                (region.x + region.width / 2) / scale,
                (region.y + region.height / 2) / scale)
            card:Show()
        end
    end
    if not controller then
        controller = CreateFrame("Frame")
        for _, event in ipairs({"DISPLAY_SIZE_CHANGED", "UI_SCALE_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_LEAVING_WORLD"}) do
            controller:RegisterEvent(event)
        end
        controller:SetScript("OnEvent", function() Identify:Hide() end)
    end
    -- Instructions need reading time. Actual region labels still expire after
    -- twelve seconds; unconfirmed placement stays until closed or invalidated.
    if #regions == 1 and regions[1].unspanned then return true end
    local elapsed = 0
    controller:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + delta
        if elapsed >= 12 then Identify:Hide() end
    end)
    return true
end
