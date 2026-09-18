--[[
    Offhand: Multi-Monitor Setup Addon
    Core/Init.lua: Addon initialization, namespace, event dispatcher, and combat-safe queue
--]]

local addonName, Offhand = ...
_G.Offhand = Offhand

Offhand.name = addonName
local getMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
Offhand.version = (getMetadata and getMetadata(addonName, "Version")) or "1.0.1"
Offhand.modules = {}
Offhand.callbacks = {}

-- Client flavor detection
local tocVersion = select(4, GetBuildInfo())
Offhand.tocVersion = tocVersion
Offhand.isClassicEra = (WOW_PROJECT_ID == WOW_PROJECT_CLASSIC)
Offhand.isRetail = (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE)

-- Formatted chat printing
function Offhand:Print(msg, ...)
    if select("#", ...) > 0 then
        msg = string.format(msg, ...)
    end
    local frame = DEFAULT_CHAT_FRAME or (ChatFrame1 and ChatFrame1:IsShown() and ChatFrame1)
    if frame then
        frame:AddMessage("|cff00e5ff[Offhand]|r " .. tostring(msg))
    end
end

function Offhand:Debug(msg, ...)
    local db = (OffhandDB or OffhandDB)
    if db and db.debugMode then
        if select("#", ...) > 0 then
            msg = string.format(msg, ...)
        end
        local frame = DEFAULT_CHAT_FRAME or (ChatFrame1 and ChatFrame1:IsShown() and ChatFrame1)
        if frame then
            frame:AddMessage("|cff888888[Offhand Debug]|r " .. tostring(msg))
        end
    end
end

-- Localization table with embedded English baseline
local L = Offhand.L or setmetatable({}, {
    __index = function(t, key)
        return key
    end
})
Offhand.L = L

-- ============================================================================
-- Default English Localization (Baseline for all clients)
-- ============================================================================
L["ADDON_TITLE"] = "Offhand: Dual Monitor Workstation"
L["ADDON_DESC"] = "Transforms dual monitor setups into a dedicated primary 3D viewport and secondary command deck."
L["CMD_HELP_TITLE"] = "Offhand Slash Commands"
L["LAYOUT_REAPPLIED"] = "Layout reapplied!"
L["CONFIG_SAVED"] = "Configuration saved! Welcome to Offhand Dual Monitor Workstation."

-- Options Dashboard Header & Tabs
L["OPTIONS_TITLE"] = "Offhand DUAL MONITOR WORKSTATION"
L["TAB_DISPLAY"] = "Display & Viewport"
L["TAB_WORKSPACE"] = "Offhand Monitor & Map"
L["TAB_THEMES"] = "Themes & Colors"
L["BTN_AUTO_WIZARD"] = "Auto-Setup Wizard"
L["BTN_AUTO_WIZARD_TIP_TITLE"] = "Display Calibration Wizard"
L["BTN_AUTO_WIZARD_TIP_DESC"] = "Open the guided 1-click display configuration wizard to automatically detect your screen resolution and calibrate your physical monitor seam."

-- Tab 1: Display & Viewport
L["CARD_LAYOUT_PRESETS"] = "1. Monitor Layout Preset"
L["CARD_LAYOUT_PRESETS_DESC"] = "Select which physical monitor displays your 3D game world and which displays your 2D Offhand Monitor."
L["PRESET_PL_LR"] = "Portrait Left + Game Right"
L["PRESET_PL_LR_TIP_TITLE"] = "Portrait Left + Game Right"
L["PRESET_PL_LR_TIP_DESC"] = "Ideal for setups with a vertical Offhand Monitor on the left and your main horizontal gaming monitor on the right."
L["PRESET_GL_PR"] = "Game Left + Portrait Right"
L["PRESET_GL_PR_TIP_TITLE"] = "Game Left + Portrait Right"
L["PRESET_GL_PR_TIP_DESC"] = "Ideal for setups with your main gaming monitor on the left and a vertical Offhand Monitor on the right."
L["PRESET_DUAL_LANDSCAPE"] = "Dual Landscape (50/50)"
L["PRESET_DUAL_LANDSCAPE_TIP_TITLE"] = "Dual Landscape (Side by Side)"
L["PRESET_DUAL_LANDSCAPE_TIP_DESC"] = "Splits the game window equally in half across two identical horizontal monitors side by side."
L["BTN_1CLICK_AUTOCONFIG"] = "1-Click Auto-Configure"
L["BTN_1CLICK_AUTOCONFIG_TIP_TITLE"] = "Automatic Hardware Detection"
L["BTN_1CLICK_AUTOCONFIG_TIP_DESC"] = "Queries your active screen resolution and automatically applies recommended seam ratio, monitor orientation, and 3D aspect ratio."

L["CARD_VIEWPORT_AR"] = "2. 3D Viewport Aspect Ratio & Position"
L["AR_16_9"] = "16:9 Standard Widescreen"
L["AR_16_9_TIP_TITLE"] = "16:9 Aspect Ratio"
L["AR_16_9_TIP_DESC"] = "Locks the 3D game camera to standard 16:9 widescreen. Letterboxes top and bottom if necessary to maintain natural perspective without horizontal stretching."
L["AR_21_9"] = "21:9 Ultrawide"
L["AR_21_9_TIP_TITLE"] = "21:9 Aspect Ratio"
L["AR_21_9_TIP_DESC"] = "Locks the 3D game camera to 21:9 cinematic ultrawide for expanded field of view."
L["AR_FILL"] = "Fit Window Height (Fill)"
L["AR_FILL_TIP_TITLE"] = "Fit Window Height (Fill Mode)"
L["AR_FILL_TIP_DESC"] = "Stretches the 3D viewport vertically to match the configured height percentage without top or bottom letterboxing."

