local addon = {
    db = {
        userMediaEnabled = true,
        userMediaFitMode = "PACKAGE",
    },
}

local packageMetadata = {
    ["X-Offhand-Media-Schema"] = "2",
    ["X-Offhand-Generator-Version"] = "3",
    ["X-Offhand-Image-Width"] = "200",
    ["X-Offhand-Image-Height"] = "100",
    ["X-Offhand-Texture-Width"] = "256",
    ["X-Offhand-Texture-Height"] = "128",
    ["X-Offhand-Suggested-Fit"] = "FILL",
    ["X-Offhand-Zoom"] = "1.0000",
    ["X-Offhand-Focal-X"] = "0.5000",
    ["X-Offhand-Focal-Y"] = "0.5000",
    ["X-Offhand-Opacity"] = "0.8000",
    ["X-Offhand-Dim"] = "0.2000",
    ["X-Offhand-Matte"] = "#161922",
}
C_AddOns = {
    GetAddOnMetadata = function(name, field)
        assert(name == "Offhand_UserMedia")
        return packageMetadata[field]
    end,
    LoadAddOn = function() error("code-free media packages must never be loaded as executable addons") end,
}

local function Texture()
    local texture = { shown = false }
    function texture:SetTexture(value) self.texture = value end
    function texture:SetVertexColor(r, g, b, a) self.vertex = { r, g, b, a } end
    function texture:SetColorTexture(r, g, b, a) self.color = { r, g, b, a } end
    function texture:SetAlpha(value) self.alpha = value end
    function texture:SetTexCoord(left, right, top, bottom) self.coords = { left, right, top, bottom } end
    function texture:ClearAllPoints() self.point = nil; self.allPoints = nil end
    function texture:SetAllPoints(frame) self.allPoints = frame end
    function texture:SetPoint(...) self.point = { ... } end
    function texture:SetSize(width, height) self.width = width; self.height = height end
    function texture:Show() self.shown = true end
    function texture:Hide() self.shown = false end
    return texture
end

