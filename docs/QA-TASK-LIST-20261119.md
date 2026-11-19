# Offhand QA task list

Updated 19 November 2026 for the Forever integration branch. The shared addon baseline is Beta 36 (`f3dba2e`). The Discord comparison used the matched Test 7 addon and private Companion 2.1.8.8107. The combined development candidate uses Companion 2.1.9 Beta 1 (Windows file version 2.1.9.1). The installed Store build used for two-character QA was package 2.1.801.0.

## Original session

| Request | Current evidence and remaining work |
| --- | --- |
| Easier first map scaling and finer slider sensitivity | The working checkout has direct map settings, Auto Fit and fine adjustments. Try a first-run portrait layout and a short workspace. Check pointer drag, keyboard increments, bounds and reopen with native maps and OpenMap. |
| Theme labels and Studio opacity | Paired preset swatches and Studio-layer opacity are in the working checkout. Compare the label and rendered colour for each preset and check both opacity endpoints with a custom image and a built-in background. |
| XP bar under action bars | Beta 36 fits the generated XP and reputation anchors and preserves custom positions. The merged regression checks cover existing layouts and other visible bars. Capture the reported character’s actual XP owner and action bars if overlap persists. |
| Spoken addon placement | Identify the addon, frame and action that opens it. Capture the position with the native Talking Head and with Spoken enabled before choosing an owner-specific placement fix. |
| Block map and bag keybinds | Separate opt-in settings keep the keyboard from closing a map or inventory on Offhand. A closed window opens through its existing binding. Forever live input results are below. Repeat on physical Mainhand/Offhand rectangles, check combat transitions, and extend provider coverage. |
| Shared profile visibility and numeric Edit Mode labels | Retest the picker on both characters. Record the displayed label, actual layout name and scope. Profiles now labels account-wide settings, the character’s selection and its saved HUD by name. Add a reviewed copy/reuse action for compatible HUD layouts. Keep Blizzard layout ownership intact. |
| Profile selection after switching characters | GUID-matched legacy and all-character recovery is in the branch. Recheck cold launch and switching in both directions on the combined package with distinct shared preferences and character HUD names. See the [two-character test record](FOREVER-PROFILE-LIVE-QA-20261118.md). |
| Expanded/compact map hotkey | Open. Define close/reopen behaviour for both sizes, verify native and OpenMap dispatch, then expose a bindable action. |
| Professions bag follows Offhand with combined bags on Mainhand | Capture the detached frame and its owner on both displays. Verify native bags, BagSmith and ArkInventory separately, with combined and separate bags. |
| Shorter Companion tutorial and prominent Windows display settings | Four-step tutorial and Setup display-settings action are present. Check at 100–200% DPI in the intended Companion build with keyboard navigation. |
| Website Studio entry | Direct Background Studio link is present in the working checkout. Check the deployed destination and the custom-canvas download workflow. |
| Donation buttons | Companion links to the website support section with the Ko-fi action. Check the packaged link. The project’s addon policy keeps donation requests outside the game. |
| Clear/reset guidance | Fresh-profile controls and reset copy are present in the working checkout. Verify that creating preferences and rebuilding a character HUD have distinct labels and that a shared reset explains who it affects. |
| In-game centre line | Display settings and `/offhand centerline` use the same Mainhand guide. Verify mixed heights and scale changes, and hide it from the other entry point. |
| In-game Windows monitor arrangement | The placement page now explains Identify, dragging numbered displays, matching height and touching edges, and Apply in all eleven locales. Check readability and actual physical placement on the affected desk. |

## Game Menu chat

| Source | Integrated work | Remaining check |
| --- | --- | --- |
| Offhand PR 128, `5ee1586` | OpenMap drag persistence with OneForAll, visible party invite on Mainhand in combat | Accept an actual invite during combat and inspect blocked actions and taint. Reopen the map after dragging and after quest-panel changes. |
| Offhand PR 129, `d5235ab` | Bag Escape priority, explicit B/Shift-B close, vendor ownership and native/replacement bag regression tests. Donor live evidence includes an NPC conversation and inspection. | Repeat the compatibility matrix on the exact combined package, including OneForAll on/off where relevant, equipped bags 1–4, flight-master interaction, actual flight and combat/control loss. Reproduce invisible Mainhand bag opening on the reporter’s geometry. Preserve stock fear/control-loss handling. [Compatibility matrix](COMPATIBILITY.md) |
| Offhand PR 130, `30c804c` | Combat panel placement candidate. Expanded Spellbook, Account Collections and Social passed the donor’s out-of-combat checks. | Open expanded Spellbook and Collections in combat. Check Social overlapping Character through combat end and Talents on an eligible character. Extend coverage to Professions, Quest Log, Group Finder, Achievements and Encounter Journal. |
| Tooltip and quest reports | Hover diagnostics and mixed-height geometry are available. | Compare a failing action-bar hover with a working bag hover. Isolate MoveAny tooltip settings, OneForAll cursor tooltip and the independent tooltip addon. Identify the exact quest window and opener. |
| OneForAll | Game Menu and AddOns centering and Spellbook resize jitter belong to OneForAll. Its AddOns fix is `d885434`, Spellbook fix `af4d762`. | Track review and combined testing in that repository. Reopen Game Menu, drag and reopen AddOns, then expand/collapse Spellbook with Move Blizzard windows enabled. |

