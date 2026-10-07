--[[
    Offhand: Multi-Monitor Setup Addon
    Locales/enUS.lua: English localization dictionary and comprehensive user help tooltips
--]]

local _, Offhand = ...
_G.Offhand = Offhand

local L = Offhand.L or setmetatable({}, {
    __index = function(t, key)
        return key
    end
})

Offhand.L = L

-- Settings and guided setup
L["CARD_SCALE_ALIGNMENT"] = "Game alignment & UI scale"
L["GLOBAL_SCALE_HELP"] = "Sets the shared game UI scale. Addons inherit it unless they apply their own scale."
L["ONBOARD_TITLE"] = "Welcome to Offhand"
L["ONBOARD_PROGRESS"] = "First-time setup: Step %d of %d"
L["ONBOARD_STEP_1_TITLE"] = "Turn a second display into your Offhand"
L["ONBOARD_STEP_1_BODY"] = "Offhand keeps the 3D world on your Mainhand monitor and gives ordinary windows, such as the map, bags and character panel, a separate workspace. This guide prepares Windows, WoW and the Companion first. The calibration wizard follows after the span is verified.\n\nClosing this guide does not mark setup complete; it will return next login until you reach the calibration step."
L["ONBOARD_STEP_2_TITLE"] = "Install the matching Companion"
L["ONBOARD_STEP_2_BODY"] = "Install the current Offhand Companion release and start Offhand.exe. Keep it running in the notification area before launching WoW. The addon cannot resize the Windows game window by itself.\n\nThe addon header shows its paired Companion release. Use matching builds whenever possible, and include both versions in bug reports."
L["ONBOARD_STEP_3_TITLE"] = "Prepare Windows and WoW"
L["ONBOARD_STEP_3_BODY"] = "1. In Windows Display Settings, arrange the displays exactly as they sit on your desk; align the shared edge.\n2. In WoW, choose Windowed mode, not Windowed (Fullscreen).\n3. In Companion, select the displays to span and choose the Mainhand display that will contain the 3D game.\n4. For one 32:9/32:10 display, select only it and use the single-display split option instead."
L["ONBOARD_STEP_4_TITLE"] = "Span WoW and verify the connection"
L["ONBOARD_STEP_4_BODY"] = "In Companion, click Span WoW Now. When spanning finishes, click Reload UI below. Offhand will return to this step and read the exact display rectangles and Companion version.\n\nThe guide will not continue while the span is absent, the saved topology differs, or the Companion version is known to be incompatible."
L["ONBOARD_STEP_5_TITLE"] = "Prepare your in-game layout"
L["ONBOARD_STEP_5_BODY"] = "Retail protects action bars and other combat controls through Blizzard Edit Mode. The calibration wizard ends with Create Mainhand HUD Layout. Press it outside combat with Edit Mode closed; Offhand will create and select a Mainhand-safe copy, then ask you to reload.\n\nThe disabled button below is a visual preview. After setup, the same action remains available in Offhand Monitor > Recovery & Preview whenever the generated layout needs to be refreshed or rebuilt."
L["ONBOARD_STEP_5_BODY_FOREVER"] = "Forever protects action bars, party/raid frames and other combat controls through Blizzard Edit Mode. The calibration wizard ends with Create Mainhand HUD Layout. Press it outside combat with Edit Mode closed; Offhand will preserve custom placements, arrange the standard HUD controls on Mainhand, and ask you to reload.\n\nThe disabled button below is a visual preview. After setup, the same action remains available in Offhand Monitor > Recovery & Preview whenever the generated layout needs to be refreshed or rebuilt."
L["ONBOARD_STEP_6_TITLE"] = "Ready for display calibration"
L["ONBOARD_STEP_6_BODY"] = "The installation checks are complete. Continue into the calibration wizard to confirm monitor orientation, the physical seam, Mainhand aspect ratio and UI size. On Forever and Retail, its final step creates and selects the required Mainhand HUD layout; setup is recorded as complete only after that succeeds.\n\nYou can reopen this guide later from /offhand guide or the Help tab."
L["ONBOARD_CHECK_AGAIN"] = "Check Again"
L["ONBOARD_RELOAD_UI"] = "Reload UI"
L["ONBOARD_START_CALIBRATION"] = "Start Calibration"
L["ONBOARD_STATUS_CHECK_PROMPT"] = "After Companion finishes spanning WoW, click Reload UI."
L["ONBOARD_STATUS_NOT_SPANNED"] = "No exact Companion span is active yet. Click Span WoW Now, then /reload if WoW was already open."
L["ONBOARD_STATUS_TOPOLOGY_MISMATCH"] = "The current game window does not match Companion's saved display topology. Restore the window, reselect the displays, and span again."
L["ONBOARD_STATUS_VERSION_MISMATCH"] = "Companion %s does not match the addon's paired release %s. Update Companion before continuing."
L["ONBOARD_STATUS_VERSION_UNKNOWN"] = "The span is valid. This older Companion did not record its version; updating is recommended."
L["ONBOARD_STATUS_READY"] = "Companion span and version verified. You can continue."
L["VERSION_TOOLTIP_ADDON_BUILD"] = "Exact addon build: %s"
L["VERSION_TOOLTIP_COMPANION_BUILD"] = "Paired Companion release: %s"
L["VERSION_TOOLTIP_COMPANION_NOTE"] = "WoW cannot verify the Companion executable currently running. Include both versions when reporting an issue."
L["CARD_PERSISTENCE"] = "Offhand Monitor windows"
L["HIDE_WORKSPACE_CLOSE_BUTTONS"] = "Hide close buttons on Offhand windows"
L["HIDE_WORKSPACE_CLOSE_BUTTONS_DESC"] = "Hides the X only while a supported window is visible in the Offhand workspace. It returns on Mainhand or when this option is disabled."
L["HIDE_WORKSPACE_MAP_MAXIMIZE"] = "Hide World Map enlarge button on Offhand"
L["HIDE_WORKSPACE_MAP_MAXIMIZE_DESC"] = "Hides the windowed map's enlarge button only while the map is on Offhand. The return-to-windowed control remains available."
L["CARD_RECOVERY"] = "Recovery & Preview"
L["CARD_ADVANCED_COMPAT"] = "Advanced compatibility"
L["ADVANCED_SHOW"] = "Show advanced options"
L["ADVANCED_HIDE"] = "Hide advanced options"
L["FOREVER_PROF_MOVE"] = "Allow experimental Professions window movement"
L["FOREVER_PROF_MOVE_DESC"] = "Forever only: waits for Blizzard to finish opening Professions, then permits dragging and delayed position restoration. Automatic opening, Escape protection and reload persistence remain disabled."
L["FOREVER_PROF_MOVE_CONFIRM"] = "Some Forever clients have frozen or crashed when addons modify the Professions window. Enable this only if Professions opens reliably without Offhand control. Consent is reset after a client build update."
L["FOREVER_PROF_MOVE_ENABLE"] = "Enable Experimental Movement"
L["FOREVER_PROF_MOVE_SAFE"] = "Keep Safe Default"
L["FOREVER_PROF_FORGET"] = "Forget Professions Position"
L["FOREVER_PROF_FORGOT"] = "Forgot the saved Professions position."
L["CARD_BEZEL"] = "Bezel compensation (advanced)"
L["PREVIEW_DUAL"] = "Preview dual-monitor layout on a single display"
L["GATHER_UI"] = "Gather Off-Screen UI"
L["RECOVERY_RESCUE_LABEL"] = "Rescue only windows that are unreachable or outside both displays."
L["RECOVERY_GATHER_LABEL"] = "Return every visible supported window to Mainhand."
L["RECOVERY_CREATE_LABEL"] = "Generate or refresh the protected Mainhand HUD layout."
L["RECOVERY_DESIGNATE_LABEL"] = "Remember the selected custom layout for this character."
L["GATHER_COMBAT"] = "Leave combat before gathering off-screen windows."
L["GATHER_RESULT"] = "Recovered %d off-screen windows. Visible windows were left in place."
L["GATHER_MAINHAND_UI"] = "Gather Safe UI to Mainhand"
L["GATHER_MAINHAND_UI_DESC"] = "Moves visible, movable, unprotected windows into Mainhand. Protected HUD systems remain owned by Blizzard Edit Mode."
L["GATHER_MAINHAND_RESULT"] = "Moved %d safe windows to Mainhand; skipped %d unsupported windows."
L["GATHER_MAINHAND_UNAVAILABLE"] = "Safe UI gathering requires an active Offhand span."
L["MAINHAND_LAYOUT_CREATE"] = "Create Mainhand HUD Layout"
L["MAINHAND_LAYOUT_CREATE_DESC"] = "Clones the source Edit Mode layout, translates its default HUD anchors to Mainhand, and builds a compact stack for XP, stance, pet, possess, vehicle-exit, encounter, and extra-ability controls. Custom-positioned source entries remain unchanged. Use this outside combat with Edit Mode closed."
L["MAINHAND_LAYOUT_CREATED"] = "Created Edit Mode layout '%s' and moved %d HUD systems to Mainhand."
L["MAINHAND_LAYOUT_FAILED"] = "Could not create the Mainhand HUD layout (%s)."
L["MAINHAND_LAYOUT_STATUS"] = "Mainhand HUD layout: %s"
L["MAINHAND_LAYOUT_UNSET"] = "Not created"
L["MAINHAND_LAYOUT_STALE"] = "%s (update required)"
L["MAINHAND_LAYOUT_RELOAD_TEXT"] = "Offhand created and selected the Mainhand HUD layout. Reload now to let Blizzard apply every protected frame?"
L["PROFILE_NEW_NAME"] = "New profile name"
L["PROFILE_ACTIVE"] = "(active)"
L["PROFILE_COPY_INTO_CURRENT"] = "Copy into current"
L["PROFILE_COPY_CONFIRM"] = "Replace settings in '%s' with a copy of '%s'? This cannot be undone."
L["PROFILE_DELETE_CONFIRM"] = "Delete profile '%s'? This cannot be undone."
L["PROFILE_RESET_CONFIRM"] = "Reset profile '%s' to defaults? This cannot be undone."
L["SETTINGS_AUTOSAVE"] = "Changes update your active profile immediately. WoW writes them to disk on logout or /reload."
L["SETTINGS_SAVED_LIVE"] = "Changes apply automatically"
L["BTN_CLOSE"] = "Close"
L["BTN_REAPPLY"] = "Reapply Layout"
L["BTN_NEXT"] = "Next"
L["BTN_BACK"] = "Back"
L["BTN_FINISH"] = "Finish Setup"
L["RAW_MOUSE_INPUT"] = "Use raw mouse input while Offhand is spanned"
L["RAW_MOUSE_INPUT_TIP_TITLE"] = "Reliable camera movement"
L["RAW_MOUSE_INPUT_TIP_DESC"] = "Prevents the hidden cursor from reaching a mixed-height window edge and blocking vertical camera movement. Offhand remembers and restores your previous raw-mouse setting outside a spanned layout."
L["FOREVER_SINGLE_SCREEN_LAYOUT_TEXT"] = "Your saved Offhand monitor is unavailable. Forever needs your confirmation to move protected UI frames to a single-screen layout.\n\nChoose Use Modern to recover now. Offhand will offer to restore '%s' when the monitor returns."
L["FOREVER_USE_MODERN"] = "Use Modern"
L["FOREVER_KEEP_OFFHAND"] = "Keep Offhand"
L["FOREVER_KEEP_CURRENT_LAYOUT"] = "Keep Current Layout"
L["FOREVER_RESTORE_LAYOUT_TEXT"] = "Your saved display layout is available again. Forever requires one player click to change protected HUD layouts.\n\nRestore '%s' now?"
L["FOREVER_RESTORE_OFFHAND"] = "Restore Offhand"
L["FOREVER_KEEP_MODERN"] = "Keep Modern"
L["FOREVER_RESTORE_SAVED_LAYOUT"] = "Restore Saved Layout"
L["FOREVER_EDIT_MODE_LAYOUT_LABEL"] = "Forever Edit Mode layout: %s"
L["FOREVER_EDIT_MODE_LAYOUT_UNSET"] = "Not selected"
L["FOREVER_EDIT_MODE_LAYOUT_MISSING_STATUS"] = "%s (not found)"
L["FOREVER_EDIT_MODE_USE_CURRENT"] = "Use Current Edit Mode Layout"
L["FOREVER_EDIT_MODE_USE_CURRENT_DESC"] = "In Blizzard Edit Mode, select and save the custom layout this character should use while spanned, then click this button. Built-in Modern and Classic layouts cannot be designated."
L["FOREVER_EDIT_MODE_LAYOUT_SAVED"] = "Forever Edit Mode layout set to '%s' for this character."
L["FOREVER_EDIT_MODE_LAYOUT_FAILED"] = "Select a saved custom layout outside combat, then try again."
L["WIZARD_RECOMMENDATION_APPLIED"] = "Recommended settings applied"
L["WIZARD_CHECK_RECOMMENDATION"] = "Continue to check monitor layout, alignment and UI size."
L["BTN_SETTINGS"] = "All Settings"
L["STEP_PROGRESS"] = "Step %d of %d"
L["STEP_1_HELP"] = "Before continuing: use Windowed mode (not Windowed Fullscreen); make Windows Display Settings match the monitors' physical edge alignment; select the displays and Mainhand in Companion; click Span WoW Now; then /reload if WoW was already open."
L["STEP_2_HELP"] = "Choose which monitor shows the game and select its aspect ratio. Your other monitor becomes the Offhand Monitor."
L["WIZARD_STEP2_OPTIONS_LOCKED"] = "These options are locked because Companion supplied the exact monitor geometry. This is expected. Change the displays or Mainhand in Companion and span again, or click Next to continue."
L["WIZARD_STEP3_OPTIONS_LOCKED"] = "Offhand Monitor width is locked because Companion supplied the exact monitor geometry. Change displays or Mainhand in Companion and span again. The laser and Game bottom offset remain available for physical alignment."
L["STEP_3_HELP"] = "Align the red guide with the monitor boundary. Adjust the bottom offset if the Mainhand Monitor sits too high or too low."
L["STEP_4_HELP"] = "Choose a comfortable UI size. On Forever and Retail, click Next to create the required Mainhand HUD layout as the final setup step."
L["HELP_OVERVIEW_TITLE"] = "Offhand Setup & Recovery Handbook"
L["HELP_OVERVIEW_BODY"] = "Follow the numbered sections once from top to bottom. The buttons below reopen the setup wizard, gather ordinary off-screen windows, or show the official Companion download. On Forever and Retail, Create Mainhand HUD Layout prepares a safe Blizzard Edit Mode copy; ordinary workspace panels remain managed separately by Offhand."
L["HELP_SETUP_TITLE"] = "Complete first-time setup"
L["HELP_SETUP_BODY"] = "1. Install Offhand and enable it for your character.\n2. Set WoW to standard Windowed mode, not Windowed (Fullscreen).\n3. Install the Companion release paired with the addon and start it before WoW.\n4. Select the displays to span and choose Mainhand. For one 32:9/32:10 display, select only it and enable the single-display split.\n5. Click Span WoW Now. If WoW was already open, return to the first-launch guide and click Reload UI.\n6. Finish the guide, then complete the calibration wizard. Companion-supplied geometry is intentionally locked in Steps 2 and 3.\n7. On Forever or Retail, press Create Mainhand HUD Layout on the wizard's final step and reload when prompted. Setup is not marked complete unless layout creation succeeds. Fine-tune the generated layout in Blizzard Edit Mode if desired.\n8. Arrange ordinary panels on the workspace. Exit WoW normally with Companion still running, then relaunch to verify a cold start."
L["HELP_COMPANION_TITLE"] = "Why Forever requires Companion"
L["HELP_COMPANION_BODY"] = "A WoW addon cannot resize or borderlessly span the Windows game client or discover the physical monitor rectangles behind one combined window. The Companion assigns an explicit Mainhand, records the exact game/workspace coordinates, and spans the selected displays before Offhand lays out the UI. This supports mixed resolutions and heights, portrait/landscape or stacked screens, negative Windows coordinates, ultrawide Mainhand displays, and an explicit one-screen 32:9 split without guessing from a combined resolution. On Forever it also refreshes only Offhand's recovery bridge while WoW is closed because that beta can write SavedVariables without reliably loading them after a full restart. It does not inspect game memory or automate gameplay."
L["HELP_PANELS_TITLE"] = "Workspace panels Offhand can restore"
L["HELP_PANELS_BODY"] = "Offhand owns ordinary movable workspace frames: World Map, Character frame, combined backpack, chat and supported addon panels. Drag them by their headers to the Offhand Monitor. Their saved position and open/closed state are restored after reload and cold launch. Enable Independent Panels to keep several Blizzard panels open together. On Forever, resize the World Map from Offhand's map settings. If Full Map hides Blizzard's controls, click Return to Windowed Map on Mainhand. Action bars and protected combat frames are not workspace panels; configure those in Blizzard Edit Mode."
L["HELP_RECOVERY_TITLE"] = "Recovery playbook"
L["HELP_RECOVERY_BODY"] = "Ordinary panel is missing: click Gather Off-Screen UI.\nEdit Mode controls are partly visible: drag their visible title bar into Mainhand. If none is reachable, close Edit Mode, use Restore Window in Companion, configure and save your custom layout, then Span WoW Now and /reload.\nProtected HUD frame is misplaced: open Edit Mode, select the layout designated for this character, reposition it and save.\nCamera stops moving vertically while holding right mouse: keep Use raw mouse input enabled on the Display tab; Offhand applies it only while spanned and restores the previous value afterward.\nSaved display is disconnected: Companion restores WoW to the surviving Mainhand and refuses to span stale topology. On Forever, click Use Modern when prompted; after reconnecting and spanning the exact saved topology, restore the saved layout. A layout you select manually takes precedence.\nOffhand profiles or settings survive /reload but disappear after a full restart: leave Companion running while WoW exits normally. Before relaunching, confirm its log reports both that the WoW process closed and that the Forever recovery snapshot was updated or is current. If this repeats, include the addon version, Companion version and those log lines in the report.\nDeliberately return to one monitor: select your normal Edit Mode layout, disable Offhand, then use Restore Window in Companion."
L["HELP_EDIT_MODE_TITLE"] = "Forever protected UI and Edit Mode"
L["HELP_EDIT_MODE_BODY"] = "Forever protects action bars, player/target frames, stance and pet bars, party and raid frames, and other combat UI. Outside combat with Edit Mode closed, Create Mainhand HUD Layout safely clones the active source through Blizzard's layout API and translates default UIParent anchors into Mainhand. Default XP/status and stance bars are stacked above the main action bar; custom-positioned source entries are preserved. Reload when prompted, then use Blizzard Edit Mode for any personal adjustments and save. Use Current Edit Mode Layout designates that custom layout per character. If a saved display disappears, layout changes still require the recovery popup buttons."
L["HELP_COLD_LAUNCH_TITLE"] = "Everyday launch, shutdown and cold-start check"
L["HELP_COLD_LAUNCH_BODY"] = "Start Companion before WoW and leave it running in the system tray. Click Span WoW Now, or let spanning finish first if you deliberately enabled automatic spanning, before opening workspace panels. During play, Offhand saves position and visibility changes into the current Forever session fallback. When finished, exit WoW normally before closing Companion. Companion waits for the WoW process to stop, captures the newest valid recovery state, and prepares it for the next launch. After any setup change, perform one full exit and relaunch to confirm the window span, workspace panels and Edit Mode manager all return correctly."
L["HELP_WELCOME_TITLE"] = "Welcome message and setup status"
L["HELP_WELCOME_BODY"] = "The first-launch guide covers installation and Companion use, then hands off to the calibration wizard. Reaching that handoff acknowledges the introduction. On Forever and Retail, setup completion is recorded only after Create Mainhand HUD Layout succeeds on the wizard's final step; other clients finish after UI-scale calibration. Both states are account-wide and included in Forever recovery. Reopen the introduction with /offhand guide, or open calibration directly with /offhand wizard."
L["EDIT_MODE_LAYOUT_MISSING"] = "Forever uses Blizzard Edit Mode for action bars and combat frames. Outside combat, select and save a custom layout, position it on Mainhand, then designate it from Offhand's Recovery card."
L["EDIT_MODE_LAYOUT_MISSING_RETAIL"] = "Blizzard Edit Mode manages action bars and combat frames. Outside combat, position them on the Mainhand Monitor and select the layout this character should use. Offhand remembers that selection per character."
L["COMPAT_ELLESMERE_PARTY"] = "EllesmereUI Raid Frames detected. Position its replacement Party/Raid Frames with EllesmereUI Unlock Mode. To use Blizzard Edit Mode instead, disable the EllesmereUI Raid Frames module."