L["ALIGN_LABEL"] = "Mainhand Monitor Alignment:"
L["ALIGN_CENTER"] = "Center"
L["ALIGN_CENTER_TIP_TITLE"] = "Center Alignment"
L["ALIGN_CENTER_TIP_DESC"] = "Centers the Mainhand Monitor within your dedicated Mainhand Monitor area."
L["ALIGN_LEFT"] = "Left"
L["ALIGN_LEFT_TIP_TITLE"] = "Left Alignment"
L["ALIGN_LEFT_TIP_DESC"] = "Anchors the Mainhand Monitor flush to the left boundary of your Mainhand Monitor area."
L["ALIGN_RIGHT"] = "Right"
L["ALIGN_RIGHT_TIP_TITLE"] = "Right Alignment"
L["ALIGN_RIGHT_TIP_DESC"] = "Anchors the Mainhand Monitor flush to the right boundary of your Mainhand Monitor area."

L["SLIDER_GAME_HEIGHT"] = "Game Height Ratio:"
L["SLIDER_GAME_HEIGHT_TIP_TITLE"] = "Mainhand Monitor Height"
L["SLIDER_GAME_HEIGHT_TIP_DESC"] = "Adjusts what percentage of the total window height is occupied by the Mainhand Monitor when using Fill mode."
L["LABEL_BOTTOM_OFFSET"] = "Game bottom offset (pixels):"
L["LABEL_BOTTOM_OFFSET_TIP_TITLE"] = "Bottom Inset Offset"
L["LABEL_BOTTOM_OFFSET_TIP_DESC"] = "Pushes the bottom of the Mainhand Monitor upward by the specified number of pixels to clear taskbars or secondary HUD elements."

L["CARD_SEAM_CALIBRATION"] = "3. Physical Monitor Seam Alignment & Laser Guide"
L["SLIDER_SEAM_WIDTH"] = "Offhand Monitor width (%):"
L["SLIDER_SEAM_WIDTH_TIP_TITLE"] = "Physical Seam Position"
L["SLIDER_SEAM_WIDTH_TIP_DESC"] = "Defines where the boundary between your Offhand Monitor and Mainhand Monitor sits, as a percentage of total spanned screen width."
L["BTN_SEAM_MINUS"] = "- 1%"
L["BTN_SEAM_MINUS_TIP_TITLE"] = "Nudge Seam Left"
L["BTN_SEAM_MINUS_TIP_DESC"] = "Moves the monitor dividing seam 1% to the left."
L["BTN_SEAM_PLUS"] = "+ 1%"
L["BTN_SEAM_PLUS_TIP_TITLE"] = "Nudge Seam Right"
L["BTN_SEAM_PLUS_TIP_DESC"] = "Moves the monitor dividing seam 1% to the right."
L["BTN_LASER_TOGGLE"] = "Toggle Laser Guide"
L["BTN_LASER_TOGGLE_TIP_TITLE"] = "Physical Bezel Laser Guide"
L["BTN_LASER_TOGGLE_TIP_DESC"] = "Shows or hides a bright vertical red laser line on screen. Adjust your seam slider until the line aligns exactly with your physical monitor plastic bezel."
L["SLIDER_BEZEL_GAP"] = "Physical Bezel Gap Correction:"
L["SLIDER_BEZEL_GAP_TIP_TITLE"] = "Bezel Gap Compensation"
L["SLIDER_BEZEL_GAP_TIP_DESC"] = "Compensates for the physical plastic border between your screens by creating a blank dead zone to prevent visual misalignment across monitors."

-- Tab 2: Offhand Monitor & Map
L["CARD_WORKSPACE_MGMT"] = "1. Offhand Monitor Panel Management & Behavior"
L["CHECK_CANVAS_ENABLED"] = "Enable Offhand Offhand Canvas"
L["CHECK_CANVAS_ENABLED_TIP_TITLE"] = "Offhand Offhand Canvas"
L["CHECK_CANVAS_ENABLED_TIP_DESC"] = "Enables the Offhand Monitor workstation backdrop where UI panels, maps, character sheets, and bags are organized."
L["CHECK_ESC_PERSIST"] = "Keep Panels in Offhand Monitor on ESC (Independent Panels)"
L["CHECK_ESC_PERSIST_TIP_TITLE"] = "Independent Offhand Monitor Panels"
L["CHECK_ESC_PERSIST_TIP_DESC"] = "Prevents pressing Escape from closing panels docked in your Offhand Monitor. Escape will only clear targets or open the game menu on your main monitor."
L["CHECK_ALLOW_DRAG"] = "Allow Panel Cross-Seam Dragging"
L["CHECK_ALLOW_DRAG_TIP_TITLE"] = "Cross-Seam Dragging"
L["CHECK_ALLOW_DRAG_TIP_DESC"] = "Allows you to freely drag supported frames (Character Frame, Spellbook, Bags) across the seam between your Mainhand Monitor and Offhand Monitor."
L["CHECK_SEAM_REDIRECT"] = "Offhand Monitor Panel Redirection (Bags, Char, Spellbook)"
L["CHECK_SEAM_REDIRECT_TIP_TITLE"] = "Automatic Panel Redirection"
L["CHECK_SEAM_REDIRECT_TIP_DESC"] = "Automatically routes standard Blizzard panels (Character, Spellbook, Quest Log) into the Offhand Monitor upon opening."
L["CHECK_SEAM_SNAP"] = "Clean Seam Snapping & Edge Alignment"
L["CHECK_SEAM_SNAP_TIP_TITLE"] = "Edge Snapping"
L["CHECK_SEAM_SNAP_TIP_DESC"] = "Snaps dragging frames neatly to the Offhand Monitor borders and monitor seam so your Offhand Monitor stays tidy."
L["SLIDER_HUD_SCALE"] = "Global UI & HUD Scale:"
L["SLIDER_HUD_SCALE_TIP_TITLE"] = "Global Interface Scale"
L["SLIDER_HUD_SCALE_TIP_DESC"] = "Resizes the entire user interface (action bars, unit frames, dialogs). Recommended: 56% to 70% for multi-monitor setups."

