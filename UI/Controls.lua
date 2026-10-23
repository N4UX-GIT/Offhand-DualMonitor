--[[
    Offhand: Multi-Monitor Setup Addon
    UI/Controls.lua: Shared UI control behavior
--]]

local _, Offhand = ...

local Controls = {}
Offhand.UIControls = Controls

function Controls.CreateNativeCheckbox(parent, text, getVal, setVal, tooltipTitle, tooltipText)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetSize(22, 22)

    local label = check:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("LEFT", check, "RIGHT", 8, 1)
    label:SetText(text)
    label:SetWidth(600)
    label:SetJustifyH("LEFT")
    check.Text = label

    local labelButton = CreateFrame("Button", nil, check)
    labelButton:SetPoint("TOPLEFT", label, "TOPLEFT", -4, 5)
    labelButton:SetPoint("BOTTOMRIGHT", label, "BOTTOMRIGHT", 4, -5)
    labelButton:SetScript("OnClick", function()
        check:SetChecked(not check:GetChecked())
        setVal(check:GetChecked())
        Offhand:ApplyFullLayout()
    end)
    check.labelButton = labelButton

    check:SetChecked(getVal())
    check:SetScript("OnClick", function(self)
        setVal(self:GetChecked())
        Offhand:ApplyFullLayout()
    end)
    if (tooltipTitle or tooltipText) and Offhand.SetTooltip then
        Offhand:SetTooltip(check, tooltipTitle, tooltipText)
        Offhand:SetTooltip(labelButton, tooltipTitle, tooltipText)
    end
    return check
end

function Controls.SetCheckboxEnabled(check, enabled)
    if not check then return end
    if check.SetEnabled then check:SetEnabled(enabled) end
    if check.labelButton and check.labelButton.SetEnabled then
        check.labelButton:SetEnabled(enabled)
    end
    if check.SetAlpha then check:SetAlpha(enabled and 1 or 0.55) end
    if check.Text and check.Text.SetTextColor then
        if enabled then
            check.Text:SetTextColor(1, 1, 1)
        else
            check.Text:SetTextColor(0.55, 0.55, 0.55)
        end
    end
end

function Controls.SetChoiceSelected(button, selected)
    if not button then return false end
    button:SetEnabled(true)
    button.selected = selected and true or false
    if selected and button.LockHighlight then
        button:LockHighlight()
    elseif button.UnlockHighlight then
        button:UnlockHighlight()
    end
    return true
end

function Controls.StackCards(parent, cards, spacing)
    if not parent or type(cards) ~= "table" then return 0 end
    spacing = tonumber(spacing) or 12
    local height = 0
    for _, card in ipairs(cards) do
        card:ClearAllPoints()
        card:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -height)
        height = height + card:GetHeight() + spacing
    end
    parent:SetHeight(height)
    return height
end

function Controls.CreateNativeRadioButton(parent, text, getVal, setVal, tooltipTitle, tooltipText)
    local radio = CreateFrame("CheckButton", nil, parent, "UIRadioButtonTemplate")
    radio:SetSize(18, 18)

    local label = radio:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("LEFT", radio, "RIGHT", 6, 1)
    label:SetText(text)
    radio.Text = label

    radio:SetChecked(getVal())
    radio:SetScript("OnClick", function()
        setVal()
        Offhand.Options:RefreshPanel()
    end)
    if (tooltipTitle or tooltipText) and Offhand.SetTooltip then
        Offhand:SetTooltip(radio, tooltipTitle, tooltipText)
    end
    return radio
end

function Controls.ParseSliderInput(inputStr, minVal, maxVal, step, formatStr)
    if not inputStr then return nil end
    local hasExplicitPercent = tostring(inputStr):find("%%") ~= nil
    local cleaned = tostring(inputStr):gsub("%%", ""):gsub("[^%d%.%-]", "")
    local num = tonumber(cleaned)
    if not num then return nil end
    local isPercent = formatStr and formatStr:find("%%%%")
    if isPercent then
        if hasExplicitPercent then
            num = num / 100
        elseif maxVal <= 2.5 and num > 2.5 then
            num = num / 100
        end
    end
    local clamped = math.max(minVal, math.min(maxVal, num))
    local stepped = math.floor(((clamped - minVal) / step) + 0.5) * step + minVal
    stepped = math.floor(stepped * 10000 + 0.5) / 10000
    return math.max(minVal, math.min(maxVal, stepped))
end

Offhand.ParseSliderInput = function(self, ...)
    if type(self) == "table" and self == Offhand then
        return Controls.ParseSliderInput(...)
    end
    return Controls.ParseSliderInput(self, ...)
end

function Controls.CreateBottomControl(parent)
    local labels = Offhand.L or setmetatable({}, {
        __index = function(_, key) return key end,
    })
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(280, 46)
    local label = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", 0, 0)
    label:SetText(labels["LABEL_BOTTOM_OFFSET_SHORT"])
    local input = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
    input:SetSize(55, 22)
    input:SetPoint("TOPLEFT", 4, -20)
    input:SetAutoFocus(false)
    input:SetNumeric(true)
    input:SetMaxLetters(5)
    local function Refresh()
        input:SetText(tostring(math.floor(Offhand.db.gameBottomPixels or 0)))
    end
    local function Apply(delta)
        local value = tonumber(input:GetText())
        if not value then Refresh(); return end
        local _, height = GetPhysicalScreenSize()
        Offhand.db.gameBottomPixels = math.max(0, math.min(height - 1,
            math.floor(value + (delta or 0) + 0.5)))
        Refresh()
        Offhand:ApplyFullLayout()
    end
    local previous = input
    for _, item in ipairs({ { "-1 px", -1 }, { "+1 px", 1 }, { "Apply", 0 } }) do
        local button = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        button:SetSize(54, 22)
        button:SetPoint("LEFT", previous, "RIGHT", 6, 0)
        button:SetText(item[1])
        local delta = item[2]
        button:SetScript("OnClick", function() Apply(delta) end)
        previous = button
    end
    input:SetScript("OnEnterPressed", function(self) Apply(0); self:ClearFocus() end)
    input:SetScript("OnEscapePressed", function(self) Refresh(); self:ClearFocus() end)
    row.Refresh = Refresh
    row:SetScript("OnShow", Refresh)
    Refresh()
    return row
end
