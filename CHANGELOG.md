# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]
### Added
- Added durable Forever onboarding state and Companion recovery so acknowledged welcome/setup state survives reloads and cold launches.
- Expanded the in-game FAQ, first-run guide, website, and distribution documentation with the complete Companion, Wizard, Edit Mode, and cold-launch setup flow.
- Added Companion control tooltips, an in-app setup/help guide, a security behavior disclosure, release SHA-256 verification instructions, and GitHub build-provenance attestations.
- Added exact Companion-to-addon game/workspace rectangles, an explicit Mainhand selector, stable Windows display identities, and an opt-in one-screen 32:9/32:10 split.
- Added automated coverage for reordered, missing, mixed-resolution, negative-coordinate, stacked, ultrawide-split, and stale-topology display states.

### Changed
- Companion automatic spanning is now disabled by default on fresh installs while preserving existing saved choices.
- Replaced automatic startup update traffic with an explicit **Check for Updates** action.
- Replaced the oversized embedded Companion artwork with the supplied 64×64 asset, reducing the executable from roughly 2 MB to roughly 250 KB.
- Companion release archives now include their exact C# source, manifest, build script, artwork, and security documentation.
- Normal spanning now requires exactly two selected displays; one display is accepted only with explicit super-ultrawide split mode. More than two are rejected until multi-workspace semantics are designed.
- Workspace placement, panel clamping, maps, bags, chat, popup rescue, and seam guides now use a full rectangle instead of a left/right deck-width assumption.
- Fresh addon profiles remain inert until the setup wizard enables Offhand.

### Fixed
- Fixed the Welcome to Offhand popup returning after it was acknowledged or after the setup wizard was completed.
- Fixed Forever workspace panels and Blizzard Edit Mode controls drifting or becoming inaccessible after window spanning and full client restarts.
- Fixed mixed-resolution and stacked layouts being treated as equal-height side-by-side screens, which caused overlap, squashed game views, and black bars.
- Fixed disconnected displays silently collapsing a saved dual-monitor span onto one screen and shrinking the UI to an unreadable size.
- Fixed 32:9 Mainhand displays being constrained by the legacy 16:9/21:9 resolution heuristic.

## [2.0.0] - 2026-09-20
### Added
- **Multi-Monitor Support:** Added full support for complex 3 and 4 monitor setups, including a dedicated monitor selection interface in the Companion App to choose exactly which screens to span.
- **Vertical Stack Support:** Added full support for vertically stacked monitor configurations (Top/Bottom) to both the Addon and Companion App.
- **Auto-Updates:** Added an automatic update checker to the Companion App to notify you when new releases drop on GitHub.
- **Enhanced Heuristics:** The 1-Click Auto-Setup Wizard now automatically detects irregular ultra-wide spanned resolutions and suggests the correct monitor aspect ratio.

### Fixed
- **World Map Dimming:** Fixed a major issue where the World Map would forcefully fade, dim, or close itself while your character was moving during combat.
- **Process Detection:** Expanded Companion App executable detection to reliably hook into any WoW client regardless of region, executable name, or PTR status.

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
