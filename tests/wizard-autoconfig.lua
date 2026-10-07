StaticPopupDialogs = {}
--[[
    tests/wizard-autoconfig.lua
    Verifies 1-click Auto-Configuration heuristics, Options:AutoConfigure,
    Wizard dialog initialization, button bindings, and slash command routing.
--]]

local frames = {}
local registeredEvents = {}
local slashCmds = {}

SLASH_OFFHAND1 = "/offhand"
SlashCmdList = {}
UISpecialFrames = {}

function CreateFrame(kind, name, parent, template)
    local f = {
        kind = kind,
        name = name,
        parent = parent,
        template = template,
        shown = false,
        points = {},
        scripts = {},
        texts = {},
        enabled = true,
        checked = false,
        val = 0.36,
        children = {},
        regions = {},
    }
    if parent and type(parent) == "table" and parent.children then
        table.insert(parent.children, f)
    end
    function f:GetChildren() return unpack(self.children) end
    function f:GetRegions() return unpack(self.regions) end
    function f:GetObjectType() return self.kind end
    function f:GetLeft() return self.points["TOPLEFT"] and self.points["TOPLEFT"].x or 0 end
    function f:GetRight() return (self:GetLeft() or 0) + (self.width or 0) end
    function f:GetStringWidth() return string.len(self.text or "") * 6 end
    function f:GetFontString() return { GetStringWidth = function() return string.len(self.text or "") * 6 end, SetTextColor = function() end } end
    function f:SetSize(w, h) self.width, self.height = w, h end
    function f:GetSize() return self.width, self.height end
    function f:GetWidth() return self.width or 0 end
    function f:GetHeight() return self.height or 0 end
    function f:SetWidth(w) self.width = w end
    function f:SetHeight(h) self.height = h end
    function f:GetParent() return self.parent end
    function f:SetScrollChild(c) self.scrollChild = c end
    function f:SetVerticalScroll(v) self.verticalScroll = v end
    function f:SetPoint(point, rel, relPoint, x, y)
        self.points[point] = { point = point, rel = rel, relPoint = relPoint, x = x, y = y }
        self.firstPoint = self.points[point]
    end
    function f:GetPoint(index)
        if self.firstPoint then
            return self.firstPoint.point, self.firstPoint.rel, self.firstPoint.relPoint, self.firstPoint.x, self.firstPoint.y
        end
    end
    function f:ClearAllPoints() self.points = {} end
    function f:SetAutoFocus() end
    function f:SetNumeric() end
    function f:SetMaxLetters() end
    function f:HighlightText() end
    function f:ClearFocus() end
    function f:SetFontObject() end
    function f:SetTextColor() end
    function f:SetTextInsets() end
    function f:SetFrameStrata(strata) self.strata = strata end
    function f:EnableMouse() end
    function f:SetMovable() end
    function f:SetClampedToScreen() end
    function f:RegisterForDrag() end
    function f:SetScript(evt, handler) self.scripts[evt] = handler end
    function f:Show() self.shown = true; if self.scripts["OnShow"] then self.scripts["OnShow"](self) end end
    function f:Hide() self.shown = false; if self.scripts["OnHide"] then self.scripts["OnHide"](self) end end
    function f:SetShown(shown) if shown then self:Show() else self:Hide() end end
    function f:IsShown() return self.shown end
    function f:SetText(t) self.text = t end
    function f:GetFontString()
        if not f._fontString then f._fontString = { SetWidth = function() end, SetWordWrap = function() end, SetTextColor = function() end } end
        return f._fontString
    end
    function f:GetText() return self.text end
    function f:SetTextColor() end
    function f:SetEnabled(val) self.enabled = val end
    function f:IsEnabled() return self.enabled end
    function f:SetChecked(val) self.checked = val end
    function f:GetChecked() return self.checked end
    function f:LockHighlight() self.highlightLocked = true end
    function f:UnlockHighlight() self.highlightLocked = false end
    function f:SetMinMaxValues(min, max) self.minVal, self.maxVal = min, max end
    function f:SetValueStep(step) self.step = step end
    function f:SetObeyStepOnDrag() end
    function f:SetOrientation() end
    function f:SetValue(v)
        self.val = v
        if self.scripts["OnValueChanged"] then self.scripts["OnValueChanged"](self, v) end
    end
    function f:GetValue() return self.val end
    function f:SetBackdrop() end
    function f:SetBackdropColor() end
    function f:SetBackdropBorderColor() end
    function f:SetThumbTexture() end
    function f:CreateTexture()
        local t = { SetAllPoints = function() end, SetColorTexture = function() end, SetTexture = function() end, SetVertexColor = function() end, SetSize = function() end, SetPoint = function() end }
        return t
    end
    function f:CreateFontString(layer, sublayer, template)
        local fs = {
            text = "",
            points = {},
            SetText = function(s, t) s.text = t end,
            SetWidth = function() end,
            SetHeight = function() end,
            SetWordWrap = function() end,
            SetTextColor = function() end,
            GetText = function(s) return s.text end,
            SetPoint = function(s, pt, rel, relPt, x, y) s.points[pt] = { rel = rel, relPt = relPt, x = x, y = y } end,
            ClearAllPoints = function(s) s.points = {} end,
            SetJustifyH = function() end,
            SetJustifyV = function() end,
            SetTextColor = function() end,
            SetWidth = function() end,
        }
        return fs
    end
    function f:RegisterEvent(evt) registeredEvents[evt] = true end
    frames[#frames + 1] = f
    if name then _G[name] = f end
    return f
end

UIParent = CreateFrame("Frame", "UIParent")
UIParent:SetSize(4000, 2560)
function UIParent:GetEffectiveScale() return 1.0 end

InCombatLockdown = function() return false end
strtrim = function(s) return (s:gsub("^%s*(.-)%s*$", "%1")) end
strsplit = function(delim, str)
    local t = {}
    for part in string.gmatch(str, "[^" .. delim .. "]+") do table.insert(t, part) end
    return unpack(t)
end

-- Mock C_Timer
C_Timer = {
    After = function(sec, cb) cb() end,
    NewTimer = function(sec, cb) return { Cancel = function() end } end,
}

-- Mock physical resolution: 4000x2560 (portrait left + landscape right)
GetPhysicalScreenSize = function() return 4000, 2560 end
GetScreenWidth = function() return 4000 end
GetScreenHeight = function() return 2560 end
GetBuildInfo = function() return "1.15.5", "58238", "Jan 1 2025", 11505 end
hooksecurefunc = function(t, name, fn) end
C_AddOns = {
    GetAddOnMetadata = function(_, key)
        if key == "Version" then return "2.1.2" end
        if key == "X-Offhand-Release" then return "beta.18" end
        if key == "X-Offhand-Addon-Release" then return "beta.18" end
        if key == "X-Offhand-Companion-Version" then return "2.1.2" end
        if key == "X-Offhand-Companion-Release" then return "beta.18" end
        if key == "X-Offhand-Companion-Protocol" then return "1" end
        if key == "X-Offhand-Companion-Min-Version" then return "2.1.2-beta.18" end
    end,
}

-- Load Offhand modules
local addon = { modules = {} }
assert(loadfile("Core/Init.lua"))("Offhand", addon)
assert(StaticPopupDialogs["OFFHAND_COMPANION_VERSION_WARNING"].text
        ~= "POPUP_COMPANION_VERSION_TEXT"
        and StaticPopupDialogs["OFFHAND_COMPANION_VERSION_WARNING"].button1
        ~= "POPUP_BTN_GOT_IT",
    "Companion popups must use readable fallback copy before locale files load")
assert(loadfile("Core/Config.lua"))("Offhand", addon)
assert(loadfile("Core/Viewport.lua"))("Offhand", addon)
assert(loadfile("Core/SeamRedirect.lua"))("Offhand", addon)
assert(loadfile("Core/Canvas.lua"))("Offhand", addon)
assert(loadfile("Locales/enUS.lua"))("Offhand", addon)
assert(loadfile("UI/Themes.lua"))("Offhand", addon)
assert(loadfile("UI/Options.lua"))("Offhand", addon)
assert(loadfile("UI/Onboarding.lua"))("Offhand", addon)
assert(loadfile("UI/Wizard.lua"))("Offhand", addon)

-- Initialize defaults
addon.db = {
    enabled = true,
    layoutPreset = "PORTRAIT_LEFT_LANDSCAPE_RIGHT",
    deckWidthRatio = 0.36,
    primaryPosition = "RIGHT",
    aspectRatioMode = "16_9",
    hudScale = 0.70,
    theme = "CLASSIC",
    firstRunComplete = false,
}

addon:InitializePopups()
local handoffNotice = StaticPopupDialogs["OFFHAND_COMPANION_HANDOFF_NOTICE"]
local topologyWarning = StaticPopupDialogs["OFFHAND_COMPANION_TOPOLOGY_WARNING"]
local versionWarning = StaticPopupDialogs["OFFHAND_COMPANION_VERSION_WARNING"]
assert(not handoffNotice.hasEditBox and not topologyWarning.hasEditBox,
    "layout handoff notices must not imply that Companion needs downloading")
assert(handoffNotice.text:find("versions may already be correct", 1, true),
    "missing-layout guidance must reassure users with matching versions")
assert(not handoffNotice.text:find("is required", 1, true),
    "missing-layout guidance must not report a version requirement")
assert(versionWarning.hasEditBox,
    "a genuine Companion version mismatch must retain the official download address")

local readyMatch = {
    topologyStatus = "READY", companionVersionStatus = "MATCH",
}
local readyUnknown = {
    topologyStatus = "READY", companionVersionStatus = "UNKNOWN",
}
local readyMismatch = {
    topologyStatus = "READY", companionVersionStatus = "MISMATCH",
}
assert(addon:GetCompanionNoticeKind(readyMatch, false) == nil,
    "matching Companion topology and version must not show a warning")
assert(addon:GetCompanionNoticeKind(readyUnknown, false) == nil,
    "a valid topology with unknown legacy version must not show a warning")
assert(addon:GetCompanionNoticeKind(readyMismatch, false) == "VERSION",
    "only an explicit version mismatch should request a Companion update")
assert(addon:GetCompanionNoticeKind({ topologyStatus = "ABSENT" }, false) == nil,
    "non-Forever clients must retain their manual-span path")
assert(addon:GetCompanionNoticeKind({ topologyStatus = "MISMATCH" }, false) == "TOPOLOGY",
    "non-Forever stale topology must provide layout-only guidance")
addon.isForever = true
assert(addon:GetCompanionNoticeKind({ topologyStatus = "ABSENT" }, false) == "HANDOFF",
    "Forever must explain a missing Companion handoff")
assert(addon:GetCompanionNoticeKind({ topologyStatus = "MISMATCH" }, false) == nil,
    "Forever topology recovery must remain owned by its recovery prompt")
assert(addon:GetCompanionNoticeKind({ topologyStatus = "ABSENT" }, true) == nil,
    "Companion guidance must not compete with an active recovery prompt")
addon.isForever = false

local shownCompanionNotices = {}
local originalCompanionStaticPopupShow = StaticPopup_Show
StaticPopup_Show = function(key)
    shownCompanionNotices[#shownCompanionNotices + 1] = key
end
addon:ShowCompanionNotice("HANDOFF", { topologyStatus = "ABSENT" })
addon:ShowCompanionNotice("HANDOFF", { topologyStatus = "ABSENT" })
assert(#shownCompanionNotices == 1
        and shownCompanionNotices[1] == "OFFHAND_COMPANION_HANDOFF_NOTICE",
    "automatic Companion guidance must appear at most once per UI session")
addon:ShowCompanionNotice("VERSION", {
    companionVersion = "2.1.2-beta.18",
    expectedCompanionVersion = "2.1.2-beta.19",
})
assert(versionWarning.text:find("2.1.2%-beta%.18")
        and versionWarning.text:find("2.1.2%-beta%.19"),
    "version mismatch guidance must identify both actual and required builds")
StaticPopup_Show = originalCompanionStaticPopupShow

local hiddenCompanionPopups = {}
StaticPopup_Hide = function(key) hiddenCompanionPopups[key] = true end
addon.db.firstRunComplete = true
addon._companionNoticesShown = { HANDOFF = true, TOPOLOGY = true, VERSION = true }
local resolvedKind = addon:RefreshCompanionNoticeState({
    topologyStatus = "READY", companionVersionStatus = "MATCH",
    companionTopology = true, isSpanned = true,
})
assert(resolvedKind == nil
        and hiddenCompanionPopups.OFFHAND_COMPANION_HANDOFF_NOTICE
        and hiddenCompanionPopups.OFFHAND_COMPANION_TOPOLOGY_WARNING
        and hiddenCompanionPopups.OFFHAND_COMPANION_VERSION_WARNING
        and hiddenCompanionPopups.OFFHAND_WELCOME_SPAN_WARNING
        and hiddenCompanionPopups.OFFHAND_COMPANION_WARNING,
    "a verified span must dismiss current and legacy Companion/download prompts")
assert(not next(addon._companionNoticesShown),
    "resolved Companion notices must be eligible to appear again after a later regression")
StaticPopup_Hide = nil

-- Either welcome action must acknowledge the first-run guide without claiming
-- that calibration was completed. This prevents the popup recurring on login.
OffhandDB = { onboarding = {} }
StaticPopupDialogs["OFFHAND_WELCOME_SPAN_WARNING"].OnAccept()
assert(addon:IsWelcomeDismissed(), "Get Companion App must acknowledge the welcome guide")
assert(not addon:IsSetupComplete(), "Downloading the Companion must not complete calibration")
OffhandDB.onboarding = {}
addon.isForever = true
local createMainhandLayoutCount = 0
local reloadPromptCount = 0
local createMainhandLayoutResult = { true, "Offhand - Mainhand - Test", 52 }
addon.Mainhand = {
    GetLayoutStatus = function()
        return { configured = false }
    end,
    PromptReload = function()
        reloadPromptCount = reloadPromptCount + 1
        return true
    end,
}
addon.Options.CreateMainhandHUDLayout = function()
    createMainhandLayoutCount = createMainhandLayoutCount + 1
    return unpack(createMainhandLayoutResult)
end
StaticPopupDialogs["OFFHAND_WELCOME_SPAN_WARNING"].OnCancel()
assert(addon:IsWelcomeDismissed(), "Launch Wizard must acknowledge the welcome guide")
assert(OffhandSetupWizardFrame and OffhandSetupWizardFrame:IsShown(),
    "Launch Wizard must open the setup wizard")
addon.Wizard:Close()

local layoutAppliedCount = 0
function addon:ApplyFullLayout()
    layoutAppliedCount = layoutAppliedCount + 1
end

-- ============================================================================
-- 1. Test Topology Detection Heuristics
-- ============================================================================
local infoMixed = addon.Options:DetectTopology()
assert(infoMixed.isSpanned == true, "4000x2560 must be detected as spanned")
assert(infoMixed.recommendedPreset == "PORTRAIT_LEFT_LANDSCAPE_RIGHT", "Mixed setup must recommend PORTRAIT_LEFT_LANDSCAPE_RIGHT")
assert(math.abs(infoMixed.recommendedDeckRatio - 0.36) < 0.001, "Mixed setup must recommend 36% deck ratio")
assert(infoMixed.recommendedPosition == "RIGHT", "Mixed setup must recommend game monitor on RIGHT")
assert(infoMixed.recommendedAR == "16_9", "Mixed setup must recommend 16:9 AR")

-- Exact Companion geometry must classify the monitor rectangles themselves.
-- Treating every side-by-side exact plan as dual landscape corrupts the saved
-- manual fallback and misleads the wizard for portrait + landscape users.
local originalGetMetrics = addon.Viewport.GetMetrics
addon.Viewport.GetMetrics = function()
    return {
        companionTopology = true, topologyMode = "DUAL_DISPLAY",
        physicalWidth = 4000, physicalHeight = 2560,
        gamePixelWidth = 2560, gamePixelHeight = 1440,
        gamePixelLeft = 1440, gamePixelBottom = 0,
        workspacePixelWidth = 1440, workspacePixelHeight = 2560,
        workspacePixelLeft = 0, workspacePixelBottom = 0,
        gameLeft = 1440, gameRight = 4000, gameBottom = 0, gameTop = 1440,
        workspaceLeft = 0, workspaceRight = 1440, workspaceBottom = 0, workspaceTop = 2560,
    }
end
local infoExactMixed = addon.Options:DetectTopology()
assert(infoExactMixed.exactTopology and infoExactMixed.recommendedPreset == "PORTRAIT_LEFT_LANDSCAPE_RIGHT",
    "Exact portrait workspace plus landscape game must not be reported as dual landscape")
assert(infoExactMixed.recommendedPosition == "RIGHT" and math.abs(infoExactMixed.recommendedDeckRatio - 0.36) < 0.001,
    "Exact mixed topology must retain its physical side and workspace ratio")
addon.Viewport.GetMetrics = originalGetMetrics

-- A valid Companion handoff can briefly disagree with Forever's stale
-- pre-span bordered-window dimensions. Do not reinterpret that one landscape
-- window as a mixed portrait/landscape monitor pair.
GetPhysicalScreenSize = function() return 3818, 2104 end
addon.Viewport.GetMetrics = function()
    return {
        companionTopology = false,
        topologyStatus = "MISMATCH",
        isSpanned = false,
    }
end
local infoPendingExact = addon.Options:DetectTopology()
assert(not infoPendingExact.isSpanned and infoPendingExact.topologyStatus == "MISMATCH",
    "a mismatched exact topology must not fall through to aspect-ratio guesses")
assert(infoPendingExact.description == "Companion topology does not match the current WoW window",
    "the wizard must explain the exact-topology mismatch")
addon.Viewport.GetMetrics = originalGetMetrics

-- Test 3840x1080 (dual landscape side by side)
GetPhysicalScreenSize = function() return 3840, 1080 end
local infoDual = addon.Options:DetectTopology()
assert(infoDual.isSpanned == true, "3840x1080 must be detected as spanned")
assert(infoDual.recommendedPreset == "LANDSCAPE_DUAL", "Dual 1080p must recommend LANDSCAPE_DUAL")
assert(math.abs(infoDual.recommendedDeckRatio - 0.50) < 0.001, "Dual 1080p must recommend 50% seam")
assert(infoDual.recommendedAR == "16_9", "Dual 1080p must recommend 16:9 AR")

-- Test 5360x1440 (3440x1440 Ultrawide + 1920x1080 Landscape)
GetPhysicalScreenSize = function() return 5360, 1440 end
local infoUW1080 = addon.Options:DetectTopology()
assert(infoUW1080.isSpanned == true, "5360x1440 must be detected as spanned")
assert(infoUW1080.recommendedPreset == "LANDSCAPE_DUAL", "5360x1440 must recommend LANDSCAPE_DUAL")
assert(math.abs(infoUW1080.recommendedDeckRatio - 0.358) < 0.002, "5360x1440 must recommend ~35.8% seam")
assert(infoUW1080.recommendedAR == "21_9", "5360x1440 must recommend 21:9 AR")
assert(infoUW1080.recommendedPosition == "RIGHT", "5360x1440 must default primary monitor RIGHT")

-- Test 6000x1440 (3440x1440 Ultrawide + 2560x1440 Landscape)
GetPhysicalScreenSize = function() return 6000, 1440 end
local infoUW1440 = addon.Options:DetectTopology()
assert(infoUW1440.isSpanned == true, "6000x1440 must be detected as spanned")
assert(math.abs(infoUW1440.recommendedDeckRatio - 0.427) < 0.002, "6000x1440 must recommend ~42.7% seam")
assert(infoUW1440.recommendedAR == "21_9", "6000x1440 must recommend 21:9 AR")

-- Test 4480x1440 (2560x1440 Landscape + 1920x1080 Landscape)
GetPhysicalScreenSize = function() return 4480, 1440 end
local infoMixedLand = addon.Options:DetectTopology()
assert(infoMixedLand.isSpanned == true, "4480x1440 must be detected as spanned")
assert(math.abs(infoMixedLand.recommendedDeckRatio - 0.429) < 0.002, "4480x1440 must recommend ~42.9% seam")
assert(infoMixedLand.recommendedAR == "16_9", "4480x1440 must recommend 16:9 AR")

-- Test 4480x1080 (2560x1080 Ultrawide + 1920x1080 Landscape)
GetPhysicalScreenSize = function() return 4480, 1080 end
local infoUW1080p = addon.Options:DetectTopology()
assert(infoUW1080p.isSpanned == true, "4480x1080 must be detected as spanned")
assert(math.abs(infoUW1080p.recommendedDeckRatio - 0.429) < 0.002, "4480x1080 must recommend ~42.9% seam")
assert(infoUW1080p.recommendedAR == "21_9", "4480x1080 must recommend 21:9 AR")

-- Test 4880x2560 (Portrait 1440p + Ultrawide 3440x1440)
GetPhysicalScreenSize = function() return 4880, 2560 end
local infoPortUW1440 = addon.Options:DetectTopology()
assert(infoPortUW1440.isSpanned == true, "4880x2560 must be detected as spanned")
assert(math.abs(infoPortUW1440.recommendedDeckRatio - 0.295) < 0.002, "4880x2560 must recommend ~29.5% seam")
assert(infoPortUW1440.recommendedAR == "21_9", "4880x2560 must recommend 21:9 AR")

-- Test 4520x1920 (Portrait 1080p + Ultrawide 3440x1440)
GetPhysicalScreenSize = function() return 4520, 1920 end
local infoPortUW1080 = addon.Options:DetectTopology()
assert(infoPortUW1080.isSpanned == true, "4520x1920 must be detected as spanned")
assert(math.abs(infoPortUW1080.recommendedDeckRatio - 0.239) < 0.002, "4520x1920 must recommend ~23.9% seam")
assert(infoPortUW1080.recommendedAR == "21_9", "4520x1920 must recommend 21:9 AR")

-- Test 3640x1920 (Portrait 1080p + Landscape 1440p)
GetPhysicalScreenSize = function() return 3640, 1920 end
local infoPort1080_1440 = addon.Options:DetectTopology()
assert(infoPort1080_1440.isSpanned == true, "3640x1920 must be detected as spanned")
assert(math.abs(infoPort1080_1440.recommendedDeckRatio - 0.297) < 0.002, "3640x1920 must recommend ~29.7% seam")
assert(infoPort1080_1440.recommendedAR == "16_9", "3640x1920 must recommend 16:9 AR")

-- Test 3000x1920 (Portrait 1080p + Landscape 1080p)
GetPhysicalScreenSize = function() return 3000, 1920 end
local infoPort1080_1080 = addon.Options:DetectTopology()
assert(infoPort1080_1080.isSpanned == true, "3000x1920 must be detected as spanned")
assert(math.abs(infoPort1080_1080.recommendedDeckRatio - 0.360) < 0.002, "3000x1920 must recommend ~36.0% seam")
assert(infoPort1080_1080.recommendedAR == "16_9", "3000x1920 must recommend 16:9 AR")

-- Test 5120x1440 (Dual 1440p)
GetPhysicalScreenSize = function() return 5120, 1440 end
local infoDual1440 = addon.Options:DetectTopology()
assert(infoDual1440.isSpanned == true, "5120x1440 must be detected as spanned")
assert(math.abs(infoDual1440.recommendedDeckRatio - 0.50) < 0.001, "5120x1440 must recommend 50% seam")
assert(infoDual1440.recommendedAR == "16_9", "5120x1440 must recommend 16:9 AR")

-- Test 7680x2160 (Dual 4K)
GetPhysicalScreenSize = function() return 7680, 2160 end
local infoDual4K = addon.Options:DetectTopology()
assert(infoDual4K.isSpanned == true, "7680x2160 must be detected as spanned")
assert(math.abs(infoDual4K.recommendedDeckRatio - 0.50) < 0.001, "7680x2160 must recommend 50% seam")
assert(infoDual4K.recommendedAR == "16_9", "7680x2160 must recommend 16:9 AR")

-- Test 6400x2160 (4K + 1440p)
GetPhysicalScreenSize = function() return 6400, 2160 end
local info4K_1440 = addon.Options:DetectTopology()
assert(info4K_1440.isSpanned == true, "6400x2160 must be detected as spanned")
assert(math.abs(info4K_1440.recommendedDeckRatio - 0.400) < 0.002, "6400x2160 must recommend ~40.0% seam")
assert(info4K_1440.recommendedAR == "16_9", "6400x2160 must recommend 16:9 AR")

-- Reset back to 4000x2560
GetPhysicalScreenSize = function() return 4000, 2560 end

-- ============================================================================
-- 2. Test 1-Click AutoConfigure Operation
-- ============================================================================
addon.db.deckWidthRatio = 0.50
addon.db.primaryPosition = "LEFT"
addon.db.aspectRatioMode = "FILL"
addon.db.firstRunComplete = false
layoutAppliedCount = 0

local appliedInfo = addon.Options:AutoConfigure(true)
assert(appliedInfo.isSpanned == true, "AutoConfigure must detect spanned")
assert(math.abs(addon.db.deckWidthRatio - 0.36) < 0.001, "AutoConfigure must apply 36% seam")
assert(addon.db.primaryPosition == "RIGHT", "AutoConfigure must set primary position RIGHT")
assert(addon.db.aspectRatioMode == "16_9", "AutoConfigure must set 16:9 AR")
assert(addon.db.firstRunComplete == true, "AutoConfigure must mark firstRunComplete true")
assert(layoutAppliedCount >= 1, "AutoConfigure must trigger ApplyFullLayout")

-- ============================================================================
-- 3. Test Wizard Dialog Frame & Interactive Controls
-- ============================================================================
assert(addon.Wizard ~= nil, "Offhand.Wizard must exist")
addon.Wizard:Open()

local wizardFrame = _G["OffhandSetupWizardFrame"]
assert(wizardFrame ~= nil, "OffhandSetupWizardFrame must be created")
assert(wizardFrame:IsShown() == true, "Wizard frame must be shown after Wizard:Open()")
assert(wizardFrame.topoText:GetText():find("4000x2560"), "Wizard topoText must show detected resolution")
assert(wizardFrame.recomText:GetText():find("36.0%%"), "Wizard recomText must show recommended 36% seam")
assert(wizardFrame.aspectLabel ~= nil and wizardFrame.aspectButtons ~= nil,
    "Wizard step 2 must expose its aspect-ratio label and controls")
local aspectLabelPoint = wizardFrame.aspectLabel.points["TOPLEFT"]
local aspectButtonPoint = wizardFrame.aspectButtons[1].points["TOPLEFT"]
assert(aspectLabelPoint and aspectButtonPoint and aspectButtonPoint.y <= aspectLabelPoint.y - 20,
    "Wizard step 2 aspect-ratio buttons must sit below the label without overlap")

local initialWizardMetrics = addon.Viewport.GetMetrics
addon.Viewport.GetMetrics = function()
    return { companionTopology = true, isSpanned = true, topologyStatus = "READY" }
end
wizardFrame:UpdateState()
assert(wizardFrame.aspectButtons[1]:IsEnabled() == false
        and wizardFrame.exactTopologyHelp:GetText():find("locked", 1, true),
    "Wizard step 2 must explain that exact Companion geometry locks its choices")
assert(wizardFrame.seamSlider:IsEnabled() == false
        and wizardFrame.laserButton:IsEnabled() == true
        and wizardFrame.seamHelp:GetText():find("locked", 1, true),
    "Wizard step 3 must explain its width lock while leaving physical alignment available")
local seamHelpPoint = wizardFrame.seamHelp.points["TOPLEFT"]
local seamTitlePoint = wizardFrame.seamTitle.points["TOPLEFT"]
local seamHelpY = seamHelpPoint and (seamHelpPoint.y or seamHelpPoint.relPt)
local seamTitleY = seamTitlePoint and (seamTitlePoint.y or seamTitlePoint.relPt)
assert(seamHelpY and seamTitleY and seamTitleY <= seamHelpY - 32,
    "Wizard step 3 lock guidance must not overlap the Offhand Monitor width label")
addon.Viewport.GetMetrics = initialWizardMetrics
wizardFrame:UpdateState()
assert(wizardFrame.aspectButtons[1]:IsEnabled() == true
        and wizardFrame.exactTopologyHelp:GetText() == "",
    "Wizard step 2 must remove the lock explanation when manual geometry is available")
assert(wizardFrame.seamSlider:IsEnabled() == true
        and wizardFrame.seamHelp:GetText() == addon.L["WIZARD_SEAM_INSTRUCTION"],
    "Wizard step 3 must restore normal guidance when manual geometry is available")

-- Click 1-Click Auto-Configure inside wizard
addon.db.deckWidthRatio = 0.55
addon.db.firstRunComplete = false
wizardFrame.autoBtn.scripts["OnClick"]()
assert(not addon.db.firstRunComplete, "Applying a recommendation must not finish the wizard")
assert(math.abs(addon.db.deckWidthRatio - 0.36) < 0.001, "AutoConfigure button in Wizard must set 36% seam")
assert(wizardFrame.step == 2, "Applying recommendations must advance to layout review")
assert(wizardFrame.statusText:GetText() == addon.L["WIZARD_CHECK_RECOMMENDATION"], "Auto detection must ask the user to check calibration")
assert(wizardFrame.totalSteps == 5 and #wizardFrame.pages == 5,
    "Forever setup must include the generated Mainhand HUD layout step")
for step = 1, wizardFrame.totalSteps do
    wizardFrame:SetStep(step)
    for index, page in ipairs(wizardFrame.pages) do
        assert(page:IsShown() == (index == step), "Only the current setup step may be visible")
    end
    assert(addon.Options:IsSeamGuideShown() == (step == 3), "Seam guide belongs to alignment step")
end
wizardFrame:SetStep(1)
addon.db.firstRunComplete = false
wizardFrame.finishBtn.scripts.OnClick()
assert(wizardFrame.step == 2 and not addon.db.firstRunComplete, "Next must not complete setup")
wizardFrame.backBtn.scripts.OnClick()
assert(wizardFrame.step == 1, "Back must return to the previous step")

local wizardMetrics = addon.Viewport.GetMetrics
addon.isForever = true
addon.Viewport.GetMetrics = function()
    return { companionTopology=false, topologyStatus="ABSENT", isSpanned=false }
end
OffhandDB.onboarding.setupComplete = false
wizardFrame:SetStep(4)
wizardFrame.finishBtn.scripts.OnClick()
assert(wizardFrame.step == 5 and not addon:IsSetupComplete(),
    "Forever setup must require the Mainhand HUD layout action after calibration")
wizardFrame.finishBtn.scripts.OnClick()
assert(addon:IsSetupComplete() and createMainhandLayoutCount == 1 and reloadPromptCount == 1,
    "creating the Mainhand HUD layout must finish setup and offer the required reload")
OffhandDB.onboarding.setupComplete = false
addon.Viewport.GetMetrics = function()
    return {
        companionTopology=true, topologyStatus="READY", isSpanned=true,
        companionVersionStatus="MISMATCH", companionVersion="2.1.2-beta.12",
        expectedCompanionVersion="2.1.2-beta.18",
        gamePixelWidth=2560, gamePixelHeight=1440,
        workspacePixelWidth=1440, workspacePixelHeight=2560,
        workspaceTop=2560, workspaceBottom=0, workspaceLeft=0,
        gameTop=1446, gameBottom=6, gameLeft=1440,
        topologyMode="DUAL_DISPLAY",
    }
end
wizardFrame:SetStep(4)
wizardFrame.finishBtn.scripts.OnClick()
assert(wizardFrame.step == 1 and not addon:IsSetupComplete(),
    "a known Companion mismatch must block completion and return to preflight")
addon.Viewport.GetMetrics = wizardMetrics

createMainhandLayoutResult = { false, "combat" }
wizardFrame:Show()
wizardFrame:SetStep(5)
wizardFrame.finishBtn.scripts.OnClick()
assert(not addon:IsSetupComplete() and wizardFrame.step == 5 and wizardFrame:IsShown()
        and wizardFrame.mainhandLayoutStatus:GetText():find("combat", 1, true),
    "a failed Mainhand HUD layout action must keep setup open on the final step")
createMainhandLayoutResult = { true, "Offhand - Mainhand - Test", 52 }

-- Test Continuous Global UI Scale Slider in Wizard
assert(wizardFrame.scaleSlider ~= nil, "Wizard must have scaleSlider")
assert(wizardFrame.scaleValText ~= nil, "Wizard must have scaleValText")

addon.db.hudScale = 0.70
wizardFrame.scaleSlider:SetValue(0.56)
assert(math.abs(addon.db.hudScale - 0.56) < 0.001, "scaleSlider must set hudScale to 0.56")
assert(wizardFrame.scaleValText:GetText():find("56%%"), "scaleValText must reflect 56%")
assert(wizardFrame.scalePresetButtons[1].highlightLocked == true
        and wizardFrame.scalePresetButtons[3].highlightLocked == false,
    "56% must highlight Compact and clear the Standard preset highlight")

wizardFrame.scaleSlider:SetValue(0.85)
assert(math.abs(addon.db.hudScale - 0.85) < 0.001, "scaleSlider must set hudScale to 0.85")
assert(wizardFrame.scaleValText:GetText():find("85%%"), "scaleValText must reflect 85%")
for _, button in ipairs(wizardFrame.scalePresetButtons) do
    assert(button.highlightLocked == false,
        "a custom scale must clear every preset highlight")
end

-- Test Laser Toggle in Wizard
assert(addon.Options.IsSeamGuideShown ~= nil, "Options:IsSeamGuideShown must exist")
local seamGuideLine = _G["OffhandSeamGuideLine"]
assert(seamGuideLine ~= nil, "Seam guide line must exist")

-- Side-by-side monitor layouts use a vertical seam; stacked layouts use a
-- horizontal seam. This must work both with manual topology and Companion's
-- exact rectangles.
local guideMetrics = addon.Viewport.GetMetrics
addon.Viewport.GetMetrics = function() return nil end
addon.db.layoutPreset = "STACKED_VERTICAL"
addon.db.primaryPosition = "TOP"
addon.Options:ShowSeamGuide(0.36)
assert(seamGuideLine.width == UIParent:GetWidth() and seamGuideLine.height == 4,
    "manual stacked layouts must render a horizontal seam guide")
assert(math.abs(seamGuideLine.points.BOTTOMLEFT.y - (UIParent:GetHeight() * 0.36 - 2)) < 0.01,
    "manual stacked Game Top guide must follow the workspace height ratio")

addon.db.layoutPreset = "PORTRAIT_LEFT_LANDSCAPE_RIGHT"
addon.db.primaryPosition = "RIGHT"
addon.Options:ShowSeamGuide(0.36)
assert(seamGuideLine.width == 4 and seamGuideLine.height == UIParent:GetHeight(),
    "manual side-by-side layouts must render a vertical seam guide")

addon.Viewport.GetMetrics = function()
    return {
        companionTopology = true, screenWidth = 2560, screenHeight = 2520,
        workspaceLeft = 200, workspaceRight = 2120,
        workspaceBottom = 1440, workspaceTop = 2520,
        gameLeft = 0, gameRight = 2560, gameBottom = 0, gameTop = 1440,
    }
end
addon.Options:ShowSeamGuide(0.36)
assert(seamGuideLine.width > seamGuideLine.height
        and seamGuideLine.points.BOTTOMLEFT.y == 1438,
    "Companion-controlled stacked layouts must render the guide on the horizontal boundary")
addon.Viewport.GetMetrics = guideMetrics

-- Close Wizard
addon.Wizard:Close()
assert(wizardFrame:IsShown() == false, "Wizard:Close must hide wizardFrame")
assert(addon.Options:IsSeamGuideShown() == false, "Wizard:Close must hide seam guide")
addon.isForever = false

-- ============================================================================
-- 4. Test Slash Commands Routing
-- ============================================================================
local wizardOpened = false
local originalWizardOpen = addon.Wizard.Open
addon.Wizard.Open = function() wizardOpened = true end

SlashCmdList["Offhand"]("wizard")
assert(wizardOpened == true, "/Offhand wizard must call Offhand.Wizard:Open()")

local onboardingOpened = false
local originalOnboardingOpen = addon.Onboarding.Open
addon.Onboarding.Open = function() onboardingOpened = true end
SlashCmdList["Offhand"]("setup")
assert(onboardingOpened == true, "/Offhand setup must open first-time onboarding")

onboardingOpened = false
SlashCmdList["Offhand"]("guide")
assert(onboardingOpened == true, "/Offhand guide must reopen first-time onboarding")
addon.Onboarding.Open = originalOnboardingOpen

wizardOpened = false
SlashCmdList["Offhand"]("calibrate")
assert(wizardOpened == true, "/Offhand calibrate must call Offhand.Wizard:Open()")

addon.Wizard.Open = originalWizardOpen

-- The installation guide is distinct from display calibration. It does not
-- acknowledge the welcome until the verified handoff into the Wizard.
OffhandDB.onboarding = {}
addon.Viewport.GetMetrics = function()
    return {
        companionTopology = true, isSpanned = true, topologyStatus = "MATCH",
        companionVersionStatus = "MATCH", gameLeft = 1440, gameRight = 4000,
        gameBottom = 0, gameTop = 1440, gameWidth = 2560,
    }
end
addon.Onboarding:Open()
local onboardingFrame = OffhandFirstLaunchFrame
assert(onboardingFrame and onboardingFrame:IsShown() and onboardingFrame.page == 1,
    "first-time onboarding must open at its introduction")
local originalStaticPopupShow = StaticPopup_Show
local downloadDialog = { SetFrameStrata = function(self, strata) self.strata = strata end }
StaticPopup_Show = function(key)
    assert(key == "OFFHAND_DOWNLOAD_LINK", "onboarding must open the Companion download dialog")
    return downloadDialog
end
onboardingFrame:SetPage(2)
onboardingFrame.actionButton.scripts.OnClick()
assert(not onboardingFrame:IsShown() and downloadDialog.strata == "TOOLTIP",
    "download dialog must temporarily replace the onboarding guide")
StaticPopupDialogs["OFFHAND_DOWNLOAD_LINK"].OnHide()
assert(onboardingFrame:IsShown() and onboardingFrame.page == 2,
    "closing the download dialog must return to onboarding step 2")
StaticPopup_Show = originalStaticPopupShow

local reloadCount = 0
ReloadUI = function() reloadCount = reloadCount + 1 end
onboardingFrame:SetPage(4)
onboardingFrame.actionButton.scripts.OnClick()
assert(reloadCount == 1 and OffhandDB.onboarding.resumeStep == 4,
    "step 4 Reload UI must persist its resume point before reloading")
OffhandDB.onboarding.welcomeDismissed = true
assert(addon:GetOnboardingResumeStep() == 4 and addon:IsWelcomeDismissed(),
    "a pending Step 4 resume must remain discoverable for users who dismissed the older welcome")
addon.Onboarding:Open()
assert(onboardingFrame.page == 4 and OffhandDB.onboarding.resumeStep == nil,
    "onboarding must return to step 4 once after Reload UI")
onboardingFrame:SetPage(1)
local calibrationOpened = false
addon.Wizard.Open = function() calibrationOpened = true end
for _ = 1, 6 do onboardingFrame.nextButton.scripts.OnClick() end
assert(addon:IsWelcomeDismissed(),
    "onboarding must acknowledge the welcome only when handing off to calibration")
assert(calibrationOpened, "onboarding must hand off to the separate calibration wizard")
addon.Wizard.Open = originalWizardOpen
addon.Viewport.GetMetrics = originalGetMetrics

-- ============================================================================
-- 5. Test Options Dialog 1-Click and Wizard Integration Buttons
-- ============================================================================
local optPanel = addon.Options:CreateFloatingPanel()
assert(addon.fullVersion == "2.1.2-beta.18" and addon.releaseDisplay == "Beta 18",
    "addon metadata must expose the exact standardized pre-release build")
assert(addon.companionRelease == "beta.18",
    "addon metadata must retain the frozen Companion compatibility release")
assert(addon.companionVersion == "2.1.2"
        and addon.companionFullVersion == "2.1.2-beta.18"
        and addon.companionVersionDisplay == "v2.1.2 Beta 18",
    "addon metadata must expose the exact paired Companion build")
assert(optPanel.versionButton and optPanel.versionButton.scripts.OnEnter
        and optPanel.versionButton.scripts.OnLeave,
    "the settings header version must expose an exact-build hover tooltip")
assert(optPanel.header.versionText:GetText():find("Companion v2.1.2 Beta 18", 1, true),
    "the settings header must show the paired Companion build")
assert(optPanel.versionButton.offhandTooltipText:find("v2.1.2-beta.18", 1, true)
        and optPanel.versionButton.offhandTooltipText:find("v2.1.2 Beta 18", 1, true),
    "the version tooltip must distinguish addon and paired Companion builds")
addon.db.enabled = false
optPanel:Show()
assert(optPanel.enableCheck:GetChecked() == false,
    "Directly restored Options panel must sync the master checkbox from the live profile")
optPanel:Hide()
addon.db.enabled = true
optPanel:Show()
assert(optPanel.enableCheck:GetChecked() == true,
    "Restored Options panel must not retain a stale unchecked master state")
optPanel:Hide()
-- Check the real generated card rectangles, not hardcoded expected offsets.
for tabIndex = 1, 5 do
    local tab = optPanel["tab" .. tabIndex]
    local previousBottom = 0
    local cards = {}
    for _, card in ipairs(optPanel.cards) do
        if card.parent == tab then cards[#cards + 1] = card end
    end
    table.sort(cards, function(a, b) return select(5, a:GetPoint(1)) > select(5, b:GetPoint(1)) end)
    for _, card in ipairs(cards) do
        local top = -select(5, card:GetPoint(1))
        assert(top >= previousBottom, "Settings cards overlap on tab " .. tabIndex)
        previousBottom = top + card:GetHeight()
        assert(previousBottom <= tab:GetHeight(), "Scroll content must include every card")
    end
    assert(#cards > 0, "Each tab must contain cards")
end
assert(optPanel.autoWizardBtn ~= nil, "Options dashboard must have autoWizardBtn in top banner")
assert(optPanel.companionAppBtn ~= nil, "Options dashboard must expose its Companion App button")

-- An active Companion plan owns exact monitor geometry. The settings header
-- must summarize that plan without colliding with a redundant download button.
local panelGetMetrics = addon.Viewport.GetMetrics
addon.Viewport.GetMetrics = function()
    return {
        companionTopology = true, topologyMode = "DUAL_DISPLAY",
        physicalWidth = 4000, physicalHeight = 2560,
        gamePixelWidth = 2560, gamePixelHeight = 1440,
        gamePixelLeft = 1440, gamePixelBottom = 0,
        workspacePixelWidth = 1440, workspacePixelHeight = 2560,
        workspacePixelLeft = 0, workspacePixelBottom = 0,
        gameLeft = 1440, gameRight = 4000, gameBottom = 0, gameTop = 1440,
        workspaceLeft = 0, workspaceRight = 1440, workspaceBottom = 0, workspaceTop = 2560,
    }
end
addon.Options:RefreshPanel()
assert(optPanel.banner:GetText():find("Companion active: Game 2560x1440 | Workspace 1440x2560", 1, true),
    "Exact Companion status must use a concise game/workspace summary")
assert(not optPanel.companionAppBtn:IsShown(),
    "The Companion download button must be hidden while Companion is actively supplying geometry")
assert(optPanel.banner.points["TOPRIGHT"].rel == optPanel.autoWizardBtn,
    "Exact Companion status must use the space vacated by the download button")

addon.Viewport.GetMetrics = panelGetMetrics
addon.Options:RefreshPanel()
assert(optPanel.companionAppBtn:IsShown(),
    "The Companion download button must return when exact Companion geometry is absent")
assert(optPanel.banner.points["TOPRIGHT"].rel == optPanel.companionAppBtn,
    "Manual display status must end before the Companion download button")

-- Test Window Overlap Prevention:
-- When Options is shown and Auto-Setup Wizard is clicked, Options must hide and Wizard must open
addon.Options:Open()
assert(optPanel:IsShown() == true, "Options panel must be shown")

optPanel.autoWizardBtn.scripts["OnClick"]()
assert(optPanel:IsShown() == false, "Options panel must hide when Wizard opens from it")
assert(wizardFrame:IsShown() == true, "Wizard must be shown")

-- When clicking Advanced Settings in Wizard, Wizard hides and Options panel reopens
addon.Wizard:Close()
addon.Options:Open()
assert(optPanel:IsShown() == true, "Options panel re-opened")
assert(wizardFrame:IsShown() == false, "Wizard hidden when Options opens")

-- Card 1_1 1-Click button
assert(optPanel.tab1 ~= nil, "Tab 1 must exist")
local card1_1 = optPanel.tab1
local foundAutoDetectBtn = false
for _, f in ipairs(frames) do
    if f.text == "1-Click Auto-Configure" then
        foundAutoDetectBtn = true
        addon.db.deckWidthRatio = 0.50
        f.scripts["OnClick"]()
        assert(math.abs(addon.db.deckWidthRatio - 0.36) < 0.001, "Card 1_1 1-Click button must auto-configure")
    end
end
assert(foundAutoDetectBtn, "Card 1_1 must contain 1-Click Auto-Configure button")

-- Recovery must preserve reachable panels on both monitors and skip protected UI.
local recoveryMetrics = { isSpanned = true, screenWidth = 4000, screenHeight = 2560,
    gameLeft = 1440, gameRight = 4000, gameBottom = 0, gameTop = 1440, deckWidth = 1440 }
local getMetrics = addon.Viewport.GetMetrics
addon.Viewport.GetMetrics = function() return recoveryMetrics end
addon.db.primaryPosition = "RIGHT"
local function RecoveryFrame(left, top, scale, protected, reject)
    return {
        IsShown = function() return true end,
        IsProtected = function() return protected end,
        GetEffectiveScale = function() return scale end,
        GetLeft = function() return left end, GetTop = function() return top end,
        GetWidth = function() return 200 end,
        ClearAllPoints = function() end,
        SetPoint = function(self, ...) if reject then error("rejected") end; self.moved = true end,
    }
end
local deck = RecoveryFrame(100, 2200, 1)
local game = RecoveryFrame(1800, 1000, 1)
local lost = RecoveryFrame(1000, 1200, 2) -- physically in the void after scale conversion
local secure = RecoveryFrame(2000, 2400, 1, true)
local rejected = RecoveryFrame(2000, 2400, 1, false, true)
UIPanelWindows = {}
for index, frame in ipairs({deck, game, lost, secure, rejected}) do
    local name = "RecoveryTest" .. index
    _G[name] = frame
    UIPanelWindows[name] = {}
end
assert(addon:GatherOffScreenUI() == 1, "Only successfully moved, off-screen panels may count")
assert(lost.moved and not deck.moved and not game.moved and not secure.moved)
InCombatLockdown = function() return true end
assert(addon:GatherOffScreenUI() == 0, "Recovery must do nothing in combat")
InCombatLockdown = function() return false end
addon.db.primaryPosition = "LEFT"
recoveryMetrics.gameLeft, recoveryMetrics.gameRight = 0, 2560
assert(addon:IsWindowReachable(2800, 2200, 200, recoveryMetrics), "Right workspace must remain reachable")
assert(not addon:IsWindowReachable(200, 2200, 200, recoveryMetrics), "Void over left game monitor must be recoverable")
addon.Viewport.GetMetrics = getMetrics

-- A profile mutation must be deferred until the confirmation is accepted.
StaticPopupDialogs = {}
ACCEPT, CANCEL = "Accept", "Cancel"
local pending
StaticPopup_Show = function(key, text, _, callback) pending = {key=key, callback=callback} end
local mutations = 0
addon.Options:Confirm("Replace profile?", function() mutations = mutations + 1 end)
assert(mutations == 0, "Opening a confirmation must not modify a profile")
StaticPopupDialogs[pending.key].OnAccept(nil, pending.callback)
assert(mutations == 1, "Accept must run the deferred profile operation once")

-- ============================================================================
-- 6. Test Localization & Tooltips Integration
-- ============================================================================
assert(addon.L ~= nil, "Offhand.L must be defined")
assert(addon.L["WIZARD_TITLE"] == "OFFHAND AUTO-CONFIGURATION WIZARD", "Localization must have WIZARD_TITLE")
assert(addon.L["SLIDER_HUD_SCALE_TIP_TITLE"] ~= nil, "Localization must have SLIDER_HUD_SCALE_TIP_TITLE")
assert(addon.L["CHECK_CANVAS_ENABLED_TIP_DESC"] ~= nil, "Localization must have CHECK_CANVAS_ENABLED_TIP_DESC")
assert(addon.SetTooltip ~= nil, "Offhand:SetTooltip must be defined")

print("PASS: 1-click auto-configuration, topology heuristics, wizard frame, UI scale slider, overlap prevention, and tooltips verified!")

local oldAfter = C_Timer.After
local previewTimeout
C_Timer.After = function(delay, callback)
    if delay == 4 then previewTimeout = callback end
end
addon.Options:AutoConfigure(false)
assert(previewTimeout, "Auto setup must schedule its temporary guide preview")
addon.Options:ShowSeamGuide(addon.db.deckWidthRatio)
previewTimeout()
assert(addon.Options:IsSeamGuideShown(), "Old auto-setup timeout must not hide a manually enabled guide")
addon.Options:HideSeamGuide()
C_Timer.After = oldAfter

