# Offhand QA task list

Updated 19 November 2026 for the Forever integration branch. The shared addon baseline is Beta 36 (`f3dba2e`). The Discord comparison used the matched Test 7 addon and private Companion 2.1.8.8107. The Companion source in this checkout has its own 2.1.6 development identity. The installed Store build used for two-character QA was package 2.1.801.0.

## Original session

| Request | Current evidence and remaining work |
| --- | --- |
| Easier first map scaling and finer slider sensitivity | The working checkout has direct map settings, Auto Fit and fine adjustments. Try a first-run portrait layout and a short workspace. Check pointer drag, keyboard increments, bounds and reopen with native maps and OpenMap. |
| Theme labels and Studio opacity | Paired preset swatches and Studio-layer opacity are in the working checkout. Compare the label and rendered colour for each preset and check both opacity endpoints with a custom image and a built-in background. |
| XP bar under action bars | Beta 36 fits the generated XP and reputation anchors and preserves custom positions. The merged regression checks cover existing layouts and other visible bars. Capture the reported character’s actual XP owner and action bars if overlap persists. |
| Spoken addon placement | Identify the addon, frame and action that opens it. Capture the position with the native Talking Head and with Spoken enabled before choosing an owner-specific placement fix. |
| Block map and bag keybinds | Open. Specify whether the request is to prevent closing an already-open Offhand window or suppress opening as well. Test separate map and bag controls, controller ownership, explicit close, combat transitions and restoring bindings. |
| Shared profile visibility and numeric Edit Mode labels | Retest the picker on both characters. Record the displayed label, actual layout name and scope. Add account/character scope labels and a reviewed copy/reuse action for compatible HUD layouts. Keep Blizzard layout ownership intact. |
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

The donor's live bag receipt intentionally keeps its original fingerprints. Run `python scripts/check-compatibility.py` and the checker unit tests during development. Use `--require-fresh-live` after repeating the affected live checks. The original mixed-refresh observations are recorded in the shared knowledge project under `knowledge/offhand-mixed-refresh-map-report-20261117.md` for Forever 1.60.1.70938 and 1.60.1.70959.

