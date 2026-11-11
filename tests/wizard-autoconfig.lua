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
    function f:SetParent(nextParent)
        if self.parent and self.parent.children then
            for i,child in ipairs(self.parent.children) do if child==self then table.remove(self.parent.children,i);break end end
        end
        self.parent=nextParent
        if nextParent and nextParent.children then table.insert(nextParent.children,self) end
    end
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
        if self.name == "OffhandSetupWizardFrame" then
            assert(next(self.points),
                "wizard must be anchored before Show; OnShow cannot position an unanchored native frame")
        end
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
        if not f._fontString then f._fontString = { SetWidth = function(s, width) s.width = width end, SetWordWrap = function(s, enabled) s.wordWrap = enabled end, SetTextColor = function() end } end
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
            shown = true,
            Show = function(s) s.shown=true end,
            Hide = function(s) s.shown=false end,
            IsShown = function(s) return s.shown end,
            points = {},
            SetText = function(s, t) s.text = t end,
            SetWidth = function(s, width) s.width = width end,
            SetHeight = function(s, height) s.height = height end,
            GetHeight = function(s) return s.height or 0 end,
            SetWordWrap = function(s, enabled) s.wordWrap = enabled end,
            SetNonSpaceWrap = function(s, enabled) s.nonSpaceWrap = enabled end,
            SetMaxLines = function(s, count) s.maxLines = count end,
            SetTextScale = function(s, scale) s.textScale = scale end,
            SetTextColor = function() end,
            GetText = function(s) return s.text end,
            SetPoint = function(s, pt, rel, relPt, x, y) s.points[pt] = { rel = rel, relPt = relPt, x = x, y = y } end,
            ClearAllPoints = function(s) s.points = {} end,
            SetJustifyH = function() end,
            SetJustifyV = function() end,
            SetTextColor = function() end,
            SetWidth = function(s, width) s.width = width end,
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
assert(loadfile("Core/MapScale.lua"))("Offhand", addon)
assert(loadfile("UI/Options.lua"))("Offhand", addon)
assert(loadfile("Core/SetupPlacement.lua"))("Offhand", addon)
assert(loadfile("UI/SetupVisuals.lua"))("Offhand", addon)
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
local trackedHUDCreation=addon.Options.CreateMainhandHUDLayout
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
        == addon.L["MAINHAND_LAYOUT_SPAN_ACTIONS"],
    "an unconfirmed span must explain spanning/reload rather than suggest diagnostics as a repair")

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
local interactiveMetrics = addon.Viewport.GetMetrics
addon.Viewport.GetMetrics = function()
    local m = interactiveMetrics(addon.Viewport)
    m.isSpanned = true
    return m
end
addon.Wizard:Open()

local wizardFrame = _G["OffhandSetupWizardFrame"]
assert(wizardFrame ~= nil, "OffhandSetupWizardFrame must be created")
for _, text in ipairs({wizardFrame.welcomeText,wizardFrame.topoText,wizardFrame.recomText,wizardFrame.statusText,wizardFrame.progressText}) do
    assert(text.wordWrap == true, "Wizard guidance must wrap instead of truncating native text")
end
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
    local m=initialWizardMetrics()
    m.companionTopology=true;m.isSpanned=true;m.topologyStatus="READY"
    return m
end
wizardFrame:UpdateState()
wizardFrame:SetStep(2)
assert(not wizardFrame.aspectButtons[1]:IsShown() and not wizardFrame.aspectLabel:IsShown()
        and wizardFrame.exactTopologyHelp:GetText()==addon.L.WIZARD_COMPANION_CHANGE,
    "Companion layout review must hide manual-only choices and show a short change hint")
wizardFrame:SetStep(3)
assert(not wizardFrame.seamSlider:IsShown() and not wizardFrame.seamTitle:IsShown()
        and wizardFrame.laserButton:IsEnabled() and wizardFrame.laserButton:IsShown()
        and wizardFrame.seamHelp:GetText()==addon.L.WIZARD_COMPANION_SEAM,
    "Companion seam review must hide width controls and retain physical alignment")
addon.Viewport.GetMetrics = initialWizardMetrics
wizardFrame:UpdateState()
wizardFrame:SetStep(2)
assert(wizardFrame.aspectButtons[1]:IsShown() and wizardFrame.aspectButtons[1]:IsEnabled() == true
        and wizardFrame.exactTopologyHelp:GetText() == "",
    "Wizard step 2 must remove the lock explanation when manual geometry is available")
assert(wizardFrame.seamSlider:IsEnabled() == true
        and wizardFrame.seamHelp:GetText() == addon.L["WIZARD_SEAM_INSTRUCTION"],
    "Wizard step 3 must restore normal guidance when manual geometry is available")

-- First-install users may follow Next instead of the optional recommendation.
-- Opening a guide remains inert; explicitly advancing confirmed calibration
-- must activate the saved geometry before the HUD transaction can use it.
do
    local savedMetrics, savedApply = addon.Viewport.GetMetrics, addon.ApplyFullLayout
    local savedRatio, savedScale = addon.db.deckWidthRatio, addon.db.hudScale
    local savedComplete = OffhandDB.onboarding.setupComplete
    local applied = 0
    addon.Viewport.GetMetrics = function()
        return {
            companionTopology = true, topologyStatus = "READY", isSpanned = true,
            companionVersionStatus = "MATCH", physicalWidth = 4480, physicalHeight = 1440,
            gamePixelLeft = 1920, gamePixelBottom = 0, gamePixelWidth = 2560, gamePixelHeight = 1440,
            workspacePixelLeft = 0, workspacePixelBottom = 5, workspacePixelWidth = 1920, workspacePixelHeight = 1080,
            gameLeft = 1920, gameRight = 4480, gameBottom = 0, gameTop = 1440,
            workspaceLeft = 0, workspaceRight = 1920, workspaceBottom = 5, workspaceTop = 1085,
        }
    end
    addon.ApplyFullLayout = function()
        if addon.db.enabled then applied = applied + 1 end
    end
    OffhandDB.onboarding.setupComplete = false
    addon.db.firstRunComplete = false
    addon.db.deckWidthRatio, addon.db.hudScale = 0.43, 0.81
    addon:SetEnabled(false)
    addon.Wizard:Open(1)
    assert(not addon.db.enabled and applied == 0,
        "merely opening calibration must preserve an explicitly disabled viewport")
    wizardFrame.finishBtn.scripts.OnClick()
    assert(addon.db.enabled and applied == 1 and wizardFrame.step == 2,
        "fresh-install Next must activate confirmed calibration without requiring Auto-Configure")
    assert(addon.db.deckWidthRatio == 0.43 and addon.db.hudScale == 0.81
            and not addon:IsSetupComplete() and not addon.db.automaticSetupSuppressed,
        "manual continuation must preserve calibration and leave HUD setup incomplete")
    wizardFrame.finishBtn.scripts.OnClick()
    assert(applied == 1, "later calibration steps must not repeatedly activate an already enabled profile")

    addon:SetEnabled(false)
    addon.Wizard:Open(3)
    wizardFrame.finishBtn.scripts.OnClick()
    assert(addon.db.enabled and applied == 2 and wizardFrame.step == 4,
        "resumed calibration must not strand a disabled profile at a later step")

    local savedCreate, savedPrompt = addon.Options.CreateMainhandHUDLayout, addon.Mainhand.PromptReload
    local created = 0
    addon.Options.CreateMainhandHUDLayout = function()
        assert(addon.db.enabled, "manual setup must activate before requesting the native HUD transaction")
        created = created + 1
        return true, "Offhand", 52
    end
    addon.Mainhand.PromptReload = function() end
    wizardFrame.finishBtn.scripts.OnClick()
    assert(wizardFrame.step == 5 and not addon:IsSetupComplete())
    addon:SetEnabled(false)
    wizardFrame.finishBtn.scripts.OnClick()
    assert(addon.db.enabled and created == 1 and addon:IsSetupComplete() and not wizardFrame:IsShown(),
        "fresh manual setup must complete the HUD transaction without the recommendation action")
    addon.Options.CreateMainhandHUDLayout, addon.Mainhand.PromptReload = savedCreate, savedPrompt
    OffhandDB.onboarding.setupComplete = false
    addon.db.firstRunComplete = false

    local beforeRejected, validMetrics = applied, addon.Viewport.GetMetrics
    addon:SetEnabled(false)
    addon.Viewport.GetMetrics = function()
        return { companionTopology = false, topologyStatus = "MISMATCH", isSpanned = false }
    end
    addon.Wizard:Open(1)
    wizardFrame.finishBtn.scripts.OnClick()
    assert(not addon.db.enabled and applied == beforeRejected,
        "a stale or restored window must never be activated by calibration continuation")
    addon.Viewport.GetMetrics = function()
        local metrics = validMetrics()
        metrics.companionVersionStatus = "MISMATCH"
        return metrics
    end
    addon.Wizard:Open(1)
    wizardFrame.finishBtn.scripts.OnClick()
    assert(not addon.db.enabled and applied == beforeRejected,
        "an incompatible Companion version must not activate calibration")

    addon.Viewport.GetMetrics, addon.ApplyFullLayout = savedMetrics, savedApply
    addon.db.deckWidthRatio, addon.db.hudScale = savedRatio, savedScale
    OffhandDB.onboarding.setupComplete = savedComplete
    addon:SetEnabled(true)
    addon.Wizard:Open(1)
