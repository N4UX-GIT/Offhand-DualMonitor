--[[
    Offhand: Multi-Monitor Setup Addon
    UI/Wizard.lua: Guided setup and display calibration with shared UI controls.
--]]

local _, Offhand = ...
local Controls = assert(Offhand.UIControls, "Offhand UI controls must load before Wizard")
local CreateFrame = Controls.CreateFrame

local L = Offhand.L or setmetatable({}, {
    __index = function(t, key)
        return key
    end
})

local Wizard = {}
Offhand.Wizard = Wizard

local wizardFrame = nil
local editModeReturnWatcher

function Wizard:GetSavedStep()
    local step = type(OffhandCharDB) == "table" and tonumber(OffhandCharDB.wizardProgressStep)
    if not step or step ~= step or step < 1 or step > 5 then
        if type(OffhandCharDB) == "table" then OffhandCharDB.wizardProgressStep = nil end
        return nil
    end
    return math.floor(step)
end

local function PlacementFailure()
    local m = Offhand.Viewport and Offhand.Viewport.GetMetrics and Offhand.Viewport:GetMetrics()
    local method = Offhand.GetOnboardingSetupMethod and Offhand:GetOnboardingSetupMethod()
    if Offhand._displayGeometryTransitionActive then return "span" end
    if not m or not m.isSpanned then return "span" end
    if method == "COMPANION" and not m.companionTopology then return "span" end
    -- A deliberately confirmed manual canvas can supersede an old bridge.
    if m.topologyStatus == "MISMATCH" and not m.manualCanvas then return "span" end
end

StaticPopupDialogs["OFFHAND_WIZARD_SKIP_MAINHAND_LAYOUT"] = {
    text = L["WIZARD_SKIP_HUD_CONFIRM_TEXT"],
    button1 = L["WIZARD_SKIP_HUD_CONFIRM"],
    button2 = L["BTN_BACK"],
    OnAccept = function(_, callback)
        if callback then callback() end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local function BackdropTemplate()
    return not Offhand.isLegacyWrath and "BackdropTemplate" or nil
end

local function SetShown(frame, shown)
    if frame.SetShown then frame:SetShown(shown)
    elseif shown then frame:Show()
    else frame:Hide() end
end

local function SupportsGeneratedMainhandLayout()
    local supportsEditMode = type(Offhand.HasBlizzardEditMode) == "function"
        and Offhand:HasBlizzardEditMode()
    return supportsEditMode
        and Offhand.Options
        and type(Offhand.Options.CreateMainhandHUDLayout) == "function"
end

local function UsesControllerLayout()
    return Offhand.Mainhand and Offhand.Mainhand.IsControllerLayout
        and Offhand.Mainhand:IsControllerLayout() or false
end

local function CanCreateControllerLayout()
    return Offhand.Mainhand and Offhand.Mainhand.CanCreateControllerLayout
        and Offhand.Mainhand:CanCreateControllerLayout() or false
end

local function ReadinessSummary(hudState)
    local m = Offhand.Viewport and Offhand.Viewport.GetMetrics
        and Offhand.Viewport:GetMetrics() or nil
    local source = m and m.companionTopology and L["READINESS_SOURCE_COMPANION"]
        or L["READINESS_SOURCE_MANUAL"]
    local gameW = math.floor((m and (m.gamePixelWidth or m.gameWidth) or 0) + 0.5)
    local gameH = math.floor((m and (m.gamePixelHeight or m.gameHeight) or 0) + 0.5)
    local workW = math.floor((m and (m.workspacePixelWidth or m.workspaceWidth) or 0) + 0.5)
    local workH = math.floor((m and (m.workspacePixelHeight or m.workspaceHeight) or 0) + 0.5)
    local side = (Offhand.db and Offhand.db.primaryPosition) or "?"
    local ar = (Offhand.db and Offhand.db.aspectRatioMode) or "?"
    local seam = ((Offhand.db and Offhand.db.deckWidthRatio) or 0) * 100
    local recovery = Offhand.isForever and L["READINESS_RECOVERY_FOREVER"]
        or L["READINESS_RECOVERY_STANDARD"]
    return string.format(L["READINESS_SUMMARY"], source, gameW, gameH, workW, workH,
        tostring(side), tostring(ar), seam, hudState, recovery)
end

function Wizard:DetectTopology()
    if Offhand.Options and Offhand.Options.DetectTopology then
        return Offhand.Options:DetectTopology()
    end
    return {
        physWidth = 1920,
        physHeight = 1080,
        aspectRatio = 16 / 9,
        isSpanned = false,
        recommendedPreset = "PORTRAIT_LEFT_LANDSCAPE_RIGHT",
        recommendedDeckRatio = 0.36,
        recommendedPosition = "RIGHT",
        recommendedAR = "16_9",
        description = "Standard Display",
    }
end

local function CreateWizardCard(parent, titleText, yOffset, height)
    local card = CreateFrame("Frame", nil, parent, BackdropTemplate())
    card:SetSize(628, height)
    card:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, yOffset)

    card:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    Controls.StyleSurface(card, "card")

    local title = card:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("TOPLEFT", card, "TOPLEFT", 12, -8)
    title:SetText(titleText)
    card.title = title
    card.sectionLabel = titleText

    return card
end

