--[[
    Offhand: Multi-Monitor Setup Addon
    UI/Options.lua: Clean Tabbed Settings, Calibration Dashboard & Setup Guide
    Task-oriented settings with shared addon-owned controls.
--]]

local _, Offhand = ...

local L = Offhand.L or setmetatable({}, {
    __index = function(t, key)
        return key
    end
})

local tinsert = table.insert
local COMPANION_DOWNLOAD_URL = Offhand.companionDownloadUrl
local POWERTOYS_DOWNLOAD_URL = Offhand.powerToysDownloadUrl
local Controls = assert(Offhand.UIControls, "Offhand UI controls must load before Options")
local CreateFrame = Controls.CreateFrame
local TopologyDetection = assert(Offhand.TopologyDetection, "Offhand topology detection must load before Options")
local CreateNativeCheckbox = Controls.CreateNativeCheckbox
local SetCheckboxEnabled = Controls.SetCheckboxEnabled
local CreateNativeRadioButton = Controls.CreateNativeRadioButton
-- Professions movement now defaults on and has completed its compatibility
-- burn-in. Keep the reversible control implementation available for a future
-- client regression without presenting the experimental card to players.
local SHOW_FOREVER_PROFESSIONS_COMPATIBILITY_UI = false

local function BackdropTemplate()
    return not Offhand.isLegacyWrath and "BackdropTemplate" or nil
end

local function SetShown(frame, shown)
    if frame.SetShown then frame:SetShown(shown)
    elseif shown then frame:Show()
    else frame:Hide() end
end

local function SetSolidColor(texture, r, g, b, a)
    if not texture then return end
    if texture.SetColorTexture then
        texture:SetColorTexture(r, g, b, a)
    elseif texture.SetTexture then
        texture:SetTexture(r, g, b, a)
    end
end


