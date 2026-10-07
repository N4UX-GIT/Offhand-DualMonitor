--[[
    Offhand: Multi-Monitor Setup Addon
    UI/Onboarding.lua: account-wide first-launch installation and Companion guide

    This is intentionally separate from UI/Wizard.lua. Onboarding explains and
    verifies the installation workflow; the existing wizard calibrates a window
    that has already been spanned successfully.
--]]

local _, Offhand = ...
local L = Offhand.L

local Onboarding = {}
Offhand.Onboarding = Onboarding

local guideFrame
local PAGE_COUNT = 6
local resumeAfterDownload

local function Metrics()
    return Offhand.Viewport and Offhand.Viewport.GetMetrics
        and Offhand.Viewport:GetMetrics() or nil
end

local function CompanionStatus()
    local m = Metrics()
    if not m or not m.companionTopology or not m.isSpanned then
        return false, L["ONBOARD_STATUS_NOT_SPANNED"]
    end
    if m.topologyStatus == "MISMATCH" then
        return false, L["ONBOARD_STATUS_TOPOLOGY_MISMATCH"]
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
        if f.page == 4 then
            local ready, message = CompanionStatus()
            f.statusText:SetText((ready and "|cff55ff55" or "|cffff5555") .. message .. "|r")
            if not ready then return end
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
        self.pageTitle:SetText(L["ONBOARD_STEP_" .. self.page .. "_TITLE"])
        local bodyKey = "ONBOARD_STEP_" .. self.page .. "_BODY"
        if self.page == 5 and Offhand.isForever then bodyKey = bodyKey .. "_FOREVER" end
        self.pageBody:SetText(L[bodyKey])
        self.backButton:SetEnabled(self.page > 1)
        self.nextButton:SetText(self.page == PAGE_COUNT
            and L["ONBOARD_START_CALIBRATION"] or L["BTN_NEXT"])
        self.statusText:SetText(self.page == 4 and L["ONBOARD_STATUS_CHECK_PROMPT"] or "")
        self.actionButton:Hide()
        self.actionButton:SetScript("OnClick", nil)
        if self.page == 2 then
            self.actionButton:SetText(L["POPUP_BTN_GET_APP"])
            self.actionButton:SetScript("OnClick", function()
                resumeAfterDownload = self.page
                self:Hide()
                local dialog = StaticPopup_Show and StaticPopup_Show("OFFHAND_DOWNLOAD_LINK")
                if dialog and dialog.SetFrameStrata then dialog:SetFrameStrata("TOOLTIP") end
                if not dialog then
                    resumeAfterDownload = nil
                    self:Show()
                end
            end)
            self.actionButton:Show()
        elseif self.page == 4 then
            self.actionButton:SetText(L["ONBOARD_RELOAD_UI"])
            self.actionButton:SetScript("OnClick", function()
                if Offhand.SetOnboardingResumeStep then Offhand:SetOnboardingResumeStep(4) end
                if ReloadUI then ReloadUI() end
            end)
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
    f:ClearAllPoints()
    if m and m.isSpanned and m.gameWidth and m.gameWidth > 0 then
        f:SetPoint("CENTER", UIParent, "BOTTOMLEFT",
            (m.gameLeft + m.gameRight) / 2, (m.gameBottom + m.gameTop) / 2)
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
