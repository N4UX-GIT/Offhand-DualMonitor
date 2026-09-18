--[[
    Offhand: Multi-Monitor Setup Addon
    UI/Options.lua: Clean Tabbed Settings, Calibration Dashboard & Setup Guide
    (Pure ASCII, sleek tabbed interface, zero clutter, bulletproof native widgets)
--]]

local _, Offhand = ...

local L = Offhand.L or setmetatable({}, {
    __index = function(t, key)
        return key
    end
})

local tinsert = table.insert


StaticPopupDialogs["OFFHAND_DOWNLOAD_LINK"] = {
    text = "The Companion App automates a pixel-perfect, borderless span across multiple monitors.\n\nDownload it securely from GitHub below:",
    button1 = "Close",
    hasEditBox = true,
    editBoxWidth = 260,
    OnShow = function(self)
        local eb = self.EditBox or _G[self:GetName().."EditBox"]
        if eb then
            eb:SetText("https://github.com/N4UX-GIT/Offhand-DualMonitor/releases/latest")
            eb:HighlightText()
            eb:SetFocus()
        end
    end,
    EditBoxOnEscapePressed = function(self)
        self:GetParent():Hide()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local Options = {}
Offhand.Options = Options

-- Shared presentation rules for settings and the wizard. Selection is not disability.
function Options:SetChoiceSelected(button, selected)
    button:SetEnabled(true)
    button.selected = selected
    if selected and button.LockHighlight then button:LockHighlight()
    elseif button.UnlockHighlight then button:UnlockHighlight() end
end

function Options:StackCards(parent, cards)
    local height = 0
    for _, card in ipairs(cards) do
        card:ClearAllPoints()
        card:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -height)
        height = height + card:GetHeight() + 12
    end
    parent:SetHeight(height)
end

function Options:Confirm(message, callback)
    StaticPopupDialogs["OFFHAND_CONFIRM_PROFILE"] = {
        text = "%s", button1 = ACCEPT, button2 = CANCEL,
        OnAccept = function(_, data) data() end,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }
    StaticPopup_Show("OFFHAND_CONFIRM_PROFILE", message, nil, callback)
end

local configFrame
local setupFrame
local seamGuideLine
local seamGuideRevision = 0
local currentTab = 1

-- ============================================================================
-- Topology Detection
-- ============================================================================
function Options:DetectTopology()
    local physW, physH
    if GetPhysicalScreenSize then
        pcall(function() physW, physH = GetPhysicalScreenSize() end)
    end

    if not physW or physW <= 0 then
        local resStr = (GetCVar and (GetCVar("gxWindowedResolution") or GetCVar("gxFullscreenResolution"))) or "0x0"
        local w, h = strsplit("x", resStr)
        physW = tonumber(w) or (GetScreenWidth and GetScreenWidth()) or 1920
        physH = tonumber(h) or (GetScreenHeight and GetScreenHeight()) or 1080
    end

    local ar = physW / math.max(physH, 1)

    local function Near(v, target, tol)
        return math.abs(v - target) <= (tol or 100)
    end

    local info = {
        physWidth = physW,
        physHeight = physH,
        aspectRatio = ar,
        isSpanned = false,
        recommendedPreset = "PORTRAIT_LEFT_LANDSCAPE_RIGHT",
        recommendedDeckRatio = 0.36,
        recommendedPosition = "RIGHT",
        recommendedAR = "16_9",
        description = "Single Display",
    }

    -- ------------------------------------------------------------------------
    -- 1. Specific High-Confidence Multi-Monitor Topologies
    -- ------------------------------------------------------------------------
    if Near(physW, 5360) and Near(physH, 1440) then
        -- 3440x1440 Ultrawide + 1920x1080 Landscape (5360x1440)
        info.isSpanned = true
        info.recommendedPreset = "LANDSCAPE_DUAL"
        info.recommendedDeckRatio = 0.358 -- 1920 / 5360 = ~35.8% (or 3440 / 5360 = 64.2% if primary left)
        info.recommendedPosition = "RIGHT"
        info.recommendedAR = "21_9"
        info.description = string.format("Ultrawide 21:9 (3440p) + 1080p Landscape")

    elseif Near(physW, 6000) and Near(physH, 1440) then
        -- 3440x1440 Ultrawide + 2560x1440 Landscape (6000x1440)
        info.isSpanned = true
        info.recommendedPreset = "LANDSCAPE_DUAL"
        info.recommendedDeckRatio = 0.427 -- 2560 / 6000 = ~42.7%
        info.recommendedPosition = "RIGHT"
        info.recommendedAR = "21_9"
        info.description = string.format("Ultrawide 21:9 (3440p) + 1440p Landscape")

    elseif Near(physW, 4480) and Near(physH, 1080) then
        -- 2560x1080 Ultrawide + 1920x1080 Landscape (4480x1080)
        info.isSpanned = true
        info.recommendedPreset = "LANDSCAPE_DUAL"
        info.recommendedDeckRatio = 0.429 -- 1920 / 4480 = ~42.9%
        info.recommendedPosition = "RIGHT"
        info.recommendedAR = "21_9"
        info.description = string.format("Ultrawide 21:9 (2560p) + 1080p Landscape")

    elseif Near(physW, 4480) and Near(physH, 1440) then
        -- 2560x1440 Landscape + 1920x1080 Landscape (4480x1440)
        info.isSpanned = true
        info.recommendedPreset = "LANDSCAPE_DUAL"
        info.recommendedDeckRatio = 0.429 -- 1920 / 4480 = ~42.9%
        info.recommendedPosition = "RIGHT"
        info.recommendedAR = "16_9"
        info.description = string.format("1440p Gaming + 1080p Landscape")

    elseif Near(physW, 6400) and Near(physH, 2160) then
        -- 3840x2160 (4K) + 2560x1440 (1440p) = 6400x2160
        info.isSpanned = true
        info.recommendedPreset = "LANDSCAPE_DUAL"
        info.recommendedDeckRatio = 0.400 -- 2560 / 6400
        info.recommendedPosition = "RIGHT"
        info.recommendedAR = "16_9"
        info.description = string.format("4K Gaming + 1440p Landscape")

    elseif Near(physW, 7680) and Near(physH, 2160) then
        -- Dual 4K (3840 + 3840 = 7680x2160)
        info.isSpanned = true
        info.recommendedPreset = "LANDSCAPE_DUAL"
        info.recommendedDeckRatio = 0.50
        info.recommendedPosition = "LEFT"
        info.recommendedAR = "16_9"
        info.description = string.format("Dual 4K Landscape (7680x2160)")

    elseif Near(physW, 5120) and Near(physH, 1440) then
        -- Dual 1440p (2560 + 2560 = 5120x1440) or Super-Ultrawide 32:9
        info.isSpanned = true
        info.recommendedPreset = "LANDSCAPE_DUAL"
        info.recommendedDeckRatio = 0.50
        info.recommendedPosition = "LEFT"
        info.recommendedAR = "16_9"
        info.description = string.format("Dual 1440p Landscape")

    elseif Near(physW, 3840) and Near(physH, 1080) then
        -- Dual 1080p (1920 + 1920 = 3840x1080)
        info.isSpanned = true
        info.recommendedPreset = "LANDSCAPE_DUAL"
        info.recommendedDeckRatio = 0.50
        info.recommendedPosition = "LEFT"
        info.recommendedAR = "16_9"
        info.description = string.format("Dual 1080p Landscape")

    elseif Near(physW, 4880) and Near(physH, 2560) then
        -- Portrait 1440p (1440x2560) + Ultrawide 3440x1440p (4880x2560)
        info.isSpanned = true
        info.recommendedPreset = "PORTRAIT_LEFT_LANDSCAPE_RIGHT"
        info.recommendedPosition = "RIGHT"
        info.recommendedDeckRatio = 0.295 -- 1440 / 4880
        info.recommendedAR = "21_9"
        info.description = string.format("Portrait 1440p + Ultrawide 21:9")

    elseif Near(physW, 4520) and Near(physH, 1920) then
        -- Portrait 1080p (1080x1920) + Ultrawide 3440x1440p (4520x1920)
        info.isSpanned = true
        info.recommendedPreset = "PORTRAIT_LEFT_LANDSCAPE_RIGHT"
        info.recommendedPosition = "RIGHT"
        info.recommendedDeckRatio = 0.239 -- 1080 / 4520
        info.recommendedAR = "21_9"
        info.description = string.format("Portrait 1080p + Ultrawide 21:9")

    elseif Near(physW, 4000) and Near(physH, 2560) then
        -- Portrait 1440p (1440x2560) + Landscape 1440p (2560x1440) = 4000x2560
        info.isSpanned = true
        info.recommendedPreset = "PORTRAIT_LEFT_LANDSCAPE_RIGHT"
        info.recommendedPosition = "RIGHT"
        info.recommendedDeckRatio = 0.360 -- 1440 / 4000
        info.recommendedAR = "16_9"
        info.description = string.format("Mixed Portrait (1440p) + Landscape (1440p)")

    elseif Near(physW, 3640) and Near(physH, 1920) then
        -- Portrait 1080p (1080x1920) + Landscape 1440p (2560x1440) = 3640x1920
        info.isSpanned = true
        info.recommendedPreset = "PORTRAIT_LEFT_LANDSCAPE_RIGHT"
        info.recommendedPosition = "RIGHT"
        info.recommendedDeckRatio = 0.297 -- 1080 / 3640
        info.recommendedAR = "16_9"
        info.description = string.format("Mixed Portrait (1080p) + Landscape (1440p)")

    elseif Near(physW, 3000) and Near(physH, 1920) then
        -- Portrait 1080p (1080x1920) + Landscape 1080p (1920x1080) = 3000x1920
        info.isSpanned = true
        info.recommendedPreset = "PORTRAIT_LEFT_LANDSCAPE_RIGHT"
        info.recommendedPosition = "RIGHT"
        info.recommendedDeckRatio = 0.360 -- 1080 / 3000
        info.recommendedAR = "16_9"
        info.description = string.format("Mixed Portrait (1080p) + Landscape (1080p)")

    -- ------------------------------------------------------------------------
    -- 2. Fallback Heuristics by Aspect Ratio & Geometry
    -- ------------------------------------------------------------------------
    elseif physH >= 1800 and physW >= 2800 and ar < 2.6 then
        -- General Mixed Portrait + Landscape
        info.isSpanned = true
        info.recommendedPreset = "PORTRAIT_LEFT_LANDSCAPE_RIGHT"
        info.recommendedPosition = "RIGHT"
        info.recommendedDeckRatio = 0.36
        info.recommendedAR = "16_9"
        info.description = string.format("Mixed Portrait + Landscape")

    elseif ar >= 3.0 then
        -- Generic dual landscape side-by-side
        info.isSpanned = true
        info.recommendedPreset = "LANDSCAPE_DUAL"
        info.recommendedDeckRatio = 0.50
        info.recommendedPosition = "LEFT"
        info.recommendedAR = "16_9"
        info.description = string.format("Dual Landscape Side-by-Side")

    elseif ar >= 2.0 then
        -- Ultrawide single display spanned
        info.isSpanned = true
        info.recommendedPreset = "PORTRAIT_LEFT_LANDSCAPE_RIGHT"
        info.recommendedDeckRatio = 0.36
        info.recommendedPosition = "RIGHT"
        info.recommendedAR = "21_9"
        info.description = string.format("Ultrawide Spanned")

    else
        info.isSpanned = false
        info.recommendedPreset = "PORTRAIT_LEFT_LANDSCAPE_RIGHT"
        info.recommendedDeckRatio = 0.36
        info.recommendedPosition = "RIGHT"
        info.recommendedAR = "16_9"
        info.description = string.format("Single Display")
    end

    return info