-- ============================================================================
-- Core & General Strings
-- ============================================================================
L["ADDON_TITLE"] = "Offhand: Multi-Monitor Setup"
L["ADDON_DESC"] = "Dual Monitor Offhand Monitor and Seamless Display Topology Manager"
L["CMD_HELP_TITLE"] = "Offhand Slash Commands"
L["LAYOUT_REAPPLIED"] = "Layout reapplied!"
L["CONFIG_SAVED"] = "Configuration saved! Welcome to Offhand Multi-Monitor Setup."

-- ============================================================================
-- Options Dashboard Header & Tabs
-- ============================================================================
L["OPTIONS_TITLE"] = "OFFHAND MULTI-MONITOR WORKSPACE"
L["TAB_DISPLAY"] = "Display"
L["TAB_WORKSPACE"] = "Offhand Monitor & Map"
L["TAB_THEMES"] = "Themes & Colors"
L["BTN_AUTO_WIZARD"] = "Auto-Setup Wizard"
L["BTN_AUTO_WIZARD_TIP_TITLE"] = "Display Calibration Wizard"
L["BTN_AUTO_WIZARD_TIP_DESC"] = "Open the guided 1-click display configuration wizard to automatically detect your screen resolution and calibrate your physical monitor seam."

-- ============================================================================
-- Tab 1: Display & Viewport
-- ============================================================================
L["CARD_LAYOUT_PRESETS"] = "Display Mode & Dual Monitor Orientation"
L["CARD_LAYOUT_PRESETS_DESC"] = "Select which physical monitor displays your 3D game world and which displays your 2D Offhand Monitor."
L["PRESET_PL_LR"] = "Portrait (Left) + Game (Right)"
L["PRESET_PL_LR_TIP_TITLE"] = "Portrait Left + Game Right"
L["PRESET_PL_LR_TIP_DESC"] = "Ideal for setups with a vertical Offhand Monitor on the left and your main horizontal gaming monitor on the right."