local canvas = {
    width = 100,
    height = 100,
    bgTexture = Texture(),
}
function canvas:GetWidth() return self.width end
function canvas:GetHeight() return self.height end
function canvas:SetBackdrop()end
function canvas:SetBackdropColor(...)self.backdropColor={...}end
function canvas:CreateTexture()
    local texture = Texture()
    self.created = self.created or {}
    self.created[#self.created + 1] = texture
    return texture
end

assert(loadfile("Core/UserMedia.lua"))("Offhand", addon)
addon:InitializeUserMedia()
assert(addon.UserMedia:IsAvailable(), "generated TOC metadata should be discovered and validate")

assert(addon.UserMedia:ApplyToCanvas(canvas), "enabled media should apply")
local fill = canvas.userMediaTexture.coords
assert(math.abs(fill[1] - (50 / 256)) < 0.0001, "Fill must crop horizontally around the focal point")
assert(math.abs(fill[2] - (150 / 256)) < 0.0001, "Fill crop must end at the focused content edge")
assert(fill[3] == 0 and math.abs(fill[4] - (100 / 128)) < 0.0001, "Fill must exclude padded TGA pixels")
assert(canvas.userMediaTexture.alpha == 0.8, "Package opacity must apply")
assert(canvas.userMediaDimTexture.color[4] == 0.2, "Package darkening must apply")

addon.UserMedia:SetFitMode("FIT")
addon.UserMedia:ApplyToCanvas(canvas)
assert(canvas.userMediaTexture.width == 100 and canvas.userMediaTexture.height == 50,
    "Fit must preserve image aspect ratio within the canvas")
assert(canvas.userMediaTexture.coords[2] == 200 / 256
    and canvas.userMediaTexture.coords[4] == 100 / 128,
    "Fit must exclude power-of-two padding")

addon.UserMedia:SetFitMode("STRETCH")
addon.UserMedia:ApplyToCanvas(canvas)
assert(canvas.userMediaTexture.allPoints == canvas, "Stretch must cover the canvas")
assert(canvas.userMediaTexture.coords[2] == 200 / 256, "Stretch must use only image content")

-- Exercise the real theme dispatcher with two independent region geometries.
local other={width=400,height=100,bgTexture=Texture()}
other.GetWidth,other.GetHeight,other.CreateTexture=canvas.GetWidth,canvas.GetHeight,canvas.CreateTexture
other.SetBackdrop,other.SetBackdropColor=canvas.SetBackdrop,canvas.SetBackdropColor
addon.canvases={portrait=canvas,wide=other}
addon.WorkspaceRegions={IsCanvas=function(_,f)return f==canvas or f==other end}
assert(loadfile('UI/Themes.lua'))('Offhand',addon)
addon.db.userMediaEnabled=false
assert(addon.Themes:SetRegionMediaMode('portrait','IMAGE'))
assert(addon.Themes:SetRegionMediaMode('wide','IMAGE'))
assert(addon.Themes:SetRegionMediaFit('portrait','FILL'))
assert(addon.Themes:SetRegionMediaFit('wide','FIT'))
assert(canvas.userMediaTexture~=other.userMediaTexture,'Regions shared mutable texture state')
assert(math.abs(canvas.userMediaTexture.coords[1]-50/256)<.0001)
assert(other.userMediaTexture.width==200 and other.userMediaTexture.height==100)
assert(other.userMediaTexture.alpha==.8 and other.userMediaDimTexture.color[4]==.2)
assert(canvas.backdropColor[4]==0 and other.backdropColor[4]==0,'Theme backdrop obscured the installed image')
assert(addon.db.userMediaEnabled==false and addon.db.userMediaFitMode=='STRETCH','Region image choice changed globals')
assert(addon.Themes:SetRegionMediaMode('portrait','THEME'))
assert(not canvas.userMediaTexture.shown and other.userMediaTexture.shown,'Theme-only region hid another region image')
assert(canvas.backdropColor[4]>.9 and other.backdropColor[4]==0,'Theme-only fallback did not restore its background fill')
assert(addon.Themes:SetRegionMediaMode('portrait','IMAGE'))
other.width=100;other.height=400;addon.Themes:ApplyCanvasTheme()
assert(other.userMediaTexture.width==100 and other.userMediaTexture.height==50,'Resizing did not recompute region fit')
assert(addon.Themes:SetRegionMediaFit('wide','STRETCH'))
assert(other.userMediaTexture.allPoints==other and other.userMediaTexture.coords[2]==200/256)
addon.UserMedia.status='MISSING';addon.UserMedia.metadata=nil;addon.Themes:ApplyCanvasTheme()
assert(not canvas.userMediaTexture.shown and not other.userMediaTexture.shown,'Missing package did not restore all themes')
addon.UserMedia:Refresh();addon.Themes:ApplyCanvasTheme()
assert(canvas.userMediaTexture.shown and other.userMediaTexture.shown,'Package recovery lost saved region intent')
addon.db.userMediaEnabled=true

addon.UserMedia.metadata = nil
addon.UserMedia.status = "INVALID"
assert(not addon.UserMedia:ApplyToCanvas(canvas), "invalid media must fall back safely")
assert(canvas.userMediaTexture.shown == false and canvas.userMediaDimTexture.shown == false,
    "invalid media must hide custom regions")

packageMetadata["X-Offhand-Media-Schema"] = "1"
local available, legacyStatus = addon.UserMedia:Refresh()
assert(not available and legacyStatus == "INVALID"
    and addon.UserMedia.reason == "LEGACY_OR_UNSUPPORTED_SCHEMA",
    "legacy executable packages must require safe regeneration")

packageMetadata["X-Offhand-Media-Schema"] = "2"
C_AddOns = nil
GetAddOnMetadata = function(name, field)
    assert(name == "Offhand_UserMedia")
    return packageMetadata[field]
end
local legacyApiAddon = { db = { userMediaEnabled = true, userMediaFitMode = "PACKAGE" } }
assert(loadfile("Core/UserMedia.lua"))("Offhand", legacyApiAddon)
legacyApiAddon:InitializeUserMedia()
assert(legacyApiAddon.UserMedia:IsAvailable(),
    "legacy clients should read code-free package metadata without loading addon code")

packageMetadata["X-Offhand-Opacity"] = "5"
local tamperedAvailable, tamperedStatus = legacyApiAddon.UserMedia:Refresh()
assert(not tamperedAvailable and tamperedStatus == "INVALID"
    and legacyApiAddon.UserMedia.reason == "PRESENTATION",
    "out-of-range declarative metadata must fail closed")

print("PASS: code-free Background Studio metadata, validation, fit modes, padding crop, and fallback verified!")