end

function Options:AutoConfigure(silent, fromWizard)
    local info = Options:DetectTopology()
    if not Offhand.db then return info end

    Offhand.db.enabled = true
    Offhand.db.layoutPreset = info.recommendedPreset
    Offhand.db.deckWidthRatio = info.recommendedDeckRatio
    Offhand.db.primaryPosition = info.recommendedPosition or "RIGHT"
    Offhand.db.aspectRatioMode = info.recommendedAR or "16_9"
    Offhand.db.hudScale = 0.70
    if not fromWizard then Offhand.db.firstRunComplete = true end

    if Offhand.ApplyFullLayout then
        Offhand:ApplyFullLayout()
    end

    if not silent then
        Options:ShowSeamGuide(info.recommendedDeckRatio)
        local previewRevision = seamGuideRevision
        if C_Timer and C_Timer.After then
            C_Timer.After(4.0, function()
                if seamGuideRevision == previewRevision then Options:HideSeamGuide() end
            end)
        end
        if Offhand.Print then
            Offhand:Print(L["MSG_AUTOCONFIG_APPLIED"], info.description)
            local presetLabel = L["PRESET_DUAL_LANDSCAPE"]
            if info.recommendedPreset == "PORTRAIT_LEFT_LANDSCAPE_RIGHT" then
                if info.recommendedPosition == "RIGHT" then
                    presetLabel = L["PRESET_PL_LR"]
                else
                    presetLabel = L["PRESET_GL_PR"]
                end
            end
            local arLabel = L["AR_" .. (info.recommendedAR or "16_9")] or (info.recommendedAR or "16:9")
            Offhand:Print(L["MSG_AUTOCONFIG_DETAILS"], presetLabel, info.recommendedDeckRatio * 100, arLabel)
        end
        if configFrame and configFrame.IsShown and configFrame:IsShown() then
            Options:RefreshPanel()
        end
    end
    return info
end

-- ============================================================================
-- Visual Seam Alignment Guide Line (Red Laser)
-- ============================================================================
function Options:ShowSeamGuide(deckRatio)
    if not UIParent then return end
    seamGuideRevision = seamGuideRevision + 1
    if not deckRatio then
        deckRatio = (Offhand.db and Offhand.db.deckWidthRatio) or 0.36
    end

    if not seamGuideLine then
        seamGuideLine = CreateFrame("Frame", "OffhandSeamGuideLine", UIParent)
        seamGuideLine:SetFrameStrata("TOOLTIP")
        seamGuideLine:SetWidth(4)

        local tex = seamGuideLine:CreateTexture(nil, "OVERLAY")
        tex:SetAllPoints()
        tex:SetColorTexture(1.0, 0.2, 0.2, 0.85)
        seamGuideLine.texture = tex

        local label = seamGuideLine:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("CENTER", seamGuideLine, "CENTER", 0, 0)
        label:SetText("<< BEZEL SEAM >>")
        label:SetTextColor(1, 1, 1, 1)
    end

    local screenW = UIParent:GetWidth() or 1920
    local screenH = UIParent:GetHeight() or 1080
    local x = screenW * deckRatio
    if Offhand.db and Offhand.db.primaryPosition == "LEFT" then
        x = screenW - x
    end

    seamGuideLine:ClearAllPoints()
    seamGuideLine:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x - 2, screenH)
    seamGuideLine:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x - 2, 0)
    seamGuideLine:Show()
end

function Options:HideSeamGuide()
    seamGuideRevision = seamGuideRevision + 1
    if seamGuideLine then
        seamGuideLine:Hide()
    end
end

function Options:IsSeamGuideShown()
    return (seamGuideLine and seamGuideLine.IsShown and seamGuideLine:IsShown()) or false
end

-- ============================================================================
-- Native Bulletproof UI Widget Builders
-- ============================================================================
local function CreateNativeCheckbox(parent, text, getVal, setVal, tooltipTitle, tooltipText)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetSize(22, 22)

    local label = check:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("LEFT", check, "RIGHT", 8, 1)
    label:SetText(text)
    label:SetWidth(600)
    label:SetJustifyH("LEFT")
    check.Text = label

    -- Keep the native 22px check art; extend only the label's click target.
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

local function CreateNativeRadioButton(parent, text, getVal, setVal, tooltipTitle, tooltipText)
    local radio = CreateFrame("CheckButton", nil, parent, "UIRadioButtonTemplate")
    radio:SetSize(18, 18)

    local label = radio:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("LEFT", radio, "RIGHT", 6, 1)
    label:SetText(text)
    radio.Text = label

    radio:SetChecked(getVal())
    radio:SetScript("OnClick", function(self)
        setVal()
        Options:RefreshPanel()
    end)
    if (tooltipTitle or tooltipText) and Offhand.SetTooltip then
        Offhand:SetTooltip(radio, tooltipTitle, tooltipText)
    end
    return radio
end

local registeredSliders = {}

local function ParseSliderInput(inputStr, minVal, maxVal, step, formatStr)
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
        return ParseSliderInput(...)
    else
        return ParseSliderInput(self, ...)
    end
end