L["PRESET_GL_PR"] = "Game (Left) + Portrait (Right)"
L["PRESET_GL_PR_TIP_TITLE"] = "Game Left + Portrait Right"
L["PRESET_GL_PR_TIP_DESC"] = "Ideal for setups with your main gaming monitor on the left and a vertical Offhand Monitor on the right."

L["PRESET_DUAL_LANDSCAPE"] = "Dual Landscape Side-by-Side (50/50)"
L["PRESET_DUAL_LANDSCAPE_TIP_TITLE"] = "Dual Landscape (Side by Side)"
L["PRESET_DUAL_LANDSCAPE_TIP_DESC"] = "Splits the game window equally in half across two identical horizontal monitors side by side."

L["BTN_1CLICK_AUTOCONFIG"] = "1-Click Auto-Configure"
L["BTN_1CLICK_AUTOCONFIG_TIP_TITLE"] = "Automatic Hardware Detection"
L["BTN_1CLICK_AUTOCONFIG_TIP_DESC"] = "Queries your active screen resolution and automatically applies recommended seam ratio, monitor orientation, and 3D aspect ratio."
L["EXACT_TOPOLOGY_LOCKED"] = "Companion controls monitor layout. Change displays or Mainhand there, then span again."
L["COMPANION_TOPOLOGY_SUMMARY"] = "Companion active: Game %dx%d | Workspace %dx%d"