function Wizard:CreateFrame()
    if wizardFrame then return wizardFrame end
    if not CreateFrame then return nil end

    local f = CreateFrame("Frame", "OffhandSetupWizardFrame", UIParent, BackdropTemplate())
    f:SetSize(668, 454)
    Controls.RegisterDialog(f)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:EnableMouse(true)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)

    if tinsert and UISpecialFrames then
        tinsert(UISpecialFrames, "OffhandSetupWizardFrame")
    end

    if Offhand.Themes and Offhand.Themes.ApplyBackdrop then
        Offhand.Themes:ApplyBackdrop(f, (Offhand.db and Offhand.db.theme) or "CLASSIC", 1.0)
    end
    if Offhand.Themes and Offhand.Themes.CreateBayHeader then
        f.header = Offhand.Themes:CreateBayHeader(f, L["WIZARD_TITLE"])
    end

    local closeBtn = CreateFrame("Button", nil, f.header or f, "UIPanelCloseButton")
    closeBtn:SetSize(28, 28)
    if f.header then
        closeBtn:SetPoint("RIGHT", f.header, "RIGHT", -4, 0)
    else
        closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
    end
    closeBtn:SetScript("OnClick", function()
        Wizard:Close()
        if Wizard.openedFromOptions then
            Wizard.openedFromOptions = false
            if Offhand.Options and Offhand.Options.Open then
                Offhand.Options:Open()
            end
        end
    end)
    if Offhand.SetTooltip then
        Offhand:SetTooltip(closeBtn, L["WIZARD_BTN_CLOSE_TIP_TITLE"], L["WIZARD_BTN_CLOSE_TIP_DESC"])
    end

    f:SetScript("OnHide", function(self)
        self.recenterGeneration = (self.recenterGeneration or 0) + 1
        if Offhand.Options and Offhand.Options.HideSeamGuide then
            Offhand.Options:HideSeamGuide()
        end
    end)

    -- ========================================================================
    -- WELCOME / INTRO TEXT
    -- ========================================================================
    local welcomeText = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    welcomeText:SetPoint("TOPLEFT", 16, -54)
    welcomeText:SetPoint("TOPRIGHT", -16, -54)
    welcomeText:SetJustifyH("LEFT")
    welcomeText:SetText(L["WIZARD_WELCOME_TEXT"])
    f.welcomeText = welcomeText

    -- ========================================================================
    -- CARD 1: DISPLAY TOPOLOGY & 1-CLICK AUTO-SETUP
    -- ========================================================================
    local card1 = CreateWizardCard(f, L["WIZARD_CARD1_TITLE"], -116, 144)

    local logoIcon = card1:CreateTexture(nil, "ARTWORK")
    local textLeft = 14
    if logoIcon and logoIcon.SetSize and logoIcon.SetPoint and logoIcon.SetTexture then
        logoIcon:SetSize(38, 38)
        logoIcon:SetPoint("TOPLEFT", 14, -28)
        logoIcon:SetTexture("Interface\\AddOns\\Offhand\\Media\\OffhandLogo64x64.blp")
        card1.logoIcon = logoIcon
        textLeft = 60
    end

    local topoText = card1:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    topoText:SetPoint("TOPLEFT", textLeft, -28)
    topoText:SetPoint("TOPRIGHT", -14, -28)
    topoText:SetJustifyH("LEFT")
    f.topoText = topoText

    local recomText = card1:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    recomText:SetPoint("TOPLEFT", textLeft, -56)
    recomText:SetPoint("TOPRIGHT", -14, -56)
    recomText:SetJustifyH("LEFT")
    f.recomText = recomText

    local autoBtn = CreateFrame("Button", nil, card1, "UIPanelButtonTemplate")
    autoBtn:SetSize(608, 28)
    autoBtn:SetPoint("TOPLEFT", 14, -84)
    autoBtn:SetText("|cff00ff00" .. L["WIZARD_BTN_AUTOCONFIG"] .. "|r")
    if Offhand.SetTooltip then
        Offhand:SetTooltip(autoBtn, L["WIZARD_BTN_AUTOCONFIG_TIP_TITLE"], L["WIZARD_BTN_AUTOCONFIG_TIP_DESC"])
    end
    f.autoBtn = autoBtn

    local statusText = card1:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    statusText:SetPoint("TOPLEFT", 14, -118)
    statusText:SetPoint("TOPRIGHT", -14, -118)
    statusText:SetJustifyH("CENTER")
    statusText:SetText(L["WIZARD_STATUS_READY"])
    f.statusText = statusText

    autoBtn:SetScript("OnClick", function()
        if Offhand.Options and Offhand.Options.AutoConfigure then
            Offhand.Options:AutoConfigure(true, true)
            f:UpdateState()
            
            autoBtn:SetText(L["WIZARD_RECOMMENDATION_APPLIED"])
            statusText:SetText(L["WIZARD_CHECK_RECOMMENDATION"])
            f:SetStep(2)
        end
    end)

    -- ========================================================================
    -- CARD 2: MONITOR ORIENTATION & 3D VIEWPORT
    -- ========================================================================
    local card2 = CreateWizardCard(f, L["WIZARD_CARD2_TITLE"], -256, 206)

    local orientLabel = card2:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    orientLabel:SetPoint("TOPLEFT", 14, -28)
    orientLabel:SetText(L["WIZARD_LABEL_LAYOUT"])

    local btnPl = CreateFrame("Button", nil, card2, "UIPanelButtonTemplate")
    btnPl:SetSize(299, 24)
    btnPl:SetPoint("TOPLEFT", 14, -46)
    btnPl:SetText(L["PRESET_PL_LR"])
    if Offhand.SetTooltip then Offhand:SetTooltip(btnPl, L["PRESET_PL_LR_TIP_TITLE"], L["PRESET_PL_LR_TIP_DESC"]) end

    local btnPr = CreateFrame("Button", nil, card2, "UIPanelButtonTemplate")
    btnPr:SetSize(299, 24)
    btnPr:SetPoint("LEFT", btnPl, "RIGHT", 10, 0)
    btnPr:SetText(L["PRESET_GL_PR"])
    if Offhand.SetTooltip then Offhand:SetTooltip(btnPr, L["PRESET_GL_PR_TIP_TITLE"], L["PRESET_GL_PR_TIP_DESC"]) end

    local btnDual = CreateFrame("Button", nil, card2, "UIPanelButtonTemplate")
    btnDual:SetSize(608, 24)
    btnDual:SetPoint("TOPLEFT", 14, -90)
    btnDual:SetText(L["PRESET_DUAL_LANDSCAPE"])  
    if Offhand.SetTooltip then Offhand:SetTooltip(btnDual, L["PRESET_DUAL_LANDSCAPE_TIP_TITLE"], L["PRESET_DUAL_LANDSCAPE_TIP_DESC"]) end

    local btnVt = CreateFrame("Button", nil, card2, "UIPanelButtonTemplate")
    btnVt:SetSize(299, 24)
    btnVt:SetPoint("TOPLEFT", 14, -68)
    btnVt:SetText(L["PRESET_STACK_TOP"])

    local btnVb = CreateFrame("Button", nil, card2, "UIPanelButtonTemplate")
    btnVb:SetSize(299, 24)
    btnVb:SetPoint("LEFT", btnVt, "RIGHT", 10, 0)
    btnVb:SetText(L["PRESET_STACK_BOTTOM"])

    local arLabel = card2:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    arLabel:SetPoint("TOPLEFT", card2, "TOPLEFT", 14, -116)
    arLabel:SetText(L["WIZARD_LABEL_AR"])
    f.aspectLabel = arLabel

    local btn169 = CreateFrame("Button", nil, card2, "UIPanelButtonTemplate")
    btn169:SetSize(196, 24)
    btn169:SetPoint("TOPLEFT", card2, "TOPLEFT", 14, -136)
    btn169:SetText(L["AR_16_9"])
    if Offhand.SetTooltip then Offhand:SetTooltip(btn169, L["AR_16_9_TIP_TITLE"], L["AR_16_9_TIP_DESC"]) end

    local btn219 = CreateFrame("Button", nil, card2, "UIPanelButtonTemplate")
    btn219:SetSize(196, 24)
    btn219:SetPoint("LEFT", btn169, "RIGHT", 10, 0)
    btn219:SetText(L["AR_21_9"])
    if Offhand.SetTooltip then Offhand:SetTooltip(btn219, L["AR_21_9_TIP_TITLE"], L["AR_21_9_TIP_DESC"]) end

    local btnFill = CreateFrame("Button", nil, card2, "UIPanelButtonTemplate")
    btnFill:SetSize(196, 24)
    btnFill:SetPoint("LEFT", btn219, "RIGHT", 10, 0)
    btnFill:SetText(L["AR_FILL"])
    if Offhand.SetTooltip then Offhand:SetTooltip(btnFill, L["AR_FILL_TIP_TITLE"], L["AR_FILL_TIP_DESC"]) end
    f.aspectButtons = { btn169, btn219, btnFill }

    local exactTopologyHelp = card2:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    exactTopologyHelp:SetPoint("TOPLEFT", card2, "TOPLEFT", 14, -166)
    exactTopologyHelp:SetPoint("TOPRIGHT", card2, "TOPRIGHT", -14, -166)
    exactTopologyHelp:SetJustifyH("CENTER")
    if exactTopologyHelp.SetWordWrap then exactTopologyHelp:SetWordWrap(true) end
    f.exactTopologyHelp = exactTopologyHelp

    btnPl:SetScript("OnClick", function()
        Offhand.db.layoutPreset = "PORTRAIT_LEFT_LANDSCAPE_RIGHT"
        Offhand.db.primaryPosition = "RIGHT"
        f:UpdateState()
        Offhand:ApplyFullLayout()
    end)

    btnPr:SetScript("OnClick", function()
        Offhand.db.layoutPreset = "PORTRAIT_LEFT_LANDSCAPE_RIGHT"
        Offhand.db.primaryPosition = "LEFT"
        f:UpdateState()
        Offhand:ApplyFullLayout()
    end)

    btnDual:SetScript("OnClick", function()
        Offhand.db.layoutPreset = "LANDSCAPE_DUAL"
        Offhand.db.primaryPosition = "LEFT"
        Offhand.db.deckWidthRatio = 0.50
        f:UpdateState()
        Offhand:ApplyFullLayout()
    end)

    btnVt:SetScript("OnClick", function()
        Offhand.db.layoutPreset = "STACKED_VERTICAL"
        Offhand.db.primaryPosition = "TOP"
        f:UpdateState()
        Offhand:ApplyFullLayout()
    end)

    btnVb:SetScript("OnClick", function()
        Offhand.db.layoutPreset = "STACKED_VERTICAL"
        Offhand.db.primaryPosition = "BOTTOM"
        f:UpdateState()
        Offhand:ApplyFullLayout()
    end)

    btn169:SetScript("OnClick", function()
        Offhand.db.aspectRatioMode = "16_9"
        f:UpdateState()
        Offhand:ApplyFullLayout()
    end)

    btn219:SetScript("OnClick", function()
        Offhand.db.aspectRatioMode = "21_9"
        f:UpdateState()
        Offhand:ApplyFullLayout()
    end)

    btnFill:SetScript("OnClick", function()
        Offhand.db.aspectRatioMode = "FILL"
        f:UpdateState()
        Offhand:ApplyFullLayout()
    end)

    -- ========================================================================
    -- CARD 3: BEZEL SEAM ALIGNMENT & LASER GUIDE
    -- ========================================================================
    local card3 = CreateWizardCard(f, L["WIZARD_CARD3_TITLE"], -402, 136)

    local seamHelp = card3:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    seamHelp:SetPoint("TOPLEFT", 14, -28)
    seamHelp:SetPoint("TOPRIGHT", -14, -28)
    seamHelp:SetJustifyH("LEFT")
    seamHelp:SetText(L["WIZARD_SEAM_INSTRUCTION"])
    f.seamHelp = seamHelp

    local seamTitle = card3:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    seamTitle:SetPoint("TOPLEFT", 14, -60)
    seamTitle:SetText(L["WIZARD_LABEL_SEAM"])
    f.seamTitle = seamTitle

    local seamEditBox = CreateFrame("EditBox", nil, card3, BackdropTemplate())
    seamEditBox:SetSize(60, 20)
    seamEditBox:SetPoint("LEFT", seamTitle, "RIGHT", 10, 0)
    seamEditBox:SetAutoFocus(false)
    if seamEditBox.SetFontObject then seamEditBox:SetFontObject("GameFontHighlightSmall") end
    if seamEditBox.SetJustifyH then seamEditBox:SetJustifyH("CENTER") end
    if seamEditBox.SetBackdrop then
        seamEditBox:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        seamEditBox:SetBackdropColor(0.04, 0.04, 0.06, 0.9)
        seamEditBox:SetBackdropBorderColor(0.35, 0.33, 0.28, 0.9)
    end
    seamEditBox:SetText(string.format("%.1f%%", ((Offhand.db and Offhand.db.deckWidthRatio) or 0.36) * 100))
    f.seamEditBox = seamEditBox
    if Offhand.SetTooltip then
        Offhand:SetTooltip(seamEditBox, L["WIZARD_SEAM_EDIT_TIP_TITLE"], L["WIZARD_SEAM_EDIT_TIP_DESC"])
    end

    -- seamValText: lightweight stub without visual output -- the editBox already shows the value.
    -- Kept as a real object so tests and UpdateState calls remain compatible.
    local seamValTextStub = { _text = "" }
    seamValTextStub.SetText = function(self, t) self._text = t or "" end
    seamValTextStub.GetText = function(self) return self._text end
    local seamValText = seamValTextStub
    f.seamValText = seamValText

    -- Seam Slider
    local seamSlider = CreateFrame("Slider", nil, card3, BackdropTemplate())
    seamSlider:SetOrientation("HORIZONTAL")
    seamSlider:SetSize(280, 16)
    seamSlider:SetPoint("TOPLEFT", 14, -80)
    seamSlider:SetMinMaxValues(0.15, 0.80)
    seamSlider:SetValueStep(0.005)
    seamSlider:SetObeyStepOnDrag(true)
    seamSlider:EnableMouse(true)
    seamSlider:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    seamSlider:SetBackdropColor(0.06, 0.06, 0.08, 0.95)
    seamSlider:SetBackdropBorderColor(0.40, 0.38, 0.30, 0.9)

    local thumb = seamSlider:CreateTexture(nil, "OVERLAY")
    if thumb and thumb.SetTexture then
        thumb:SetTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    elseif thumb and thumb.SetColorTexture then
        thumb:SetColorTexture(1.0, 0.82, 0.0, 1.0)
    end
    if thumb and thumb.SetSize then
        thumb:SetSize(18, 20)
    end
    seamSlider:SetThumbTexture(thumb)
    seamSlider.thumb = thumb
    Controls.StyleSlider(seamSlider)

    seamSlider.SetValueDirect = function(self, val)
        if not Controls.IsSliderEnabled(self) then return end
        self._isDirect = true
        self:SetValue(val)
        self._isDirect = nil
    end

    local function CommitSeamEditBox()
        if not Controls.IsSliderEnabled(seamSlider) then
            seamEditBox:SetText(string.format("%.1f%%", ((Offhand.db and Offhand.db.deckWidthRatio) or 0.36) * 100))
            if seamEditBox.ClearFocus then seamEditBox:ClearFocus() end
            return
        end
        local txt = seamEditBox:GetText()
        local parsed = Offhand.ParseSliderInput and Offhand:ParseSliderInput(txt, 0.15, 0.80, 0.005, "%.1f%%")
        if parsed then
            seamSlider:SetValueDirect(parsed)
            seamEditBox:SetText(string.format("%.1f%%", parsed * 100))
        else
            local cur = (Offhand.db and Offhand.db.deckWidthRatio) or 0.36
            seamEditBox:SetText(string.format("%.1f%%", cur * 100))
        end
        if seamEditBox.ClearFocus then seamEditBox:ClearFocus() end
    end

    seamEditBox:SetScript("OnEnterPressed", function() CommitSeamEditBox() end)
    seamEditBox:SetScript("OnEscapePressed", function(s)
        local cur = (Offhand.db and Offhand.db.deckWidthRatio) or 0.36
        s:SetText(string.format("%.1f%%", cur * 100))
        if s.ClearFocus then s:ClearFocus() end
    end)
    seamEditBox:SetScript("OnEditFocusLost", function(s)
        CommitSeamEditBox()
        Controls.SetInputFocused(s, false)
    end)
    seamEditBox:SetScript("OnEditFocusGained", function(s)
        if s.HighlightText then s:HighlightText() end
        Controls.SetInputFocused(s, true)
    end)

    local btnMinus = CreateFrame("Button", nil, card3, "UIPanelButtonTemplate")
    btnMinus:SetSize(46, 22)
    btnMinus:SetPoint("LEFT", seamSlider, "RIGHT", 12, 0)
    btnMinus:SetText(L["BTN_SEAM_MINUS"])
    if Offhand.SetTooltip then Offhand:SetTooltip(btnMinus, L["BTN_SEAM_MINUS_TIP_TITLE"], L["BTN_SEAM_MINUS_TIP_DESC"]) end

    local btnPlus = CreateFrame("Button", nil, card3, "UIPanelButtonTemplate")
    btnPlus:SetSize(46, 22)
    btnPlus:SetPoint("LEFT", btnMinus, "RIGHT", 4, 0)
    btnPlus:SetText(L["BTN_SEAM_PLUS"])
    if Offhand.SetTooltip then Offhand:SetTooltip(btnPlus, L["BTN_SEAM_PLUS_TIP_TITLE"], L["BTN_SEAM_PLUS_TIP_DESC"]) end

    local btnLaser = CreateFrame("Button", nil, card3, "UIPanelButtonTemplate")
    btnLaser:SetSize(138, 22)
    btnLaser:SetPoint("LEFT", btnPlus, "RIGHT", 12, 0)
    btnLaser:SetText(L["BTN_LASER_TOGGLE"])
    f.laserButton = btnLaser
    seamSlider.btnMinus, seamSlider.btnPlus, seamSlider.editBox = btnMinus, btnPlus, seamEditBox
    if Offhand.SetTooltip then Offhand:SetTooltip(btnLaser, L["BTN_LASER_TOGGLE_TIP_TITLE"], L["BTN_LASER_TOGGLE_TIP_DESC"]) end

    seamSlider:SetScript("OnMouseDown", function(self, button)
        if not Controls.IsSliderEnabled(self) then return end
        if button == "LeftButton" then self.isDragging = true end
    end)

    seamSlider:SetScript("OnMouseUp", function(self, button)
        if button ~= "LeftButton" then return end
        self.isDragging = false
        if self._pendingApply then
            self._pendingApply = false
            self:SetScript("OnUpdate", nil)
            Offhand:ApplyFullLayout()
            if f.UpdateState then f:UpdateState() end
        end
    end)

    seamSlider:SetScript("OnHide", function(self)
        if Controls.EndSliderInteraction(self) then Offhand:ApplyFullLayout() end
    end)

    seamSlider:SetScript("OnValueChanged", function(self, val, userInput)
        if not Controls.IsSliderEnabled(self) then return end
        val = math.floor((val / 0.005) + 0.5) * 0.005
        Offhand.db.deckWidthRatio = val
        seamValText:SetText(string.format(L["WIZARD_SEAM_VAL_FMT"], val * 100))
        if seamEditBox and not (seamEditBox.HasFocus and seamEditBox:HasFocus()) then
            seamEditBox:SetText(string.format("%.1f%%", val * 100))
        end
        if Offhand.Options and Offhand.Options.ShowSeamGuide and Offhand.Options:IsSeamGuideShown() then
            Offhand.Options:ShowSeamGuide(val)
        end
        f:UpdateLaserButton()

        if self._isDirect then
            self._pendingApply = false
            self:SetScript("OnUpdate", nil)
            Offhand:ApplyFullLayout()
            if f.UpdateState then f:UpdateState() end
            return
        end

        local isMouseDown = (IsMouseButtonDown and IsMouseButtonDown("LeftButton")) or (self.isDragging == true) or (userInput == true)
        if isMouseDown then
            self._pendingApply = true
            self:SetScript("OnUpdate", function(s)
                local stillDown = (IsMouseButtonDown and IsMouseButtonDown("LeftButton"))
                if not stillDown then
                    s.isDragging = false
                    if s._pendingApply then
                        s._pendingApply = false
                        s:SetScript("OnUpdate", nil)
                        Offhand:ApplyFullLayout()
                    end
                end
            end)
        else
            self._pendingApply = false
            self:SetScript("OnUpdate", nil)
            Offhand:ApplyFullLayout()
        end
    end)
    if Offhand.SetTooltip then Offhand:SetTooltip(seamSlider, L["SLIDER_SEAM_WIDTH_TIP_TITLE"], L["SLIDER_SEAM_WIDTH_TIP_DESC"]) end

    btnMinus:SetScript("OnClick", function()
        local current = seamSlider:GetValue() or 0.36
        seamSlider:SetValueDirect(math.max(0.15, current - 0.01))
    end)

    btnPlus:SetScript("OnClick", function()
        local current = seamSlider:GetValue() or 0.36
        seamSlider:SetValueDirect(math.min(0.80, current + 0.01))
    end)

    btnLaser:SetScript("OnClick", function()
        if Offhand.Options then
            if Offhand.Options:IsSeamGuideShown() then
                Offhand.Options:HideSeamGuide()
            else
                Offhand.Options:ShowSeamGuide(Offhand.db.deckWidthRatio)
            end
            f:UpdateLaserButton()
        end
    end)

    -- Quick Seam Presets
    local btnSeam36 = CreateFrame("Button", nil, card3, "UIPanelButtonTemplate")
    btnSeam36:SetSize(196, 24)
    btnSeam36:SetPoint("TOPLEFT", 14, -110)
    btnSeam36:SetText(L["WIZARD_PRESET_SEAM_36"])
    btnSeam36:SetScript("OnClick", function() seamSlider:SetValue(0.36) end)
    if Offhand.SetTooltip then Offhand:SetTooltip(btnSeam36, L["WIZARD_PRESET_SEAM_36_TIP_TITLE"], L["WIZARD_PRESET_SEAM_36_TIP_DESC"]) end

    local btnSeam50 = CreateFrame("Button", nil, card3, "UIPanelButtonTemplate")
    btnSeam50:SetSize(196, 24)
    btnSeam50:SetPoint("LEFT", btnSeam36, "RIGHT", 10, 0)
    btnSeam50:SetText(L["WIZARD_PRESET_SEAM_50"])
    btnSeam50:SetScript("OnClick", function() seamSlider:SetValue(0.50) end)
    if Offhand.SetTooltip then Offhand:SetTooltip(btnSeam50, L["WIZARD_PRESET_SEAM_50_TIP_TITLE"], L["WIZARD_PRESET_SEAM_50_TIP_DESC"]) end

    local btnSeam55 = CreateFrame("Button", nil, card3, "UIPanelButtonTemplate")
    btnSeam55:SetSize(196, 24)
    btnSeam55:SetPoint("LEFT", btnSeam50, "RIGHT", 10, 0)
    btnSeam55:SetText(L["WIZARD_PRESET_SEAM_55"])
    btnSeam55:SetScript("OnClick", function() seamSlider:SetValue(0.55) end)
    if Offhand.SetTooltip then Offhand:SetTooltip(btnSeam55, L["WIZARD_PRESET_SEAM_55_TIP_TITLE"], L["WIZARD_PRESET_SEAM_55_TIP_DESC"]) end

    -- ========================================================================
    -- CARD 4: GLOBAL UI SCALE & CALIBRATION (CONTINUOUS SLIDER)
    -- ========================================================================
    local card4 = CreateWizardCard(f, L["WIZARD_CARD4_TITLE"], -546, 136)

    local scaleHelp = card4:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    scaleHelp:SetPoint("TOPLEFT", 14, -28)
    scaleHelp:SetPoint("TOPRIGHT", -14, -28)
    scaleHelp:SetJustifyH("LEFT")
    scaleHelp:SetText(L["WIZARD_UI_SCALE_INSTRUCTION"])

    local scaleTitle = card4:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    scaleTitle:SetPoint("TOPLEFT", 14, -48)
    scaleTitle:SetText(L["WIZARD_LABEL_UI_SCALE"])

    local scaleEditBox = CreateFrame("EditBox", nil, card4, BackdropTemplate())
    scaleEditBox:SetSize(60, 20)
    scaleEditBox:SetPoint("LEFT", scaleTitle, "RIGHT", 10, 0)
    scaleEditBox:SetAutoFocus(false)
    if scaleEditBox.SetFontObject then scaleEditBox:SetFontObject("GameFontHighlightSmall") end
    if scaleEditBox.SetJustifyH then scaleEditBox:SetJustifyH("CENTER") end
    if scaleEditBox.SetBackdrop then
        scaleEditBox:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        scaleEditBox:SetBackdropColor(0.04, 0.04, 0.06, 0.9)
        scaleEditBox:SetBackdropBorderColor(0.35, 0.33, 0.28, 0.9)
    end
    scaleEditBox:SetText(string.format("%.0f%%", ((Offhand.db and Offhand.db.hudScale) or 0.70) * 100))
    f.scaleEditBox = scaleEditBox
    if Offhand.SetTooltip then
        Offhand:SetTooltip(scaleEditBox, L["WIZARD_SCALE_EDIT_TIP_TITLE"], L["WIZARD_SCALE_EDIT_TIP_DESC"])
    end

    -- scaleValText: lightweight stub without visual output -- the editBox already shows the value.
    -- Kept as a real object so tests and UpdateState calls remain compatible.
    local scaleValTextStub = { _text = "" }
    scaleValTextStub.SetText = function(self, t) self._text = t or "" end
    scaleValTextStub.GetText = function(self) return self._text end
    local scaleValText = scaleValTextStub
    f.scaleValText = scaleValText

    -- Continuous UI Scale Slider
    local scaleSlider = CreateFrame("Slider", nil, card4, BackdropTemplate())
    scaleSlider:SetOrientation("HORIZONTAL")
    scaleSlider:SetSize(280, 16)
    scaleSlider:SetPoint("TOPLEFT", 14, -68)
    scaleSlider:SetMinMaxValues(0.25, 1.25)
    scaleSlider:SetValueStep(0.01)
    scaleSlider:SetObeyStepOnDrag(true)
    scaleSlider:EnableMouse(true)
    scaleSlider:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    scaleSlider:SetBackdropColor(0.06, 0.06, 0.08, 0.95)
    scaleSlider:SetBackdropBorderColor(0.40, 0.38, 0.30, 0.9)

    local scaleThumb = scaleSlider:CreateTexture(nil, "OVERLAY")
    if scaleThumb and scaleThumb.SetTexture then
        thumb = scaleThumb
        scaleThumb:SetTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    elseif scaleThumb and scaleThumb.SetColorTexture then
        scaleThumb:SetColorTexture(1.0, 0.82, 0.0, 1.0)
    end
    if scaleThumb and scaleThumb.SetSize then
        scaleThumb:SetSize(18, 20)
    end
    scaleSlider:SetThumbTexture(scaleThumb)
    scaleSlider.thumb = scaleThumb
    Controls.StyleSlider(scaleSlider)

    scaleSlider.SetValueDirect = function(self, val)
        self._isDirect = true
        self:SetValue(val)
        self._isDirect = nil
    end

    local function CommitScaleEditBox()
        local txt = scaleEditBox:GetText()
        local parsed = Offhand.ParseSliderInput and Offhand:ParseSliderInput(txt, 0.25, 1.25, 0.01, "%.0f%%")
        if parsed then
            scaleSlider:SetValueDirect(parsed)
            scaleEditBox:SetText(string.format("%.0f%%", parsed * 100))
        else
            local cur = (Offhand.db and Offhand.db.hudScale) or 0.70
            scaleEditBox:SetText(string.format("%.0f%%", cur * 100))
        end
        if scaleEditBox.ClearFocus then scaleEditBox:ClearFocus() end
    end

    scaleEditBox:SetScript("OnEnterPressed", function() CommitScaleEditBox() end)
    scaleEditBox:SetScript("OnEscapePressed", function(s)
        local cur = (Offhand.db and Offhand.db.hudScale) or 0.70
        s:SetText(string.format("%.0f%%", cur * 100))
        if s.ClearFocus then s:ClearFocus() end
    end)
    scaleEditBox:SetScript("OnEditFocusLost", function(s)
        CommitScaleEditBox()
        Controls.SetInputFocused(s, false)
    end)
    scaleEditBox:SetScript("OnEditFocusGained", function(s)
        if s.HighlightText then s:HighlightText() end
        Controls.SetInputFocused(s, true)
    end)

    local btnScaleMinus = CreateFrame("Button", nil, card4, "UIPanelButtonTemplate")
    btnScaleMinus:SetSize(46, 22)
    btnScaleMinus:SetPoint("LEFT", scaleSlider, "RIGHT", 12, 0)
    btnScaleMinus:SetText(L["BTN_SEAM_MINUS"])
    if Offhand.SetTooltip then Offhand:SetTooltip(btnScaleMinus, L["WIZARD_BTN_SCALE_DOWN_TIP_TITLE"], L["WIZARD_BTN_SCALE_DOWN_TIP_DESC"]) end

    local btnScalePlus = CreateFrame("Button", nil, card4, "UIPanelButtonTemplate")
    btnScalePlus:SetSize(46, 22)
    btnScalePlus:SetPoint("LEFT", btnScaleMinus, "RIGHT", 4, 0)
    btnScalePlus:SetText(L["BTN_SEAM_PLUS"])
    if Offhand.SetTooltip then Offhand:SetTooltip(btnScalePlus, L["WIZARD_BTN_SCALE_UP_TIP_TITLE"], L["WIZARD_BTN_SCALE_UP_TIP_DESC"]) end

    local btnScaleReset = CreateFrame("Button", nil, card4, "UIPanelButtonTemplate")
    btnScaleReset:SetSize(138, 22)
    btnScaleReset:SetPoint("LEFT", btnScalePlus, "RIGHT", 12, 0)
    btnScaleReset:SetText(L["WIZARD_BTN_SCALE_RESET"])
    btnScaleReset:SetScript("OnClick", function()
        scaleSlider:SetValueDirect(0.70)
    end)
    if Offhand.SetTooltip then Offhand:SetTooltip(btnScaleReset, L["WIZARD_BTN_SCALE_RESET_TIP_TITLE"], L["WIZARD_BTN_SCALE_RESET_TIP_DESC"]) end

    -- Physical-pixel-delta drag controller (scale-independent)
    local DRAG_PIXELS = 600
    local function StartScaleDrag(self)
        self._dragStartX = GetCursorPosition and select(1, GetCursorPosition()) or 0
        self._dragStartVal = self:GetValue()
        self._isCustomDrag = true
        self:SetScript("OnUpdate", function(s)
            if not s._isCustomDrag then s:SetScript("OnUpdate", nil) return end
            local curX = GetCursorPosition and select(1, GetCursorPosition()) or s._dragStartX
            local pixelDelta = curX - s._dragStartX
            local newVal = math.max(0.25, math.min(1.25, s._dragStartVal + pixelDelta * (1.00 / DRAG_PIXELS)))
            newVal = math.floor((newVal / 0.01) + 0.5) * 0.01
            Offhand.db.hudScale = newVal
            scaleValText:SetText(string.format(L["WIZARD_SCALE_VAL_FMT"], newVal * 100))
            if scaleEditBox and not (scaleEditBox.HasFocus and scaleEditBox:HasFocus()) then
                scaleEditBox:SetText(string.format("%.0f%%", newVal * 100))
            end
            s:SetValue(newVal)
        end)
    end

    scaleSlider:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then StartScaleDrag(self) end
    end)

    scaleSlider:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and self._isCustomDrag then
            Controls.EndSliderInteraction(self)
            local finalValue = math.max(0.25, math.min(1.25, self:GetValue() or Offhand.db.hudScale or 0.70))
            finalValue = math.floor(finalValue / 0.01 + 0.5) * 0.01
            Offhand.db.hudScale = finalValue
            scaleValText:SetText(string.format(L["WIZARD_SCALE_VAL_FMT"], finalValue * 100))
            scaleEditBox:SetText(string.format("%.0f%%", finalValue * 100))
            Offhand:ApplyFullLayout()
        end
    end)

    scaleSlider:SetScript("OnHide", function(self)
        if Controls.EndSliderInteraction(self) then Offhand:ApplyFullLayout() end
    end)

    scaleSlider:SetScript("OnValueChanged", function(self, val, userInput)
        if self._isCustomDrag then return end
        val = math.floor((val / 0.01) + 0.5) * 0.01
        Offhand.db.hudScale = val
        scaleValText:SetText(string.format(L["WIZARD_SCALE_VAL_FMT"], val * 100))
        if scaleEditBox and not (scaleEditBox.HasFocus and scaleEditBox:HasFocus()) then
            scaleEditBox:SetText(string.format("%.0f%%", val * 100))
        end
        if self._isDirect then
            self._pendingApply = false
            self:SetScript("OnUpdate", nil)
            Offhand:ApplyFullLayout()
            if f.UpdateState then f:UpdateState() end
            return
        end
        Offhand:ApplyFullLayout()
        if f.UpdateState then f:UpdateState() end
    end)
    if Offhand.SetTooltip then Offhand:SetTooltip(scaleSlider, L["WIZARD_UI_SCALE_TIP_TITLE"], L["WIZARD_UI_SCALE_TIP_DESC"]) end

    btnScaleMinus:SetScript("OnClick", function()
        local current = scaleSlider:GetValue() or 0.70
        scaleSlider:SetValueDirect(math.max(0.25, current - 0.01))
    end)

    btnScalePlus:SetScript("OnClick", function()
        local current = scaleSlider:GetValue() or 0.70
        scaleSlider:SetValueDirect(math.min(1.25, current + 0.01))
    end)

    -- Quick Scale Preset Buttons
    local btnHud56 = CreateFrame("Button", nil, card4, "UIPanelButtonTemplate")
    btnHud56:SetSize(145, 24)
    btnHud56:SetPoint("TOPLEFT", 14, -98)
    btnHud56:SetText(L["WIZARD_PRESET_SCALE_56"])
    btnHud56:SetScript("OnClick", function() scaleSlider:SetValueDirect(0.56) end)
    if Offhand.SetTooltip then Offhand:SetTooltip(btnHud56, L["WIZARD_PRESET_SCALE_56_TIP_TITLE"], L["WIZARD_PRESET_SCALE_56_TIP_DESC"]) end

    local btnHud65 = CreateFrame("Button", nil, card4, "UIPanelButtonTemplate")
    btnHud65:SetSize(145, 24)
    btnHud65:SetPoint("LEFT", btnHud56, "RIGHT", 9, 0)
    btnHud65:SetText(L["WIZARD_PRESET_SCALE_65"])
    btnHud65:SetScript("OnClick", function() scaleSlider:SetValueDirect(0.65) end)
    if Offhand.SetTooltip then Offhand:SetTooltip(btnHud65, L["WIZARD_PRESET_SCALE_65_TIP_TITLE"], L["WIZARD_PRESET_SCALE_65_TIP_DESC"]) end

    local btnHud70 = CreateFrame("Button", nil, card4, "UIPanelButtonTemplate")
    btnHud70:SetSize(145, 24)
    btnHud70:SetPoint("LEFT", btnHud65, "RIGHT", 9, 0)
    btnHud70:SetText(L["WIZARD_PRESET_SCALE_70"])
    btnHud70:SetScript("OnClick", function() scaleSlider:SetValueDirect(0.70) end)
    if Offhand.SetTooltip then Offhand:SetTooltip(btnHud70, L["WIZARD_PRESET_SCALE_70_TIP_TITLE"], L["WIZARD_PRESET_SCALE_70_TIP_DESC"]) end

    local btnHud100 = CreateFrame("Button", nil, card4, "UIPanelButtonTemplate")
    btnHud100:SetSize(145, 24)
    btnHud100:SetPoint("LEFT", btnHud70, "RIGHT", 9, 0)
    btnHud100:SetText(L["WIZARD_PRESET_SCALE_100"])
    btnHud100:SetScript("OnClick", function() scaleSlider:SetValueDirect(1.00) end)
    if Offhand.SetTooltip then Offhand:SetTooltip(btnHud100, L["WIZARD_PRESET_SCALE_100_TIP_TITLE"], L["WIZARD_PRESET_SCALE_100_TIP_DESC"]) end
    f.scalePresetButtons = { btnHud56, btnHud65, btnHud70, btnHud100 }

    -- ========================================================================
    -- CARD 5: GENERATED MAINHAND HUD LAYOUT (FOREVER / RETAIL)
    -- ========================================================================
    local card5 = CreateWizardCard(f, L["MAINHAND_LAYOUT_CREATE"], -690, 216)

    local layoutHelp = card5:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    layoutHelp:SetPoint("TOPLEFT", card5, "TOPLEFT", 14, -32)
    layoutHelp:SetPoint("TOPRIGHT", card5, "TOPRIGHT", -14, -32)
    layoutHelp:SetPoint("BOTTOMLEFT", card5, "BOTTOMLEFT", 14, 50)
    layoutHelp:SetPoint("BOTTOMRIGHT", card5, "BOTTOMRIGHT", -14, 50)
    layoutHelp:SetJustifyH("LEFT")
    if layoutHelp.SetJustifyV then layoutHelp:SetJustifyV("TOP") end
    if layoutHelp.SetWordWrap then layoutHelp:SetWordWrap(true) end
    layoutHelp:SetText(L["WIZARD_STEP_5_BODY"])
    f.mainhandLayoutHelp = layoutHelp

    local layoutStatus = card5:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    layoutStatus:SetPoint("BOTTOMLEFT", card5, "BOTTOMLEFT", 14, 20)
    layoutStatus:SetPoint("BOTTOMRIGHT", card5, "BOTTOMRIGHT", -14, 20)
    layoutStatus:SetJustifyH("CENTER")
    f.mainhandLayoutStatus = layoutStatus

    -- ========================================================================
    -- FOOTER ACTIONS
    -- ========================================================================
    local advBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    advBtn:SetSize(170, 28)
    advBtn:SetPoint("BOTTOMLEFT", 18, 14)
    advBtn:SetText(L["BTN_SETTINGS"])
    advBtn:SetScript("OnClick", function()
        if Offhand.IsSetupComplete and not Offhand:IsSetupComplete() then
            Wizard.settingsResumeStep = f.step
        end
        Wizard.openedFromOptions = false
        Wizard:Close()
        if Offhand.Options and Offhand.Options.Open then
            Offhand.Options:Open()
        end
    end)
    if Offhand.SetTooltip then Offhand:SetTooltip(advBtn, L["WIZARD_BTN_ADVANCED_TIP_TITLE"], L["WIZARD_BTN_ADVANCED_TIP_DESC"]) end

    local finishBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.finishBtn = finishBtn
    finishBtn:SetSize(170, 28)
    finishBtn:SetPoint("BOTTOMRIGHT", -18, 14)
    finishBtn:SetText("|cffffd100" .. L["WIZARD_BTN_FINISH"] .. "|r")

    local skipLayoutBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.skipLayoutBtn = skipLayoutBtn
    skipLayoutBtn:SetSize(220, 28)
    skipLayoutBtn:SetPoint("BOTTOMLEFT", 18, 14)
    skipLayoutBtn:SetText(L["WIZARD_SKIP_HUD_LAYOUT"])
    skipLayoutBtn:Hide()

    local validationStatus
    local function SetValidationText(message)
        validationStatus:SetText(message)
        if f.LayoutStep and f.step then f:LayoutStep() end
    end

    local function ValidateTopology()
        SetValidationText("")
        if PlacementFailure() then
            f:ShowRecovery("span")
            return false
        end
        local currentInfo = Wizard:DetectTopology()
        if currentInfo.topologyStatus == "MISMATCH" then
            local message = Offhand.Options:GetMainhandLayoutFailureText("span")
            statusText:SetText("|cffff5555" .. message .. "|r")
            SetValidationText("|cffff5555" .. message .. "|r")
            return false
        end
        if currentInfo.exactTopology and currentInfo.companionVersionStatus == "MISMATCH" then
            local message = string.format(L["WIZARD_STATUS_COMPANION_MISMATCH"],
                currentInfo.companionVersion or "?", currentInfo.expectedCompanionVersion or "?")
            statusText:SetText("|cffff5555" .. message .. "|r")
            SetValidationText("|cffff5555" .. message .. "|r")
            return false
        end
        return true
    end

    local function CompleteSetup(deferMainhandLayout)
        if not ValidateTopology() then return end
        if type(OffhandCharDB) == "table" then
            OffhandCharDB.wizardRecoveryStep = nil
            OffhandCharDB.wizardProgressStep = nil
            OffhandCharDB.hudSetupReminder = deferMainhandLayout == true or nil
            OffhandCharDB.hudSetupReminderDeclined = nil
        end
        if f.totalSteps > 4 and Offhand.Mainhand
            and type(Offhand.Mainhand.SetEditModeLayoutDeferred) == "function" then
            Offhand.Mainhand:SetEditModeLayoutDeferred(deferMainhandLayout == true)
        end
        if Offhand.MarkSetupComplete then
            Offhand:MarkSetupComplete()
        elseif Offhand.db then
            Offhand.db.firstRunComplete = true
        end
        Wizard.openedFromOptions = false
        Wizard:Close()
        Offhand:ApplyFullLayout()
        if Offhand.Print then
            if deferMainhandLayout then
                Offhand:Print(L["WIZARD_SKIP_HUD_COMPLETE"])
                Offhand:Print(L["WIZARD_SKIP_HUD_NEXT"])
            else
                Offhand:Print(L["CONFIG_SAVED"])
                Offhand:Print(ReadinessSummary(L["READINESS_HUD_READY"]))
                Offhand:Print(L["READINESS_COLD_START"])
            end
        end
    end

    skipLayoutBtn:SetScript("OnClick", function()
        if not ValidateTopology() then return end
        Offhand:ShowPopup("OFFHAND_WIZARD_SKIP_MAINHAND_LAYOUT", nil, nil, function()
            CompleteSetup(true)
        end)
    end)
    f.advBtn = advBtn

    finishBtn:SetScript("OnClick", function()
        if f.recoveryReason then
            if f.recoveryReason == "maximum" then Wizard:OpenLayoutManagement()
            elseif f.recoveryAction == "reload" then Wizard:ReloadPlacement()
            else Wizard:ReturnToWindowSetup(f.recoveryMethod and 4 or 2) end
            return
        end
        if not ValidateTopology() then return end
        if f.step < 4 then f:SetStep(f.step + 1); return end
        if f.step == 4 then
            if f.totalSteps > 4 then
                f:SetStep(5)
                return
            end
            CompleteSetup()
            return
        end

        if UsesControllerLayout() and not CanCreateControllerLayout() then
            CompleteSetup(true)
            return
        end

        local ok, value, moved, activation = Offhand.Options:CreateMainhandHUDLayout()
        if not ok and value == "already" and Offhand.Mainhand
            and type(Offhand.Mainhand.GetLayoutStatus) == "function" then
            local existing = Offhand.Mainhand:GetLayoutStatus()
            if existing and existing.configured and existing.currentGeometry then
                ok = true
                value = existing.generatedName
                moved = existing.movedSystems
            end
        end
        if not ok then
            if value == "span" or value == "maximum" then
                f:ShowRecovery(value)
                return
            end
            local failure = Offhand.Options:GetMainhandLayoutFailureText(value)
            layoutStatus:SetText("|cffff5555" .. failure .. "|r")
            f:LayoutStep()
            return
        end
        if Offhand.Print then
            Offhand:Print(L["MAINHAND_LAYOUT_CREATED"], tostring(value), moved or 0)
        end
        CompleteSetup(false)
        if Offhand.Mainhand then
            if activation == "select" and Offhand.Mainhand.PromptManualLayoutSelection then
                Offhand.Mainhand:PromptManualLayoutSelection(value)
            elseif Offhand.Mainhand.PromptReload then
                Offhand.Mainhand:PromptReload()
            end
        end
    end)


    local backBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    backBtn:SetSize(100, 28)
    backBtn:SetPoint("RIGHT", finishBtn, "LEFT", -12, 0)
    backBtn:SetText(L["BTN_BACK"])
    backBtn:SetScript("OnClick", function() f:SetStep(f.step - 1) end)
    f.backBtn = backBtn
    local progress = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    f.progressText = progress
    progress:SetPoint("TOPLEFT", 18, -116)

    validationStatus = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    validationStatus:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 190, 54)
    validationStatus:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -18, 54)
    if validationStatus.SetHeight then validationStatus:SetHeight(54) end
    if validationStatus.SetJustifyH then validationStatus:SetJustifyH("CENTER") end
    if validationStatus.SetJustifyV then validationStatus:SetJustifyV("MIDDLE") end
    if validationStatus.SetWordWrap then validationStatus:SetWordWrap(true) end
    f.validationStatus = validationStatus
    for _, text in ipairs({ welcomeText, progress, topoText, recomText, statusText,
        layoutHelp, layoutStatus, validationStatus }) do
        if text.SetWordWrap then text:SetWordWrap(true) end
    end

    f.totalSteps = SupportsGeneratedMainhandLayout() and 5 or 4
    f.pages = {card1, card2, card3, card4}
    if f.totalSteps == 5 then
        f.pages[5] = card5
    else
        card5:Hide()
    end
    card3:SetHeight(208)
    local bottomControl = Offhand.Options:CreateBottomControl(card3)
    bottomControl:SetPoint("TOPLEFT", 14, -148)
    card3:SetHeight(math.max(208, 148 + bottomControl:GetHeight() + 14))
    for _, card in ipairs(f.pages) do
        card:ClearAllPoints()
        card:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -140)
    end

    local recoveryCard = CreateWizardCard(f, L["WIZARD_RECOVERY_SPAN_TITLE"], -140, 230)
    recoveryCard.title:SetWidth(600)
    recoveryCard.title:SetWordWrap(true)
    local recoveryBody = recoveryCard:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    recoveryBody:SetPoint("TOPLEFT", recoveryCard, "TOPLEFT", 14, -36)
    recoveryBody:SetPoint("TOPRIGHT", recoveryCard, "TOPRIGHT", -14, -36)
    recoveryBody:SetJustifyH("LEFT")
    if recoveryBody.SetJustifyV then recoveryBody:SetJustifyV("TOP") end
    recoveryBody:SetWordWrap(true)
    recoveryCard:Hide()
    local recoveryBack = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    recoveryBack:SetSize(260, 28)
    recoveryBack:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 18, 14)
    recoveryBack:Hide()
    f.recoveryCard, f.recoveryBody, f.recoveryBackButton = recoveryCard, recoveryBody, recoveryBack
    recoveryBack:SetScript("OnClick", function()
        if f.recoveryReason == "maximum" then f:SetStep(5); return end
        if f.recoveryMethod == "COMPANION" then Wizard:ReturnToWindowSetup()
        else f:SetStep(f.step) end
    end)
    local restartBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    restartBtn:SetSize(180, 24)
    restartBtn:SetText(L["WIZARD_RESTART"])
    restartBtn:Hide()
    restartBtn:SetScript("OnClick", function() Wizard:RestartCalibration() end)
    f.restartButton = restartBtn

    function f:ShowRecovery(reason)
        self.recoveryReason = reason
        welcomeText:SetText(L["WIZARD_RECOVERY_INTRO"])
        if Offhand.Options.HideSeamGuide then Offhand.Options:HideSeamGuide() end
        for _, card in ipairs(self.pages) do card:Hide() end
        advBtn:Hide(); skipLayoutBtn:Hide(); backBtn:Hide()
        restartBtn:Hide()
        local method = Offhand.GetOnboardingSetupMethod and Offhand:GetOnboardingSetupMethod()
        self.recoveryMethod = method
        self.recoveryAction = method == "COMPANION" and "reload" or "placement"
        local primaryKey = reason == "maximum" and "WIZARD_RECOVERY_OPEN_EDITMODE"
            or method == "COMPANION" and "ONBOARD_RELOAD_UI"
            or method and "WIZARD_RECOVERY_WINDOW_SETUP" or "WIZARD_RECOVERY_CHOOSE_METHOD"
        recoveryBack:SetText(L[reason == "maximum" and "WIZARD_RECOVERY_RETRY"
            or method == "COMPANION" and "WIZARD_RECOVERY_WINDOW_SETUP" or "WIZARD_RECOVERY_RECHECK"])
        SetShown(recoveryBack, reason == "maximum" or method ~= nil)
        finishBtn:SetSize(260, 28)
        finishBtn:SetText("|cffffd100" .. L[primaryKey] .. "|r")
        recoveryCard.sectionLabel = L[reason == "maximum" and "WIZARD_RECOVERY_MAX_TITLE" or "WIZARD_RECOVERY_SPAN_TITLE"]
        recoveryCard.title:SetText(recoveryCard.sectionLabel)
        recoveryBody:SetText(L[reason == "maximum" and "WIZARD_RECOVERY_MAX_BODY"
            or method == "COMPANION" and "WIZARD_RECOVERY_COMPANION_BODY"
            or method == "FANCYZONES" and "WIZARD_RECOVERY_FANCYZONES_BODY"
            or method == "MANUAL" and "WIZARD_RECOVERY_MANUAL_BODY" or "WIZARD_RECOVERY_CHOOSE_BODY"])
        validationStatus:SetText("")
        recoveryCard:Show()
        self:LayoutStep()
    end

    function f:LayoutStep()
        local card = self.recoveryReason and recoveryCard or self.pages[self.step or 1]
        if not card then return end
        if self.recoveryReason then
            local top = Controls.GetCardContentTop(card, 36)
            recoveryBody:ClearAllPoints()
            recoveryBody:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -top)
            local width = card:GetWidth() - 28
            recoveryBody:SetWidth(width)
            -- A previous constrained height can make native metrics describe
            -- ellipsized text. Clear it before measuring, then reserve every
            -- paragraph even while font metrics settle after a display change.
            local height = Controls.FitParagraphText(recoveryBody, recoveryBody:GetText(), width)
            card:SetHeight(top + height + 12)
        elseif self.step == 1 then
            local top = Controls.GetCardContentTop(card1, 28)
            local width = card1:GetWidth() - textLeft - 14
            if topoText.ClearAllPoints then topoText:ClearAllPoints() end
            topoText:SetPoint("TOPLEFT", card1, "TOPLEFT", textLeft, -top)
            topoText:SetPoint("TOPRIGHT", card1, "TOPRIGHT", -14, -top)
            if card1.logoIcon then
                if card1.logoIcon.ClearAllPoints then card1.logoIcon:ClearAllPoints() end
                card1.logoIcon:SetPoint("TOPLEFT", card1, "TOPLEFT", 14, -top)
            end
            top = top + Controls.MeasureWrappedText(topoText, topoText:GetText(), width) + 8
            if recomText.ClearAllPoints then recomText:ClearAllPoints() end
            recomText:SetPoint("TOPLEFT", card1, "TOPLEFT", textLeft, -top)
            recomText:SetPoint("TOPRIGHT", card1, "TOPRIGHT", -14, -top)
            top = top + Controls.MeasureWrappedText(recomText, recomText:GetText(), width) + 12
            local actionHeight = math.max(28,
                Controls.MeasureWrappedText(autoBtn:GetFontString(), autoBtn:GetText(), 590, 14) + 8)
            autoBtn:ClearAllPoints()
            autoBtn:SetPoint("TOPLEFT", card1, "TOPLEFT", 14, -top)
            autoBtn:SetSize(600, actionHeight)
            top = top + actionHeight + 12
            if statusText.ClearAllPoints then statusText:ClearAllPoints() end
            statusText:SetPoint("TOPLEFT", card1, "TOPLEFT", 14, -top)
            statusText:SetPoint("TOPRIGHT", card1, "TOPRIGHT", -14, -top)
            card1:SetHeight(top + Controls.MeasureWrappedText(statusText, statusText:GetText(), 600) + 14)
        elseif self.step == 5 then
            local top = Controls.GetCardContentTop(card5, 32)
            local helpHeight = Controls.FitParagraphText(layoutHelp, layoutHelp:GetText(), 600)
            if layoutHelp.ClearAllPoints then layoutHelp:ClearAllPoints() end
            layoutHelp:SetPoint("TOPLEFT", card5, "TOPLEFT", 14, -top)
            layoutHelp:SetPoint("TOPRIGHT", card5, "TOPRIGHT", -14, -top)
            if layoutHelp.SetHeight then layoutHelp:SetHeight(helpHeight) end
            top = top + helpHeight + 14
            if layoutStatus.ClearAllPoints then layoutStatus:ClearAllPoints() end
            layoutStatus:SetPoint("TOPLEFT", card5, "TOPLEFT", 14, -top)
            layoutStatus:SetPoint("TOPRIGHT", card5, "TOPRIGHT", -14, -top)
            card5:SetHeight(top + Controls.MeasureWrappedText(layoutStatus, layoutStatus:GetText(), 600) + 16)
        end
        local footerHeight = 28
        for _, button in ipairs({ advBtn, skipLayoutBtn, backBtn, finishBtn, recoveryBack }) do
            if button:IsShown() then
                footerHeight = math.max(footerHeight,
                    Controls.MeasureWrappedText(button:GetFontString(), button:GetText(), button:GetWidth() - 10, 14) + 8)
            end
        end
        local message = validationStatus:GetText() or ""
        local validationHeight = message ~= "" and Controls.FitParagraphText(validationStatus, message, 632) or 1
        local progressWidth = restartBtn:IsShown() and 434 or 632
        progress:SetWidth(progressWidth)
        local restartHeight = Controls.MeasureWrappedText(restartBtn:GetFontString(), restartBtn:GetText(), 170) + 8
        restartBtn:SetHeight(math.max(24, restartHeight))
        local layout = Controls.GetWizardLayout(
            Controls.MeasureWrappedText(welcomeText, welcomeText:GetText(), 632),
            math.max(Controls.MeasureWrappedText(progress, progress:GetText(), progressWidth),
                restartBtn:IsShown() and restartBtn:GetHeight() or 0),
            card:GetHeight(), validationHeight, footerHeight)
        self:SetHeight(layout.height)
        if progress.ClearAllPoints then progress:ClearAllPoints() end
        progress:SetPoint("TOPLEFT", self, "TOPLEFT", restartBtn:IsShown() and 216 or 18, -layout.progressTop)
        progress:SetWidth(progressWidth)
        restartBtn:ClearAllPoints()
        restartBtn:SetPoint("TOPLEFT", self, "TOPLEFT", 18, -layout.progressTop)
        card:ClearAllPoints()
        card:SetPoint("TOPLEFT", self, "TOPLEFT", 16, -layout.cardTop)
        if validationStatus.ClearAllPoints then validationStatus:ClearAllPoints() end
        validationStatus:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 18, layout.validationBottom)
        validationStatus:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -18, layout.validationBottom)
        validationStatus:SetHeight(layout.validationHeight)
        for _, button in ipairs({ advBtn, skipLayoutBtn, backBtn, finishBtn, recoveryBack }) do
            button:SetHeight(layout.footerHeight)
        end
        Controls.FitDialog(self, Offhand.Viewport and Offhand.Viewport:GetMetrics())
    end
    function f:SetStep(step)
        self.step = math.max(1, math.min(self.totalSteps, step))
        if type(OffhandCharDB) == "table" then OffhandCharDB.wizardProgressStep = self.step end
        if Offhand.SetOnboardingResumeStep and Offhand.IsSetupComplete and not Offhand:IsSetupComplete() then
            Offhand:SetOnboardingResumeStep(6)
        end
        self.recoveryReason = nil
        recoveryCard:Hide()
        recoveryBack:Hide()
        restartBtn:Hide()
        progress:SetText(string.format(L["STEP_PROGRESS"], self.step, self.totalSteps))
        validationStatus:SetText("")
        if PlacementFailure() then self:ShowRecovery("span"); return end
        for i, card in ipairs(self.pages) do SetShown(card, i == self.step) end
        local helpKey = self.step == 5 and "STEP_5_HELP"
            or (self.step == 4 and self.totalSteps == 4 and "STEP_4_HELP_NO_EDITMODE")
            or (self.step == 4 and "STEP_4_HELP_EDITMODE")
            or ("STEP_" .. self.step .. "_HELP")
        welcomeText:SetText(L[helpKey])
        backBtn:Show()
        backBtn:SetEnabled(self.step > 1)
        SetShown(restartBtn, self.step > 1)
        SetShown(advBtn, self.step ~= 5)
        local controllerLayout = self.step == 5 and UsesControllerLayout()
        local canCreateController = controllerLayout and CanCreateControllerLayout()
        SetShown(skipLayoutBtn, self.step == 5 and not controllerLayout)
        finishBtn:SetText(self.step == 5
            and (controllerLayout and canCreateController and L["WIZARD_GAMEPAD_FINISH"]
                or controllerLayout and L["BTN_FINISH"] or L["MAINHAND_LAYOUT_CREATE"])
            or (self.step == self.totalSteps and L["BTN_FINISH"] or L["BTN_NEXT"]))
        finishBtn:SetSize(self.step == 5 and 230 or 170, 28)
        if self.step == 5 then
            local state = Offhand.Mainhand and Offhand.Mainhand.GetLayoutStatus
                and Offhand.Mainhand:GetLayoutStatus() or nil
            local name = state and state.deferred and L["MAINHAND_LAYOUT_DEFERRED"]
                or (state and state.configured and state.generatedName
                    or L["MAINHAND_LAYOUT_UNSET"])
            if state and state.configured and not state.deferred
                and not state.currentGeometry then
                name = string.format(L["MAINHAND_LAYOUT_STALE"], tostring(name))
            end
            layoutStatus:SetText(controllerLayout and (canCreateController
                    and L["MAINHAND_LAYOUT_GAMEPAD_STATUS"] or L["MAINHAND_LAYOUT_GAMEPAD_FAILED"])
                or string.format(L["MAINHAND_LAYOUT_STATUS"], tostring(name)))
            layoutHelp:SetText((controllerLayout and (canCreateController
                    and L["WIZARD_GAMEPAD_LAYOUT_BODY"] or L["MAINHAND_LAYOUT_GAMEPAD_FAILED"])
                or L["WIZARD_STEP_5_BODY"]) .. "\n\n" ..
                ReadinessSummary(controllerLayout and (canCreateController
                        and L["MAINHAND_LAYOUT_GAMEPAD_STATUS"] or L["MAINHAND_LAYOUT_GAMEPAD_FAILED"])
                    or state and state.configured and not state.deferred
                    and L["READINESS_HUD_READY"] or L["READINESS_HUD_PENDING"]))
        end
        if self.step == 3 then
            Offhand.Options:ShowSeamGuide(Offhand.db and Offhand.db.deckWidthRatio)
        else
            Offhand.Options:HideSeamGuide()
        end
        self:UpdateLaserButton()
        self:LayoutStep()
    end

    function f:UpdateLaserButton()
        local isShown = Offhand.Options and Offhand.Options.IsSeamGuideShown and Offhand.Options:IsSeamGuideShown()
        btnLaser:SetText(isShown and ("|cffff3333" .. L["WIZARD_BTN_LASER_HIDE"] .. "|r") or L["WIZARD_BTN_LASER_SHOW"])
    end

    function f:UpdateState()
        if self._updatingState or not Offhand.db then return end
        self._updatingState = true
        local p = Offhand.db.layoutPreset
        local pos = Offhand.db.primaryPosition
        local ar = Offhand.db.aspectRatioMode
        local hud = Offhand.db.hudScale or 0.70
        local seam = Offhand.db.deckWidthRatio or 0.36
        local metrics = Offhand.Viewport and Offhand.Viewport.GetMetrics and Offhand.Viewport:GetMetrics()
        local manualGeometryEnabled = not (metrics and metrics.companionTopology)
        exactTopologyHelp:SetText(manualGeometryEnabled and ""
            or ("|cffffd100" .. L["WIZARD_STEP2_OPTIONS_LOCKED"] .. "|r"))
        seamHelp:SetText(manualGeometryEnabled and L["WIZARD_SEAM_INSTRUCTION"]
            or L["WIZARD_STEP3_OPTIONS_LOCKED"])
        for _, control in ipairs({btnPl, btnPr, btnDual, btnVt, btnVb, btn169, btn219,
            btnFill, seamSlider, seamEditBox, btnMinus, btnPlus, btnSeam36, btnSeam50, btnSeam55}) do
            if control == seamSlider then Controls.SetSliderEnabled(control, manualGeometryEnabled)
            elseif control and control.SetEnabled then control:SetEnabled(manualGeometryEnabled) end
            if control and control.SetAlpha then control:SetAlpha(manualGeometryEnabled and 1 or 0.55) end
        end

        seamSlider:SetValue(seam)
        seamValText:SetText(string.format(L["WIZARD_SEAM_VAL_FMT"], seam * 100))
        if seamEditBox and not (seamEditBox.HasFocus and seamEditBox:HasFocus()) then
            seamEditBox:SetText(string.format("%.1f%%", seam * 100))
        end

        scaleSlider:SetValue(hud)
        scaleValText:SetText(string.format(L["WIZARD_SCALE_VAL_FMT"], hud * 100))
        if scaleEditBox and not (scaleEditBox.HasFocus and scaleEditBox:HasFocus()) then
            scaleEditBox:SetText(string.format("%.0f%%", hud * 100))
        end

        Offhand.Options:SetChoiceSelected(btnPl, p == "PORTRAIT_LEFT_LANDSCAPE_RIGHT" and pos == "RIGHT")
        Offhand.Options:SetChoiceSelected(btnPr, p == "PORTRAIT_LEFT_LANDSCAPE_RIGHT" and pos == "LEFT")
        Offhand.Options:SetChoiceSelected(btnDual, p == "LANDSCAPE_DUAL")
        Offhand.Options:SetChoiceSelected(btnVt, p == "STACKED_VERTICAL" and pos == "TOP")
        Offhand.Options:SetChoiceSelected(btnVb, p == "STACKED_VERTICAL" and pos == "BOTTOM")

        Offhand.Options:SetChoiceSelected(btn169, ar == "16_9")
        Offhand.Options:SetChoiceSelected(btn219, ar == "21_9")
        Offhand.Options:SetChoiceSelected(btnFill, ar == "FILL")
        -- Selection styling intentionally enables a choice button, so enforce
        -- the exact-topology lock after applying that styling.
        for _, control in ipairs({btnPl, btnPr, btnDual, btnVt, btnVb,
            btn169, btn219, btnFill}) do
            if control and control.SetEnabled then control:SetEnabled(manualGeometryEnabled) end
        end

        Offhand.Options:SetChoiceSelected(btnHud56, math.abs(hud - 0.56) < 0.005)
        Offhand.Options:SetChoiceSelected(btnHud65, math.abs(hud - 0.65) < 0.005)
        Offhand.Options:SetChoiceSelected(btnHud70, math.abs(hud - 0.70) < 0.005)
        Offhand.Options:SetChoiceSelected(btnHud100, math.abs(hud - 1.00) < 0.005)

        local trimKey = (Offhand.db and Offhand.db.trimColor) or "GOLD"
        local pals = Offhand.Themes and Offhand.Themes.GetColorPalettes and Offhand.Themes:GetColorPalettes()
        local c = pals and pals[trimKey]
        if c then
            if seamSlider.thumb and seamSlider.thumb.SetVertexColor then
                seamSlider.thumb:SetVertexColor(c.r, c.g, c.b, 1.0)
            end
            if scaleSlider.thumb and scaleSlider.thumb.SetVertexColor then
                scaleSlider.thumb:SetVertexColor(c.r, c.g, c.b, 1.0)
            end
        else
            if seamSlider.thumb and seamSlider.thumb.SetVertexColor then
                seamSlider.thumb:SetVertexColor(1.0, 0.82, 0.0, 1.0)
            end
            if scaleSlider.thumb and scaleSlider.thumb.SetVertexColor then
                scaleSlider.thumb:SetVertexColor(1.0, 0.82, 0.0, 1.0)
            end
        end

        self:UpdateLaserButton()
        self._updatingState = nil
        if self.step then self:LayoutStep() end
    end

    f.seamSlider = seamSlider
    f.seamValText = seamValText
    f.seamEditBox = seamEditBox
    f.scaleSlider = scaleSlider
    f.scaleValText = scaleValText
    f.scaleEditBox = scaleEditBox

    function f:CenterInMainhand()
        if self.step then self:LayoutStep() end
        local m = Offhand.Viewport and Offhand.Viewport.GetMetrics and Offhand.Viewport:GetMetrics()
        local scale = Controls.FitDialog(self, m)
        self:ClearAllPoints()
        if m and m.isSpanned and m.gameLeft and m.gameRight and m.gameBottom and m.gameTop then
            -- Metrics are UIParent units; offsets on this scaled dialog are
            -- local units. Recompute from the rectangle, never the old anchor.
            self:SetPoint("CENTER", UIParent, "BOTTOMLEFT",
                (m.gameLeft + m.gameRight) / (2 * scale),
                (m.gameBottom + m.gameTop) / (2 * scale))
        else
            self:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        end
    end

    function f:RecenterForDisplayChange()
        if not self:IsShown() then return end
        self.recenterGeneration = (self.recenterGeneration or 0) + 1
        local generation = self.recenterGeneration
        self:CenterInMainhand()
        -- UIParent and accepted topology can settle after the initial event.
        -- Follow the existing 0.75-second display debounce without polling.
        if C_Timer and C_Timer.After then
            for _, delay in ipairs({0.15, 0.9}) do
                C_Timer.After(delay, function()
                    if self.recenterGeneration == generation then self:CenterInMainhand() end
                end)
            end
        end
    end

    wizardFrame = f
    f:RegisterEvent("PLAYER_REGEN_ENABLED")
    f:RegisterEvent("PLAYER_CONTROL_GAINED")
    f:RegisterEvent("CINEMATIC_STOP")
    f:RegisterEvent("DISPLAY_SIZE_CHANGED")
    f:RegisterEvent("UI_SCALE_CHANGED")
    f:SetScript("OnEvent", function(self, event)
        if event == "DISPLAY_SIZE_CHANGED" or event == "UI_SCALE_CHANGED" then
            self:RecenterForDisplayChange()
        else
            Wizard:ResumeFromSettings()
        end
    end)
    f:SetScript("OnShow", function(self) self:RecenterForDisplayChange() end)
    return f
