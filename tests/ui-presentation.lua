-- Addon-owned presentation, interaction states, scrolling and viewport fitting.
local addon = { db = { trimColor = "GOLD" } }
local function Region()
    local region = { shown = true }
    function region:SetPoint(...) self.point = { ... } end
    function region:ClearAllPoints() self.point = nil end
    function region:SetSize(w, h) self.width, self.height = w, h end
    function region:SetWidth(w) self.width = w end
    function region:SetWordWrap(wrap) self.wrap = wrap end
    function region:SetJustifyH(value) self.justify = value end
    function region:SetTextColor(...) self.color = { ... } end
    function region:SetColorTexture(...) self.color = { ... } end
    function region:SetVertexColor(...) self.color = { ... } end
    function region:SetTexture(path) self.texture = path end
    function region:SetText(text) self.text = text end
    function region:GetText() return self.text end
    function region:Show() self.shown = true end
    function region:Hide() self.shown = false end
    return region
end
local function Frame(kind, name, parent, template)
    local frame = Region()
    frame.kind, frame.name, frame.parent, frame.template = kind, name, parent, template
    frame.scripts, frame.hooks, frame.enabled = {}, {}, true
    function frame:SetScript(event, callback) self.scripts[event] = callback end
    function frame:HookScript(event, callback)
        self.hooks[event] = self.hooks[event] or {}
        table.insert(self.hooks[event], callback)
    end
    function frame:Fire(event, ...)
        if self.scripts[event] then self.scripts[event](self, ...) end
        for _, callback in ipairs(self.hooks[event] or {}) do callback(self, ...) end
    end
    function frame:SetEnabled(enabled) self.enabled = enabled; self:Fire(enabled and "OnEnable" or "OnDisable") end
    function frame:IsEnabled() return self.enabled end
    function frame:CreateFontString() return Region() end
    function frame:CreateTexture() return Region() end
    function frame:SetFontString(text) self.label = text end
    function frame:GetFontString() return self.label end
    function frame:SetBackdrop(backdrop) self.backdrop = backdrop end
    function frame:SetBackdropColor(...) self.background = { ... } end
    function frame:SetBackdropBorderColor(...) self.border = { ... } end
    function frame:SetScale(scale) self.scale = scale; self.scaleWrites = (self.scaleWrites or 0) + 1 end
    function frame:GetScale() return self.scale or 1 end
    function frame:IsShown() return self.shown end
    function frame:GetCenter()
        if self.centerX then return self.centerX / self:GetScale(), self.centerY / self:GetScale() end
    end
    function frame:SetPoint(...)
        self.point = { ... }
        if self.point[1] == "CENTER" and self.point[3] == "BOTTOMLEFT" then
            self.centerX, self.centerY = self.point[4] * self:GetScale(), self.point[5] * self:GetScale()
        end
    end
    function frame:GetWidth() return self.width or 0 end
    function frame:GetHeight() return self.height or 0 end
    function frame:GetScrollChild() return self.child end
    function frame:SetVerticalScroll(offset) self.offset = offset end
    function frame:GetVerticalScroll() return self.offset or 0 end
    function frame:SetValue(value) self.value = value end
    function frame:SetMinMaxValues(low, high) self.low, self.high = low, high end
    function frame:EnableMouseWheel(enabled) self.wheel = enabled end
    function frame:SetThumbTexture(texture) self.thumbPath = texture end
    function frame:GetThumbTexture() return self.thumb end
    function frame:GetName() return self.name end
    for _, method in ipairs({ "SetNormalFontObject", "SetHighlightFontObject", "SetDisabledFontObject",
        "SetPushedTextOffset", "SetFontObject", "SetTextInsets", "SetAutoFocus", "LockHighlight", "UnlockHighlight" }) do
        frame[method] = function() end
    end
    return frame