L["CARD_VIEWPORT_AR"] = "Mainhand Monitor Geometry & Bezel Seam"
L["AR_16_9"] = "16:9 Standard"
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
L["SLIDER_SEAM_WIDTH"] = "Offhand Monitor width ():"
L["SLIDER_SEAM_WIDTH_TIP_TITLE"] = "Physical Seam Position"
L["SLIDER_SEAM_WIDTH_TIP_DESC"] = "Defines where the boundary between your Offhand Monitor and Mainhand Monitor sits, as a percentage of total spanned screen width."

L["BTN_SEAM_MINUS"] = "- 1%"
L["BTN_SEAM_MINUS_TIP_TITLE"] = "Nudge Seam Left"
L["BTN_SEAM_MINUS_TIP_DESC"] = "Moves the monitor dividing seam 1% to the left."

L["BTN_SEAM_PLUS"] = "+ 1%"
L["BTN_SEAM_PLUS_TIP_TITLE"] = "Nudge Seam Right"
L["BTN_SEAM_PLUS_TIP_DESC"] = "Moves the monitor dividing seam 1% to the right."

L["BTN_LASER_TOGGLE"] = "Show Red Seam Guide Laser"
L["BTN_LASER_TOGGLE_TIP_TITLE"] = "Physical Bezel Laser Guide"
L["BTN_LASER_TOGGLE_TIP_DESC"] = "Shows or hides a bright red seam line: vertical for side-by-side displays and horizontal for stacked displays. Align it with the physical monitor bezel."

