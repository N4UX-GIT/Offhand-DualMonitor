# Forever Discord test.2 local live verification

Verified 2026-11-05 on the release Forever client, WoW 1.60.1 build 70790,
using an available level 1 Orc Shaman on the current realm. No realm/account
switch, movement, combat, loot, quest progress or public chat was performed.

## Installation

- Updated `C:/Games/World of Warcraft/_forever_/Interface/AddOns/Offhand`
  from `Offhand-v2.1.2-beta.26-forever-discord.test2.zip`.
- Addon ZIP SHA256:
  `46FFA54BFA0521D30AE85F7410C8F44BFCDEA1F7C5E9F10A4DF959B57042C696`.
- Previous installed Beta 21 folder is backed up under
  `C:/Games/World of Warcraft/_offhand_deploy_backups/forever-discord-test2-20261105-140200/Offhand`.
- Preserved installed generated `Core/CompanionTopology.lua` and
  `Core/ForeverState.lua` during deployment. SavedVariables were backed up and
  not reset. The released Beta 20 Companion subsequently refreshed its generated
  files normally for the current display arrangement.
- The old `D:/Games/World of Warcraft/_classic_beta_` installation was not changed.
- Final integrity check matches all 75 non-generated packaged files, including
  the six restored manifests. The two generated files are intentional exceptions.

## Observed results

| Check | Result | Evidence and limits |
| --- | --- | --- |
| Release client loads candidate | Pass | Entered world on level 1 Shaman; Offhand and map addons loaded. |
| Companion detects candidate and spans WoW | Pass | Companion verified test.2 and spanned the 4000x2560 canvas, with 2560x1440 Mainhand and 1440x2560 workspace. |
| Character HUD handoff | Pass for prompt and Later | Card appeared on Mainhand after span. It correctly reported no compatible saved HUD layout and offered Customize HUD/Later. |
| Later persistence | Pass across reloads | Card stayed quiet and character SavedVariables contain `choice="later"`, `gamepad=false` and the display signature. Reuse and Customize completion were not exercised. |
| Leatrix workspace map survives Escape | Pass | Disabled only OpenMap for the test character and reloaded. Opened map with M. Read-only telemetry reported `shown=true`, `workspace=true`, `owner=LeatrixMaps`. Escape opened Game Menu while the map remained shown at the same bounds. |
| Leatrix later-open observer | Pass | M closed the map, M reopened it, then Escape again opened Game Menu without closing the workspace map. |
| Reload restores external workspace map | Pass with restored OpenMap combination | Restored OpenMap, reloaded, and observed the workspace map shown with `owner=OpenMap`. |
| OpenMap workspace Escape | Pass | With both original map addons enabled, Escape opened Game Menu while the map remained shown on the workspace. |
| Captured Lua/protected-action errors | No new recorded errors | BugGrabber message/time/counter records exactly match the three historical baseline entries. |
| Taint log comparison | Unchanged, limited evidence | Length remains 5968 bytes and timestamp remains 2026-10-22. This is not a claim of complete taint safety or proof that every action was logged. |

The UI capture exposed only the primary monitor while WoW spanned both displays.
A temporary local `Core/LiveQA.lua` was therefore appended to the installed
manifests. Its addon-owned overlay and bounded character log read native map
visibility, position, workspace classification, external owner, Escape registry
membership and Game Menu visibility. It did not move/show/hide the map, replace
native scripts, or invoke panel actions. M and Escape were hardware-style UI
inputs. This is native-client state observation, with secondary map pixels not
visually inspected. The recorder source and resulting character data are retained
only in the local evidence directory.

## Cleanup and outstanding acceptance

OpenMap's original enabled state was restored. WoW exited normally. Original
manifests were restored, the temporary observer file and its live character
SavedVariables field were removed, and the Companion process started for this
run was stopped. Battle.net and unrelated applications were preserved.
The test character retains the intentionally tested Later choice.

Still pending: genuinely fresh account/profile onboarding and placement handoff;
HUD customization/reuse; cold relaunch; external drag between workspace/Mainhand;
live persistence-option changes while open; map pin interaction/sharing;
Gamepad mode transitions/menu/loot; combat/taint; French/narrow wrapping.
Zygor was not installed, so its rendering failure remains unverified.
This run does not establish broad release acceptance or reporter acceptance.

Local evidence: `dist/live-forever-20261105-140200/`. This includes the deployment
receipt, pre/post diagnostics and settings, read-only recorder, recorded map
transitions, error comparison, and final package integrity check. Raw diagnostic
files remain local because they can contain character/account context.
