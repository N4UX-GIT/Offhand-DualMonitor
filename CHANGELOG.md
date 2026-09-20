# Changelog

All notable changes to this project will be documented in this file.

## [2.0.0] - 2026-09-20
### Added
- **Vertical Stack Support:** Added full support for vertically stacked monitor configurations (Top/Bottom) to both the Addon and Companion App.
- **Auto-Updates:** Added an automatic update checker to the Companion App to notify you when new releases drop on GitHub.
- **Enhanced Heuristics:** The 1-Click Auto-Setup Wizard now automatically detects irregular ultra-wide spanned resolutions and suggests the correct monitor aspect ratio.

### Fixed
- **World Map Dimming:** Fixed a major issue where the World Map would forcefully fade, dim, or close itself while your character was moving during combat.
- **Escape Key Persistence:** Fixed a bug where pressing the Escape key would accidentally close panels docked safely in your Offhand Monitor.
- **Panel Demodalization Engine:** Completely rewrote the core frame detachment system. The Character Frame, Spellbook, and Map now retain their flawless native UI geometry, expanding gracefully without clipping backgrounds or squishing layout stats.
- **Chat Frame Dragging:** Fixed an issue in Retail WoW where Chat Frames would violently snap back to the Edit Mode grid. They can now be dragged completely free-form across both monitors just like Classic Era.
- **Bag Layout Algorithm:** Fixed the native Backpack sorting algorithm so that expanded bags stack correctly on your workspace without colliding with action bars or the micro menu.
- **UI & Typography Overhaul:** Completely redesigned the layout of the Options UI and Configuration Wizard. Fixed squished columns, floating text, overlapping checkboxes, and truncated button labels for a pristine configuration experience.
- **Process Detection:** Expanded Companion App executable detection to reliably hook into any WoW client regardless of region or PTR status.
- **Localization:** Restored and expanded authentic community translations across 11 different languages.

## [1.0.1] - 2026-09-19
### Fixed
- Fixed a critical issue where the WoW client could permanently save the squished 3D viewport dimensions to its internal layout cache if the addon was disabled or uninstalled. Offhand now gracefully restores the WorldFrame back to full screen milliseconds before the game shuts down or reloads.

## [1.0.0] - 2026-09-18
### Added
- Initial public release of Offhand - Dual-Monitor Workstation!
- Intelligent 3D viewport rendering to restrict the game world to your primary monitor.
- Companion App for Windows to achieve flawless, borderless window spanning.
- 1-Click Auto-Configuration Wizard for instant calibration.
- Full support for Retail, Classic Era, Progression Classic, and WoW Forever.