L["SLIDER_BEZEL_GAP"] = "Bezel Compensation Gap"
L["SLIDER_BEZEL_GAP_TIP_TITLE"] = "Bezel Gap Compensation"
L["SLIDER_BEZEL_GAP_TIP_DESC"] = "Compensates for the physical plastic border between your screens by creating a blank dead zone to prevent visual misalignment across monitors."

-- ============================================================================
-- Tab 2: Offhand Monitor & Map
-- ============================================================================
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

-- ============================================================================
-- Tab 3: Themes & Colors
-- ============================================================================
L["CARD_THEMES"] = "1. Visual Theme Style Presets"
L["THEME_CLASSIC"] = "Classic Warcraft"
L["THEME_CLASSIC_DESC"] = "Authentic WoW dialog style with gold trim and stone backdrop"
L["THEME_CLASSIC_TIP_TITLE"] = "Classic Warcraft Theme"
L["THEME_CLASSIC_TIP_DESC"] = "Uses genuine Blizzard dialog art and authentic stone textures matching the original World of Warcraft aesthetic."

L["THEME_SLATE"] = "Blizzard Slate"
L["THEME_SLATE_DESC"] = "Muted charcoal dialog with pewter/silver trim"
L["THEME_SLATE_TIP_TITLE"] = "Blizzard Slate Theme"
L["THEME_SLATE_TIP_DESC"] = "A sophisticated dark charcoal theme with sleek silver-pewter borders."

L["THEME_TINKER"] = "Forged Brass"
L["THEME_TINKER_DESC"] = "Forged brass borders with glowing blue accents"
L["THEME_TINKER_TIP_TITLE"] = "Forged Brass Theme"
L["THEME_TINKER_TIP_DESC"] = "Dark metal featuring antique brass trim and bright blue energy accents."

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

-- ============================================================================
-- Wizard Dialog Strings & Tooltips
-- ============================================================================
L["WIZARD_TITLE"] = "OFFHAND AUTO-CONFIGURATION WIZARD"
L["WIZARD_CARD1_TITLE"] = "1. Display Topology & 1-Click Auto-Setup"
L["WIZARD_DETECTED_PREFIX"] = "Detected Display:"
L["WIZARD_RECOM_PREFIX"] = "Recommendation:"
L["WIZARD_BTN_AUTOCONFIG"] = "1-Click Auto-Configure & Apply (Recommended)"
L["WIZARD_BTN_AUTOCONFIG_TIP_TITLE"] = "Automatic 1-Click Calibration"
L["WIZARD_BTN_AUTOCONFIG_TIP_DESC"] = "Instantly calibrates your dual monitor setup based on detected screen resolution. Sets the seam split, 3D viewport, and orientation with a single click."
L["WIZARD_STATUS_READY"] = "Click above to automatically detect resolution and configure seam, orientation, and viewport."
L["WIZARD_STATUS_SPAN_REQUIRED"] = "Span not detected. Use Windowed mode (not Windowed Fullscreen), match Windows Display Settings to the physical monitor arrangement, click Span WoW Now, then /reload."
L["WIZARD_STATUS_COMPANION_MISMATCH"] = "Companion %s wrote this layout; this addon expects %s. Update before continuing."
L["WIZARD_STATUS_COMPANION_UNKNOWN"] = "Span detected, but an older Companion did not record its version. Expected: %s."
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

L["WIZARD_PRESET_SCALE_85"] = "Comfortable (85%)"
L["WIZARD_PRESET_SCALE_85_TIP_TITLE"] = "Comfortable UI (85%)"
L["WIZARD_PRESET_SCALE_85_TIP_DESC"] = "A larger, relaxed scale for players who prefer bigger text and icons at normal viewing distance."

L["WIZARD_BTN_ADVANCED"] = "Advanced Settings (/offhand)"
L["WIZARD_BTN_ADVANCED_TIP_TITLE"] = "Advanced Settings"
L["WIZARD_BTN_ADVANCED_TIP_DESC"] = "Closes the wizard and opens the full 3-tab Offhand options dashboard with complete customization controls."

L["WIZARD_BTN_FINISH"] = "Finish Setup"
L["WIZARD_BTN_FINISH_TIP_TITLE"] = "Finish Calibration"
L["WIZARD_BTN_FINISH_TIP_DESC"] = "Saves your configuration, marks initial setup complete, and applies your new multi-monitor layout."