end

function Wizard:CancelEditModeReturn()
    self.editModeReturnStep = nil
    if editModeReturnWatcher then editModeReturnWatcher:SetScript("OnUpdate", nil) end
end

function Wizard:ReturnToWindowSetup(page)
    self:CancelEditModeReturn()
    if type(OffhandCharDB) == "table" then OffhandCharDB.wizardRecoveryStep = nil end
    if Offhand.SetOnboardingResumeStep then Offhand:SetOnboardingResumeStep(page == 2 and 2 or 4) end
    self:Close()
    if Offhand.Onboarding then Offhand.Onboarding:Open() end
end

function Wizard:ReloadPlacement()
    if not wizardFrame or (InCombatLockdown and InCombatLockdown()) then
        if wizardFrame then
            wizardFrame.recoveryBody:SetText(L["ONBOARD_RELOAD_COMBAT"])
            wizardFrame:LayoutStep()
        end
        return false
    end
    if type(ReloadUI) ~= "function" or type(OffhandCharDB) ~= "table" then return false end
    OffhandCharDB.wizardRecoveryStep = wizardFrame.step
    -- Existing login handoff opens Onboarding even for previously completed users.
    if Offhand.SetOnboardingResumeStep then Offhand:SetOnboardingResumeStep(6) end
    ReloadUI()
    return true
