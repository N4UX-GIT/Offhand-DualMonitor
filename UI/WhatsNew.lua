-- Account-wide release notes and a copyable link to the verified Store release.
local _, Offhand = ...
local L, Controls = Offhand.L, Offhand.UIControls
local WhatsNew = {}
Offhand.WhatsNew = WhatsNew

-- The paired Companion and the version published in Microsoft Store can differ.
-- See docs/ADDON-RELEASE-NOTICES.md before updating either value.
local storeVersion = "2.1.8"
local releases = {
    ["2.1.5-beta.34"] = { highlights = "WHATS_NEW_BETA34", companion = "2.1.9-beta.1" },
    ["2.1.5-beta.33"] = { highlights = "WHATS_NEW_BETA33" },
    ["2.1.5-beta.32"] = { highlights = "WHATS_NEW_BETA32", companion = "2.1.7" },
}
local releasesUrl = "https://github.com/N4UX-GIT/Offhand-DualMonitor/releases/tag/v"
local dialog

local function Compare(actual, expected)
    return Offhand.Viewport:CompareReleaseVersions(actual, expected)
end

function WhatsNew:HasUnseenRelease()
    local current = Offhand.fullVersion
    if type(OffhandDB) ~= "table" or type(current) ~= "string" or current == "" then return false end
    local seen = OffhandDB.lastSeenRelease
    if seen == current then return false end
    local order = Compare(current, seen)
    return order == nil or order > 0
end