L["WIZARD_BTN_CLOSE"] = "Close Wizard"
L["WIZARD_BTN_CLOSE_TIP_TITLE"] = "Close Wizard"
L["WIZARD_BTN_CLOSE_TIP_DESC"] = "Close the setup wizard without saving any new changes."

-- ============================================================================
-- Wizard â€” Inline Display Text (non-button)
-- ============================================================================
L["WIZARD_SEAM_VAL_FMT"] = "Seam: %.1f%%"
L["WIZARD_SCALE_VAL_FMT"] = "Scale: %.0f%%"
L["WIZARD_SEAM_EDIT_TIP_TITLE"] = "Manual Seam Width Entry"
L["WIZARD_SEAM_EDIT_TIP_DESC"] = "Type a percentage (e.g. 36%) or ratio (e.g. 0.36) and press Enter to apply the seam position."
L["WIZARD_SCALE_EDIT_TIP_TITLE"] = "Manual UI Scale Entry"
L["WIZARD_SCALE_EDIT_TIP_DESC"] = "Type a percentage (e.g. 70%) or decimal (e.g. 0.70) and press Enter to apply the global UI scale."
L["WIZARD_BTN_SCALE_DOWN_TIP_TITLE"] = "Scale Down"
L["WIZARD_BTN_SCALE_DOWN_TIP_DESC"] = "Decreases the global UI scale by 1%."
L["WIZARD_BTN_SCALE_UP_TIP_TITLE"] = "Scale Up"
L["WIZARD_BTN_SCALE_UP_TIP_DESC"] = "Increases the global UI scale by 1%."
L["WIZARD_BTN_SCALE_RESET"] = "Reset (70%)"
L["WIZARD_BTN_SCALE_RESET_TIP_TITLE"] = "Reset UI Scale"
L["WIZARD_BTN_SCALE_RESET_TIP_DESC"] = "Resets the Global UI Scale to the recommended standard default of 70%."

-- ============================================================================
-- Options Panel â€” Tab Labels & General Buttons
-- ============================================================================
L["BTN_APPLY_LAYOUT"] = "Apply Layout"
L["BTN_APPLY_LAYOUT_TIP_TITLE"] = "Apply Layout"
L["BTN_APPLY_LAYOUT_TIP_DESC"] = "Immediately forces all viewports, seams, and UI elements to update with the current settings."
L["BTN_SAVE_CLOSE"] = "Close"
L["BTN_SAVE_CLOSE_TIP_TITLE"] = "Close"
L["BTN_SAVE_CLOSE_TIP_DESC"] = "Saves all settings and closes the configuration dashboard."
L["LABEL_BOTTOM_OFFSET_SHORT"] = "Game bottom offset (pixels):"

-- ============================================================================
-- Options Panel â€” Slider Step & Edit Tooltips (shared factory)
-- ============================================================================
L["SLIDER_STEP_UP_TIP_TITLE"] = "Step Up"
L["SLIDER_STEP_UP_TIP_DESC_FMT"] = "Increases the value by %s."
L["SLIDER_STEP_DOWN_TIP_TITLE"] = "Step Down"
L["SLIDER_STEP_DOWN_TIP_DESC_FMT"] = "Decreases the value by %s."
L["SLIDER_EDITBOX_TIP_TITLE"] = "Manual Value Entry"
L["SLIDER_EDITBOX_TIP_DESC"] = "Click to type an exact numeric or percentage value and press Enter."

-- ============================================================================
-- Options Panel â€” World Map Section
-- ============================================================================
L["BTN_MAP_AUTOFIT"] = "Auto-Fit"
L["BTN_MAP_AUTOFIT_TIP_TITLE"] = "Auto-Fit World Map"
L["BTN_MAP_AUTOFIT_TIP_DESC"] = "Automatically scales the World Map to fit the exact width of your Offhand Monitor."
L["BTN_MAP_100_TIP_TITLE"] = "100% Map Scale"
L["BTN_MAP_100_TIP_DESC"] = "Sets the World Map to standard 100% scale."
L["BTN_MAP_150_TIP_TITLE"] = "150% Map Scale"
L["BTN_MAP_150_TIP_DESC"] = "Sets the World Map to 150% scale for a larger, more detailed view."
L["BTN_MAP_200_TIP_TITLE"] = "200% Map Scale"
L["BTN_MAP_200_TIP_DESC"] = "Sets the World Map to 200% scale."
L["BTN_MAP_250_TIP_TITLE"] = "250% Map Scale"
L["BTN_MAP_250_TIP_DESC"] = "Sets the World Map to 250% scale, filling a large portion of your secondary deck."

-- ============================================================================
-- Options Panel â€” Canvas & Trim Color Buttons
-- ============================================================================
L["BTN_CANVAS_TONE_TIP_TITLE_FMT"] = "%s Tone"
L["BTN_CANVAS_TONE_TIP_DESC_FMT"] = "Sets the Offhand Monitor background tone to %s."
L["BTN_CANVAS_CUSTOM"] = "Custom Color..."
L["BTN_CANVAS_CUSTOM_ACTIVE_FMT"] = "Custom (#%02x%02x%02x)"
L["BTN_CANVAS_CUSTOM_TIP_TITLE"] = "Custom Canvas Color"
L["BTN_CANVAS_CUSTOM_TIP_DESC"] = "Open the color wheel to choose any custom background color and opacity for your secondary Offhand Monitor."
L["BTN_CANVAS_PREVIEW_TIP_TITLE"] = "Live Background Preview"
L["BTN_CANVAS_PREVIEW_TIP_DESC"] = "Click this swatch to open the Color Picker and customize your secondary screen background color."
L["BTN_TRIM_ACCENT_TIP_TITLE_FMT"] = "%s Accent"
L["BTN_TRIM_ACCENT_TIP_DESC_FMT"] = "Applies %s highlight tint to dialog borders, slider handles, and UI frames."
L["BTN_TRIM_CUSTOM"] = "Custom Accent..."
L["BTN_TRIM_CUSTOM_ACTIVE_FMT"] = "Custom (#%02x%02x%02x)"
L["BTN_TRIM_CUSTOM_TIP_TITLE"] = "Custom Accent Color"
L["BTN_TRIM_CUSTOM_TIP_DESC"] = "Open the color picker wheel to select any custom accent tint for borders, headers, and slider thumbs."