end

-- Click 1-Click Auto-Configure inside wizard
addon.db.deckWidthRatio = 0.55
addon.db.firstRunComplete = false
wizardFrame:SetStep(1)
assert(wizardFrame.recommendedButton==wizardFrame.autoBtn and wizardFrame.autoBtn.uiPrimary
    and not wizardFrame.finishBtn.uiPrimary,
    "wizard discovery must highlight Apply recommendations rather than bypass it")
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
assert(wizardFrame.recommendedButton==wizardFrame.finishBtn and wizardFrame.finishBtn.uiPrimary
    and wizardFrame.progressText:GetText():find(wizardFrame.finishBtn:GetText(),1,true),
    "wizard must highlight and name its recommended next action")
assert(wizardFrame.welcomeText:GetText() == addon.L["STEP_5_HELP"]
        and wizardFrame.mainhandLayoutHelp:GetText()==addon.L.WIZARD_HUD_SHORT_BODY
        and not wizardFrame.mainhandLayoutHelp:GetText():find("Readiness:",1,true),
    "HUD setup must use short player instructions without diagnostic readiness fields")
wizardFrame:SetStep(4)
assert(wizardFrame.stepIllustration.legend:GetText():find("70%%"),
    "the scale preview must show the current UI percentage")
addon.db.hudScale=.85;wizardFrame:UpdateState()
assert(wizardFrame.stepIllustration.legend:GetText():find("85%%"),
    "the scale preview must follow current scale changes")
