# Companion revision 3: Anniversary live acceptance

1 November 2026, approximately 23:29-23:44 CET. Result: targeted native-window
recovery/control pass; broader release acceptance remains partial.

## Exact subject and environment

- Companion `2.1.3-beta.1`, file version `2.1.3.1`, local candidate revision 3.
- Source build: `f7d33ae54a66dc3657f34be4b54cd4db10956e9c`.
- Executable SHA-256: `B24A4D5B5F1B7BE732BCEB9A19074BDAE91FED83636B3BEB8E9E1F2DD1205002`.
- ZIP SHA-256: `5E2A7D61B8ECD36B61D60A281F7700E251FDDC470B3E325EE25D505D9FB6F078`.
- Anniversary executable and login screen: `2.5.6.70577`, standard Windowed mode.
- Installed Offhand: `2.1.2-beta.24-tbc-test.11`, protocol 1; no addon source deployment was performed.
- Selected existing character on Spineshatter, idle in Terokkar Forest. No movement, combat, targeting, casts or gameplay were automated.
- Enabled installed addons in the post-run harness inventory: Moonweaver, Offhand, OneWorld and WeakAurasArchive. The full private inventory remains local.
- Mainhand: `2560x1440`, origin `(0,0)`. Workspace: portrait `1440x2560`, origin `(-1440,-1114)`. Both SDR at 100% Windows scaling.
- Combined bounds: `(-1440,-1114)`, `4000x2560`. VSync initially Disabled; auto-span initially off, delay 30 seconds.

The user approved Anniversary testing after its update. Battle.net then showed
Play with build 70577; the agent did not initiate an update or handle credentials.
Both game launches used the launcher and the same visibly selected character.

## Results

Times below are Companion local log times in CET.

| Case | Observation | Result |
| --- | --- | --- |
| Initial manual span | 23:31:33 native outer/client/region readback matched `4000x2560`, borderless style `140B0000`; stable arm at 23:31:38 | Pass |
| VSync Disabled to Enabled, Apply | Client visibly reset. At 23:34:02 one automatic recovery restored matching bounds/style/clipping; re-arm at 23:34:14 | Pass |
| VSync Enabled to Disabled, Apply | Second reset recovered at 23:34:52 without another manual span; re-arm at 23:35:04 | Pass |
| Explicit Restore | 23:35:27 restore remained a bordered ordinary window beyond an eleven-second wait; no forced respan | Pass |
| Fresh arm, Pause, graphics Apply | Manual span 23:36:04, arm 23:36:10, Pause 23:36:26. Reset remained unrecovered beyond eleven seconds | Pass |
| Resume after cancellation | Resume 23:37:32 did not recover the cancelled span after another eleven-second wait | Pass |
| Manual re-arm after cancellation | Manual span 23:38:10, arm 23:38:14. Returning VSync to Disabled recovered at 23:38:40; re-arm 23:38:52 | Pass |
| Companion exit/restart with span intact | Restart at 23:39:46; existing-span/display-loss protection detected at 23:39:48. No graphics arm was inferred | Observation pass; no reset was induced during this adopted-only state |
| Fresh client with optional delayed auto-span | Auto-span temporarily enabled at 23:40:52. New process verified at 23:41:33; auto-span applied at 23:42:03 and armed at 23:42:09 | Pass for configured delay, native span and stable arm |
| Settings cleanup | Auto-span returned to off at 23:43:15; VSync Disabled. Both test game sessions and both candidate sessions closed normally | Pass |

Native readbacks are produced by the actual Companion and corroborated by
visible reset/recovery transitions. An independent continuous native observer
was not running. No injected window manipulation or renderer access was used.
The Mainhand was visibly correct; full workspace panel placement was not audited.

## Evidence and cleanup

Private raw evidence is under ignored `dist/live-qa-rc3-20261101`: initial span,
both recovery cycles, control sequence, restart adoption, auto-span, preflight,
process launch metadata, addon inventory and cleanup records. Raw logs contain
local device/account metadata and must not be attached publicly without redaction.

No visible Lua error dialog appeared during the inspected steps. No
`_BugGrabber.lua` SavedVariables file was found in the inspected Anniversary
account tree, so there is no fresh BugGrabber error audit. Combat/taint safety is
not established by this run.

After normal exit, the exact pre-test Companion preference file and generated
topology bytes were restored from backups and hash-checked. VSync is `0`, the
original windowed size `2114x1353` was restored, and Battle.net remains open.
The Companion legitimately refreshed its generated ForeverState recovery bridge
after game shutdown; that generated state was retained rather than discarded.
No SavedVariables deletion, source deployment, Store change or publication occurred.

## Remaining release gates

- This exact artifact on Retail; no launchable Retail executable was found in the inspected installation.
- Routing correction from follow-up source review: Retail is installed at
  `D:/Games/World of Warcraft/_retail_`, executable `12.1.5.70688`, addon Beta 24.
  The earlier unsuccessful search covered the C: installation. Retail has not
  yet been launched with this candidate; its preflight backups are prepared.
- Era and final Forever acceptance; Forever remains deferred until the November 4 milestone and actual build confirmation.
- Reset recovery after an auto-applied span, explicit display-edit cancellation, hotplug, mixed DPI and Wine.
- `/reload`, character-swap and map/bag/chat/HUD persistence under the intended addon release.
- Protected actions, current taint/error evidence, rollback failure paths on real WoW and Store-channel runtime behavior.
- Sharpness comparison, original hang/error reports and schema 1 default-workflow acceptance remain separate.

Minor observation: production diagnostics repeat the word in messages such as
"Graphics graphics reset detected". This is cosmetic and was not changed in the
accepted artifact. Synthetic rollback/persistence/package checks retain their
existing evidence level; this test did not force a failed native span.

User follow-up: oversized game-options tooltips are tracked independently as
`OH-UI-OPTIONS-TOOLTIP-SCALE` in ISSUES.md. Companion acceptance here does not
claim tooltip correctness, and no tooltip behavior is changed in this artifact.
