StaticPopupDialogs = {}
-- Test Canvas themes, real-time opacity updates, padded headers, and themed slider handles
local addon = {
    modules = {},
    db = {
        enabled = true,
        seamRedirect = true,
        theme = "CLASSIC",
        trimColor = "GOLD",
        canvasColor = "CHARCOAL",
        canvasAlpha = 0.95,
        savedWorkspacePositions = {}
    }
}

UIParent = {
    GetEffectiveScale = function() return 1 end,
    GetWidth = function() return 4000 end,
    GetHeight = function() return 2560 end,
    GetLeft = function() return 0 end,
    GetRight = function() return 4000 end,
    GetTop = function() return 2560 end,
    GetBottom = function() return 0 end,
    GetScale = function() return 1 end,
    SetScale = function() end,
}

local metrics = {
    gameLeft = 1440, gameRight = 4000, gameBottom = 0, gameTop = 1440,
    gameWidth = 2560, gameHeight = 1440, deckWidth = 1440, hudScale = 1,
    screenWidth = 4000, screenHeight = 2560, isSpanned = true,
}
addon.Viewport = { GetMetrics = function() return metrics end }
addon.Print = function() end
addon.ApplyFullLayout = function() end
InCombatLockdown = function() return false end
hooksecurefunc = function() end
UISpecialFrames = {}

