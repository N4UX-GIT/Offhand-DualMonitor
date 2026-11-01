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
        hooks = {},
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
    function f:GetVerticalScroll() return self.verticalScroll or 0 end
    function f:EnableMouseWheel(enabled) self.mouseWheel = enabled end
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
    function f:HookScript(event, callback)
        self.hooks[event] = self.hooks[event] or {}
        table.insert(self.hooks[event], callback)
    end
    function f:Show()
        self.shown = true
        if self.scripts["OnShow"] then self.scripts["OnShow"](self) end
        for _, callback in ipairs(self.hooks.OnShow or {}) do callback(self) end
    end
    function f:Hide()
        self.shown = false
        if self.scripts["OnHide"] then self.scripts["OnHide"](self) end
        for _, callback in ipairs(self.hooks.OnHide or {}) do callback(self) end
    end
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
            SetHeight = function(s, height) s.height = height end,
            GetHeight = function(s) return s.height or 0 end,
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
assert(loadfile("Core/ClientRuntime.lua"))("Offhand", addon)
local versionDiagnostics = addon:GetVersionDiagnostics({
    companionVersion = "2.1.2-beta.18",
    companionVersionStatus = "MATCH",
})
assert(versionDiagnostics.clientVersion == "1.15.5"
        and versionDiagnostics.clientBuild == "58238"
        and versionDiagnostics.interfaceVersion == "11505"
        and versionDiagnostics.clientProject == "unknown"
        and versionDiagnostics.addonVersion == "2.1.2-beta.18"
        and versionDiagnostics.companionWriter == "2.1.2-beta.18"
        and versionDiagnostics.companionPaired == "2.1.2-beta.18"
        and versionDiagnostics.companionMinimum == "2.1.2-beta.18"
        and versionDiagnostics.companionProtocol == 1
        and versionDiagnostics.companionStatus == "MATCH",
    "diagnostics must identify the client, addon, and Companion builds")
addon.db = {
    enabled = true,
    firstRunComplete = true,
    layoutPreset = "PORTRAIT_LEFT_LANDSCAPE_RIGHT",
    primaryPosition = "RIGHT",
}
local operatingDiagnostics = addon:GetOperatingDiagnostics({
    isSpanned = true,
    companionTopology = true,
    topologyStatus = "READY",
    preset = "PORTRAIT_LEFT_LANDSCAPE_RIGHT",
    gamePixelLeft = 1440,
    gamePixelBottom = 6,
    gamePixelWidth = 2560,
    gamePixelHeight = 1440,
    workspacePixelLeft = 0,
    workspacePixelBottom = 0,
    workspacePixelWidth = 1440,
    workspacePixelHeight = 2560,
})
assert(operatingDiagnostics.enabled and operatingDiagnostics.spanned
        and operatingDiagnostics.topologySource == "Companion"
        and operatingDiagnostics.layoutPreset == "PORTRAIT_LEFT_LANDSCAPE_RIGHT"
        and operatingDiagnostics.mainhandPosition == "RIGHT"
        and not operatingDiagnostics.inCombat and operatingDiagnostics.setupComplete
        and operatingDiagnostics.mainhandLeft == 1440
        and operatingDiagnostics.mainhandBottom == 6
        and operatingDiagnostics.mainhandWidth == 2560
        and operatingDiagnostics.mainhandHeight == 1440
        and operatingDiagnostics.workspaceLeft == 0
        and operatingDiagnostics.workspaceBottom == 0
        and operatingDiagnostics.workspaceWidth == 1440
        and operatingDiagnostics.workspaceHeight == 2560,
    "diagnostics must expose operating state and exact display rectangles")
assert(StaticPopupDialogs["OFFHAND_COMPANION_VERSION_WARNING"].text
        ~= "POPUP_COMPANION_VERSION_TEXT"
        and StaticPopupDialogs["OFFHAND_COMPANION_VERSION_WARNING"].button1
        ~= "POPUP_BTN_GOT_IT",
    "Companion popups must use readable fallback copy before locale files load")
assert(loadfile("Core/Config.lua"))("Offhand", addon)
assert(loadfile("Core/ManualCanvas.lua"))("Offhand", addon)
assert(loadfile("Core/Viewport.lua"))("Offhand", addon)
assert(loadfile("Core/HUDCompatibility.lua"))("Offhand", addon)
assert(loadfile("Core/HUDTransientPolicy.lua"))("Offhand", addon)
assert(loadfile("Core/HUDRecovery.lua"))("Offhand", addon)
assert(loadfile("Core/HUDTransientFrames.lua"))("Offhand", addon)
assert(loadfile("Core/SeamRedirect.lua"))("Offhand", addon)
assert(loadfile("Core/CanvasCompatibility.lua"))("Offhand", addon)
assert(loadfile("Core/CanvasFrameState.lua"))("Offhand", addon)
assert(loadfile("Core/CanvasPanelRegistry.lua"))("Offhand", addon)
assert(loadfile("Core/CanvasPersistence.lua"))("Offhand", addon)
assert(loadfile("Core/CanvasBackpackState.lua"))("Offhand", addon)
assert(loadfile("Core/CanvasForeverBags.lua"))("Offhand", addon)
assert(loadfile("Core/CanvasForeverMap.lua"))("Offhand", addon)
assert(loadfile("Core/CanvasChat.lua"))("Offhand", addon)
assert(loadfile("Core/CanvasProfessions.lua"))("Offhand", addon)
assert(loadfile("Core/CanvasPanelMotion.lua"))("Offhand", addon)
assert(loadfile("Core/CanvasMapPresentation.lua"))("Offhand", addon)
assert(loadfile("Core/CanvasPanelLifecycle.lua"))("Offhand", addon)
assert(loadfile("Core/CanvasPanelPlacement.lua"))("Offhand", addon)
assert(loadfile("Core/Canvas.lua"))("Offhand", addon)
assert(loadfile("Locales/enUS.lua"))("Offhand", addon)
assert(loadfile("UI/Themes.lua"))("Offhand", addon)
assert(loadfile("UI/Controls.lua"))("Offhand", addon)
assert(loadfile("Core/TopologyDetection.lua"))("Offhand", addon)
assert(loadfile("UI/OptionsActions.lua"))("Offhand", addon)
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
assert(addon:GetCompanionNoticeKind({ topologyStatus = "MISMATCH", manualCanvas = true }, false) == nil,
    "a remembered independent canvas must supersede stale optional topology")
assert(addon:GetCompanionNoticeKind({ topologyStatus = "ABSENT",
        manualCanvasState = "EXACT_REQUIRED" }, false) == "HANDOFF",
    "explicit exact mode must still explain a missing Companion handoff")
assert(addon:GetCompanionNoticeKind({ topologyStatus = "MISMATCH" }, false) == "TOPOLOGY",
    "non-Forever stale topology must provide layout-only guidance")
addon.isForever = true
assert(addon:GetCompanionNoticeKind({ topologyStatus = "ABSENT" }, false) == nil,
    "Forever must allow an independent remembered-window path without a Companion handoff")
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

local originalManualDiagnostics = addon.ManualCanvas.GetDiagnostics
addon.ManualCanvas.GetDiagnostics = function() return { count = 0 } end
local independentPrompt
StaticPopup_Show = function(key) independentPrompt = key end
addon._independentWindowPromptDismissed = nil
local independentKind = addon:RefreshCompanionNoticeState({
    topologyStatus = "ABSENT", companionTopology = false, isSpanned = false,
    manualCanvasState = "MISMATCH", physicalWidth = 3998, physicalHeight = 2480,
})
assert(independentKind == "INDEPENDENT"
        and independentPrompt == "OFFHAND_CONFIRM_EXISTING_WINDOW",
    "configured upgrades without a remembered canvas must offer explicit recovery")
addon.ManualCanvas.GetDiagnostics = originalManualDiagnostics
StaticPopup_Show = originalCompanionStaticPopupShow