end

function Wizard:ResumeAfterReload()
    local step = type(OffhandCharDB) == "table" and tonumber(OffhandCharDB.wizardRecoveryStep)
    if not step and Offhand.GetOnboardingResumeStep and Offhand:GetOnboardingResumeStep() == 6
        and Offhand.IsSetupComplete and not Offhand:IsSetupComplete() then
        step = self:GetSavedStep()
    end
    if not step or step ~= step or step < 1 or step > 5 then
        if type(OffhandCharDB) == "table" then OffhandCharDB.wizardRecoveryStep = nil end
        return false
    end
    if InCombatLockdown and InCombatLockdown() then return false end
    OffhandCharDB.wizardRecoveryStep = nil
    if Offhand.SetOnboardingResumeStep then Offhand:SetOnboardingResumeStep(nil) end
    self:Open(math.floor(step))
    return true
end

function Wizard:RestartCalibration()
    -- Restart navigation only. Existing calibration and layouts stay available.
    if type(OffhandCharDB) == "table" then
        OffhandCharDB.wizardProgressStep = nil
        OffhandCharDB.wizardRecoveryStep = nil
    end
    self:Open(1)
    if wizardFrame and not wizardFrame.recoveryReason then
        wizardFrame.validationStatus:SetText(L["WIZARD_RESTART_NOTICE"])
        wizardFrame:LayoutStep()
    end
