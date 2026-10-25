# Retail graphics recovery test 4

This is a separate portable candidate, restricted to the _retail_ client. Classic
and Forever are excluded in this variant. Window title must say RETAIL TEST 4.
The published Store Companion and addon installation are not replaced.

## Basis

The public v22 release-tag addon plus Store Beta 20 reproduced a native reset on
Retail when Graphics Options changed VSync Enabled to Disabled. Native capture
records the window falling from 4000x2560 to outer 2114x1353 at the span origin,
client 2100x1339, with resize-frame styles and the old 4000x2560 region retained.
Manual re-spanning restored it. No BugSack errors were reported and no sampled
hung state appeared. The original Midnight hang/excessive-error report remains
unreproduced and is not claimed fixed by this candidate.

Test 4 enables the same recovery policy already tested on Anniversary, with a
Retail-only scope gate and correctly labeled UI/log/settings. It retains the
captured-signature requirement, stable initial span, healthy post-verification,
ten-second cooldown, three-attempt/five-minute limit, and manual cancellation.
No new native recovery mechanism or experimental resize nudge is introduced.

## First Retail recovery test

1. Close Retail normally to preserve the probe capture. Exit Store Companion via
   its tray menu. Start this candidate Offhand.exe and confirm RETAIL TEST 4.
2. Keep the installed release-tag v22 addon and existing display choices. Test 4
   initially reads public selections but writes only RetailTestConfig.ini beside
   itself. Review selected displays and Mainhand before manual spanning.
3. Launch Retail in ordinary Windowed mode. Set VSync Enabled before spanning.
   Start the Retail native watcher, click Span WoW Now and wait for Retail span
   verified stable. Verify both screens. If unstable, stop and retain logs.
4. Enter /ohcapture start. In Graphics Options change VSync to Disabled once.
   Do not click Span WoW Now or /reload while observing automatic restoration.
5. Wait up to ten seconds for recovery, then for Retail recovery re-armed. Check
   window appearance, Mainhand viewport/HUD, chat, workspace panels and Options.
6. /ohcapture stop, stop the native watcher, take screenshots and retain the first
   new BugSack error if present. Exit normally when done to flush probe data.

If WoW hangs, stop repeating the action. The native watcher flushes independently;
probe data may not save until normal exit. Do not infer the hang's cause from a
window-size match. Do not reset the profile to conceal a failure.

## Behavior and rollback

Recovery requires the same confirmed window/display plan and the captured reset
signature, not merely a VSync CVar change. It will not re-span hung, minimized or
maximized windows. Restore Window and Pause Monitor cancel recovery even during
cooldown; Resume Monitor does not revive a cancelled arm. Failures or excessive
resets pause attempts with a log/tray notice. Manual Span establishes a new arm.

Candidate launch auto-span is disabled. Activity logs go to retail-recovery.log
beside the EXE. The public INI and Store executable are unchanged. To roll back,
Exit this candidate and reopen the Store Companion. Existing addon topology-file
writes retain the same Beta 20 format and metadata.

## Evidence status

Shared policy guards and separate Classic/Retail scope builds pass automated
regressions. Anniversary live results support the shared mechanism but do not
constitute Retail acceptance. Retail automatic recovery is live pending until
the sequence above passes, followed by repeat/cancellation checks as appropriate.

### 2026-10-25: Retail Test 4 cancellation checks confirmed by user

- User confirms steps 1-4 of the final control sequence passed: repeat automatic
  recovery without manual span, Pause Monitor during cooldown, no recovery while
  paused, Resume without restoring cancelled ownership, Restore Window staying
  restored, and explicit manual spanning for normal use.
- Evidence level: user-confirmed visible behavior on the tested Retail display
  arrangement. The open Options panel retained its old offset after Restore;
  this is tracked separately as addon menu placement, not native re-spanning.
- Retail and Anniversary candidate recovery/control sequences are now accepted
  for this arrangement. Other display configurations, rate-limit exhaustion and
  the original Midnight hang/excessive-error report are not live verified here.
- After completion of the release-tag baseline test, the local development addon
  candidate including MenuPlacement was installed into Retail for separate UI QA.
  72 copied files hash verified; two generated bridges preserved; SavedVariables
  untouched. Full prior addon backup: D:/Games/World of Warcraft/
  _offhand_deploy_backups/onboarding-identify-20261025-000349-712-Retail/Offhand.
- No Store or public Companion binary was replaced and no release was published.

### 2026-10-25: Separate addon menu-placement follow-up passed

User confirms the installed addon development candidate keeps open Graphics
Options centered and usable after Restore Window and re-span, and Options/Escape
menu close/reopen checks passed with no new BugSack errors reported. This follows
the successful Retail Test 4 repeat recovery and cancellation sequence. Scope is
the tested configuration; the original client hang remains unreproduced. No
Store/public release has been made.
