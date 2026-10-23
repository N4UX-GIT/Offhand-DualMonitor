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