end

function Wizard:OpenLayoutManagement()
    if not wizardFrame then return false end
    if InCombatLockdown and InCombatLockdown() then
        wizardFrame.recoveryBody:SetText(L["WIZARD_RECOVERY_EDITMODE_COMBAT"])
        wizardFrame:LayoutStep()
        return false
    end
    local manager = _G.EditModeManagerFrame
    if not manager or type(ShowUIPanel) ~= "function"
        or (type(manager.CanEnterEditMode) == "function" and not manager:CanEnterEditMode()) then
        wizardFrame.recoveryBody:SetText(L["WIZARD_RECOVERY_MAX_BODY"] .. "\n\n" .. L["WIZARD_RECOVERY_EDITMODE_MANUAL"])
        wizardFrame:LayoutStep()
        return false
    end
    self:Close()
    -- Same player-click entry as Blizzard's game menu, without hooks or fields
    -- on the native manager or its protected descendants.
    local ok = pcall(ShowUIPanel, manager)
    if not ok then
        wizardFrame:Show()
        wizardFrame.recoveryBody:SetText(L["WIZARD_RECOVERY_MAX_BODY"] .. "\n\n" .. L["WIZARD_RECOVERY_EDITMODE_MANUAL"])
        wizardFrame:LayoutStep()
        return false
    end
    self.editModeReturnStep = wizardFrame.step
    if not editModeReturnWatcher then editModeReturnWatcher = CreateFrame("Frame") end
    local elapsed, interval, seen = 0, 0, manager:IsShown()
    editModeReturnWatcher:SetScript("OnUpdate", function(watcher, delta)
        elapsed, interval = elapsed + delta, interval + delta
        if interval < 0.2 then return end
        interval = 0
        seen = seen or manager:IsShown()
        if not seen and elapsed < 3 then return end
        if manager:IsShown() or (InCombatLockdown and InCombatLockdown())
            or (Offhand.IsBlizzardInputReserved and Offhand:IsBlizzardInputReserved()) then return end
        local step = Wizard.editModeReturnStep
        watcher:SetScript("OnUpdate", nil)
        Wizard.editModeReturnStep = nil
        if not step then return end
        Wizard:Open(step)
        wizardFrame.validationStatus:SetText(L[seen and "WIZARD_RECOVERY_RETURNED" or "WIZARD_RECOVERY_EDITMODE_MANUAL"])
        wizardFrame:LayoutStep()
    end)
    return true
