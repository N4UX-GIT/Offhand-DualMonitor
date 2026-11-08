# Offhand Custom Workspace Regions, Discord Test 1

**Unofficial experimental tester build, 3 November 2026.** This GitHub prerelease
is for Discord testing. It is separate from the regular addon and Store release.

Download **Offhand-Complete-custom-workspace-regions-20261103-1.zip** for both
components. Separate Addon and Companion ZIPs contain the same component files.
Use these attached assets; GitHub's automatic Source code downloads are developer
snapshots and contain the older convenience executable under Companion/.

Included: updated Offhand addon based on Beta 24, plus portable Companion
2.1.3 Beta 3 (file version 2.1.3.4). The AddOns list labels the addon
**Custom Regions Test 1**. Its normal compatibility version stays Beta 24.

## Install

1. Exit WoW and any running Offhand Companion, including a Store/tray instance.
2. Back up your current Offhand addon folder, the client's WTF folder and
   `%LOCALAPPDATA%\Offhand`. These keep your current settings and rollback state.
3. Extract the Complete ZIP into a new folder. Copy its **Offhand** folder into
   the WoW client's `Interface\AddOns`, replacing the existing Offhand folder.
   The result must be `Interface\AddOns\Offhand\Offhand.toc`, with no nested
   Offhand folder. Repeat for each client you intend to test. Keep other addons
   and `Offhand_UserMedia` as they are.
4. Keep the Complete ZIP's **Offhand.exe** outside the AddOns folder. Start WoW
   in standard **Windowed** mode, then start this extracted executable. Use the
   portable executable included here for this test.
5. Verify the game monitor and selected displays in Companion. Choose
   **Custom region...**, then the appropriate layout. Multiple workspaces supports
   one full game monitor and up to two workspace areas on other monitors.
6. Set dimensions or use **Select area on monitor...** to move/resize the area.
   **Save plan** stores settings. Click **Span WoW Now** to apply, then type
   `/reload` in WoW once. Custom plans use manual spanning.
7. Open `/oh` to review the in-game setup. Preserve your existing HUD layout and
   follow the setup prompts only if that setup is still incomplete.

The Companion was built locally and is unsigned; no GitHub Actions attestation
is claimed. `checksums-sha256.txt` identifies all attached assets. The exact
Companion executable SHA-256 is:

`AB022A01DEE6D5CC627A5387DFC032D1B3D02BEA22DD0D5ED7CEC22157F388A3`

Use the repository's security guidance if Windows reports a warning or detection.

## What to test and report

- Select and adjust an area, apply it, reload, reopen panels and restore the window.
- Check taskbar coverage while WoW is focused, panel placement, readability,
  tooltips, mouse input, closing/reopening and persistence after restarting.
- If you have three monitors, test both workspace areas independently. Report
  monitor resolution, Windows scaling, orientation, offsets and which is Mainhand.
- Include **Custom Regions Test 1**, WoW flavor/build, steps, expected/actual
  behavior, relevant screenshots and any fresh Lua error. Remove private chat
  and account information from reports.

Oversized panels should return to Mainhand while retaining their saved workspace
destination. Custom Retail PlayerSpells retains native size. Anniversary Settings
tooltips receive a separate scale correction.

All 86 Lua suites and manifest/Lua 5.1 checks passed. Bounded Anniversary live
checks covered Settings tooltip text/scale/hide restoration and a production
recovery probe in an actual 480x600 workspace. P8's native span/restore and cold
restart were previously checked on Retail and Anniversary with two displays;
that earlier run used an older addon snapshot.

**Still experimental:** real three-monitor input/rendering, mixed DPI and physical
disconnect/reconnect; larger native panels, replacement bags, cold panel recovery,
tooltip follow-up in active spans/other clients, and combat/protected actions.
Forever, original Wrath and other clients are not accepted by this test pass.

## Restore and roll back

Click **Restore Window** in the test Companion before closing it. Exit WoW and
the Companion, restore your backed-up Offhand folder and settings, then return
to your usual Companion. Restore backed-up WTF/settings only while WoW is closed
if you want to undo test-time profile changes. Avoid running two Companions.
You can also reinstall the regular Beta 24 addon and your usual Store/portable
Companion. Keep the backups until you have confirmed normal operation.

The test tag is `test-custom-workspace-regions-20261103-1`. `TEST-BUILD.json`
records source revisions and file hashes. Packaging changes only the six TOC
titles/candidate markers; Lua, XML and media match the reviewed addon runtime.
The regular release channel and its frozen convenience binaries stay separate.