## Discord mixed-refresh chat

| Scenario | Remaining check |
| --- | --- |
| Sharpness, framing and 60 FPS on the affected desk | Fridell’s 3440×1440 100 Hz Mainhand and left 1080×1920 60 Hz Offhand are the acceptance setup. Use a stationary scene and fixed camera. Capture restored, immediately after spanning and after reload, without recalibration. Record centre line, full diagnostics, render scale, AA, VSync and FPS. Compare Standard with the 1080×1440 custom slice separately. The local 4000×2560 check exercised the viewport refresh and did not reproduce the blur. |
| Map/HUD positioning and misleading remembered-window warning | Repeat map drag, close and reopen with the reporter’s actual map provider. Compare Blizzard Modern and the generated Mainhand HUD, including a changed Windows vertical offset. Verify same-size changed display rectangles ask for one placement review. |
| Standard re-span and Companion notifications | Confirm rollback restores an unclipped window on a genuine shrink. Check the persistent Span failed card and delivery of one background/tray failure warning on the combined executable. Check dashboard height and tray flash at multiple DPI scales. |
| Reload guidance and acknowledgement | Try same-layout restore/re-span, a first span with WoW already open, a changed layout and a real failed span. Check localized Reload UI, guide and dismiss actions. A future “Layout loaded” message should require verified current geometry. A delayed General.log receipt may retire a matching normal reminder only. Check stale/rotated logs and simultaneous clients before enabling automatic dismissal. |
| Native Companion and release | Run the actual candidate executable through monitor hotplug, mixed DPI, restore and dashboard flows. Compare with the Store baseline and test signed install/update/rollback separately. Package the merged addon, repeat live interaction and profile tests on those exact bytes, and record the hash and compatibility receipt before promotion. |

## Companion development baseline

The combined branch uses the four-monitor development source published at `eb733b3` and the native DPI clipping and restore fixes from `1be38f8`. The earlier `companion/develop` tip (`f53bab9`) is already in its ancestry. This candidate keeps the Forever character recovery bridge, selected-client window protection, Standard re-span checks, four-step tour, and span-failure guidance from the QA branch.

Use the standalone development executable with the addon ZIP built from the same QA commit for the remaining tests. Four-monitor layouts have generated-bridge coverage for schemas 2 and 3. Physical monitor hotplug, mixed-refresh spanning, and switching characters on the paired build still need live acceptance. The Store package remains the comparison build.

## Combined candidate

The addon-only QA ZIP for source commit `76bbecf` is `dist/integrated-forever-qa-20261119/Offhand-v2.1.5-beta.36-qa.76bbecf.zip` (SHA-256 `17078a80cb174e2714b29d907766c72d6c726dca1226f0e3a6a52959b899fbcf`). Its files match the clean source checkout. All six manifests, 138 Lua suites, ten checker tests and the multi-character recovery fixture passed there. Fourteen focused suites passed against the extracted addon. The current working tree also passed its 139 Lua suites, including its additional local window-selection coverage.

## Keyboard acceptance on Forever 1.60.1.70959

On Moonweaver Noggaholic, the regular map action owned M and BetterBags owned B. An isolated test addon supplied workspace or Mainhand as the location result. WoW dispatched the real keys to the installed map and inventory providers.

| Action | Observed result |
| --- | --- |
| Press M and B with both windows closed | World Map and BetterBags Backpack opened. |
| Press both again with workspace ownership | Both remained visible. |
| Click each window's X | Both closed. WoW reported the original map and BetterBags bindings again. |
| Press both keys again | Both reopened. |
| Switch the location result to Mainhand and press both keys | Both closed normally. |

