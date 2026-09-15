--[[
    Offhand: Multi-Monitor Workspace Addon
    UI/Themes.lua: Authentic Classic WoW UI styling, theme presets, and color palettes
--]]

local _, Offhand = ...

local Themes = {}
Offhand.Themes = Themes

local THEME_DATA = {
    CLASSIC = {
        name = "Classic Warcraft",
        description = "Authentic WoW dialog style with gold trim and stone backdrop",
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
        bgColor = { 1.0, 1.0, 1.0, 1.0 },
        borderColor = { 1.0, 1.0, 1.0, 1.0 },
        headerColor = { 1.0, 1.0, 1.0, 1.0 },
        headerTextColor = { 1.0, 0.82, 0.0, 1.0 },
    },
    BLIZZARD_SLATE = {
        name = "Blizzard Slate",
        description = "Muted charcoal dialog with pewter/silver trim",
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
        bgColor = { 0.07, 0.07, 0.08, 0.96 },
        borderColor = { 0.65, 0.68, 0.72, 1.0 },     -- Pewter Silver
        headerColor = { 0.11, 0.12, 0.14, 1.0 },
        headerTextColor = { 0.95, 0.95, 0.95, 1.0 },
    },
    OBSIDIAN = {
        name = "Obsidian Dark",
        description = "Clean modern dark theme with subtle stone borders",
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
        bgColor = { 0.06, 0.07, 0.08, 0.96 },
        borderColor = { 0.35, 0.36, 0.40, 1.0 },     -- Subtle Slate
        headerColor = { 0.12, 0.13, 0.15, 1.0 },
        headerTextColor = { 1.0, 0.82, 0.0, 1.0 },  -- Classic Gold text
    },
    PITCH_BLACK = {
        name = "Pitch Black (OLED)",
        description = "Pure black for OLED displays",
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
        bgColor = { 0.0, 0.0, 0.0, 1.0 },
        borderColor = { 0.18, 0.18, 0.18, 1.0 },
        headerColor = { 0.05, 0.05, 0.05, 1.0 },
        headerTextColor = { 0.8, 0.8, 0.8, 1.0 },
    },
    GNOMISH_TINKER = {
        name = "Gnomish Tinker",
        description = "Dark forged metal with electric blue HUD accents",
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
        bgColor         = { 0.04, 0.06, 0.10, 0.97 },   -- Near-black deep metal
        borderColor     = { 0.22, 0.30, 0.40, 1.0  },   -- Forged steel-blue rim
        headerColor     = { 0.06, 0.10, 0.18, 1.0  },   -- Dark panel header
        headerTextColor = { 0.35, 0.72, 1.00, 1.0  },   -- HUD display blue
    },
}

-- Preset color options for trim/accents
local COLOR_PALETTES = {
    GOLD         = { name = "Blizzard Gold",     r = 1.00, g = 0.82, b = 0.00, a = 1.0 },
    TINKER_BRASS = { name = "Clockwork Brass",   r = 0.85, g = 0.65, b = 0.18, a = 1.0 },
    TINKER_STEEL = { name = "Forged Steel Blue", r = 0.35, g = 0.72, b = 1.00, a = 1.0 },
    CYAN_GLOW    = { name = "Goggle Cyan",       r = 0.00, g = 0.82, b = 1.00, a = 1.0 },
    SILVER       = { name = "Pewter Silver",     r = 0.72, g = 0.75, b = 0.78, a = 1.0 },
    BRONZE       = { name = "Warm Bronze",       r = 0.85, g = 0.58, b = 0.25, a = 1.0 },
    EMERALD      = { name = "Emerald Green",     r = 0.22, g = 0.82, b = 0.35, a = 1.0 },
    CRIMSON      = { name = "Crimson Red",       r = 0.85, g = 0.22, b = 0.22, a = 1.0 },
}