local function ReleaseMessage()
    local release = releases[Offhand.fullVersion]
    local lines = { L[release and release.highlights or "WHATS_NEW_FALLBACK"] }
    if release then
        lines[#lines + 1] = release.companion
            and L["WHATS_NEW_COMPANION_PAIRED"]:format(release.companion)
            or L["WHATS_NEW_COMPANION_UNCHANGED"]
    end

    -- The bridge identifies the writer of the last span, even when its old
    -- geometry no longer matches. It is not a probe of the installed desktop app.
    local bridge = _G.OffhandCompanionTopology
    local lastUsed = type(bridge) == "table" and bridge.companionVersion
    local order = Compare(lastUsed, storeVersion)
    if order ~= nil then
        lines[#lines + 1] = L["WHATS_NEW_COMPANION_LAST_USED"]:format(lastUsed)
    end
    lines[#lines + 1] = L["WHATS_NEW_COMPANION_STORE"]:format(storeVersion)
    if order == nil or order < 0 then
        lines[#lines + 1] = L["WHATS_NEW_COMPANION_CHECK"]
    end
    return table.concat(lines, "\n\n"), order == nil or order < 0
end

local function Fit(f, metrics)
    f:SetHeight(110 + f.body:GetHeight() + (f.link:IsShown() and f.copyHint:GetHeight() + 38 or 0))
    local scale = Controls.FitDialog(f, metrics)
    f:ClearAllPoints()
    if metrics and metrics.isSpanned and metrics.gameLeft and metrics.gameRight
        and metrics.gameBottom and metrics.gameTop then
        f:SetPoint("CENTER", UIParent, "BOTTOMLEFT",
            (metrics.gameLeft + metrics.gameRight) / (2 * scale),
            (metrics.gameBottom + metrics.gameTop) / (2 * scale))
    else
        f:SetPoint("CENTER", UIParent, "CENTER")
    end
end

local function Metrics()
    return Offhand.Viewport:GetMetrics()
end

local function ShowLink(f, url)
    f.link:SetText(url)
    f.link:Show()
    f.copyHint:Show()
    Fit(f, Metrics())
    if not Offhand:IsGamepadUIEnabled() then
        f.link:SetFocus()
        f.link:HighlightText()
    end
end

function WhatsNew:Dismiss()
    if not dialog or not dialog:IsShown() then return end
    if self:HasUnseenRelease() then OffhandDB.lastSeenRelease = Offhand.fullVersion end
    local afterDismiss = self.afterDismiss
    self:Interrupt()
    if afterDismiss then C_Timer.After(0, afterDismiss) end
end

function WhatsNew:IsShown()
    return dialog and dialog:IsShown()
end

function WhatsNew:Interrupt()
    self.afterDismiss = nil
    if self:IsShown() then dialog:Hide() end
end

local function CreateDialog()
    local f = CreateFrame("Frame", "OffhandWhatsNewFrame", UIParent,
        not Offhand.isLegacyWrath and "BackdropTemplate" or nil)
    f:SetSize(560, 300)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f.uiSetupSurface = true
    Controls.StyleSurface(f, "window")
    Controls.RegisterDialog(f)

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -6, -6)
    close:SetScript("OnClick", function() WhatsNew:Dismiss() end)

    local title = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 24, -20)
    title:SetPoint("TOPRIGHT", -42, -20)
    title:SetJustifyH("LEFT")
    f.title = title

    local body = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    body:SetPoint("TOPLEFT", 24, -52)
    body:SetJustifyH("LEFT")
    body:SetJustifyV("TOP")
    if body.SetWordWrap then body:SetWordWrap(true) end
    if body.SetNonSpaceWrap then body:SetNonSpaceWrap(true) end
    f.body = body

    local function Button(label, point, x, action)
        local button = Controls.CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        button:SetSize(160, 30)
        button:SetPoint(point, f, point, x, 14)
        button:SetText(label)
        button:SetScript("OnClick", action)
        return button
    end
    f.storeButton = Button(L["WHATS_NEW_STORE_LINK"], "BOTTOMLEFT", 24, function()
        ShowLink(f, Offhand.companionStoreUrl)
    end)
    Button(L["WHATS_NEW_NOTES_LINK"], "BOTTOM", 0, function()
        ShowLink(f, releasesUrl .. Offhand.fullVersion)
    end)
    Button(L["BTN_CLOSE"], "BOTTOMRIGHT", -24, function() WhatsNew:Dismiss() end)

    local link = Controls.CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    link:SetSize(512, 24)
    link:SetPoint("BOTTOM", 0, 52)
    link:SetScript("OnEscapePressed", link.ClearFocus)
    link:SetScript("OnEnterPressed", link.ClearFocus)
    f.link = link
    local hint = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    hint:SetPoint("BOTTOMLEFT", link, "TOPLEFT", 0, 4)
    hint:SetJustifyH("LEFT")
    hint:SetText(L["WHATS_NEW_COPY_HINT"])
    Controls.FitCompactParagraph(hint, L["WHATS_NEW_COPY_HINT"], 512)
    f.copyHint = hint
    f:SetScript("OnHide", function() link:ClearFocus() end)
    f:Hide()
    return f
end

function WhatsNew:Open(metrics)
    if Offhand:IsBlizzardInputReserved() then return false end
    if dialog and dialog:IsShown() then return true end
    dialog = dialog or CreateDialog()
    local message, prompt = ReleaseMessage()
    dialog.title:SetText(L["WHATS_NEW_TITLE"]:format(Offhand.fullVersion))
    dialog.body:SetText(message)
    Controls.FitCompactParagraph(dialog.body, message, 512)
    Controls.SetRecommendedButton(dialog.storeButton, prompt)
    dialog.link:Hide()
    dialog.copyHint:Hide()
    Fit(dialog, metrics or Metrics())
    dialog:Show()
    return true
end

function WhatsNew:MaybeShow(metrics, afterDismiss)
    if not self:HasUnseenRelease() then return false end
    if InCombatLockdown() then
        if not self.queued then
            self.queued = true
            Offhand:RunOrQueueCombat(function()
                self.queued = nil
                afterDismiss()
            end)
        end
        return true
    end
    if not self:Open(metrics) then return false end
    self.afterDismiss = afterDismiss
    return true
end