L["CARD_MINIMAP_CONFIG"] = "2. Minimap Configuration & Positioning"
L["CHECK_DOCK_MINIMAP"] = "Dock Minimap into Secondary Offhand Monitor Deck"
L["CHECK_DOCK_MINIMAP_TIP_TITLE"] = "Offhand Monitor Minimap Docking"
L["CHECK_DOCK_MINIMAP_TIP_DESC"] = "Moves the Minimap from your main game screen into the top of your Offhand Monitor, keeping your 3D view clean and uncluttered."
L["SLIDER_MINIMAP_SCALE"] = "Minimap Scale Multiplier:"
L["SLIDER_MINIMAP_SCALE_TIP_TITLE"] = "Minimap Size"
L["SLIDER_MINIMAP_SCALE_TIP_DESC"] = "Controls the size of the Minimap when docked in your Offhand Monitor (0.6x to 2.0x)."
L["CHECK_LOCK_MINIMAP"] = "Lock Minimap Position in Offhand Monitor"
L["CHECK_LOCK_MINIMAP_TIP_TITLE"] = "Lock Minimap"
L["CHECK_LOCK_MINIMAP_TIP_DESC"] = "Prevents accidental dragging or repositioning of the Minimap in your secondary deck."
L["BTN_RESET_MINIMAP"] = "Reset Minimap to Default Offhand Monitor Position"
L["BTN_RESET_MINIMAP_TIP_TITLE"] = "Reset Minimap"
L["BTN_RESET_MINIMAP_TIP_DESC"] = "Resets the Minimap position, frame strata, and layout to the top center of the Offhand Monitor."

L["CARD_BAG_MGMT"] = "3. Bag Management & Docking"
L["CHECK_DOCK_BAGS"] = "Auto-Dock All Bags into Secondary Deck"
L["CHECK_DOCK_BAGS_TIP_TITLE"] = "Secondary Deck Bag Docking"
L["CHECK_DOCK_BAGS_TIP_DESC"] = "Automatically places all opened container bags into your Offhand Monitor, clearing your gaming monitor for full combat visibility."
L["CHECK_VERTICAL_BAGS"] = "Force Vertical Bag Column Layout"
L["CHECK_VERTICAL_BAGS_TIP_TITLE"] = "Vertical Bag Columns"
L["CHECK_VERTICAL_BAGS_TIP_DESC"] = "Stacks open container bags neatly in vertical columns on your secondary screen instead of sprawling horizontally."
L["SLIDER_BAG_SCALE"] = "Bag Scale Multiplier:"
L["SLIDER_BAG_SCALE_TIP_TITLE"] = "Bag Window Size"
L["SLIDER_BAG_SCALE_TIP_DESC"] = "Adjusts the scale of your container bags on the Offhand Monitor (0.6x to 1.5x)."

-- Tab 3: Themes & Colors
L["CARD_THEMES"] = "1. Visual Theme Style Presets"
L["THEME_CLASSIC"] = "Classic Warcraft"
L["THEME_CLASSIC_DESC"] = "Authentic WoW dialog style with gold trim and stone backdrop"
L["THEME_CLASSIC_TIP_TITLE"] = "Classic Warcraft Theme"
L["THEME_CLASSIC_TIP_DESC"] = "Uses genuine Blizzard dialog art and authentic stone textures matching the original World of Warcraft aesthetic."
L["THEME_SLATE"] = "Blizzard Slate"
L["THEME_SLATE_DESC"] = "Muted charcoal dialog with pewter/silver trim"
L["THEME_SLATE_TIP_TITLE"] = "Blizzard Slate Theme"
L["THEME_SLATE_TIP_DESC"] = "A sophisticated dark charcoal theme with sleek silver-pewter borders."
L["THEME_TINKER"] = "Gnomish Tinker"
L["THEME_TINKER_DESC"] = "Clockwork brass borders with glowing cyan engineering accents"
L["THEME_TINKER_TIP_TITLE"] = "Gnomish Tinker Theme"
L["THEME_TINKER_TIP_DESC"] = "Inspired by Gnomish engineering blueprints, featuring antique brass trim and bright electric cyan energy accents."
L["THEME_OBSIDIAN"] = "Obsidian Dark"
L["THEME_OBSIDIAN_DESC"] = "Clean modern dark theme with subtle stone borders"
L["THEME_OBSIDIAN_TIP_TITLE"] = "Obsidian Dark Theme"
L["THEME_OBSIDIAN_TIP_DESC"] = "A clean, minimalist dark theme designed for modern gaming aesthetics."
L["THEME_PITCH_BLACK"] = "Pitch Black (OLED)"
L["THEME_PITCH_BLACK_DESC"] = "Pure black for OLED displays"
L["THEME_PITCH_BLACK_TIP_TITLE"] = "Pitch Black (OLED) Theme"
L["THEME_PITCH_BLACK_TIP_DESC"] = "Pure black background designed to turn off pixels on OLED displays for maximum contrast."

