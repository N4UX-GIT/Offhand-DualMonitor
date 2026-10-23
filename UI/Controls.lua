--[[
    Offhand: Multi-Monitor Setup Addon
    UI/Controls.lua: Shared UI control behavior
--]]

local _, Offhand = ...

local Controls = {}
Offhand.UIControls = Controls

-- Only addon-owned settings controls opt into this presentation layer. Never
-- skin Blizzard windows or modify the global CreateFrame function.
local styledFrames = setmetatable({}, { __mode = "k" })
local FLAT_BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
}

function Controls.GetAccent()
    local db = Offhand.db or {}
    local palettes = Offhand.Themes and Offhand.Themes:GetColorPalettes() or {}
    local color = db.trimColor == "CUSTOM" and db.customTrimColor or palettes[db.trimColor or "GOLD"]
    return (color and color.r) or 1, (color and color.g) or 0.82, (color and color.b) or 0.12
end

function Controls.StyleSurface(frame, kind)
    if not frame or not frame.SetBackdrop or not frame.SetBackdropColor
        or not frame.SetBackdropBorderColor then return end
    kind = kind or "card"
    styledFrames[frame] = kind
    frame:SetBackdrop(FLAT_BACKDROP)
    local black = Offhand.db and Offhand.db.theme == "PITCH_BLACK"
    local shade = black and 0 or (kind == "window" and 0.035 or 0.065)
    if kind == "input" then shade = black and 0 or 0.025 end
    local enabled = not frame.IsEnabled or frame:IsEnabled()
    local selected = frame.selected or frame.uiPrimary
    local active = selected or frame.uiHover or frame.uiFocus
    local r, g, b = Controls.GetAccent()
    if kind == "button" then
        shade = enabled and (frame.uiPressed and 0.055 or (active and 0.14 or 0.09)) or 0.045
    end
    frame:SetBackdropColor(shade, shade, black and shade or shade + 0.014, 1)
    if active and enabled then
        frame:SetBackdropBorderColor(r * 0.85, g * 0.85, b * 0.85, 1)
    else
        frame:SetBackdropBorderColor(0.20, 0.22, 0.26, 1)
    end
    if kind == "button" then
        local text = frame.GetFontString and frame:GetFontString()
        if text and text.SetTextColor then
            if not enabled then text:SetTextColor(0.45, 0.48, 0.53)
            else text:SetTextColor(0.93, 0.94, 0.96) end
        end
        if frame.selectionMark then
            if frame.selected then frame.selectionMark:Show() else frame.selectionMark:Hide() end
        end
    end
    if (kind == "card" or kind == "header") and frame.title and frame.title.SetTextColor then
        frame.title:SetTextColor(r, g, b, 1)
    end
end

function Controls.RefreshStyles()
    for frame, kind in pairs(styledFrames) do Controls.StyleSurface(frame, kind) end
end