local function CreateNativeSlider(parent, text, minVal, maxVal, step, getVal, setVal, formatStr, tooltipTitle, tooltipText)
    local slider = CreateFrame("Slider", nil, parent, "BackdropTemplate")
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
    local editBox = CreateFrame("EditBox", nil, slider, "BackdropTemplate")
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

    local function ApplyLayoutCleanly(s)
        if s._pendingApply then
            s._pendingApply = false
            s:SetScript("OnUpdate", nil)
            Offhand:ApplyFullLayout()
        end
    end

    slider.SetValueDirect = function(self, val)
        self._isDirect = true
        self:SetValue(val)
        self._isDirect = nil
    end

    local function CommitEditBox()
        local txt = editBox:GetText()
        local parsed = ParseSliderInput(txt, minVal, maxVal, step, formatStr)
        if parsed then
            slider:SetValueDirect(parsed)
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
    -- GetCursorPosition() returns raw screen pixels â€” scale-independent.
    -- The same physical mouse movement always produces the same value change
    -- regardless of UIParent:SetScale(), fixing the runaway sensitivity on the
    -- Global UI Scale slider (which modifies the parent frame's own scale).
    local DRAG_PIXELS = 300  -- physical pixels of travel for full value range

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
    end
    slider:UpdateTheme()

    if (tooltipTitle or tooltipText) and Offhand.SetTooltip then
        Offhand:SetTooltip(slider, tooltipTitle, tooltipText)
    end

    tinsert(registeredSliders, slider)
    return slider
end

-- Shared bottom control tested by regression tests
function Options:CreateBottomControl(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(280, 46)
    local label = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", 0, 0)
    label:SetText(L["LABEL_BOTTOM_OFFSET_SHORT"])
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
    for _, item in ipairs({{"-1 px", -1}, {"+1 px", 1}, {"Apply", 0}}) do
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

function Options:GetConfigFrame()
    return configFrame
end

-- ============================================================================
-- Unified Clean Tabbed Dashboard
-- ============================================================================
function Options:CreateFloatingPanel()
    if configFrame then return configFrame end

    configFrame = CreateFrame("Frame", "OffhandFloatingConfigFrame", UIParent, "BackdropTemplate")
    configFrame:SetSize(720, 732)
    configFrame:SetFrameStrata("DIALOG")
    configFrame:EnableMouse(true)
    configFrame:SetMovable(true)
    configFrame:SetClampedToScreen(true)
    configFrame:RegisterForDrag("LeftButton")
    configFrame:SetScript("OnDragStart", configFrame.StartMoving)
    configFrame:SetScript("OnDragStop", configFrame.StopMovingOrSizing)

    if tinsert and UISpecialFrames then
        tinsert(UISpecialFrames, "OffhandFloatingConfigFrame")
    end

    Offhand.Themes:ApplyBackdrop(configFrame, (Offhand.db and Offhand.db.theme) or "CLASSIC", 0.98)
    
    -- Focused! Style Header
    local header = Offhand.Themes:CreateBayHeader(configFrame, "", 68)
    configFrame.header = header
    
    if header.icon and header.icon.Hide then
        header.icon:Hide()
    end
    
    if header.title then
        if header.title.Hide then header.title:Hide() else header.title:SetText("") end
    end

    local logo = header.CreateTexture and header:CreateTexture(nil, "ARTWORK")
    if logo and logo.SetSize and logo.SetPoint and logo.SetTexture then
        logo:SetSize(48, 48)
        logo:SetPoint("LEFT", header, "LEFT", 16, 0)
        logo:SetTexture("Interface\\AddOns\\Offhand\\Media\\OffhandLogo64x64.blp")
        header.logo = logo
    end

    local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    if header.logo and header.logo.SetPoint then
        title:SetPoint("TOPLEFT", header.logo, "TOPRIGHT", 14, -4)
    else
        title:SetPoint("TOPLEFT", header, "TOPLEFT", 76, -18)
    end
    title:SetText("|cffffcc00Offhand|r")
    
    local version = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    version:SetPoint("BOTTOMLEFT", title, "BOTTOMRIGHT", 8, 2)
    local verNum = (GetAddOnMetadata and GetAddOnMetadata("Offhand", "Version")) or "1.0.0"
    version:SetText("|cffaaaaaaVersion " .. verNum .. "|r")
    
    local desc = header:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    desc:SetText("Dual Monitor Offhand Monitor and Seamless Display Topology Manager")
    
    local closeBtn = CreateFrame("Button", nil, configFrame.header, "UIPanelCloseButton")
    closeBtn:SetSize(28, 28)
    closeBtn:SetPoint("RIGHT", configFrame.header, "RIGHT", -10, 0)
    closeBtn:SetScript("OnClick", function()
        Options:Close()
    end)

    configFrame:SetScript("OnHide", function()
        Options:HideSeamGuide()
    end)

    -- Divider Line Below Tabs
    local divider = configFrame:CreateTexture(nil, "ARTWORK")
    if divider.SetHeight then divider:SetHeight(1) end
    if divider.SetPoint then
        divider:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 4, -36)
        divider:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", -4, -36)
    end
    if divider.SetColorTexture then divider:SetColorTexture(1, 1, 1, 0.15) end
    configFrame.divider = divider

    -- Auto-Setup Wizard Button
    local autoWizardBtn = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
    autoWizardBtn:SetSize(155, 22)
    autoWizardBtn:SetPoint("TOPRIGHT", -18, -126)
    autoWizardBtn:SetText(L["BTN_AUTO_WIZARD"])
    autoWizardBtn:SetScript("OnClick", function()
        if Offhand.Wizard and Offhand.Wizard.Open then
            Offhand.Wizard.openedFromOptions = true
            configFrame:Hide()
            Offhand.Wizard:Open()
        end
    end)

    local compAppBtn = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
    compAppBtn:SetSize(155, 22)
    compAppBtn:SetPoint("RIGHT", autoWizardBtn, "LEFT", -10, 0)
    compAppBtn:SetText("Get Companion App")
    compAppBtn:SetScript("OnClick", function()
        StaticPopup_Show("OFFHAND_DOWNLOAD_LINK")
    end)

    if Offhand.SetTooltip then
        Offhand:SetTooltip(autoWizardBtn, L["BTN_AUTO_WIZARD_TIP_TITLE"], L["BTN_AUTO_WIZARD_TIP_DESC"])
    end
    configFrame.autoWizardBtn = autoWizardBtn

    -- Status & Topology Detection Banner
    local banner = configFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    banner:SetPoint("TOPLEFT", 18, -130)
    banner:SetPoint("TOPRIGHT", autoWizardBtn, "TOPLEFT", -8, 0)
    banner:SetJustifyH("LEFT")
    configFrame.banner = banner

    -- Data-Driven Tab Buttons will be created after Tab Content Containers

    -- Master ScrollFrame for all Tab Content
    local optionsScrollFrame = CreateFrame("ScrollFrame", "OffhandOptionsScrollFrame", configFrame, "UIPanelScrollFrameTemplate")
    optionsScrollFrame:SetPoint("TOPLEFT", 16, -156)
    optionsScrollFrame:SetPoint("BOTTOMRIGHT", -42, 52)
    configFrame.scrollFrame = optionsScrollFrame

    local optionsScrollChild = CreateFrame("Frame", nil, optionsScrollFrame)
    optionsScrollChild:SetSize(662, 10)
    optionsScrollFrame:SetScrollChild(optionsScrollChild)
    configFrame.scrollChild = optionsScrollChild

    -- Tab Content Containers (Anchored to ScrollChild)
    local tab1 = CreateFrame("Frame", nil, optionsScrollChild)
    tab1:SetPoint("TOPLEFT", 0, 0)
    tab1:SetPoint("TOPRIGHT", 0, 0)
    tab1:SetHeight(1)
    configFrame.tab1 = tab1

    local tab2 = CreateFrame("Frame", nil, optionsScrollChild)
    tab2:SetPoint("TOPLEFT", 0, 0)
    tab2:SetPoint("TOPRIGHT", 0, 0)
    tab2:SetHeight(1)
    configFrame.tab2 = tab2

    local tab3 = CreateFrame("Frame", nil, optionsScrollChild)
    tab3:SetPoint("TOPLEFT", 0, 0)
    tab3:SetPoint("TOPRIGHT", 0, 0)
    tab3:SetHeight(1)
    configFrame.tab3 = tab3
    
    local tab4 = CreateFrame("Frame", nil, optionsScrollChild)
    tab4:SetPoint("TOPLEFT", 0, 0)
    tab4:SetPoint("TOPRIGHT", 0, 0)
    tab4:SetHeight(1)
    configFrame.tab4 = tab4

    local tab5 = CreateFrame("Frame", nil, optionsScrollChild)
    tab5:SetPoint("TOPLEFT", 0, 0)
    tab5:SetPoint("TOPRIGHT", 0, 0)
    tab5:SetHeight(1)
    configFrame.tab5 = tab5

    local registeredCards = {}

    local function CreateCard(parent, titleText, height)
        local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        card:SetSize(662, height)
        card:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)

        card:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        card:SetBackdropColor(1.0, 1.0, 1.0, 0.85)
        card:SetBackdropBorderColor(0.55, 0.50, 0.35, 0.85)

        local title = card:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        title:SetPoint("TOPLEFT", card, "TOPLEFT", 12, -8)
        title:SetText(titleText)
        card.title = title

        tinsert(registeredCards, card)
        return card
    end

    function Options:UpdateCardThemes()
        local trimKey = (Offhand.db and Offhand.db.trimColor) or "GOLD"
        local themeKey = (Offhand.db and Offhand.db.theme) or "CLASSIC"
        local c
        if trimKey == "CUSTOM" and Offhand.db and Offhand.db.customTrimColor then
            c = Offhand.db.customTrimColor
        else
            local pals = Offhand.Themes and Offhand.Themes.GetColorPalettes and Offhand.Themes:GetColorPalettes()
            c = pals and pals[trimKey]
        end
        local br = c and { c.r * 0.75, c.g * 0.75, c.b * 0.75, 0.85 } or { 0.55, 0.50, 0.35, 0.85 }
        local textR, textG, textB = (c and c.r) or 1.0, (c and c.g) or 0.82, (c and c.b) or 0.0

        for _, card in ipairs(registeredCards) do
            if themeKey == "CLASSIC" then
                card:SetBackdropColor(1.0, 1.0, 1.0, 1.0)
                if trimKey == "GOLD" then
                    card:SetBackdropBorderColor(0.55, 0.50, 0.35, 0.85)
                else
                    card:SetBackdropBorderColor(br[1], br[2], br[3], br[4])
                end
            else
                card:SetBackdropColor(0.04, 0.04, 0.05, 1.0)
                card:SetBackdropBorderColor(br[1], br[2], br[3], br[4])
            end
            if card.title then
                card.title:SetTextColor(textR, textG, textB, 1.0)
            end
        end

        for _, slider in ipairs(registeredSliders) do
            if slider.UpdateTheme then
                slider:UpdateTheme(trimKey)
            end
        end

        if Options.UpdateTrimHighlights then
            Options:UpdateTrimHighlights()
        end
        if Options.UpdateCanvasHighlights then
            Options:UpdateCanvasHighlights()
        end
    end

    local tabConfig = {
        { id = 1, frame = tab1, label = "Display" },
        { id = 2, frame = tab2, label = "Offhand Monitor" },
        { id = 3, frame = tab3, label = "Themes" },
        { id = 4, frame = tab4, label = L["TAB_PROFILES"] },
        { id = 5, frame = tab5, label = "FAQ & Help" }
    }
    
    local tabButtons = {}
    configFrame.cards = registeredCards

    local function SwitchTab(tabIndex)
        currentTab = tabIndex
        local normalColor = {0.8, 0.8, 0.8}
        local activeColor = {1.0, 0.82, 0.0}

        for i, t in ipairs(tabConfig) do
            local isActive = (tabIndex == t.id)
            t.frame:SetShown(isActive)
            
            local c = isActive and activeColor or normalColor
            local btn = tabButtons[i]
            if btn then
                local fs = btn.GetFontString and btn:GetFontString()
                if fs then fs:SetTextColor(c[1], c[2], c[3]) end
            end
            
            if isActive then
                optionsScrollChild:SetHeight(t.frame:GetHeight())
            end
        end

        optionsScrollFrame:SetVerticalScroll(0)

        if Options.UpdateTrimHighlights then
            Options:UpdateTrimHighlights()
        end
        if Options.UpdateCanvasHighlights then
            Options:UpdateCanvasHighlights()
        end
    end

    -- Dynamically generate the tab buttons
    local btnGap = 12
    local totalAvailableWidth = 684
    local btnWidth = (totalAvailableWidth - (btnGap * (#tabConfig - 1))) / #tabConfig
    local startX = (configFrame:GetWidth() - totalAvailableWidth) / 2

    for i, t in ipairs(tabConfig) do
        local btn = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
        btn:SetSize(btnWidth, 26)
        if i == 1 then
            btn:SetPoint("TOPLEFT", startX, -84)
        else
            btn:SetPoint("LEFT", tabButtons[i - 1], "RIGHT", btnGap, 0)
        end
        btn:SetText(t.label)
        btn:SetScript("OnClick", function() SwitchTab(t.id) end)
        table.insert(tabButtons, btn)
    end

    -- ========================================================================
    -- TAB 1: DISPLAY & VIEWPORT CALIBRATION
    -- ========================================================================
    local card1_1 = CreateCard(tab1, "Display Mode & Dual Monitor Orientation", 130)

    local enableCheck = CreateNativeCheckbox(card1_1, "Enable Offhand Dual Monitor Mode",
        function() return Offhand.db and Offhand.db.enabled end,
        function(val) Offhand.db.enabled = val end,
        L["CHECK_CANVAS_ENABLED_TIP_TITLE"], L["CHECK_CANVAS_ENABLED_TIP_DESC"]
    )
    enableCheck:SetPoint("TOPLEFT", 12, -26)
    configFrame.enableCheck = enableCheck
    local minimapCheck = CreateNativeCheckbox(card1_1, "Show Minimap Icon",
        function() return Offhand.db and Offhand.db.showMinimapIcon end,
        function(val) 
            Offhand.db.showMinimapIcon = val 
            if Offhand.UpdateMinimapIcon then Offhand:UpdateMinimapIcon() end
        end,
        "Minimap Icon", "Toggle the Offhand icon on the minimap ring."
    )
    minimapCheck:SetPoint("TOPLEFT", 12, -96)
    minimapCheck.Text:SetWidth(180)


    local laserCheck = CreateNativeCheckbox(card1_1, "Show Red Seam Guide Laser",
        function() return (seamGuideLine and seamGuideLine:IsShown()) or false end,
        function(val)
            if val then
                Options:ShowSeamGuide(Offhand.db and Offhand.db.deckWidthRatio)
            else
                Options:HideSeamGuide()
            end
        end,
        L["BTN_LASER_TOGGLE_TIP_TITLE"], L["BTN_LASER_TOGGLE_TIP_DESC"]
    )
    laserCheck:SetPoint("TOPLEFT", 240, -96)
    laserCheck.Text:SetWidth(360)
    configFrame.laserCheck = laserCheck

    local rPortraitLeft = CreateNativeRadioButton(card1_1, "Portrait (Left) + Game (Right)",
        function() return (Offhand.db and Offhand.db.layoutPreset == "PORTRAIT_LEFT_LANDSCAPE_RIGHT" and Offhand.db.primaryPosition == "RIGHT") end,
        function()
            Offhand.db.layoutPreset = "PORTRAIT_LEFT_LANDSCAPE_RIGHT"
            Offhand.db.primaryPosition = "RIGHT"
        end,
        L["PRESET_PL_LR_TIP_TITLE"], L["PRESET_PL_LR_TIP_DESC"]
    )
    rPortraitLeft:SetPoint("TOPLEFT", 12, -50)

    local rPortraitRight = CreateNativeRadioButton(card1_1, "Game (Left) + Portrait (Right)",
        function() return (Offhand.db and Offhand.db.layoutPreset == "PORTRAIT_LEFT_LANDSCAPE_RIGHT" and Offhand.db.primaryPosition == "LEFT") end,
        function()
            Offhand.db.layoutPreset = "PORTRAIT_LEFT_LANDSCAPE_RIGHT"
            Offhand.db.primaryPosition = "LEFT"
        end,
        L["PRESET_GL_PR_TIP_TITLE"], L["PRESET_GL_PR_TIP_DESC"]
    )
    rPortraitRight:SetPoint("TOPLEFT", 360, -50)

    local rDual = CreateNativeRadioButton(card1_1, "Dual Landscape Side-by-Side (50/50)",
        function() return (Offhand.db and Offhand.db.layoutPreset == "LANDSCAPE_DUAL") end,
        function()
            Offhand.db.layoutPreset = "LANDSCAPE_DUAL"
            Offhand.db.primaryPosition = "LEFT"
            Offhand.db.deckWidthRatio = 0.50
        end,
        L["PRESET_DUAL_LANDSCAPE_TIP_TITLE"], L["PRESET_DUAL_LANDSCAPE_TIP_DESC"]
    )
    rDual:SetPoint("TOPLEFT", 12, -74)

    local autoDetectBtn = CreateFrame("Button", nil, card1_1, "UIPanelButtonTemplate")
    autoDetectBtn:SetSize(200, 22)
    autoDetectBtn:SetPoint("TOPLEFT", 360, -74)
    autoDetectBtn:SetText("1-Click Auto-Configure")
    autoDetectBtn:SetScript("OnClick", function()
        Options:AutoConfigure()
    end)
    if Offhand.SetTooltip then
        Offhand:SetTooltip(autoDetectBtn, L["BTN_1CLICK_AUTOCONFIG_TIP_TITLE"], L["BTN_1CLICK_AUTOCONFIG_TIP_DESC"])
    end
    card1_1.autoDetectBtn = autoDetectBtn


    local card1_2 = CreateCard(tab1, "Mainhand Monitor Geometry & Bezel Seam", 120)

    local r169 = CreateNativeRadioButton(card1_2, "16:9 Standard",
        function() return (Offhand.db and Offhand.db.aspectRatioMode == "16_9") end,
        function() Offhand.db.aspectRatioMode = "16_9" end,
        L["AR_16_9_TIP_TITLE"], L["AR_16_9_TIP_DESC"]
    )
    r169:SetPoint("TOPLEFT", 12, -26)

    local r219 = CreateNativeRadioButton(card1_2, "21:9 Ultrawide",
        function() return (Offhand.db and Offhand.db.aspectRatioMode == "21_9") end,
        function() Offhand.db.aspectRatioMode = "21_9" end,
        L["AR_21_9_TIP_TITLE"], L["AR_21_9_TIP_DESC"]
    )
    r219:SetPoint("TOPLEFT", 200, -26)

    local rFill = CreateNativeRadioButton(card1_2, "Fit Window Height (Fill)",
        function() return (Offhand.db and Offhand.db.aspectRatioMode == "FILL") end,
        function() Offhand.db.aspectRatioMode = "FILL" end,
        L["AR_FILL_TIP_TITLE"], L["AR_FILL_TIP_DESC"]
    )
    rFill:SetPoint("TOPLEFT", 380, -26)

    local seamSlider = CreateNativeSlider(card1_2, L["SLIDER_SEAM_WIDTH"], 0.15, 0.80, 0.005,
        function() return (Offhand.db and Offhand.db.deckWidthRatio) or 0.36 end,
        function(val)
            Offhand.db.deckWidthRatio = val
            Options:ShowSeamGuide(val)
            laserCheck:SetChecked(true)
        end,
        "%.1f%%",
        L["SLIDER_SEAM_WIDTH_TIP_TITLE"], L["SLIDER_SEAM_WIDTH_TIP_DESC"]
    )
    seamSlider:SetPoint("TOPLEFT", 12, -74)
    seamSlider:SetWidth(350)

    local p36Btn = CreateFrame("Button", nil, card1_2, "UIPanelButtonTemplate")
    p36Btn:SetSize(66, 22)
    p36Btn:SetPoint("LEFT", seamSlider, "RIGHT", 16, -6)
    p36Btn:SetText("36%")
    p36Btn:SetScript("OnClick", function() seamSlider:SetValue(0.36) end)
    if Offhand.SetTooltip then Offhand:SetTooltip(p36Btn, L["WIZARD_PRESET_SEAM_36_TIP_TITLE"], L["WIZARD_PRESET_SEAM_36_TIP_DESC"]) end

    local p50Btn = CreateFrame("Button", nil, card1_2, "UIPanelButtonTemplate")
    p50Btn:SetSize(66, 22)
    p50Btn:SetPoint("LEFT", p36Btn, "RIGHT", 6, 0)
    p50Btn:SetText("50%")
    p50Btn:SetScript("OnClick", function() seamSlider:SetValue(0.50) end)
    if Offhand.SetTooltip then Offhand:SetTooltip(p50Btn, L["WIZARD_PRESET_SEAM_50_TIP_TITLE"], L["WIZARD_PRESET_SEAM_50_TIP_DESC"]) end

    local p55Btn = CreateFrame("Button", nil, card1_2, "UIPanelButtonTemplate")
    p55Btn:SetSize(66, 22)
    p55Btn:SetPoint("LEFT", p50Btn, "RIGHT", 6, 0)
    p55Btn:SetText("55%")
    p55Btn:SetScript("OnClick", function() seamSlider:SetValue(0.55) end)
    if Offhand.SetTooltip then Offhand:SetTooltip(p55Btn, L["WIZARD_PRESET_SEAM_55_TIP_TITLE"], L["WIZARD_PRESET_SEAM_55_TIP_DESC"]) end


    local card1_3 = CreateCard(tab1, L["CARD_SCALE_ALIGNMENT"], 156)

    local bottomControl = Options:CreateBottomControl(card1_3)
    bottomControl:SetPoint("TOPLEFT", 12, -26)

    local hudSlider = CreateNativeSlider(card1_3, "Global UI Size (% of Mainhand Monitor)", 0.25, 1.25, 0.01,
        function() return (Offhand.db and Offhand.db.hudScale) or 0.70 end,
        function(val) Offhand.db.hudScale = val end,
        "%.0f%%",
        L["SLIDER_HUD_SCALE_TIP_TITLE"], L["SLIDER_HUD_SCALE_TIP_DESC"]
    )
    hudSlider:SetPoint("TOPLEFT", 336, -46)
    hudSlider:SetWidth(200)

    local p56Btn = CreateFrame("Button", nil, card1_3, "UIPanelButtonTemplate")
    p56Btn:SetSize(56, 22)
    p56Btn:SetPoint("TOPLEFT", 336, -82)
    p56Btn:SetText("56%")
    p56Btn:SetScript("OnClick", function() hudSlider:SetValueDirect(0.56) end)
    if Offhand.SetTooltip then Offhand:SetTooltip(p56Btn, L["WIZARD_PRESET_SCALE_56_TIP_TITLE"], L["WIZARD_PRESET_SCALE_56_TIP_DESC"]) end

    local p65Btn = CreateFrame("Button", nil, card1_3, "UIPanelButtonTemplate")
    p65Btn:SetSize(56, 22)
    p65Btn:SetPoint("LEFT", p56Btn, "RIGHT", 5, 0)
    p65Btn:SetText("65%")
    p65Btn:SetScript("OnClick", function() hudSlider:SetValueDirect(0.65) end)
    if Offhand.SetTooltip then Offhand:SetTooltip(p65Btn, L["WIZARD_PRESET_SCALE_65_TIP_TITLE"], L["WIZARD_PRESET_SCALE_65_TIP_DESC"]) end

    local p70Btn = CreateFrame("Button", nil, card1_3, "UIPanelButtonTemplate")
    p70Btn:SetSize(56, 22)
    p70Btn:SetPoint("LEFT", p65Btn, "RIGHT", 5, 0)
    p70Btn:SetText("70%")
    p70Btn:SetScript("OnClick", function() hudSlider:SetValueDirect(0.70) end)
    if Offhand.SetTooltip then Offhand:SetTooltip(p70Btn, L["WIZARD_PRESET_SCALE_70_TIP_TITLE"], L["WIZARD_PRESET_SCALE_70_TIP_DESC"]) end

    local p85Btn = CreateFrame("Button", nil, card1_3, "UIPanelButtonTemplate")
    p85Btn:SetSize(56, 22)
    p85Btn:SetPoint("LEFT", p70Btn, "RIGHT", 5, 0)
    p85Btn:SetText("85%")
    p85Btn:SetScript("OnClick", function() hudSlider:SetValueDirect(0.85) end)
    if Offhand.SetTooltip then Offhand:SetTooltip(p85Btn, L["WIZARD_PRESET_SCALE_85_TIP_TITLE"], L["WIZARD_PRESET_SCALE_85_TIP_DESC"]) end

    local p100Btn = CreateFrame("Button", nil, card1_3, "UIPanelButtonTemplate")
    p100Btn:SetSize(56, 22)
    p100Btn:SetPoint("LEFT", p85Btn, "RIGHT", 5, 0)
    p100Btn:SetText("100%")
    p100Btn:SetScript("OnClick", function() hudSlider:SetValueDirect(1.00) end)
    if Offhand.SetTooltip then Offhand:SetTooltip(p100Btn, L["WIZARD_PRESET_SCALE_100_TIP_TITLE"], L["WIZARD_PRESET_SCALE_100_TIP_DESC"]) end

    local hudNote = card1_3:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    hudNote:SetPoint("TOPLEFT", 336, -112)
    hudNote:SetPoint("TOPRIGHT", -12, -112)
    hudNote:SetJustifyH("LEFT")
    hudNote:SetText(L["GLOBAL_SCALE_HELP"])

    local card1_4 = CreateCard(tab1, "OBS Streamer Capture Setup", 110)
    
    local obsDesc = card1_4:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    obsDesc:SetPoint("TOPLEFT", 16, -26)
    obsDesc:SetPoint("TOPRIGHT", -16, -26)
    obsDesc:SetJustifyH("LEFT")
    obsDesc:SetText("|cffaaaaaaTo hide the bezel gap on stream, create two Game Capture sources in OBS. Add a 'Crop/Pad' filter to both and enter these exact pixel values, then snap them together.|r")
    
    local obsSource1 = card1_4:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    obsSource1:SetPoint("TOPLEFT", 16, -60)
    obsSource1:SetJustifyH("LEFT")
    
    local obsSource2 = card1_4:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    obsSource2:SetPoint("TOPLEFT", 16, -80)
    obsSource2:SetJustifyH("LEFT")
    
    function Options:UpdateOBSCard()
        local m = Offhand.Viewport and Offhand.Viewport.GetMetrics and Offhand.Viewport:GetMetrics()
        if not m then return end
        
        local pw = m.physicalWidth or 0
        local gameCropL = math.floor(m.gamePixelLeft + 0.5)
        local gameCropR = math.floor(pw - (m.gamePixelLeft + m.gamePixelWidth) + 0.5)
        
        local db = Offhand.db
        local deckRatio = tonumber(db.deckWidthRatio) or (m.preset == "LANDSCAPE_DUAL" and 0.5 or 0.36)
        local deck = math.floor(pw * deckRatio + 0.5)
        local bezel = math.floor((tonumber(db.bezelGap) or 0) + 0.5)
        
        local deckCropL, deckCropR = 0, 0
        if m.gamePixelLeft > 0 then
            -- Game is on Right, Deck is on Left
            deckCropL = 0
            deckCropR = math.floor(pw - deck + 0.5)
        else
            -- Game is on Left, Deck is on Right
            deckCropL = math.floor(m.gamePixelWidth + bezel + 0.5)
            deckCropR = 0
        end
        
        obsSource1:SetText(string.format("Source 1 (Main Game) Crop:  Left: |cffffffff%d|r   Right: |cffffffff%d|r", gameCropL, gameCropR))
        obsSource2:SetText(string.format("Source 2 (Offhand Canvas) Crop:  Left: |cffffffff%d|r   Right: |cffffffff%d|r", deckCropL, deckCropR))
    end

    -- ========================================================================
    -- TAB 2: WORKSPACE & WORLD MAP
    -- ========================================================================
    local card2_1 = CreateCard(tab2, "World Map Scaling & Navigation", 150)

    local mapScaleSlider = CreateNativeSlider(card2_1, "Map Scale (% of Native)", 0.50, 2.50, 0.05,
        function()
            local s = Offhand.db and Offhand.db.workspaceMapScale
            if s == "AUTO" then
                local m = Offhand.Viewport and Offhand.Viewport:GetMetrics()
                local baseWidth = (WorldMapFrame and WorldMapFrame:GetWidth()) or 610
                if baseWidth <= 0 then baseWidth = 610 end
                local availableWidth = (m and m.deckWidth and (m.deckWidth - 24)) or 610
                return math.max(0.50, math.min(2.50, math.floor((availableWidth / baseWidth) * 100 + 0.5) / 100))
            end
            return (tonumber(s) and tonumber(s)) or 1.00
        end,
        function(val)
            Offhand.db.workspaceMapScale = val
            if Offhand.Canvas and Offhand.Canvas.ConfigureWorldMap then
                Offhand.Canvas:ConfigureWorldMap()
            end
        end,
        "%.0f%%",
        L["SLIDER_MINIMAP_SCALE_TIP_TITLE"], "Adjusts the scale of the World Map on your Offhand Monitor canvas."
    )
    mapScaleSlider:SetPoint("TOPLEFT", 12, -54)
    mapScaleSlider:SetWidth(290)

    local autoFitBtn = CreateFrame("Button", nil, card2_1, "UIPanelButtonTemplate")
    autoFitBtn:SetSize(72, 22)
    autoFitBtn:SetPoint("LEFT", mapScaleSlider, "RIGHT", 12, -6)
    autoFitBtn:SetText("Auto-Fit")
    autoFitBtn:SetScript("OnClick", function()
        Offhand.db.workspaceMapScale = "AUTO"
        if Offhand.Canvas and Offhand.Canvas.ConfigureWorldMap then
            Offhand.Canvas:ConfigureWorldMap()
        end
        local m = Offhand.Viewport and Offhand.Viewport:GetMetrics()
        local baseWidth = (WorldMapFrame and WorldMapFrame:GetWidth()) or 610
        if baseWidth <= 0 then baseWidth = 610 end
        local availableWidth = (m and m.deckWidth and (m.deckWidth - 24)) or 610
        local computedScale = math.max(0.50, math.min(2.50, math.floor((availableWidth / baseWidth) * 100 + 0.5) / 100))
        mapScaleSlider:SetValue(computedScale)
    end)
    if Offhand.SetTooltip then Offhand:SetTooltip(autoFitBtn, L["BTN_MAP_AUTOFIT_TIP_TITLE"], L["BTN_MAP_AUTOFIT_TIP_DESC"]) end

    local p100Btn = CreateFrame("Button", nil, card2_1, "UIPanelButtonTemplate")
    p100Btn:SetSize(48, 22)
    p100Btn:SetPoint("LEFT", autoFitBtn, "RIGHT", 5, 0)
    p100Btn:SetText("100%")
    p100Btn:SetScript("OnClick", function() mapScaleSlider:SetValue(1.00) end)
    if Offhand.SetTooltip then Offhand:SetTooltip(p100Btn, L["BTN_MAP_100_TIP_TITLE"], L["BTN_MAP_100_TIP_DESC"]) end

    local p150Btn = CreateFrame("Button", nil, card2_1, "UIPanelButtonTemplate")
    p150Btn:SetSize(48, 22)
    p150Btn:SetPoint("LEFT", p100Btn, "RIGHT", 5, 0)
    p150Btn:SetText("150%")
    p150Btn:SetScript("OnClick", function() mapScaleSlider:SetValue(1.50) end)
    if Offhand.SetTooltip then Offhand:SetTooltip(p150Btn, L["BTN_MAP_150_TIP_TITLE"], L["BTN_MAP_150_TIP_DESC"]) end

    local p200Btn = CreateFrame("Button", nil, card2_1, "UIPanelButtonTemplate")
    p200Btn:SetSize(48, 22)
    p200Btn:SetPoint("LEFT", p150Btn, "RIGHT", 5, 0)
    p200Btn:SetText("200%")
    p200Btn:SetScript("OnClick", function() mapScaleSlider:SetValue(2.00) end)
    if Offhand.SetTooltip then Offhand:SetTooltip(p200Btn, L["BTN_MAP_200_TIP_TITLE"], L["BTN_MAP_200_TIP_DESC"]) end

    local p250Btn = CreateFrame("Button", nil, card2_1, "UIPanelButtonTemplate")
    p250Btn:SetSize(48, 22)
    p250Btn:SetPoint("LEFT", p200Btn, "RIGHT", 5, 0)
    p250Btn:SetText("250%")
    p250Btn:SetScript("OnClick", function() mapScaleSlider:SetValue(2.50) end)
    if Offhand.SetTooltip then Offhand:SetTooltip(p250Btn, L["BTN_MAP_250_TIP_TITLE"], L["BTN_MAP_250_TIP_DESC"]) end

    local mapTip = card2_1:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    mapTip:SetPoint("TOPLEFT", 12, -88)
    mapTip:SetText("|cffffd100Map Zoom Tip:|r Hold |cffffffffCtrl + Mousewheel|r over the World Map to scale it in real-time!")

    local mapMoveCheck = CreateNativeCheckbox(card2_1, "Keep World Map open while running / walking",
        function() return Offhand.db and Offhand.db.preventMapCloseOnMove end,
        function(val)
            Offhand.db.preventMapCloseOnMove = val
            if Offhand.Canvas and Offhand.Canvas.UpdateMapMovementBehavior then
                Offhand.Canvas:UpdateMapMovementBehavior()
            end
        end,
        "Persistent Map Movement", "Prevents the World Map from closing automatically when your character moves."
    )
    mapMoveCheck:SetPoint("TOPLEFT", 10, -112)

    local mapDesc = card2_1:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    mapDesc:SetPoint("TOPLEFT", 32, -134)
    local hasLMap = C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Leatrix_Maps") or (IsAddOnLoaded and IsAddOnLoaded("Leatrix_Maps"))
    if hasLMap then
        mapDesc:SetText("|cff00ff00Leatrix Maps detected:|r Compatible with Leatrix.")
    else
        mapDesc:SetText("|cff888888Allows navigating with map open. (Compatible with Leatrix)|r")
    end


    local card2_2 = CreateCard(tab2, L["CARD_PERSISTENCE"], 220)
    local recoveryCard = CreateCard(tab2, L["CARD_RECOVERY"], 118)

        local gatherBtn = CreateFrame("Button", nil, recoveryCard, "UIPanelButtonTemplate")
    gatherBtn:SetSize(160, 26)
    gatherBtn:SetPoint("TOPLEFT", 12, -30)
    gatherBtn:SetText(L["GATHER_UI"])
    gatherBtn:SetScript("OnClick", function() if Offhand.GatherOffScreenUI then Offhand:GatherOffScreenUI() end end)

    local proTipDesc = card2_2:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    proTipDesc:SetPoint("TOPLEFT", 10, -26)
    proTipDesc:SetPoint("TOPRIGHT", -10, -26)
    proTipDesc:SetJustifyH("LEFT")
    proTipDesc:SetText("|cffffd100Pro Tip:|r You can click and drag the header of standard Blizzard windows (Character, Spellbook, Quest Log, Bags) to freely move them across your monitors!")

    local panelCheck = CreateNativeCheckbox(card2_2, "Keep panels placed on Offhand Monitor open independently",
        function() return Offhand.db and Offhand.db.independentWorkspacePanels end,
        function(val) Offhand.db.independentWorkspacePanels = val end,
        L["CHECK_ESC_PERSIST_TIP_TITLE"], L["CHECK_ESC_PERSIST_TIP_DESC"]
    )
    panelCheck:SetPoint("TOPLEFT", 10, -66)

    local panelDesc = card2_2:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    panelDesc:SetPoint("TOPLEFT", 32, -88)
    panelDesc:SetText("|cff888888Allows opening bags, character pane, spellbook & map simultaneously.|r")

    local escapeCheck = CreateNativeCheckbox(card2_2, "Keep Offhand Monitor panels open when pressing Escape",
        function() return Offhand.db and Offhand.db.persistentWorkspacePanels ~= false end,
        function(val)
            Offhand.db.persistentWorkspacePanels = val
            if Offhand.Canvas and Offhand.Canvas.UpdatePersistenceBehavior then
                Offhand.Canvas:UpdatePersistenceBehavior()
            end
        end,
        L["CHECK_ESC_PERSIST_TIP_TITLE"], L["CHECK_ESC_PERSIST_TIP_DESC"]
    )
    escapeCheck:SetPoint("TOPLEFT", 10, -110)

    local escapeDesc = card2_2:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    escapeDesc:SetPoint("TOPLEFT", 32, -132)
    escapeDesc:SetText("|cff888888Escape clears targets or opens Game Menu without closing Offhand Monitor elements.|r")

    local reloadCheck = CreateNativeCheckbox(card2_2, "Persist open panels across reloads & zone transitions",
        function() return Offhand.db and Offhand.db.restoreWorkspaceOnReload ~= false end,
        function(val) Offhand.db.restoreWorkspaceOnReload = val end,
        "Reload Persistence", "Automatically re-opens any panels you had open on the Offhand Monitor after a /reload or loading screen completes."
    )
    reloadCheck:SetPoint("TOPLEFT", 10, -154)

    local seamCheck = CreateNativeCheckbox(card2_2, "Reroute popups & dialogs away from center bezel",
        function() return Offhand.db and Offhand.db.seamRedirect end,
        function(val) Offhand.db.seamRedirect = val end,
        L["CHECK_SEAM_REDIRECT_TIP_TITLE"], L["CHECK_SEAM_REDIRECT_TIP_DESC"]
    )
    seamCheck:SetPoint("TOPLEFT", 10, -178)

    local forceCheck = CreateNativeCheckbox(recoveryCard, L["PREVIEW_DUAL"],
        function() return (Offhand.db and Offhand.db.forceDualOnSingle) or false end,
        function(val) Offhand.db.forceDualOnSingle = val end,
        "Force Dual Mode", "Forces multi-monitor canvas logic on single-screen setups for testing and preview."
    )
    forceCheck:SetPoint("TOPLEFT", 12, -76)

    local compatDesc = card2_2:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    compatDesc:SetPoint("TOPLEFT", 12, -202)
    compatDesc:SetWidth(636)
    compatDesc:SetJustifyH("LEFT")
    card2_2.compatDesc = compatDesc


    local card2_3 = CreateCard(tab1, L["CARD_BEZEL"], 116)

    local bezelSlider = CreateNativeSlider(card2_3, "Bezel Compensation Gap", 0, 100, 2,
        function() return (Offhand.db and Offhand.db.bezelGap) or 0 end,
        function(val) Offhand.db.bezelGap = val end,
        "%d px",
        L["SLIDER_BEZEL_GAP_TIP_TITLE"], L["SLIDER_BEZEL_GAP_TIP_DESC"]
    )
    bezelSlider:SetPoint("TOPLEFT", 12, -54)
    bezelSlider:SetWidth(290)


    local bezelNote = card2_3:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    bezelNote:SetPoint("TOPLEFT", 12, -76)
    bezelNote:SetText("|cff888888Compensates for physical display monitor edges to align frames continuously.|r")

    -- ========================================================================
    -- TAB 3: THEMES & COLOR CUSTOMIZATION
    -- ========================================================================
    local card3_1 = CreateCard(tab3, "Visual Theme Preset", 114)

    local rClassic = CreateNativeRadioButton(card3_1, "Classic Warcraft",
        function() return (Offhand.db and Offhand.db.theme == "CLASSIC") end,
        function()
            Offhand.db.theme = "CLASSIC"
            Offhand.db.trimColor = "GOLD"
            Offhand.db.canvasColor = "CLASSIC_STONE"
            Offhand:UpdateTheme()
        end,
        L["THEME_CLASSIC_TIP_TITLE"], L["THEME_CLASSIC_TIP_DESC"]
    )
    rClassic:SetPoint("TOPLEFT", 12, -26)

    local subClassic = card3_1:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subClassic:SetPoint("TOPLEFT", 34, -46)
    subClassic:SetText("|cff888888Authentic WoW gold & stone|r")

    local rSlate = CreateNativeRadioButton(card3_1, "Blizzard Slate",
        function() return (Offhand.db and Offhand.db.theme == "BLIZZARD_SLATE") end,
        function()
            Offhand.db.theme = "BLIZZARD_SLATE"
            Offhand.db.trimColor = "SILVER"
            Offhand.db.canvasColor = "CHARCOAL"
            Offhand:UpdateTheme()
        end,
        L["THEME_SLATE_TIP_TITLE"], L["THEME_SLATE_TIP_DESC"]
    )
    rSlate:SetPoint("TOPLEFT", 236, -26)

    local subSlate = card3_1:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subSlate:SetPoint("TOPLEFT", 258, -46)
    subSlate:SetText("|cff888888Charcoal dialog & silver trim|r")

    local rTinker = CreateNativeRadioButton(card3_1, "Forged Brass",
        function() return (Offhand.db and Offhand.db.theme == "GNOMISH_TINKER") end,
        function()
            Offhand.db.theme = "GNOMISH_TINKER"
            Offhand.db.trimColor = "TINKER_BRASS"
            Offhand.db.canvasColor = "TINKER_SLATE"
            Offhand:UpdateTheme()
        end,
        L["THEME_TINKER_TIP_TITLE"], L["THEME_TINKER_TIP_DESC"]
    )
    rTinker:SetPoint("TOPLEFT", 470, -26)

    local subTinker = card3_1:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subTinker:SetPoint("TOPLEFT", 492, -46)
    subTinker:SetText("|cff888888Forged brass & blue accents|r")

    local rObsidian = CreateNativeRadioButton(card3_1, "Obsidian Dark",
        function() return (Offhand.db and Offhand.db.theme == "OBSIDIAN") end,
        function()
            Offhand.db.theme = "OBSIDIAN"
            Offhand.db.trimColor = "BRONZE"
            Offhand.db.canvasColor = "CHARCOAL"
            Offhand:UpdateTheme()
        end,
        L["THEME_OBSIDIAN_TIP_TITLE"], L["THEME_OBSIDIAN_TIP_DESC"]
    )
    rObsidian:SetPoint("TOPLEFT", 12, -68)

    local subObsidian = card3_1:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subObsidian:SetPoint("TOPLEFT", 34, -88)
    subObsidian:SetText("|cff888888Dark neutral slate Offhand Monitor|r")

    local rPitchBlack = CreateNativeRadioButton(card3_1, "Pitch Black",
        function() return (Offhand.db and Offhand.db.theme == "PITCH_BLACK") end,
        function()
            Offhand.db.theme = "PITCH_BLACK"
            Offhand.db.canvasColor = "PURE_BLACK"
            Offhand:UpdateTheme()
        end,
        L["THEME_PITCH_BLACK_TIP_TITLE"], L["THEME_PITCH_BLACK_TIP_DESC"]
    )
    rPitchBlack:SetPoint("TOPLEFT", 236, -68)

    local subPitchBlack = card3_1:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subPitchBlack:SetPoint("TOPLEFT", 258, -88)
    subPitchBlack:SetText("|cff888888True OLED pure black canvas|r")


    local card3_2 = CreateCard(tab3, "Dialog Header & Border Trim Palette", 94)

    local trimButtons = {
        { "GOLD", "Gold", 1.00, 0.82, 0.00 },
        { "TINKER_BRASS", "Brass", 0.85, 0.65, 0.18 },
        { "CYAN_GLOW", "Cyan", 0.00, 0.82, 1.00 },
        { "SILVER", "Silver", 0.72, 0.75, 0.78 },
        { "BRONZE", "Bronze", 0.85, 0.58, 0.25 },
        { "EMERALD", "Emerald", 0.22, 0.82, 0.35 },
    }
    local trimBtnFrames = {}
    local customTrimBtn
    for i, t in ipairs(trimButtons) do
        local btn = CreateFrame("Button", nil, card3_2, "UIPanelButtonTemplate")
        btn:SetSize(155, 24)
        local row = (i <= 4) and 1 or 2
        local col = (i <= 4) and (i - 1) or (i - 5)
        local x = 12 + col * (155 + 8)
        local y = (row == 1) and -30 or -58
        btn:SetPoint("TOPLEFT", x, y)
        local trimKey = t[1]
        btn.trimKey = trimKey
        btn.trimData = t
        btn:SetText(t[2])
        btn:SetScript("OnClick", function()
            Offhand.db.trimColor = trimKey
            Offhand:UpdateTheme()
            Options:RefreshPanel()
        end)
        if Offhand.SetTooltip then
            Offhand:SetTooltip(btn, string.format(L["BTN_TRIM_ACCENT_TIP_TITLE_FMT"], t[2]), string.format(L["BTN_TRIM_ACCENT_TIP_DESC_FMT"], t[2]))
        end
        tinsert(trimBtnFrames, btn)
    end

    customTrimBtn = CreateFrame("Button", nil, card3_2, "UIPanelButtonTemplate")
    customTrimBtn:SetSize(155, 24)
    customTrimBtn:SetPoint("TOPLEFT", 12 + 2 * (155 + 8), -58)
    customTrimBtn:SetText(L["BTN_TRIM_CUSTOM"])
    customTrimBtn:SetScript("OnClick", function()
        local cur = (Offhand.db and Offhand.db.customTrimColor) or { r = 1.0, g = 0.82, b = 0.0 }
        Offhand:OpenColorPicker(cur.r, cur.g, cur.b, 1.0, false, function(r, g, b)
            Offhand.db.customTrimColor = { r = r, g = g, b = b }
            Offhand.db.trimColor = "CUSTOM"
            Offhand:UpdateTheme()
            Options:RefreshPanel()
        end)
    end)
    if Offhand.SetTooltip then
        Offhand:SetTooltip(customTrimBtn, L["BTN_TRIM_CUSTOM_TIP_TITLE"], L["BTN_TRIM_CUSTOM_TIP_DESC"])
    end

    function Options:UpdateTrimHighlights()
        local curTrim = (Offhand.db and Offhand.db.trimColor) or "GOLD"
        for _, btn in ipairs(trimBtnFrames) do
            local t = btn.trimData
            local isSelected = (btn.trimKey == curTrim)
            btn:SetText(t[2])
            Options:SetChoiceSelected(btn, isSelected)
            if isSelected then
                if btn.LockHighlight then btn:LockHighlight() end
                local fs = btn.GetFontString and btn:GetFontString()
                if fs and fs.SetTextColor then fs:SetTextColor(1.0, 0.95, 0.60, 1.0) end
            else
                if btn.UnlockHighlight then btn:UnlockHighlight() end
                local fs = btn.GetFontString and btn:GetFontString()
                if fs and fs.SetTextColor then fs:SetTextColor(t[3], t[4], t[5], 1.0) end
            end
        end
        if customTrimBtn then
            local isCustom = (curTrim == "CUSTOM")
            local c = (Offhand.db and Offhand.db.customTrimColor) or { r = 1.0, g = 0.82, b = 0.0 }
            if isCustom then
                customTrimBtn:SetText(string.format(L["BTN_TRIM_CUSTOM_ACTIVE_FMT"], math.floor(c.r*255+0.5), math.floor(c.g*255+0.5), math.floor(c.b*255+0.5)))
                if customTrimBtn.LockHighlight then customTrimBtn:LockHighlight() end
                local fs = customTrimBtn.GetFontString and customTrimBtn:GetFontString()
                if fs and fs.SetTextColor then fs:SetTextColor(0.2, 1.0, 0.4, 1.0) end
            else
                customTrimBtn:SetText(L["BTN_TRIM_CUSTOM"])
                if customTrimBtn.UnlockHighlight then customTrimBtn:UnlockHighlight() end
                local fs = customTrimBtn.GetFontString and customTrimBtn:GetFontString()
                if fs and fs.SetTextColor then fs:SetTextColor(1.0, 0.82, 0.0, 1.0) end
            end
        end
    end
    Options:UpdateTrimHighlights()


    local card3_3 = CreateCard(tab3, "Offhand Canvas Background (Secondary Monitor)", 210)

    local canvasButtons = {
        { "CLASSIC_STONE", "Classic Stone" },
        { "TINKER_SLATE",  "Tinker Slate" },
        { "CHARCOAL",      "Charcoal Slate" },
        { "WARM_NIGHT",    "Warm Night" },
        { "DEEP_BLUE",     "Midnight Navy" },
        { "PURE_BLACK",    "Pitch Black" },
    }
    local canvasBtnFrames = {}
    local customCanvasBtn
    for i, c in ipairs(canvasButtons) do
        local btn = CreateFrame("Button", nil, card3_3, "UIPanelButtonTemplate")
        btn:SetSize(155, 24)
        local row = (i <= 4) and 1 or 2
        local col = (i <= 4) and (i - 1) or (i - 5)
        local x = 12 + col * (155 + 8)
        local y = (row == 1) and -30 or -58
        btn:SetPoint("TOPLEFT", x, y)
        local canvasKey = c[1]
        btn.canvasKey = canvasKey
        btn.canvasTitle = c[2]
        btn:SetText(c[2])
        btn:SetScript("OnClick", function()
            Offhand.db.canvasColor = canvasKey
            Offhand:UpdateTheme()
            Options:RefreshPanel()
        end)
        if Offhand.SetTooltip then
            Offhand:SetTooltip(btn, string.format(L["BTN_CANVAS_TONE_TIP_TITLE_FMT"], c[2]), string.format(L["BTN_CANVAS_TONE_TIP_DESC_FMT"], c[2]))
        end
        tinsert(canvasBtnFrames, btn)
    end

    local alphaSlider -- forward declaration for OpenCustomCanvasPicker

    customCanvasBtn = CreateFrame("Button", nil, card3_3, "UIPanelButtonTemplate")
    customCanvasBtn:SetSize(155, 24)
    customCanvasBtn:SetPoint("TOPLEFT", 12 + 2 * (155 + 8), -58)
    customCanvasBtn:SetText(L["BTN_CANVAS_CUSTOM"])
    local function OpenCustomCanvasPicker()
        local cur = (Offhand.db and Offhand.db.customCanvasColor) or { r = 0.12, g = 0.22, b = 0.35 }
        local curA = (Offhand.db and Offhand.db.canvasAlpha) or 0.95
        Offhand:OpenColorPicker(cur.r, cur.g, cur.b, curA, true, function(r, g, b, a)
            Offhand.db.customCanvasColor = { r = r, g = g, b = b }
            if a ~= nil then
                Offhand.db.canvasAlpha = a
            end
            Offhand.db.canvasColor = "CUSTOM"
            Offhand:UpdateTheme()
            if Options.UpdateCanvasHighlights then
                Options:UpdateCanvasHighlights()
            end
            if alphaSlider and alphaSlider.SetValue then
                alphaSlider:SetValue(Offhand.db.canvasAlpha)
            end
        end)
    end
    customCanvasBtn:SetScript("OnClick", OpenCustomCanvasPicker)
    if Offhand.SetTooltip then
        Offhand:SetTooltip(customCanvasBtn, L["BTN_CANVAS_CUSTOM_TIP_TITLE"], L["BTN_CANVAS_CUSTOM_TIP_DESC"])
    end

    -- Live Offhand Canvas Swatch Preview (Interactive click-to-pick)
    local swatchCard = CreateFrame("Frame", nil, card3_3, "BackdropTemplate")
    swatchCard:SetSize(300, 36)
    swatchCard:SetPoint("TOPLEFT", 12, -84)
    if swatchCard.EnableMouse then swatchCard:EnableMouse(true) end
    swatchCard:SetScript("OnMouseDown", OpenCustomCanvasPicker)
    if Offhand.SetTooltip then
        Offhand:SetTooltip(swatchCard, L["BTN_CANVAS_PREVIEW_TIP_TITLE"], L["BTN_CANVAS_PREVIEW_TIP_DESC"])
    end

    local swatchText = swatchCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    swatchText:SetPoint("CENTER", swatchCard, "CENTER", 0, 0)
    card3_3.swatchCard = swatchCard

    function Options:UpdateCanvasHighlights()
        local curColor = (Offhand.db and Offhand.db.canvasColor) or "CHARCOAL"
        local curAlpha = (Offhand.db and Offhand.db.canvasAlpha) or 0.95
        for _, btn in ipairs(canvasBtnFrames) do
            local isSelected = (btn.canvasKey == curColor)
            btn:SetText(btn.canvasTitle)
            Options:SetChoiceSelected(btn, isSelected)
            if isSelected then
                if btn.LockHighlight then btn:LockHighlight() end
                local fs = btn.GetFontString and btn:GetFontString()
                if fs and fs.SetTextColor then fs:SetTextColor(1.0, 0.95, 0.60, 1.0) end
            else
                if btn.UnlockHighlight then btn:UnlockHighlight() end
                local fs = btn.GetFontString and btn:GetFontString()
                if fs and fs.SetTextColor then fs:SetTextColor(1.0, 0.82, 0.0, 1.0) end
            end
        end
        if customCanvasBtn then
            local isCustom = (curColor == "CUSTOM")
            local c = (Offhand.db and Offhand.db.customCanvasColor) or { r = 0.12, g = 0.22, b = 0.35 }
            if isCustom then
                customCanvasBtn:SetText(string.format(L["BTN_CANVAS_CUSTOM_ACTIVE_FMT"], math.floor(c.r*255+0.5), math.floor(c.g*255+0.5), math.floor(c.b*255+0.5)))
                if customCanvasBtn.LockHighlight then customCanvasBtn:LockHighlight() end
                local fs = customCanvasBtn.GetFontString and customCanvasBtn:GetFontString()
                if fs and fs.SetTextColor then fs:SetTextColor(0.2, 1.0, 0.4, 1.0) end
            else
                customCanvasBtn:SetText(L["BTN_CANVAS_CUSTOM"])
                if customCanvasBtn.UnlockHighlight then customCanvasBtn:UnlockHighlight() end
                local fs = customCanvasBtn.GetFontString and customCanvasBtn:GetFontString()
                if fs and fs.SetTextColor then fs:SetTextColor(1.0, 0.82, 0.0, 1.0) end
            end
        end

        if Offhand.Themes and Offhand.Themes.ApplyCanvasTheme then
            Offhand.Themes:ApplyCanvasTheme(swatchCard)
            local pName
            if curColor == "CUSTOM" then
                local c = (Offhand.db and Offhand.db.customCanvasColor) or { r = 0.12, g = 0.22, b = 0.35 }
                pName = string.format("Custom (#%02x%02x%02x)", math.floor(c.r*255+0.5), math.floor(c.g*255+0.5), math.floor(c.b*255+0.5))
            else
                local pals = Offhand.Themes:GetCanvasPalettes()
                pName = pals and pals[curColor] and pals[curColor].name or curColor
            end
            swatchText:SetText(string.format("|cffffd100Preview:|r %s (%d%%)", pName, math.floor(curAlpha * 100 + 0.5)))
        end
    end

    alphaSlider = CreateNativeSlider(card3_3, "Background Opacity", 0.10, 1.0, 0.05,
        function() return (Offhand.db and Offhand.db.canvasAlpha) or 0.95 end,
        function(val)
            Offhand.db.canvasAlpha = val
            Offhand:UpdateTheme()
            if Options.UpdateCanvasHighlights then
                Options:UpdateCanvasHighlights()
            end
        end,
        "%.0f%%",
        L["SLIDER_CANVAS_OPACITY_TIP_TITLE"], L["SLIDER_CANVAS_OPACITY_TIP_DESC"]
    )
    alphaSlider:SetPoint("TOPLEFT", 12, -154)
    alphaSlider:SetWidth(320)

    local themeNote = card3_3:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    themeNote:SetPoint("TOPLEFT", 12, -188)
    themeNote:SetText("|cff888888Colors & opacity apply live to your secondary screen canvas backdrop. Click preview swatch or Custom for color wheel.|r")

    -- ========================================================================
    -- TAB 4: PROFILES
    -- ========================================================================
    local card4_1 = CreateCard(tab4, L["PROFILES_LIST_TITLE"] or "Profiles", 390)
    
    local activeProfileLabel = card4_1:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
    activeProfileLabel:SetPoint("TOPLEFT", 16, -24)
    activeProfileLabel:SetText((L["PROFILES_CURRENT_LABEL"] or "Active Profile:") .. " |cff00ff00" .. tostring((OffhandCharDB and OffhandCharDB.activeProfile) or "Default") .. "|r")

    local profileScroll = CreateFrame("ScrollFrame", "OffhandProfileScrollFrame", card4_1, "UIPanelScrollFrameTemplate")
    profileScroll:SetPoint("TOPLEFT", 16, -56)
    profileScroll:SetSize(280, 220)
    
    local profileScrollBG = CreateFrame("Frame", nil, profileScroll, "BackdropTemplate")
    profileScrollBG:SetPoint("TOPLEFT", -4, 4)
    profileScrollBG:SetPoint("BOTTOMRIGHT", 24, -4)
    if profileScrollBG.SetFrameLevel then
        profileScrollBG:SetFrameLevel(profileScroll.GetFrameLevel and (profileScroll:GetFrameLevel() - 1) or 1)
    end
    profileScrollBG:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    profileScrollBG:SetBackdropColor(0, 0, 0, 0.8)

    local profileScrollContent = CreateFrame("Frame", nil, profileScroll)
    profileScrollContent:SetSize(280, 420)
    if profileScroll.SetScrollChild then profileScroll:SetScrollChild(profileScrollContent) end

    local selectedProfileName = nil
    local profileButtons = {}
    
    local loadBtn = CreateFrame("Button", nil, card4_1, "UIPanelButtonTemplate")
    loadBtn:SetSize(160, 26)
    loadBtn:SetPoint("TOPLEFT", profileScroll, "TOPRIGHT", 40, 0)
    loadBtn:SetText(L["PROFILES_BTN_LOAD"] or "Load")
    
    local copyBtn = CreateFrame("Button", nil, card4_1, "UIPanelButtonTemplate")
    copyBtn:SetSize(160, 26)
    copyBtn:SetPoint("TOPLEFT", loadBtn, "BOTTOMLEFT", 0, -8)
    copyBtn:SetText(L["PROFILE_COPY_INTO_CURRENT"])
    
    local deleteBtn = CreateFrame("Button", nil, card4_1, "UIPanelButtonTemplate")
    deleteBtn:SetSize(160, 26)
    deleteBtn:SetPoint("TOPLEFT", copyBtn, "BOTTOMLEFT", 0, -8)
    deleteBtn:SetText(L["PROFILES_BTN_DELETE"] or "Delete")
    
    local resetBtn = CreateFrame("Button", nil, card4_1, "UIPanelButtonTemplate")
    resetBtn:SetSize(160, 26)
    resetBtn:SetPoint("TOPLEFT", deleteBtn, "BOTTOMLEFT", 0, -24)
    resetBtn:SetText(L["PROFILES_BTN_RESET"] or "Reset Current")
    
    local createEditBox = CreateFrame("EditBox", nil, card4_1, "InputBoxTemplate")
    createEditBox:SetSize(200, 26)
    createEditBox:SetPoint("TOPLEFT", profileScroll, "BOTTOMLEFT", 6, -34)
    createEditBox:SetAutoFocus(false)
    createEditBox:SetMaxLetters(40)
    local nameLabel = card4_1:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    nameLabel:SetPoint("TOPLEFT", profileScroll, "BOTTOMLEFT", 0, -14)
    nameLabel:SetText(L["PROFILE_NEW_NAME"])
    
    local createBtn = CreateFrame("Button", nil, card4_1, "UIPanelButtonTemplate")
    createBtn:SetSize(80, 26)
    createBtn:SetPoint("LEFT", createEditBox, "RIGHT", 4, 0)
    createBtn:SetText(L["PROFILES_BTN_CREATE"] or "Save As")

    local autoSaveNote = card4_1:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    autoSaveNote:SetPoint("TOPLEFT", profileScroll, "BOTTOMLEFT", 0, -72)
    autoSaveNote:SetWidth(620)
    autoSaveNote:SetJustifyH("LEFT")
    autoSaveNote:SetText(L["SETTINGS_AUTOSAVE"])

    function Options:UpdateProfileList()
        local profiles = Offhand.GetProfiles and Offhand:GetProfiles() or {"Default"}
        activeProfileLabel:SetText((L["PROFILES_CURRENT_LABEL"] or "Active Profile:") .. " |cff00ff00" .. tostring((OffhandCharDB and OffhandCharDB.activeProfile) or "Default") .. "|r")
        
        -- Hide old buttons
        for _, btn in ipairs(profileButtons) do btn:Hide() end
        
        local yOffset = -4
        for i, pName in ipairs(profiles) do
            local btn = profileButtons[i]
            if not btn then
                btn = CreateFrame("Button", nil, profileScrollContent)
                btn:SetSize(270, 20)
                local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                fs:SetPoint("LEFT", btn, "LEFT", 8, 0)
                fs:SetWidth(250)
                fs:SetJustifyH("LEFT")
                btn.text = fs
                local tex = btn:CreateTexture(nil, "BACKGROUND")
                tex:SetAllPoints()
                tex:SetColorTexture(1, 0.82, 0, 0.3)
                tex:Hide()
                btn.highlight = tex
                
                btn:SetScript("OnClick", function(self)
                    selectedProfileName = self.profileName
                    Options:UpdateProfileList()
                end)
                profileButtons[i] = btn
            end
            btn.profileName = pName
            btn:SetPoint("TOPLEFT", profileScrollContent, "TOPLEFT", 4, yOffset)
            btn.text:SetText(pName .. (pName == ((OffhandCharDB and OffhandCharDB.activeProfile) or "Default") and ("  |cffffd100" .. L["PROFILE_ACTIVE"] .. "|r") or ""))
            if pName == selectedProfileName then
                btn.highlight:Show()
            else
                btn.highlight:Hide()
            end
            btn:Show()
            yOffset = yOffset - 22
        end
        
        profileScrollContent:SetHeight(math.max(220, #profiles * 22 + 8))
        loadBtn:SetEnabled(selectedProfileName ~= nil and selectedProfileName ~= (OffhandCharDB and OffhandCharDB.activeProfile))
        copyBtn:SetEnabled(selectedProfileName ~= nil and selectedProfileName ~= (OffhandCharDB and OffhandCharDB.activeProfile))
        deleteBtn:SetEnabled(selectedProfileName ~= nil and selectedProfileName ~= (OffhandCharDB and OffhandCharDB.activeProfile) and selectedProfileName ~= "Default")
    end

    loadBtn:SetScript("OnClick", function()
        if selectedProfileName and Offhand.SetProfile then
            Offhand:SetProfile(selectedProfileName)
        end
    end)
    copyBtn:SetScript("OnClick", function()
        if selectedProfileName and Offhand.CopyProfile then
            local source = selectedProfileName
            local destination = (OffhandCharDB and OffhandCharDB.activeProfile) or "Default"
            Options:Confirm(string.format(L["PROFILE_COPY_CONFIRM"], destination, source), function()
                if ((OffhandCharDB and OffhandCharDB.activeProfile) or "Default") == destination then
                    Offhand:CopyProfile(source)
                end
            end)
        end
    end)
    deleteBtn:SetScript("OnClick", function()
        if selectedProfileName and Offhand.DeleteProfile then
            local name = selectedProfileName
            Options:Confirm(string.format(L["PROFILE_DELETE_CONFIRM"], name), function()
                Offhand:DeleteProfile(name)
                selectedProfileName = nil
                Options:UpdateProfileList()
            end)
        end
    end)
    resetBtn:SetScript("OnClick", function()
        local name = (OffhandCharDB and OffhandCharDB.activeProfile) or "Default"
        Options:Confirm(string.format(L["PROFILE_RESET_CONFIRM"], name), function()
            if ((OffhandCharDB and OffhandCharDB.activeProfile) or "Default") == name then
                if Offhand.ResetConfig then Offhand:ResetConfig() end
            end
        end)
    end)
    createBtn:SetScript("OnClick", function()
        local t = strtrim(createEditBox:GetText() or "")
        if t ~= "" and Offhand.CreateProfile then
            local success, err = Offhand:CreateProfile(t)
            if success then
                createEditBox:SetText("")
                createEditBox:ClearFocus()
                selectedProfileName = t
                Options:UpdateProfileList()
            else
                Offhand:Print("|cffff3333" .. tostring(err) .. "|r")
            end
        end
    end)

    -- ========================================================================
    -- TAB 5: FAQ & HELP
    -- ========================================================================
    local helpCards = {}
    for _, topic in ipairs({ "SETUP", "PANELS", "RECOVERY", "EDIT_MODE" }) do
        local card = CreateCard(tab5, L["HELP_" .. topic .. "_TITLE"], 112)
        local body = card:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        body:SetPoint("TOPLEFT", 14, -30)
        body:SetPoint("TOPRIGHT", -14, -30)
        body:SetJustifyH("LEFT")
        body:SetText(L["HELP_" .. topic .. "_BODY"])
        helpCards[#helpCards + 1] = card
    end

    Options:StackCards(tab1, {card1_1, card1_2, card1_3, card2_3, card1_4})
    Options:StackCards(tab2, {card2_1, card2_2, recoveryCard})
    Options:StackCards(tab3, {card3_1, card3_2, card3_3})
    Options:StackCards(tab4, {card4_1})
    Options:StackCards(tab5, helpCards)

    -- ========================================================================
    -- BOTTOM ACTION BAR (Shared across tabs)
    -- ========================================================================
    local applyBtn = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
    applyBtn:SetSize(150, 28)
    applyBtn:SetPoint("BOTTOMLEFT", 20, 14)
    applyBtn:SetText(L["BTN_REAPPLY"])
    applyBtn:SetScript("OnClick", function()
        Offhand:ApplyFullLayout()
        Offhand:Print(L["MSG_LAYOUT_APPLIED"])
    end)
    if Offhand.SetTooltip then
        Offhand:SetTooltip(applyBtn, L["BTN_APPLY_LAYOUT_TIP_TITLE"], L["BTN_APPLY_LAYOUT_TIP_DESC"])
    end

    local saveStatus = configFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    saveStatus:SetPoint("BOTTOM", configFrame, "BOTTOM", 0, 23)
    saveStatus:SetText(L["SETTINGS_SAVED_LIVE"])

    local closePanelBtn = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
    closePanelBtn:SetSize(150, 28)
    closePanelBtn:SetPoint("BOTTOMRIGHT", -20, 14)
    closePanelBtn:SetText(L["BTN_CLOSE"])
    closePanelBtn:SetScript("OnClick", function()
        Options:Close()
    end)
    if Offhand.SetTooltip then
        Offhand:SetTooltip(closePanelBtn, L["BTN_CLOSE"], L["SETTINGS_AUTOSAVE"])
    end

    function Options:RefreshPanel()
        if not configFrame then return end
        local info = Options:DetectTopology()
        banner:SetText(string.format("|cffffd100Display:|r %s  |cff888888(%dx%d)|r",
            info.description, info.physWidth, info.physHeight))

        local curSeam = (Offhand.db and Offhand.db.deckWidthRatio) or 0.36
        seamSlider:SetValue(curSeam)
        if seamSlider.UpdateText then seamSlider:UpdateText() end

        enableCheck:SetChecked((Offhand.db and Offhand.db.enabled) or false)
        laserCheck:SetChecked((seamGuideLine and seamGuideLine:IsShown()) or false)

        rPortraitLeft:SetChecked(Offhand.db and Offhand.db.layoutPreset == "PORTRAIT_LEFT_LANDSCAPE_RIGHT" and Offhand.db.primaryPosition == "RIGHT")
        rPortraitRight:SetChecked(Offhand.db and Offhand.db.layoutPreset == "PORTRAIT_LEFT_LANDSCAPE_RIGHT" and Offhand.db.primaryPosition == "LEFT")
        rDual:SetChecked(Offhand.db and Offhand.db.layoutPreset == "LANDSCAPE_DUAL")

        r169:SetChecked(Offhand.db and Offhand.db.aspectRatioMode == "16_9")
        r219:SetChecked(Offhand.db and Offhand.db.aspectRatioMode == "21_9")
        rFill:SetChecked(Offhand.db and Offhand.db.aspectRatioMode == "FILL")

        seamCheck:SetChecked((Offhand.db and Offhand.db.seamRedirect) or false)
        mapMoveCheck:SetChecked((Offhand.db and Offhand.db.preventMapCloseOnMove) or false)
        panelCheck:SetChecked((Offhand.db and Offhand.db.independentWorkspacePanels) or false)
        escapeCheck:SetChecked((Offhand.db and Offhand.db.persistentWorkspacePanels ~= false) or false)
        reloadCheck:SetChecked((Offhand.db and Offhand.db.restoreWorkspaceOnReload ~= false) or false)
        forceCheck:SetChecked((Offhand.db and Offhand.db.forceDualOnSingle) or false)

        local curTheme = (Offhand.db and Offhand.db.theme) or "CLASSIC"
        rClassic:SetChecked(curTheme == "CLASSIC")
        rSlate:SetChecked(curTheme == "BLIZZARD_SLATE")
        rTinker:SetChecked(curTheme == "GNOMISH_TINKER")
        rObsidian:SetChecked(curTheme == "OBSIDIAN")
        rPitchBlack:SetChecked(curTheme == "PITCH_BLACK")

        bezelSlider:UpdateText()
        alphaSlider:UpdateText()
        hudSlider:UpdateText()
        mapScaleSlider:UpdateText()

        if Options.UpdateProfileList then
            Options:UpdateProfileList()
        end

        local bagAddon = Offhand.HasCustomBagAddon and Offhand.HasCustomBagAddon()
        local mmAddon = Offhand.HasCustomMinimapAddon and Offhand.HasCustomMinimapAddon()
        if card2_2.compatDesc then
            if bagAddon and mmAddon then
                card2_2.compatDesc:SetText("|cff00ff00Addon Compatibility:|r Custom Bag & Minimap addons active (control yielded).")
            elseif bagAddon then
                card2_2.compatDesc:SetText("|cff00ff00Addon Compatibility:|r Custom Bag addon active (control yielded).")
            elseif mmAddon then
                card2_2.compatDesc:SetText("|cff00ff00Addon Compatibility:|r Custom Minimap addon active (control yielded).")
            else
                card2_2.compatDesc:SetText("|cff888888Auto-detects Bagnon, SexyMap, AdiBags, ElvUI, etc. to prevent conflicts.|r")
            end
        end
        if Options.UpdateOBSCard then
            Options:UpdateOBSCard()
        end
        Options:UpdateCardThemes()
        Offhand:ApplyFullLayout()
    end

    SwitchTab(currentTab or 1)
    Options:UpdateCardThemes()
    configFrame:Hide()
    return configFrame
end

function Options:Open(showSeamGuide)
    if Offhand.Wizard and Offhand.Wizard.Close then
        Offhand.Wizard:Close()
    end
    local panel = self:CreateFloatingPanel()
    if panel:IsShown() and not showSeamGuide then
        panel:Hide()
        return
    end

    local m = Offhand.Viewport and Offhand.Viewport:GetMetrics()
    if m and m.gameWidth and m.gameWidth > 0 then
        local cx = (m.gameLeft + m.gameRight) / 2
        local cy = (m.gameBottom + m.gameTop) / 2
        panel:ClearAllPoints()
        panel:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx, cy)
    else
        panel:ClearAllPoints()
        panel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end

    self:RefreshPanel()
    panel:Show()

    if showSeamGuide then
        self:ShowSeamGuide(Offhand.db and Offhand.db.deckWidthRatio)
        if configFrame and configFrame.laserCheck then
            configFrame.laserCheck:SetChecked(true)
        end
    end
end

function Options:Close()
    self:HideSeamGuide()
    if Offhand.db then
        Offhand.db.firstRunComplete = true
    end
    if configFrame then
        configFrame:Hide()
    end
end

--

function Offhand:InitializeOptions()
    -- Options ready
end