L["CARD_TRIM_COLOR"] = "2. Border Trim & Accent Color"
L["TRIM_GOLD"] = "Blizzard Gold"
L["TRIM_BRASS"] = "Clockwork Brass"
L["TRIM_CYAN"] = "Goggle Cyan"
L["TRIM_SILVER"] = "Pewter Silver"
L["TRIM_BRONZE"] = "Warm Bronze"
L["TRIM_EMERALD"] = "Emerald Green"
L["TRIM_CRIMSON"] = "Crimson Red"

L["CARD_CANVAS_BACKGROUND"] = "3. Secondary Deck Background Tone & Opacity"
L["CANVAS_STONE"] = "Classic Stone"
L["CANVAS_TINKER"] = "Tinker Slate"
L["CANVAS_CHARCOAL"] = "Charcoal Slate"
L["CANVAS_WARM_NIGHT"] = "Warm Night"
L["CANVAS_NAVY"] = "Midnight Navy"
L["CANVAS_BLACK"] = "Pitch Black"
L["SLIDER_CANVAS_OPACITY"] = "Canvas Background Opacity:"
L["SLIDER_CANVAS_OPACITY_TIP_TITLE"] = "Canvas Transparency"
L["SLIDER_CANVAS_OPACITY_TIP_DESC"] = "Adjusts how solid or translucent the Offhand Monitor background appears (0% to 100%)."

-- Wizard Dialog Strings & Tooltips
L["WIZARD_TITLE"] = "Offhand AUTO-CONFIGURATION WIZARD"
L["WIZARD_CARD1_TITLE"] = "1. Display Topology & 1-Click Auto-Setup"
L["WIZARD_DETECTED_PREFIX"] = "Detected Display:"
L["WIZARD_RECOM_PREFIX"] = "Recommendation:"
L["WIZARD_BTN_AUTOCONFIG"] = "1-Click Auto-Configure & Apply (Recommended)"
L["WIZARD_BTN_AUTOCONFIG_TIP_TITLE"] = "Automatic 1-Click Calibration"
L["WIZARD_BTN_AUTOCONFIG_TIP_DESC"] = "Instantly calibrates your dual monitor setup based on detected screen resolution. Sets the seam split, 3D viewport, and orientation with a single click."
L["WIZARD_STATUS_READY"] = "Click above to automatically detect resolution and configure seam, orientation, and viewport."
L["WIZARD_STATUS_APPLIED"] = "[Applied] Setup automatically configured for %s"

L["WIZARD_CARD2_TITLE"] = "2. Monitor Orientation & 3D Viewport"
L["WIZARD_LABEL_LAYOUT"] = "Monitor Layout Preset:"
L["WIZARD_LABEL_AR"] = "Mainhand Monitor Aspect Ratio:"

L["WIZARD_CARD3_TITLE"] = "3. Physical Monitor Seam Alignment"
L["WIZARD_SEAM_INSTRUCTION"] = "Align the red laser line with the physical bezel dividing your two monitors:"
L["WIZARD_LABEL_SEAM"] = "Offhand Monitor width:"
L["WIZARD_BTN_LASER_SHOW"] = "Show Laser"
L["WIZARD_BTN_LASER_HIDE"] = "Hide Laser"
L["WIZARD_PRESET_SEAM_36"] = "1440/4000 Seam (36%)"
L["WIZARD_PRESET_SEAM_36_TIP_TITLE"] = "1440p Portrait + 4K Landscape"
L["WIZARD_PRESET_SEAM_36_TIP_DESC"] = "Configures a 36% seam split, precisely tailored for a 1440x2560 portrait screen paired with a 2560x1440 landscape screen."
L["WIZARD_PRESET_SEAM_50"] = "Equal Split (50%)"
L["WIZARD_PRESET_SEAM_50_TIP_TITLE"] = "50% Equal Split"
L["WIZARD_PRESET_SEAM_50_TIP_DESC"] = "Splits the display exactly in half across two monitors of equal width."
L["WIZARD_PRESET_SEAM_55"] = "Custom Split (55%)"
L["WIZARD_PRESET_SEAM_55_TIP_TITLE"] = "55% Asymmetric Split"
L["WIZARD_PRESET_SEAM_55_TIP_DESC"] = "Places 55% of the total screen width on the left monitor and 45% on the right monitor."

L["WIZARD_CARD4_TITLE"] = "4. Global UI Scale & Calibration"
L["WIZARD_UI_SCALE_INSTRUCTION"] = "Adjust the overall size of the user interface to suit your monitor viewing distance:"
L["WIZARD_LABEL_UI_SCALE"] = "Global UI Scale:"
L["WIZARD_UI_SCALE_TIP_TITLE"] = "Global UI Scale"
L["WIZARD_UI_SCALE_TIP_DESC"] = "Scales all action bars, unit frames, and dialogs. Choose a compact scale (56% to 70%) to keep your game screen unobstructed."

L["WIZARD_PRESET_SCALE_56"] = "Compact (56%)"
L["WIZARD_PRESET_SCALE_56_TIP_TITLE"] = "Compact UI (56%)"
L["WIZARD_PRESET_SCALE_56_TIP_DESC"] = "Ultra-clean minimalist scale, freeing maximum screen space for 3D world visuals."
L["WIZARD_PRESET_SCALE_65"] = "Balanced (65%)"
L["WIZARD_PRESET_SCALE_65_TIP_TITLE"] = "Balanced UI (65%)"
L["WIZARD_PRESET_SCALE_65_TIP_DESC"] = "A well-balanced scale providing crisp text legibility while maintaining generous screen real estate."
L["WIZARD_PRESET_SCALE_70"] = "Standard (70%)"
L["WIZARD_PRESET_SCALE_70_TIP_TITLE"] = "Standard UI (70%)"
L["WIZARD_PRESET_SCALE_70_TIP_DESC"] = "Standard Offhand default scale, ideal for 1440p and 4K displays at normal desk viewing distance."
L["WIZARD_PRESET_SCALE_100"] = "Full size (100%)"
L["WIZARD_PRESET_SCALE_100_TIP_TITLE"] = "Unscaled UI (100%)"
L["WIZARD_PRESET_SCALE_100_TIP_DESC"] = "Standard 100% Blizzard UI size without scaling reductions."

