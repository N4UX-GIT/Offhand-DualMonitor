StaticPopupDialogs = {}
-- ============================================================================
-- Offhand Slider Stepping, Fixed Text Entry & Drag Debounce Unit Tests
-- ============================================================================

SlashCmdList = {}
local frames = {}
local registeredEvents = {}

local function makeMockFrame(name, w, h)
    local f = {
        name = name,
        w = w or 100,
        h = h or 100,
        points = {},
        scripts = {},
        shown = true,
        val = 0,
        minVal = 0,
        maxVal = 1,
        step = 0.01,
        text = "",
        enabled = true,
    }
    table.insert(frames, f)
    function f:SetSize(width, height) self.w = width; self.h = height end
    function f:GetWidth() return self.w end
    function f:GetHeight() return self.h end
    function f:SetHeight(height) self.h = height end
    function f:SetWidth(width) self.w = width end
    function f:SetScrollChild(c) self.scrollChild = c end
    function f:SetVerticalScroll(v) self.verticalScroll = v end
    function f:SetPoint(pt, relTo, relPt, x, y)
        table.insert(self.points, { point = pt, relTo = relTo, relPt = relPt, x = x, y = y })
    end
    function f:ClearAllPoints() self.points = {} end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:IsShown() return self.shown end
    function f:SetShown(val) self.shown = val end
    function f:SetScript(scriptName, fn) self.scripts[scriptName] = fn end
    function f:SetMovable() end
    function f:SetClampedToScreen() end
    function f:RegisterForDrag() end
    function f:EnableMouse() end
    function f:StartMoving() end
    function f:StopMovingOrSizing() end
    function f:SetBackdrop(bd) self.backdrop = bd end
    function f:SetBackdropColor(r, g, b, a) self.bgColor = { r = r, g = g, b = b, a = a } end
    function f:SetBackdropBorderColor(r, g, b, a) self.borderColor = { r = r, g = g, b = b, a = a } end
    function f:SetFrameStrata() end
    function f:SetFrameLevel() end
    function f:SetText(t) self.text = t end
    function f:GetFontString()
        if not f._fontString then f._fontString = { SetWidth = function() end, SetWordWrap = function() end, SetTextColor = function() end } end
        return f._fontString
    end
    function f:GetText() return self.text or "" end
    function f:SetTextColor() end
    function f:SetAutoFocus() end
    function f:SetNumeric() end
    function f:SetMaxLetters() end
    function f:ClearFocus() self.hasFocus = false end
    function f:HasFocus() return self.hasFocus or false end
    function f:HighlightText() end
    function f:SetFontObject() end
    function f:SetJustifyH() end
    function f:SetOrientation() end
    function f:SetMinMaxValues(min, max) self.minVal, self.maxVal = min, max end
    function f:SetValueStep(step) self.step = step end
    function f:SetObeyStepOnDrag() end
    function f:SetValue(v)
        self.val = v
        if self.scripts["OnValueChanged"] then self.scripts["OnValueChanged"](self, v) end
    end
    function f:GetValue() return self.val end
    function f:SetThumbTexture(t) self.thumb = t end
    function f:SetChecked(c) self.checked = c end
    function f:GetChecked() return self.checked end
    function f:SetEnabled(e) self.enabled = e end
    function f:IsEnabled() return self.enabled end
    function f:CreateFontString()
        return {
            points = {},
            text = "",
            SetPoint = function(s, pt, rel, relPt, x, y) table.insert(s.points, { point = pt, rel = rel, relPt = relPt, x = x, y = y }) end,
            SetText = function(self, t) self.text = t end,
            GetText = function(self) return self.text or "" end,
            SetTextColor = function() end,
            SetJustifyH = function() end,
            SetWidth = function() end,
        }
    end
    function f:CreateTexture()
        return {
            SetAllPoints = function() end,
            SetColorTexture = function() end,
            SetTexture = function(self, t) self.texture = t end,
            SetVertexColor = function(self, r, g, b, a) self.vertexColor = { r = r, g = g, b = b, a = a } end,
            SetSize = function(self, w, h) self.w = w; self.h = h end,
            SetPoint = function() end,
        }
    end
    function f:RegisterEvent(evt) registeredEvents[evt] = true end
    if name then _G[name] = f end
    return f
end

