-- Settings actions shared with onboarding and the setup wizard.
local _, Offhand = ...
local CreateFrame = assert(Offhand.UIControls, "Offhand UI controls must load before settings actions").CreateFrame
local Actions = {}
Offhand.OptionsActions = Actions

function Actions.Install(Options, services)
    local L = Offhand.L or setmetatable({}, { __index = function(_, key) return key end })
    local SetSolidColor = services.SetSolidColor
    local function BackdropTemplate()
        return not Offhand.isLegacyWrath and "BackdropTemplate" or nil
    end
    local seamGuideLine
    local seamGuideRevision = 0

    local GamepadFocusBindingStatusText

    function Options:OpenGamepadFocusKeybindings()
        local behavior = Offhand.WorkspaceBehavior
        if not behavior or behavior:GetGamepadFocusBindingContext() == nil
            or (InCombatLockdown and InCombatLockdown()) then
            return false, "unavailable"
        end
        local frame = self.gamepadFocusCapture
        if not frame then
            frame = CreateFrame("Frame", "OffhandGamepadFocusCapture", UIParent, BackdropTemplate())
            if not frame.EnableGamePadButton then return false, "unavailable" end
            self.gamepadFocusCapture = frame
            frame:SetSize(520, 210)
            frame:SetFrameStrata("FULLSCREEN_DIALOG")
            frame:EnableMouse(true)
            frame:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 32,
                insets = { left = 11, right = 12, top = 12, bottom = 11 } })
            local text = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            text:SetPoint("TOPLEFT", 28, -28)
            text:SetPoint("TOPRIGHT", -28, -28)
            text:SetHeight(110)
            text:SetWordWrap(true)
            frame.text = text
            local accept = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
            accept:SetSize(210, 24)
            accept:SetPoint("BOTTOMLEFT", 32, 28)
            accept:SetText(ACCEPT or L["BTN_CONFIRM"])
            frame.accept = accept
            local cancel = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
            cancel:SetSize(210, 24)
            cancel:SetPoint("BOTTOMRIGHT", -32, 28)
            cancel:SetText(CANCEL or L["BTN_CANCEL"])
            cancel:SetScript("OnClick", function() frame:Hide() end)
            local function ConfirmAssignment()
                if not frame.key then return end
                local ok = behavior:AssignGamepadFocusBinding(frame.key, true)
                if ok then frame:Hide()
                else frame.text:SetText(L["GAMEPAD_FOCUS_CONTROL_UNAVAILABLE"]) end
            end
            accept:SetScript("OnClick", ConfirmAssignment)
            frame:SetScript("OnGamePadButtonDown", function(_, key)
                if IsKeyPressIgnoredForBinding and IsKeyPressIgnoredForBinding(key) then return end
                if CreateKeyChordStringUsingMetaKeyState then key = CreateKeyChordStringUsingMetaKeyState(key) end
                if frame.key then
                    if key == frame.key then ConfirmAssignment() end
                    return
                end
                local ok, reason, previous = behavior:AssignGamepadFocusBinding(key)
                if ok then frame:Hide()
                elseif reason == "conflict" then
                    frame.key = key
                    frame.text:SetText(string.format(L["GAMEPAD_FOCUS_CONTROL_CONFLICT"], key,
                        _G["BINDING_NAME_" .. previous] or previous))
                    accept:Show()
                else frame.text:SetText(L["GAMEPAD_FOCUS_CONTROL_UNAVAILABLE"]) end
            end)
            frame:SetScript("OnKeyDown", function(_, key)
                if key == "ESCAPE" then frame:Hide() end
            end)
            frame:SetScript("OnHide", function()
                frame:EnableGamePadButton(false)
                frame:EnableKeyboard(false)
                frame.key = nil
                if Options.gamepadFocusBindingStatus then
                    Options.gamepadFocusBindingStatus:SetText(GamepadFocusBindingStatusText())
                end
            end)
            frame:RegisterEvent("PLAYER_REGEN_DISABLED")
            frame:SetScript("OnEvent", function() frame:Hide() end)
        end
        frame.key = nil
        frame.text:SetText(L["GAMEPAD_FOCUS_CONTROL_CAPTURE"])
        frame.accept:Hide()
        frame:ClearAllPoints()
        local anchor = Offhand.API and Offhand.API.GetMainhandFrame and Offhand.API.GetMainhandFrame()
        frame:SetPoint("CENTER", anchor or UIParent, "CENTER")
        frame:Show()
        frame:EnableGamePadButton(true)
        frame:EnableKeyboard(true)
        return true
    end

    GamepadFocusBindingStatusText = function()
        local first, second
        if Offhand.WorkspaceBehavior then
            first, second = Offhand.WorkspaceBehavior:GetGamepadFocusBindingKeys()
        end
        if not first then return L["GAMEPAD_FOCUS_CONTROL_UNBOUND"] end

        local function DisplayKey(key)
            if type(GetBindingText) == "function" then
                local text = GetBindingText(key, "KEY_", 1)
                if type(text) == "string" and text ~= "" then return text end
            end
            return tostring(key)
        end

        local keys = DisplayKey(first)
        if second then keys = keys .. ", " .. DisplayKey(second) end
        return string.format(L["GAMEPAD_FOCUS_CONTROL_BOUND"], keys)
    end

    function Options:AutoConfigure(silent, fromWizard)
        local info = Options:DetectTopology()
        if not Offhand.db then return info end

        if Offhand.SetEnabled then Offhand:SetEnabled(true) else Offhand.db.enabled = true end
        Offhand.db.layoutPreset = info.recommendedPreset
        Offhand.db.deckWidthRatio = info.recommendedDeckRatio
        Offhand.db.primaryPosition = info.recommendedPosition or "RIGHT"
        Offhand.db.aspectRatioMode = info.recommendedAR or "16_9"
        Offhand.db.hudScale = 0.70
        if not fromWizard then
            if Offhand.MarkSetupComplete then
                Offhand:MarkSetupComplete()
            else
                Offhand.db.firstRunComplete = true
            end
        end

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
                local arKey = info.recommendedAR or "16_9"
                local localeKey = "AR_" .. arKey
                local arLabel = L[localeKey]
                if not arLabel or arLabel == localeKey then arLabel = arKey == "32_9" and "32:9" or arKey end
                Offhand:Print(L["MSG_AUTOCONFIG_DETAILS"], presetLabel, info.recommendedDeckRatio * 100, arLabel)
            end
            local configFrame = services.GetConfigFrame()
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
            SetSolidColor(tex, 1.0, 0.2, 0.2, 0.85)
            seamGuideLine.texture = tex

            local label = seamGuideLine:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            label:SetPoint("CENTER", seamGuideLine, "CENTER", 0, 0)
            label:SetText(L["SLIDER_SEAM_WIDTH"])
            label:SetTextColor(1, 1, 1, 1)
        end

        seamGuideLine:ClearAllPoints()
        local m = Offhand.Viewport and Offhand.Viewport:GetMetrics()
        if m and m.companionTopology then
            local vertical = m.workspaceRight <= m.gameLeft + 2 or m.gameRight <= m.workspaceLeft + 2
            if vertical then
                local x = m.workspaceRight <= m.gameLeft + 2 and m.gameLeft or m.workspaceLeft
                local bottom = math.max(m.workspaceBottom, m.gameBottom)
                local top = math.min(m.workspaceTop, m.gameTop)
                if top <= bottom then bottom, top = 0, m.screenHeight end
                seamGuideLine:SetSize(4, math.max(4, top - bottom))
                seamGuideLine:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x - 2, bottom)
            else
                local y = m.workspaceTop <= m.gameBottom + 2 and m.gameBottom or m.workspaceBottom
                local left = math.max(m.workspaceLeft, m.gameLeft)
                local right = math.min(m.workspaceRight, m.gameRight)
                if right <= left then left, right = 0, m.screenWidth end
                seamGuideLine:SetSize(math.max(4, right - left), 4)
                seamGuideLine:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, y - 2)
            end
        else
            local screenW = UIParent:GetWidth() or 1920
            local screenH = UIParent:GetHeight() or 1080
            local db = Offhand.db or {}
            local stacked = db.layoutPreset == "STACKED_VERTICAL"
                or db.primaryPosition == "TOP" or db.primaryPosition == "BOTTOM"
            if stacked then
                local y = screenH * deckRatio
                if db.primaryPosition == "BOTTOM" then y = screenH - y end
                seamGuideLine:SetSize(screenW, 4)
                seamGuideLine:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, y - 2)
            else
                local x = screenW * deckRatio
                if db.primaryPosition == "LEFT" then x = screenW - x end
                seamGuideLine:SetSize(4, screenH)
                seamGuideLine:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x - 2, 0)
            end
        end
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

    return GamepadFocusBindingStatusText
end

