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
-- Keep persisted page IDs compatible. Former HUD-preview page 5 now aliases
-- calibration handoff 6; players see five tasks, not a disabled preview page.
local PAGE_COUNT = 6
local DISPLAY_PAGE_COUNT = 5
local resumeAfterDownload
local settingsReturnWatcher

local function SetShown(frame, shown)
    if frame.SetShown then frame:SetShown(shown)
    elseif shown then frame:Show()
    else frame:Hide() end
end

local function SetTextureColor(texture, r, g, b, a)
    if texture.SetColorTexture then texture:SetColorTexture(r, g, b, a)
    else texture:SetTexture(r, g, b, a) end
end

local function WindowedState()
    local getter = C_CVar and C_CVar.GetCVar or GetCVar
    if type(getter) ~= "function" then return "UNKNOWN" end
    local known, uncertain = false, false
    for _, entry in ipairs({{"gxWindow", "1"}, {"gxMaximize", "0"}}) do
        local ok, value = pcall(getter, entry[1])
        if ok and (value == "0" or value == "1") then
            known = true
            if value ~= entry[2] then return "OTHER" end
        elseif not ok or (value ~= nil and value ~= "") then
            uncertain = true
        end
    end
    return known and not uncertain and "WINDOWED" or "UNKNOWN"
end

local function ModeBody(mode, method, expanded)
    local key = mode == "WINDOWED" and "ONBOARD_MODE_READY_BODY"
        or (mode == "UNKNOWN" and "ONBOARD_MODE_UNKNOWN_BODY" or "ONBOARD_MODE_TASK_BODY")
    local text = L[key]
    if expanded and method then text = text .. "\n\n" .. L["ONBOARD_PATH_" .. method .. "_3"] end
    return text
end

function Onboarding:SaveProgress(page)
    if Offhand.IsSetupComplete and not Offhand:IsSetupComplete()
        and Offhand.SetOnboardingResumeStep then
        Offhand:SetOnboardingResumeStep(page)
    end
end