local frames = {}
local function makeMockFrame(name, w, h)
    local f = {
        name = name,
        w = w or 100,
        h = h or 100,
        points = {},
        scripts = {},
        shown = true,
        backdrop = nil,
        bgColor = nil,
        borderColor = nil,
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
    function f:GetText() return self.text or "" end
    function f:SetTextColor() end
    function f:SetAutoFocus() end
    function f:SetNumeric() end
    function f:SetMaxLetters() end
    function f:ClearFocus() end
    function f:SetOrientation() end
    function f:SetMinMaxValues() end
    function f:SetValueStep() end
    function f:SetObeyStepOnDrag() end
    function f:SetValue(v) self.val = v end
    function f:SetThumbTexture(t) self.thumb = t end
    function f:SetChecked(c) self.checked = c end
    function f:GetChecked() return self.checked end
    function f:SetEnabled(e) self.enabled = e end
    function f:CreateFontString()
        return {
            SetPoint = function() end,
            SetText = function(self, t) self.text = t end,
            GetText = function(self) return self.text end,
            SetTextColor = function() end,
            SetJustifyH = function() end,
            SetWidth = function(self, width) self.width = width end,
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
    return f
end

CreateFrame = function(frameType, name, parent, template)
    local f = makeMockFrame(name or ("mock_" .. tostring(#frames + 1)), 200, 200)
    f.template = template
    f.parent = parent
    return f
end

BackdropTemplateMixin = {}
Mixin = function(t, m) end

-- Load Themes and Options
local themesChunk = assert(loadfile("UI/Themes.lua"))
themesChunk("Offhand", addon)

local optionsChunk = assert(loadfile("UI/Options.lua"))
optionsChunk("Offhand", addon)

-- 1. Test Canvas Palettes and ApplyCanvasTheme
local mockCanvas = makeMockFrame("OffhandCanvasFrame", 1440, 2560)
_G["OffhandCanvasFrame"] = mockCanvas
addon.canvas = mockCanvas

addon.db.canvasColor = "TINKER_SLATE"
addon.db.canvasAlpha = 0.80
addon.Themes:ApplyCanvasTheme(mockCanvas)

assert(mockCanvas.backdrop ~= nil, "Canvas must have a backdrop applied")
assert(mockCanvas.backdrop.tile == true, "Tinker slate canvas must tile")
assert(mockCanvas.backdrop.tileSize == 64, "Canvas tile size must be 64px")
assert(mockCanvas.bgColor ~= nil, "Canvas must have bgColor")
assert(math.abs(mockCanvas.bgColor.a - 0.80) < 0.01, "Canvas opacity must match canvasAlpha (0.80)")
assert(mockCanvas.bgColor.r > 0.08, "Tinker slate r must be vibrant and distinct (> 0.08)")

-- Change to Classic Stone and verify
addon.db.canvasColor = "CLASSIC_STONE"
addon.db.canvasAlpha = 0.50
addon.Themes:ApplyCanvasTheme(mockCanvas)
assert(mockCanvas.backdrop.bgFile:find("UI%-DialogBox%-Background"), "Classic Stone canvas must use Blizzard Dialog Background")
assert(math.abs(mockCanvas.bgColor.a - 0.50) < 0.01, "Canvas opacity must update to 0.50")

-- Change to Pure Black and verify
addon.db.canvasColor = "PURE_BLACK"
addon.db.canvasAlpha = 1.00
addon.Themes:ApplyCanvasTheme(mockCanvas)
assert(mockCanvas.backdrop.tile == false, "Pure Black canvas must not tile")
assert(mockCanvas.bgColor.r == 0 and mockCanvas.bgColor.g == 0 and mockCanvas.bgColor.b == 0, "Pure Black must be 0,0,0")

-- Verify Active Theme Border applied to Workspace Canvas
-- A. Classic Warcraft theme with Gold trim
addon.db.theme = "CLASSIC"
addon.db.trimColor = "GOLD"
addon.db.canvasColor = "CLASSIC_STONE"
addon.Themes:ApplyCanvasTheme(mockCanvas)
assert(mockCanvas.backdrop.edgeFile == "Interface\\DialogFrame\\UI-DialogBox-Border", "Classic theme must apply UI-DialogBox-Border to workspace canvas")
assert(mockCanvas.backdrop.edgeSize == 32, "Classic theme edgeSize must be 32")
assert(mockCanvas.borderColor.r == 1.0 and mockCanvas.borderColor.g == 1.0 and mockCanvas.borderColor.b == 1.0, "Classic Gold trim must keep untainted 1,1,1 border color")

-- B. Blizzard Slate theme with Silver trim
addon.db.theme = "BLIZZARD_SLATE"
addon.db.trimColor = "SILVER"
addon.Themes:ApplyCanvasTheme(mockCanvas)
assert(mockCanvas.backdrop.edgeFile == "Interface\\Tooltips\\UI-Tooltip-Border", "Blizzard Slate theme must apply UI-Tooltip-Border to workspace canvas")
assert(mockCanvas.backdrop.edgeSize == 14, "Blizzard Slate edgeSize must be 14")
local pals = addon.Themes:GetColorPalettes()
assert(math.abs(mockCanvas.borderColor.r - pals.SILVER.r) < 0.01, "Blizzard Slate border color must match Silver trim")

-- C. Forged Brass theme with Brass trim
addon.db.theme = "GNOMISH_TINKER"
addon.db.trimColor = "TINKER_BRASS"
addon.Themes:ApplyCanvasTheme(mockCanvas)
assert(mockCanvas.backdrop.edgeFile == "Interface\\DialogFrame\\UI-DialogBox-Border", "Forged Brass must use DialogBox-Border")
assert(math.abs(mockCanvas.borderColor.r - pals.TINKER_BRASS.r) < 0.01, "Forged Brass border color must match Tinker Brass trim")

-- 2. Test BayHeader Padded Dimensions and Anchoring
local mockParent = makeMockFrame("MockParent", 720, 650)
local header = addon.Themes:CreateBayHeader(mockParent, "TEST PADDED HEADER")
assert(header:GetHeight() == 36, "BayHeader height must be 36px for padded breathing room")
local pt = header.points[1]
assert(pt.x == 14 and pt.y == -14, "BayHeader TOPLEFT must be indented (14, -14)")

-- 3. Test Options Panel and Themed Slider Thumbs
local configFrame = addon.Options:CreateFloatingPanel()
assert(configFrame ~= nil, "Options floating panel must be created")
assert(configFrame:GetHeight() == 732, "Options floating panel height must be 732px")

-- Change trim color to CYAN_GLOW and check slider thumb tint
addon.db.trimColor = "CYAN_GLOW"
addon.Options:UpdateCardThemes()

local foundThemedSlider = false
for _, f in ipairs(frames) do
    if f.thumb and f.thumb.vertexColor then
        foundThemedSlider = true
        local vc = f.thumb.vertexColor
        assert(vc.r == 0.0 and vc.b == 1.0, "CYAN_GLOW trim must tint slider thumbs to cyan")
    end
end
assert(foundThemedSlider, "Slider thumbs must be registered and themed")

-- Change trim color to GOLD and verify
addon.db.trimColor = "GOLD"
addon.Options:UpdateCardThemes()
for _, f in ipairs(frames) do
    if f.thumb and f.thumb.vertexColor then
        local vc = f.thumb.vertexColor
        assert(vc.r == 1.0 and vc.g == 0.82 and vc.b == 0.0, "GOLD trim must tint slider thumbs to Blizzard gold")
    end
end

-- 4. Test Custom Trim Color
addon.db.trimColor = "CUSTOM"
addon.db.customTrimColor = { r = 0.90, g = 0.10, b = 0.50 }
addon.Options:UpdateCardThemes()
for _, f in ipairs(frames) do
    if f.thumb and f.thumb.vertexColor then
        local vc = f.thumb.vertexColor
        assert(math.abs(vc.r - 0.90) < 0.01 and math.abs(vc.g - 0.10) < 0.01 and math.abs(vc.b - 0.50) < 0.01,
            "CUSTOM trim must tint slider thumbs to user-defined RGB")
    end
end

-- 5. Test Custom Canvas Color
addon.db.canvasColor = "CUSTOM"
addon.db.customCanvasColor = { r = 0.35, g = 0.45, b = 0.55 }
addon.db.canvasAlpha = 0.88
addon.Themes:ApplyCanvasTheme(mockCanvas)
assert(mockCanvas.bgColor ~= nil, "Custom canvas must have bgColor")
assert(math.abs(mockCanvas.bgColor.r - 0.35) < 0.01, "Custom canvas r must match 0.35")
assert(math.abs(mockCanvas.bgColor.g - 0.45) < 0.01, "Custom canvas g must match 0.45")
assert(math.abs(mockCanvas.bgColor.b - 0.55) < 0.01, "Custom canvas b must match 0.55")
assert(math.abs(mockCanvas.bgColor.a - 0.88) < 0.01, "Custom canvas alpha must match 0.88")

print("PASS: Canvas themes, custom color pickers, live opacity, padded header (36px), and themed slider handles verified!")
