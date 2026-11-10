# Companion header, navigation and setup guidance review

Date: 2026-11-10. Unpublished UI Preview 4, product 2.1.5, file 2.1.5.8004. Production artifacts and addon source remain unchanged.

## Changes

- Header order: OFFHAND, Dual-wield your monitors, descriptive subtext, version/detected addon/creator credit, community links.
- The version line ends with `| Crafted by: N4UX`. Detected addon metadata comes from the existing running-client installation inspection, using TOC Version and X-Offhand-Release. A current installation is displayed as `Addon: 2.1.5 Beta 28`. Waiting, missing and unavailable states are explicit, and stopping WoW clears the previous detected version. Installed-file detection does not establish that WoW loaded/enabled the addon; the tooltip and System Status preserve that distinction.
- Header rows are measured and spaced using actual scaled bounds. Version text wraps before the links move down. Metadata refresh does not resize the outer window.
- Navigation uses flat, unfilled tabs with an underline for the selected page. Additional spacing separates navigation from actions. Restore has a quieter border and normal-weight text. Span remains the primary highlighted action. Keyboard navigation and active custom-layout indication are retained.
- Setup instructions now require enabling Offhand and logging into a character, explicitly distinguish Windowed from Windowed (Fullscreen), and identify `/offhand guide`, Companion, Reload UI, Confirm placement, Start Calibration, and conditional Create Mainhand HUD Layout/reload prompts. Reloading alone is not presented as completing initial setup.

## Guidance evidence

Current source manifests identify addon 2.1.5 / Pre-Release Beta 28. `Core/Init.lua` routes `/offhand guide` and `/offhand setup` to Onboarding, and `/offhand wizard` to calibration. `UI/Onboarding.lua` gates Companion placement on the reload/checkpoint, offers Confirm placement, and exposes Start Calibration before opening Wizard. `UI/Wizard.lua` contains the generated Mainhand HUD step. `Locales/enUS.lua` supplies the exact English action names and explains the Edit Mode-dependent final HUD step.

Shared knowledge status/search and authored `offhand-guide-native-20261109.md` / `offhand-visual-setup-20261109.md` were consulted. The former records scoped native Forever 1.60.1.70862 observations of Span, Reload UI, placement confirmation and calibration handoff. Cached game sources are review-due. This change uses current product source for copy and preserves that earlier evidence boundary; no fresh game-client acceptance or new WoW API behavior is claimed.

## Validation

Native preference/layout checks cover header order, wrapped version/credit text, current/missing/stopped metadata, source metadata inspection, quiet navigation styles, exact setup action names, stable bounds and minimum-width layout at 100%-200% scaling. Workspace UX passes 111 checks per architecture. Store update checks pass 472 assertions across production/preview x64/x86 variants without real Store queries. Frozen 2.1.5 publication checks pass, including rejection of current development source as the submitted release.

The preview keeps isolated settings, automatic spanning/recovery/update checks disabled, and published files unchanged. Local native review and package receipt are recorded after building below.