-- Use native Button state/font handling with addon-owned flat artwork. Small
-- steppers retain their explicit size; labels wrap inside the available bounds.
function Controls.CreateFrame(kind, name, parent, template, ...)
    local button = kind == "Button" and template == "UIPanelButtonTemplate"
    local input = kind == "EditBox" and template == "InputBoxTemplate"
    if button or input then template = not Offhand.isLegacyWrath and "BackdropTemplate" or nil end
    local frame = _G.CreateFrame(kind, name, parent, template, ...)
    if button then
        if frame.SetFontString then
            local text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            text:SetPoint("TOPLEFT", frame, "TOPLEFT", 5, -2)
            text:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -5, 2)
            text:SetJustifyH("CENTER")
            text:SetWordWrap(true)
            frame:SetFontString(text)
            frame:SetNormalFontObject("GameFontHighlightSmall")
            frame:SetHighlightFontObject("GameFontHighlightSmall")
            frame:SetDisabledFontObject("GameFontDisableSmall")
            if frame.SetPushedTextOffset then frame:SetPushedTextOffset(0, -1) end
        end
        local mark = frame.CreateTexture and frame:CreateTexture(nil, "OVERLAY")
        if mark and mark.SetColorTexture and mark.Show and mark.Hide then
            mark:SetColorTexture(0.93, 0.94, 0.96, 1)
            mark:SetSize(2, 12)
            mark:SetPoint("LEFT", frame, "LEFT", 2, 0)
            frame.selectionMark = mark
        end
        Controls.StyleSurface(frame, "button")
        if frame.HookScript then
            frame:HookScript("OnEnter", function(self) self.uiHover = true; Controls.StyleSurface(self, "button") end)
            frame:HookScript("OnLeave", function(self) self.uiHover = nil; self.uiPressed = nil; Controls.StyleSurface(self, "button") end)
            frame:HookScript("OnEnable", function(self) Controls.StyleSurface(self, "button") end)
            frame:HookScript("OnDisable", function(self) Controls.StyleSurface(self, "button") end)
            frame:HookScript("OnMouseDown", function(self) self.uiPressed = true; Controls.StyleSurface(self, "button") end)
            frame:HookScript("OnMouseUp", function(self) self.uiPressed = nil; Controls.StyleSurface(self, "button") end)
            frame:HookScript("OnHide", function(self) self.uiHover = nil; self.uiPressed = nil; Controls.StyleSurface(self, "button") end)
        end
    elseif input then
        frame:SetAutoFocus(false)
        if frame.SetFontObject then frame:SetFontObject("GameFontHighlightSmall") end
        if frame.SetTextInsets then frame:SetTextInsets(8, 8, 0, 0) end
        Controls.StyleSurface(frame, "input")
        if frame.HookScript then
            frame:HookScript("OnEditFocusGained", function(self) self.uiFocus = true; Controls.StyleSurface(self, "input") end)
            frame:HookScript("OnEditFocusLost", function(self) self.uiFocus = nil; Controls.StyleSurface(self, "input") end)
        end
    end
    return frame
end

local CreateFrame = Controls.CreateFrame

function Controls.StyleSlider(slider)
    Controls.StyleSurface(slider, "input")
    local thumb = slider.thumb or (slider.GetThumbTexture and slider:GetThumbTexture())
    if thumb then
        if thumb.SetTexture then thumb:SetTexture("Interface\\Buttons\\WHITE8X8") end
        if thumb.SetSize then thumb:SetSize(10, 20) end
        if thumb.SetVertexColor then thumb:SetVertexColor(Controls.GetAccent()) end
    end
    if slider.editBox then Controls.StyleSurface(slider.editBox, "input") end
end

-- Fit a logical canvas rather than compressing individual columns. Metrics are
-- UIParent units, so compensate for our local scale when centering in callers.
function Controls.FitDialog(frame, metrics)
    if not frame or not frame.SetScale then return 1 end
    local width = metrics and metrics.gameWidth or (UIParent.GetWidth and UIParent:GetWidth())
    local height = metrics and metrics.gameHeight or (UIParent.GetHeight and UIParent:GetHeight())
    width, height = tonumber(width) or 1920, tonumber(height) or 1080
    if width <= 0 or height <= 0 then return 1 end
    local scale = math.min(1, math.max(1, width - 32) / frame:GetWidth(),
        math.max(1, height - 32) / frame:GetHeight())
    frame:SetScale(scale)
    return scale
end

function Controls.SetScrollOffset(scroll, offset)
    local child = scroll.GetScrollChild and scroll:GetScrollChild() or scroll.scrollChild
    local range = child and math.max(0, child:GetHeight() - scroll:GetHeight()) or 0
    offset = math.max(0, math.min(range, tonumber(offset) or 0))
    scroll:SetVerticalScroll(offset)
    local name = scroll.GetName and scroll:GetName()
    local bar = scroll.ScrollBar or (name and _G[name .. "ScrollBar"])
    if bar and bar.SetMinMaxValues then bar:SetMinMaxValues(0, range) end
    if bar and bar.SetValue then bar:SetValue(offset) end
    return offset
end

function Controls.EnableWheelScroll(scroll)
    local name = scroll.GetName and scroll:GetName()
    local bar = scroll.ScrollBar or (name and _G[name .. "ScrollBar"])
    if bar and bar.SetThumbTexture and bar.GetThumbTexture then
        bar:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
        local thumb = bar:GetThumbTexture()
        if thumb then thumb:SetVertexColor(0.42, 0.46, 0.53, 1); thumb:SetWidth(8) end
    end
    if not scroll.EnableMouseWheel then return end
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        Controls.SetScrollOffset(self, (self:GetVerticalScroll() or 0) - delta * 40)
    end)