end
CreateFrame = Frame
local nativeFactory = CreateFrame
UIParent = Frame("Frame")
UIParent:SetSize(1920, 1080)
assert(loadfile("UI/Themes.lua"))("Offhand", addon)
assert(loadfile("UI/Controls.lua"))("Offhand", addon)
local ui = addon.UIControls
local button = ui.CreateFrame("Button", nil, UIParent, "UIPanelButtonTemplate")
assert(CreateFrame == nativeFactory, "presentation must never replace the global frame factory")
assert(button.template == "BackdropTemplate" and button:GetFontString().wrap,
    "addon buttons must use flat addon-owned artwork with wrapping labels")
assert(not button.selectionMark.shown)
ui.SetChoiceSelected(button, true)
assert(button.enabled and button.selected and button.selectionMark.shown,
    "selection must have a non-color marker without disabling the choice")
ui.SetChoiceSelected(button, false)
button:Fire("OnEnter")
local hoverShade = button.background[1]
assert(button.uiHover and button.border[1] > button.border[2])
button:Fire("OnMouseDown")
assert(button.background[1] < hoverShade, "press must visibly differ from hover")
button:Fire("OnMouseUp")
assert(button.background[1] == hoverShade)
button:SetEnabled(false)
assert(button:GetFontString().color[1] < 0.5 and button.border[1] == 0.2,
    "disabled actions must lose their active styling")
button:Fire("OnHide")
assert(not button.uiHover and not button.uiPressed, "hidden controls must discard transient state")
ui.SetButtonTextColor(button, 0.2, 0.8, 0.4)
assert(button:GetFontString().color[1] < 0.5, "semantic text colors must not override disabled styling")
button:SetEnabled(true)
button:Fire("OnEnter")
button:Fire("OnMouseDown")
button:Fire("OnMouseUp")
button:Fire("OnLeave")
assert(button:GetFontString().color[1] == 0.2 and button:GetFontString().color[2] == 0.8,
    "hover and press states must retain a palette or custom-color cue")
local close = ui.CreateFrame("Button", nil, UIParent, "UIPanelCloseButton")
assert(close.template == "UIPanelCloseButton" and not close.backdrop,
    "native close controls and unrequested templates must remain untouched")
local input = ui.CreateFrame("EditBox", nil, UIParent, "InputBoxTemplate")
-- Application handlers must coexist with focus styling through HookScript.
local focusEvents = 0
input:SetScript("OnEditFocusGained", function() focusEvents = focusEvents + 1 end)
input:Fire("OnEditFocusGained")
assert(focusEvents == 1 and input.uiFocus and input.border[1] > 0.8)
input:Fire("OnEditFocusLost")
assert(not input.uiFocus and input.border[1] == 0.2)
addon.isLegacyWrath = true
CreateFrame = function(...)
    local legacyFrame = Frame(...)
    function legacyFrame:CreateTexture()
        local texture = Region()
        texture.SetColorTexture = nil
        return texture
    end
    return legacyFrame
end
local legacy = ui.CreateFrame("Button", nil, UIParent, "UIPanelButtonTemplate")
assert(legacy.template == nil and legacy.backdrop,
    "legacy clients must not require BackdropTemplate")
ui.SetChoiceSelected(legacy, true)
assert(legacy.selectionMark and legacy.selectionMark.shown,
    "legacy selection must retain its non-color cue without SetColorTexture")
CreateFrame = nativeFactory
addon.db.theme = "PITCH_BLACK"
ui.StyleSurface(input, "input")
assert(input.background[1] == 0 and input.background[2] == 0 and input.background[3] == 0)
addon.db.trimColor, addon.db.customTrimColor = "CUSTOM", { r = 0.2, g = 0.8, b = 0.4 }
ui.SetChoiceSelected(button, true)
ui.RefreshStyles()
assert(math.abs(button.border[2] - 0.68) < 0.001, "custom accents must refresh existing widgets")
ui.SetInputFocused(input, true)
ui.RefreshStyles()
assert(input.uiFocus and math.abs(input.border[2] - 0.68) < 0.001,
    "numeric focus borders must follow custom accents and survive theme refresh")