-- Either welcome action must acknowledge the first-run guide without claiming
-- that calibration was completed. This prevents the popup recurring on login.
OffhandDB = { onboarding = {} }
StaticPopupDialogs["OFFHAND_WELCOME_SPAN_WARNING"].OnAccept()
assert(addon:IsWelcomeDismissed(), "Window Setup must acknowledge the welcome guide")
assert(not addon:IsSetupComplete(), "Opening window setup must not complete calibration")
OffhandDB.onboarding = {}
addon.isForever = true
local createMainhandLayoutCount = 0
local reloadPromptCount = 0
local createMainhandLayoutResult = { true, "Offhand - Mainhand - Test", 52 }
local mainhandLayoutDeferred = false
addon.Mainhand = {
    GetLayoutStatus = function()
        return { configured = false, deferred = mainhandLayoutDeferred }
    end,
    SetEditModeLayoutDeferred = function(_, deferred)
        mainhandLayoutDeferred = deferred == true
        return true
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
assert(addon:IsWelcomeDismissed(), "Not Now must acknowledge the welcome guide")

local layoutAppliedCount = 0
function addon:ApplyFullLayout()
    layoutAppliedCount = layoutAppliedCount + 1
end

local originalPreviewMetrics = addon.Viewport.GetManualPreviewMetrics
local originalRememberMetrics = addon.ManualCanvas.RememberFromMetrics
addon.Viewport.GetManualPreviewMetrics = function()
    return { physicalWidth = 3998, physicalHeight = 2480 }
end
addon.ManualCanvas.RememberFromMetrics = function(_, metrics)
    assert(metrics.physicalWidth == 3998 and metrics.physicalHeight == 2480,
        "upgrade recovery must remember the current preview canvas")
    return true, "manual-1", {
        name = "3998x2480 SIDE_BY_SIDE", referenceWidth = 3998, referenceHeight = 2480,
    }
end
StaticPopupDialogs["OFFHAND_CONFIRM_EXISTING_WINDOW"].OnAccept()
assert(layoutAppliedCount == 1,
    "confirming the existing window must immediately reapply the saved layout")
addon.Viewport.GetManualPreviewMetrics = originalPreviewMetrics
addon.ManualCanvas.RememberFromMetrics = originalRememberMetrics

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

local originalPhysicalScreenSize = GetPhysicalScreenSize
GetPhysicalScreenSize = function() return 2560, 1440 end
local stalePhysicalMixed = addon.Options:DetectTopology()
assert(stalePhysicalMixed.physWidth == 4000 and stalePhysicalMixed.physHeight == 2560
        and math.abs(stalePhysicalMixed.aspectRatio - 4000 / 2560) < 0.001
        and math.abs(stalePhysicalMixed.recommendedDeckRatio - 0.36) < 0.001,
    "accepted mixed span must use Companion dimensions for wizard size and workspace percentage")
addon.Viewport.GetMetrics = function()
    return {
        companionTopology = true, physicalWidth = 2560, physicalHeight = 2520,
        gamePixelWidth = 2560, gamePixelHeight = 1440,
        workspacePixelWidth = 1920, workspacePixelHeight = 1080,
        gameLeft = 0, gameRight = 2560, gameBottom = 0, gameTop = 1440,
        workspaceLeft = 200, workspaceRight = 2120, workspaceBottom = 1440, workspaceTop = 2520,
    }
end
local stalePhysicalStacked = addon.Options:DetectTopology()
assert(stalePhysicalStacked.recommendedPreset == "STACKED_VERTICAL"
        and stalePhysicalStacked.recommendedPosition == "BOTTOM"
        and stalePhysicalStacked.physHeight == 2520
        and math.abs(stalePhysicalStacked.recommendedDeckRatio - 1080 / 2520) < 0.001,
    "accepted stacked span must divide workspace height by full Companion height")
GetPhysicalScreenSize = originalPhysicalScreenSize
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
assert(addon.Options:GetMainhandLayoutFailureText("span")
        == addon.L["MAINHAND_LAYOUT_SPAN_MISMATCH"],
    "a stale Companion layout must produce actionable manual and Companion recovery guidance")
addon.Viewport.GetMetrics = originalGetMetrics
assert(addon.Options:GetMainhandLayoutFailureText("span")
        == addon.L["MAINHAND_LAYOUT_SPAN_UNCONFIRMED"],
    "an unconfirmed span without stale topology must produce actionable diagnostics guidance")

-- Test 3840x1080 (dual landscape side by side)
GetPhysicalScreenSize = function() return 3840, 1080 end
local infoDual = addon.Options:DetectTopology()
assert(infoDual.isSpanned == true, "3840x1080 must be detected as spanned")
assert(infoDual.recommendedPreset == "LANDSCAPE_DUAL", "Dual 1080p must recommend LANDSCAPE_DUAL")
assert(math.abs(infoDual.recommendedDeckRatio - 0.50) < 0.001, "Dual 1080p must recommend 50% seam")
assert(infoDual.recommendedAR == "16_9", "Dual 1080p must recommend 16:9 AR")

-- A manually confirmed single 21:9 display preserves a 16:9 Mainhand and
-- assigns only the remaining width to the Offhand workspace.
GetPhysicalScreenSize = function() return 3440, 1440 end
local infoSingleUW = addon.Options:DetectTopology()
assert(infoSingleUW.isSpanned == true, "3440x1440 must support an intentional single-display split")
assert(infoSingleUW.recommendedPreset == "LANDSCAPE_DUAL",
    "single-display ultrawide must use side-by-side landscape regions")
assert(math.abs(infoSingleUW.recommendedDeckRatio - (880 / 3440)) < 0.002,
    "3440x1440 must reserve 880 pixels for the workspace beside a 2560x1440 Mainhand")
assert(infoSingleUW.recommendedPosition == "RIGHT" and infoSingleUW.recommendedAR == "16_9",
    "single-display ultrawide must default to a right-side 16:9 Mainhand")

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
wizardFrame:SetStep(5)
assert(wizardFrame.welcomeText:GetText() == addon.L["STEP_5_HELP"]
        and wizardFrame.mainhandLayoutHelp:GetText():find(addon.L["WIZARD_STEP_5_BODY"], 1, true) == 1
        and wizardFrame.welcomeText:GetText() ~= wizardFrame.mainhandLayoutHelp:GetText()
        and wizardFrame.mainhandLayoutHelp:GetText():find("Recovery & Preview", 1, true)
        and wizardFrame.mainhandLayoutHelp:GetText():find("Readiness:", 1, true),
    "wizard step 5 must separate its purpose from its detailed action and recovery guidance")
assert(wizardFrame.skipLayoutBtn:IsShown() and not wizardFrame.advBtn:IsShown(),
    "the final HUD step must replace All Settings with an explicit finish-without-layout path")
do
    local function CheckWizardBounds()
        local card = wizardFrame.pages[wizardFrame.step]
        local top = -select(5, card:GetPoint(1))
        local validationTop = wizardFrame:GetHeight() - wizardFrame.validationStatus.points.BOTTOMLEFT.y
            - wizardFrame.validationStatus:GetHeight()
        assert(top + card:GetHeight() + 12 <= validationTop,
            "wizard card must clear the validation region on step " .. wizardFrame.step)
        local progressTop = -wizardFrame.progressText.points.TOPLEFT.y
        assert(progressTop >= 54 + addon.UIControls.MeasureWrappedText(
                wizardFrame.welcomeText, wizardFrame.welcomeText:GetText(), 632) + 12,
            "wizard progress must follow its wrapped introduction")
        assert(top >= progressTop + addon.UIControls.MeasureWrappedText(
                wizardFrame.progressText, wizardFrame.progressText:GetText(), 632) + 12,
            "wizard card must follow its progress text")
        assert(wizardFrame.validationStatus.points.BOTTOMLEFT.y
                >= 14 + wizardFrame.finishBtn:GetHeight() + 12,
            "wizard validation must stay above the complete footer")
    end
    for step = 1, wizardFrame.totalSteps do wizardFrame:SetStep(step); CheckWizardBounds() end
    local originalHelp = wizardFrame.mainhandLayoutHelp:GetText()
    local originalStatus = wizardFrame.mainhandLayoutStatus:GetText()
    local originalFinish = wizardFrame.finishBtn:GetText()
    local originalHeight = wizardFrame:GetHeight()
    wizardFrame.mainhandLayoutHelp:SetText(string.rep("Expanded readiness guidance ", 120))
    wizardFrame.mainhandLayoutStatus:SetText(string.rep("Long layout status ", 20))
    wizardFrame.finishBtn:SetText(string.rep("Translated finish action ", 5))
    wizardFrame:LayoutStep()
    CheckWizardBounds()
    assert(wizardFrame:GetHeight() > originalHeight,
        "the final readiness card must expand instead of clipping its detailed guidance")
    local bodyBottom = -wizardFrame.mainhandLayoutHelp.points.TOPLEFT.y
        + wizardFrame.mainhandLayoutHelp:GetHeight()
    assert(bodyBottom + 14 <= -wizardFrame.mainhandLayoutStatus.points.TOPLEFT.y,
        "final layout status must stay below the full guidance text")
    wizardFrame.mainhandLayoutHelp:SetText(originalHelp)
    wizardFrame.mainhandLayoutStatus:SetText(originalStatus)
    wizardFrame.finishBtn:SetText(originalFinish)
    wizardFrame:LayoutStep()
    assert(wizardFrame:GetHeight() == originalHeight, "wizard relayout must not accumulate height")
end
wizardFrame:SetStep(1)
assert(not wizardFrame.skipLayoutBtn:IsShown() and wizardFrame.advBtn:IsShown(),
    "the HUD skip action must remain isolated to the final wizard step")
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
assert(wizardFrame.step == 4 and not addon:IsSetupComplete()
        and wizardFrame.validationStatus:GetText():find(
            "2.1.2-beta.12", 1, true),
    "a known Companion mismatch must block completion and explain the problem on the current step")
addon.Viewport.GetMetrics = function()
    return {
        companionTopology=false, topologyStatus="MISMATCH", isSpanned=false,
    }
end
wizardFrame:SetStep(4)
wizardFrame.finishBtn.scripts.OnClick()
assert(wizardFrame.step == 4 and not addon:IsSetupComplete()
        and wizardFrame.validationStatus:GetText():find(
            addon.L["MAINHAND_LAYOUT_SPAN_MISMATCH"], 1, true)
        and wizardFrame.statusText:GetText():find(
            addon.L["MAINHAND_LAYOUT_SPAN_MISMATCH"], 1, true),
    "a stale topology must block wizard completion with actionable guidance on the current step")

-- FancyZones targets the Windows work area and sizes the decorated outer
-- window, while WoW reports the smaller render client area. A confirmed
-- manual canvas must therefore remain valid
-- even when a stale Companion bridge still describes the same display union
-- as a larger borderless 4000x2560 window.
addon.Viewport.GetMetrics = function()
    return {
        companionTopology=false, topologyStatus="MISMATCH", isSpanned=true,
        manualCanvas=true, manualCanvasState="MATCH", manualCanvasSource="FANCYZONES",
        physicalWidth=3998, physicalHeight=2480,
        screenWidth=1200, screenHeight=744,
        gamePixelLeft=1439, gamePixelBottom=0,
        gamePixelWidth=2559, gamePixelHeight=1440,
        workspacePixelLeft=0, workspacePixelBottom=0,
        workspacePixelWidth=1439, workspacePixelHeight=2480,
    }
end
wizardFrame:SetStep(4)
wizardFrame.finishBtn.scripts.OnClick()
assert(wizardFrame.step == 5 and not addon:IsSetupComplete()
        and wizardFrame.validationStatus:GetText() == "",
    "a remembered FancyZones canvas must override stale Companion topology during wizard validation")
addon.Viewport.GetMetrics = wizardMetrics

createMainhandLayoutResult = { false, "combat" }
wizardFrame:Show()
wizardFrame:SetStep(5)
wizardFrame.finishBtn.scripts.OnClick()
assert(not addon:IsSetupComplete() and wizardFrame.step == 5 and wizardFrame:IsShown()
        and wizardFrame.mainhandLayoutStatus:GetText():find("combat", 1, true),
    "a failed Mainhand HUD layout action must keep setup open on the final step")
createMainhandLayoutResult = { false, "span" }
addon.Viewport.GetMetrics = function()
    return { companionTopology=false, topologyStatus="MISMATCH", isSpanned=false }
end
wizardFrame.finishBtn.scripts.OnClick()
assert(wizardFrame.mainhandLayoutStatus:GetText():find(
        addon.L["MAINHAND_LAYOUT_SPAN_MISMATCH"], 1, true),
    "the final HUD action must replace the cryptic span token with recovery guidance")
addon.Viewport.GetMetrics = wizardMetrics
createMainhandLayoutResult = { true, "Offhand - Mainhand - Test", 52 }

-- HUD generation is recommended but must not make onboarding impossible when
-- Blizzard's layout slots or APIs cannot complete the transaction.
OffhandDB.onboarding.setupComplete = false
addon.db.firstRunComplete = false
wizardFrame:Show()
wizardFrame:SetStep(5)
local skipCharacter = OffhandCharDB
OffhandCharDB = {}
local skipPopup
local skipPopupShow = StaticPopup_Show
StaticPopup_Show = function(key, text, _, callback)
    skipPopup = { key = key, callback = callback }
end
wizardFrame.skipLayoutBtn.scripts.OnClick()
if addon._gamepadSafePopup and addon._gamepadSafePopup.popupKey then
    skipPopup = { key = addon._gamepadSafePopup.popupKey, callback = addon._gamepadSafePopup.data }
end
assert(skipPopup and skipPopup.key == "OFFHAND_WIZARD_SKIP_MAINHAND_LAYOUT"
        and not addon:IsSetupComplete() and not mainhandLayoutDeferred,
    "skipping HUD generation must require confirmation before changing setup state")
local skipPrint, skipMessages = addon.Print, {}
addon.Print = function(_, message) skipMessages[#skipMessages + 1] = message end
StaticPopupDialogs[skipPopup.key].OnAccept(nil, skipPopup.callback)
addon.Print = skipPrint
assert(#skipMessages == 2 and skipMessages[1] == addon.L.WIZARD_SKIP_HUD_COMPLETE
        and skipMessages[2] == addon.L.WIZARD_SKIP_HUD_NEXT,
    "HUD skip must report pending work and next actions without completed-HUD or restart-success messaging")
assert(addon:IsSetupComplete() and mainhandLayoutDeferred and OffhandCharDB.hudSetupReminder and not wizardFrame:IsShown(),
    "confirmed HUD deferral must complete setup, persist the choice, and close the wizard")
StaticPopup_Show = skipPopupShow
OffhandCharDB = skipCharacter
OffhandDB.onboarding.setupComplete = false
addon.db.firstRunComplete = false
mainhandLayoutDeferred = false

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

-- The named FancyZones shortcut must retain every return value from the
-- remember operation and identify the independent placement method correctly.
local originalManualRemember = addon.ManualCanvas.RememberFromMetrics
local originalManualPreview = addon.Viewport.GetManualPreviewMetrics
local originalApplyFullLayout = addon.ApplyFullLayout
local originalPrint = addon.Print
local rememberedName, rememberedSource, appliedRememberedLayout, rememberedMessage
addon.Viewport.GetManualPreviewMetrics = function()
    return { physicalWidth = 3998, physicalHeight = 2480,
        screenWidth = 1934.5, screenHeight = 1200 }
end
addon.ManualCanvas.RememberFromMetrics = function(_, _, name, source)
    rememberedName, rememberedSource = name, source
    return true, "manual-1", {
        name = name, referenceWidth = 3998, referenceHeight = 2480,
    }
end
addon.ApplyFullLayout = function() appliedRememberedLayout = true end
addon.Print = function(_, formatString, ...)
    rememberedMessage = string.format(formatString, ...)
end
SlashCmdList["Offhand"]("remember FancyZones")
assert(rememberedName == "FancyZones" and rememberedSource == "FANCYZONES",
    "/Offhand remember FancyZones must store a canonical FancyZones record")
assert(appliedRememberedLayout and rememberedMessage
        and rememberedMessage:find("FancyZones", 1, true),
    "a successful remember command must retain its record and apply the layout")
addon.ManualCanvas.RememberFromMetrics = originalManualRemember
addon.Viewport.GetManualPreviewMetrics = originalManualPreview
addon.ApplyFullLayout = originalApplyFullLayout
addon.Print = originalPrint

-- The installation guide is distinct from display calibration. It does not
-- acknowledge the welcome until the verified handoff into the Wizard.
local originalGuideCvar = GetCVar
GetCVar = function(name)
    if name == "gxWindow" then return "1" end
    if name == "gxMaximize" then return "0" end
    if originalGuideCvar then return originalGuideCvar(name) end
end
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
for _, name in ipairs(UISpecialFrames) do
    assert(name ~= "OffhandFirstLaunchFrame", "Escape must not dismiss the installation guide")
end
onboardingFrame.closeButton.scripts.OnClick()
assert(not onboardingFrame:IsShown() and not addon:IsSetupComplete(),
    "the explicit close button must remain available without completing setup")
addon.Onboarding:Open()
local identifyCalls = 0
addon.DisplayIdentify = { Show = function() identifyCalls = identifyCalls + 1 end, Hide = function() end }
onboardingFrame:SetPage(4)
assert(onboardingFrame.secondaryActionButton:IsShown(), "region labels must be available during placement")
onboardingFrame.secondaryActionButton.scripts.OnClick()
assert(identifyCalls == 1)
do
    local oldSettings, oldPanel, oldGraphics = Settings, SettingsPanel, GRAPHICS_LABEL
    local oldVideo, oldShow, oldCombat = VideoOptionsFrame, ShowUIPanel, InCombatLockdown
    local openedCategory
    GRAPHICS_LABEL = "Localized graphics"
    SettingsPanel = CreateFrame("Frame")
    function SettingsPanel:GetAllCategories()
        return {{GetName = function() return GRAPHICS_LABEL end, GetID = function() return 987 end}}
    end
    Settings = {OpenToCategory = function(id) openedCategory = id; SettingsPanel:Show() end}
    onboardingFrame:SetPage(3)
    assert(not onboardingFrame.secondaryActionButton:IsShown(), "manual settings should start in troubleshooting")
    onboardingFrame.helpButton.scripts.OnClick()
    assert(onboardingFrame.secondaryActionButton:IsShown())
    onboardingFrame.secondaryActionButton.scripts.OnClick()
    assert(openedCategory == 987 and not onboardingFrame:IsShown()
        and OffhandDB.onboarding.resumeStep == 3,
        "the display button must resolve the localized category and preserve its handoff step")
    local watcher = frames[#frames]
    watcher.scripts.OnUpdate(watcher, 0.2)
    SettingsPanel:Hide()
    watcher.scripts.OnUpdate(watcher, 0.2)
    assert(onboardingFrame:IsShown() and onboardingFrame.page == 3
        and not watcher.scripts.OnUpdate and OffhandDB.onboarding.resumeStep == 3,
        "closing game settings must return to the same guide step without completing setup")
    assert(not addon:IsSetupComplete())
    -- Unknown category IDs open general settings, never a guessed numeric ID.
    SettingsPanel.GetAllCategories = nil
    onboardingFrame.secondaryActionButton.scripts.OnClick()
    assert(openedCategory == nil)
    watcher.scripts.OnUpdate(watcher, 0.2)
    SettingsPanel:Hide()
    watcher.scripts.OnUpdate(watcher, 0.2)
    Settings.OpenToCategory = function() error("unavailable") end
    assert(not addon.Onboarding:OpenDisplaySettings() and onboardingFrame:IsShown()
        and OffhandDB.onboarding.resumeStep == 3,
        "a rejected native opener must leave a reachable manual instruction")
    Settings, SettingsPanel = nil, nil
    VideoOptionsFrame = CreateFrame("Frame")
    ShowUIPanel = function(panel) assert(panel == VideoOptionsFrame); panel:Show() end
    assert(addon.Onboarding:OpenDisplaySettings())
    watcher.scripts.OnUpdate(watcher, 0.2)
    VideoOptionsFrame:Hide()
    watcher.scripts.OnUpdate(watcher, 0.2)
    assert(onboardingFrame:IsShown(), "legacy Video settings must also return to the guide")
    VideoOptionsFrame, ShowUIPanel = nil, nil
    assert(not addon.Onboarding:OpenDisplaySettings() and onboardingFrame:IsShown())
    local attempts = 0
    SettingsPanel = CreateFrame("Frame")
    Settings = {OpenToCategory = function() attempts = attempts + 1 end}
    InCombatLockdown = function() return true end
    assert(not addon.Onboarding:OpenDisplaySettings() and attempts == 0)
    InCombatLockdown = oldCombat
    assert(addon.Onboarding:OpenDisplaySettings())
    watcher.scripts.OnUpdate(watcher, 3)
    assert(onboardingFrame:IsShown() and not watcher.scripts.OnUpdate,
        "an opener that never shows a panel must not strand the guide")
    Settings.OpenToCategory = function() SettingsPanel:Show() end
    addon.Onboarding:OpenDisplaySettings()
    watcher.scripts.OnUpdate(watcher, 600)
    assert(not watcher.scripts.OnUpdate and OffhandDB.onboarding.resumeStep == 3,
        "abandoned settings must stop polling while preserving reload recovery")
    addon.Onboarding:Open()
    assert(onboardingFrame.page == 3 and OffhandDB.onboarding.resumeStep == 3)
    addon.Onboarding:OpenDisplaySettings()
    addon.Onboarding:Close()
    assert(not watcher.scripts.OnUpdate, "world-transition cleanup must cancel the settings observer")
    Settings, SettingsPanel, GRAPHICS_LABEL = oldSettings, oldPanel, oldGraphics
    VideoOptionsFrame, ShowUIPanel, InCombatLockdown = oldVideo, oldShow, oldCombat
    addon.Onboarding:Open()
end
onboardingFrame:SetPage(1)
do
    local oldCVar, oldGet, oldSet, oldInfo = C_CVar, GetCVar, SetCVar, GetCVarInfo
    local oldUpdate, oldRestart, oldCombat = UpdateWindow, RestartGx, InCombatLockdown
    local oldSettingsPanel, oldVideo = SettingsPanel, VideoOptionsFrame
    SettingsPanel, VideoOptionsFrame = nil, nil
    local values, writes, applies = {gxMaximize = "1"}, {}, 0
    C_CVar = {
        GetCVar = function(name) return values[name] end,
        SetCVar = function(name, value) writes[#writes + 1] = name; values[name] = value end,
        GetCVarInfo = function(name) return values[name], "0", false, false, false, false, false end,
    }
    UpdateWindow = function() applies = applies + 1 end
    onboardingFrame:SetPage(3)
    assert(onboardingFrame.statusText:GetText() == addon.L["ONBOARD_STATE_MODE_OTHER"])
    onboardingFrame.nextButton.scripts.OnClick()
    assert(onboardingFrame.page == 3, "a known fullscreen setting must not advance to placement verification")
    onboardingFrame.actionButton.scripts.OnClick()
    assert(values.gxMaximize == "0" and #writes == 1 and applies == 1,
        "modern Windowed mode must change only gxMaximize and apply once")
    assert(onboardingFrame.actionButton:GetText() == addon.L["ONBOARD_MODE_ALREADY_BUTTON"]
        and not onboardingFrame.actionButton:IsEnabled() and onboardingFrame.nextButton:IsEnabled(),
        "the successful request must replace the action with an already-selected indicator")
    assert(values.gxWindow == nil and values.gxMonitor == nil and values.gxWindowedResolution == nil,
        "the action must not invent CVars, change monitors or change resolution")
    assert(onboardingFrame.page == 3 and not addon:IsSetupComplete(),
        "requesting Windowed mode must not bypass span verification or complete setup")
    onboardingFrame:SetPage(3)
    assert(onboardingFrame.statusText:GetText() == addon.L["ONBOARD_STATE_MODE_READY"])
    assert(addon.Onboarding:SetWindowedMode() and #writes == 1 and applies == 1,
        "already-windowed spans must not be resized or reapplied")
    values.gxMaximize = "1"
    onboardingFrame.scripts.OnEvent(onboardingFrame, "CVAR_UPDATE", "GXMAXIMIZE")
    assert(onboardingFrame.actionButton:IsEnabled() and not onboardingFrame.nextButton:IsEnabled()
        and onboardingFrame.actionButton:GetText() == addon.L["ONBOARD_SET_WINDOWED"],
        "an external return to fullscreen must refresh the action and block progression")
    values.gxMaximize = "0"
    onboardingFrame.scripts.OnEvent(onboardingFrame, "CVAR_UPDATE", "gxmaximize")
    assert(not onboardingFrame.actionButton:IsEnabled() and onboardingFrame.nextButton:IsEnabled())
    local previousGet = C_CVar.GetCVar
    C_CVar.GetCVar = function() error("irrelevant event must not read mode") end
    onboardingFrame.scripts.OnEvent(onboardingFrame, "CVAR_UPDATE", "unrelatedSetting")
    onboardingFrame:Hide()
    onboardingFrame.scripts.OnEvent(onboardingFrame, "CVAR_UPDATE", "gxmaximize")
    C_CVar.GetCVar = previousGet
    onboardingFrame:Show()
    values = {gxWindow = "0", gxMaximize = "1"}
    writes, applies = {}, 0
    assert(addon.Onboarding:SetWindowedMode() and values.gxWindow == "1"
        and values.gxMaximize == "0" and #writes == 2 and applies == 1,
        "exclusive fullscreen clients need both mode flags changed")
    values, writes, applies = {gxWindow = "0", gxMaximize = "1"}, {}, 0
    C_CVar.GetCVarInfo = function(name) return values[name], "0", false, false, false, true, false end
    assert(not addon.Onboarding:SetWindowedMode() and #writes == 0 and applies == 0,
        "secure CVars must never be written")
    assert(onboardingFrame.helpExpanded and onboardingFrame.secondaryActionButton:IsShown(),
        "a rejected one-click action must reveal the manual settings fallback automatically")
    C_CVar.GetCVarInfo = function(name) return values[name], "0", false, false, true, false, false end
    assert(not addon.Onboarding:SetWindowedMode() and #writes == 0, "locked CVars must never be written")
    C_CVar.GetCVarInfo = function(name) return values[name], "0", false, false, false, false, true end
    assert(not addon.Onboarding:SetWindowedMode() and #writes == 0, "read-only CVars must never be written")
    C_CVar.GetCVarInfo = function(name) return values[name], "0", false, false, false, false, false end
    C_CVar.SetCVar = function(name, value)
        writes[#writes + 1] = name
        if name == "gxMaximize" and value == "0" then return false end
        values[name] = value
    end
    assert(not addon.Onboarding:SetWindowedMode() and values.gxWindow == "0"
        and values.gxMaximize == "1" and applies == 0,
        "partial writes must roll back without applying an incomplete mode")
    C_CVar.SetCVar = function(name, value) values[name] = value end
    UpdateWindow = function() error("blocked by client") end
    assert(not addon.Onboarding:SetWindowedMode() and values.gxWindow == "0"
        and values.gxMaximize == "1", "native apply errors must restore requested CVar values")
    UpdateWindow, RestartGx = nil, nil
    assert(not addon.Onboarding:SetWindowedMode() and values.gxWindow == "0",
        "missing apply APIs must not leave pending mode changes")
    -- Legacy getters/setters and graphics apply fallback.
    GetCVar, SetCVar, GetCVarInfo = C_CVar.GetCVar, C_CVar.SetCVar, C_CVar.GetCVarInfo
    C_CVar = nil
    RestartGx = function() applies = applies + 1 end
    assert(addon.Onboarding:SetWindowedMode() and applies == 1)
    values = {}
    assert(not addon.Onboarding:SetWindowedMode(), "unavailable mode CVars require manual settings")
    onboardingFrame:SetPage(3)
    assert(onboardingFrame.statusText:GetText() == addon.L["ONBOARD_STATE_MODE_UNKNOWN"]
        and onboardingFrame.secondaryActionButton:IsShown()
        and onboardingFrame.actionButton:GetText() ~= addon.L["ONBOARD_MODE_ALREADY_BUTTON"],
        "unknown mode must expose manual settings, never show Already Windowed")
    local previousPopup, modeConfirmation = addon.ShowPopup
    addon.ShowPopup = function(_, key, _, _, callback)
        assert(key == "OFFHAND_CONFIRM_WINDOWED_MODE")
        modeConfirmation = callback
        return {SetFrameStrata = function() end, Raise = function() end}
    end
    onboardingFrame.nextButton.scripts.OnClick()
    assert(onboardingFrame.page == 3 and modeConfirmation,
        "unknown mode must require an explicit player confirmation before placement")
    values.gxMaximize = "1"
    modeConfirmation()
    assert(onboardingFrame.page == 3, "confirmation must reject a newly detected wrong mode")
    values.gxMaximize = nil
    modeConfirmation()
    assert(onboardingFrame.page == 4, "an acknowledged unknown mode may continue without claiming detection")
    addon.ShowPopup = previousPopup
    onboardingFrame:SetPage(3)
    GetCVar = function(name) if name == "gxWindow" then error("unreadable") end; return "0" end
    onboardingFrame:RefreshModeState(true)
    assert(onboardingFrame.statusText:GetText() == addon.L["ONBOARD_STATE_MODE_UNKNOWN"],
        "a partial CVar read failure must never produce Already Windowed")
    GetCVar = previousGet
    values = {gxMaximize = "1"}
    InCombatLockdown = function() return true end
    onboardingFrame.scripts.OnEvent(onboardingFrame, "PLAYER_REGEN_DISABLED")
    assert(not onboardingFrame.actionButton:IsEnabled() and not onboardingFrame.nextButton:IsEnabled())
    assert(not addon.Onboarding:SetWindowedMode() and values.gxMaximize == "1")
    InCombatLockdown = oldCombat
    onboardingFrame.scripts.OnEvent(onboardingFrame, "PLAYER_REGEN_ENABLED")
    assert(onboardingFrame.actionButton:IsEnabled())
    SettingsPanel = {IsShown = function() return true end}
    assert(not addon.Onboarding:SetWindowedMode() and values.gxMaximize == "1",
        "pending native settings must not be committed or discarded")
    C_CVar, GetCVar, SetCVar, GetCVarInfo = oldCVar, oldGet, oldSet, oldInfo
    UpdateWindow, RestartGx, InCombatLockdown = oldUpdate, oldRestart, oldCombat
    SettingsPanel, VideoOptionsFrame = oldSettingsPanel, oldVideo
    onboardingFrame:SetPage(1)
end
do
    local function CheckGuideBounds()
        local bodyBottom = -onboardingFrame.pageBody.points.TOPLEFT.y + onboardingFrame.pageBody:GetHeight()
        local statusTop = onboardingFrame:GetHeight() - onboardingFrame.statusText.points.BOTTOMLEFT.y
            - onboardingFrame.statusText:GetHeight()
        local contentBottom = statusTop
        if onboardingFrame.actionButton:IsShown() then
            contentBottom = onboardingFrame:GetHeight() - onboardingFrame.actionButton.points.BOTTOM.y
                - onboardingFrame.actionButton:GetHeight()
            assert(onboardingFrame:GetHeight() - onboardingFrame.actionButton.points.BOTTOM.y + 12 <= statusTop,
                "setup status must not overlap the action row")
        end
        assert(bodyBottom + 16 <= contentBottom, "setup body must not overlap actions or status")
        if onboardingFrame.modeIllustration:IsShown() then
            local illustrationBottom = -onboardingFrame.modeIllustration.points.TOPLEFT.y + 88
            assert(illustrationBottom + 16 <= contentBottom,
                "the mode illustration must not overlap actions or status")
        end
    end
    for page = 1, 6 do onboardingFrame:SetPage(page); CheckGuideBounds() end
    for _, page in ipairs({3, 4}) do
        onboardingFrame:SetPage(page)
        onboardingFrame.helpButton.scripts.OnClick()
        CheckGuideBounds()
        onboardingFrame.helpButton.scripts.OnClick()
        CheckGuideBounds()
    end
    onboardingFrame:SetPage(2)
    onboardingFrame:SetStatusText(string.rep("Expanded setup status ", 60))
    CheckGuideBounds()
    assert(onboardingFrame:GetHeight() > 430, "long setup status must expand rather than overlap the content")
    onboardingFrame:SetPage(5)
    assert(onboardingFrame.actionButton.points.BOTTOM.x == 0,
        "a single action must be recentered after the three-method page")
    onboardingFrame:SetPage(1)
end
local originalStaticPopupShow = StaticPopup_Show
local originalGuidePopup, guidePopupCalls = addon.ShowPopup, 0
addon.ShowPopup = function(self, ...)
    guidePopupCalls = guidePopupCalls + 1
    return originalGuidePopup(self, ...)
end
local downloadDialog = { SetFrameStrata = function(self, strata) self.strata = strata end }
StaticPopup_Show = function(key)
    assert(key == "OFFHAND_POWERTOYS_LINK", "the primary Windows path must open the PowerToys dialog")
    return downloadDialog
end
onboardingFrame:SetPage(2)
assert(onboardingFrame.actionButton:GetText() == addon.L["ONBOARD_USE_COMPANION"],
    "Companion must be the first placement choice")
onboardingFrame.secondaryActionButton.scripts.OnClick()
assert(onboardingFrame:IsShown() and onboardingFrame.methodDetails == "FANCYZONES"
        and not onboardingFrame.nextButton:IsShown() and guidePopupCalls == 0,
    "choosing FancyZones must show Already installed / Get, without opening a download")
onboardingFrame.secondaryActionButton.scripts.OnClick()
downloadDialog = addon._gamepadSafePopup or downloadDialog
assert(downloadDialog.popupKey == "OFFHAND_POWERTOYS_LINK", "setup must use the owned download card")
assert(not onboardingFrame:IsShown() and downloadDialog.strata == "TOOLTIP",
    "download dialog must temporarily replace the onboarding guide")
assert(addon:GetOnboardingSetupMethod() == "FANCYZONES",
    "choosing FancyZones must persist the setup method across reload")
StaticPopupDialogs["OFFHAND_POWERTOYS_LINK"].OnHide()
assert(onboardingFrame:IsShown() and onboardingFrame.page == 2,
    "closing the download dialog must return to onboarding step 2")
assert(onboardingFrame.methodDetails == "FANCYZONES",
    "returning from a download must retain the selected software handoff")
onboardingFrame.actionButton.scripts.OnClick()
assert(onboardingFrame.page == 3, "already-installed FancyZones must continue without downloading again")
assert(guidePopupCalls == 1)
onboardingFrame.backButton.scripts.OnClick()

StaticPopup_Show = function(key)
    assert(key == "OFFHAND_DOWNLOAD_LINK", "the Companion path must open its download dialog")
    return downloadDialog
end
onboardingFrame.actionButton.scripts.OnClick()
assert(onboardingFrame:IsShown() and onboardingFrame.methodDetails == "COMPANION" and guidePopupCalls == 1,
    "choosing Companion must not automatically open its download")
onboardingFrame.secondaryActionButton.scripts.OnClick()
assert(addon:GetOnboardingSetupMethod() == "COMPANION",
    "choosing Companion must persist the setup method across reload")
StaticPopupDialogs["OFFHAND_DOWNLOAD_LINK"].OnHide()
onboardingFrame.backButton.scripts.OnClick()
assert(onboardingFrame.page == 2 and not onboardingFrame.methodDetails,
    "Back from the software handoff must allow another method")
onboardingFrame.tertiaryActionButton.scripts.OnClick()
assert(onboardingFrame.page == 3 and addon:GetOnboardingSetupMethod() == "MANUAL",
    "manual placement needs no software installation handoff")
onboardingFrame.backButton.scripts.OnClick()
onboardingFrame.actionButton.scripts.OnClick()
onboardingFrame.actionButton.scripts.OnClick()
assert(onboardingFrame.page == 3 and addon:GetOnboardingSetupMethod() == "COMPANION",
    "already-installed Companion must continue without opening a download")
assert(guidePopupCalls == 2, "only explicit Get actions may open software downloads")
addon.ShowPopup = originalGuidePopup
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
assert(onboardingFrame.page == 4 and OffhandDB.onboarding.resumeStep == 4,
    "unfinished onboarding must retain step 4 across subsequent reloads")

-- Manual spanning and intentional single-ultrawide layouts are first-class
-- paths, but WoW cannot expose physical display boundaries. They must require
-- explicit acknowledgement rather than claim automatic span detection.
addon.Viewport.GetMetrics = function()
    return {
        companionTopology = false, topologyStatus = "ABSENT", isSpanned = true,
        gameLeft = 1440, gameRight = 4000, gameBottom = 0, gameTop = 1440,
        gameWidth = 2560, physicalWidth = 4000, physicalHeight = 2560,
        screenWidth = 1200, screenHeight = 768,
        gamePixelLeft = 1440, gamePixelBottom = 0,
        gamePixelWidth = 2560, gamePixelHeight = 1440,
        workspacePixelLeft = 0, workspacePixelBottom = 0,
        workspacePixelWidth = 1440, workspacePixelHeight = 2560,
    }
end
assert(addon:SetOnboardingSetupMethod("MANUAL") == true,
    "manual setup method must be accepted")
onboardingFrame:SetPage(4)
local manualPopup
StaticPopup_Show = function(key, text, _, callback)
    local frame = {
        SetFrameStrata = function(self, strata) self.strata = strata end,
        Raise = function(self) self.raised = true end,
    }
    manualPopup = { key = key, text = text, callback = callback, frame = frame }
    return frame
end
onboardingFrame.nextButton.scripts.OnClick()
assert(onboardingFrame.page == 4 and manualPopup
        and manualPopup.key == "OFFHAND_CONFIRM_MANUAL_LAYOUT",
    "manual geometry must wait for explicit acknowledgement at onboarding step 4")
assert(manualPopup.frame.strata == "TOOLTIP" and manualPopup.frame.raised,
    "the manual-layout confirmation must be raised above the onboarding window")
StaticPopupDialogs[manualPopup.key].OnAccept(nil, manualPopup.callback)
assert(onboardingFrame.page == 6,
    "confirmed manual geometry must advance directly to the calibration handoff")

assert(addon:SetOnboardingSetupMethod("FANCYZONES") == true,
    "FancyZones setup method must be accepted")
onboardingFrame:SetPage(4)
manualPopup = nil
onboardingFrame.nextButton.scripts.OnClick()
assert(onboardingFrame.page == 4 and manualPopup
        and manualPopup.key == "OFFHAND_CONFIRM_MANUAL_LAYOUT",
    "FancyZones must use the same explicit remembered-canvas confirmation as manual placement")

addon.Viewport.GetMetrics = function()
    return {
        companionTopology = false, topologyStatus = "ABSENT", isSpanned = false,
        physicalWidth = 2560, physicalHeight = 1440,
        screenWidth = 1365, screenHeight = 768,
        gamePixelLeft = 0, gamePixelBottom = 0,
        gamePixelWidth = 2560, gamePixelHeight = 1440,
        workspacePixelLeft = 0, workspacePixelBottom = 0,
        workspacePixelWidth = 922, workspacePixelHeight = 1440,
    }
end
onboardingFrame:SetPage(4)
manualPopup = nil
onboardingFrame.nextButton.scripts.OnClick()
assert(onboardingFrame.page == 4 and manualPopup
        and manualPopup.key == "OFFHAND_CONFIRM_MANUAL_LAYOUT",
    "an unverified single-screen canvas must require the same deliberate manual-layout acknowledgement")
assert(onboardingFrame.page == 4,
    "cancelling manual layout acknowledgement must remain on onboarding step 4")

addon.Viewport.GetMetrics = function()
    return {
        companionTopology = false, topologyStatus = "MISMATCH", isSpanned = true,
        physicalWidth = 4000, physicalHeight = 2560,
        screenWidth = 1200, screenHeight = 768,
        gamePixelLeft = 1440, gamePixelBottom = 0,
        gamePixelWidth = 2560, gamePixelHeight = 1440,
        workspacePixelLeft = 0, workspacePixelBottom = 0,
        workspacePixelWidth = 1440, workspacePixelHeight = 2560,
    }
end
manualPopup = nil
onboardingFrame.nextButton.scripts.OnClick()
assert(onboardingFrame.page == 4 and manualPopup
        and manualPopup.key == "OFFHAND_CONFIRM_MANUAL_LAYOUT",
    "manual setup must be able to relinquish stale generated Companion topology explicitly")

addon:SetOnboardingSetupMethod("COMPANION")
addon.Viewport.GetMetrics = function()
    return { companionTopology = false, topologyStatus = "ABSENT", isSpanned = true }
end
onboardingFrame.nextButton.scripts.OnClick()
assert(onboardingFrame.page == 4 and onboardingFrame.statusText:GetText():find(
        addon.L["ONBOARD_STATUS_COMPANION_RELOAD_REQUIRED"], 1, true),
    "Companion setup must wait for generated topology to load after a span")

addon._displayGeometryTransitionActive = true
onboardingFrame.nextButton.scripts.OnClick()
assert(onboardingFrame.page == 4 and onboardingFrame.statusText:GetText():find(
        addon.L["ONBOARD_STATUS_GEOMETRY_SETTLING"], 1, true),
    "onboarding must not validate geometry while the display is still settling")
addon._displayGeometryTransitionActive = nil

addon.Viewport.GetMetrics = function()
    return {
        companionTopology = true, isSpanned = true, topologyStatus = "MATCH",
        companionVersionStatus = "MATCH", gameLeft = 1440, gameRight = 4000,
        gameBottom = 0, gameTop = 1440, gameWidth = 2560,
    }
end
StaticPopup_Show = originalStaticPopupShow
addon.isForever = true
onboardingFrame:SetPage(5)
assert(onboardingFrame.page == 6 and not onboardingFrame.actionButton:IsShown()
        and onboardingFrame.stepText:GetText() == string.format(addon.L["ONBOARD_PROGRESS"], 5, 5),
    "legacy preview progress must lead to task 5 of 5, not a disabled action")
addon.isForever = false
local originalHasBlizzardEditMode = addon.HasBlizzardEditMode
addon.HasBlizzardEditMode = function() return true end
onboardingFrame:SetPage(5)
assert(onboardingFrame.pageBody:GetText() == string.format(addon.L["ONBOARD_CALIBRATE_TASK_EDITMODE"], "|cffffd100" .. onboardingFrame.nextButton:GetText() .. "|r"),
    "non-Forever clients with Edit Mode must receive client-neutral HUD guidance")
onboardingFrame:SetPage(6)
assert(onboardingFrame.pageBody:GetText() == string.format(addon.L["ONBOARD_CALIBRATE_TASK_EDITMODE"], "|cffffd100" .. onboardingFrame.nextButton:GetText() .. "|r"),
    "Edit Mode completion guidance must not be restricted to Retail by name")
addon.HasBlizzardEditMode = function() return false end
onboardingFrame:SetPage(5)
assert(onboardingFrame.pageTitle:GetText() == addon.L["ONBOARD_CALIBRATE_TASK_TITLE"]
        and onboardingFrame.pageBody:GetText() == string.format(addon.L["ONBOARD_CALIBRATE_TASK_CLASSIC"], "|cffffd100" .. onboardingFrame.nextButton:GetText() .. "|r")
        and not onboardingFrame.actionButton:IsShown(),
    "Classic-family clients without Edit Mode must receive non-Retail preparation guidance")
onboardingFrame:SetPage(6)
assert(onboardingFrame.pageBody:GetText() == string.format(addon.L["ONBOARD_CALIBRATE_TASK_CLASSIC"], "|cffffd100" .. onboardingFrame.nextButton:GetText() .. "|r"),
    "Classic-family completion guidance must describe the four-step wizard")
addon.HasBlizzardEditMode = originalHasBlizzardEditMode
onboardingFrame:SetPage(1)
local calibrationOpened = false
addon.Wizard.Open = function() calibrationOpened = true end
onboardingFrame.nextButton.scripts.OnClick()
onboardingFrame.actionButton.scripts.OnClick() -- choose Companion
onboardingFrame.actionButton.scripts.OnClick() -- Already installed
for _ = 1, 4 do onboardingFrame.nextButton.scripts.OnClick() end
assert(addon:IsWelcomeDismissed(),
    "onboarding must acknowledge the welcome only when handing off to calibration")
assert(calibrationOpened, "onboarding must hand off to the separate calibration wizard")
assert(OffhandDB.onboarding.resumeStep == 6 and not addon:IsSetupComplete(),
    "calibration handoff must retain incomplete setup rather than silently dismiss it")
addon.Onboarding:Close()
addon.Onboarding:Open()
assert(onboardingFrame.page == 6 and OffhandDB.onboarding.resumeStep == 6,
    "abandoned calibration must resume its handoff stage with saved values intact")
local resumeMetrics = addon.Viewport.GetMetrics
addon.Viewport.GetMetrics = function() return {isSpanned = false} end
addon.Onboarding:Open()
assert(onboardingFrame.page == 4, "a restored single-window session must recheck placement before calibration")
addon.Viewport.GetMetrics = resumeMetrics
for _, method in ipairs({"FANCYZONES", "COMPANION", "MANUAL"}) do
    addon:SetOnboardingSetupMethod(method)
    for _, page in ipairs({3, 4}) do
        onboardingFrame:SetPage(page)
        assert(onboardingFrame.pageBody:GetText() == addon.L[page == 3 and "ONBOARD_MODE_READY_BODY" or "ONBOARD_PLACE_" .. method],
            "preparation must be one task and placement must describe only the selected method")
        onboardingFrame.helpButton.scripts.OnClick()
        assert(onboardingFrame.pageBody:GetText():find(addon.L["ONBOARD_PATH_" .. method .. "_" .. page], 1, true),
            "troubleshooting must reveal only the selected method's detailed instructions")
        onboardingFrame.helpButton.scripts.OnClick()
    end
    assert(onboardingFrame.actionButton.points.BOTTOM.x == (method == "COMPANION" and -101 or 0),
        "visible placement actions must be centered without a hidden reload action")
end
-- Migrate older welcome-dismissed/incomplete records without a resume marker.
OffhandDB.onboarding.resumeStep = nil
addon:SetOnboardingSetupMethod("COMPANION")
addon.Onboarding:Open()
assert(onboardingFrame.page == 6, "legacy incomplete acknowledgements must still lead back to calibration")
OffhandDB.onboarding.resumeStep = nil
OffhandDB.onboarding.setupMethod = nil
addon.Viewport.GetMetrics = function() return {isSpanned = false} end
addon.Onboarding:Open()
assert(onboardingFrame.page == 2, "a missing method must return to method selection")
addon.Viewport.GetMetrics = resumeMetrics
addon:SetOnboardingSetupMethod("COMPANION")
onboardingFrame:SetPage(6)
OffhandDB.onboarding.setupComplete = true
OffhandDB.onboarding.resumeStep = nil
addon.Onboarding:Open()
assert(onboardingFrame.page == 1 and not OffhandDB.onboarding.resumeStep,
    "completed users may inspect the guide without becoming incomplete again")
OffhandDB.onboarding.setupComplete = false
addon.Wizard.Open = originalWizardOpen
addon.Viewport.GetMetrics = originalGetMetrics
GetCVar = originalGuideCvar

-- ============================================================================
-- 5. Test Options Dialog 1-Click and Wizard Integration Buttons
-- ============================================================================
local optPanel = addon.Options:CreateFloatingPanel()
optPanel.identifyDisplaysButton.scripts.OnClick()
assert(identifyCalls == 2, "settings must expose the same identification action")
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
assert(#optPanel.tabButtons == 5 and optPanel.tabButtons[1].selected,
    "settings must expose all five pages with a persistent selected navigation state")
optPanel.scrollFrame:SetHeight(400) -- anchored viewport height in the real client
optPanel.scrollFrame.scripts.OnMouseWheel(optPanel.scrollFrame, -10)
assert(optPanel.scrollFrame:GetVerticalScroll() == 400)
optPanel.tabButtons[2].scripts.OnClick()
assert(optPanel.scrollFrame:GetVerticalScroll() == 0 and optPanel.tabButtons[2].selected
        and not optPanel.tabButtons[1].selected,
    "a newly visited settings page must begin at its top")
optPanel.tabButtons[1].scripts.OnClick()
assert(optPanel.scrollFrame:GetVerticalScroll() == 400,
    "returning to a page must restore that page's session scroll position")
local lastSection = optPanel.sectionButtons[9]
assert(lastSection and lastSection:IsShown(), "Display must expose all nine section shortcuts")
assert(-lastSection.points.TOPLEFT.y + lastSection:GetHeight() < optPanel:GetHeight() - 52,
    "section shortcuts must not overlap the fixed footer")
lastSection.scripts.OnClick()
assert(optPanel.scrollFrame:GetVerticalScroll() > 400,
    "section shortcuts must jump to their actual stacked card offset")
optPanel.tabButtons[4].scripts.OnClick()
assert(not lastSection:IsShown() and optPanel.sectionButtons[1]:IsShown(),
    "shorter pages must hide stale section shortcuts")
optPanel.tabButtons[1].scripts.OnClick()
addon.UIControls.SetScrollOffset(optPanel.scrollFrame, 0)
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
assert(optPanel.companionAppBtn:IsShown(),
    "Window Setup must remain available when Companion is actively supplying geometry")
local lockedSeamSlider
for _, frame in ipairs(frames) do
    if frame.title and frame.title.GetText and frame.title:GetText() == addon.L.SLIDER_SEAM_WIDTH
        and frame.btnPlus then lockedSeamSlider = frame; break end
end
assert(lockedSeamSlider and not lockedSeamSlider.enabled and not lockedSeamSlider.btnPlus.enabled
        and not lockedSeamSlider.editBox.enabled,
    "exact topology must lock the complete settings seam control, not just its rail")
assert(optPanel.banner.points["TOPRIGHT"].rel == -24
        and optPanel.banner.points["TOPLEFT"].rel == 218,
    "Exact Companion status must have a dedicated full-width row above setup actions")

addon.Viewport.GetMetrics = panelGetMetrics
addon.Options:RefreshPanel()
assert(lockedSeamSlider.enabled and lockedSeamSlider.btnPlus.enabled and lockedSeamSlider.editBox.enabled,
    "returning to manual geometry must re-enable the complete seam control")
assert(optPanel.companionAppBtn:IsShown(),
    "Window Setup must remain available when exact Companion geometry is absent")
assert(optPanel.banner.points["TOPRIGHT"].rel == -24,
    "Manual display status must retain the dedicated status row")

-- Test Window Overlap Prevention:
-- When Options is shown and Auto-Setup Wizard is clicked, Options must hide and Wizard must open
addon.Options:Open()
assert(optPanel:IsShown() == true, "Options panel must be shown")

assert(optPanel.autoWizardBtn:GetText() == addon.L["ONBOARD_CONTINUE_SETUP"])
optPanel.autoWizardBtn.scripts["OnClick"]()
assert(onboardingFrame:IsShown() and not optPanel:IsShown(),
    "unfinished users need a visible route back to setup, not standalone calibration")
addon.Onboarding:Close()
local previousSetupComplete = OffhandDB.onboarding.setupComplete
OffhandDB.onboarding.setupComplete = true
addon.Options:Open()
assert(optPanel.autoWizardBtn:GetText() == addon.L["BTN_AUTO_WIZARD"])
optPanel.autoWizardBtn.scripts["OnClick"]()
assert(optPanel:IsShown() == false, "Options panel must hide when Wizard opens from it")
assert(wizardFrame:IsShown() == true, "Wizard must be shown")
OffhandDB.onboarding.setupComplete = previousSetupComplete

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

-- Profile presentation must retain selection, keyboard and scroll contracts
-- without changing the profile storage/mutation implementation.
do
    local controls = assert(optPanel.profileControls)
    local originalGet, originalCreate = addon.GetProfiles, addon.CreateProfile
    local originalCharacterDB = OffhandCharDB
    OffhandCharDB = OffhandCharDB or {}
    local originalActive = OffhandCharDB.activeProfile
    local profileNames = { "Default" }
    for i = 1, 20 do profileNames[#profileNames + 1] = string.format("Profile %02d", i) end
    addon.GetProfiles = function() return profileNames end
    OffhandCharDB.activeProfile = "Default"
    addon.Options:UpdateProfileList()
    assert(#controls.rows == 21 and controls.rows[1].activeText:GetText() == addon.L.PROFILE_ACTIVE)
    assert(controls.rows[1].text:GetText() == "Default",
        "profile names and active-state labels must use separate text regions")
    controls.rows[2].scripts.OnClick(controls.rows[2])
    assert(controls.rows[2].selected and controls.load.enabled and controls.copy.enabled
        and controls.delete.enabled, "selecting an inactive profile must enable its existing actions")
    addon.UIControls.SetScrollOffset(controls.scroll, 10000)
    profileNames = { "Default" }
    addon.Options:UpdateProfileList()
    assert(not controls.load.enabled and not controls.copy.enabled and not controls.delete.enabled,
        "removing a selected profile must clear its stale action state")
    assert(controls.scroll:GetVerticalScroll() == 0 and not controls.rows[2]:IsShown(),
        "shrinking the list must clamp scrolling and hide obsolete rows")
    local creations = 0
    addon.CreateProfile = function(_, name)
        creations = creations + 1
        profileNames[#profileNames + 1] = name
        OffhandCharDB.activeProfile = name
        return true
    end
    controls.input:SetText("   ")
    controls.input.scripts.OnEnterPressed(controls.input)
    assert(creations == 0, "Enter on an empty profile name must do nothing")
    controls.input:SetText("Keyboard profile")
    controls.input.scripts.OnEscapePressed(controls.input)
    assert(creations == 0 and controls.input:GetText() == "Keyboard profile",
        "Escape must only leave the profile field, not create or discard a name")
    for i = 1, 20 do profileNames[#profileNames + 1] = string.format("Profile %02d", i) end
    controls.input:SetText("  Keyboard profile  ")
    controls.input.scripts.OnEnterPressed(controls.input)
    assert(creations == 1 and profileNames[#profileNames] == "Keyboard profile"
        and controls.input:GetText() == "", "Enter must use the same trimmed creation path as the button")
    assert(controls.rows[#profileNames].selected and controls.scroll:GetVerticalScroll() > 0,
        "newly created profiles must be selected and revealed even in a long list")
    addon.GetProfiles, addon.CreateProfile = originalGet, originalCreate
    OffhandCharDB.activeProfile = originalActive
    OffhandCharDB = originalCharacterDB
    addon.Options:UpdateProfileList()
end


-- Retired internal step 5 aliases 6 for saved resumes, but Back must skip it.
onboardingFrame:SetPage(6)
onboardingFrame.backButton.scripts.OnClick()
assert(onboardingFrame.page == 4, "Back from calibration handoff must return to placement")
onboardingFrame.backButton.scripts.OnClick()
assert(onboardingFrame.page == 3, "placement Back must still return to Windowed setup")
-- Preserve legacy saved-resume markers.
onboardingFrame:SetPage(5)
assert(onboardingFrame.page == 6, "calibration handoff must remain reachable")

-- First-time Settings is a detour, not an exit from calibration.
OffhandDB.onboarding.setupComplete = false
addon.db.firstRunComplete = false
addon.Wizard:Open()
wizardFrame:SetStep(3)
wizardFrame.advBtn.scripts.OnClick()
assert(optPanel:IsShown() and not wizardFrame:IsShown() and addon.Wizard.settingsResumeStep == 3,
    "All Settings must retain the unfinished calibration step")
addon.Options:Close()
assert(wizardFrame:IsShown() and wizardFrame.step == 3 and not addon.Wizard.settingsResumeStep,
    "closing Settings must return to the same first-time wizard step")
addon:MarkSetupComplete()
wizardFrame.advBtn.scripts.OnClick()
addon.Options:Close()
assert(not wizardFrame:IsShown(), "completed users must retain ordinary Settings close behavior")

-- Display changes recenter the visible guide without changing its task.
local metricsGetter = addon.Viewport.GetMetrics
addon.Viewport.GetMetrics = function() return {
    isSpanned = true, gameWidth = 1600, gameLeft = 1000, gameRight = 2600,
    gameBottom = 100, gameTop = 1000,
} end
onboardingFrame:SetPage(4)
onboardingFrame:Show()
onboardingFrame.scripts.OnEvent(onboardingFrame, "DISPLAY_SIZE_CHANGED")
assert(onboardingFrame.page == 4 and onboardingFrame.points.CENTER.relPoint == "BOTTOMLEFT",
    "resizing must recenter the guide in Mainhand without leaving placement")
addon.Viewport.GetMetrics = metricsGetter

-- Existing-layout warnings expose recovery actions, not an acknowledgement only.
do
    local guideModule, wizardModule = addon.Onboarding, addon.Wizard
    local guides, calibrations = 0, 0
    addon.Onboarding = {Open = function() guides = guides + 1 end}
    addon.Wizard = {Open = function() calibrations = calibrations + 1 end}
    for _, notice in ipairs({handoffNotice, topologyWarning, versionWarning}) do
        assert(notice.button1 and notice.button2 and notice.button3,
            "recovery warnings must offer guide, calibration and dismiss actions")
        notice.OnAccept()
        notice.OnAlt()
    end
    assert(guides == 3 and calibrations == 3, "warning actions must launch their named recovery flow")
    addon.Onboarding, addon.Wizard = guideModule, wizardModule
end