StaticPopupDialogs["OFFHAND_DOWNLOAD_LINK"] = {
    text = "The Companion App automates a pixel-perfect, borderless span across multiple monitors.\n\nRecommended for Windows: copy the Microsoft Store address below. Portable and Linux/Wine options remain available at offhand-wow.onrender.com/companion.html and through the official GitHub releases.",
    button1 = "Close",
    hasEditBox = true,
    editBoxWidth = 260,
    OnShow = function(self)
        local eb = self.EditBox or _G[self:GetName().."EditBox"]
        if eb then
            eb._OffhandSettingDownloadUrl = true
            eb:SetText(COMPANION_DOWNLOAD_URL)
            eb._OffhandSettingDownloadUrl = nil
            eb:HighlightText()
            eb:SetFocus()
        end
    end,
    gamepadEditBoxText = function() return COMPANION_DOWNLOAD_URL end,
    EditBoxOnTextChanged = function(self)
        if self._OffhandSettingDownloadUrl or self:GetText() == COMPANION_DOWNLOAD_URL then return end
        self._OffhandSettingDownloadUrl = true
        self:SetText(COMPANION_DOWNLOAD_URL)
        self._OffhandSettingDownloadUrl = nil
        self:HighlightText()
    end,
    EditBoxOnEscapePressed = function(self)
        self:GetParent():Hide()
    end,
    OnHide = function()
        if Offhand.Onboarding and Offhand.Onboarding.ResumeAfterDownload then
            Offhand.Onboarding:ResumeAfterDownload()
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["OFFHAND_POWERTOYS_LINK"] = {
    text = L["POWERTOYS_LINK_TEXT"],
    button1 = L["BTN_CLOSE"],
    hasEditBox = true,
    editBoxWidth = 300,
    OnShow = function(self)
        local eb = self.EditBox or _G[self:GetName().."EditBox"]
        if eb then
            eb._OffhandSettingDownloadUrl = true
            eb:SetText(POWERTOYS_DOWNLOAD_URL)
            eb._OffhandSettingDownloadUrl = nil
            eb:HighlightText()
            eb:SetFocus()
        end
    end,
    gamepadEditBoxText = function() return POWERTOYS_DOWNLOAD_URL end,
    EditBoxOnTextChanged = function(self)
        if self._OffhandSettingDownloadUrl or self:GetText() == POWERTOYS_DOWNLOAD_URL then return end
        self._OffhandSettingDownloadUrl = true
        self:SetText(POWERTOYS_DOWNLOAD_URL)
        self._OffhandSettingDownloadUrl = nil
        self:HighlightText()
    end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    OnHide = function()
        if Offhand.Onboarding and Offhand.Onboarding.ResumeAfterDownload then
            Offhand.Onboarding:ResumeAfterDownload()
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["OFFHAND_ENABLE_FOREVER_PROFESSIONS_MOVEMENT"] = {
    text = L["FOREVER_PROF_MOVE_CONFIRM"],
    button1 = L["FOREVER_PROF_MOVE_ENABLE"],
    button2 = L["FOREVER_PROF_MOVE_SAFE"],
    OnAccept = function(_, callback)
        if callback then callback() end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local Options = {}
Offhand.Options = Options

_G.BINDING_HEADER_OFFHAND = L["BINDING_HEADER_OFFHAND"]
_G.HEADER_OFFHAND = L["BINDING_HEADER_OFFHAND"]
_G.BINDING_NAME_OFFHAND_TOGGLE_SETTINGS = L["BINDING_NAME_OFFHAND_TOGGLE_SETTINGS"]
_G.BINDING_NAME_OFFHAND_TOGGLE_GAMEPAD_UI_FOCUS =
    L["BINDING_NAME_OFFHAND_TOGGLE_GAMEPAD_UI_FOCUS"]

function Options:CreateMainhandHUDLayout()
    if Offhand.Mainhand and Offhand.Mainhand.CreateOrUpdateEditModeLayout then
        return Offhand.Mainhand:CreateOrUpdateEditModeLayout()
    end
    return false, "unavailable"
end

function Options:GetMainhandLayoutFailureText(reason)
    if reason == "maximum" then return L["MAINHAND_LAYOUT_MAXIMUM"] end
    if reason == "gamepad" then return L["MAINHAND_LAYOUT_GAMEPAD_FAILED"] end
    if reason == "span" then
        local metrics = Offhand.Viewport and Offhand.Viewport.GetMetrics
            and Offhand.Viewport:GetMetrics() or nil
        if metrics and metrics.topologyStatus == "MISMATCH"
            and not metrics.manualCanvas then
            return L["MAINHAND_LAYOUT_SPAN_MISMATCH"]
        end
        return L["MAINHAND_LAYOUT_SPAN_UNCONFIRMED"]
    end
    return string.format(L["MAINHAND_LAYOUT_FAILED"], tostring(reason or "unavailable"))
end

function Options:GatherSafeUIToMainhand()
    if Offhand.Mainhand and Offhand.Mainhand.GatherSafeUI then
        return Offhand.Mainhand:GatherSafeUI()
    end
    return false, "unavailable", 0, 0
end

-- Shared presentation rules for settings and the wizard. Selection is not disability.
function Options:SetChoiceSelected(button, selected)
    return Controls.SetChoiceSelected(button, selected)
end

function Options:StackCards(parent, cards)
    return Controls.StackCards(parent, cards)
end

function Options:Confirm(message, callback)
    StaticPopupDialogs["OFFHAND_CONFIRM_PROFILE"] = {
        text = "%s", button1 = ACCEPT, button2 = CANCEL,
        OnAccept = function(_, data) data() end,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }
    Offhand:ShowPopup("OFFHAND_CONFIRM_PROFILE", message, nil, callback)
end

local configFrame
local GamepadFocusBindingStatusText = assert(
    Offhand.OptionsActions,
    "Offhand settings actions must load before Options"
).Install(Options, {
    GetConfigFrame = function() return configFrame end,
    SetSolidColor = SetSolidColor,
})
local setupFrame
local currentTab = 1

-- ============================================================================
-- Topology Detection
-- ============================================================================
function Options:DetectTopology()
    return TopologyDetection.Detect()
end


local registeredSliders = {}

local function CreateNativeSlider(...)
    local slider = Controls.CreateNativeSlider(...)
    tinsert(registeredSliders, slider)
    return slider
end

function Options:CreateBottomControl(parent)
    return Controls.CreateBottomControl(parent)
end

function Options:GetConfigFrame()
    return configFrame
end

-- ============================================================================
-- Unified Clean Tabbed Dashboard
-- ============================================================================
function Options:CreateFloatingPanel()
    if configFrame then return configFrame end

    configFrame = CreateFrame("Frame", "OffhandFloatingConfigFrame", UIParent, BackdropTemplate())
    configFrame:SetSize(922, 732)
    Controls.RegisterDialog(configFrame)
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
    local getMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    local verNum = (getMetadata and getMetadata("Offhand", "Version")) or "1.0.0"
    local companionDisplay = Offhand.companionVersionDisplay or ("v" .. verNum)
    version:SetText("|cffaaaaaav" .. verNum .. "|r |cff777777[Companion "
        .. companionDisplay .. "]|r")
    header.versionText = version

    local versionButton = CreateFrame("Button", nil, header)
    local versionWidth = version.GetStringWidth and version:GetStringWidth() or 220
    versionButton:SetSize(math.max(96, math.min(360, versionWidth + 10)), 18)
    versionButton:SetPoint("CENTER", version, "CENTER", 0, 0)
    configFrame.versionButton = versionButton
    if Offhand.SetTooltip then
        local releaseDisplay = Offhand.releaseDisplay or ""
        local fullDisplay = "Offhand v" .. verNum
            .. (releaseDisplay ~= "" and (" " .. releaseDisplay) or "")
        local releaseTag = "v" .. (Offhand.fullVersion or verNum)
        local tooltipText = string.format(L["VERSION_TOOLTIP_ADDON_BUILD"], releaseTag)
            .. "\n" .. string.format(L["VERSION_TOOLTIP_COMPANION_BUILD"], companionDisplay)
            .. "\n\n" .. L["VERSION_TOOLTIP_COMPANION_NOTE"]
        versionButton.offhandTooltipTitle = fullDisplay
        versionButton.offhandTooltipText = tooltipText
        Offhand:SetTooltip(versionButton, fullDisplay, tooltipText)
    end
    
    local desc = header:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    desc:SetText(L["ADDON_DESC"])
    
    local closeBtn = CreateFrame("Button", nil, configFrame.header, "UIPanelCloseButton")
    closeBtn:SetSize(28, 28)
    closeBtn:SetPoint("RIGHT", configFrame.header, "RIGHT", -10, 0)
    closeBtn:SetScript("OnClick", function()
        Options:Close()
    end)

    configFrame:SetScript("OnHide", function()
        Options:HideSeamGuide()
        if Options.gamepadFocusCapture then Options.gamepadFocusCapture:Hide() end
        if Offhand.HUD and Offhand.HUD.SetGroupLootMoverShown then
            Offhand.HUD:SetGroupLootMoverShown(false)
        end
    end)

    -- Sidebar divider, kept outside the scrolling content.
    local divider = configFrame:CreateTexture(nil, "ARTWORK")
    if divider.SetWidth then divider:SetWidth(1) end
    if divider.SetPoint then
        divider:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 202, -88)
        divider:SetPoint("BOTTOMLEFT", configFrame, "BOTTOMLEFT", 202, 52)
    end
    SetSolidColor(divider, 1, 1, 1, 0.15)
    configFrame.divider = divider

    -- Auto-Setup Wizard Button
    local autoWizardBtn = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
    autoWizardBtn:SetSize(155, 22)
    autoWizardBtn:SetPoint("TOPRIGHT", -24, -126)
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
    compAppBtn:SetText(L["POPUP_BTN_SETUP_GUIDE"])
    compAppBtn:SetScript("OnClick", function()
        if Offhand.Onboarding and Offhand.Onboarding.Open then Offhand.Onboarding:Open() end
    end)

    if Offhand.SetTooltip then
        Offhand:SetTooltip(autoWizardBtn, L["BTN_AUTO_WIZARD_TIP_TITLE"], L["BTN_AUTO_WIZARD_TIP_DESC"])
    end
    configFrame.autoWizardBtn = autoWizardBtn
    configFrame.companionAppBtn = compAppBtn

    -- Status & Topology Detection Banner
    local banner = configFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    banner:SetPoint("TOPLEFT", 218, -94)
    banner:SetPoint("TOPRIGHT", -24, -94)
    banner:SetJustifyH("LEFT")
    configFrame.banner = banner

    -- Data-Driven Tab Buttons will be created after Tab Content Containers

    -- Master ScrollFrame for all Tab Content
    local optionsScrollFrame = CreateFrame("ScrollFrame", "OffhandOptionsScrollFrame", configFrame, "UIPanelScrollFrameTemplate")
    optionsScrollFrame:SetPoint("TOPLEFT", 218, -164)
    optionsScrollFrame:SetPoint("BOTTOMRIGHT", -42, 52)
    configFrame.scrollFrame = optionsScrollFrame
    Controls.EnableWheelScroll(optionsScrollFrame)

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
        local card = CreateFrame("Frame", nil, parent, BackdropTemplate())
        card:SetSize(662, height)
        card:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)

        Controls.StyleSurface(card, "card")

        local title = card:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        title:SetPoint("TOPLEFT", card, "TOPLEFT", 12, -8)
        title:SetText(titleText)
        card.title = title
        card.settingsTab = parent
        card.sectionLabel = titleText

        tinsert(registeredCards, card)
        return card
    end

    function Options:UpdateCardThemes()
        local trimKey = (Offhand.db and Offhand.db.trimColor) or "GOLD"
        local c
        if trimKey == "CUSTOM" and Offhand.db and Offhand.db.customTrimColor then
            c = Offhand.db.customTrimColor
        else
            local pals = Offhand.Themes and Offhand.Themes.GetColorPalettes and Offhand.Themes:GetColorPalettes()
            c = pals and pals[trimKey]
        end
        local textR, textG, textB = (c and c.r) or 1.0, (c and c.g) or 0.82, (c and c.b) or 0.0

        for _, card in ipairs(registeredCards) do
            Controls.StyleSurface(card, "card")
            if card.title then
                card.title:SetTextColor(textR, textG, textB, 1.0)
            end
        end

        for _, slider in ipairs(registeredSliders) do
            if slider.UpdateTheme then
                slider:UpdateTheme(trimKey)
            end
        end
        Controls.RefreshStyles()

        if Options.UpdateTrimHighlights then
            Options:UpdateTrimHighlights()
        end
        if Options.UpdateCanvasHighlights then
            Options:UpdateCanvasHighlights()
        end
    end

    local tabConfig = {
        { id = 1, frame = tab1, label = L["TAB_DISPLAY"] },
        { id = 2, frame = tab2, label = L["TAB_WORKSPACE"] },
        { id = 3, frame = tab3, label = L["TAB_THEMES"] },
        { id = 4, frame = tab4, label = L["TAB_PROFILES"] },
        { id = 5, frame = tab5, label = L["TAB_HELP"] }
    }
    
    local tabButtons = {}
    local sectionButtons = {}
    local sectionTitle = configFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    sectionTitle:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 24, -360)
    sectionTitle:SetText(L["UI_SECTIONS"])
    configFrame.cards = registeredCards
    configFrame.tabButtons = tabButtons
    configFrame.sectionButtons = sectionButtons
    local tabScrollOffsets = {}
    local displayedTab

    local function SwitchTab(tabIndex)
        if displayedTab and optionsScrollFrame.GetVerticalScroll then
            tabScrollOffsets[displayedTab] = optionsScrollFrame:GetVerticalScroll()
        end
        currentTab = tabIndex

        for i, t in ipairs(tabConfig) do
            local isActive = (tabIndex == t.id)
            SetShown(t.frame, isActive)
            
            local btn = tabButtons[i]
            if btn then
                Controls.SetChoiceSelected(btn, isActive)
            end
            
            if isActive then
                optionsScrollChild:SetHeight(t.frame:GetHeight())
            end
        end

        displayedTab = tabIndex
        Controls.SetScrollOffset(optionsScrollFrame, tabScrollOffsets[tabIndex] or 0)

        local pageCards = {}
        for _, card in ipairs(registeredCards) do
            if card.settingsTab == tabConfig[tabIndex].frame then
                pageCards[#pageCards + 1] = card
            end
        end
        table.sort(pageCards, function(a, b)
            return (select(5, a:GetPoint(1)) or 0) > (select(5, b:GetPoint(1)) or 0)
        end)
        for index, card in ipairs(pageCards) do
            local button = sectionButtons[index]
            if not button then
                button = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
                button:SetSize(166, 28)
                sectionButtons[index] = button
            end
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 20, -380 - (index - 1) * 32)
            button:SetText(card.sectionLabel)
            local target = card
            button:SetScript("OnClick", function()
                local _, _, _, _, y = target:GetPoint(1)
                Controls.SetScrollOffset(optionsScrollFrame, -(y or 0))
            end)
            if Offhand.SetTooltip then Offhand:SetTooltip(button, card.sectionLabel) end
            button:Show()
        end
        for i = #pageCards + 1, #sectionButtons do sectionButtons[i]:Hide() end

        if Options.UpdateTrimHighlights then
            Options:UpdateTrimHighlights()
        end
        if Options.UpdateCanvasHighlights then
            Options:UpdateCanvasHighlights()
        end
    end

    -- Dynamically generate the tab buttons
    for i, t in ipairs(tabConfig) do
        local btn = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
        btn:SetSize(166, 44)
        btn:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 20, -94 - (i - 1) * 52)
        btn:SetText(t.label)
        btn:SetScript("OnClick", function() SwitchTab(t.id) end)
        table.insert(tabButtons, btn)
    end

    -- ========================================================================
    -- TAB 1: DISPLAY & VIEWPORT CALIBRATION
    -- ========================================================================
    local card1_1 = CreateCard(tab1, L["CARD_LAYOUT_PRESETS"], 184)

    local enableCheck = CreateNativeCheckbox(card1_1, L["ENABLE_OFFHAND"],
        function() return Offhand.db and Offhand.db.enabled end,
        function(val)
            if Offhand.SetEnabled then Offhand:SetEnabled(val) else Offhand.db.enabled = val end
        end,
        L["CHECK_CANVAS_ENABLED_TIP_TITLE"], L["CHECK_CANVAS_ENABLED_TIP_DESC"]
    )
    enableCheck:SetPoint("TOPLEFT", 12, -26)
    configFrame.enableCheck = enableCheck
    local minimapCheck = CreateNativeCheckbox(card1_1, L["SHOW_MINIMAP_ICON"],
        function() return Offhand.db and Offhand.db.showMinimapIcon end,
        function(val) 
            Offhand.db.showMinimapIcon = val 
            if Offhand.UpdateMinimapIcon then Offhand:UpdateMinimapIcon() end
        end,
        "Minimap Icon", "Toggle the Offhand icon on the minimap ring."
    )
    minimapCheck:SetPoint("TOPLEFT", 12, -122)
    minimapCheck.Text:SetWidth(180)


    local laserCheck = CreateNativeCheckbox(card1_1, L["BTN_LASER_TOGGLE"],
        function() return Options:IsSeamGuideShown() end,
        function(val)
            if val then
                Options:ShowSeamGuide(Offhand.db and Offhand.db.deckWidthRatio)
            else
                Options:HideSeamGuide()
            end
        end,
        L["BTN_LASER_TOGGLE_TIP_TITLE"], L["BTN_LASER_TOGGLE_TIP_DESC"]
    )
    laserCheck:SetPoint("TOPLEFT", 330, -122)
    laserCheck.Text:SetWidth(290)
    configFrame.laserCheck = laserCheck

    local rawMouseCheck = CreateNativeCheckbox(card1_1, L["RAW_MOUSE_INPUT"],
        function() return Offhand.db and Offhand.db.rawMouseInput ~= false end,
        function(val)
            if Offhand.SetRawMouseInput then Offhand:SetRawMouseInput(val) else Offhand.db.rawMouseInput = val end
        end,
        L["RAW_MOUSE_INPUT_TIP_TITLE"], L["RAW_MOUSE_INPUT_TIP_DESC"]
    )
    rawMouseCheck:SetPoint("TOPLEFT", 12, -146)
    rawMouseCheck.Text:SetWidth(560)

    local rPortraitLeft = CreateNativeRadioButton(card1_1, L["PRESET_PL_LR"],
        function() return (Offhand.db and Offhand.db.layoutPreset == "PORTRAIT_LEFT_LANDSCAPE_RIGHT" and Offhand.db.primaryPosition == "RIGHT") end,
        function()
            Offhand.db.layoutPreset = "PORTRAIT_LEFT_LANDSCAPE_RIGHT"
            Offhand.db.primaryPosition = "RIGHT"
        end,
        L["PRESET_PL_LR_TIP_TITLE"], L["PRESET_PL_LR_TIP_DESC"]
    )
    rPortraitLeft:SetPoint("TOPLEFT", 12, -50)

    local rPortraitRight = CreateNativeRadioButton(card1_1, L["PRESET_GL_PR"],
        function() return (Offhand.db and Offhand.db.layoutPreset == "PORTRAIT_LEFT_LANDSCAPE_RIGHT" and Offhand.db.primaryPosition == "LEFT") end,
        function()
            Offhand.db.layoutPreset = "PORTRAIT_LEFT_LANDSCAPE_RIGHT"
            Offhand.db.primaryPosition = "LEFT"
        end,
        L["PRESET_GL_PR_TIP_TITLE"], L["PRESET_GL_PR_TIP_DESC"]
    )
    rPortraitRight:SetPoint("TOPLEFT", 330, -50)

    local rDual = CreateNativeRadioButton(card1_1, L["PRESET_DUAL_LANDSCAPE"],
        function() return (Offhand.db and Offhand.db.layoutPreset == "LANDSCAPE_DUAL") end,
        function()
            Offhand.db.layoutPreset = "LANDSCAPE_DUAL"
            Offhand.db.primaryPosition = "LEFT"
            Offhand.db.deckWidthRatio = 0.50
        end,
        L["PRESET_DUAL_LANDSCAPE_TIP_TITLE"], L["PRESET_DUAL_LANDSCAPE_TIP_DESC"]
    )
    rDual:SetPoint("TOPLEFT", 12, -74)
    
    local rVerticalBottom = CreateNativeRadioButton(card1_1, L["PRESET_STACK_BOTTOM"],
        function() return (Offhand.db and Offhand.db.primaryPosition == "BOTTOM") end,
        function()
            Offhand.db.layoutPreset = "STACKED_VERTICAL"
            Offhand.db.primaryPosition = "BOTTOM"
        end,
        L["STACKED_LAYOUT"], L["PRESET_STACK_BOTTOM"]
    )
    rVerticalBottom:SetPoint("TOPLEFT", 330, -74)

    local rVerticalTop = CreateNativeRadioButton(card1_1, L["PRESET_STACK_TOP"],
        function() return (Offhand.db and Offhand.db.primaryPosition == "TOP") end,
        function()
            Offhand.db.layoutPreset = "STACKED_VERTICAL"
            Offhand.db.primaryPosition = "TOP"
        end,
        L["STACKED_LAYOUT"], L["PRESET_STACK_TOP"]
    )
    rVerticalTop:SetPoint("TOPLEFT", 12, -98)

    local autoDetectBtn = CreateFrame("Button", nil, card1_1, "UIPanelButtonTemplate")
    autoDetectBtn:SetSize(200, 22)
    autoDetectBtn:SetPoint("TOPLEFT", 330, -98)
    autoDetectBtn:SetText(L["BTN_1CLICK_AUTOCONFIG"])
    autoDetectBtn:SetScript("OnClick", function()
        Options:AutoConfigure()
    end)
    if Offhand.SetTooltip then
        Offhand:SetTooltip(autoDetectBtn, L["BTN_1CLICK_AUTOCONFIG_TIP_TITLE"], L["BTN_1CLICK_AUTOCONFIG_TIP_DESC"])
    end
    card1_1.autoDetectBtn = autoDetectBtn


    local manualCanvasCard = CreateCard(tab1, L["CARD_MANUAL_CANVAS"], 96)
    local manualCanvasStatus = manualCanvasCard:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    manualCanvasStatus:SetPoint("TOPLEFT", 14, -30)
    manualCanvasStatus:SetPoint("RIGHT", manualCanvasCard, "RIGHT", -226, 0)
    manualCanvasStatus:SetJustifyH("LEFT")
    manualCanvasStatus:SetText(L["MANUAL_CANVAS_UNREMEMBERED"])
    configFrame.manualCanvasStatus = manualCanvasStatus

    local rememberCanvasBtn = CreateFrame("Button", nil, manualCanvasCard, "UIPanelButtonTemplate")
    rememberCanvasBtn:SetSize(200, 24)
    rememberCanvasBtn:SetPoint("TOPRIGHT", manualCanvasCard, "TOPRIGHT", -14, -28)
    rememberCanvasBtn:SetText(L["BTN_REMEMBER_CURRENT_WINDOW"])
    rememberCanvasBtn:SetScript("OnClick", function()
        local preview = Offhand.Viewport and Offhand.Viewport.GetManualPreviewMetrics
            and Offhand.Viewport:GetManualPreviewMetrics() or nil
        local method = Offhand.GetOnboardingSetupMethod
            and Offhand:GetOnboardingSetupMethod() or "MANUAL"
        local source = method == "FANCYZONES" and "FANCYZONES" or "MANUAL"
        local ok, reason, record
        if Offhand.ManualCanvas then
            ok, reason, record = Offhand.ManualCanvas:RememberFromMetrics(preview, nil, source)
        end
        if ok then
            if Offhand.ApplyFullLayout then Offhand:ApplyFullLayout() end
            Offhand:Print(L["MSG_MANUAL_CANVAS_REMEMBERED"], record.name,
                record.referenceWidth, record.referenceHeight)
        else
            Offhand:Print(L["MSG_MANUAL_CANVAS_REMEMBER_FAILED"], tostring(reason or "unavailable"))
        end
        Options:RefreshPanel()
    end)
    if Offhand.SetTooltip then
        Offhand:SetTooltip(rememberCanvasBtn, L["BTN_REMEMBER_CURRENT_WINDOW_TIP_TITLE"],
            L["BTN_REMEMBER_CURRENT_WINDOW_TIP_DESC"])
    end
    configFrame.rememberCanvasBtn = rememberCanvasBtn


    local card1_2 = CreateCard(tab1, L["CARD_VIEWPORT_AR"], 120)

    local r169 = CreateNativeRadioButton(card1_2, L["AR_16_9"],
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

    local rFill = CreateNativeRadioButton(card1_2, L["AR_FILL"],
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

    local motionCard = CreateCard(tab1, L["CARD_MOTION_CLARITY"], 88)

    local motionDesc = motionCard:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    motionDesc:SetPoint("TOPLEFT", 14, -30)
    motionDesc:SetPoint("TOPRIGHT", -14, -30)
    motionDesc:SetJustifyH("LEFT")
    motionDesc:SetText(L["MOTION_CLARITY_DESC"])

    local motionCheck = CreateNativeCheckbox(motionCard, L["CHECK_ANTI_SHIMMER"],
        function()
            return Offhand.IsAntiShimmerEnabled and Offhand:IsAntiShimmerEnabled() or false
        end,
        function(val)
            if Offhand.SetAntiShimmer then
                Offhand:SetAntiShimmer(val)
            elseif Offhand.db then
                Offhand.db.antiShimmer = val
            end
        end,
        L["CHECK_ANTI_SHIMMER_TIP_TITLE"], L["CHECK_ANTI_SHIMMER_TIP_DESC"])
    motionCheck:SetPoint("TOPLEFT", 12, -54)
    motionCheck.Text:SetWidth(500)

    local card1_3 = CreateCard(tab1, L["CARD_SCALE_ALIGNMENT"], 156)

    local bottomControl = Options:CreateBottomControl(card1_3)
    configFrame.bottomControl = bottomControl
    bottomControl:SetPoint("TOPLEFT", 12, -26)
    card1_3:SetHeight(math.max(156, 26 + bottomControl:GetHeight() + 12))

    local hudSlider = CreateNativeSlider(card1_3, L["SLIDER_HUD_SCALE"], 0.25, 1.25, 0.01,
        function() return (Offhand.db and Offhand.db.hudScale) or 0.70 end,
        function(val) Offhand.db.hudScale = val end,
        "%.0f%%",
        L["SLIDER_HUD_SCALE_TIP_TITLE"], L["SLIDER_HUD_SCALE_TIP_DESC"]
    )
    hudSlider:SetPoint("TOPLEFT", 336, -46)
    hudSlider:SetWidth(200)
    hudSlider:LayoutCompact()

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

    local card1_4 = CreateCard(tab1, L["CARD_WORLD_TEXT"], 150)

    local worldTextCheck = CreateNativeCheckbox(card1_4, L["WORLD_TEXT_COMPENSATION"],
        function() return Offhand.db and Offhand.db.worldTextCompensation ~= false end,
        function(val) Offhand.db.worldTextCompensation = val end,
        L["WORLD_TEXT_COMPENSATION_TIP_TITLE"], L["WORLD_TEXT_COMPENSATION_TIP_DESC"])
    worldTextCheck:SetPoint("TOPLEFT", 12, -28)
    worldTextCheck.Text:SetWidth(290)

    local worldTextSlider = CreateNativeSlider(card1_4, L["WORLD_TEXT_SCALE"], 0.50, 1.50, 0.01,
        function() return (Offhand.db and Offhand.db.worldTextScale) or 1 end,
        function(val) Offhand.db.worldTextScale = val end,
        "%.0f%%", L["WORLD_TEXT_SCALE_TIP_TITLE"], L["WORLD_TEXT_SCALE_TIP_DESC"])
    worldTextSlider:SetPoint("TOPLEFT", 336, -50)
    worldTextSlider:SetWidth(200)
    worldTextSlider:LayoutCompact()

    local speechBubbleCheck = CreateNativeCheckbox(card1_4, L["SPEECH_BUBBLE_COMPENSATION"],
        function() return Offhand.db and Offhand.db.speechBubbleCompensation ~= false end,
        function(val) Offhand.db.speechBubbleCompensation = val end,
        L["SPEECH_BUBBLE_COMPENSATION_TIP_TITLE"], L["SPEECH_BUBBLE_COMPENSATION_TIP_DESC"])
    speechBubbleCheck:SetPoint("TOPLEFT", 12, -92)
    speechBubbleCheck.Text:SetWidth(290)

    local speechBubbleSlider = CreateNativeSlider(card1_4, L["SPEECH_BUBBLE_SCALE"], 0.50, 1.50, 0.01,
        function() return (Offhand.db and Offhand.db.speechBubbleScale) or 1 end,
        function(val) Offhand.db.speechBubbleScale = val end,
        "%.0f%%", L["SPEECH_BUBBLE_SCALE_TIP_TITLE"], L["SPEECH_BUBBLE_SCALE_TIP_DESC"])
    speechBubbleSlider:SetPoint("TOPLEFT", 336, -114)
    speechBubbleSlider:SetWidth(200)
    speechBubbleSlider:LayoutCompact()

    local groupLootCard = CreateCard(tab1, L["CARD_GROUP_LOOT"], 126)

    local groupLootDescription = groupLootCard:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    groupLootDescription:SetPoint("TOPLEFT", 14, -32)
    groupLootDescription:SetWidth(365)
    groupLootDescription:SetJustifyH("LEFT")
    groupLootDescription:SetText(L["GROUP_LOOT_MOVE_DESC"])

    local groupLootMoveButton = CreateFrame("Button", nil, groupLootCard, "UIPanelButtonTemplate")
    groupLootMoveButton:SetSize(128, 24)
    groupLootMoveButton:SetPoint("TOPRIGHT", -150, -38)
    groupLootMoveButton:SetText(L["GROUP_LOOT_MOVE"])
    groupLootMoveButton:SetScript("OnClick", function()
        if not Offhand.HUD or not Offhand.HUD.ToggleGroupLootMover then return end
        local ok, reason = Offhand.HUD:ToggleGroupLootMover()
        if not ok then
            Offhand:Print(L["GROUP_LOOT_MOVE_UNAVAILABLE"], tostring(reason or "unavailable"))
        end
    end)
    if Offhand.SetTooltip then
        Offhand:SetTooltip(groupLootMoveButton,
            L["GROUP_LOOT_MOVE_TIP_TITLE"], L["GROUP_LOOT_MOVE_TIP_DESC"])
    end

    local groupLootResetButton = CreateFrame("Button", nil, groupLootCard, "UIPanelButtonTemplate")
    groupLootResetButton:SetSize(128, 24)
    groupLootResetButton:SetPoint("LEFT", groupLootMoveButton, "RIGHT", 8, 0)
    groupLootResetButton:SetText(L["GROUP_LOOT_RESET"])
    groupLootResetButton:SetScript("OnClick", function()
        if Offhand.HUD and Offhand.HUD.ResetGroupLootPosition then
            Offhand.HUD:ResetGroupLootPosition()
        end
    end)
    if Offhand.SetTooltip then
        Offhand:SetTooltip(groupLootResetButton,
            L["GROUP_LOOT_RESET_TIP_TITLE"], L["GROUP_LOOT_RESET_TIP_DESC"])
    end

    local groupLootDirectionCheck = CreateNativeCheckbox(groupLootCard, L["GROUP_LOOT_STACK_DOWN"],
        function()
            return Offhand.db and Offhand.db.groupLootStackDirection == "DOWN"
        end,
        function(value)
            if Offhand.HUD and Offhand.HUD.SetGroupLootStackDirection then
                Offhand.HUD:SetGroupLootStackDirection(value and "DOWN" or "UP")
            elseif Offhand.db then
                Offhand.db.groupLootStackDirection = value and "DOWN" or "UP"
            end
        end,
        L["GROUP_LOOT_STACK_DOWN_TIP_TITLE"], L["GROUP_LOOT_STACK_DOWN_TIP_DESC"])
    groupLootDirectionCheck:SetPoint("TOPLEFT", 12, -82)
    groupLootDirectionCheck.Text:SetWidth(500)

    local card1_5 = CreateCard(tab1, L["OBS_SETUP"], 110)
    
    local obsDesc = card1_5:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    obsDesc:SetPoint("TOPLEFT", 16, -26)
    obsDesc:SetPoint("TOPRIGHT", -16, -26)
    obsDesc:SetJustifyH("LEFT")
    obsDesc:SetText(L["OBS_HELP"])
    
    local obsSource1 = card1_5:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    obsSource1:SetPoint("TOPLEFT", 16, -60)
    obsSource1:SetJustifyH("LEFT")
    
    local obsSource2 = card1_5:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    obsSource2:SetPoint("TOPLEFT", 16, -80)
    obsSource2:SetJustifyH("LEFT")
    
    function Options:UpdateOBSCard()
        local m = Offhand.Viewport and Offhand.Viewport.GetMetrics and Offhand.Viewport:GetMetrics()
        if not m then return end
        
        local pw = m.physicalWidth or 0
        local ph = m.physicalHeight or 0
        local gameCropL = math.floor(m.gamePixelLeft + 0.5)
        local gameCropR = math.floor(pw - (m.gamePixelLeft + m.gamePixelWidth) + 0.5)
        local gameCropT = math.floor(ph - (m.gamePixelBottom + m.gamePixelHeight) + 0.5)
        local gameCropB = math.floor(m.gamePixelBottom + 0.5)
        local workspaceLeft = m.workspacePixelLeft or 0
        local workspaceBottom = m.workspacePixelBottom or 0
        local workspaceWidth = m.workspacePixelWidth or 0
        local workspaceHeight = m.workspacePixelHeight or 0
        local deckCropL = math.floor(workspaceLeft + 0.5)
        local deckCropR = math.floor(pw - (workspaceLeft + workspaceWidth) + 0.5)
        local deckCropT = math.floor(ph - (workspaceBottom + workspaceHeight) + 0.5)
        local deckCropB = math.floor(workspaceBottom + 0.5)

        obsSource1:SetText(string.format(L["OBS_GAME"] .. " — L:%d R:%d T:%d B:%d", gameCropL, gameCropR, gameCropT, gameCropB))
        obsSource2:SetText(string.format(L["OBS_WORKSPACE"] .. " — L:%d R:%d T:%d B:%d", deckCropL, deckCropR, deckCropT, deckCropB))
    end

    -- ========================================================================
    -- TAB 2: WORKSPACE & WORLD MAP
    -- ========================================================================
    local card2_1 = CreateCard(tab2, L["MAP_SETTINGS"], 150)

    local mapScaleSlider = CreateNativeSlider(card2_1, L["MAP_SCALE"], 0.50, 2.50, 0.05,
        function()
            local s = Offhand.db and Offhand.db.workspaceMapScale
            if s == "AUTO" then
                local m = Offhand.Viewport and Offhand.Viewport:GetMetrics()
                local baseWidth = (WorldMapFrame and WorldMapFrame:GetWidth()) or 610
                if baseWidth <= 0 then baseWidth = 610 end
                local availableWidth = (m and (m.workspaceWidth or m.deckWidth) and ((m.workspaceWidth or m.deckWidth) - 24)) or 610
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
    autoFitBtn:SetText(L["BTN_MAP_AUTOFIT"])
    autoFitBtn:SetScript("OnClick", function()
        Offhand.db.workspaceMapScale = "AUTO"
        if Offhand.Canvas and Offhand.Canvas.ConfigureWorldMap then
            Offhand.Canvas:ConfigureWorldMap()
        end
        local m = Offhand.Viewport and Offhand.Viewport:GetMetrics()
        local baseWidth = (WorldMapFrame and WorldMapFrame:GetWidth()) or 610
        if baseWidth <= 0 then baseWidth = 610 end
        local availableWidth = (m and (m.workspaceWidth or m.deckWidth) and ((m.workspaceWidth or m.deckWidth) - 24)) or 610
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
    mapTip:SetText(Offhand.isForever and L["MAP_SCALE_HELP_FOREVER"] or L["MAP_SCALE_HELP"])

    local mapMoveCheck = CreateNativeCheckbox(card2_1, L["MAP_KEEP_OPEN"],
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
    mapDesc:SetJustifyH("LEFT")
    mapDesc:SetWidth(530)
    mapDesc:SetWordWrap(true)
    local hasLMap = C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Leatrix_Maps") or (IsAddOnLoaded and IsAddOnLoaded("Leatrix_Maps"))
    if hasLMap then
        mapDesc:SetText(L["COMPAT_LEATRIX"])
    else
        mapDesc:SetText(L["MAP_KEEP_OPEN_DESC"])
    end


    local card2_2 = CreateCard(tab2, L["CARD_PERSISTENCE"],
        Offhand.isForever and 558 or 374)
    local supportsMainhandLayout = type(Offhand.HasBlizzardEditMode) == "function"
        and Offhand:HasBlizzardEditMode()
    -- Forever has two layout-status rows plus wrapped Edit Mode guidance.
    -- Keep the preview checkbox below that text instead of sharing its line.
    local recoveryHeight = Offhand.isForever and 374 or (supportsMainhandLayout and 302 or 152)
    local recoveryCard = CreateCard(tab2, L["CARD_RECOVERY"], recoveryHeight)
    local advancedCard
    local advancedCheck
    local foreverLayoutStatus
    local mainhandLayoutStatus
    local createLayout
    local gamepadDragHandlesCheck
    local gamepadFocusBindingStatus
    local offhandCards

    local function CreateRecoveryCaption(text, leftColumn, top)
        local caption = recoveryCard:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        if leftColumn then
            caption:SetPoint("TOPLEFT", recoveryCard, "TOPLEFT", 14, top)
            caption:SetPoint("TOPRIGHT", recoveryCard, "TOP", -8, top)
        else
            caption:SetPoint("TOPLEFT", recoveryCard, "TOP", 8, top)
            caption:SetPoint("TOPRIGHT", recoveryCard, "TOPRIGHT", -14, top)
        end
        caption:SetJustifyH("LEFT")
        caption:SetWordWrap(true)
        caption:SetText(text)
        return caption
    end

    if Offhand.isForever and SHOW_FOREVER_PROFESSIONS_COMPATIBILITY_UI then
        advancedCard = CreateCard(tab2, L["CARD_ADVANCED_COMPAT"], 52)
        local expanded = false
        local advancedControls = {}

        local disclosure = CreateFrame("Button", nil, advancedCard, "UIPanelButtonTemplate")
        disclosure:SetSize(172, 22)
        disclosure:SetPoint("TOPRIGHT", advancedCard, "TOPRIGHT", -10, -7)
        disclosure:SetText(L["ADVANCED_SHOW"])

        local warning = advancedCard:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        warning:SetPoint("TOPLEFT", advancedCard, "TOPLEFT", 14, -38)
        warning:SetPoint("TOPRIGHT", advancedCard, "TOPRIGHT", -14, -38)
        warning:SetJustifyH("LEFT")
        warning:SetWordWrap(true)
        warning:SetText("|cffffaa00" .. L["FOREVER_PROF_MOVE_DESC"] .. "|r")
        advancedControls[#advancedControls + 1] = warning

        advancedCheck = CreateNativeCheckbox(advancedCard, L["FOREVER_PROF_MOVE"],
            function()
                return Offhand.IsExperimentalForeverProfessionsMovementEnabled
                    and Offhand:IsExperimentalForeverProfessionsMovementEnabled() or false
            end,
            function(enabled)
                if not enabled then
                    if Offhand.SetExperimentalForeverProfessionsMovement then
                        Offhand:SetExperimentalForeverProfessionsMovement(false)
                    end
                    return
                end

                -- The native checkbox reflects committed consent only. Keep it
                -- off while the warning dialog is awaiting a decision.
                advancedCheck:SetChecked(false)
                Offhand:ShowPopup("OFFHAND_ENABLE_FOREVER_PROFESSIONS_MOVEMENT", nil, nil, function()
                    if Offhand.SetExperimentalForeverProfessionsMovement then
                        Offhand:SetExperimentalForeverProfessionsMovement(true)
                    end
                    advancedCheck:SetChecked(Offhand.IsExperimentalForeverProfessionsMovementEnabled
                        and Offhand:IsExperimentalForeverProfessionsMovementEnabled() or false)
                end)
            end,
            L["FOREVER_PROF_MOVE"], L["FOREVER_PROF_MOVE_DESC"]
        )
        advancedCheck:SetPoint("TOPLEFT", advancedCard, "TOPLEFT", 12, -102)
        advancedControls[#advancedControls + 1] = advancedCheck

        local forgetButton = CreateFrame("Button", nil, advancedCard, "UIPanelButtonTemplate")
        forgetButton:SetSize(220, 24)
        forgetButton:SetPoint("TOPLEFT", advancedCard, "TOPLEFT", 14, -138)
        forgetButton:SetText(L["FOREVER_PROF_FORGET"])
        forgetButton:SetScript("OnClick", function()
            if Offhand.Canvas and Offhand.Canvas.RelinquishForeverProfessionsPanels then
                Offhand.Canvas:RelinquishForeverProfessionsPanels()
            end
            Offhand:Print(L["FOREVER_PROF_FORGOT"])
        end)
        advancedControls[#advancedControls + 1] = forgetButton

        local function SetAdvancedExpanded(value)
            expanded = value == true
            advancedCard:SetHeight(expanded and 176 or 52)
            disclosure:SetText(expanded and L["ADVANCED_HIDE"] or L["ADVANCED_SHOW"])
            for _, control in ipairs(advancedControls) do SetShown(control, expanded) end
            if offhandCards then Options:StackCards(tab2, offhandCards) end
        end
        disclosure:SetScript("OnClick", function() SetAdvancedExpanded(not expanded) end)
        SetAdvancedExpanded(false)
    end

    local gatherBtn = CreateFrame("Button", nil, recoveryCard, "UIPanelButtonTemplate")
    gatherBtn:SetSize(160, 26)
    gatherBtn:SetPoint("TOPLEFT", 12, -30)
    gatherBtn:SetText(L["GATHER_UI"])
    gatherBtn:SetScript("OnClick", function() if Offhand.GatherOffScreenUI then Offhand:GatherOffScreenUI() end end)
    CreateRecoveryCaption(L["RECOVERY_RESCUE_LABEL"], true, -60)
    if Offhand.SetTooltip then
        Offhand:SetTooltip(gatherBtn, L["GATHER_UI"], L["RECOVERY_RESCUE_LABEL"])
    end

    local gatherMainhand = CreateFrame("Button", nil, recoveryCard, "UIPanelButtonTemplate")
    gatherMainhand:SetSize(220, 26)
    gatherMainhand:SetPoint("TOPRIGHT", recoveryCard, "TOPRIGHT", -12, -30)
    gatherMainhand:SetText(L["GATHER_MAINHAND_UI"])
    gatherMainhand:SetScript("OnClick", function()
        local ok, why, moved, skipped = Options:GatherSafeUIToMainhand()
        if ok then
            Offhand:Print(L["GATHER_MAINHAND_RESULT"], moved or 0, skipped or 0)
        else
            Offhand:Print(L[why == "combat" and "GATHER_COMBAT" or "GATHER_MAINHAND_UNAVAILABLE"])
        end
    end)
    if Offhand.SetTooltip then
        Offhand:SetTooltip(gatherMainhand, L["GATHER_MAINHAND_UI"], L["GATHER_MAINHAND_UI_DESC"])
    end
    CreateRecoveryCaption(L["RECOVERY_GATHER_LABEL"], false, -60)

    if supportsMainhandLayout then
        createLayout = CreateFrame("Button", nil, recoveryCard, "UIPanelButtonTemplate")
        createLayout:SetSize(220, 26)
        createLayout:SetPoint("TOPLEFT", recoveryCard, "TOPLEFT", 12, -104)
        createLayout:SetText(L["MAINHAND_LAYOUT_CREATE"])
        createLayout:SetScript("OnClick", function()
            local ok, value, moved, activation = Options:CreateMainhandHUDLayout()
            if ok then
                Offhand:Print(L["MAINHAND_LAYOUT_CREATED"], tostring(value), moved or 0)
                if activation == "select" and Offhand.Mainhand.PromptManualLayoutSelection then
                    Offhand.Mainhand:PromptManualLayoutSelection(value)
                else
                    Offhand.Mainhand:PromptReload()
                end
            else
                Offhand:Print(Options:GetMainhandLayoutFailureText(value))
            end
            if Options.RefreshPanel then Options:RefreshPanel() end
        end)
        if Offhand.SetTooltip then
            Offhand:SetTooltip(createLayout, L["MAINHAND_LAYOUT_CREATE"], L["MAINHAND_LAYOUT_CREATE_DESC"])
        end
        CreateRecoveryCaption(L["RECOVERY_CREATE_LABEL"], true, -134)

        mainhandLayoutStatus = recoveryCard:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        mainhandLayoutStatus:SetPoint("TOPLEFT", recoveryCard, "TOPLEFT", 14, -190)
        mainhandLayoutStatus:SetPoint("TOPRIGHT", recoveryCard, "TOPRIGHT", -14, -190)
        mainhandLayoutStatus:SetJustifyH("LEFT")
    end

    if Offhand.isForever then
        foreverLayoutStatus = recoveryCard:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        foreverLayoutStatus:SetPoint("TOPLEFT", recoveryCard, "TOPLEFT", 14, -214)
        foreverLayoutStatus:SetPoint("TOPRIGHT", recoveryCard, "TOPRIGHT", -14, -214)
        foreverLayoutStatus:SetJustifyH("LEFT")

        local useCurrentLayout = CreateFrame("Button", nil, recoveryCard, "UIPanelButtonTemplate")
        useCurrentLayout:SetSize(220, 26)
        useCurrentLayout:SetPoint("TOPRIGHT", recoveryCard, "TOPRIGHT", -12, -104)
        useCurrentLayout:SetText(L["FOREVER_EDIT_MODE_USE_CURRENT"])
        useCurrentLayout:SetScript("OnClick", function()
            local ok, value = Offhand.HUD and Offhand.HUD.UseCurrentForeverEditModeLayout
                and Offhand.HUD:UseCurrentForeverEditModeLayout()
            if ok then
                Offhand:Print(L["FOREVER_EDIT_MODE_LAYOUT_SAVED"], tostring(value))
            else
                Offhand:Print(L["FOREVER_EDIT_MODE_LAYOUT_FAILED"])
            end
            if Options.RefreshPanel then Options:RefreshPanel() end
        end)
        if Offhand.SetTooltip then
            Offhand:SetTooltip(useCurrentLayout, L["FOREVER_EDIT_MODE_USE_CURRENT"],
                L["FOREVER_EDIT_MODE_USE_CURRENT_DESC"])
        end
        CreateRecoveryCaption(L["RECOVERY_DESIGNATE_LABEL"], false, -134)

        local layoutHelp = recoveryCard:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        layoutHelp:SetPoint("TOPLEFT", recoveryCard, "TOPLEFT", 14, -238)
        layoutHelp:SetPoint("TOPRIGHT", recoveryCard, "TOPRIGHT", -14, -238)
        layoutHelp:SetJustifyH("LEFT")
        layoutHelp:SetWordWrap(true)
        layoutHelp:SetText(L["FOREVER_EDIT_MODE_USE_CURRENT_DESC"])
    end

    local proTipDesc = card2_2:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    proTipDesc:SetPoint("TOPLEFT", 10, -26)
    proTipDesc:SetPoint("TOPRIGHT", -10, -26)
    proTipDesc:SetJustifyH("LEFT")
    proTipDesc:SetText(L["CHECK_ALLOW_DRAG_TIP_DESC"])

    local panelCheck = CreateNativeCheckbox(card2_2, L["PANELS_INDEPENDENT"],
        function() return Offhand.db and Offhand.db.independentWorkspacePanels end,
        function(val) Offhand.db.independentWorkspacePanels = val end,
        L["CHECK_ESC_PERSIST_TIP_TITLE"], L["CHECK_ESC_PERSIST_TIP_DESC"]
    )
    panelCheck:SetPoint("TOPLEFT", 10, -66)

    local panelDesc = card2_2:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    panelDesc:SetPoint("TOPLEFT", 32, -88)
    panelDesc:SetText(L["PANELS_INDEPENDENT_DESC"])
    panelDesc:SetJustifyH("LEFT")
    panelDesc:SetWidth(530)
    panelDesc:SetWordWrap(true)

    local escapePersistenceDesc = Offhand.isForever
        and L["CHECK_ESC_PERSIST_TIP_DESC_FOREVER"] or L["CHECK_ESC_PERSIST_TIP_DESC"]
    local escapeCheck = CreateNativeCheckbox(card2_2, L["CHECK_ESC_PERSIST"],
        function() return Offhand.db and Offhand.db.persistentWorkspacePanels ~= false end,
        function(val)
            Offhand.db.persistentWorkspacePanels = val
            if Offhand.Canvas and Offhand.Canvas.UpdatePersistenceBehavior then
                Offhand.Canvas:UpdatePersistenceBehavior()
            end
        end,
        L["CHECK_ESC_PERSIST_TIP_TITLE"], escapePersistenceDesc
    )
    escapeCheck:SetPoint("TOPLEFT", 10, -110)

    local escapeDesc = card2_2:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    escapeDesc:SetPoint("TOPLEFT", 32, -132)
    escapeDesc:SetText(escapePersistenceDesc)
    escapeDesc:SetJustifyH("LEFT")
    escapeDesc:SetWidth(530)
    escapeDesc:SetWordWrap(true)

    local reloadCheck = CreateNativeCheckbox(card2_2, L["RELOAD_PERSIST"],
        function() return Offhand.db and Offhand.db.restoreWorkspaceOnReload ~= false end,
        function(val) Offhand.db.restoreWorkspaceOnReload = val end,
        L["RELOAD_PERSIST"], L["RELOAD_PERSIST"]
    )
    reloadCheck:SetPoint("TOPLEFT", 10, -164)

    local seamCheck = CreateNativeCheckbox(card2_2, L["REDIRECT_POPUPS"],
        function() return Offhand.db and Offhand.db.seamRedirect end,
        function(val) Offhand.db.seamRedirect = val end,
        L["CHECK_SEAM_REDIRECT_TIP_TITLE"], L["CHECK_SEAM_REDIRECT_TIP_DESC"]
    )
    seamCheck:SetPoint("TOPLEFT", 10, -190)

    local hideCloseCheck = CreateNativeCheckbox(card2_2, L["HIDE_WORKSPACE_CLOSE_BUTTONS"],
        function() return Offhand.db and Offhand.db.hideWorkspaceCloseButtons == true end,
        function(val)
            if Offhand.WorkspaceChrome and Offhand.WorkspaceChrome.SetEnabled then
                Offhand.WorkspaceChrome:SetEnabled(val)
            elseif Offhand.db then
                Offhand.db.hideWorkspaceCloseButtons = val == true
            end
        end,
        L["HIDE_WORKSPACE_CLOSE_BUTTONS"], L["HIDE_WORKSPACE_CLOSE_BUTTONS_DESC"]
    )
    hideCloseCheck:SetPoint("TOPLEFT", 10, -216)

    local hideCloseDesc = card2_2:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    hideCloseDesc:SetPoint("TOPLEFT", 32, -238)
    hideCloseDesc:SetWidth(530)
    hideCloseDesc:SetJustifyH("LEFT")
    hideCloseDesc:SetWordWrap(true)
    hideCloseDesc:SetText(L["HIDE_WORKSPACE_CLOSE_BUTTONS_DESC"])

    local hideMapMaximizeCheck = CreateNativeCheckbox(card2_2, L["HIDE_WORKSPACE_MAP_MAXIMIZE"],
        function() return Offhand.db and Offhand.db.hideWorkspaceMapMaximizeButton == true end,
        function(val)
            if Offhand.WorkspaceChrome and Offhand.WorkspaceChrome.SetMapMaximizeEnabled then
                Offhand.WorkspaceChrome:SetMapMaximizeEnabled(val)
            elseif Offhand.db then
                Offhand.db.hideWorkspaceMapMaximizeButton = val == true
            end
        end,
        L["HIDE_WORKSPACE_MAP_MAXIMIZE"], L["HIDE_WORKSPACE_MAP_MAXIMIZE_DESC"]
    )
    hideMapMaximizeCheck:SetPoint("TOPLEFT", 10, -282)

    local hideMapMaximizeDesc = card2_2:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    hideMapMaximizeDesc:SetPoint("TOPLEFT", 32, -304)
    hideMapMaximizeDesc:SetWidth(530)
    hideMapMaximizeDesc:SetJustifyH("LEFT")
    hideMapMaximizeDesc:SetWordWrap(true)
    hideMapMaximizeDesc:SetText(L["HIDE_WORKSPACE_MAP_MAXIMIZE_DESC"])

    if Offhand.isForever then
        gamepadDragHandlesCheck = CreateNativeCheckbox(card2_2,
            L["SHOW_GAMEPAD_DRAG_HANDLES"],
            function()
                if Offhand.Mainhand and Offhand.Mainhand.AreForeverGamepadDragHandlesShown then
                    return Offhand.Mainhand:AreForeverGamepadDragHandlesShown()
                end
                return true
            end,
            function(val)
                if Offhand.Mainhand and Offhand.Mainhand.SetForeverGamepadDragHandlesShown then
                    Offhand.Mainhand:SetForeverGamepadDragHandlesShown(val)
                elseif Offhand.db then
                    Offhand.db.showGamepadPanelDragHandles = val == true
                end
            end,
            L["SHOW_GAMEPAD_DRAG_HANDLES"], L["SHOW_GAMEPAD_DRAG_HANDLES_DESC"]
        )
        gamepadDragHandlesCheck:SetPoint("TOPLEFT", 10, -330)

        local gamepadDragHandlesDesc = card2_2:CreateFontString(nil,
            "ARTWORK", "GameFontHighlightSmall")
        gamepadDragHandlesDesc:SetPoint("TOPLEFT", 32, -352)
        gamepadDragHandlesDesc:SetWidth(530)
        gamepadDragHandlesDesc:SetJustifyH("LEFT")
        gamepadDragHandlesDesc:SetWordWrap(true)
        gamepadDragHandlesDesc:SetText(L["SHOW_GAMEPAD_DRAG_HANDLES_DESC"])

        local gamepadFocusTitle = card2_2:CreateFontString(nil,
            "ARTWORK", "GameFontNormal")
        gamepadFocusTitle:SetPoint("TOPLEFT", card2_2, "TOPLEFT", 14, -396)
        gamepadFocusTitle:SetText(L["GAMEPAD_FOCUS_CONTROL_TITLE"])

        local gamepadFocusButton = CreateFrame("Button", nil, card2_2,
            "UIPanelButtonTemplate")
        gamepadFocusButton:SetSize(210, 24)
        gamepadFocusButton:SetPoint("TOPRIGHT", card2_2, "TOPRIGHT", -14, -386)
        gamepadFocusButton:SetText(L["GAMEPAD_FOCUS_CONTROL_BUTTON"])
        gamepadFocusButton:SetScript("OnClick", function()
            local ok = Options:OpenGamepadFocusKeybindings()
            if not ok then Offhand:Print(L["GAMEPAD_FOCUS_CONTROL_UNAVAILABLE"]) end
        end)

        local gamepadFocusDesc = card2_2:CreateFontString(nil,
            "ARTWORK", "GameFontHighlightSmall")
        gamepadFocusDesc:SetPoint("TOPLEFT", card2_2, "TOPLEFT", 32, -426)
        gamepadFocusDesc:SetWidth(530)
        gamepadFocusDesc:SetJustifyH("LEFT")
        gamepadFocusDesc:SetWordWrap(true)
        gamepadFocusDesc:SetText(L["GAMEPAD_FOCUS_CONTROL_DESC"])

        gamepadFocusBindingStatus = card2_2:CreateFontString(nil,
            "ARTWORK", "GameFontHighlightSmall")
        gamepadFocusBindingStatus:SetPoint("TOPLEFT", card2_2, "TOPLEFT", 32, -478)
        gamepadFocusBindingStatus:SetWidth(530)
        gamepadFocusBindingStatus:SetJustifyH("LEFT")
        gamepadFocusBindingStatus:SetText(GamepadFocusBindingStatusText())
        Options.gamepadFocusBindingStatus = gamepadFocusBindingStatus
    end

    local forceCheck = CreateNativeCheckbox(recoveryCard, L["PREVIEW_DUAL"],
        function() return (Offhand.db and Offhand.db.forceDualOnSingle) or false end,
        function(val) Offhand.db.forceDualOnSingle = val end,
        L["PREVIEW_DUAL"], L["PREVIEW_DUAL"]
    )
    forceCheck:SetPoint("TOPLEFT", 12,
        Offhand.isForever and -304 or (supportsMainhandLayout and -230 or -112))

    if supportsMainhandLayout then
        local autoEditModeControls = CreateNativeCheckbox(recoveryCard, L["AUTO_RECOVER_EDIT_MODE_CONTROLS"],
            function() return Offhand.db and Offhand.db.autoRecoverEditModeControls ~= false end,
            function(value) Offhand.db.autoRecoverEditModeControls = value == true end,
            L["AUTO_RECOVER_EDIT_MODE_CONTROLS"], L["AUTO_RECOVER_EDIT_MODE_CONTROLS_DESC"])
        autoEditModeControls:SetPoint("TOPLEFT", forceCheck, "BOTTOMLEFT", 0, -6)
    end

    local compatDesc = card2_2:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    compatDesc:SetPoint("TOPLEFT", 32, Offhand.isForever and -528 or -344)
    compatDesc:SetWidth(530)
    compatDesc:SetJustifyH("LEFT")
    compatDesc:SetWordWrap(true)
    card2_2.compatDesc = compatDesc

    local windowControlCard = CreateCard(tab2, L["CARD_WORKSPACE_WINDOW_CONTROL"], 274)

    local characterScaleSlider = CreateNativeSlider(windowControlCard, L["CHARACTER_WORKSPACE_SCALE"],
        0.75, 1.50, 0.05,
        function()
            return Offhand.WorkspaceBehavior and Offhand.WorkspaceBehavior:GetCharacterScale() or 1
        end,
        function(value)
            if Offhand.WorkspaceBehavior then
                Offhand.WorkspaceBehavior:SetCharacterScale(value)
            elseif Offhand.db then
                Offhand.db.characterWorkspaceScale = value
            end
        end,
        "%.0f%%", L["CHARACTER_WORKSPACE_SCALE_TIP_TITLE"],
        L["CHARACTER_WORKSPACE_SCALE_TIP_DESC"])
    characterScaleSlider:SetPoint("TOPLEFT", windowControlCard, "TOPLEFT", 14, -58)
    characterScaleSlider:SetWidth(260)

    local lockCheck = CreateNativeCheckbox(windowControlCard, L["LOCK_WORKSPACE_WINDOWS"],
        function() return Offhand.db and Offhand.db.lockWorkspaceWindows == true end,
        function(value)
            if Offhand.WorkspaceBehavior then
                Offhand.WorkspaceBehavior:SetLockEnabled(value)
            elseif Offhand.db then
                Offhand.db.lockWorkspaceWindows = value == true
            end
            if C_Timer and C_Timer.After then
                C_Timer.After(0, function()
                    if Options.RefreshPanel then Options:RefreshPanel() end
                end)
            end
        end,
        L["LOCK_WORKSPACE_WINDOWS_TIP_TITLE"], L["LOCK_WORKSPACE_WINDOWS_TIP_DESC"])
    lockCheck:SetPoint("TOPLEFT", 12, -104)

    local lockDesc = windowControlCard:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    lockDesc:SetPoint("TOPLEFT", 34, -128)
    lockDesc:SetPoint("TOPRIGHT", -14, -128)
    lockDesc:SetJustifyH("LEFT")
    lockDesc:SetWordWrap(true)
    lockDesc:SetText(Offhand.isForever
        and L["LOCK_WORKSPACE_WINDOWS_FOREVER"] or L["LOCK_WORKSPACE_WINDOWS_DESC"])

    local function CreateLockTypeCheck(label, kind, top)
        local check = CreateNativeCheckbox(windowControlCard, label,
            function()
                local types = Offhand.db and Offhand.db.lockedWorkspaceWindowTypes
                return not types or types[kind] ~= false
            end,
            function(value)
                if Offhand.WorkspaceBehavior then
                    Offhand.WorkspaceBehavior:SetWindowTypeLocked(kind, value)
                end
            end,
            L["LOCK_WORKSPACE_WINDOWS_TIP_TITLE"], L["LOCK_WORKSPACE_WINDOWS_TIP_DESC"])
        check:SetPoint("TOPLEFT", 34, top)
        return check
    end

    local lockMapCheck = CreateLockTypeCheck(L["LOCK_WORKSPACE_MAP"], "map", -180)
    local lockBagsCheck = CreateLockTypeCheck(L["LOCK_WORKSPACE_BAGS"], "bags", -206)
    local lockCharacterCheck = CreateLockTypeCheck(L["LOCK_WORKSPACE_CHARACTER"], "character", -232)


    local card2_3 = CreateCard(tab1, L["CARD_BEZEL"], 116)

    local bezelSlider = CreateNativeSlider(card2_3, L["SLIDER_BEZEL_GAP"], 0, 100, 2,
        function() return (Offhand.db and Offhand.db.bezelGap) or 0 end,
        function(val) Offhand.db.bezelGap = val end,
        "%d px",
        L["SLIDER_BEZEL_GAP_TIP_TITLE"], L["SLIDER_BEZEL_GAP_TIP_DESC"]
    )
    bezelSlider:SetPoint("TOPLEFT", 12, -54)
    bezelSlider:SetWidth(290)


    local bezelNote = card2_3:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    bezelNote:SetPoint("TOPLEFT", 12, -76)
    bezelNote:SetText(L["SLIDER_BEZEL_GAP_TIP_DESC"])
    bezelNote:SetJustifyH("LEFT")
    bezelNote:SetWidth(530)
    bezelNote:SetWordWrap(true)

    -- ========================================================================
    -- TAB 3: THEMES & COLOR CUSTOMIZATION
    -- ========================================================================
    local card3_1 = CreateCard(tab3, L["CARD_THEMES"], 200)

    local rClassic = CreateNativeRadioButton(card3_1, L["THEME_CLASSIC"],
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
    subClassic:SetWidth(280)
    subClassic:SetWordWrap(true)
    subClassic:SetJustifyH("LEFT")
    subClassic:SetPoint("TOPLEFT", 34, -46)
    subClassic:SetText(L["THEME_CLASSIC_DESC"])

    local rSlate = CreateNativeRadioButton(card3_1, L["THEME_SLATE"],
        function() return (Offhand.db and Offhand.db.theme == "BLIZZARD_SLATE") end,
        function()
            Offhand.db.theme = "BLIZZARD_SLATE"
            Offhand.db.trimColor = "SILVER"
            Offhand.db.canvasColor = "CHARCOAL"
            Offhand:UpdateTheme()
        end,
        L["THEME_SLATE_TIP_TITLE"], L["THEME_SLATE_TIP_DESC"]
    )
    rSlate:SetPoint("TOPLEFT", 320, -26)

    local subSlate = card3_1:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subSlate:SetWidth(280)
    subSlate:SetWordWrap(true)
    subSlate:SetJustifyH("LEFT")
    subSlate:SetPoint("TOPLEFT", 342, -46)
    subSlate:SetText(L["THEME_SLATE_DESC"])

    local rTinker = CreateNativeRadioButton(card3_1, L["THEME_TINKER"],
        function() return (Offhand.db and Offhand.db.theme == "GNOMISH_TINKER") end,
        function()
            Offhand.db.theme = "GNOMISH_TINKER"
            Offhand.db.trimColor = "TINKER_BRASS"
            Offhand.db.canvasColor = "TINKER_SLATE"
            Offhand:UpdateTheme()
        end,
        L["THEME_TINKER_TIP_TITLE"], L["THEME_TINKER_TIP_DESC"]
    )
    rTinker:SetPoint("TOPLEFT", 12, -142)

    local subTinker = card3_1:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subTinker:SetWidth(280)
    subTinker:SetWordWrap(true)
    subTinker:SetJustifyH("LEFT")
    subTinker:SetPoint("TOPLEFT", 34, -162)
    subTinker:SetText(L["THEME_TINKER_DESC"])

    local rObsidian = CreateNativeRadioButton(card3_1, L["THEME_OBSIDIAN"],
        function() return (Offhand.db and Offhand.db.theme == "OBSIDIAN") end,
        function()
            Offhand.db.theme = "OBSIDIAN"
            Offhand.db.trimColor = "BRONZE"
            Offhand.db.canvasColor = "CHARCOAL"
            Offhand:UpdateTheme()
        end,
        L["THEME_OBSIDIAN_TIP_TITLE"], L["THEME_OBSIDIAN_TIP_DESC"]
    )
    rObsidian:SetPoint("TOPLEFT", 12, -84)

    local subObsidian = card3_1:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subObsidian:SetWidth(280)
    subObsidian:SetWordWrap(true)
    subObsidian:SetJustifyH("LEFT")
    subObsidian:SetPoint("TOPLEFT", 34, -104)
    subObsidian:SetText(L["THEME_OBSIDIAN_DESC"])

    local rPitchBlack = CreateNativeRadioButton(card3_1, L["CANVAS_BLACK"],
        function() return (Offhand.db and Offhand.db.theme == "PITCH_BLACK") end,
        function()
            Offhand.db.theme = "PITCH_BLACK"
            Offhand.db.canvasColor = "PURE_BLACK"
            Offhand:UpdateTheme()
        end,
        L["THEME_PITCH_BLACK_TIP_TITLE"], L["THEME_PITCH_BLACK_TIP_DESC"]
    )
    rPitchBlack:SetPoint("TOPLEFT", 320, -84)

    local subPitchBlack = card3_1:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subPitchBlack:SetWidth(280)
    subPitchBlack:SetWordWrap(true)
    subPitchBlack:SetJustifyH("LEFT")
    subPitchBlack:SetPoint("TOPLEFT", 342, -104)
    subPitchBlack:SetText(L["THEME_PITCH_BLACK_DESC"])

    Controls.LayoutChoiceDescriptions(card3_1, {
        { radio = rClassic, body = subClassic, text = L["THEME_CLASSIC_DESC"] },
        { radio = rSlate, body = subSlate, text = L["THEME_SLATE_DESC"] },
        { radio = rObsidian, body = subObsidian, text = L["THEME_OBSIDIAN_DESC"] },
        { radio = rPitchBlack, body = subPitchBlack, text = L["THEME_PITCH_BLACK_DESC"] },
        { radio = rTinker, body = subTinker, text = L["THEME_TINKER_DESC"] },
    }, 2)


    local card3_2 = CreateCard(tab3, L["CARD_TRIM_COLOR"], 94)

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
                Controls.SetButtonTextColor(btn, 1.0, 0.95, 0.60, 1.0)
            else
                if btn.UnlockHighlight then btn:UnlockHighlight() end
                Controls.SetButtonTextColor(btn, t[3], t[4], t[5], 1.0)
            end
        end
        if customTrimBtn then
            local isCustom = (curTrim == "CUSTOM")
            Options:SetChoiceSelected(customTrimBtn, isCustom)
            local c = (Offhand.db and Offhand.db.customTrimColor) or { r = 1.0, g = 0.82, b = 0.0 }
            if isCustom then
                customTrimBtn:SetText(string.format(L["BTN_TRIM_CUSTOM_ACTIVE_FMT"], math.floor(c.r*255+0.5), math.floor(c.g*255+0.5), math.floor(c.b*255+0.5)))
                if customTrimBtn.LockHighlight then customTrimBtn:LockHighlight() end
                Controls.SetButtonTextColor(customTrimBtn, 0.2, 1.0, 0.4, 1.0)
            else
                customTrimBtn:SetText(L["BTN_TRIM_CUSTOM"])
                if customTrimBtn.UnlockHighlight then customTrimBtn:UnlockHighlight() end
                Controls.SetButtonTextColor(customTrimBtn, 1.0, 0.82, 0.0, 1.0)
            end
        end
    end
    Options:UpdateTrimHighlights()


    local card3_3 = CreateCard(tab3, L["CARD_CANVAS_BACKGROUND"], 210)

    local canvasButtons = {
        { "CLASSIC_STONE", "Classic Stone" },
        { "TINKER_SLATE",  "Tinker Slate" },
        { "CHARCOAL",      "Charcoal Slate" },
        { "WARM_NIGHT",    "Warm Night" },
        { "DEEP_BLUE",     "Midnight Navy" },
        { "PURE_BLACK",    L["CANVAS_BLACK"] },
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
    local swatchCard = CreateFrame("Frame", nil, card3_3, BackdropTemplate())
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
                Controls.SetButtonTextColor(btn, 1.0, 0.95, 0.60, 1.0)
            else
                if btn.UnlockHighlight then btn:UnlockHighlight() end
                Controls.SetButtonTextColor(btn, 1.0, 0.82, 0.0, 1.0)
            end
        end
        if customCanvasBtn then
            local isCustom = (curColor == "CUSTOM")
            Options:SetChoiceSelected(customCanvasBtn, isCustom)
            local c = (Offhand.db and Offhand.db.customCanvasColor) or { r = 0.12, g = 0.22, b = 0.35 }
            if isCustom then
                customCanvasBtn:SetText(string.format(L["BTN_CANVAS_CUSTOM_ACTIVE_FMT"], math.floor(c.r*255+0.5), math.floor(c.g*255+0.5), math.floor(c.b*255+0.5)))
                if customCanvasBtn.LockHighlight then customCanvasBtn:LockHighlight() end
                Controls.SetButtonTextColor(customCanvasBtn, 0.2, 1.0, 0.4, 1.0)
            else
                customCanvasBtn:SetText(L["BTN_CANVAS_CUSTOM"])
                if customCanvasBtn.UnlockHighlight then customCanvasBtn:UnlockHighlight() end
                Controls.SetButtonTextColor(customCanvasBtn, 1.0, 0.82, 0.0, 1.0)
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
            swatchText:SetText(string.format(L["BTN_CANVAS_PREVIEW_TIP_TITLE"] .. ": %s (%d%%)", pName, math.floor(curAlpha * 100 + 0.5)))
        end
    end

    alphaSlider = CreateNativeSlider(card3_3, L["SLIDER_CANVAS_OPACITY"], 0.10, 1.0, 0.05,
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
    themeNote:SetText(L["BTN_CANVAS_PREVIEW_TIP_DESC"])

    local card3_4 = CreateCard(tab3, L["CARD_USER_MEDIA"], 176)

    local userMediaStatus = card3_4:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    userMediaStatus:SetPoint("TOPLEFT", 14, -30)
    userMediaStatus:SetPoint("TOPRIGHT", -14, -30)
    userMediaStatus:SetJustifyH("LEFT")
    userMediaStatus:SetWordWrap(true)

    local userMediaEnableCheck = CreateNativeCheckbox(card3_4, L["USER_MEDIA_ENABLE"],
        function() return Offhand.db and Offhand.db.userMediaEnabled == true end,
        function(value)
            local enabled = Offhand.UserMedia and Offhand.UserMedia.SetEnabled
                and Offhand.UserMedia:SetEnabled(value)
            if value and not enabled then
                local status, reason = "MISSING", nil
                if Offhand.UserMedia and Offhand.UserMedia.GetStatus then
                    status, reason = Offhand.UserMedia:GetStatus()
                end
                Offhand:Print(status == "INVALID" and reason == "LEGACY_OR_UNSUPPORTED_SCHEMA"
                    and L["USER_MEDIA_STATUS_LEGACY"]
                    or status == "INVALID" and L["USER_MEDIA_STATUS_INVALID"]
                    or status == "DISABLED" and L["USER_MEDIA_STATUS_DISABLED"]
                    or L["USER_MEDIA_STATUS_MISSING"])
            end
            if Options.UpdateUserMediaControls then Options:UpdateUserMediaControls() end
        end,
        L["USER_MEDIA_ENABLE_TIP_TITLE"], L["USER_MEDIA_ENABLE_TIP_DESC"])
    userMediaEnableCheck:SetPoint("TOPLEFT", 12, -70)

    local function SelectUserMediaFit(mode)
        if Offhand.UserMedia and Offhand.UserMedia.SetFitMode then
            Offhand.UserMedia:SetFitMode(mode)
        elseif Offhand.db then
            Offhand.db.userMediaFitMode = mode
        end
    end

    local userMediaPackageFit = CreateNativeRadioButton(card3_4, L["USER_MEDIA_FIT_PACKAGE"],
        function() return Offhand.db and Offhand.db.userMediaFitMode == "PACKAGE" end,
        function() SelectUserMediaFit("PACKAGE") end,
        L["USER_MEDIA_FIT_TIP_TITLE"], L["USER_MEDIA_FIT_TIP_DESC"])
    userMediaPackageFit:SetPoint("TOPLEFT", 12, -104)

    local userMediaFillFit = CreateNativeRadioButton(card3_4, L["USER_MEDIA_FIT_FILL"],
        function() return Offhand.db and Offhand.db.userMediaFitMode == "FILL" end,
        function() SelectUserMediaFit("FILL") end,
        L["USER_MEDIA_FIT_TIP_TITLE"], L["USER_MEDIA_FIT_TIP_DESC"])
    userMediaFillFit:SetPoint("TOPLEFT", 220, -104)

    local userMediaContainFit = CreateNativeRadioButton(card3_4, L["USER_MEDIA_FIT_FIT"],
        function() return Offhand.db and Offhand.db.userMediaFitMode == "FIT" end,
        function() SelectUserMediaFit("FIT") end,
        L["USER_MEDIA_FIT_TIP_TITLE"], L["USER_MEDIA_FIT_TIP_DESC"])
    userMediaContainFit:SetPoint("TOPLEFT", 330, -104)

    local userMediaStretchFit = CreateNativeRadioButton(card3_4, L["USER_MEDIA_FIT_STRETCH"],
        function() return Offhand.db and Offhand.db.userMediaFitMode == "STRETCH" end,
        function() SelectUserMediaFit("STRETCH") end,
        L["USER_MEDIA_FIT_TIP_TITLE"], L["USER_MEDIA_FIT_TIP_DESC"])
    userMediaStretchFit:SetPoint("TOPLEFT", 430, -104)

    local userMediaRestartNote = card3_4:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    userMediaRestartNote:SetPoint("TOPLEFT", 14, -138)
    userMediaRestartNote:SetPoint("TOPRIGHT", -14, -138)
    userMediaRestartNote:SetJustifyH("LEFT")
    userMediaRestartNote:SetText(L["USER_MEDIA_RESTART_NOTE"])

    local userMediaFitControls = {
        userMediaPackageFit, userMediaFillFit, userMediaContainFit, userMediaStretchFit,
    }

    function Options:UpdateUserMediaControls()
        local status, reason, metadata = "MISSING", nil, nil
        if Offhand.UserMedia and Offhand.UserMedia.GetStatus then
            status, reason, metadata = Offhand.UserMedia:GetStatus()
        end
        if status == "AVAILABLE" and metadata then
            userMediaStatus:SetText(string.format(L["USER_MEDIA_STATUS_AVAILABLE"],
                metadata.imageWidth, metadata.imageHeight,
                metadata.textureWidth, metadata.textureHeight, metadata.schema))
        elseif status == "DISABLED" then
            userMediaStatus:SetText(L["USER_MEDIA_STATUS_DISABLED"])
        elseif status == "INVALID" then
            userMediaStatus:SetText(reason == "LEGACY_OR_UNSUPPORTED_SCHEMA"
                and L["USER_MEDIA_STATUS_LEGACY"] or L["USER_MEDIA_STATUS_INVALID"])
        else
            userMediaStatus:SetText(L["USER_MEDIA_STATUS_MISSING"])
        end

        userMediaEnableCheck:SetChecked(Offhand.db and Offhand.db.userMediaEnabled == true or false)
        local configuredFit = Offhand.db and Offhand.db.userMediaFitMode or "PACKAGE"
        userMediaPackageFit:SetChecked(configuredFit == "PACKAGE")
        userMediaFillFit:SetChecked(configuredFit == "FILL")
        userMediaContainFit:SetChecked(configuredFit == "FIT")
        userMediaStretchFit:SetChecked(configuredFit == "STRETCH")
        local available = status == "AVAILABLE"
        for _, control in ipairs(userMediaFitControls) do
            SetCheckboxEnabled(control, available)
        end
    end

    -- ========================================================================
    -- TAB 4: PROFILES
    -- ========================================================================
    local card4_1
    do -- Keep profile-only locals below Lua 5.1's per-function local limit.
        card4_1 = CreateCard(tab4, L["PROFILES_LIST_TITLE"], 390)
    
        local activeProfileLabel = card4_1:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
        activeProfileLabel:SetPoint("TOPLEFT", 16, -24)
        activeProfileLabel:SetWidth(630)
        if activeProfileLabel.SetWordWrap then activeProfileLabel:SetWordWrap(false) end
        activeProfileLabel:SetText(L["PROFILES_CURRENT_LABEL"] .. " |cff00ff00" .. tostring((OffhandCharDB and OffhandCharDB.activeProfile) or "Default") .. "|r")

        local profileScroll = CreateFrame("ScrollFrame", "OffhandProfileScrollFrame", card4_1, "UIPanelScrollFrameTemplate")
        profileScroll:SetPoint("TOPLEFT", 16, -56)
        profileScroll:SetSize(280, 220)
        Controls.EnableWheelScroll(profileScroll)
    
        local profileScrollBG = CreateFrame("Frame", nil, profileScroll, BackdropTemplate())
        profileScrollBG:SetPoint("TOPLEFT", -4, 4)
        profileScrollBG:SetPoint("BOTTOMRIGHT", 24, -4)
        if profileScrollBG.SetFrameLevel then
            profileScrollBG:SetFrameLevel(profileScroll.GetFrameLevel and (profileScroll:GetFrameLevel() - 1) or 1)
        end
        Controls.StyleSurface(profileScrollBG, "input")

        local profileScrollContent = CreateFrame("Frame", nil, profileScroll)
        profileScrollContent:SetSize(280, 420)
        if profileScroll.SetScrollChild then profileScroll:SetScrollChild(profileScrollContent) end

        local selectedProfileName = nil
        local profileButtons = {}
        local profileRowHeight = 30
    
        local loadBtn = CreateFrame("Button", nil, card4_1, "UIPanelButtonTemplate")
        loadBtn:SetSize(160, 26)
        loadBtn:SetPoint("TOPLEFT", profileScroll, "TOPRIGHT", 40, 0)
        loadBtn:SetText(L["PROFILES_BTN_LOAD"])
    
        local copyBtn = CreateFrame("Button", nil, card4_1, "UIPanelButtonTemplate")
        copyBtn:SetSize(160, 26)
        copyBtn:SetPoint("TOPLEFT", loadBtn, "BOTTOMLEFT", 0, -8)
        copyBtn:SetText(L["PROFILE_COPY_INTO_CURRENT"])
    
        local deleteBtn = CreateFrame("Button", nil, card4_1, "UIPanelButtonTemplate")
        deleteBtn:SetSize(160, 26)
        deleteBtn:SetPoint("TOPLEFT", copyBtn, "BOTTOMLEFT", 0, -8)
        deleteBtn:SetText(L["PROFILES_BTN_DELETE"])
    
        local resetBtn = CreateFrame("Button", nil, card4_1, "UIPanelButtonTemplate")
        resetBtn:SetSize(160, 26)
        resetBtn:SetPoint("TOPLEFT", deleteBtn, "BOTTOMLEFT", 0, -24)
        resetBtn:SetText(L["PROFILES_BTN_RESET"])
    
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
        createBtn:SetText(L["PROFILES_BTN_CREATE"])
        configFrame.profileControls = {
            rows = profileButtons, scroll = profileScroll, input = createEditBox,
            create = createBtn, load = loadBtn, copy = copyBtn, delete = deleteBtn,
        }

        local autoSaveNote = card4_1:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        autoSaveNote:SetPoint("TOPLEFT", profileScroll, "BOTTOMLEFT", 0, -72)
        autoSaveNote:SetWidth(620)
        autoSaveNote:SetJustifyH("LEFT")
        autoSaveNote:SetText(L["SETTINGS_AUTOSAVE"])

        function Options:UpdateProfileList()
            local profiles = Offhand.GetProfiles and Offhand:GetProfiles() or {"Default"}
            activeProfileLabel:SetText(L["PROFILES_CURRENT_LABEL"] .. " |cff00ff00" .. tostring((OffhandCharDB and OffhandCharDB.activeProfile) or "Default") .. "|r")
        
            -- Hide old buttons
            for _, btn in ipairs(profileButtons) do btn:Hide() end
            local selectionExists = false
            for _, name in ipairs(profiles) do
                if name == selectedProfileName then selectionExists = true; break end
            end
            if not selectionExists then selectedProfileName = nil end
        
            local yOffset = -4
            for i, pName in ipairs(profiles) do
                local btn = profileButtons[i]
                if not btn then
                    btn = CreateFrame("Button", nil, profileScrollContent, "UIPanelButtonTemplate")
                    btn:SetSize(270, 28)
                    local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                    fs:SetPoint("LEFT", btn, "LEFT", 8, 0)
                    fs:SetWidth(154)
                    fs:SetJustifyH("LEFT")
                    if fs.SetWordWrap then fs:SetWordWrap(false) end
                    btn.text = fs
                    local active = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    active:SetPoint("RIGHT", btn, "RIGHT", -8, 0)
                    active:SetWidth(90)
                    active:SetJustifyH("RIGHT")
                    if active.SetWordWrap then active:SetWordWrap(false) end
                    btn.activeText = active
                
                    btn:SetScript("OnClick", function(self)
                        selectedProfileName = self.profileName
                        Options:UpdateProfileList()
                    end)
                    profileButtons[i] = btn
                end
                btn.profileName = pName
                btn:ClearAllPoints()
                btn:SetPoint("TOPLEFT", profileScrollContent, "TOPLEFT", 4, yOffset)
                btn.text:SetText(pName)
                btn.activeText:SetText(pName == ((OffhandCharDB and OffhandCharDB.activeProfile) or "Default")
                    and L["PROFILE_ACTIVE"] or "")
                Controls.SetChoiceSelected(btn, pName == selectedProfileName)
                if Offhand.SetTooltip then Offhand:SetTooltip(btn, pName) end
                btn:Show()
                yOffset = yOffset - profileRowHeight
            end
        
            profileScrollContent:SetHeight(math.max(220, #profiles * profileRowHeight + 8))
            Controls.SetScrollOffset(profileScroll,
                profileScroll.GetVerticalScroll and profileScroll:GetVerticalScroll() or 0)
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
        local function CreateProfileFromInput()
            local t = strtrim(createEditBox:GetText() or "")
            if t ~= "" and Offhand.CreateProfile then
                local success, err = Offhand:CreateProfile(t)
                if success then
                    createEditBox:SetText("")
                    createEditBox:ClearFocus()
                    selectedProfileName = t
                    Options:UpdateProfileList()
                    for index, name in ipairs(Offhand:GetProfiles()) do
                        if name == t then
                            Controls.EnsureScrollVisible(profileScroll, (index - 1) * profileRowHeight + 4, 28)
                            break
                        end
                    end
                else
                    Offhand:Print("|cffff3333" .. tostring(err) .. "|r")
                end
            end
        end
        createBtn:SetScript("OnClick", CreateProfileFromInput)
        createEditBox:SetScript("OnEnterPressed", CreateProfileFromInput)
        createEditBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    end

    -- ========================================================================
    -- TAB 5: FAQ & HELP
    -- ========================================================================
    local function MeasureHelpText(fontString, text)
        return Controls.MeasureWrappedText(fontString, text, 630)
    end

    local function FitHelpCard(card, body, text, reservedHeight, minimumHeight)
        local bodyHeight = MeasureHelpText(body, text)
        card:SetHeight(math.max(minimumHeight or 88, bodyHeight + (reservedHeight or 50)))
    end

    local helpOverview = CreateCard(tab5, L["HELP_OVERVIEW_TITLE"], 1)
    local overviewTop = Controls.GetCardContentTop(helpOverview, 32)
    local overviewBody = helpOverview:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    overviewBody:SetPoint("TOPLEFT", helpOverview, "TOPLEFT", 14, -overviewTop)
    overviewBody:SetWidth(634)
    if overviewBody.SetWordWrap then overviewBody:SetWordWrap(true) end
    overviewBody:SetJustifyH("LEFT")
    overviewBody:SetText(L["HELP_OVERVIEW_BODY"])
    FitHelpCard(helpOverview, overviewBody, L["HELP_OVERVIEW_BODY"], overviewTop + 56, 132)

    local onboardingHelpBtn = CreateFrame("Button", nil, helpOverview, "UIPanelButtonTemplate")
    onboardingHelpBtn:SetSize(145, 26)
    onboardingHelpBtn:SetPoint("BOTTOMLEFT", 14, 14)
    onboardingHelpBtn:SetText(L["ONBOARD_TITLE"])
    onboardingHelpBtn:SetScript("OnClick", function()
        if Offhand.Onboarding and Offhand.Onboarding.Open then Offhand.Onboarding:Open() end
    end)

    local wizardHelpBtn = CreateFrame("Button", nil, helpOverview, "UIPanelButtonTemplate")
    wizardHelpBtn:SetSize(145, 26)
    wizardHelpBtn:SetPoint("LEFT", onboardingHelpBtn, "RIGHT", 10, 0)
    wizardHelpBtn:SetText(L["BTN_AUTO_WIZARD"])
    wizardHelpBtn:SetScript("OnClick", function()
        if Offhand.Wizard and Offhand.Wizard.Open then Offhand.Wizard:Open() end
    end)

    local gatherHelpBtn = CreateFrame("Button", nil, helpOverview, "UIPanelButtonTemplate")
    gatherHelpBtn:SetSize(145, 26)
    gatherHelpBtn:SetPoint("LEFT", wizardHelpBtn, "RIGHT", 10, 0)
    gatherHelpBtn:SetText(L["GATHER_UI"])
    gatherHelpBtn:SetScript("OnClick", function()
        if Offhand.GatherOffScreenUI then Offhand:GatherOffScreenUI() end
    end)

    local companionHelpBtn = CreateFrame("Button", nil, helpOverview, "UIPanelButtonTemplate")
    companionHelpBtn:SetSize(145, 26)
    companionHelpBtn:SetPoint("LEFT", gatherHelpBtn, "RIGHT", 10, 0)
    companionHelpBtn:SetText(L["POPUP_BTN_SETUP_GUIDE"])
    companionHelpBtn:SetScript("OnClick", function()
        if Offhand.Onboarding and Offhand.Onboarding.Open then Offhand.Onboarding:Open() end
    end)

    local helpCards = { helpOverview }
    local helpTopics = { "SETUP", "COMPANION", "EDIT_MODE", "PANELS", "COLD_LAUNCH", "RECOVERY", "WELCOME" }
    for index, topic in ipairs(helpTopics) do
        local title = string.format("%d. %s", index, L["HELP_" .. topic .. "_TITLE"])
        local text = L["HELP_" .. topic .. "_BODY"]
        local card = CreateCard(tab5, title, 1)
        local contentTop = Controls.GetCardContentTop(card, 34)
        local body = card:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        body:SetPoint("TOPLEFT", card, "TOPLEFT", 16, -contentTop)
        body:SetWidth(630)
        if body.SetWordWrap then body:SetWordWrap(true) end
        body:SetJustifyH("LEFT")
        body:SetText(text)
        FitHelpCard(card, body, text, contentTop + 16, 88)
        helpCards[#helpCards + 1] = card
    end

    Options:StackCards(tab1, {card1_1, manualCanvasCard, card1_2, motionCard,
        card1_3, card2_3, card1_4, groupLootCard, card1_5})
    offhandCards = {card2_1, card2_2, windowControlCard}
    if advancedCard then offhandCards[#offhandCards + 1] = advancedCard end
    offhandCards[#offhandCards + 1] = recoveryCard
    Options:StackCards(tab2, offhandCards)
    Options:StackCards(tab3, {card3_1, card3_2, card3_3, card3_4})
    Options:StackCards(tab4, {card4_1})
    Options:StackCards(tab5, helpCards)

    -- ========================================================================
    -- BOTTOM ACTION BAR (Shared across tabs)
    -- ========================================================================
    local applyBtn = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
    applyBtn:SetSize(150, 28)
    applyBtn:SetPoint("BOTTOMLEFT", 20, 14)
    applyBtn:SetText(L["BTN_REAPPLY"])
    applyBtn.uiPrimary = true
    applyBtn:SetScript("OnClick", function()
        Offhand:ApplyFullLayout()
        Offhand:Print(L["MSG_LAYOUT_APPLIED"])
    end)
    if Offhand.SetTooltip then
        Offhand:SetTooltip(applyBtn, L["BTN_APPLY_LAYOUT_TIP_TITLE"], L["BTN_APPLY_LAYOUT_TIP_DESC"])
    end

    local saveStatus = configFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    saveStatus:SetPoint("BOTTOM", configFrame, "BOTTOM", 0, 23)
    saveStatus:SetWidth(540)
    saveStatus:SetJustifyH("CENTER")
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
        local bannerText
        if info.exactTopology then
            bannerText = string.format(L["COMPANION_TOPOLOGY_SUMMARY"],
                info.gamePixelWidth, info.gamePixelHeight,
                info.workspacePixelWidth, info.workspacePixelHeight)
                .. "\n|cffaaaaaa" .. L["EXACT_TOPOLOGY_LOCKED"] .. "|r"
        else
            bannerText = string.format(L["TAB_DISPLAY"] .. ": %s (%dx%d)",
                info.description, info.physWidth, info.physHeight)
        end
        compAppBtn:Show()
        banner:ClearAllPoints()
        banner:SetPoint("TOPLEFT", 218, -94)
        banner:SetPoint("TOPRIGHT", -24, -94)
        banner:SetText(bannerText)
        local bannerHeight = math.max(24, banner.GetStringHeight and banner:GetStringHeight() or 24)
        local actionTop = 94 + bannerHeight + 8
        autoWizardBtn:ClearAllPoints()
        autoWizardBtn:SetPoint("TOPRIGHT", configFrame, "TOPRIGHT", -24, -actionTop)
        optionsScrollFrame:ClearAllPoints()
        optionsScrollFrame:SetPoint("TOPLEFT", 218, -(actionTop + 38))
        optionsScrollFrame:SetPoint("BOTTOMRIGHT", -42, 52)

        local manualMetrics = Offhand.Viewport and Offhand.Viewport.GetMetrics
            and Offhand.Viewport:GetMetrics() or nil
        local manualDiag = Offhand.ManualCanvas and Offhand.ManualCanvas.GetDiagnostics
            and Offhand.ManualCanvas:GetDiagnostics() or nil
        if configFrame.manualCanvasStatus then
            if manualMetrics and manualMetrics.manualCanvas then
                configFrame.manualCanvasStatus:SetText(string.format(
                    L["MANUAL_CANVAS_MATCHED"],
                    tostring(manualMetrics.manualCanvasName or L["MANUAL_CANVAS_DEFAULT_NAME"]),
                    tostring(manualMetrics.manualCanvasState or "MATCH"),
                    manualMetrics.physicalWidth or 0, manualMetrics.physicalHeight or 0))
            elseif manualDiag and manualDiag.count > 0 then
                configFrame.manualCanvasStatus:SetText(string.format(
                    L["MANUAL_CANVAS_MISMATCH"],
                    manualMetrics and manualMetrics.physicalWidth or 0,
                    manualMetrics and manualMetrics.physicalHeight or 0))
            else
                configFrame.manualCanvasStatus:SetText(L["MANUAL_CANVAS_UNREMEMBERED"])
            end
        end
        if configFrame.rememberCanvasBtn then
            configFrame.rememberCanvasBtn:SetEnabled(not info.exactTopology)
            if configFrame.rememberCanvasBtn.SetAlpha then
                configFrame.rememberCanvasBtn:SetAlpha(info.exactTopology and 0.55 or 1)
            end
        end

        seamSlider:UpdateText()
        configFrame.bottomControl:Refresh()

        local manualGeometryEnabled = not info.exactTopology
        for _, control in ipairs({rPortraitLeft, rPortraitRight, rDual, rVerticalBottom,
            rVerticalTop, r169, r219, rFill, seamSlider, p36Btn, p50Btn, p55Btn}) do
            if control == seamSlider then Offhand.UIControls.SetSliderEnabled(control, manualGeometryEnabled)
            elseif control and control.SetEnabled then control:SetEnabled(manualGeometryEnabled) end
            if control and control.SetAlpha then control:SetAlpha(manualGeometryEnabled and 1 or 0.55) end
        end

        enableCheck:SetChecked((Offhand.db and Offhand.db.enabled) or false)
        laserCheck:SetChecked(Options:IsSeamGuideShown())
        rawMouseCheck:SetChecked((Offhand.db and Offhand.db.rawMouseInput ~= false) or false)
        worldTextCheck:SetChecked((Offhand.db and Offhand.db.worldTextCompensation ~= false) or false)
        speechBubbleCheck:SetChecked((Offhand.db and Offhand.db.speechBubbleCompensation ~= false) or false)
        worldTextSlider:UpdateText()
        speechBubbleSlider:UpdateText()

        rPortraitLeft:SetChecked(Offhand.db and Offhand.db.layoutPreset == "PORTRAIT_LEFT_LANDSCAPE_RIGHT" and Offhand.db.primaryPosition == "RIGHT")
        rPortraitRight:SetChecked(Offhand.db and Offhand.db.layoutPreset == "PORTRAIT_LEFT_LANDSCAPE_RIGHT" and Offhand.db.primaryPosition == "LEFT")
        rDual:SetChecked(Offhand.db and Offhand.db.layoutPreset == "LANDSCAPE_DUAL")
        rVerticalBottom:SetChecked(Offhand.db and Offhand.db.primaryPosition == "BOTTOM")
        rVerticalTop:SetChecked(Offhand.db and Offhand.db.primaryPosition == "TOP")

        r169:SetChecked(Offhand.db and Offhand.db.aspectRatioMode == "16_9")
        r219:SetChecked(Offhand.db and Offhand.db.aspectRatioMode == "21_9")
        rFill:SetChecked(Offhand.db and Offhand.db.aspectRatioMode == "FILL")

        seamCheck:SetChecked((Offhand.db and Offhand.db.seamRedirect) or false)
        hideCloseCheck:SetChecked((Offhand.db and Offhand.db.hideWorkspaceCloseButtons == true) or false)
        hideMapMaximizeCheck:SetChecked((Offhand.db and Offhand.db.hideWorkspaceMapMaximizeButton == true) or false)
        if gamepadDragHandlesCheck then
            local showGamepadDragHandles = true
            if Offhand.Mainhand and Offhand.Mainhand.AreForeverGamepadDragHandlesShown then
                showGamepadDragHandles = Offhand.Mainhand:AreForeverGamepadDragHandlesShown()
            end
            gamepadDragHandlesCheck:SetChecked(showGamepadDragHandles)
        end
        if gamepadFocusBindingStatus then
            gamepadFocusBindingStatus:SetText(GamepadFocusBindingStatusText())
        end
        mapMoveCheck:SetChecked((Offhand.db and Offhand.db.preventMapCloseOnMove) or false)
        panelCheck:SetChecked((Offhand.db and Offhand.db.independentWorkspacePanels) or false)
        escapeCheck:SetChecked((Offhand.db and Offhand.db.persistentWorkspacePanels ~= false) or false)
        reloadCheck:SetChecked((Offhand.db and Offhand.db.restoreWorkspaceOnReload ~= false) or false)
        forceCheck:SetChecked((Offhand.db and Offhand.db.forceDualOnSingle) or false)
        characterScaleSlider:UpdateText()
        local lockSupported = Offhand.WorkspaceBehavior
            and Offhand.WorkspaceBehavior:IsLockSupported() or not Offhand.isForever
        lockCheck:SetChecked(lockSupported
            and (Offhand.db and Offhand.db.lockWorkspaceWindows == true) or false)
        local lockTypes = Offhand.db and Offhand.db.lockedWorkspaceWindowTypes or nil
        lockMapCheck:SetChecked(not lockTypes or lockTypes.map ~= false)
        lockBagsCheck:SetChecked(not lockTypes or lockTypes.bags ~= false)
        lockCharacterCheck:SetChecked(not lockTypes or lockTypes.character ~= false)
        SetCheckboxEnabled(lockCheck, lockSupported)
        local lockChildrenEnabled = lockSupported
            and Offhand.db and Offhand.db.lockWorkspaceWindows == true
        SetCheckboxEnabled(lockMapCheck, lockChildrenEnabled)
        SetCheckboxEnabled(lockBagsCheck, lockChildrenEnabled)
        SetCheckboxEnabled(lockCharacterCheck, lockChildrenEnabled)
        if motionCheck then
            motionCheck:SetChecked(Offhand.IsAntiShimmerEnabled and Offhand:IsAntiShimmerEnabled() or false)
        end
        if groupLootDirectionCheck then
            groupLootDirectionCheck:SetChecked(Offhand.db and Offhand.db.groupLootStackDirection == "DOWN" or false)
        end
        if advancedCheck then
            advancedCheck:SetChecked(Offhand.IsExperimentalForeverProfessionsMovementEnabled
                and Offhand:IsExperimentalForeverProfessionsMovementEnabled() or false)
        end
        if foreverLayoutStatus then
            local status = Offhand.HUD and Offhand.HUD.GetForeverEditModeLayoutStatus
                and Offhand.HUD:GetForeverEditModeLayoutStatus() or nil
            local name = status and status.preferredName or L["FOREVER_EDIT_MODE_LAYOUT_UNSET"]
            if status and status.preferredName and not status.preferredAvailable then
                name = string.format(L["FOREVER_EDIT_MODE_LAYOUT_MISSING_STATUS"], status.preferredName)
            end
            foreverLayoutStatus:SetText(string.format(L["FOREVER_EDIT_MODE_LAYOUT_LABEL"], name))
        end
        if mainhandLayoutStatus then
            local controllerLayout = Offhand.Mainhand and Offhand.Mainhand.IsControllerLayout
                and Offhand.Mainhand:IsControllerLayout()
            local canCreateController = controllerLayout and Offhand.Mainhand
                and Offhand.Mainhand.CanCreateControllerLayout
                and Offhand.Mainhand:CanCreateControllerLayout()
            if createLayout then
                local enabled = not controllerLayout or canCreateController
                createLayout:SetEnabled(enabled)
                createLayout:SetAlpha(enabled and 1 or 0.55)
            end
            local status = Offhand.Mainhand and Offhand.Mainhand.GetLayoutStatus
                and Offhand.Mainhand:GetLayoutStatus() or nil
            local name = controllerLayout and (canCreateController
                    and L["MAINHAND_LAYOUT_GAMEPAD_STATUS"] or L["MAINHAND_LAYOUT_GAMEPAD_FAILED"])
                or status and status.deferred and L["MAINHAND_LAYOUT_DEFERRED"]
                or (status and status.configured and status.generatedName
                    or L["MAINHAND_LAYOUT_UNSET"])
            if not controllerLayout and status and status.configured and not status.deferred
                and not status.currentGeometry then
                name = string.format(L["MAINHAND_LAYOUT_STALE"], tostring(name))
            end
            mainhandLayoutStatus:SetText(string.format(L["MAINHAND_LAYOUT_STATUS"], tostring(name)))
        end

        local curTheme = (Offhand.db and Offhand.db.theme) or "CLASSIC"
        rClassic:SetChecked(curTheme == "CLASSIC")
        rSlate:SetChecked(curTheme == "BLIZZARD_SLATE")
        rTinker:SetChecked(curTheme == "GNOMISH_TINKER")
        rObsidian:SetChecked(curTheme == "OBSIDIAN")
        rPitchBlack:SetChecked(curTheme == "PITCH_BLACK")

        if Options.UpdateUserMediaControls then
            Options:UpdateUserMediaControls()
        end

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
                card2_2.compatDesc:SetText(L["COMPAT_BOTH"])
            elseif bagAddon then
                card2_2.compatDesc:SetText(L["COMPAT_BAGS"])
            elseif mmAddon then
                card2_2.compatDesc:SetText(L["COMPAT_MINIMAP"])
            else
                card2_2.compatDesc:SetText(L["COMPAT_AUTO"])
            end
        end
        if Options.UpdateOBSCard then
            Options:UpdateOBSCard()
        end
        Options:UpdateCardThemes()
        Offhand:ApplyFullLayout()
    end

    -- Canvas persistence may restore this frame by calling Show() directly,
    -- bypassing Options:Open(). Always resync checkbox/radio state from the
    -- live profile so a stale construction-time checkbox cannot invert a click.
    configFrame:SetScript("OnShow", function()
        Controls.FitDialog(configFrame, Offhand.Viewport and Offhand.Viewport:GetMetrics())
        Options:RefreshPanel()
    end)

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
    local panelScale = Controls.FitDialog(panel, m)
    if m and m.gameWidth and m.gameWidth > 0 then
        local cx = (m.gameLeft + m.gameRight) / 2
        local cy = (m.gameBottom + m.gameTop) / 2
        panel:ClearAllPoints()
        panel:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx / panelScale, cy / panelScale)
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
    if configFrame then
        configFrame:Hide()
    end
end

--

function Offhand:InitializeOptions()
    -- Options ready
end