ui.SetInputFocused(input, false)
assert(input.border[1] == 0.2)
local slider = Frame("Slider")
slider.thumb = Region()
ui.StyleSlider(slider)
assert(slider.thumb.texture == "Interface\\Buttons\\WHITE8X8" and slider.thumb.width == 10)
local scroll = Frame("ScrollFrame")
scroll:SetSize(662, 400)
scroll.child = Frame("Frame"); scroll.child:SetSize(662, 1200)
scroll.ScrollBar = Frame("Slider"); scroll.ScrollBar.thumb = Region()
ui.EnableWheelScroll(scroll)
assert(scroll.wheel and scroll.ScrollBar.thumb.width == 8)
assert(ui.SetScrollOffset(scroll, 10000) == 800 and scroll.ScrollBar.value == 800)
assert(scroll.ScrollBar.high == 800, "restored offsets must not use a previous page's scrollbar range")
scroll:Fire("OnMouseWheel", 1)
assert(scroll.offset == 760 and scroll.ScrollBar.value == 760)
scroll:Fire("OnMouseWheel", -100)
assert(scroll.offset == 800)
assert(ui.SetScrollOffset(scroll, -20) == 0)
scroll.child:SetSize(662, 200)
assert(ui.SetScrollOffset(scroll, 300) == 0, "short pages must not scroll beyond content")
local dialog = Frame("Frame"); dialog:SetSize(922, 732)
local scale = ui.FitDialog(dialog, { gameWidth = 800, gameHeight = 600 })
assert(scale < 1 and 922 * scale <= 768 and 732 * scale <= 568,
    "dialog must fit within the game viewport with an edge margin")
assert(ui.FitDialog(dialog, { gameWidth = 2560, gameHeight = 1440 }) == 1,
    "fitting must reset a previous reduction and never enlarge a dialog")
assert(dialog.scale == 1, "resetting fit must write the full scale back to the dialog")
assert(ui.FitDialog(dialog, nil) == 1, "single-screen recovery must use UIParent dimensions")
local fitHooks, layouts = 0, 0
addon.ApplyFullLayout = function() layouts = layouts + 1 end
hooksecurefunc = function(owner, method, callback)
    assert(owner == addon and method == "ApplyFullLayout", "only addon layout may be hooked")
    fitHooks = fitHooks + 1
    local original = owner[method]
    owner[method] = function(...) original(...); callback(...) end
end
local fitMetrics = { gameWidth = 800, gameHeight = 600 }
addon.Viewport = { GetMetrics = function() return fitMetrics end }
dialog.centerX, dialog.centerY = 700, 400
local hidden = Frame("Frame"); hidden:SetSize(922, 732); hidden:Hide()
ui.RegisterDialog(dialog)
ui.RegisterDialog(dialog)
ui.RegisterDialog(hidden)
assert(fitHooks == 1, "registering dialogs must never multiply the layout hook")
addon:ApplyFullLayout()
assert(layouts == 1 and dialog.scale < 1 and hidden.scaleWrites == nil,
    "layout changes must refit only visible registered dialogs")
assert(math.abs(dialog.centerX - 700) < 0.001 and math.abs(dialog.centerY - 400) < 0.001,
    "refitting must preserve the dialog's UIParent-space center")
local scaleWrites = dialog.scaleWrites
addon:ApplyFullLayout()
assert(dialog.scaleWrites == scaleWrites and dialog.scripts.OnUpdate == nil,
    "unchanged fits must not rewrite scale or install polling")
fitMetrics = { gameWidth = 1920, gameHeight = 1080 }
addon:ApplyFullLayout()
assert(dialog.scale == 1 and math.abs(dialog.centerX - 700) < 0.001,
    "restoring the viewport must recover full dialog scale without center drift")
print("PASS: addon-owned UI styling, interaction states, wheel limits, scrollbar sync and viewport fitting")