addon.db.hudScale=.70;wizardFrame:UpdateState();wizardFrame:SetStep(5)
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
    local frameCount, height, cardHeight=#frames,wizardFrame:GetHeight(),wizardFrame.pages[5]:GetHeight()
    for _=1,50 do wizardFrame:LayoutStep();CheckWizardBounds() end
    assert(#frames==frameCount and wizardFrame:GetHeight()==height and wizardFrame.pages[5]:GetHeight()==cardHeight,
        "visual refresh allocated frames or accumulated illustration height")
    assert(wizardFrame.progressRail.cells[1].state=="complete" and wizardFrame.progressRail.cells[5].state=="current")

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
    return { companionTopology=false, topologyStatus="ABSENT", isSpanned=true }
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
assert(wizardFrame.step == 4 and not addon:IsSetupComplete()
        and wizardFrame.recoveryReason == "span"
        and wizardFrame.recoveryBody:GetText():find("Choose placement method", 1, true),
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
assert(wizardFrame.recoveryReason == "span"
        and wizardFrame.finishBtn:GetText():find("Choose placement method", 1, true),
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
assert(#skipMessages == 3 and skipMessages[1] == addon.L.WIZARD_SKIP_HUD_COMPLETE
        and skipMessages[2] == addon.L.WIZARD_SKIP_HUD_NEXT
        and skipMessages[3] == addon.L.SETUP_FIRST_PANEL,
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
addon:SetEnabled(false)
assert(addon.db.automaticSetupSuppressed == true)
addon.Onboarding:Open()
assert(addon.db.enabled == false and addon.db.automaticSetupSuppressed == false,
    "explicit guide entry must clear setup suppression without activating the viewport")
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
            local illustrationBottom = -onboardingFrame.modeIllustration.points.TOPLEFT.y + onboardingFrame.modeIllustration:GetHeight()
            assert(illustrationBottom + 16 <= contentBottom,
                "the mode illustration must not overlap actions or status")
        end
    end
    for page = 1, 6 do
        onboardingFrame:SetPage(page);CheckGuideBounds()
        assert(onboardingFrame.modeIllustration:IsShown()==(page>=3),
            "non-illustrated guide tasks exposed the native-default visible pool")
    end
    local frameCount,height=#frames,onboardingFrame:GetHeight()
    for _=1,50 do onboardingFrame:LayoutPage();CheckGuideBounds() end
    assert(#frames==frameCount and onboardingFrame:GetHeight()==height,
        "guide visual refresh allocated frames or changed the stable layout")

    for _, page in ipairs({3, 4}) do
        onboardingFrame:SetPage(page)
        onboardingFrame.helpButton.scripts.OnClick()
        CheckGuideBounds()
        onboardingFrame.helpButton.scripts.OnClick()
        CheckGuideBounds()
    end
    do
        local dictionary, oldLocale = {}, GetLocale
        for key,value in pairs(addon.L) do dictionary[key]=value end
        local oldMethod, oldCheckpoint=addon:GetOnboardingSetupMethod(),addon:GetPlacementCheckpoint()
        local oldMetrics,oldPreview=addon.Viewport.GetMetrics,addon.Viewport.GetManualPreviewMetrics
        addon.Viewport.GetMetrics=function() return {isSpanned=true,physicalWidth=4000,physicalHeight=2560,
            gameWidth=2560,gameHeight=1440,gameLeft=1440,gameRight=4000,gameBottom=0,gameTop=1440} end
        addon.Viewport.GetManualPreviewMetrics=function() return {physicalWidth=4000,physicalHeight=2560} end
        for _,locale in ipairs({"enUS","deDE","esES","esMX","frFR","itIT","ptBR","ruRU","koKR","zhCN","zhTW"}) do
            for key in pairs(addon.L) do addon.L[key]=nil end
            for key,value in pairs(dictionary) do addon.L[key]=value end
            GetLocale=function() return locale end
            assert(loadfile("Locales/"..locale..".lua"))("Offhand",addon)
            addon:SetOnboardingSetupMethod("MANUAL")
            addon.SetupPlacement:Reset()
            onboardingFrame:SetPage(4)
            CheckGuideBounds()
            assert(onboardingFrame.actionButton.uiPrimary and not onboardingFrame.nextButton.enabled)
            assert(onboardingFrame.pageBody:GetText():find(addon.L.ONBOARD_SPAN_ACK,1,true))
            onboardingFrame.actionButton.scripts.OnClick()
            CheckGuideBounds()
            assert(onboardingFrame.pageBody:GetText():find(
                addon:GetReloadUIFunction() and addon.L.ONBOARD_RELOAD_UI or "/reload",1,true))
            assert(onboardingFrame.actionButton:IsShown() == (addon:GetReloadUIFunction() ~= nil),
                "manual reload guidance must not show a nonfunctional action button")
            assert(addon.SetupPlacement:RequestReload())
            assert(loadfile("Core/SetupPlacement.lua"))("Offhand",addon)
            onboardingFrame:SetPage(4)
            CheckGuideBounds()
            assert(onboardingFrame.nextButton.uiPrimary and onboardingFrame.nextButton.enabled,
                "review action was not highlighted after reload for "..locale)
            assert(onboardingFrame.pageBody:GetText():find(addon.L.ONBOARD_CONFIRM_PLACEMENT,1,true))
            addon:SetOnboardingSetupMethod("COMPANION")
            addon.SetupPlacement:Reset()
            assert(addon.SetupPlacement:AcknowledgeSpan() and addon.SetupPlacement:RequestReload())
            assert(loadfile("Core/SetupPlacement.lua"))("Offhand",addon)
            onboardingFrame:SetPage(4)
            CheckGuideBounds()
            assert(onboardingFrame.placementPhase==1 and not onboardingFrame.nextButton.enabled
                and onboardingFrame.pageBody:GetText():find(addon.L.ONBOARD_RELOAD_COMPLETE_PLACE,1,true),
                "localized span recovery must acknowledge the completed reload: "..locale)
            addon:SetOnboardingSetupMethod("MANUAL")
            wizardFrame:SetStep(5)
            local card=wizardFrame.pages[5]
            local top=-select(5,card:GetPoint(1))
            local validationTop=wizardFrame:GetHeight()-wizardFrame.validationStatus.points.BOTTOMLEFT.y
                -wizardFrame.validationStatus:GetHeight()
            assert(top+card:GetHeight()+12<=validationTop,"localized wizard caption overlaps content: "..locale)
        end
        for key in pairs(addon.L) do addon.L[key]=nil end
        for key,value in pairs(dictionary) do addon.L[key]=value end
        GetLocale=oldLocale
        OffhandDB.onboarding.setupMethod=oldMethod
        addon.Viewport.GetMetrics,addon.Viewport.GetManualPreviewMetrics=oldMetrics,oldPreview
        addon:SetPlacementCheckpoint(oldCheckpoint)
        assert(loadfile("Core/SetupPlacement.lua"))("Offhand",addon)
        wizardFrame:SetStep(5)
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
assert(not onboardingFrame.nextButton.enabled and onboardingFrame.actionButton.uiPrimary,
    "placement must start with a highlighted window-position acknowledgement")
onboardingFrame.actionButton.scripts.OnClick()
assert(reloadCount==0 and addon.SetupPlacement:GetStage()=="RELOAD" and not onboardingFrame.nextButton.enabled)
onboardingFrame.actionButton.scripts.OnClick()
assert(addon.SetupPlacement:GetStage()=="RELOAD", "requesting Reload UI counted as a completed reload")
assert(reloadCount == 1 and OffhandDB.onboarding.resumeStep == 4,
    "step 4 Reload UI must persist its resume point before reloading")
OffhandDB.onboarding.welcomeDismissed = true
assert(addon:GetOnboardingResumeStep() == 4 and addon:IsWelcomeDismissed(),
    "a pending Step 4 resume must remain discoverable for users who dismissed the older welcome")
addon.Onboarding:Open()
assert(onboardingFrame.page == 4 and OffhandDB.onboarding.resumeStep == 4,
    "unfinished onboarding must retain step 4 across subsequent reloads")
do
    local previousStyle = addon.IsGamepadUIEnabled
    addon.IsGamepadUIEnabled = function() return true end
    local previousForever, previousUI, previousMetrics = addon.isForever, C_UI, addon.Viewport.GetMetrics
    local protectedReloadCalls = 0
    addon.isForever = true
    C_UI = { Reload = function() protectedReloadCalls = protectedReloadCalls + 1 end }
    addon.Viewport.GetMetrics = function() return {
        isSpanned=true, companionTopology=true, topologyStatus="READY", companionVersionStatus="MATCH",
        physicalWidth=4000,physicalHeight=2560,gameWidth=2560,gameHeight=1440,
        gameLeft=1440,gameRight=4000,gameBottom=0,gameTop=1440,
    } end
    addon.SetupPlacement:Reset()
    onboardingFrame:SetPage(4)
    onboardingFrame.actionButton.scripts.OnClick()
    local stage, signature = addon.SetupPlacement:GetStage()
    assert(stage == "RELOAD" and protectedReloadCalls == 0
        and not onboardingFrame.actionButton:IsShown() and not onboardingFrame.nextButton.enabled
        and onboardingFrame.pageBody:GetText() == addon.L.SETUP_MANUAL_RELOAD
        and addon:GetOnboardingResumeStep() == 4,
        "Forever must save its manual reload handoff without invoking either reload API")
    assert(not addon.SetupPlacement:Confirm(signature),
        "preparing manual reload must not unlock placement in the current UI session")
    onboardingFrame:RefreshPlacementState()
    assert(not onboardingFrame.nextButton.enabled and protectedReloadCalls == 0)
    assert(loadfile("Core/SetupPlacement.lua"))("Offhand",addon)
    onboardingFrame:SetPage(4)
    assert(addon.SetupPlacement:GetStage() == "CONFIRM" and onboardingFrame.nextButton.enabled,
        "a modeled real UI reload must unlock the saved placement review")
    addon.isForever, C_UI, addon.Viewport.GetMetrics = previousForever, previousUI, previousMetrics
    addon.IsGamepadUIEnabled = previousStyle
end

-- Reproduce a real reload without an applied Companion span. Reload remains
-- complete, but the next task must be placement, never a repeated reload loop.
do
    local oldMetrics, oldMethod = addon.Viewport.GetMetrics, addon:GetOnboardingSetupMethod()
    local oldCheckpoint, oldUI, oldStyle = addon:GetPlacementCheckpoint(), C_UI, addon.IsGamepadUIEnabled
    local reloads, matched = 0, false
    C_UI = {Reload=function() reloads=reloads+1 end}
    addon.IsGamepadUIEnabled=function() return false end
    addon:SetOnboardingSetupMethod("COMPANION")
    addon.Viewport.GetMetrics=function() return {
        physicalWidth=4000,physicalHeight=2560,screenWidth=1200,screenHeight=768,
        topologyStatus=matched and "READY" or "MISMATCH",companionTopology=matched,
        companionVersionStatus="MATCH",isSpanned=matched,
        gameLeft=1440,gameRight=4000,gameBottom=0,gameTop=1440,gameWidth=2560,
    } end
    addon.SetupPlacement:Reset()
    assert(addon.SetupPlacement:AcknowledgeSpan() and addon.SetupPlacement:RequestReload())
    assert(loadfile("Core/SetupPlacement.lua"))("Offhand",addon)
    local checkpoint=addon:GetPlacementCheckpoint()
    onboardingFrame:SetPage(4)
    assert(addon.SetupPlacement:GetStage()=="CONFIRM" and addon:GetPlacementCheckpoint()==checkpoint,
        "an unsuccessful span must not erase the fact that the UI actually reloaded")
    assert(onboardingFrame.placementPhase==1 and onboardingFrame.modeIllustration.kind=="POSITION"
        and onboardingFrame.actionButton:GetText():find(addon.L.ONBOARD_SPAN_ACK,1,true)
        and onboardingFrame.pageBody:GetText():find(addon.L.ONBOARD_RELOAD_COMPLETE_PLACE,1,true)
        and not onboardingFrame.nextButton.enabled,
        "an unspanned post-reload window must show placement instructions and lock confirmation")
    onboardingFrame.nextButton.scripts.OnClick()
    assert(onboardingFrame.page==4 and reloads==0,"a stale confirmation bypassed missing span")
    onboardingFrame.actionButton.scripts.OnClick()
    assert(reloads==0 and addon.SetupPlacement:GetStage()=="RELOAD"
        and onboardingFrame.placementPhase==2 and not onboardingFrame.nextButton.enabled,
        "the recovery action must acknowledge new placement without immediately reloading")
    matched=true
    onboardingFrame.actionButton.scripts.OnClick()
    assert(reloads==1 and addon.SetupPlacement:GetStage()=="RELOAD" and not onboardingFrame.nextButton.enabled,
        "a reload request after spanning must still wait for a new UI session")
    assert(loadfile("Core/SetupPlacement.lua"))("Offhand",addon)
    onboardingFrame:SetPage(4)
    assert(onboardingFrame.placementPhase==3 and onboardingFrame.nextButton.enabled
        and not onboardingFrame.actionButton:IsShown(),"valid placement must unlock after the actual reload")
    matched=false
    onboardingFrame:RefreshPlacementState()
    assert(not onboardingFrame.nextButton.enabled and onboardingFrame.placementPhase==1,
        "losing the valid span must lock confirmation and restore placement guidance")
    addon.Viewport.GetMetrics, C_UI, addon.IsGamepadUIEnabled=oldMetrics,oldUI,oldStyle
    addon:SetOnboardingSetupMethod(oldMethod)
    addon:SetPlacementCheckpoint(oldCheckpoint)
    assert(loadfile("Core/SetupPlacement.lua"))("Offhand",addon)
end

local function PreparePlacementReview()
    onboardingFrame:SetPage(4)
    if addon.SetupPlacement:GetStage()=="SPAN" then onboardingFrame.actionButton.scripts.OnClick() end
    if addon.SetupPlacement:GetStage()=="RELOAD" then
        onboardingFrame.actionButton.scripts.OnClick()
        -- A fresh module models a new UI session; merely calling ReloadUI above
        -- intentionally leaves the checkpoint locked in the old session.
        assert(loadfile("Core/SetupPlacement.lua"))("Offhand", addon)
    end
    onboardingFrame:SetPage(4)
    local stage=addon.SetupPlacement:GetStage()
    assert(stage=="CONFIRM" or stage=="READY", "placement fixture did not perform a modeled reload")
end

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
local originalManualShowPopup = addon.ShowPopup
addon.ShowPopup = function(_, key, text, _, callback)
    local frame = {
        SetFrameStrata = function(self, strata) self.strata = strata end,
        Raise = function(self) self.raised = true end,
    }
    manualPopup = { key = key, text = text, callback = callback, frame = frame }
    return frame
end
PreparePlacementReview()
onboardingFrame.nextButton.scripts.OnClick()
assert(onboardingFrame.page == 4 and manualPopup
        and manualPopup.key == "OFFHAND_CONFIRM_MANUAL_LAYOUT",
    "manual geometry must wait for explicit acknowledgement at onboarding step 4")
assert(manualPopup.frame.strata == "TOOLTIP" and manualPopup.frame.raised,
    "the manual-layout confirmation must be raised above the onboarding window")
do
    -- Modal acceptance must recheck live state, not trust the opening snapshot.
    local checkpoint=addon:GetPlacementCheckpoint()
    addon._displayGeometryTransitionActive=true
    StaticPopupDialogs[manualPopup.key].OnAccept(nil,manualPopup.callback)
    assert(onboardingFrame.page==4 and addon:GetPlacementCheckpoint()==checkpoint)
    addon._displayGeometryTransitionActive=nil
    onboardingFrame:SetPage(4)
    onboardingFrame.nextButton.scripts.OnClick()
    local stale=manualPopup.callback
    onboardingFrame:SetPage(3)
    onboardingFrame:SetPage(4)
    stale()
    assert(onboardingFrame.page==4 and addon:GetPlacementCheckpoint()==checkpoint,
        "a modal from a previous page visit confirmed placement")
    onboardingFrame.nextButton.scripts.OnClick()
    local metrics=addon.Viewport.GetMetrics
    addon.Viewport.GetMetrics=function()
        local m=metrics();m.physicalWidth=m.physicalWidth+100;return m
    end
    StaticPopupDialogs[manualPopup.key].OnAccept(nil,manualPopup.callback)
    assert(onboardingFrame.page==4 and addon:GetPlacementCheckpoint()==checkpoint,
        "resizing while the modal was open accepted the old preview")
    addon.Viewport.GetMetrics=metrics
    onboardingFrame:SetPage(4)
    onboardingFrame.nextButton.scripts.OnClick()
    local combat=InCombatLockdown
    InCombatLockdown=function() return true end
    StaticPopupDialogs[manualPopup.key].OnAccept(nil,manualPopup.callback)
    assert(onboardingFrame.page==4 and addon:GetPlacementCheckpoint()==checkpoint
        and not onboardingFrame.nextButton.enabled,
        "combat accepted a placement review or left confirmation enabled")
    InCombatLockdown=combat
    onboardingFrame:SetPage(4)
    onboardingFrame.nextButton.scripts.OnClick()
end
StaticPopupDialogs[manualPopup.key].OnAccept(nil, manualPopup.callback)
assert(onboardingFrame.page == 6,
    "confirmed manual geometry must advance directly to the calibration handoff")

assert(addon:SetOnboardingSetupMethod("FANCYZONES") == true,
    "FancyZones setup method must be accepted")
onboardingFrame:SetPage(4)
manualPopup = nil
PreparePlacementReview()
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
PreparePlacementReview()
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
PreparePlacementReview()
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
addon.ShowPopup = originalManualShowPopup
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
assert(onboardingFrame.pageBody:GetText() == string.format(addon.L["ONBOARD_CALIBRATE_TASK_EDITMODE"], "|cffffd100" .. onboardingFrame.nextButton:GetText() .. "|r") .. "\n\n" .. addon.L.SETUP_FIRST_PANEL,
    "non-Forever clients with Edit Mode must receive client-neutral HUD guidance")
onboardingFrame:SetPage(6)
assert(onboardingFrame.pageBody:GetText() == string.format(addon.L["ONBOARD_CALIBRATE_TASK_EDITMODE"], "|cffffd100" .. onboardingFrame.nextButton:GetText() .. "|r") .. "\n\n" .. addon.L.SETUP_FIRST_PANEL,
    "Edit Mode completion guidance must not be restricted to Retail by name")
addon.HasBlizzardEditMode = function() return false end
onboardingFrame:SetPage(5)
assert(onboardingFrame.pageTitle:GetText() == addon.L["ONBOARD_CALIBRATE_TASK_TITLE"]
        and onboardingFrame.pageBody:GetText() == string.format(addon.L["ONBOARD_CALIBRATE_TASK_CLASSIC"], "|cffffd100" .. onboardingFrame.nextButton:GetText() .. "|r") .. "\n\n" .. addon.L.SETUP_FIRST_PANEL
        and not onboardingFrame.actionButton:IsShown(),
    "Classic-family clients without Edit Mode must receive non-Retail preparation guidance")
onboardingFrame:SetPage(6)
assert(onboardingFrame.pageBody:GetText() == string.format(addon.L["ONBOARD_CALIBRATE_TASK_CLASSIC"], "|cffffd100" .. onboardingFrame.nextButton:GetText() .. "|r") .. "\n\n" .. addon.L.SETUP_FIRST_PANEL,
    "Classic-family completion guidance must describe the four-step wizard")
addon.HasBlizzardEditMode = originalHasBlizzardEditMode
onboardingFrame:SetPage(1)
local calibrationOpened = false
addon.Wizard.Open = function() calibrationOpened = true end
onboardingFrame.nextButton.scripts.OnClick()
onboardingFrame.actionButton.scripts.OnClick() -- choose Companion
onboardingFrame.actionButton.scripts.OnClick() -- Already installed
onboardingFrame.nextButton.scripts.OnClick() -- Windowed -> placement
PreparePlacementReview()
local confirmPlacement, previousPlacementPopup = nil, addon.ShowPopup
addon.ShowPopup=function(_, key, _, _, callback)
    assert(key=="OFFHAND_CONFIRM_PLACEMENT")
    confirmPlacement=callback
    return {SetFrameStrata=function() end,Raise=function() end}
end
onboardingFrame.nextButton.scripts.OnClick()
assert(confirmPlacement and onboardingFrame.page==4, "Companion placement must wait for final confirmation")
StaticPopupDialogs.OFFHAND_CONFIRM_PLACEMENT.OnAccept(nil,confirmPlacement)
assert(onboardingFrame.page==6 and addon.SetupPlacement:GetStage()=="READY")
onboardingFrame.nextButton.scripts.OnClick()
addon.ShowPopup=previousPlacementPopup
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
    addon.SetupPlacement:Reset()
    for _, page in ipairs({3, 4}) do
        onboardingFrame:SetPage(page)
        local expectedBody = page == 3 and addon.L["ONBOARD_MODE_READY_BODY"]
            or string.format(addon.L["ONBOARD_SPAN_" .. method], "|cffffd100" .. addon.L["ONBOARD_SPAN_ACK"] .. "|r")
        assert(onboardingFrame.pageBody:GetText() == expectedBody,
            "preparation must be one task and placement must describe only the selected method")
        onboardingFrame.helpButton.scripts.OnClick()
        assert(onboardingFrame.pageBody:GetText():find(addon.L["ONBOARD_PATH_" .. method .. "_" .. page], 1, true),
            "troubleshooting must reveal only the selected method's detailed instructions")
        onboardingFrame.helpButton.scripts.OnClick()
    end
    assert(onboardingFrame.actionButton.points.BOTTOM.x == -101,
        "visible placement actions must be centered without a hidden reload action")
end
-- Migrate older welcome-dismissed/incomplete records without a resume marker.
OffhandDB.onboarding.resumeStep = nil
addon:SetOnboardingSetupMethod("COMPANION")
addon.Onboarding:Open()
assert(onboardingFrame.page == 4, "legacy incomplete acknowledgements must verify placement before calibration")
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
assert(optPanel.header.versionText:GetText():find("N4UX", 1, true),
    "the version row must credit the addon author")
assert(optPanel.header.taglineText:GetText() == "| " .. addon.L.ADDON_DESC
    and optPanel.header.taglineText.points.LEFT.rel == optPanel.header.titleText
    and optPanel.header.taglineText.points.LEFT.relPt == "RIGHT"
    and optPanel.header.versionText:GetHeight() == 16,
    "the tagline must share the title row, above one readable version row")
do
    local previous, shown = addon.ShowPopup
    addon.ShowPopup = function(_, key) shown = key end
    optPanel.websiteButton.scripts.OnClick()
    assert(shown == "OFFHAND_WEBSITE_LINK"
        and StaticPopupDialogs[shown].gamepadEditBoxText() == "https://offhand-wow.onrender.com/")
    optPanel.discordButton.scripts.OnClick()
    assert(shown == "OFFHAND_DISCORD_LINK"
        and StaticPopupDialogs[shown].gamepadEditBoxText() == "https://discord.gg/J2P3SM6pAY")
    addon.ShowPopup = previous
end
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
do
    local function Sections(tab)
        local cards = {}
        for _, card in ipairs(optPanel.cards) do
            if card.parent == tab then cards[#cards+1] = card end
        end
        table.sort(cards, function(a,b) return select(5,a:GetPoint(1)) > select(5,b:GetPoint(1)) end)
        return cards
    end
    local display, workspace, appearance = Sections(optPanel.tab1), Sections(optPanel.tab2), Sections(optPanel.tab3)
    assert(display[1].sectionLabel == addon.L.CARD_LAYOUT_PRESETS
        and display[2].sectionLabel == addon.L.CARD_VIEWPORT_AR
        and display[3].sectionLabel == addon.L.CARD_SCALE_ALIGNMENT,
        "display geometry and UI size must precede secondary and advanced settings")
    assert(workspace[1].sectionLabel == addon.L.MAP_SETTINGS
        and workspace[2].sectionLabel == addon.L.CARD_PERSISTENCE
        and workspace[3].sectionLabel == addon.L[addon.isForever
            and "CARD_CHARACTER_WINDOW" or "CARD_WORKSPACE_WINDOW_CONTROL"],
        "map and everyday window controls must lead the Offhand page")
    if addon.isForever then
        assert(workspace[3]:GetHeight() == 100, "Forever must use a compact Character scale card")
        for _, child in ipairs(workspace[3].children) do
            assert(not child.Text or child.Text:GetText() ~= addon.L.LOCK_WORKSPACE_WINDOWS,
                "unsupported lock controls must not be created in Forever settings")
        end
    end
    local recoveryIndex, routingIndex
    for i,card in ipairs(workspace) do
        if card.sectionLabel == addon.L.CARD_RECOVERY then recoveryIndex=i end
        if card.sectionLabel == addon.L.WORKSPACE_ROUTING_TITLE then routingIndex=i end
    end
    assert(not routingIndex or recoveryIndex < routingIndex,
        "optional automatic routing must follow map, window and recovery tools")
    assert(appearance[1].sectionLabel == addon.L.CARD_THEMES,
        "overall appearance must precede individual workspace overrides")
    assert(optPanel.tabButtons[2]:GetText() == "Offhand Monitor"
        and optPanel.tabButtons[5]:GetText() == "Help & Setup")
    local help = Sections(optPanel.tab5)[1]
    local recoveryLink
    for _,child in ipairs(help.children) do
        if child.GetText and child:GetText() == addon.L.BTN_OPEN_RECOVERY then recoveryLink=child end
    end
    assert(recoveryLink, "setup help must link to the existing recovery section")
    recoveryLink.scripts.OnClick()
    assert(optPanel.tabButtons[2].selected and optPanel.scrollFrame:GetVerticalScroll() > 0)
    optPanel.tabButtons[1].scripts.OnClick()
    addon.UIControls.SetScrollOffset(optPanel.scrollFrame,0)
end
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

-- Discord v23 regression: a directly opened/resumed wizard must not reach HUD
-- creation with missing Companion geometry, or strand a player at a full list.
do
    local savedMetrics, savedMethod = addon.Viewport.GetMetrics, addon:GetOnboardingSetupMethod()
    local savedCharDB=OffhandCharDB
    OffhandCharDB={}
    local savedReload, savedEditMode, savedShow, savedCombat = ReloadUI, EditModeManagerFrame, ShowUIPanel, InCombatLockdown
    local ready = false
    addon:SetOnboardingSetupMethod("COMPANION")
    addon.Viewport.GetMetrics = function()
        if not ready then return {isSpanned=false, topologyStatus="ABSENT"} end
        return {isSpanned=true, companionTopology=true, topologyStatus="READY",
            companionVersionStatus="MATCH", physicalWidth=4000, physicalHeight=2560,
            screenWidth=4000,screenHeight=2560,
            gamePixelWidth=2560, gamePixelHeight=1440, workspacePixelWidth=1440, workspacePixelHeight=2560,
            gameLeft=1440, gameRight=4000, gameBottom=0, gameTop=1440,
            workspaceLeft=0, workspaceRight=1440, workspaceTop=2560, workspaceBottom=0, topologyMode="DUAL_DISPLAY"}
    end
    InCombatLockdown=function() return false end
    addon.Wizard:Open()
    assert(wizardFrame.recoveryReason=='span' and wizardFrame.recoveryCard:IsShown())
    local body = wizardFrame.recoveryBody
    local originalHeight = body.GetStringHeight
    body.GetStringHeight = function() return 12 end -- stale ellipsized native metrics
    wizardFrame:LayoutStep()
    assert(body.height > 100 and body.width == wizardFrame.recoveryCard:GetWidth() - 28,
        'recovery must reserve full paragraphs despite truncated native metrics')
    local reserved = body.height
    body.GetStringHeight = function() return reserved + 40 end
    wizardFrame.scripts.OnEvent(wizardFrame, 'DISPLAY_SIZE_CHANGED')
    assert(body.height >= reserved + 40
        and wizardFrame.recoveryCard:GetHeight() >= body.height + 36 + 12,
        'display changes must remeasure and contain the full recovery text')
    body.GetStringHeight = originalHeight
    wizardFrame:LayoutStep()
    for _,card in ipairs(wizardFrame.pages) do assert(not card:IsShown()) end
    assert(not wizardFrame.skipLayoutBtn:IsShown() and not wizardFrame.backBtn:IsShown(),
        'missing placement must not offer navigation/finish paths around its recovery')
    local initialCreates=createMainhandLayoutCount
    wizardFrame:SetStep(5)
    local reloads=0
    ReloadUI=function() reloads=reloads+1 end
    InCombatLockdown=function() return true end
    wizardFrame.finishBtn.scripts.OnClick()
    assert(reloads==0 and not OffhandCharDB.wizardRecoveryStep,'combat must not persist a reload request')
    InCombatLockdown=function() return false end
    wizardFrame.finishBtn.scripts.OnClick()
    assert(reloads==1 and OffhandCharDB.wizardRecoveryStep==5 and addon:GetOnboardingResumeStep()==6)
    do
        local previousForever, previousStyle = addon.isForever, addon.IsGamepadUIEnabled
        addon.isForever = true
        addon.IsGamepadUIEnabled = function() return true end
        wizardFrame:ShowRecovery('span')
        assert(wizardFrame.finishBtn:GetText():find(addon.L.BTN_RELOAD_INSTRUCTIONS,1,true)
            and wizardFrame.recoveryBody:GetText() == addon.L.WIZARD_RECOVERY_COMPANION_MANUAL_BODY)
        wizardFrame.finishBtn.scripts.OnClick()
        local prompt = addon._gamepadSafePopup
        assert(reloads == 1 and OffhandCharDB.wizardRecoveryStep == 5
            and prompt.popupKey == "OFFHAND_SETUP_MANUAL_RELOAD" and not prompt.definition.OnAccept,
            "Forever recovery must save the wizard step and offer instructions without reloading")
        prompt.accept.scripts.OnClick()
        assert(reloads == 1, "dismissing reload instructions must never call a reload API")
        addon.isForever, addon.IsGamepadUIEnabled = previousForever, previousStyle
        wizardFrame:ShowRecovery('span')
    end
    assert(createMainhandLayoutCount==initialCreates,'missing placement must not call HUD generation')
    -- Simulate the persisted handoff in a newly opened guide after /reload.
    addon.Onboarding:Open()
    assert(wizardFrame.step==5 and wizardFrame.recoveryReason=='span'
        and not OffhandCharDB.wizardRecoveryStep,'failed reload must remain recoverable at the saved step')
    wizardFrame.finishBtn.scripts.OnClick()
    ready=true
    addon.Onboarding:Open()
    assert(wizardFrame.step==5 and not wizardFrame.recoveryReason and wizardFrame.pages[5]:IsShown(),
        'loaded geometry must resume the same step without automatically creating a layout')
    assert(wizardFrame.backBtn:IsShown(),'normal Back must reappear after span recovery')
    ready=false
    wizardFrame:SetStep(2)
    wizardFrame.recoveryBackButton.scripts.OnClick()
    assert(onboardingFrame:IsShown() and onboardingFrame.page==4 and not wizardFrame:IsShown())
    ready=true
    addon.Wizard:OpenHUDSetup()
    addon.Wizard:OpenLayoutCapacityRecovery()
    assert(wizardFrame.step == wizardFrame.totalSteps and wizardFrame.recoveryReason == 'maximum',
        'Repair HUD capacity failure must enter actionable wizard recovery')
    addon.Wizard:OpenHUDSetup()
    createMainhandLayoutResult={false,'maximum'}
    wizardFrame.finishBtn.scripts.OnClick()
    assert(wizardFrame.recoveryReason=='maximum' and wizardFrame.recoveryBody:GetText():find('layout dropdown',1,true))
    assert(not wizardFrame.recoveryBody:GetText():find('Limit is 5',1,true))
    assert(wizardFrame:GetHeight() >= wizardFrame.recoveryCard:GetHeight()+100,
        'recovery text must participate in the measured layout')
    local manager={shown=false,IsShown=function(self) return self.shown end,CanEnterEditMode=function() return true end}
    EditModeManagerFrame=manager
    ShowUIPanel=function(frame) assert(frame==manager);frame.shown=true end
    InCombatLockdown=function() return true end
    assert(not addon.Wizard:OpenLayoutManagement() and not manager.shown)
    InCombatLockdown=function() return false end
    assert(addon.Wizard:OpenLayoutManagement() and not wizardFrame:IsShown() and manager.shown)
    local watcher
    for _,frame in ipairs(frames) do
        if frame.scripts.OnUpdate and frame~=wizardFrame and frame~=onboardingFrame then watcher=frame end
    end
    assert(watcher,'Edit Mode return must have an addon-owned observer')
    watcher.scripts.OnUpdate(watcher,0.25)
    assert(not wizardFrame:IsShown(),'opening Edit Mode must keep calibration out of the way')
    manager.shown=false
    watcher.scripts.OnUpdate(watcher,0.25)
    assert(wizardFrame:IsShown() and wizardFrame.step==5 and not watcher.scripts.OnUpdate,
        'closing Edit Mode must resume HUD setup and stop observing')
    assert(wizardFrame.backBtn:IsShown(),'normal Back must reappear after Edit Mode recovery')
    assert(createMainhandLayoutCount==initialCreates+1,'return must not automatically retry or delete a layout')
    -- Repeated visits reuse the watcher, and explicit guide navigation cancels it.
    wizardFrame:ShowRecovery('maximum')
    assert(addon.Wizard:OpenLayoutManagement())
    addon.Onboarding:Open()
    assert(not watcher.scripts.OnUpdate and not addon.Wizard.editModeReturnStep)
    manager.shown=false
    assert(not manager.scripts and not manager.hooks,'native Edit Mode manager must not receive addon hooks/fields')
    -- Each placement method must lead with an action that can resolve its state.
    ready=false
    for _,method in ipairs({'MANUAL','FANCYZONES'}) do
        addon:SetOnboardingSetupMethod(method)
        wizardFrame:SetStep(3)
        assert(wizardFrame.finishBtn:GetText():find('Return to window setup',1,true))
        assert(not wizardFrame.recoveryBody:GetText():find('Span WoW Now',1,true))
        assert(wizardFrame.recoveryBody:GetText():find('Confirm placement',1,true))
        wizardFrame.recoveryBackButton.scripts.OnClick()
        assert(wizardFrame.recoveryReason=='span','rechecking must not confirm a missing placement')
        wizardFrame.finishBtn.scripts.OnClick()
        assert(onboardingFrame:IsShown() and onboardingFrame.page==4)
    end
    OffhandDB.onboarding.setupMethod=nil
    wizardFrame:SetStep(3)
    assert(wizardFrame.finishBtn:GetText():find('Choose placement method',1,true))
    wizardFrame.finishBtn.scripts.OnClick()
    assert(onboardingFrame.page==2,'unknown method must return to method selection')
    addon:SetOnboardingSetupMethod('COMPANION')
    ready=true
    OffhandDB.onboarding.setupComplete=false
    addon.Wizard:Open(3)
    local ratio=addon.db.deckWidthRatio
    addon.Wizard:Close()
    addon.Wizard:Open()
    assert(wizardFrame.step==3 and wizardFrame.restartButton:IsShown() and wizardFrame.backBtn:IsShown(),
        'ordinary close/reopen must resume the incomplete task with navigation intact')
    assert(wizardFrame.validationStatus:GetText():find('Continuing calibration',1,true))
    addon.Wizard:Close()
    addon.Onboarding:Open()
    assert(wizardFrame:IsShown() and wizardFrame.step==3 and not onboardingFrame:IsShown(),
        'login guide handoff must resume incomplete calibration without overlapping dialogs')
    wizardFrame.restartButton.scripts.OnClick()
    assert(wizardFrame.step==1 and addon.db.deckWidthRatio==ratio and not wizardFrame.restartButton:IsShown(),
        'restart must reset navigation only, not saved calibration values')
    for _,bad in ipairs({0,6,'invalid'}) do
        OffhandCharDB.wizardProgressStep=bad
        assert(not addon.Wizard:GetSavedStep(),'invalid saved task must not become an actionable step')
    end
    OffhandCharDB.wizardProgressStep=3
    createMainhandLayoutResult={true,'Offhand - Mainhand - Test',52}
    wizardFrame:SetStep(5)
    wizardFrame.finishBtn.scripts.OnClick()
    assert(not OffhandCharDB.wizardProgressStep and not OffhandCharDB.wizardRecoveryStep,
        'successful setup must clear pending calibration markers')
    addon.Wizard:Open()
    assert(wizardFrame.step==1,'completed users must start fresh when intentionally reopening calibration')
    local reasons={combat='HUD_FAILURE_COMBAT',open='HUD_FAILURE_EDITMODE_OPEN',
        disabled='HUD_FAILURE_DISABLED',['read-api']='HUD_FAILURE_API',['save-api']='HUD_FAILURE_API',
        api='HUD_FAILURE_API',unsupported='HUD_FAILURE_API',unavailable='HUD_FAILURE_UNAVAILABLE',
        presets='HUD_FAILURE_UNAVAILABLE',state='HUD_FAILURE_STATE',source='HUD_FAILURE_SOURCE',
        ['repair-system']='HUD_FAILURE_REPAIR',already='HUD_FAILURE_ALREADY',save='HUD_FAILURE_SAVE',
        ['activate-api']='HUD_FAILURE_ACTIVATE',gamepad='HUD_FAILURE_CONTROLLER'}
    for reason,key in pairs(reasons) do
        local message=addon.Options:GetMainhandLayoutFailureText(reason)
        assert(message==addon.L[key] and not message:find('('..reason..')',1,true),
            'HUD failure must have actionable localized guidance: '..reason)
    end
    assert(addon.Options:GetMainhandLayoutFailureText('future-api-reason')==addon.L.HUD_FAILURE_UNKNOWN)
    local originalCreate=addon.Mainhand.CreateOrUpdateEditModeLayout
    addon.Mainhand.CreateOrUpdateEditModeLayout=function() return false,'save' end
    assert(not trackedHUDCreation(addon.Options) and addon.Mainhand.lastLayoutFailure=='save',
        'the technical failure reason must remain available on the addon namespace')
    addon.Mainhand.CreateOrUpdateEditModeLayout=function() return true,'layout',3,'select' end
    local success,name,moved,activation=trackedHUDCreation(addon.Options)
    assert(success and name=='layout' and moved==3 and activation=='select' and not addon.Mainhand.lastLayoutFailure,
        'successful HUD creation must preserve results and clear the stale technical failure')
    addon.Mainhand.CreateOrUpdateEditModeLayout=originalCreate
    local preference=addon.ManualCanvas:GetGeometryPreference()
    OffhandCharDB.wizardProgressStep=5
    OffhandCharDB.wizardRecoveryStep=5
    onboardingFrame:SelectMethod('MANUAL')
    assert(not OffhandCharDB.wizardProgressStep and not OffhandCharDB.wizardRecoveryStep and addon.db.deckWidthRatio==ratio,
        'changing placement methods must restart review without resetting calibration values')
    addon.ManualCanvas:SetGeometryPreference(preference)
    addon.Viewport.GetMetrics=savedMetrics
    if savedMethod then addon:SetOnboardingSetupMethod(savedMethod) end
    ReloadUI,EditModeManagerFrame,ShowUIPanel,InCombatLockdown=savedReload,savedEditMode,savedShow,savedCombat
    OffhandCharDB=savedCharDB
    print('PASS: missing-span reload handoff and Edit Mode capacity recovery without native hooks')
end

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
do
    local body, status = onboardingFrame.pageBody, onboardingFrame.statusText
    local bodyMeasure, statusMeasure = body.GetStringHeight, status.GetStringHeight
    body.GetStringHeight = function() return 12 end
    status.GetStringHeight = function() return 12 end
    onboardingFrame:SetPage(4)
    onboardingFrame:SetStatusText(string.rep("Full status instructions. ", 40))
    assert(body.height > 15 and status.height > 42,
        "guide paragraphs and status must grow past stale truncated measurements")
    body.GetStringHeight, status.GetStringHeight = bodyMeasure, statusMeasure
end
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

-- Recompute the wizard center from current geometry across native window
-- changes, including delayed topology acceptance and local dialog scaling.
do
    local oldGetter, oldTimer = addon.Viewport.GetMetrics, C_Timer.After
    local oldSetScale, oldGetScale = wizardFrame.SetScale, wizardFrame.GetScale
    local pending, reads = {}, 0
    local metrics = {isSpanned = false, gameWidth = 1920, gameHeight = 1080}
    C_Timer.After = function(delay, callback)
        pending[#pending + 1] = {delay = delay, callback = callback}
    end
    addon.Viewport.GetMetrics = function() reads = reads + 1; return metrics end
    wizardFrame.SetScale = function(self, scale) self.testScale = scale end
    wizardFrame.GetScale = function(self) return self.testScale or 1 end
    wizardFrame:Show()
    local step, reason = wizardFrame.step, wizardFrame.recoveryReason
    local function centered(x, y)
        local point = wizardFrame.points.CENTER
        local scale = wizardFrame:GetScale()
        assert(point.relPoint == "BOTTOMLEFT"
            and math.abs(point.x * scale - x) < 0.001
            and math.abs(point.y * scale - y) < 0.001,
            "wizard center must match Mainhand in UIParent units")
    end
    local function resize(event)
        pending = {}
        wizardFrame.scripts.OnEvent(wizardFrame, event or "DISPLAY_SIZE_CHANGED")
        assert(#pending == 2 and pending[2].delay > 0.75,
            "resize must use bounded settling checks after the geometry debounce")
    end
    -- The immediate event can still see the ordinary client rectangle.
    resize()
    local stale = pending
    metrics = {isSpanned = true, gameWidth = 1600, gameHeight = 900,
        gameLeft = 1440, gameRight = 3040, gameBottom = 0, gameTop = 900}
    pending[2].callback()
    centered(2240, 450)
    -- Repeat span/restore without accumulating the old absolute anchor.
    for i = 1, 3 do
        metrics = {isSpanned = false, gameWidth = 1920, gameHeight = 1080}
        resize()
        local point = wizardFrame.points.CENTER
        assert(point.relPoint == "CENTER" and point.x == 0 and point.y == 0,
            "restored wizard must center on the ordinary client")
        metrics = {isSpanned = true, gameWidth = 1600, gameHeight = 900,
            gameLeft = 1440, gameRight = 3040, gameBottom = 0, gameTop = 900}
        resize()
        centered(2240, 450)
    end
    local previousReads = reads
    for _, timer in ipairs(stale) do timer.callback() end
    assert(reads == previousReads, "superseded resize callbacks must do no work")
    metrics = {isSpanned = true, gameWidth = 400, gameHeight = 600,
        gameLeft = 1600, gameRight = 2000, gameBottom = 120, gameTop = 720}
    resize("UI_SCALE_CHANGED")
    assert(wizardFrame:GetScale() < 1, "small Mainhand must fit the dialog")
    centered(1800, 420)
    assert(wizardFrame.step == step and wizardFrame.recoveryReason == reason,
        "repositioning must preserve the calibration step and recovery state")
    wizardFrame:Hide()
    previousReads = reads
    for _, timer in ipairs(pending) do timer.callback() end
    wizardFrame.scripts.OnEvent(wizardFrame, "DISPLAY_SIZE_CHANGED")
    assert(reads == previousReads, "hidden wizard must cancel queued geometry work")
    assert(not wizardFrame.scripts.OnUpdate, "centering must not add continuous polling")
    addon.Viewport.GetMetrics, C_Timer.After = oldGetter, oldTimer
    wizardFrame.SetScale, wizardFrame.GetScale = oldSetScale, oldGetScale
    wizardFrame.testScale = nil
end
print("PASS: wizard centers across span, restore, scale and delayed geometry without task changes")

do
    local detectedMetrics = addon.Viewport.GetMetrics
    addon.Viewport.GetMetrics = function(self)
        local metrics = detectedMetrics(self)
        metrics.isSpanned = true
        return metrics
    end
    addon:SetOnboardingSetupMethod("MANUAL")
    addon.HasBlizzardEditMode = function() return true end
    OffhandCharDB = {}
    local generated, reopen, reloads
    local characterOwned = false
    local ellesmereReview, importReload, importPrompts
    addon.EllesmereLayout = {
        IsAvailable = function() return true end,
        ShowPreview = function(_, direction, callback)
            assert(direction == (ellesmereReview and "ellesmere" or "fit") and not wizardFrame:IsShown(),
                "the wizard must be hidden before the visual preview opens")
            reopen = callback
            return true
        end,
        HasPendingReload = function() return importReload end,
        PromptImportReload = function()
            if not importReload then return end
            assert(not wizardFrame:IsShown(), "the reload prompt must follow setup completion")
            importPrompts = (importPrompts or 0) + 1
        end,
    }
    addon.Mainhand.GetEllesmereLayoutSource = function()
        return {generated = generated, generatedActive = true, characterOwned = characterOwned}
    end
    addon.Mainhand.PromptReload = function()
        assert(not wizardFrame:IsShown() and OffhandCharDB.wizardRecoveryStep == 6)
        reloads = (reloads or 0) + 1
    end
    addon.Wizard:Open(6)
    assert(wizardFrame.totalSteps == 6 and wizardFrame.step == 5 and not wizardFrame.pages[6]:IsShown(),
        "missing native layout must prevent Step 6")
    generated = {layoutName = "Offhand (3)"}
    addon.Wizard:Open(6)
    assert(wizardFrame.step == 5 and wizardFrame.finishBtn:GetText() == addon.L.MAINHAND_LAYOUT_CREATE,
        "a shared account layout must not bypass the character HUD creation step")
    local creates = createMainhandLayoutCount
    createMainhandLayoutResult = {true, "Offhand", 3, "active"}
    wizardFrame.finishBtn.scripts.OnClick()
    assert(createMainhandLayoutCount == creates + 1 and reloads == 1
        and not addon.Wizard:ResumeAfterReload(), "native creation must queue Step 6 for a real reload")

    generated = {layoutName = "Offhand"}
    characterOwned = true
    assert(loadfile("UI/Wizard.lua"))("Offhand", addon)
    assert(addon.Wizard:ResumeAfterReload(), "the new session must consume the saved handoff")
    wizardFrame = _G.OffhandSetupWizardFrame
    assert(wizardFrame:IsShown() and wizardFrame.step == 6 and not OffhandCharDB.wizardRecoveryStep,
        string.format("reload must open Step 6 (step %s, total %s, recovery %s)", tostring(wizardFrame.step),
            tostring(wizardFrame.totalSteps), tostring(wizardFrame.recoveryReason)))
    local previewButton
    for _, child in ipairs({wizardFrame.pages[6]:GetChildren()}) do
        if child:GetObjectType() == "Button" and child:GetText() == addon.L.ELLESMERE_HUD_VISUAL then
            previewButton = child
        end
    end
    assert(previewButton and not wizardFrame.pages[5]:IsShown())
    local transferTab = wizardFrame.progressRail.cells[6]
    assert(transferTab.text:GetText() == addon.L.SETUP_STAGE_ELLESMERE,
        "the progress tab must use the short product label")
    local rail = wizardFrame.progressRail
    local placement = rail.cells[2]
    placement.text.GetUnboundedStringWidth = function() return 142 end
    wizardFrame:LayoutStep()
    assert(placement.text.width >= 142 and placement.text.textScale == 1
        and not placement.text.wordWrap and not placement.text.nonSpaceWrap and placement.text.maxLines == 1,
        "a longer stage must get a wider tab at the normal text size")
    for index = 1, 6 do
        local cell = rail.cells[index]
        cell.text.GetUnboundedStringWidth = function() return 115 end
    end
    wizardFrame:LayoutStep()
    assert(rail:GetHeight() == 30 and transferTab.text.textScale < 1
        and transferTab.text.width >= 115 * transferTab.text.textScale
        and math.abs(transferTab.points.TOPLEFT.x + transferTab:GetWidth() - rail:GetWidth()) < 0.01,
        "long translated labels must fit on one line within the full rail")
    for index = 1, 6 do rail.cells[index].text.GetUnboundedStringWidth = nil end
    wizardFrame:LayoutStep()
    assert(transferTab.text.textScale == 1, "the next layout must restore the base tab text scale")
    previewButton.scripts.OnClick()
    assert(reopen and not wizardFrame:IsShown())
    reopen()
    assert(wizardFrame:IsShown() and wizardFrame.step == 6, "closing the preview returns to the same wizard step")
    wizardFrame.backBtn.scripts.OnClick()
    assert(wizardFrame.step == 5 and wizardFrame.finishBtn:GetText() == addon.L.BTN_NEXT)
    wizardFrame.finishBtn.scripts.OnClick()
    assert(wizardFrame.step == 6 and createMainhandLayoutCount == creates + 1 and reloads == 1,
        "a matching existing layout must advance without being recreated or reloaded")
    addon.Mainhand.GetEllesmereLayoutSource = function() return {generated = generated, generatedActive = false} end
    wizardFrame.finishBtn.scripts.OnClick()
    assert(wizardFrame:IsShown() and wizardFrame.step == 5,
        "Finish Setup must recheck that Blizzard still has the matching layout active")
    addon.Mainhand.GetEllesmereLayoutSource = function() return {generated = generated, generatedActive = true} end
    wizardFrame.finishBtn.scripts.OnClick()
    wizardFrame.finishBtn.scripts.OnClick()
    assert(not wizardFrame:IsShown() and not OffhandCharDB.wizardProgressStep
        and not OffhandCharDB.wizardRecoveryStep, "Finish Setup must be available without an import")

    ellesmereReview = true
    addon.Mainhand.GetEllesmereLayoutSource = function()
        return {generated = generated, generatedActive = true, characterOwned = true, ellesmereReview = true}
    end
    addon.Wizard:OpenHUDSetup(true)
    assert(wizardFrame.step == 6 and createMainhandLayoutCount == creates + 1 and reloads == 1,
        "enabling EllesmereUI with an active character layout must open Step 6 directly")
    previewButton.scripts.OnClick()
    reopen("inactive")
    assert(wizardFrame.finishBtn:GetText() == addon.L.BTN_FINISH and not importPrompts,
        "an inactive profile must leave Finish unchanged")
    previewButton.scripts.OnClick()
    importReload = true
    reopen("reload")
    assert(wizardFrame.finishBtn:GetText() == addon.L.ELLESMERE_HUD_FINISH_RELOAD and not importPrompts)
    wizardFrame.finishBtn.scripts.OnClick()
    assert(importPrompts == 1 and reloads == 1 and createMainhandLayoutCount == creates + 1,
        "Finish after an active import must prompt once without rewriting Blizzard's layout")
    importReload, ellesmereReview = nil, nil

    local selectPrompt
    addon.Mainhand.GetEllesmereLayoutSource = function() return {generated = generated, generatedActive = false} end
    addon.Mainhand.GetLayoutStatus = function() return {generatedName = "Other mode"} end
    addon.Mainhand.UseExistingEditModeLayout = function(_, name)
        assert(name == "Offhand", "wizard activation must target the current mode's matching layout")
        return false, "activate-api"
    end
    addon.Mainhand.PromptManualLayoutSelection = function(_, name, resumeWizard)
        selectPrompt = name == "Offhand" and resumeWizard
    end
    addon.Wizard:Open(6)
    assert(wizardFrame.step == 5, "an inactive layout must stay at the native step even without a pending flag")
    wizardFrame.finishBtn.scripts.OnClick()
    assert(selectPrompt and OffhandCharDB.wizardRecoveryStep == 6 and not wizardFrame:IsShown(),
        "the manual selection path must instruct the user to reload into Step 6")
    addon.Wizard:Open(5)
    assert(wizardFrame.finishBtn:GetText() == addon.L.BTN_NEXT,
        "reopening the wizard before manual selection must still offer layout selection first")
    print("PASS: EllesmereUI wizard preview, native reload handoff, reuse and optional completion")
end
