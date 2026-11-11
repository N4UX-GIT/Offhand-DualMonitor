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

## Built and reviewed

Built from source commit `3f246d8` into ignored `dist/companion-branding-preview-4-20261110`. The native interaction audit passed, with four source files and 45 reviewed declarations. Computer Use reviewed the actual Setup and Advanced pages, tagline/subtext/version order, wrapped guidance and underlined navigation. The already running Forever client's installed addon was detected as 2.1.5 Beta 28 and displayed in the header with the final N4UX credit. This is installation metadata evidence, not evidence that the game loaded the addon. No game input, Span, Restore or addon file update was performed.

The preview is left running on Setup. Screenshots `setup.png` and `advanced.png` are beside the executable. Actual review used one 2560x1440 display; scale extremes were exercised in native layout fixtures. No claim is made about fresh in-game setup completion or subsecond flash absence.

Installed preference hashes remain unchanged. Frozen prepared 2.1.5 EXE/ZIP hashes still match their release records. The local ZIP has exactly LICENSE, Offhand.exe and README.txt with matching embedded executable bytes, and no preferences.

- Preview EXE SHA256: `034AD815399F10C28033D77CA549A4A5A4393292D66EF64A76809D238B9EAFB6`.
- Preview ZIP SHA256: `62CDD37A4B26E8C8EE26746B5EDA18204BEA0668175E3920F427A111D5E5B11D`.

## UI Preview 5 refinement

The owner approved the quieter tabs and requested a subtle boundary plus more useful Span/Restore captions. Both tabs now have the same 1px neutral charcoal border, preserving the selected underline and unfilled background. This distinguishes navigation targets without giving them the primary action's gold outline.

Span caption: `Place WoW across the selected game and workspace areas.` followed by `Then type /reload in WoW.` Restore caption: `Stop spanning and return WoW to a normal window.` The latter describes both remembered-bound and fallback restoration; `InvokeRestoreWindow` explicitly restores caption/thick-frame styles and uses a fitted default when no previous bounds are available. No window behavior changes.

This remains an unpublished local preview: product 2.1.5 UI Preview 5, file 2.1.5.8005. Preference/layout tests check caption meaning, wrapping and alignment below each action plus subtle equal tab borders at the existing scale/width matrix. The original guide, detected addon metadata, branding, keyboard access and frozen release boundaries remain in place.

The initial native review exposed excess whitespace from WinForms table auto-sizing with multiline captions. Action-row height is now explicitly measured from the two caption widths and actual text height. Regression checks reject both clipped captions and excess bottom space. The final preference/layout run passed at 100%-200%, including stable tab/panel bounds and enlarged-child checks.

Final Preview 5 was built from `677af36` in ignored `dist/companion-tabs-preview-5b-20261110`. Computer Use reviewed the subtle tab borders, selected underline, captions and corrected spacing in the actual running window. It remains open on Setup. The earlier Preview 4 and initial Preview 5 were exited; the installed Store app remained open. No game input or window-management actions were performed. Automatic spanning/recovery/update checks remain disabled in the preview. Installed preference hashes stayed unchanged; the builder's frozen public artifact checks passed.

The local package contains exactly LICENSE, Offhand.exe and README.txt, with matching embedded EXE bytes and no user preferences. EXE SHA256: `1BAC74B88EC88A3A0D0C70185A08F4A7B11AB824637973CF629F4E9A69C28A66`. ZIP SHA256: `48CB4ADB5518A86942A886961DDE42C6DCF3CBA685C599B3E83378839CF0F19A`. No publication or production version change.