-- ============================================================================
-- Options Panel â€” Guide Link & Autoconfig Print
-- ============================================================================
L["BTN_GUIDE_LINK"] = "View Window Spanning Guide"
L["BTN_GUIDE_LINK_TIP_TITLE"] = "Window Spanning Guide"
L["BTN_GUIDE_LINK_TIP_DESC"] = "View instructions and batch files for spanning World of Warcraft across multiple physical monitors."
L["MSG_AUTOCONFIG_APPLIED"] = "|cff00ff001-Click Auto-Configuration applied:|r %s"
L["MSG_AUTOCONFIG_DETAILS"] = "Preset: |cffffd100%s|r | Seam: |cffffd100%.1f%%|r | Viewport: |cffffd100%s|r"
L["MSG_LAYOUT_APPLIED"] = "Layout applied successfully."

-- ============================================================================
-- Slash Command System Messages
-- ============================================================================
L["MSG_LOADED"] = "v%s loaded! Type |cffffcc00/offhand|r to configure."
L["MSG_FIRST_RUN"] = "First time using Offhand? Type |cff00ff00/offhand wizard|r for 1-click auto-setup & calibration."
L["MSG_LAYOUT_ERROR"] = "Layout error: %s"
L["MSG_AR_16_9"] = "Aspect Ratio locked to 16:9 (Standard Widescreen)."
L["MSG_AR_21_9"] = "Aspect Ratio locked to 21:9 (Ultrawide)."
L["MSG_AR_FILL"] = "Using configured game height. Adjust with /offhand height <5-100 percent>."
L["MSG_AR_CUSTOM"] = "Custom Aspect Ratio set to %.3f:1."
L["MSG_HUD_SET"] = "Global UI size set to %.0f%% of Mainhand Monitor."
L["MSG_HUD_CURRENT"] = "Current global UI size multiplier: %.2f (default 0.70). Usage: /offhand hud <25-125 percent>"
L["MSG_CHAT_DECK"] = "Chat docked to Command Deck (Bottom Bay)."
L["MSG_CHAT_GAME"] = "Chat locked to Mainhand Monitor (Bottom-Left)."
L["MSG_CHAT_TOGGLED"] = "Chat position toggled to: %s."
L["MSG_SEAM_SET"] = "Seam & Secondary Deck width set to %.1f%%."
L["MSG_BOTTOM_SET"] = "Game bottom inset set to %.0f pixels."
L["MSG_HEIGHT_SET"] = "Game height set to %.0f%% of canvas (used in Fill mode)."
L["MSG_DIAG_VIEWPORT"] = "Viewport bounds check: %s."
L["MSG_DIAG_PASS"] = "PASS"
L["MSG_DIAG_MISMATCH"] = "MISMATCH"
L["MSG_DIAG_GAME_PIX"] = "Game pixels: %dx%d at (%d, %d), global UI scale %.3f."
L["MSG_DIAG_FULL"] = "Diagnostics: Phys=%dx%d | Screen=%dx%d | EffScale=%.3f | DeckWidth=%d (%.1f%%) | GameArea=%dx%d"
L["MSG_TOGGLE_ON"] = "|cff00ff00Enabled|r"
L["MSG_TOGGLE_OFF"] = "|cffff3333Disabled|r"
L["MSG_TOGGLED"] = "Offhand is now %s."
L["MSG_DEBUG_ON"] = "|cff00ff00On|r"
L["MSG_DEBUG_OFF"] = "|cffff3333Off|r"
L["MSG_DEBUG_TOGGLED"] = "Debug mode %s."
L["MSG_SPAN_GUIDE"] = "Use the included Offhand.exe to stretch WoW across both monitors."
L["MSG_STATUS"] = "Status: %s. Type |cffffcc00/offhand|r for options, or |cff00ff00/offhand wizard|r for auto-setup."
L["MSG_PANEL_LAYOUT_ERROR"] = "Panel layout error: %s"
L["MSG_MAP_LAYOUT_ERROR"] = "Map layout error: %s"

-- ============================================================================
-- Profile Management
-- ============================================================================
L["TAB_PROFILES"] = "Profiles"
L["PROFILES_CURRENT_LABEL"] = "Active Profile:"
L["PROFILES_LIST_TITLE"] = "Saved Profiles"
L["PROFILES_BTN_CREATE"] = "Create"
L["PROFILES_BTN_LOAD"] = "Load"
L["PROFILES_BTN_COPY"] = "Copy From"
L["PROFILES_BTN_DELETE"] = "Delete"
L["PROFILES_BTN_RESET"] = "Reset Current"
L["PROFILES_CREATE_TIP_TITLE"] = "Create Profile"
L["PROFILES_CREATE_TIP_DESC"] = "Create a new profile with the given name."
L["MSG_PROFILE_CREATED"] = "Created profile: %s"
L["MSG_PROFILE_LOADED"] = "Loaded profile: %s"
L["MSG_PROFILE_DELETED"] = "Deleted profile: %s"
L["MSG_PROFILE_RESET"] = "Profile reset to defaults."
L["MSG_PROFILE_COPIED"] = "Copied settings from profile: %s"
L["PROFILES_WARN_DELETE_ACTIVE"] = "Cannot delete the active profile."
L["PROFILES_WARN_DEFAULT"] = "Cannot delete the Default profile."
L["PROFILES_WARN_EMPTY_NAME"] = "Profile name cannot be empty."
L["PROFILES_WARN_EXISTS"] = "A profile with that name already exists."


-- New Setup UI Strings

