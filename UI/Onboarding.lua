--[[
    Offhand: Multi-Monitor Setup Addon
    UI/Onboarding.lua: account-wide first-launch installation and window setup guide

    This is intentionally separate from UI/Wizard.lua. Onboarding explains and
    verifies the installation workflow; the existing wizard calibrates a window
    that has already been spanned successfully.
--]]

local _, Offhand = ...
local Controls = assert(Offhand.UIControls, "Offhand UI controls must load before Onboarding")
local CreateFrame = Controls.CreateFrame
local L = Offhand.L

local Onboarding = {}
Offhand.Onboarding = Onboarding

local guideFrame
local PAGE_COUNT = 6
local resumeAfterDownload

local function BringPopupForward(dialog)
    if not dialog then return nil end
    if dialog.SetFrameStrata then dialog:SetFrameStrata("TOOLTIP") end
    if dialog.Raise then dialog:Raise() end
    return dialog
end

StaticPopupDialogs["OFFHAND_CONFIRM_MANUAL_LAYOUT"] = {
    text = L["ONBOARD_MANUAL_CONFIRM_TEXT"],
    button1 = L["ONBOARD_MANUAL_CONFIRM_ACCEPT"],
    button2 = L["BTN_BACK"],
    OnAccept = function(_, callback)
        if callback then callback() end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["OFFHAND_CONFIRM_MANUAL_LAYOUT_FOREVER"] = {
    text = L["ONBOARD_MANUAL_CONFIRM_TEXT_FOREVER"],
    button1 = L["ONBOARD_MANUAL_CONFIRM_ACCEPT"],
    button2 = L["BTN_BACK"],
    OnAccept = function(_, callback)
        if callback then callback() end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local function Metrics()
    return Offhand.Viewport and Offhand.Viewport.GetMetrics
        and Offhand.Viewport:GetMetrics() or nil
end

local function SupportsGeneratedMainhandLayout()
    return type(Offhand.HasBlizzardEditMode) == "function"
        and Offhand:HasBlizzardEditMode()
end

local function SetupStatus()
    local m = Metrics()
    local method = Offhand.GetOnboardingSetupMethod
        and Offhand:GetOnboardingSetupMethod() or nil
    if Offhand._displayGeometryTransitionActive then
        return false, L["ONBOARD_STATUS_GEOMETRY_SETTLING"]
    end
    if not method then
        return false, L["ONBOARD_STATUS_METHOD_REQUIRED"]
    end
    if not m then
        return false, L["ONBOARD_STATUS_NOT_SPANNED"]
    end
    if method == "COMPANION" and m.topologyStatus == "MISMATCH" then
        return false, L["ONBOARD_STATUS_TOPOLOGY_MISMATCH"]
    end
    -- WoW exposes the complete render canvas, but not the number or rectangles
    -- of the physical displays beneath a manually resized window. Therefore an
    -- absent Companion topology cannot honestly distinguish a dual-display
    -- span, an intentional single-ultrawide split, and an ordinary window.
    -- Require the player to acknowledge the manual logical split instead of
    -- reporting an automatic detection that the client cannot perform.
    if method == "COMPANION" and not m.companionTopology then
        return false, L["ONBOARD_STATUS_COMPANION_RELOAD_REQUIRED"]
    end
    if method == "MANUAL" or method == "FANCYZONES" then
        local preview = Offhand.Viewport and Offhand.Viewport.GetManualPreviewMetrics
            and Offhand.Viewport:GetManualPreviewMetrics() or nil
        if not preview or not preview.physicalWidth or preview.physicalWidth <= 0
            or not preview.physicalHeight or preview.physicalHeight <= 0 then
            return false, L["ONBOARD_STATUS_NOT_SPANNED"]
        end
        return true, L["ONBOARD_STATUS_MANUAL_CONFIRM"], true, preview
    end
    if not m.isSpanned then
        return false, L["ONBOARD_STATUS_NOT_SPANNED"]
    end
    if m.companionVersionStatus == "MISMATCH" then
        return false, string.format(L["ONBOARD_STATUS_VERSION_MISMATCH"],
            tostring(m.companionVersion or "?"),
            tostring(m.expectedCompanionVersion or Offhand.companionFullVersion or "?"))
    end
    if m.companionVersionStatus == "UNKNOWN" then
        return true, L["ONBOARD_STATUS_VERSION_UNKNOWN"]
    end
    return true, L["ONBOARD_STATUS_READY"]
end

function Onboarding:CreateFrame()
    if guideFrame then return guideFrame end
    if not CreateFrame then return nil end

    local f = CreateFrame("Frame", "OffhandFirstLaunchFrame", UIParent,
        not Offhand.isLegacyWrath and "BackdropTemplate" or nil)
    f:SetSize(660, 430)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:EnableMouse(true)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    if UISpecialFrames and tinsert then tinsert(UISpecialFrames, "OffhandFirstLaunchFrame") end

    if Offhand.Themes and Offhand.Themes.ApplyBackdrop then
        Offhand.Themes:ApplyBackdrop(f, (Offhand.db and Offhand.db.theme) or "CLASSIC", 1)
    end
    if Offhand.Themes and Offhand.Themes.CreateBayHeader then
        f.header = Offhand.Themes:CreateBayHeader(f, L["ONBOARD_TITLE"])
    end

    local close = CreateFrame("Button", nil, f.header or f, "UIPanelCloseButton")
    close:SetSize(28, 28)
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -5, -5)
    close:SetScript("OnClick", function() f:Hide() end)

    local step = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    step:SetPoint("TOPLEFT", f, "TOPLEFT", 24, -58)
    f.stepText = step

    local title = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 24, -88)
    title:SetPoint("TOPRIGHT", f, "TOPRIGHT", -24, -88)
    title:SetJustifyH("LEFT")
    f.pageTitle = title

    local body = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    body:SetPoint("TOPLEFT", f, "TOPLEFT", 24, -126)
    body:SetPoint("TOPRIGHT", f, "TOPRIGHT", -24, -126)
    body:SetHeight(190)
    body:SetJustifyH("LEFT")
    body:SetJustifyV("TOP")
    if body.SetWordWrap then body:SetWordWrap(true) end
    f.pageBody = body

    local status = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    status:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 24, 74)
    status:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -24, 74)
    status:SetHeight(42)
    status:SetJustifyH("CENTER")
    status:SetJustifyV("MIDDLE")
    if status.SetWordWrap then status:SetWordWrap(true) end
    f.statusText = status

    local action = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    action:SetSize(190, 26)
    action:SetPoint("BOTTOM", f, "BOTTOM", 0, 115)
    f.actionButton = action

    local secondaryAction = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    secondaryAction:SetSize(190, 26)
    secondaryAction:SetPoint("LEFT", action, "RIGHT", 12, 0)
    f.secondaryActionButton = secondaryAction

    local tertiaryAction = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    tertiaryAction:SetSize(190, 26)
    tertiaryAction:SetPoint("LEFT", secondaryAction, "RIGHT", 12, 0)
    f.tertiaryActionButton = tertiaryAction

    local back = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    back:SetSize(110, 28)
    back:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 24, 24)
    back:SetText(L["BTN_BACK"])
    back:SetScript("OnClick", function() f:SetPage(f.page - 1) end)
    f.backButton = back

    local nextButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    nextButton:SetSize(150, 28)
    nextButton:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -24, 24)
    nextButton:SetScript("OnClick", function()
        if f.page == 2 and (not Offhand.GetOnboardingSetupMethod
            or not Offhand:GetOnboardingSetupMethod()) then
            f.statusText:SetText("|cffff5555" .. L["ONBOARD_STATUS_METHOD_REQUIRED"] .. "|r")
            return
        end
        if f.page == 4 then
            local ready, message, confirmManual, preview = SetupStatus()
            f.statusText:SetText((ready and "|cff55ff55" or "|cffff5555") .. message .. "|r")
            if not ready then return end
            if confirmManual then
                local popup = Offhand.isForever and "OFFHAND_CONFIRM_MANUAL_LAYOUT_FOREVER"
                    or "OFFHAND_CONFIRM_MANUAL_LAYOUT"
                local dialog = Offhand:ShowPopup(popup, nil, nil, function()
                    if f.page ~= 4 then return end
                    local method = Offhand.GetOnboardingSetupMethod
                        and Offhand:GetOnboardingSetupMethod() or "MANUAL"
                    local ok = Offhand.ManualCanvas
                        and Offhand.ManualCanvas:RememberFromMetrics(preview, nil, method)
                    if not ok then
                        f.statusText:SetText("|cffff5555" .. L["ONBOARD_STATUS_NOT_SPANNED"] .. "|r")
                        return
                    end
                    if Offhand.ApplyFullLayout then Offhand:ApplyFullLayout() end
                    f:SetPage(5)
                end)
                BringPopupForward(dialog)
                return
            end
        end
        if f.page < PAGE_COUNT then
            f:SetPage(f.page + 1)
            return
        end
        if Offhand.MarkWelcomeDismissed then Offhand:MarkWelcomeDismissed() end
        f:Hide()
        if Offhand.Wizard and Offhand.Wizard.Open then Offhand.Wizard:Open() end
    end)
    f.nextButton = nextButton

    function f:SetPage(page)
        self.page = math.max(1, math.min(PAGE_COUNT, page or 1))
        self.stepText:SetText(string.format(L["ONBOARD_PROGRESS"], self.page, PAGE_COUNT))
        local titleKey = "ONBOARD_STEP_" .. self.page .. "_TITLE"
        if self.page == 5 and not SupportsGeneratedMainhandLayout() then
            titleKey = "ONBOARD_STEP_5_TITLE_NO_EDITMODE"
        end
        self.pageTitle:SetText(L[titleKey])
        local bodyKey = "ONBOARD_STEP_" .. self.page .. "_BODY"
        if self.page == 5 and not SupportsGeneratedMainhandLayout() then
            bodyKey = "ONBOARD_STEP_5_BODY_NO_EDITMODE"
        elseif self.page == 5 and Offhand.isForever then
            bodyKey = bodyKey .. "_FOREVER"
        elseif self.page == 5 then
            bodyKey = "ONBOARD_STEP_5_BODY_EDITMODE"
        elseif self.page == 6 and not SupportsGeneratedMainhandLayout() then
            bodyKey = "ONBOARD_STEP_6_BODY_NO_EDITMODE"
        elseif self.page == 6 then
            bodyKey = "ONBOARD_STEP_6_BODY_EDITMODE"
        end
        self.pageBody:SetText(L[bodyKey])
        self.backButton:SetEnabled(self.page > 1)
        self.nextButton:SetText(self.page == PAGE_COUNT
            and L["ONBOARD_START_CALIBRATION"] or L["BTN_NEXT"])
        self.statusText:SetText(self.page == 4 and L["ONBOARD_STATUS_CHECK_PROMPT"] or "")
        self.actionButton:Hide()
        self.secondaryActionButton:Hide()
        self.tertiaryActionButton:Hide()
        self.actionButton:SetEnabled(true)
        self.actionButton:SetScript("OnClick", nil)
        if self.page == 2 then
            local method = Offhand.GetOnboardingSetupMethod
                and Offhand:GetOnboardingSetupMethod() or nil
            self.actionButton:ClearAllPoints()
            self.actionButton:SetPoint("BOTTOM", self, "BOTTOM", -202, 115)
            self.actionButton:SetText(L["ONBOARD_USE_FANCYZONES"])
            self.actionButton:SetScript("OnClick", function()
                if Offhand.SetOnboardingSetupMethod then
                    Offhand:SetOnboardingSetupMethod("FANCYZONES")
                end
                if Offhand.ManualCanvas then Offhand.ManualCanvas:SetGeometryPreference("MANUAL") end
                resumeAfterDownload = self.page
                self:Hide()
                local dialog = Offhand:ShowPopup("OFFHAND_POWERTOYS_LINK")
                if dialog and dialog.SetFrameStrata then dialog:SetFrameStrata("TOOLTIP") end
                if not dialog then
                    resumeAfterDownload = nil
                    self:Show()
                end
            end)
            self.actionButton:Show()
            self.secondaryActionButton:SetText(L["ONBOARD_USE_COMPANION"])
            self.secondaryActionButton:SetScript("OnClick", function()
                if Offhand.SetOnboardingSetupMethod then
                    Offhand:SetOnboardingSetupMethod("COMPANION")
                end
                if Offhand.ManualCanvas then Offhand.ManualCanvas:SetGeometryPreference("AUTO") end
                resumeAfterDownload = self.page
                self:Hide()
                local dialog = Offhand:ShowPopup("OFFHAND_DOWNLOAD_LINK")
                if dialog and dialog.SetFrameStrata then dialog:SetFrameStrata("TOOLTIP") end
                if not dialog then
                    resumeAfterDownload = nil
                    self:Show()
                end
            end)
            self.secondaryActionButton:Show()
            self.tertiaryActionButton:SetText(L["ONBOARD_USE_MANUAL"])
            self.tertiaryActionButton:SetScript("OnClick", function()
                if Offhand.SetOnboardingSetupMethod then
                    Offhand:SetOnboardingSetupMethod("MANUAL")
                end
                if Offhand.ManualCanvas then Offhand.ManualCanvas:SetGeometryPreference("MANUAL") end
                self.statusText:SetText("|cff55ff55" .. L["ONBOARD_METHOD_MANUAL_SELECTED"] .. "|r")
            end)
            self.tertiaryActionButton:Show()
            if method == "FANCYZONES" then
                self.statusText:SetText("|cff55ff55" .. L["ONBOARD_METHOD_FANCYZONES_SELECTED"] .. "|r")
            elseif method == "COMPANION" then
                self.statusText:SetText("|cff55ff55" .. L["ONBOARD_METHOD_COMPANION_SELECTED"] .. "|r")
            elseif method == "MANUAL" then
                self.statusText:SetText("|cff55ff55" .. L["ONBOARD_METHOD_MANUAL_SELECTED"] .. "|r")
            end
        elseif self.page == 4 then
            self.actionButton:ClearAllPoints()
            self.actionButton:SetPoint("BOTTOM", self, "BOTTOM", 0, 115)
            self.actionButton:SetText(L["ONBOARD_RELOAD_UI"])
            self.actionButton:SetScript("OnClick", function()
                if InCombatLockdown and InCombatLockdown() then
                    self.statusText:SetText("|cffff5555" .. L["ONBOARD_RELOAD_COMBAT"] .. "|r")
                    return
                end
                if Offhand.SetOnboardingResumeStep then Offhand:SetOnboardingResumeStep(4) end
                if ReloadUI then ReloadUI() end
            end)
            self.actionButton:Show()
        elseif self.page == 5 and SupportsGeneratedMainhandLayout() then
            self.actionButton:SetText(L["MAINHAND_LAYOUT_CREATE"])
            self.actionButton:SetEnabled(false)
            self.statusText:SetText(L["RECOVERY_CREATE_LABEL"])
            self.actionButton:Show()
        end
    end

    guideFrame = f
    return f