-- Preset color options for the workspace background
local CANVAS_PALETTES = {
    CLASSIC_STONE= { name = "Classic Stone",  r = 0.72, g = 0.72, b = 0.75, bg = "Interface\\DialogFrame\\UI-DialogBox-Background" },
    TINKER_SLATE = { name = "Tinker Slate",   r = 0.22, g = 0.42, b = 0.64, bg = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark" },
    CHARCOAL     = { name = "Charcoal Slate", r = 0.26, g = 0.27, b = 0.30, bg = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark" },
    WARM_NIGHT   = { name = "Warm Night",     r = 0.40, g = 0.28, b = 0.22, bg = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark" },
    DEEP_BLUE    = { name = "Midnight Navy",  r = 0.15, g = 0.24, b = 0.48, bg = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark" },
    DEEP_METAL   = { name = "Dark Metal",     r = 0.08, g = 0.14, b = 0.24, bg = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark" },
    PURE_BLACK   = { name = "Pitch Black",    r = 0.00, g = 0.00, b = 0.00, bg = "Interface\\Buttons\\WHITE8X8" },
}

function Themes:GetThemeList()
    return { "CLASSIC", "BLIZZARD_SLATE", "GNOMISH_TINKER", "OBSIDIAN", "PITCH_BLACK" }
end

function Themes:GetColorPalettes()
    return COLOR_PALETTES
end

function Themes:GetCanvasPalettes()
    return CANVAS_PALETTES
end

function Themes:GetThemeInfo(themeKey)
    return THEME_DATA[themeKey] or THEME_DATA.CLASSIC
end

function Themes:ApplyCanvasTheme(canvasFrame)
    if not canvasFrame then
        canvasFrame = _G["OffhandCanvasFrame"] or Offhand.canvas
    end
    if not canvasFrame and Offhand.Canvas and Offhand.Canvas.CreateFrames then
        Offhand.Canvas:CreateFrames()
        canvasFrame = _G["OffhandCanvasFrame"] or Offhand.canvas
    end
    if not canvasFrame then return end

    local currentThemeKey = (Offhand.db and Offhand.db.theme) or "CLASSIC"
    local theme = self:GetThemeInfo(currentThemeKey)
    local isClassic = (currentThemeKey == "CLASSIC")
    local isPureBlackTheme = (currentThemeKey == "PITCH_BLACK")

    local colorKey = (Offhand.db and Offhand.db.canvasColor) or "CHARCOAL"
    local alpha = (Offhand.db and Offhand.db.canvasAlpha)
    if alpha == nil then alpha = 0.95 end

    local r, g, b
    local bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark"
    local isPureBlackBg = (colorKey == "PURE_BLACK") or isPureBlackTheme

    if not isPureBlackTheme and colorKey == "CUSTOM" and Offhand.db and Offhand.db.customCanvasColor then
        local c = Offhand.db.customCanvasColor
        r, g, b = c.r or 0.22, c.g or 0.42, c.b or 0.64
    elseif isPureBlackBg then
        r, g, b = 0.0, 0.0, 0.0
        bgFile = "Interface\\Buttons\\WHITE8X8"
    else
        local c = CANVAS_PALETTES[colorKey] or CANVAS_PALETTES.CHARCOAL
        r, g, b = c.r, c.g, c.b
        bgFile = c.bg or bgFile
    end

    if not canvasFrame.SetBackdrop then
        Mixin(canvasFrame, BackdropTemplateMixin)
    end

    -- Apply active visual theme border styling directly to the workspace canvas
    local edgeFile = theme.edgeFile or "Interface\\DialogFrame\\UI-DialogBox-Border"
    local edgeSize = theme.edgeSize or 32
    local insets = theme.insets or { left = 11, right = 12, top = 12, bottom = 11 }

    if isPureBlackTheme then
        edgeFile = "Interface\\Buttons\\WHITE8X8"
        edgeSize = 1
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    end

    if canvasFrame.SetBackdrop then
        canvasFrame:SetBackdrop({
            bgFile = bgFile,
            edgeFile = edgeFile,
            tile = not isPureBlackBg,
            tileSize = 64,
            edgeSize = edgeSize,
            insets = insets,
        })
        canvasFrame:SetBackdropColor(r, g, b, alpha)
    end

    -- Dedicated solid background texture for guaranteed vibrant visibility on real clients
    if not canvasFrame.bgTexture and canvasFrame.CreateTexture then
        canvasFrame.bgTexture = canvasFrame:CreateTexture(nil, "BACKGROUND", nil, -8)
        if canvasFrame.bgTexture.SetAllPoints then
            canvasFrame.bgTexture:SetAllPoints(canvasFrame)
        end
    end
    if canvasFrame.bgTexture and canvasFrame.bgTexture.SetColorTexture then
        canvasFrame.bgTexture:SetColorTexture(r, g, b, alpha)
        if canvasFrame.bgTexture.Show then canvasFrame.bgTexture:Show() end
    end

    -- Resolve border trim color according to theme and trimColor setting
    local br = theme.borderColor or { 1.0, 1.0, 1.0, 1.0 }
    if isPureBlackTheme then
        br = { 0.18, 0.18, 0.18, 1.0 }
    elseif Offhand.db and Offhand.db.trimColor then
        if Offhand.db.trimColor == "CUSTOM" and Offhand.db.customTrimColor then
            local c = Offhand.db.customTrimColor
            br = { c.r, c.g, c.b, c.a or 1.0 }
        elseif COLOR_PALETTES[Offhand.db.trimColor] then
            if isClassic and Offhand.db.trimColor == "GOLD" then
                -- Classic Blizzard gold on UI-DialogBox-Border is pre-rendered; keep untainted
                br = { 1.0, 1.0, 1.0, 1.0 }
            else
                local c = COLOR_PALETTES[Offhand.db.trimColor]
                br = { c.r, c.g, c.b, c.a or 1.0 }
            end
        end
    end

    if canvasFrame.SetBackdropBorderColor then
        canvasFrame:SetBackdropBorderColor(br[1], br[2], br[3], br[4] or 1.0)
    end
end

function Themes:ApplyBackdrop(frame, themeKey, customAlpha)
    if not frame then return end
    if frame == _G["OffhandCanvasFrame"] or frame == Offhand.canvas then
        self:ApplyCanvasTheme(frame)
        return
    end

    local currentThemeKey = themeKey or (Offhand.db and Offhand.db.theme) or "CLASSIC"
    local theme = self:GetThemeInfo(currentThemeKey)
    local isClassic = (currentThemeKey == "CLASSIC")
    local alpha = customAlpha or (Offhand.db and Offhand.db.canvasAlpha) or 0.95

    if not frame.SetBackdrop then
        Mixin(frame, BackdropTemplateMixin)
    end

    frame:SetBackdrop({
        bgFile = theme.bgFile,
        edgeFile = theme.edgeFile,
        tile = isClassic,
        tileSize = isClassic and 32 or 16,
        edgeSize = theme.edgeSize,
        insets = theme.insets,
    })

    -- Background color
    local bg = theme.bgColor
    if isClassic then
        frame:SetBackdropColor(1.0, 1.0, 1.0, alpha)
    else
        frame:SetBackdropColor(bg[1], bg[2], bg[3], alpha)
    end

    -- Window border color
    local br = theme.borderColor
    if Offhand.db and Offhand.db.trimColor then
        if Offhand.db.trimColor == "CUSTOM" and Offhand.db.customTrimColor then
            local c = Offhand.db.customTrimColor
            br = { c.r, c.g, c.b, c.a or 1.0 }
        elseif COLOR_PALETTES[Offhand.db.trimColor] then
            if isClassic and Offhand.db.trimColor == "GOLD" then
                -- Default Blizzard Gold on UI-DialogBox-Border is pre-rendered; keep untainted
                br = { 1.0, 1.0, 1.0, 1.0 }
            else
                local c = COLOR_PALETTES[Offhand.db.trimColor]
                br = { c.r, c.g, c.b, c.a }
            end
        end
    end
    frame:SetBackdropBorderColor(br[1], br[2], br[3], br[4] or 1.0)
end

function Themes:CreateBayHeader(parent, titleText, customHeight)
    local header = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    local h = customHeight or 36
    header:SetHeight(h)
    header:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, -14)
    header:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -14, -14)

    header:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })

    local icon = header:CreateTexture(nil, "OVERLAY")
    local iconOffset = 14
    if icon and icon.SetTexture and icon.SetSize and icon.SetPoint then
        icon:SetSize(24, 24)
        icon:SetPoint("LEFT", header, "LEFT", 10, 0)
        icon:SetTexture("Interface\\AddOns\\Offhand\\Media\\OffhandLogo64x64.blp")
        header.icon = icon
        iconOffset = 40
    end

    local title = header:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("LEFT", header, "LEFT", iconOffset, 0)
    title:SetText(titleText or "Offhand")
    header.title = title

    self:UpdateHeader(header, titleText)
    return header
end

function Themes:UpdateHeader(header, titleText)
    if not header then return end

    local themeKey = (Offhand.db and Offhand.db.theme) or "CLASSIC"
    local theme = self:GetThemeInfo(themeKey)
    local isClassic = (themeKey == "CLASSIC")

    header:SetBackdropColor(theme.headerColor[1], theme.headerColor[2], theme.headerColor[3], 0.90)

    local br = theme.borderColor
    if Offhand.db and Offhand.db.trimColor then
        if Offhand.db.trimColor == "CUSTOM" and Offhand.db.customTrimColor then
            local c = Offhand.db.customTrimColor
            br = { c.r, c.g, c.b, c.a or 1.0 }
        elseif COLOR_PALETTES[Offhand.db.trimColor] then
            if isClassic and Offhand.db.trimColor == "GOLD" then
                br = { 0.85, 0.70, 0.20, 1.0 }
            else
                local c = COLOR_PALETTES[Offhand.db.trimColor]
                br = { c.r, c.g, c.b, c.a or 1.0 }
            end
        end
    end
    header:SetBackdropBorderColor(br[1], br[2], br[3], br[4] or 1.0)

    local textCol = theme.headerTextColor
    if Offhand.db and Offhand.db.trimColor then
        if Offhand.db.trimColor == "CUSTOM" and Offhand.db.customTrimColor then
            local c = Offhand.db.customTrimColor
            textCol = { c.r, c.g, c.b, 1.0 }
        elseif COLOR_PALETTES[Offhand.db.trimColor] then
            local c = COLOR_PALETTES[Offhand.db.trimColor]
            textCol = { c.r, c.g, c.b, 1.0 }
        end
    end

    if header.title then
        if titleText then header.title:SetText(titleText) end
        header.title:SetTextColor(textCol[1], textCol[2], textCol[3], textCol[4] or 1.0)
    end
end

function Offhand:UpdateTheme()
    local themeKey = (Offhand.db and Offhand.db.theme) or "CLASSIC"

    -- Update background workspace canvas
    Themes:ApplyCanvasTheme()

    -- Update config dialog if created
    local config = Offhand.Options and Offhand.Options.GetConfigFrame and Offhand.Options:GetConfigFrame()
    if config then
        Themes:ApplyBackdrop(config, themeKey, 0.98)
        if config.header then
            Themes:UpdateHeader(config.header)
        end
        if Offhand.Options.UpdateCardThemes then
            Offhand.Options:UpdateCardThemes()
        end
    end
end

function Offhand:InitializeThemes()
    -- Theme registry ready
end