function Onboarding:SetWindowedMode()
    local f = guideFrame
    if not f then return false end
    local function Status(key)
        f.modeRequestInProgress = nil
        if f.page == 3 and (key == "ONBOARD_WINDOWED_UNAVAILABLE" or key == "ONBOARD_WINDOWED_CLOSE_SETTINGS") then
            f.helpExpanded = true
            f:SetPage(3)
        end
        if f.RefreshModeState then f:RefreshModeState(false) end
        f:SetStatusText(L[key])
    end
    if InCombatLockdown and InCombatLockdown() then
        Status("ONBOARD_DISPLAY_COMBAT")
        return false
    end
    -- Do not apply or discard somebody else's pending Graphics changes.
    for _, panel in ipairs({SettingsPanel or false, VideoOptionsFrame or false}) do
        if panel and panel.IsShown and panel:IsShown() then
            Status("ONBOARD_WINDOWED_CLOSE_SETTINGS")
            return false
        end
    end
    local getter = C_CVar and C_CVar.GetCVar or GetCVar
    local setter = C_CVar and C_CVar.SetCVar or SetCVar
    local info = C_CVar and C_CVar.GetCVarInfo or GetCVarInfo
    local apply = type(UpdateWindow) == "function" and UpdateWindow
        or (type(RestartGx) == "function" and RestartGx)
    if type(getter) ~= "function" or type(setter) ~= "function" then
        Status("ONBOARD_WINDOWED_UNAVAILABLE")
        return false
    end
    local changes, known = {}, 0
    -- gxWindow is present on older clients with exclusive fullscreen. Modern
    -- clients may expose only gxMaximize. Never create an absent CVar.
    for _, entry in ipairs({{"gxWindow", "1"}, {"gxMaximize", "0"}}) do
        local ok, value = pcall(getter, entry[1])
        if ok and (value == "0" or value == "1") then
            known = known + 1
            if value ~= entry[2] then
                if type(info) == "function" then
                    local readable, _, _, _, _, locked, secure, readOnly = pcall(info, entry[1])
                    if not readable or locked or secure or readOnly then
                        Status("ONBOARD_WINDOWED_UNAVAILABLE")
                        return false
                    end
                end
                changes[#changes + 1] = {name = entry[1], old = value, value = entry[2]}
            end
        elseif not ok or (value ~= nil and value ~= "") then
            Status("ONBOARD_WINDOWED_UNAVAILABLE")
            return false
        end
    end
    if known == 0 or (#changes > 0 and not apply) then
        Status("ONBOARD_WINDOWED_UNAVAILABLE")
        return false
    end
    if #changes == 0 then
        if WindowedState() ~= "WINDOWED" then
            Status("ONBOARD_WINDOWED_UNAVAILABLE")
            return false
        end
        Status("ONBOARD_WINDOWED_ALREADY")
        return true
    end
    local changed = {}
    f.modeRequestInProgress = true
    local function Restore()
        for index = #changed, 1, -1 do
            local entry = changed[index]
            pcall(setter, entry.name, entry.old)
        end
        Status("ONBOARD_WINDOWED_UNAVAILABLE")
        return false
    end
    for _, entry in ipairs(changes) do
        -- Include a rejected write in rollback in case the API changed state
        -- before returning an error. Never use securecall to bypass restrictions.
        changed[#changed + 1] = entry
        local ok, accepted = pcall(setter, entry.name, entry.value)
        local readable, value = pcall(getter, entry.name)
        if not ok or accepted == false or not readable or value ~= entry.value then
            return Restore()
        end
    end
    if Offhand.DisplayIdentify then Offhand.DisplayIdentify:Hide() end
    local ok, accepted = pcall(apply)
    if not ok or accepted == false then return Restore() end
    -- CVar readback is not proof of native window placement or a valid span.
    -- Keep the guide here and let the existing span verification run later.
    Status("ONBOARD_WINDOWED_REQUESTED")
    return true
end

function Onboarding:OpenDisplaySettings()
    local f = guideFrame
    if not f then return false end
    if InCombatLockdown and InCombatLockdown() then
        f:SetStatusText(L["ONBOARD_DISPLAY_COMBAT"])
        return false
    end
    local open, panel
    if Settings and type(Settings.OpenToCategory) == "function" and SettingsPanel then
        panel = SettingsPanel
        local categoryID
        -- Category IDs vary by client. Match Blizzard's localized category name.
        if type(panel.GetAllCategories) == "function" and GRAPHICS_LABEL then
            for _, category in ipairs(panel:GetAllCategories() or {}) do
                if type(category.GetName) == "function" and category:GetName() == GRAPHICS_LABEL
                    and type(category.GetID) == "function" then
                    categoryID = category:GetID()
                    break
                end
            end
        end
        open = function() Settings.OpenToCategory(categoryID) end
    elseif VideoOptionsFrame and type(ShowUIPanel) == "function" then
        panel = VideoOptionsFrame
        open = function() ShowUIPanel(panel) end
    end
    if not open then
        f:SetStatusText(L["ONBOARD_DISPLAY_MANUAL"])
        return false
    end
    if Offhand.DisplayIdentify then Offhand.DisplayIdentify:Hide() end
    if Offhand.SetOnboardingResumeStep then Offhand:SetOnboardingResumeStep(f.page) end
    f:Hide()
    local ok = pcall(open)
    if not ok then
        if Offhand.SetOnboardingResumeStep then Offhand:SetOnboardingResumeStep(nil) end
        self:SaveProgress(f.page)
        f:Show()
        f:SetStatusText(L["ONBOARD_DISPLAY_MANUAL"])
        return false
    end
    -- Observe visibility from an addon-owned frame. Do not hook or annotate
    -- Blizzard's settings frames, and do not change any display CVars.
    if not settingsReturnWatcher then settingsReturnWatcher = CreateFrame("Frame") end
    local elapsed, interval, seen = 0, 0, false
    settingsReturnWatcher:SetScript("OnUpdate", function(self, delta)
        elapsed, interval = elapsed + delta, interval + delta
        if interval < 0.2 then return end
        interval = 0
        local shown = panel:IsShown()
        seen = seen or shown
        if (seen and not shown) or (not seen and elapsed >= 3) then
            self:SetScript("OnUpdate", nil)
            if Offhand.SetOnboardingResumeStep then Offhand:SetOnboardingResumeStep(nil) end
            Onboarding:SaveProgress(f.page)
            f:Show()
            if seen and f.page == 3 and f.RefreshModeState then
                f:RefreshModeState(true)
            else
                f:SetStatusText(L[seen and "ONBOARD_DISPLAY_RETURN" or "ONBOARD_DISPLAY_MANUAL"])
            end
        elseif elapsed >= 600 then
            -- Stop watching an abandoned settings session. The saved guide
            -- step remains available on reload/login or /offhand guide.
            self:SetScript("OnUpdate", nil)
        end
    end)
    return true
end

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

StaticPopupDialogs["OFFHAND_CONFIRM_WINDOWED_MODE"] = {
    text = L["ONBOARD_MODE_CONFIRM_TEXT"],
    button1 = L["ONBOARD_MODE_CONFIRM_ACCEPT"],
    button2 = L["BTN_BACK"],
    OnAccept = function(_, callback) if callback then callback() end end,
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
    if WindowedState() == "OTHER" then
        return false, L["ONBOARD_STATE_MODE_OTHER"]
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
    Controls.RegisterDialog(f)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:EnableMouse(true)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    -- Deliberately not an Escape-dismissable UISpecialFrame. Keep the explicit
    -- close button without intercepting Escape or changing global bindings.

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
    f.closeButton = close

    local step = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    step:SetPoint("TOPLEFT", f, "TOPLEFT", 24, -58)
    f.stepText = step
    step:SetWidth(632)

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

    -- An illustration of the two modes, not a claim about the live window.
    local illustration = CreateFrame("Frame", nil, f)
    illustration:SetSize(612, 88)
    for index, key in ipairs({"ONBOARD_MODE_BEFORE", "ONBOARD_MODE_AFTER"}) do
        local card = CreateFrame("Frame", nil, illustration,
            not Offhand.isLegacyWrath and "BackdropTemplate" or nil)
        card:SetSize(282, 78)
        card:SetPoint("TOPLEFT", (index - 1) * 330, 0)
        Controls.StyleSurface(card, "card")
        local label = card:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        label:SetPoint("TOPLEFT", 10, -8)
        label:SetPoint("TOPRIGHT", -10, -8)
        label:SetWordWrap(true)
        label:SetText(L[key])
        local window = card:CreateTexture(nil, "ARTWORK")
        window:SetSize(index == 1 and 258 or 214, 30)
        window:SetPoint("BOTTOM", 0, 8)
        SetTextureColor(window, 0.12, 0.20, 0.24, 1)
        if index == 2 then
            local titlebar = card:CreateTexture(nil, "OVERLAY")
            titlebar:SetSize(214, 6)
            titlebar:SetPoint("BOTTOM", 0, 38)
            SetTextureColor(titlebar, 0.85, 0.68, 0.29, 1)
        end
    end
    f.modeIllustration = illustration

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
    back:SetScript("OnClick", function()
        if f.page == 2 and f.methodDetails then
            f.methodDetails = nil
            f:SetPage(2)
        else
            f:SetPage(f.page == 6 and 4 or f.page - 1)
        end
    end)
    f.backButton = back

    local help = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    help:SetSize(190, 28)
    help:SetPoint("BOTTOM", 0, 24)
    help:SetScript("OnClick", function()
        f.helpExpanded = not f.helpExpanded
        f:SetPage(f.page)
    end)
    f.helpButton = help

    local nextButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    nextButton:SetSize(150, 28)
    nextButton:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -24, 24)
    nextButton:SetScript("OnClick", function()
        if f.page == 2 then
            if f.methodDetails then return end
            f:SetStatusText("|cffff5555" .. L["ONBOARD_STATUS_METHOD_REQUIRED"] .. "|r")
            return
        end
        if f.page == 3 then
            if WindowedState() == "OTHER" then
                f:SetStatusText(L["ONBOARD_STATE_MODE_OTHER"])
                return
            end
            if Offhand._displayGeometryTransitionActive then
                f:SetStatusText(L["ONBOARD_STATUS_GEOMETRY_SETTLING"])
                return
            end
            if WindowedState() == "UNKNOWN" then
                local dialog = Offhand:ShowPopup("OFFHAND_CONFIRM_WINDOWED_MODE", nil, nil, function()
                    if f.page ~= 3 then return end
                    if WindowedState() == "OTHER" or Offhand._displayGeometryTransitionActive
                        or (InCombatLockdown and InCombatLockdown()) then
                        f:RefreshModeState(true)
                        return
                    end
                    f:SetPage(4)
                end)
                BringPopupForward(dialog)
                return
            end
        end
        if f.page == 4 then
            local ready, message, confirmManual, preview = SetupStatus()
            f:SetStatusText((ready and "|cff55ff55" or "|cffff5555") .. message .. "|r")
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
                        f:SetStatusText("|cffff5555" .. L["ONBOARD_STATUS_NOT_SPANNED"] .. "|r")
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
        local ready, message = SetupStatus()
        local m = Metrics()
        if not ready or not m or not m.isSpanned then
            f:SetPage(4)
            f:SetStatusText(message or L["ONBOARD_STATUS_NOT_SPANNED"])
            return
        end
        Onboarding:SaveProgress(6)
        if Offhand.MarkWelcomeDismissed then Offhand:MarkWelcomeDismissed() end
        f:Hide()
        if Offhand.Wizard and Offhand.Wizard.Open then Offhand.Wizard:Open() end
    end)
    f.nextButton = nextButton

    function f:LayoutPage()
        local actionHeight = 0
        for _, button in ipairs({ self.actionButton, self.secondaryActionButton, self.tertiaryActionButton }) do
            if button:IsShown() then
                actionHeight = math.max(actionHeight, 26,
                    Controls.MeasureWrappedText(button:GetFontString(), button:GetText(), 180, 14) + 8)
            end
        end
        local bodyHeight = Controls.MeasureWrappedText(self.pageBody, self.pageBody:GetText(), 612)
        local illustrated = self.modeIllustration:IsShown()
        local layout = Controls.GetGuideLayout(
            Controls.MeasureWrappedText(self.pageTitle, self.pageTitle:GetText(), 612),
            bodyHeight + (illustrated and 100 or 0),
            Controls.MeasureWrappedText(self.statusText, self.statusText:GetText(), 612),
            actionHeight)
        self:SetHeight(layout.height)
        self.pageBody:ClearAllPoints()
        self.pageBody:SetPoint("TOPLEFT", self, "TOPLEFT", 24, -layout.bodyTop)
        self.pageBody:SetPoint("TOPRIGHT", self, "TOPRIGHT", -24, -layout.bodyTop)
        self.pageBody:SetHeight(math.max(15, bodyHeight))
        self.modeIllustration:ClearAllPoints()
        self.modeIllustration:SetPoint("TOPLEFT", self, "TOPLEFT", 24, -layout.bodyTop - bodyHeight - 12)
        self.statusText:ClearAllPoints()
        self.statusText:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 24, layout.statusBottom)
        self.statusText:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -24, layout.statusBottom)
        self.statusText:SetHeight(layout.statusHeight)
        local actionCount = (self.actionButton:IsShown() and 1 or 0)
            + (self.secondaryActionButton:IsShown() and 1 or 0)
            + (self.tertiaryActionButton:IsShown() and 1 or 0)
        self.actionButton:ClearAllPoints()
        self.actionButton:SetPoint("BOTTOM", self, "BOTTOM", -101 * math.max(0, actionCount - 1), layout.actionBottom)
        for _, button in ipairs({ self.actionButton, self.secondaryActionButton, self.tertiaryActionButton }) do
            button:SetHeight(math.max(26, layout.actionHeight))
        end
        Controls.FitDialog(self, Metrics())
    end

    function f:RefreshModeState(updateStatus)
        if self.page ~= 3 or self.modeRequestInProgress then return end
        local mode = WindowedState()
        local combat = InCombatLockdown and InCombatLockdown()
        local method = Offhand.GetOnboardingSetupMethod and Offhand:GetOnboardingSetupMethod()
        self.pageTitle:SetText(L[mode == "WINDOWED" and "ONBOARD_MODE_READY_TITLE"
            or (mode == "UNKNOWN" and "ONBOARD_MODE_UNKNOWN_TITLE" or "ONBOARD_MODE_TASK_TITLE")])
        self.actionButton:SetText(L[mode == "WINDOWED" and "ONBOARD_MODE_ALREADY_BUTTON" or "ONBOARD_SET_WINDOWED"])
        self.actionButton:SetEnabled(mode ~= "WINDOWED" and not combat)
        self.nextButton:SetEnabled(mode ~= "OTHER" and not combat)
        self.pageBody:SetText(ModeBody(mode, method, self.helpExpanded))
        SetShown(self.secondaryActionButton, self.helpExpanded == true or mode == "UNKNOWN")
        if updateStatus then
            local key = combat and "ONBOARD_DISPLAY_COMBAT" or (mode == "WINDOWED" and "ONBOARD_STATE_MODE_READY"
                or (mode == "OTHER" and "ONBOARD_STATE_MODE_OTHER" or "ONBOARD_STATE_MODE_UNKNOWN"))
            self.statusText:SetText(L[key])
        end
        self:LayoutPage()
    end

    function f:SetStatusText(message)
        self.statusText:SetText(message)
        self:LayoutPage()
    end

    function f:SelectMethod(method)
        if Offhand.SetOnboardingSetupMethod then Offhand:SetOnboardingSetupMethod(method) end
        if Offhand.ManualCanvas then
            Offhand.ManualCanvas:SetGeometryPreference(method == "COMPANION" and "AUTO" or "MANUAL")
        end
        self.methodDetails = method ~= "MANUAL" and method or nil
        self:SetPage(method == "MANUAL" and 3 or 2)
    end

    function f:OpenSoftwareDownload(method)
        resumeAfterDownload = 2
        self:Hide()
        local dialog = Offhand:ShowPopup(method == "FANCYZONES" and "OFFHAND_POWERTOYS_LINK" or "OFFHAND_DOWNLOAD_LINK")
        BringPopupForward(dialog)
        if not dialog then
            resumeAfterDownload = nil
            self:Show()
        end
    end

    function f:SetPage(page)
        local nextPage = math.max(1, math.min(PAGE_COUNT, page or 1))
        if nextPage == 5 then nextPage = 6 end
        if nextPage ~= self.page then self.helpExpanded = false end
        if nextPage ~= 2 then self.methodDetails = nil end
        self.page = nextPage
        Onboarding:SaveProgress(self.page)
        self.stepText:SetText(string.format(L["ONBOARD_PROGRESS"], math.min(self.page, DISPLAY_PAGE_COUNT), DISPLAY_PAGE_COUNT))
        local titleKey = "ONBOARD_STEP_" .. self.page .. "_TITLE"
        if self.page == 6 then titleKey = "ONBOARD_CALIBRATE_TASK_TITLE" end
        if self.page == 3 then titleKey = "ONBOARD_MODE_TASK_TITLE" end
        self.pageTitle:SetText(L[titleKey])
        local bodyKey = "ONBOARD_STEP_" .. self.page .. "_BODY"
        if self.page == 1 then bodyKey = "ONBOARD_INTRO_BRIEF" end
        if self.page == 6 then
            bodyKey = SupportsGeneratedMainhandLayout() and "ONBOARD_CALIBRATE_TASK_EDITMODE"
                or "ONBOARD_CALIBRATE_TASK_CLASSIC"
        end
        local method = Offhand.GetOnboardingSetupMethod and Offhand:GetOnboardingSetupMethod()
        if self.page == 2 then bodyKey = "ONBOARD_CHOOSE_BRIEF" end
        if self.page == 3 then bodyKey = "ONBOARD_MODE_TASK_BODY" end
        if self.page == 4 and method then
            bodyKey = "ONBOARD_PLACE_" .. method
            self.pageTitle:SetText(L["ONBOARD_PLACE_TITLE"])
        end
        local bodyText = L[bodyKey]
        if self.helpExpanded and method and (self.page == 3 or self.page == 4) then
            bodyText = bodyText .. "\n\n" .. L["ONBOARD_PATH_" .. method .. "_" .. self.page]
        end
        self.pageBody:SetText(bodyText)
        SetShown(self.modeIllustration, self.page == 3)
        SetShown(self.helpButton, self.page == 3 or self.page == 4)
        self.helpButton:SetText(L[self.helpExpanded and "ONBOARD_HIDE_HELP" or "ONBOARD_SHOW_HELP"])
        self.backButton:SetEnabled(self.page > 1)
        self.nextButton:Show()
        self.nextButton:SetEnabled(true)
        self.nextButton:SetText(self.page == PAGE_COUNT
            and L["ONBOARD_START_CALIBRATION"] or L["BTN_NEXT"])
        if self.page == PAGE_COUNT and Offhand.IsWelcomeDismissed and Offhand:IsWelcomeDismissed()
            and Offhand.IsSetupComplete and not Offhand:IsSetupComplete() then
            self.nextButton:SetText(L["ONBOARD_RESUME_CALIBRATION"])
        end
        if self.page == 1 then self.nextButton:SetText(L["ONBOARD_BEGIN"])
        elseif self.page == 3 then self.nextButton:SetText(L["ONBOARD_PLACE_NEXT"])
        elseif self.page == 4 then self.nextButton:SetText(L["ONBOARD_CONFIRM_PLACEMENT"])
        end
        if self.page == 6 then
            self.pageBody:SetText(string.format(L[bodyKey], "|cffffd100" .. self.nextButton:GetText() .. "|r"))
        end
        local stateKey
        if self.page == 3 then
            local mode = WindowedState()
            stateKey = mode == "WINDOWED" and "ONBOARD_STATE_MODE_READY"
                or (mode == "OTHER" and "ONBOARD_STATE_MODE_OTHER" or "ONBOARD_STATE_MODE_UNKNOWN")
        elseif self.page == 4 then
            stateKey = method == "COMPANION" and "ONBOARD_STATE_EXACT_PENDING" or "ONBOARD_STATE_CANVAS_PENDING"
        elseif self.page >= 5 then
            stateKey = "ONBOARD_STATE_CALIBRATION_PENDING"
        end
        self.statusText:SetText(stateKey and L[stateKey] or "")
        self.actionButton:Hide()
        self.secondaryActionButton:Hide()
        self.tertiaryActionButton:Hide()
        self.actionButton:SetEnabled(true)
        self.actionButton:SetScript("OnClick", nil)
        if self.page == 3 then
            self.actionButton:SetText(L["ONBOARD_SET_WINDOWED"])
            self.actionButton:SetScript("OnClick", function()
                Onboarding:SetWindowedMode()
            end)
            self.secondaryActionButton:SetText(L["ONBOARD_OPEN_DISPLAY"])
            self.secondaryActionButton:SetScript("OnClick", function()
                Onboarding:OpenDisplaySettings()
            end)
            self.actionButton:Show()
            SetShown(self.secondaryActionButton, self.helpExpanded == true)
        elseif self.page == 2 then
            self.nextButton:Hide()
            if self.methodDetails then
                local selected = self.methodDetails
                self.pageTitle:SetText(L[selected == "FANCYZONES" and "ONBOARD_SOFTWARE_FANCYZONES_TITLE" or "ONBOARD_SOFTWARE_COMPANION_TITLE"])
                self.pageBody:SetText(L["ONBOARD_SOFTWARE_BRIEF"])
                self.statusText:SetText(L["ONBOARD_SOFTWARE_NOT_DETECTED"])
                self.actionButton:SetText(L["ONBOARD_ALREADY_INSTALLED"])
                self.actionButton:SetScript("OnClick", function() self:SetPage(3) end)
                self.secondaryActionButton:SetText(L[selected == "FANCYZONES" and "ONBOARD_GET_POWERTOYS" or "ONBOARD_GET_COMPANION"])
                self.secondaryActionButton:SetScript("OnClick", function() self:OpenSoftwareDownload(selected) end)
                self.actionButton:Show()
                self.secondaryActionButton:Show()
            else
                self.actionButton:SetText(L["ONBOARD_USE_FANCYZONES"])
                self.actionButton:SetScript("OnClick", function() self:SelectMethod("FANCYZONES") end)
                self.secondaryActionButton:SetText(L["ONBOARD_USE_COMPANION"])
                self.secondaryActionButton:SetScript("OnClick", function() self:SelectMethod("COMPANION") end)
                self.tertiaryActionButton:SetText(L["ONBOARD_USE_MANUAL"])
                self.tertiaryActionButton:SetScript("OnClick", function() self:SelectMethod("MANUAL") end)
                self.actionButton:Show()
                self.secondaryActionButton:Show()
                self.tertiaryActionButton:Show()
            end
        elseif self.page == 4 then
            self.secondaryActionButton:SetText(L["IDENTIFY_DISPLAYS"])
            self.secondaryActionButton:SetScript("OnClick", function()
                if Offhand.DisplayIdentify then Offhand.DisplayIdentify:Show() end
            end)
            self.secondaryActionButton:Show()
            self.actionButton:SetText(L["ONBOARD_RELOAD_UI"])
            self.actionButton:SetScript("OnClick", function()
                if InCombatLockdown and InCombatLockdown() then
                    self:SetStatusText("|cffff5555" .. L["ONBOARD_RELOAD_COMBAT"] .. "|r")
                    return
                end
                if Offhand.SetOnboardingResumeStep then Offhand:SetOnboardingResumeStep(4) end
                if ReloadUI then ReloadUI() end
            end)
            self.actionButton:Show()
            if method ~= "COMPANION" then
                self.secondaryActionButton:Hide()
                self.actionButton:SetText(L["IDENTIFY_DISPLAYS"])
                self.actionButton:SetScript("OnClick", function()
                    if Offhand.DisplayIdentify then Offhand.DisplayIdentify:Show() end
                end)
            end
        end
        if self.page == 3 then self:RefreshModeState(true) else self:LayoutPage() end
    end

    -- Read-only, event-driven refresh. Hidden guides do no work, and applying
    -- a request suppresses intermediate CVar events until rollback/apply ends.
    function f:CenterInMainhand()
        if not self:IsShown() then return end
        local m = Metrics()
        local scale = Controls.FitDialog(self, m)
        self:ClearAllPoints()
        if m and m.isSpanned and m.gameWidth and m.gameWidth > 0 then
            self:SetPoint("CENTER", UIParent, "BOTTOMLEFT",
                (m.gameLeft + m.gameRight) / (2 * scale), (m.gameBottom + m.gameTop) / (2 * scale))
        else
            self:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        end
    end
    for _, event in ipairs({"CVAR_UPDATE", "DISPLAY_SIZE_CHANGED", "UI_SCALE_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED"}) do
        f:RegisterEvent(event)
    end
    f:SetScript("OnEvent", function(self, event, name)
        if not self:IsShown() then return end
        if event == "DISPLAY_SIZE_CHANGED" or event == "UI_SCALE_CHANGED" then
            self:CenterInMainhand()
            -- Viewport listeners may settle after this event. Two bounded
            -- retries follow the current show session without polling.
            self.recenterGeneration = (self.recenterGeneration or 0) + 1
            local generation = self.recenterGeneration
            if C_Timer and C_Timer.After then
                for _, delay in ipairs({0.15, 0.8}) do
                    C_Timer.After(delay, function()
                        if self.recenterGeneration == generation then self:CenterInMainhand() end
                    end)
                end
            end
        end
        if self.page ~= 3 then return end
        if event == "CVAR_UPDATE" then
            name = type(name) == "string" and string.lower(name) or ""
            if name ~= "gxwindow" and name ~= "gxmaximize" then return end
        end
        self:RefreshModeState(true)
    end)
    f:SetScript("OnShow", function(self) self:RefreshModeState(true); self:CenterInMainhand() end)
    f:SetScript("OnHide", function(self) self.recenterGeneration = (self.recenterGeneration or 0) + 1 end)

    guideFrame = f
    return f
end

function Onboarding:Open()
    if Offhand.Wizard then Offhand.Wizard.settingsResumeStep = nil end
    resumeAfterDownload = nil
    if settingsReturnWatcher then settingsReturnWatcher:SetScript("OnUpdate", nil) end
    local f = self:CreateFrame()
    if not f then return end
    f.methodDetails = nil
    f.helpExpanded = false
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
    if not resumeStep and Offhand.IsWelcomeDismissed and Offhand:IsWelcomeDismissed()
        and Offhand.IsSetupComplete and not Offhand:IsSetupComplete() then
        resumeStep = 6
    end
    if resumeStep and resumeStep >= 3 and Offhand.GetOnboardingSetupMethod
        and not Offhand:GetOnboardingSetupMethod() then
        resumeStep = 2
    elseif resumeStep and resumeStep >= 3 and WindowedState() == "OTHER" then
        resumeStep = 3
    elseif resumeStep == 6 then
        local ready = SetupStatus()
        if not ready or not m or not m.isSpanned then resumeStep = 4 end
    end
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
    resumeAfterDownload = nil
    if settingsReturnWatcher then settingsReturnWatcher:SetScript("OnUpdate", nil) end
    if guideFrame then guideFrame:Hide() end
end