end

function Wizard:Open(resumeStep)
    local savedStep = not resumeStep and self:GetSavedStep() or nil
    resumeStep = resumeStep or savedStep
    self:CancelEditModeReturn()
    self.settingsResumeStep = nil
    if Offhand.Onboarding and Offhand.Onboarding.Close then Offhand.Onboarding:Close() end
    -- Hide Options dashboard if it is currently open to prevent overlapping windows
    if Offhand.Options and Offhand.Options.GetConfigFrame then
        local cfg = Offhand.Options:GetConfigFrame()
        if cfg and cfg:IsShown() then
            Wizard.openedFromOptions = true
            cfg:Hide()
        end
    end

    local f = self:CreateFrame()
    if not f then return end

    local info = self:DetectTopology()

    f.topoText:SetText(string.format("|cffffd100%s|r %s  |cff888888%dx%d|r",
        L["WIZARD_DETECTED_PREFIX"], info.description, info.physWidth, info.physHeight))

    f.recomText:SetText(string.format("|cffffd100%s|r %s | %.1f%% | %s",
        L["WIZARD_RECOM_PREFIX"],
        (info.recommendedPreset == "PORTRAIT_LEFT_LANDSCAPE_RIGHT" and (info.recommendedPosition == "RIGHT" and L["PRESET_PL_LR"] or L["PRESET_GL_PR"]) or L["PRESET_DUAL_LANDSCAPE"]),
        info.recommendedDeckRatio * 100,
        info.recommendedAR or "16:9"))

    if info.topologyStatus == "MISMATCH" then
        f.statusText:SetText("|cffff5555" ..
            Offhand.Options:GetMainhandLayoutFailureText("span") .. "|r")
    elseif info.exactTopology and info.companionVersionStatus == "MISMATCH" then
        f.statusText:SetText("|cffff5555" .. string.format(L["WIZARD_STATUS_COMPANION_MISMATCH"],
            info.companionVersion or "?", info.expectedCompanionVersion or "?") .. "|r")
    elseif info.exactTopology and info.companionVersionStatus == "UNKNOWN" then
        -- Beta 13 predates topology-writer metadata. Its exact geometry remains
        -- valid; diagnostics report the unverified writer without blocking setup.
        f.statusText:SetText(L["EXACT_TOPOLOGY_LOCKED"])
    elseif info.exactTopology then
        f.statusText:SetText(L["EXACT_TOPOLOGY_LOCKED"])
    else
        f.statusText:SetText(L["WIZARD_STATUS_READY"])
    end
    if f.autoBtn then
        f.autoBtn:SetText("|cff00ff00" .. L["WIZARD_BTN_AUTOCONFIG"] .. "|r")
    end
    if f.finishBtn and f.finishBtn.UnlockHighlight then
        f.finishBtn:UnlockHighlight()
    end

    f:UpdateState()

    Controls.RefreshStyles()

    f:SetStep(resumeStep or 1)
    if savedStep and savedStep > 1 and not f.recoveryReason then
        f.validationStatus:SetText(string.format(L["WIZARD_RESUMED"], f.step, f.totalSteps))
        f:LayoutStep()
    end

    -- An unanchored native frame cannot become visible, so OnShow alone
    -- cannot establish the first anchor. Fit and position after final layout.
    f:CenterInMainhand()
    f:Show()
end

function Wizard:ResumeFromSettings()
    local step = self.settingsResumeStep
    if not step then return end
    if InCombatLockdown and InCombatLockdown() then return end
    if Offhand.IsBlizzardInputReserved and Offhand:IsBlizzardInputReserved() then return end
    local options = Offhand.Options and Offhand.Options.GetConfigFrame and Offhand.Options:GetConfigFrame()
    if options and options:IsShown() then return end
    self.settingsResumeStep = nil
    self:Open()
    if wizardFrame then wizardFrame:SetStep(step) end
end

function Wizard:OpenHUDSetup()
    self:Open()
    if wizardFrame then wizardFrame:SetStep(wizardFrame.totalSteps) end
end

function Wizard:OpenLayoutCapacityRecovery()
    self:OpenHUDSetup()
    if wizardFrame and not PlacementFailure() then wizardFrame:ShowRecovery("maximum") end
end

function Wizard:Close()
    self:CancelEditModeReturn()
    if Offhand.Options and Offhand.Options.HideSeamGuide then
        Offhand.Options:HideSeamGuide()
    end
    if wizardFrame then
        wizardFrame:Hide()
    end
end

function Offhand:OpenWizard()
    Wizard:Open()
end
