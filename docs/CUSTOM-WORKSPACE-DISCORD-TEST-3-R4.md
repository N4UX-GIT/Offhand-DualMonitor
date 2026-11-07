# Offhand Custom Workspace Test 3 Revision 4

Unofficial, opt-in Discord tester build. This is not an official release or a
Microsoft Store update. Use both components from this package together.

## Included

- Companion 2.1.3 Beta 6 with the active-display identity follow-up. It now maps
  each display to its active Windows monitor target instead of assuming the
  first monitor entry belongs to that display. This addresses a remaining
  lookup gap that could make two selected monitors share an identity.
- Matching Beta 26-based add-on, marked **[Workspace Test 3 r4]** in WoW. Its
  runtime is the same reconciled add-on included in Revision 3, including
  Flexible Layout, named workspace profiles, supported-panel routing,
  independent workspace themes and installed background-library support.
- The earlier onboarding, per-character HUD setup/reuse, Forever controller,
  native bag/map, Ellesmere, aura ownership, native-dialog, Retail secret-value,
  tooltip and French text candidates remain included.
- Display diagnostics now include identity lookup details even when a display
  layout cannot be confirmed. Missing or ambiguous monitor bindings require
  review rather than an automatic guess.

Companion retains the Beta 6 version label. **TEST-BUILD.json**, the package name
and checksums identify this Revision 4 executable. Previous Revision 3 downloads
do not contain this Companion correction.

## Install and update

1. Close WoW and exit any running Companion through its tray menu. Back up the
   installed Offhand folder, Offhand SavedVariables and Companion preferences.
2. Extract the ZIP into a writable folder. Copy the included **Offhand** folder
   into your test client's **Interface/AddOns** folder. TOCs belong directly
   inside **Interface/AddOns/Offhand**, without an extra nested Offhand folder.
3. Run the extracted **Offhand.exe**. Keep your previous preferences backup;
   do not delete your settings just to test this revision.
4. Start WoW in ordinary **Windowed** mode with the included add-on enabled.
   For first setup, type **/offhand guide** and choose **Use Companion**.
5. Review the checked displays and **Mainhand (game)**. If prompted to review
   old identities, confirm the intended monitors. For custom layouts, open
   **Workspace layout**, review the preview and save the plan.
6. Click **Span WoW Now**, return to WoW and use **/reload** once. Complete the
   in-game setup guide where needed. A saved plan does not resize WoW by itself.

**Restore Window** returns the game to its remembered ordinary window.
**Workspace layout > Use standard display layout** disables custom workspaces.
To roll back, close WoW and Companion, restore the previous add-on and matching
SavedVariables backup, then return to your previous Companion/preferences.

## What to test

- Two checked monitors should remain distinct, including identical-resolution
  monitors. Confirm the intended game monitor, Span, Restore and reopening the
  Companion with the same saved assignments.
- Test docks, connected but disabled outputs, virtual displays and monitor
  reconnects where available. Ambiguous or missing identities should explain
  the problem and prevent an unsafe span. No full support claim is made for
  every adapter, virtual-display driver or remote-session configuration.
- Test ordinary, one-monitor, partial-secondary, multiple-workspace and Flexible
  Layout plans that fit your setup. Review monitor roles after loading profiles.
- Check reload, named profiles, panel routing, region themes, installed custom
  backgrounds and affected native/replacement panels.

One Beta 20 reporter confirmed that a PC restart cleared their selection error.
That is a working workaround; their exact cause and acceptance of this new
executable remain unconfirmed.

## Validation and limits

Automated Companion identity, migration, profiles, workspace geometry, schema
1/2/3 bridges, missing-display, native rollback/Restore, Remote Desktop planning,
taskbar, recovery, UI/scaling and interaction-boundary suites passed. All 101
add-on Lua suites and six manifests passed, with Lua 5.1 syntax validation.
Local native identity reads returned distinct targets for the physical pair.

Synthetic native-window checks and read-only display queries are separate from
live WoW acceptance. Full combined-package live acceptance, affected reporter
hardware, physical hotplug, mixed DPI, three physical displays, Wine and complete
combat/protected-action coverage remain pending.

Known Forever controller behavior: choosing Game Menu from Blizzard's radial
closes open workspace panels, including the combined backpack.

## Reporting and security

Include **Test 3 Revision 4**, WoW client/build, monitor arrangement and scaling,
steps, expected/observed results and fresh Lua errors. Copy **Display Diagnostics**
for monitor problems and identify replacement UI add-ons in use.

This portable build is unsigned and has not been submitted to Microsoft Defender
for review. SmartScreen or antivirus warnings are possible. Verify the download
against **checksums-sha256.txt** on the GitHub prerelease. If security software
flags it, keep protection enabled and report the exact detection. A local scan
is not Microsoft approval or a guarantee that every scanner will accept it.