L["WIZARD_BTN_ADVANCED"] = "Advanced Settings (/Offhand)"
L["WIZARD_BTN_ADVANCED_TIP_TITLE"] = "Advanced Settings"
L["WIZARD_BTN_ADVANCED_TIP_DESC"] = "Closes the wizard and opens the full 3-tab Offhand options dashboard with complete customization controls."
L["WIZARD_BTN_FINISH"] = "Finish Setup"
L["WIZARD_BTN_FINISH_TIP_TITLE"] = "Finish Calibration"
L["WIZARD_BTN_FINISH_TIP_DESC"] = "Saves your configuration, marks initial setup complete, and applies your new multi-monitor layout."

-- ============================================================================
-- Color Picker Helper
-- ============================================================================
function Offhand:OpenColorPicker(initialR, initialG, initialB, initialA, hasOpacity, onColorChanged)
    if not ColorPickerFrame then return end

    local function ColorCallback(restore)
        local newR, newG, newB, newA
        if restore then
            newR, newG, newB, newA = restore.r, restore.g, restore.b, restore.opacity
        else
            if ColorPickerFrame.GetColorRGB then
                newR, newG, newB = ColorPickerFrame:GetColorRGB()
            else
                newR, newG, newB = initialR, initialG, initialB
            end
            if hasOpacity then
                local opVal = (OpacitySliderFrame and OpacitySliderFrame.GetValue and OpacitySliderFrame:GetValue()) or 0
                newA = 1 - opVal
            else
                newA = initialA or 1.0
            end
        end
        if onColorChanged then
            onColorChanged(newR, newG, newB, newA)
        end
    end

    if ColorPickerFrame.SetupColorPickerAndShow then
        local info = {
            swatchFunc = function() ColorCallback() end,
            opacityFunc = function() ColorCallback() end,
            cancelFunc = function(restore) ColorCallback(restore) end,
            hasOpacity = hasOpacity or false,
            opacity = hasOpacity and (1 - (initialA or 1.0)) or 0,
            r = initialR or 1.0,
            g = initialG or 1.0,
            b = initialB or 1.0,
        }
        ColorPickerFrame:SetupColorPickerAndShow(info)
    else
        ColorPickerFrame.hasOpacity = hasOpacity or false
        ColorPickerFrame.opacity = hasOpacity and (1 - (initialA or 1.0)) or 0
        ColorPickerFrame.previousValues = {
            r = initialR or 1.0,
            g = initialG or 1.0,
            b = initialB or 1.0,
            opacity = initialA or 1.0,
        }
        ColorPickerFrame.func = function() ColorCallback() end
        ColorPickerFrame.opacityFunc = function() ColorCallback() end
        ColorPickerFrame.cancelFunc = function(restore) ColorCallback(restore) end
        if ColorPickerFrame.SetColorRGB then
            ColorPickerFrame:SetColorRGB(initialR or 1.0, initialG or 1.0, initialB or 1.0)
        end
        ColorPickerFrame:Hide()
        ColorPickerFrame:Show()
    end
end

-- ============================================================================
-- Universal Tooltip Helper
-- ============================================================================
function Offhand:SetTooltip(frame, title, text, anchor)
    if not frame then return end
    if not (title or text) then return end
    if frame.EnableMouse then frame:EnableMouse(true) end

    local oldEnter = frame.GetScript and frame:GetScript("OnEnter")
    local oldLeave = frame.GetScript and frame:GetScript("OnLeave")

    frame:SetScript("OnEnter", function(self, ...)
        if oldEnter then pcall(oldEnter, self, ...) end
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, anchor or "ANCHOR_RIGHT")
        if title and title ~= "" then
            GameTooltip:AddLine(title, 1.0, 0.82, 0.0, true)
        end
        if text and text ~= "" then
            GameTooltip:AddLine(text, 1.0, 1.0, 1.0, true)
        end
        GameTooltip:Show()
    end)

    frame:SetScript("OnLeave", function(self, ...)
        if oldLeave then pcall(oldLeave, self, ...) end
        if GameTooltip and GameTooltip:GetOwner() == self then
            GameTooltip:Hide()
        end
    end)
end

-- ============================================================================
-- Combat-Safe Queue System
-- Modifying protected frames or layout during InCombatLockdown causes Lua errors.
-- We safely queue modifications until PLAYER_REGEN_ENABLED.
-- ============================================================================
local combatQueue = {}

function Offhand:RunOrQueueCombat(action, ...)
    if not InCombatLockdown() then
        action(...)
    else
        table.insert(combatQueue, { func = action, args = { ... } })
        Offhand:Debug("Action queued for post-combat execution.")
    end
end

