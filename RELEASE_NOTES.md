<!-- offhand-companion-version: 2.1.2-beta.20 -->

# Offhand v2.1.2 Beta 24

> This is a public testing build. Back up your existing Offhand SavedVariables before installing and report regressions with the requested diagnostics.

## Changes in this build

### Fixed and improved
- Improved workspace chat position restoration and docked-tab visibility handling,
  including ownership detection for Ellesmere UI. Real incoming multi-tab traffic
  and the reported top-left position through zoning still need user verification.
- Restored Retail Spellbook availability, retained the selected Spellbook/Talents
  tab across reloads, and fitted wider Talents content inside the workspace.
  Panels closed before reload now stay closed.
- Preserved Retail World Map native panel registration and lifecycle when moved
  to Offhand, fixing the invisible map observed with OpenMap installed. This
  Offhand compatibility fix is included in Beta 24 and does not require changes
  to OpenMap.
- Added compatible shared Mainhand HUD layout reuse across characters while
  preserving character-specific rollback sources and external-addon anchors.
- Improved Mainhand bounds for world tooltips and supported speech bubbles.
- Improved Ellesmere bags, chat and status-bar ownership handling.
- Made Recover Missing UI clearer, with readable paragraphs, smaller body text,
  an opaque background and confirmation sizing that fits Mainhand.
- Added 0.1 percentage-point manual seam adjustments and decimal input.
- Updated setup guidance to recommend Companion first, explain UI repositioning,
  and recommend backing up Blizzard layouts and addon profiles before setup.

### Verified on Retail
- Tested packaged Offhand Beta 24 with an unmodified CurseForge installation of
  OpenMap v0.7.1-beta on Retail 12.1.5. After restarting, the map remained visible
  through repeated opening/closing, zooming and zone hovering, with no fresh
  errors reported. No local OpenMap patches were used for this retest.

### Known limitations and test focus
- Native loading artwork still uses the entire spanned WoW window and can crop
  across unequal or offset displays. Use Companion's Restore Window before
  loading, then Span WoW Now after returning to the world, as a manual workaround.
- Real incoming chat across tabs, exact top-left chat persistence through zoning,
  two-character shared-layout reuse/rollback and the reported mixed-landscape
  border need further live verification. Combat/taint and physical stacked-display
  tooltip/bubble checks remain outstanding. Other clients need targeted retesting.
- This is an addon-only beta. Companion remains 2.1.2-beta.20; no native loading
  resize, graphics-reset recovery or Companion binary changes are included.

## Downloads

- **Recommended Windows Companion:** [Install from Microsoft Store](https://apps.microsoft.com/detail/9PL4PW84Q90W) for a Store-signed package and Microsoft-managed updates.
- **Portable / Linux / Wine Companion:** download `Offhand-Companion-v2.1.2-beta.20.zip` from the [official GitHub release](https://github.com/N4UX-GIT/Offhand-DualMonitor/releases/tag/v2.1.2-beta.24).
- **Complete package:** `Offhand-Complete-v2.1.2-beta.24.zip`: addon and Companion together.
- **Addon only:** `Offhand-v2.1.2-beta.24.zip`: install the contained `Offhand` folder in `Interface/AddOns`.
- **Companion package:** `Offhand-Companion-v2.1.2-beta.20.zip`: unchanged, byte-identical 2.1.2-beta.20 archive, named for the Companion build rather than the addon release that carries it.
- **Standalone Companion:** `Offhand.exe`: unchanged, byte-identical 2.1.2-beta.20 executable.
- **Companion source release:** [v2.1.2-beta.20](https://github.com/N4UX-GIT/Offhand-DualMonitor/releases/tag/v2.1.2-beta.20).

## Test focus

1. Back up Offhand SavedVariables, Blizzard Edit Mode layouts and UI addon profiles before upgrading. Keep existing settings for the upgrade test.
2. Move chat to the workspace, switch tabs with real incoming messages, then check placement and message separation after /reload, zoning and a normal restart. Include Ellesmere UI where used.
3. Open Spellbook and Talents on Offhand, reload with either tab open, then close them and reload again. Check the selected tab, fit and closed state.
4. Check World Map reopen, zoom and hover behavior with your normal map addon. Separate local OpenMap grain/hover patches are not included.
5. Test shared Mainhand HUD layout reuse and rollback on two characters. Check tooltips and speech bubbles near each viewport edge, particularly on stacked monitors.
6. Report fresh Lua/protected-action errors before, during and after combat, with client/build, monitor geometry, UI addons and /offhand diag output. These checks remain outstanding.

Loading artwork still uses the spanned window. Manual workaround: Restore Window before loading, then Span WoW Now after returning to the world. This is not a spanned loading-art fix.

Companion remains 2.1.2-beta.20. No Companion binary or graphics-reset recovery changes are included.

## Linux and Wine status

The Companion is still a Windows WinForms application. Wine support is experimental: run WoW and the Companion as the same user in the same `WINEPREFIX` and with the same Wine/Proton runner version. See `Companion/Linux.md` in the complete package for a Lutris example and extraction checks. Native Linux, X11, and general Wayland support are not claimed by this release.

## Reporting issues

Use the [GitHub issue tracker](https://github.com/N4UX-GIT/Offhand-DualMonitor/issues) and include reproduction steps plus the diagnostics listed above.

## Verification

The Companion is unsigned. Download it only from the official release linked above. Use the attached SHA-256 checksums to verify the downloads. Locally prepared draft assets do not carry GitHub Actions build-provenance attestations; those are produced by the tagged release workflow.

[Full changelog](https://github.com/N4UX-GIT/Offhand-DualMonitor/blob/v2.1.2-beta.24/CHANGELOG.md)