end

function Onboarding:Open()
    local f = self:CreateFrame()
    if not f then return end
    if Offhand.Options and Offhand.Options.GetConfigFrame then
        local options = Offhand.Options:GetConfigFrame()
        if options and options:IsShown() then options:Hide() end
    end
    if Offhand.Wizard and Offhand.Wizard.Close then Offhand.Wizard:Close() end

    local m = Metrics()
    local panelScale = Controls.FitDialog(f, m)
    Controls.RefreshStyles()
    if Offhand.GetOnboardingSetupMethod and not Offhand:GetOnboardingSetupMethod()
        and m and m.companionTopology and Offhand.SetOnboardingSetupMethod then
        Offhand:SetOnboardingSetupMethod("COMPANION")
    end
    f:ClearAllPoints()
    if m and m.isSpanned and m.gameWidth and m.gameWidth > 0 then
        f:SetPoint("CENTER", UIParent, "BOTTOMLEFT",
            (m.gameLeft + m.gameRight) / (2 * panelScale), (m.gameBottom + m.gameTop) / (2 * panelScale))
    else
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    local resumeStep = Offhand.ConsumeOnboardingResumeStep
        and Offhand:ConsumeOnboardingResumeStep() or nil
    f:SetPage(resumeStep or 1)
    f:Show()
end

function Onboarding:ResumeAfterDownload()
    if not resumeAfterDownload or not guideFrame then return end
    local page = resumeAfterDownload
    resumeAfterDownload = nil
    guideFrame:SetPage(page)
    guideFrame:Show()
end

function Onboarding:Close()
    if guideFrame then guideFrame:Hide() end
end