end

function Controls.CreateNativeSlider(parent, text, minVal, maxVal, step, getVal, setVal, formatStr, tooltipTitle, tooltipText)
    local L = Offhand.L or setmetatable({}, { __index = function(_, key) return key end })
    local function BackdropTemplate()
        return not Offhand.isLegacyWrath and "BackdropTemplate" or nil
    end
    local slider = CreateFrame("Slider", nil, parent, BackdropTemplate())
    slider:SetOrientation("HORIZONTAL")
    slider:SetSize(220, 16)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider:SetValue(getVal())
    slider:EnableMouse(true)

    slider:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    slider:SetBackdropColor(0.06, 0.06, 0.08, 0.95)
    slider:SetBackdropBorderColor(0.40, 0.38, 0.30, 0.9)

    local thumb = slider:CreateTexture(nil, "OVERLAY")
    if thumb and thumb.SetTexture then
        thumb:SetTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    elseif thumb and thumb.SetColorTexture then
        thumb:SetColorTexture(1.0, 0.82, 0.0, 1.0)
    end
    if thumb and thumb.SetSize then
        thumb:SetSize(18, 20)
    end
    slider:SetThumbTexture(thumb)
    slider.thumb = thumb

    local function FormatValue(value)
        if not value then value = 0 end
        if formatStr and formatStr:find("%%%%") then value = value * 100 end
        return string.format(formatStr or "%d", value)
    end

    -- Value Stepper [+] Button (Top-Right)
    local btnPlus = CreateFrame("Button", nil, slider, "UIPanelButtonTemplate")
    btnPlus:SetSize(24, 24)
    btnPlus:SetPoint("BOTTOMRIGHT", slider, "TOPRIGHT", 0, 3)
    btnPlus:SetText("+")
    slider.btnPlus = btnPlus
    if Offhand.SetTooltip then
        Offhand:SetTooltip(btnPlus, L["SLIDER_STEP_UP_TIP_TITLE"], string.format(L["SLIDER_STEP_UP_TIP_DESC_FMT"], FormatValue(step)))
    end

    -- Direct Value Entry EditBox
    local editBox = CreateFrame("EditBox", nil, slider, BackdropTemplate())
    editBox:SetSize(56, 24)
    editBox:SetPoint("RIGHT", btnPlus, "LEFT", -2, 0)
    editBox:SetAutoFocus(false)
    if editBox.SetFontObject then editBox:SetFontObject("GameFontHighlightSmall") end
    if editBox.SetJustifyH then editBox:SetJustifyH("CENTER") end
    if editBox.SetBackdrop then
        editBox:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        editBox:SetBackdropColor(0.04, 0.04, 0.06, 0.9)
        editBox:SetBackdropBorderColor(0.35, 0.33, 0.28, 0.9)
    end
    editBox:SetText(FormatValue(getVal()))
    slider.editBox = editBox
    if Offhand.SetTooltip then
        Offhand:SetTooltip(editBox, L["SLIDER_EDITBOX_TIP_TITLE"], L["SLIDER_EDITBOX_TIP_DESC"])
    end

    -- Value Stepper [-] Button
    local btnMinus = CreateFrame("Button", nil, slider, "UIPanelButtonTemplate")
    btnMinus:SetSize(24, 24)
    btnMinus:SetPoint("RIGHT", editBox, "LEFT", -2, 0)
    btnMinus:SetText("-")
    slider.btnMinus = btnMinus
    if Offhand.SetTooltip then
        Offhand:SetTooltip(btnMinus, L["SLIDER_STEP_DOWN_TIP_TITLE"], string.format(L["SLIDER_STEP_DOWN_TIP_DESC_FMT"], FormatValue(step)))
    end

    -- Header Title
    local title = slider:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    title:SetPoint("BOTTOMLEFT", slider, "TOPLEFT", 0, 5)
    title:SetPoint("BOTTOMRIGHT", btnMinus, "BOTTOMLEFT", -6, 0)
    title:SetJustifyH("LEFT")
    title:SetText(text)
    slider.title = title

    -- Backward-compatible valueText proxy object
    local valueText = {
        SetText = function(self, t)
            if editBox and not (editBox.HasFocus and editBox:HasFocus()) then
                editBox:SetText(t)
            end
        end,
        GetText = function(self)
            return editBox:GetText()
        end,
    }
    slider.valueText = valueText

    slider.SetValueDirect = function(self, val)
        self._isDirect = true
        self:SetValue(val)
        self._isDirect = nil
    end

    local function CommitEditBox()
        local txt = editBox:GetText()
        local parsed = Controls.ParseSliderInput(txt, minVal, maxVal, step, formatStr)
        if parsed then
            slider:SetValueDirect(parsed)
            -- SetValue may not emit OnValueChanged when the parsed value is
            -- unchanged. Always normalize typed input back to its display unit.
            editBox:SetText(FormatValue(parsed))
        else
            editBox:SetText(FormatValue(slider:GetValue() or getVal()))
        end
        if editBox.ClearFocus then editBox:ClearFocus() end
    end

    editBox:SetScript("OnEnterPressed", function(self)
        CommitEditBox()
    end)

    editBox:SetScript("OnEscapePressed", function(self)
        self:SetText(FormatValue(slider:GetValue() or getVal()))
        if self.ClearFocus then self:ClearFocus() end
    end)

    editBox:SetScript("OnEditFocusLost", function(self)
        CommitEditBox()
        if self.SetBackdropBorderColor then
            self:SetBackdropBorderColor(0.35, 0.33, 0.28, 0.9)
        end
    end)

    editBox:SetScript("OnEditFocusGained", function(self)
        if self.HighlightText then self:HighlightText() end
        if self.SetBackdropBorderColor then
            self:SetBackdropBorderColor(1.0, 0.82, 0.0, 1.0)
        end
    end)

    btnMinus:SetScript("OnClick", function()
        if editBox.ClearFocus then editBox:ClearFocus() end
        local cur = slider:GetValue() or getVal()
        local stepAmount = step
        if IsShiftKeyDown and IsShiftKeyDown() then stepAmount = step * 5 end
        local newVal = math.max(minVal, cur - stepAmount)
        newVal = math.floor(((newVal - minVal) / step) + 0.5) * step + minVal
        newVal = math.floor(newVal * 10000 + 0.5) / 10000
        slider:SetValueDirect(newVal)
    end)

    btnPlus:SetScript("OnClick", function()
        if editBox.ClearFocus then editBox:ClearFocus() end
        local cur = slider:GetValue() or getVal()
        local stepAmount = step
        if IsShiftKeyDown and IsShiftKeyDown() then stepAmount = step * 5 end
        local newVal = math.min(maxVal, cur + stepAmount)
        newVal = math.floor(((newVal - minVal) / step) + 0.5) * step + minVal
        newVal = math.floor(newVal * 10000 + 0.5) / 10000
        slider:SetValueDirect(newVal)
    end)

    -- Physical-pixel-delta drag controller.
    -- GetCursorPosition() returns raw screen pixels independent of UI scale.
    -- The same physical mouse movement always produces the same value change
    -- regardless of UIParent:SetScale(), fixing the runaway sensitivity on the
    -- Global UI Scale slider (which modifies the parent frame's own scale).
    local DRAG_PIXELS = 600  -- physical pixels of travel for full value range

    local function StartCustomDrag(self)
        self._dragStartX = GetCursorPosition and select(1, GetCursorPosition()) or 0
        self._dragStartVal = self:GetValue()
        self._isCustomDrag = true
        self:SetScript("OnUpdate", function(s)
            if not s._isCustomDrag then
                s:SetScript("OnUpdate", nil)
                return
            end
            local curX = GetCursorPosition and select(1, GetCursorPosition()) or s._dragStartX
            local pixelDelta = curX - s._dragStartX
            local valDelta = pixelDelta * ((maxVal - minVal) / DRAG_PIXELS)
            local newVal = math.max(minVal, math.min(maxVal, s._dragStartVal + valDelta))
            newVal = math.floor(((newVal - minVal) / step) + 0.5) * step + minVal
            newVal = math.floor(newVal * 10000 + 0.5) / 10000
            -- Update display directly (OnValueChanged returns early during drag)
            if editBox and not (editBox.HasFocus and editBox:HasFocus()) then
                editBox:SetText(FormatValue(newVal))
            end
            setVal(newVal)
            -- Move thumb to computed position (OnValueChanged early-returns for _isCustomDrag)
            s:SetValue(newVal)
        end)
    end

    slider:SetScript("OnMouseDown", function(self, button)
        if editBox and editBox.ClearFocus then editBox:ClearFocus() end
        if button == "LeftButton" then
            StartCustomDrag(self)
        end
    end)

    slider:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            self._isCustomDrag = false
            self._dragStartX = nil
            self._dragStartVal = nil
            self:SetScript("OnUpdate", nil)
            -- Native slider handling can move the thumb after the last custom
            -- OnUpdate. Commit that final displayed value before applying the
            -- layout so a quick drag does not require a step-button click.
            local finalValue = math.max(minVal, math.min(maxVal, self:GetValue() or getVal()))
            finalValue = math.floor(((finalValue - minVal) / step) + 0.5) * step + minVal
            finalValue = math.floor(finalValue * 10000 + 0.5) / 10000
            if editBox and not (editBox.HasFocus and editBox:HasFocus()) then
                editBox:SetText(FormatValue(finalValue))
            end
            setVal(finalValue)
            Offhand:ApplyFullLayout()
        end
    end)

    slider:SetScript("OnValueChanged", function(self, val, userInput)
        -- During custom drag, OnUpdate drives value + display; skip here
        if self._isCustomDrag then return end

        val = math.max(minVal, math.min(maxVal, val))
        val = math.floor(((val - minVal) / step) + 0.5) * step + minVal
        val = math.floor(val * 10000 + 0.5) / 10000
        local formatted = FormatValue(val)
        if editBox and not (editBox.HasFocus and editBox:HasFocus()) then
            editBox:SetText(formatted)
        end
        setVal(val)

        -- Direct programmatic set ([-]/[+] buttons, editBox, preset buttons)
        if self._isDirect then
            self._pendingApply = false
            self:SetScript("OnUpdate", nil)
            Offhand:ApplyFullLayout()
            return
        end

        -- Fallback for any external SetValue not covered above
        Offhand:ApplyFullLayout()
    end)

    slider.UpdateText = function(self)
        local formatted = FormatValue(getVal())
        if editBox and not (editBox.HasFocus and editBox:HasFocus()) then
            editBox:SetText(formatted)
        end
    end

    slider.UpdateTheme = function(self, trimKey)
        local key = trimKey or (Offhand.db and Offhand.db.trimColor) or "GOLD"
        local c
        if key == "CUSTOM" and Offhand.db and Offhand.db.customTrimColor then
            c = Offhand.db.customTrimColor
        else
            local pals = Offhand.Themes and Offhand.Themes.GetColorPalettes and Offhand.Themes:GetColorPalettes()
            c = pals and pals[key]
        end
        if c and self.thumb and self.thumb.SetVertexColor then
            self.thumb:SetVertexColor(c.r, c.g, c.b, 1.0)
        elseif self.thumb and self.thumb.SetVertexColor then
            self.thumb:SetVertexColor(1.0, 0.82, 0.0, 1.0)
        end
        Controls.StyleSlider(self)
    end
    slider:UpdateTheme()

    -- Compact right-column fields have no room for a title beside the input.
    -- Put the input beside the rail and give the title its full column width.
    slider.LayoutCompact = function(self)
        btnMinus:ClearAllPoints()
        btnMinus:SetPoint("LEFT", self, "RIGHT", 8, 0)
        editBox:ClearAllPoints()
        editBox:SetPoint("LEFT", btnMinus, "RIGHT", 2, 0)
        btnPlus:ClearAllPoints()
        btnPlus:SetPoint("LEFT", editBox, "RIGHT", 2, 0)
        if title.ClearAllPoints then title:ClearAllPoints() end
        title:SetPoint("BOTTOMLEFT", self, "TOPLEFT", 0, 5)
        title:SetPoint("BOTTOMRIGHT", self, "TOPRIGHT", 116, 5)
    end

    if (tooltipTitle or tooltipText) and Offhand.SetTooltip then
        Offhand:SetTooltip(slider, tooltipTitle, tooltipText)
    end

    return slider
end

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
    if styledFrames[button] then Controls.StyleSurface(button, "button") end
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