CreateFrame = function(frameType, name, parent, template)
    local f = makeMockFrame(name or ("mock_" .. tostring(#frames + 1)), 200, 200)
    f.type = frameType
    f.parent = parent
    f.template = template
    return f
end

UIParent = CreateFrame("Frame", "UIParent")
UIParent:SetSize(4000, 2560)
function UIParent:GetEffectiveScale() return 1.0 end
function UIParent:GetScale() return 1.0 end
function UIParent:SetScale(s) self.scale = s end
function UIParent:GetLeft() return 0 end
function UIParent:GetRight() return 4000 end
function UIParent:GetTop() return 2560 end
function UIParent:GetBottom() return 0 end

InCombatLockdown = function() return false end
strtrim = function(s) return (s:gsub("^%s*(.-)%s*$", "%1")) end
strsplit = function(delim, str)
    local t = {}
    for part in string.gmatch(str, "[^" .. delim .. "]+") do table.insert(t, part) end
    return unpack(t)
end

local timerCallbacks = {}
C_Timer = {
    After = function(sec, cb)
        table.insert(timerCallbacks, cb)
    end,
    NewTimer = function(sec, cb) return { Cancel = function() end } end,
}

GetPhysicalScreenSize = function() return 4000, 2560 end
GetScreenWidth = function() return 4000 end
GetScreenHeight = function() return 2560 end
GetBuildInfo = function() return "1.15.5", "58238", "Jan 1 2025", 11505 end
hooksecurefunc = function(t, name, fn) end
UISpecialFrames = {}

-- Load Offhand modules
local addon = { modules = {} }
assert(loadfile("Core/Init.lua"))("Offhand", addon)
assert(loadfile("Core/Config.lua"))("Offhand", addon)
assert(loadfile("Core/Viewport.lua"))("Offhand", addon)
assert(loadfile("Core/SeamRedirect.lua"))("Offhand", addon)
assert(loadfile("Core/Canvas.lua"))("Offhand", addon)
assert(loadfile("Locales/enUS.lua"))("Offhand", addon)
assert(loadfile("UI/Themes.lua"))("Offhand", addon)
assert(loadfile("UI/Options.lua"))("Offhand", addon)
assert(loadfile("UI/Wizard.lua"))("Offhand", addon)

local layoutAppliedCount = 0
addon.ApplyFullLayout = function()
    layoutAppliedCount = layoutAppliedCount + 1
end

addon.db = {
    enabled = true,
    layoutPreset = "PORTRAIT_LEFT_LANDSCAPE_RIGHT",
    deckWidthRatio = 0.36,
    primaryPosition = "RIGHT",
    aspectRatioMode = "16_9",
    hudScale = 0.70,
    theme = "CLASSIC",
    trimColor = "GOLD",
    canvasColor = "SOLID_BLACK",
    canvasAlpha = 0.95,
    bezelGap = 0,
    workspaceMapScale = 1.0,
    gameBottomPixels = 0,
}

-- ============================================================================
-- 1. Test Offhand.ParseSliderInput
-- ============================================================================
print("--> Testing Offhand.ParseSliderInput smart parser...")
assert(addon.ParseSliderInput ~= nil, "addon.ParseSliderInput must exist")

-- UI Scale parsing (min 0.25, max 1.25, step 0.01, format "%.0f%%")
assert(math.abs(addon:ParseSliderInput("70%", 0.25, 1.25, 0.01, "%.0f%%") - 0.70) < 0.0001, "70% must parse to 0.70")
assert(math.abs(addon:ParseSliderInput("70", 0.25, 1.25, 0.01, "%.0f%%") - 0.70) < 0.0001, "70 must parse to 0.70")
assert(math.abs(addon:ParseSliderInput("0.70", 0.25, 1.25, 0.01, "%.0f%%") - 0.70) < 0.0001, "0.70 must parse to 0.70")
assert(math.abs(addon:ParseSliderInput("0.7", 0.25, 1.25, 0.01, "%.0f%%") - 0.70) < 0.0001, "0.7 must parse to 0.70")
assert(math.abs(addon:ParseSliderInput("25%", 0.25, 1.25, 0.01, "%.0f%%") - 0.25) < 0.0001, "25% must parse to 0.25")
assert(math.abs(addon:ParseSliderInput("125%", 0.25, 1.25, 0.01, "%.0f%%") - 1.25) < 0.0001, "125% must parse to 1.25")
-- Clamping:
assert(math.abs(addon:ParseSliderInput("10%", 0.25, 1.25, 0.01, "%.0f%%") - 0.25) < 0.0001, "Values below 0.25 must clamp to 0.25")
assert(math.abs(addon:ParseSliderInput("150%", 0.25, 1.25, 0.01, "%.0f%%") - 1.25) < 0.0001, "Values above 1.25 must clamp to 1.25")

-- Seam parsing (min 0.15, max 0.80, step 0.005, format "%.1f%%")
assert(math.abs(addon:ParseSliderInput("36.0%", 0.15, 0.80, 0.005, "%.1f%%") - 0.36) < 0.0001, "36.0% must parse to 0.36")
assert(math.abs(addon:ParseSliderInput("36%", 0.15, 0.80, 0.005, "%.1f%%") - 0.36) < 0.0001, "36% must parse to 0.36")
assert(math.abs(addon:ParseSliderInput("36", 0.15, 0.80, 0.005, "%.1f%%") - 0.36) < 0.0001, "36 must parse to 0.36")
assert(math.abs(addon:ParseSliderInput("0.36", 0.15, 0.80, 0.005, "%.1f%%") - 0.36) < 0.0001, "0.36 must parse to 0.36")
assert(math.abs(addon:ParseSliderInput("50.5%", 0.15, 0.80, 0.005, "%.1f%%") - 0.505) < 0.0001, "50.5% must parse to 0.505")

-- Map Scale parsing (min 0.50, max 2.50, step 0.05, format "%.0f%%")
assert(math.abs(addon:ParseSliderInput("150%", 0.50, 2.50, 0.05, "%.0f%%") - 1.50) < 0.0001, "150% must parse to 1.50")
assert(math.abs(addon:ParseSliderInput("150", 0.50, 2.50, 0.05, "%.0f%%") - 1.50) < 0.0001, "150 must parse to 1.50")
assert(math.abs(addon:ParseSliderInput("1.5", 0.50, 2.50, 0.05, "%.0f%%") - 1.50) < 0.0001, "1.5 must parse to 1.50")

-- Bezel Gap parsing (min 0, max 100, step 2, format "%d px")
assert(math.abs(addon:ParseSliderInput("20 px", 0, 100, 2, "%d px") - 20) < 0.0001, "20 px must parse to 20")
assert(math.abs(addon:ParseSliderInput("20", 0, 100, 2, "%d px") - 20) < 0.0001, "20 must parse to 20")
assert(math.abs(addon:ParseSliderInput("21", 0, 100, 2, "%d px") - 22) < 0.0001, "21 with step 2 must round to 22")

-- Invalid input
assert(addon:ParseSliderInput("notanumber", 0, 100, 1, "%d") == nil, "Invalid strings must return nil")
assert(addon:ParseSliderInput("", 0, 100, 1, "%d") == nil, "Empty strings must return nil")
assert(addon:ParseSliderInput(nil, 0, 100, 1, "%d") == nil, "Nil input must return nil")

-- ============================================================================
-- 2. Test Options Panel Sliders (Single-Click Steppers & EditBox)
-- ============================================================================
print("--> Testing Options panel sliders...")
local configFrame = addon.Options:CreateFloatingPanel()
assert(configFrame ~= nil, "Options floating panel must exist")

local sliders = {}
for _, f in ipairs(frames) do
    if f.type == "Slider" and f.btnMinus and f.btnPlus and f.editBox then
        table.insert(sliders, f)
    end
end
assert(#sliders >= 5, string.format("Must have at least 5 enhanced sliders with steppers and editBox, found %d", #sliders))

local hudSlider = nil
for _, s in ipairs(sliders) do
    if s.title and s.title:GetText() and s.title:GetText() == addon.L["SLIDER_HUD_SCALE"] then
        hudSlider = s
        break
    end
end
assert(hudSlider ~= nil, "hudSlider must be found")
assert(hudSlider.btnMinus ~= nil, "hudSlider must have btnMinus")
assert(hudSlider.btnPlus ~= nil, "hudSlider must have btnPlus")
assert(hudSlider.editBox ~= nil, "hudSlider must have editBox")

hudSlider:SetValue(0.70)
assert(math.abs(addon.db.hudScale - 0.70) < 0.001, "Initial hudScale must be 0.70")
assert(hudSlider.editBox:GetText():find("70%%"), "editBox must show 70%")

layoutAppliedCount = 0
hudSlider.btnMinus.scripts["OnClick"]()
assert(math.abs(addon.db.hudScale - 0.69) < 0.001, "Single click on [-] must decrement by 1% (0.69)")
assert(hudSlider.editBox:GetText():find("69%%"), "editBox must update to 69%")
assert(layoutAppliedCount > 0, "Single-click step must trigger ApplyFullLayout immediately")

layoutAppliedCount = 0
hudSlider.btnPlus.scripts["OnClick"]()
assert(math.abs(addon.db.hudScale - 0.70) < 0.001, "Single click on [+] must increment by 1% (0.70)")
assert(hudSlider.editBox:GetText():find("70%%"), "editBox must update to 70%")
assert(layoutAppliedCount > 0, "Single-click step must trigger ApplyFullLayout immediately")

layoutAppliedCount = 0
hudSlider.editBox:SetText("85%")
hudSlider.editBox.scripts["OnEnterPressed"](hudSlider.editBox)
assert(math.abs(addon.db.hudScale - 0.85) < 0.001, "Typing 85% into EditBox must set hudScale to 0.85")
assert(hudSlider.editBox:GetText():find("85%%"), "editBox must format to 85%")
assert(layoutAppliedCount > 0, "Enter on EditBox must trigger ApplyFullLayout immediately")

hudSlider.editBox:SetText("65")
hudSlider.editBox.scripts["OnEnterPressed"](hudSlider.editBox)
assert(math.abs(addon.db.hudScale - 0.65) < 0.001, "Typing 65 into EditBox must set hudScale to 0.65")
assert(hudSlider.editBox:GetText():find("65%%"), "editBox must format to 65%")

hudSlider.editBox:SetText("0.75")
hudSlider.editBox.scripts["OnEnterPressed"](hudSlider.editBox)
assert(math.abs(addon.db.hudScale - 0.75) < 0.001, "Typing 0.75 into EditBox must set hudScale to 0.75")
assert(hudSlider.editBox:GetText():find("75%%"), "editBox must format to 75%")

layoutAppliedCount = 0
timerCallbacks = {}
hudSlider.scripts["OnMouseDown"](hudSlider, "LeftButton")
assert(hudSlider._isCustomDrag == true, "Mouse down must initiate _isCustomDrag state")

-- During custom drag, OnValueChanged is a no-op (OnUpdate drives display instead)
-- The editBox is updated by the OnUpdate loop, not by OnValueChanged
-- We only verify that layout is NOT applied synchronously
hudSlider.scripts["OnValueChanged"](hudSlider, 0.76)
hudSlider.scripts["OnValueChanged"](hudSlider, 0.77)
hudSlider.scripts["OnValueChanged"](hudSlider, 0.78)
assert(layoutAppliedCount == 0, "ApplyFullLayout must NOT run during drag (OnValueChanged is skipped)")

hudSlider.scripts["OnMouseUp"](hudSlider, "LeftButton")
assert(hudSlider._isCustomDrag == false or hudSlider._isCustomDrag == nil, "Mouse up must end _isCustomDrag state")
assert(layoutAppliedCount == 1, "Mouse up must apply layout exactly once")

-- ============================================================================
-- 3. Test Wizard Sliders (Seam & Scale EditBoxes and Stepping)
-- ============================================================================
print("--> Testing Wizard sliders & text entry...")
local wiz = addon.Wizard:CreateFrame()
assert(wiz ~= nil, "Wizard frame must exist")
assert(wiz.seamSlider ~= nil, "Wizard must have seamSlider")
assert(wiz.scaleSlider ~= nil, "Wizard must have scaleSlider")
assert(wiz.seamEditBox ~= nil, "Wizard must have seamEditBox")
assert(wiz.scaleEditBox ~= nil, "Wizard must have scaleEditBox")
assert(wiz.seamValText ~= nil, "Wizard must have seamValText")
assert(wiz.scaleValText ~= nil, "Wizard must have scaleValText")

wiz.seamEditBox:SetText("45%")
wiz.seamEditBox.scripts["OnEnterPressed"](wiz.seamEditBox)
assert(math.abs(addon.db.deckWidthRatio - 0.45) < 0.001, "Wizard seamEditBox must set deckWidthRatio to 0.45")
assert(wiz.seamValText:GetText():find("45%.0%%"), "seamValText must reflect 45.0%")

wiz.scaleEditBox:SetText("70%")
wiz.scaleEditBox.scripts["OnEnterPressed"](wiz.scaleEditBox)
assert(math.abs(addon.db.hudScale - 0.70) < 0.001, "Wizard scaleEditBox must set hudScale to 0.70")
assert(wiz.scaleValText:GetText():find("70%%"), "scaleValText must reflect 70%")

layoutAppliedCount = 0
wiz.scaleSlider.scripts["OnMouseDown"](wiz.scaleSlider, "LeftButton")
assert(wiz.scaleSlider._isCustomDrag == true, "Wizard scaleSlider mouse down must set _isCustomDrag")
-- During custom drag, OnValueChanged is a no-op; OnUpdate drives display
wiz.scaleSlider.scripts["OnValueChanged"](wiz.scaleSlider, 0.72)
wiz.scaleSlider.scripts["OnValueChanged"](wiz.scaleSlider, 0.73)
assert(layoutAppliedCount == 0, "Wizard slider drag must not apply layout until mouse up")

wiz.scaleSlider.scripts["OnMouseUp"](wiz.scaleSlider, "LeftButton")
assert(wiz.scaleSlider._isCustomDrag == false or wiz.scaleSlider._isCustomDrag == nil, "Wizard scaleSlider mouse up must clear _isCustomDrag")
assert(layoutAppliedCount == 1, "Wizard scaleSlider mouse up must apply layout")

print("PASS: Universal slider manual stepping ([-]/[+]), interactive text entry (EditBox), smart parser, and drag debounce verified!")