local function ProcessCombatQueue()
    if #combatQueue == 0 then return end
    Offhand:Debug("Processing %d combat-queued actions...", #combatQueue)
    local queueCopy = combatQueue
    combatQueue = {}
    for _, item in ipairs(queueCopy) do
        local success, err = pcall(item.func, unpack(item.args))
        if not success then
            Offhand:Print("|cffff3333Queue Execution Error:|r %s", tostring(err))
        end
    end
end

-- ============================================================================
-- Core Event Dispatcher
-- ============================================================================

StaticPopupDialogs["OFFHAND_COMPANION_WARNING"] = {
    text = [[|cffd0d0d0Offhand is enabled, but your window is not optimally spanned to your physical monitor setup and resolution.|r

For a seamless, borderless experience--and to avoid the tedious process of manually stretching the window edges every time you launch the game--the Offhand Companion App is highly recommended. Download it securely from GitHub below:

(Alternatively, if you prefer to stretch the window manually across both monitors, click Ignore to permanently dismiss this warning).]],
    button1 = "OK",
    button2 = "Ignore",
    hasEditBox = true,
    editBoxWidth = 260,
    OnShow = function(self)
        local eb = self.EditBox or _G[self:GetName().."EditBox"]
        if eb then
            eb:SetText("https://github.com/N4UX/Offhand/releases")
            eb:HighlightText()
            eb:SetFocus()
        end
    end,
    OnAccept = function() end,
    OnCancel = function(self)
        Offhand.db.suppressCompanionWarning = true
    end,
    EditBoxOnEscapePressed = function(self)
        self:GetParent():Hide()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local eventFrame = CreateFrame("Frame", "OffhandEventFrame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_LEAVING_WORLD")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("UI_SCALE_CHANGED")
eventFrame:RegisterEvent("DISPLAY_SIZE_CHANGED")

eventFrame:SetScript("OnEvent", function(self, event, arg1, ...)
    if event == "ADDON_LOADED" and arg1 == addonName then
        Offhand:InitializeConfig()
        if Offhand.InitializeThemes then Offhand:InitializeThemes() end
        if Offhand.InitializeCanvas then Offhand:InitializeCanvas() end
        if Offhand.InitializeViewport then Offhand:InitializeViewport() end
        if Offhand.InitializeSeamRedirect then Offhand:InitializeSeamRedirect() end
        if Offhand.InitializeOptions then Offhand:InitializeOptions() end

        -- Initialize child modules
        for name, module in pairs(Offhand.modules) do
            if module.Initialize then
                module:Initialize()
            end
        end

    elseif event == "PLAYER_LOGIN" then
        pcall(function()
            for i=1, 13 do
                local f = _G["ContainerFrame"..i]
                if f then f:SetUserPlaced(false) end
            end
            if ContainerFrameCombinedBags then
                ContainerFrameCombinedBags:SetUserPlaced(false)
            end
            if PlayerFrame then PlayerFrame:SetUserPlaced(false) end
            if TargetFrame then TargetFrame:SetUserPlaced(false) end
            if MinimapCluster and not (Offhand.db and Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions["MinimapCluster"]) then
                MinimapCluster:SetUserPlaced(false)
            end
            if SetCVar then
                SetCVar("rawMouseEnable", "1")
                SetCVar("rawMouseAccelerationEnable", "0")
            end
        end)
        Offhand:ApplyFullLayout()
        Offhand:Print(L["MSG_LOADED"], Offhand.version)
        if not Offhand.db.firstRunComplete then
            C_Timer.After(1.5, function()
                if Offhand.Wizard and Offhand.Wizard.Open then
                    Offhand.Wizard:Open()
                else
                    Offhand:Print(L["MSG_FIRST_RUN"])
                end
            end)
        end
    elseif event == "PLAYER_LEAVING_WORLD" then
        if Offhand.db and Offhand.db.enabled and Offhand.db.savedWorkspacePositions and Offhand.db.restoreWorkspaceOnReload ~= false then
            Offhand.db.openWorkspacePanels = {}
            for name, _ in pairs(Offhand.db.savedWorkspacePositions) do
                local frame = _G[name]
                if frame and frame:IsVisible() then
                    Offhand.db.openWorkspacePanels[name] = true
                end
            end
            
            for key, val in pairs(_G) do
                if type(key) == "string" and type(val) == "table" and type(rawget(val, 0)) == "userdata" and val.IsShown then
                    local okShow, isShown = pcall(function() return val:IsShown() end)
                    if okShow and isShown then
                        if key:match("^Baganator") or key:match("^Baginator") or key:match("^Bagnon") or key:match("^AdiBags") or key:match("^BetterBags") or key:match("^ArkInventory") or key:match("^ElvUI_ContainerFrame") then
                            if Offhand.Canvas and Offhand.Canvas.IsFrameOnWorkspace then
                                local okWs, onWs = pcall(Offhand.Canvas.IsFrameOnWorkspace, val)
                                if okWs and onWs then
                                    Offhand.db.openWorkspacePanels[key] = true
                                    Offhand.db.savedWorkspacePositions[key] = Offhand.db.savedWorkspacePositions[key] or {}
                                end
                            end
                        end
                    end
                end
            end
        else
            if Offhand.db then Offhand.db.openWorkspacePanels = {} end
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Refresh viewport and layout after zone transition or loading screen
        C_Timer.After(0.5, function()
            Offhand:ApplyFullLayout()
            if Offhand.Canvas and Offhand.Canvas.RestorePersistentFrames then
                Offhand.Canvas:RestorePersistentFrames()
            end

            -- Guard: Companion App check
            if Offhand.db and Offhand.db.enabled and not Offhand.db.suppressCompanionWarning then
                local w = GetScreenWidth() * UIParent:GetEffectiveScale()
                local physW = w
                if GetPhysicalScreenSize then
                    pcall(function() physW = select(1, GetPhysicalScreenSize()) end)
                end
                if w and physW and w <= (physW + 50) then
                    StaticPopup_Show("OFFHAND_COMPANION_WARNING")
                end
            end

        end)

    elseif event == "PLAYER_REGEN_ENABLED" then
        ProcessCombatQueue()

    elseif event == "UI_SCALE_CHANGED" or event == "DISPLAY_SIZE_CHANGED" then
        if not Offhand._displayDebounceTimer then
            Offhand._displayDebounceTimer = C_Timer.NewTimer(0.2, function()
                Offhand._displayDebounceTimer = nil
                Offhand:RunOrQueueCombat(function()
                    Offhand:ApplyFullLayout()
                end)
            end)
        end
    end
end)

-- Convenience master layout apply with reentrancy protection
local isApplyingLayout = false
local layoutPending = false

function Offhand:ApplyFullLayout()
    if not Offhand.db then return end
    if InCombatLockdown() then
        if not layoutPending then
            layoutPending = true
            self:RunOrQueueCombat(function()
                layoutPending = false
                Offhand:ApplyFullLayout()
            end)
        end
        return
    end
    if isApplyingLayout then return end
    isApplyingLayout = true

    local success, err = pcall(function()
        if Offhand.Viewport and Offhand.Viewport.ApplyGlobalScale then Offhand.Viewport:ApplyGlobalScale() end
        if Offhand.UpdateViewport then
            Offhand:UpdateViewport()
        end
        if Offhand.UpdateCanvas then
            Offhand:UpdateCanvas()
        end
        if Offhand.UpdateSeamRedirect then
            Offhand:UpdateSeamRedirect()
        end
        for _, module in pairs(Offhand.modules) do
            if module.ApplyLayout then
                module:ApplyLayout()
            end
        end
    end)

    isApplyingLayout = false
    if not success then
        Offhand:Print(L["MSG_LAYOUT_ERROR"], tostring(err))
    end
end

-- ============================================================================
-- Primary Slash Command Registration (Registered immediately on load)
-- ============================================================================
SLASH_OFFHAND1 = "/offhand"
SLASH_OFFHAND2 = "/oh"
SLASH_OFFHAND3 = "/Offhand"
SLASH_OFFHAND4 = "/ak"

SlashCmdList["OFFHAND"] = function(msg)
    msg = strtrim(msg or ""):lower()
    local cmd, arg = strsplit(" ", msg, 2)

    if cmd == "diag" or cmd == "metrics" or cmd == "info" then
        local snapshot = Offhand.Viewport:CaptureDiagnostics()
        local vpStatus = snapshot.viewportMatches and L["MSG_DIAG_PASS"] or L["MSG_DIAG_MISMATCH"]
        Offhand:Print(L["MSG_DIAG_VIEWPORT"], vpStatus)
        local physW, physH = 0, 0
        if GetPhysicalScreenSize then pcall(function() physW, physH = GetPhysicalScreenSize() end) end
        local screenW = GetScreenWidth()
        local screenH = GetScreenHeight()
        local m = Offhand.Viewport and Offhand.Viewport:GetMetrics() or {}
        local effScale = UIParent and UIParent:GetEffectiveScale() or 1.0
        Offhand:Print(L["MSG_DIAG_GAME_PIX"],
            m.gamePixelWidth or 0, m.gamePixelHeight or 0, m.gamePixelLeft or 0,
            m.gamePixelBottom or 0, effScale)
        Offhand:Print(L["MSG_DIAG_FULL"],
            physW, physH, screenW, screenH, effScale, m.deckWidth or 0, (Offhand.db.deckWidthRatio or 0) * 100, m.gameWidth or 0, m.gameHeight or 0)
    elseif msg == "apply" or msg == "reload" then
        Offhand:ApplyFullLayout()
        Offhand:Print(L["LAYOUT_REAPPLIED"])
    elseif msg == "reset" then
        Offhand:ResetConfig()
    elseif msg == "toggle" then
        Offhand.db.enabled = not Offhand.db.enabled
        Offhand:Print(L["MSG_TOGGLED"], Offhand.db.enabled and L["MSG_TOGGLE_ON"] or L["MSG_TOGGLE_OFF"])
        Offhand:ApplyFullLayout()
    elseif msg == "debug" then
        Offhand.db.debugMode = not Offhand.db.debugMode
        Offhand:Print(L["MSG_DEBUG_TOGGLED"], Offhand.db.debugMode and L["MSG_DEBUG_ON"] or L["MSG_DEBUG_OFF"])
    elseif cmd == "wizard" or cmd == "setup" or cmd == "calibrate" or cmd == "span" or cmd == "guide" then
        if Offhand.Wizard and Offhand.Wizard.Open then
            Offhand.Wizard:Open()
        elseif Offhand.Options and Offhand.Options.Open then
            Offhand.Options:Open(true)
        end
    elseif cmd == "gather" then
        if Offhand.GatherOffScreenUI then
            Offhand:GatherOffScreenUI()
        end
    else
        if Offhand.Options and Offhand.Options.Open then
            Offhand.Options:Open()
        else
            Offhand:Print(L["MSG_STATUS"],
                Offhand.db.enabled and L["MSG_TOGGLE_ON"] or L["MSG_TOGGLE_OFF"])
        end
    end
end

SlashCmdList["Offhand"] = SlashCmdList["OFFHAND"]



-- Emergency bag layout rescue on logout
local logoutFix = CreateFrame('Frame')
logoutFix:RegisterEvent('PLAYER_LOGOUT')
logoutFix:SetScript('OnEvent', function()
    for i = 1, 13 do
        local bag = _G['ContainerFrame'..i]
        if bag then
            bag:ClearAllPoints()
            if i == 1 then
                bag:SetPoint('BOTTOMRIGHT', UIParent, 'BOTTOMRIGHT', -34, 70)
                bag:SetUserPlaced(true)
            else
                bag:SetUserPlaced(false)
            end
        end
    end
end)





-- A window is reachable when enough of its title edge is inside a visible area.
-- Use UIParent units throughout, including when the window has its own scale.
function Offhand:IsWindowReachable(left, top, width, m)
    local function InArea(x1, y1, x2, y2)
        return top >= y1 + 16 and top <= y2 + 2
            and math.min(left + width, x2) - math.max(left, x1) >= math.min(48, width)
    end
    if not m.isSpanned then return InArea(0, 0, m.screenWidth, m.screenHeight) end
    if InArea(m.gameLeft, m.gameBottom, m.gameRight, m.gameTop) then return true end
    local deckLeft = self.db.primaryPosition == "LEFT" and (m.gameRight + (m.bezel or 0)) or 0
    return InArea(deckLeft, 0, deckLeft + m.deckWidth, m.screenHeight)
end

function Offhand:GatherOffScreenUI()
    if InCombatLockdown() then self:Print(self.L["GATHER_COMBAT"]); return 0 end
    local m = self.Viewport and self.Viewport:GetMetrics()
    if not m then return 0 end
    local parentScale = UIParent:GetEffectiveScale() or 1
    local candidates = {}
    for name in pairs(UIPanelWindows or {}) do
        if _G[name] then candidates[_G[name]] = true end
    end
    if UIParent.GetChildren then
        for _, child in ipairs({ UIParent:GetChildren() }) do
            pcall(function()
                if child.IsForbidden and child:IsForbidden() then return end
                if child.IsMovable and child:IsMovable() then candidates[child] = true end
            end)
        end
    end
    local moved = 0
    for frame in pairs(candidates) do
        local ok, recovered = pcall(function()
            if frame == WorldFrame or frame == self.canvas then return false end
            if frame.IsForbidden and frame:IsForbidden() then return false end
            if not frame:IsShown() or frame:IsProtected() then return false end
            if frame.IsObjectType and frame:IsObjectType("GameTooltip") then return false end
            local scale = frame:GetEffectiveScale()
            if not scale or scale <= 0 then return false end
            local factor = scale / parentScale
            local left, top, width = frame:GetLeft(), frame:GetTop(), frame:GetWidth()
            if not left or not top or not width or width <= 0 then return false end
            if self:IsWindowReachable(left * factor, top * factor, width * factor, m) then return false end
            local x = (m.gameLeft + m.gameRight - UIParent:GetWidth()) / 2
            local y = (m.gameBottom + m.gameTop - UIParent:GetHeight()) / 2
            frame:ClearAllPoints()
            frame:SetPoint("CENTER", UIParent, "CENTER", x / factor, y / factor)
            return true
        end)
        if ok and recovered then moved = moved + 1 end
    end
    self:Print(string.format(self.L["GATHER_RESULT"], moved))
    return moved
end



local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function()
    local tooltips = { "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2", "SettingsTooltip" }
    
    -- Dynamically find any other global tooltips safely
    for key, val in pairs(_G) do
        if type(key) == "string" and string.match(key, "Tooltip") and type(val) == "table" and type(rawget(val, 0)) == "userdata" and val.GetObjectType then
            local ok, objType = pcall(function() return val:GetObjectType() end)
            if ok and objType == "GameTooltip" then
                local found = false
                for _, v in ipairs(tooltips) do if v == key then found = true end end
                if not found then table.insert(tooltips, key) end
            end
        end
    end

    local function EnforceTooltipScale(self)
        if not UIParent then return end
        if self.SetIgnoreParentScale and self.IsIgnoringParentScale and self:IsIgnoringParentScale() then
            self:SetIgnoreParentScale(false)
        end
        
        -- Mathematically calculate the exact local scale required to make the tooltip's absolute size match UIParent.
        -- This flawlessly handles tooltips parented to UIParent (requiring 1.0) AND tooltips parented to WorldFrame (requiring 0.39).
        if self.GetScale then
            local desiredAbsolute = UIParent:GetEffectiveScale() or 1
            local parentAbsolute = (self:GetParent() and self:GetParent():GetEffectiveScale()) or 1
            local desiredLocal = desiredAbsolute / parentAbsolute
            
            if math.abs(self:GetScale() - desiredLocal) > 0.01 then
                self:SetScale(desiredLocal)
            end
        end
    end
    
    if SharedTooltip_SetBackdropStyle then
        hooksecurefunc("SharedTooltip_SetBackdropStyle", EnforceTooltipScale)
    end
    
    -- Globally track if the user has their bags open
    if OpenAllBags and CloseAllBags and ToggleAllBags then
        hooksecurefunc("OpenAllBags", function() Offhand.db.bagsWereOpen = true end)
        hooksecurefunc("CloseAllBags", function() Offhand.db.bagsWereOpen = false end)
        hooksecurefunc("ToggleAllBags", function() Offhand.db.bagsWereOpen = not Offhand.db.bagsWereOpen end)
    end
    for _, name in ipairs(tooltips) do
        local tt = _G[name]
        if tt then
            if tt.HookScript then
                tt:HookScript("OnShow", EnforceTooltipScale)
                tt:HookScript("OnSizeChanged", EnforceTooltipScale)
            end
            if tt.SetOwner then
                hooksecurefunc(tt, "SetOwner", EnforceTooltipScale)
            end
            if tt.SetIgnoreParentScale then
                tt:SetIgnoreParentScale(false)
                hooksecurefunc(tt, "SetIgnoreParentScale", function(self, ignore)
                    if ignore then self:SetIgnoreParentScale(false) end
                end)
            end
        end
    end
end)