The client was out of combat on an unspanned desktop. A subsequent optimization reuses the location while a visible root's bounds and scale stay unchanged. The regression covers a drag and restoration of the vendor binding. Physical display routing, rapid input after moving a window, equipped bag hotkeys, other provider versions and combat still need the packaged-client pass. The temporary probe was removed after the client closed.

The all-DPI fixture now locates startup delay on Advanced and checks the current action row. The integrated dashboard passed at 100%, 125%, 150%, 175% and 200%.

The donor's live bag receipt intentionally keeps its original fingerprints. Run `python scripts/check-compatibility.py` and the checker unit tests during development. Use `--require-fresh-live` after repeating the affected live checks. The original mixed-refresh observations are recorded in the shared knowledge project under `knowledge/offhand-mixed-refresh-map-report-20261117.md` for Forever 1.60.1.70938 and 1.60.1.70959.

## Development baseline after PR review

On 19 November 2026, all 13 open Offhand PR heads were incorporated into the local branch `addon/forever/gamepad-reports-20261105`. The combined source commit is `fe09a62`. Each PR is a merge parent. Resolutions apply its reviewed changes to the QA branch while retaining the branch's newer implementations and release identities.

| PR | Reviewed head | Resolution and remaining acceptance |
| --- | --- | --- |
| 18 | `d80c3150` | Retained Beta 36's native Gamepad guards and layout generation. Added separate keyboard and Gamepad HUD preferences, migration for a named legacy controller layout and the public secure Mainhand anchor. Repeat input-style switching, panel reopening, targeting and taint checks on Forever with the packaged addon. |
| 19 | `011717a6` | Verified existing process-path fallback, display identity review and per-process auto-span retry suppression. The historical Beta 22 CI artifact and version stamps were superseded. Still needs the reporter's Wine/XWayland setup. |
| 43 | `60a3e019` | Updated the Lua setup action to 13.1.0 in the active CI job. |
| 45 | `48de023a` | Existing status-chain repair and regression cover a custom Retail Action Bar 1 attached to default XP/reputation containers. Repeat on the affected Retail mixed-height setup. |
| 100 | `8a42e813` | Integrated the standard-first workspace chooser, custom-area opt-in and localized setup help with the four-step dashboard tour. Verify the first-run handoff on a fresh profile. |
| 103 | `382a5e8b` | Updated CodeQL initialization to 4.39.3. |
| 104 | `f4515cc8` | Updated CodeQL analysis to the same upstream commit. |
| 105 | `55d0fa92` | Updated all five release-action uses on this branch to 3.0.4. All four dependency PRs were checked against upstream tag commits. Hosted workflow execution remains pending. |
| 107 | `7d0c87ac` | Integrated the Window is positioned → Reload UI → Confirm placement → Start Calibration handoff. Verified frozen Companion 2.1.5 artifacts independently of newer source, including rejection of altered artifacts and publication from historical mode. |
| 128 | `5ee15865` | Complete patch already present. Repeat map-drag persistence and an actual combat invite on the combined bytes. |
| 129 | `d5235ab8` | Complete patch already present. Refresh real Escape, equipped bags, flight and combat receipts. |
| 130 | `30c804c2` | Complete patch already present. Repeat combat panel placement and post-combat restoration. |
| 131 | `de6188b2` | Integrated running-client selection on the dashboard. Standard re-span verification follows the selected process, creation time and window even with another client open. Exercise span, restore, a closed selection and a second running WoW client on the same installation. |

The local checks cover six manifests, 138 Lua suites on committed source, 139 in the working checkout, ten compatibility-checker tests and the Forever character-recovery bridge. Native tests covered the chooser, display selection, dashboard DPI, workspace profiles and rollback. The client-selection tests used two real Windows test windows on each architecture. The Forever 1.60.1.70959 knowledge query for the secure positioning handler yielded no build-specific runtime assurance. The anchor fixture uses the existing restricted handler on simulated frames. Combat and taint acceptance remain live checks.

Local clean-source builds are in `dist/pr-baseline-fe09a62/`.

| QA artifact | SHA-256 |
| --- | --- |
| `Offhand-v2.1.5-beta.36-qa.fe09a62.zip` | `a8c0882aba779bfbf1a38b05c06f365d1e7cc9af370093f10f4c9ffe9bd0dd0a` |
| `Offhand.exe` (Companion 2.1.6.1 development build) | `f12571c7abe90efb7d7eff7d8193c51ade177d41863b70ca929d252975e97587` |

All 98 archive members matched the clean source checkout, all six manifests resolved inside the archive and seven focused suites passed on the extracted addon. The installed Store Companion and production release targets were outside this local integration.