L["POPUP_COMPANION_HANDOFF_TEXT"] = "|cffffd100Offhand could not confirm the current display span.|r\n\nYour addon and Companion versions may already be correct. Offhand has not loaded a matching display-layout snapshot for this WoW window.\n\nOpen Companion and click Span WoW Now. If WoW was already running, type /reload once afterward.\n\nYou do not need to download Companion again unless Companion reports that your version is incompatible."
L["POPUP_COMPANION_TOPOLOGY_TEXT"] = "|cffffd100The saved display layout no longer matches this WoW window.|r\n\nYour addon and Companion versions may already be correct. Open Companion, confirm the selected displays and Mainhand monitor, then click Span WoW Now. If WoW was already running, type /reload once afterward."
L["POPUP_COMPANION_VERSION_TEXT"] = "|cffffd100Companion version mismatch|r\n\nThis display layout was created by Companion %s, but this addon requires %s. Update Companion, span WoW again, and type /reload.\n\nCopy the official download address below:"
L["POPUP_WELCOME_WARNING_TEXT"] = "|cffffd100Welcome to Offhand!|r\n\n1. Set World of Warcraft to standard Windowed mode.\n2. Start |cff00ff00Offhand Companion v2.0.0+|r before WoW and span the selected displays.\n3. Launch the wizard to calibrate the Mainhand game view and Offhand workspace.\n4. On Forever and Retail, press Create Mainhand HUD Layout on the final step, then reload when prompted.\n\nEither button acknowledges this welcome guide; it will not be shown on every login. The full checklist remains available in /offhand > FAQ & Help."
L["POPUP_BTN_GOT_IT"] = "Got it"
L["POPUP_BTN_GET_APP"] = "Get Companion App"
L["POPUP_BTN_LAUNCH_WIZARD"] = "Launch Wizard"
L["POPUP_BTN_IGNORE"] = "Ignore"
L["WIZARD_WELCOME_TEXT"] = "|cffffd100Welcome to Offhand!|r This wizard verifies the Companion span before configuring the game viewport and workspace.\n\nComplete each step in order. Forever setup cannot finish until an exact Companion topology is loaded, preventing an Offhand layout from being saved against the wrong window size."

-- Newly Added Fields
L["ENABLE_OFFHAND"] = "Enable Offhand Dual Monitor Mode"
L["SHOW_MINIMAP_ICON"] = "Show Minimap Icon"
L["STACKED_LAYOUT"] = "Vertical Stack"
L["PRESET_STACK_BOTTOM"] = "Stacked: Game (Bottom)"
L["PRESET_STACK_TOP"] = "Stacked: Game (Top)"
L["MAP_SETTINGS"] = "World Map Scaling & Navigation"
L["MAP_SCALE"] = "Map Scale (% of Native)"
L["MAP_KEEP_OPEN"] = "Keep World Map open while running / walking"
L["MAP_KEEP_OPEN_DESC"] = "Allows navigating with map open. (Compatible with Leatrix)"
L["PANELS_INDEPENDENT"] = "Keep panels placed on Offhand Monitor open independently"
L["RELOAD_PERSIST"] = "Persist open panels across reloads & zone transitions"
L["REDIRECT_POPUPS"] = "Reroute popups & dialogs away from center bezel"
L["OBS_SETUP"] = "OBS capture setup"
L["OBS_HELP"] = "Use two Game Capture sources with Crop/Pad filters. Apply these pixel crops, then align the sources."
L["OBS_GAME"] = "Game crop"
L["OBS_WORKSPACE"] = "Workspace crop"
L["MAP_SCALE_HELP"] = "Hold Ctrl and scroll over the map to resize it within the monitor."
L["MAP_SCALE_HELP_FOREVER"] = "Forever: use this slider or the preset buttons. If Full Map hides Blizzard's controls, click Return to Windowed Map on Mainhand."
L["MAP_RETURN_WINDOWED"] = "Return to Windowed Map"
L["MAP_RETURN_WINDOWED_DESC"] = "Restores the normal movable map in your Offhand workspace."
L["PANELS_INDEPENDENT_HELP"] = "Open bags, character, spellbook and map together."
L["PANELS_INDEPENDENT_DESC"] = "Allows opening bags, character pane, spellbook & map simultaneously."
L["COMPAT_LEATRIX"] = "Leatrix Maps controls the map."
L["COMPAT_BOTH"] = "Bag and minimap addons control their own windows."
L["COMPAT_BAGS"] = "Your bag addon controls its windows."
L["COMPAT_MINIMAP"] = "Your minimap addon controls its window."
L["COMPAT_AUTO"] = "Compatible bag and minimap addons are detected automatically."

-- Minimap & Menu
L["MINIMAP_MENU_TITLE"] = "Offhand Workspace"
L["MINIMAP_MENU_SETTINGS"] = "Open Settings"
L["MINIMAP_MENU_WIZARD"] = "Run Setup Wizard"
L["MINIMAP_TIP_LEFT"] = "|cffffd100Left-Click:|r Open Settings"
L["MINIMAP_TIP_RIGHT"] = "|cffffd100Right-Click:|r Open Menu"
L["MINIMAP_TIP_DRAG"] = "|cffffd100Drag:|r Move Icon"

-- Forever Edit Mode Controls
L["FOREVER_EDIT_MODE_CONTROLS_TEXT"] = "Blizzard opened the Edit Mode control bar outside the physical displays.\n\nSelect Bring to Mainhand to center only the Edit Mode controls. Offhand will not move action bars, Party or Raid Frames, or other protected UI."
L["FOREVER_EDIT_MODE_BRING_TO_MAINHAND"] = "Bring to Mainhand"
L["FOREVER_EDIT_MODE_NOT_NOW"] = "Not Now"
L["FOREVER_PARTY_FRAME_RECOVERY_TEXT"] = "Blizzard placed Party or Raid Frames in unreachable space between mismatched monitor heights. Because the frames are not visible, they cannot be selected or dragged safely in Edit Mode, and Offhand cannot move protected HUD frames automatically.\n\nClose Edit Mode, click Restore Window in Companion, then open Edit Mode in the normal Mainhand window. Create or select your custom layout, center the Party Frames, and Save. Designate that layout from Offhand's Recovery card, click Span WoW Now, and type /reload. For a manual setup, first resize WoW onto one monitor instead."
L["FOREVER_PARTY_FRAME_RECOVERY_ACK"] = "Got It"
