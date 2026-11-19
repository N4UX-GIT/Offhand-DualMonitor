# Offhand QA task list

Updated 19 November 2026 for the Forever integration branch. The shared addon baseline is Beta 36 (`f3dba2e`). The Discord comparison used the matched Test 7 addon and private Companion 2.1.8.8107. The combined development candidate uses Companion 2.1.9 Beta 1 (Windows file version 2.1.9.1). The earlier Store comparison used package 2.1.801.0. The live results below use the paired development executable.

## Live acceptance with Companion 2.1.9 Beta 1

Use the Beta 36 QA ZIP and Companion in `dist/qa-companion-219-gold-trim/` for continued testing. The addon ZIP SHA-256 is `d564d6d9013edf6ee101fc2af0e4362d94c07da1e1ecf949c2b9b4347e455bbd`. The Companion executable SHA-256 is `08602635f061aa7d278dd8a74d6bc6aebbd0bf304e55d3fe1266d0f60bce4f66`. The preceding unpinned-map ZIP had SHA-256 `92df2079ab26a4e799fa670751d44a7b3bbaaa0ae277d7d4b0c957465172bb65`. The earlier map-slider ZIP had SHA-256 `d9e4de0bc2e153b4543fd33e972aec8f02fc3c48a0facabdd57ac40afd907728`. Prior addon ZIPs used for the expanded-map and programmatic scale checks had SHA-256 `9ff5c4d90f14c08b40ba79b3c8c733f7d86a9d336363b7abf203e56d1e61a28a` and `46e8f0fdb5abedb8fe57a29a5921ae4f05713e323f176fbfdae57efb787e798f`, respectively.

On Forever 1.60.1.70959 the two-character test used this same executable with the preceding Beta 36 addon ZIP from `dd1725e` (SHA-256 `f96c024783286f6970810924b12c0b26992d11d98d034217ae4ebcedb59ab9b6`). The executable produced the recovery file after WoW exited. The generated monitor geometry was retained when staging each addon.

| Last character to exit WoW | First character after restart | Offhand profile restored | Selected native Edit Mode layout |
| --- | --- | --- | --- |
| Noggaholic Naux | Moonweaver Noggaholic | QA219 Moon | Offhand Main - Moonweaver (5) |
| Moonweaver Noggaholic | Noggaholic Naux | QA219 Naux | Offhand Main - Noggaholic (6) |

Both cold logins reported `source=companion-bridge` and `bridgeCharacter=used`. Both could see the other shared settings profile. Both native dropdowns displayed the shared `DaylightUI - DPS/Tank` row by name. The generated Main layouts appeared in their corresponding character sections. Naux also had a named Pad layout. The reported numeric picker entries did not reproduce on either character.

On the local 2560 × 1440 Mainhand and 1440 × 2560 portrait Offhand, Standard span changed the original window at (215, 0), size 2130 × 1392, to (-1440, -1114), size 4000 × 2560. The full window persisted through reload. Restore returned the exact original rectangle and Naux retained profile QA219 Naux and layout 6. The centre-line slash action showed the Mainhand guide, and the Display settings button handler hid it. Real M and B keypresses opened OpenMap and Bagnon on the physical Offhand, kept them open on repeat, and reopened them following an explicit close. These checks ran outside combat. The reporter's mixed-refresh hardware remains outstanding.

The installed addon, generated files, Offhand account/character settings, native layout files and portable Companion preferences were restored after the run. Private evidence remains under the ignored `dist/forever-219-live-1795052566718/` directory. The shared knowledge query returned general persistence guidance for this build. The observations above came from the running client.

On the subsequent `76e2400` run, OpenMap 0.8.10 owned the visible world map on the physical portrait Offhand. The map settings API reported a 5 percentage-point step. Setting 115% updated both the live frame and OpenMap’s saved scale. Auto Fit calculated 110.86%, and closing and reopening the map preserved that value. The control was unavailable while the stitched map was closed. Restore returned the original window rectangle, and all 144 backed-up files and the portable preferences passed verification after cleanup.

### Map slider and BugSack replay on 19 November

On Noggaholic Naux, the previous OpenMap slider moved from 100% to 120% on a 60-pixel drag, and Up in the focused percentage field had no effect. On the 4000-pixel span, that drag produced 18 cursor-coordinate units. The revised map rail samples the physical travel through release. Up and Down in the percentage field move by one provider step, and Shift multiplies the step by five. The following results came from live input outside combat.

| Interaction | Blizzard map pinned to Offhand | OpenMap 0.8.10 on Offhand |
| --- | --- | --- |
| Drag 60 pixels right from 100% | 120% | 110% |
| Press Up, then Shift+Up | 121%, then 126% | 115%, then 140% |
| Enter 113% and reopen | 113% | 115% |
| Enter a value below the minimum | 50% saved and rendered | 50% saved and rendered |
| Enter a value above the maximum | 250% saved, 152.87% rendered to fit the portrait display | 160% saved and rendered |

The unpinned Blizzard map initially failed the same lower-bound check. A live trace on Naux showed the Mainhand fit applying 50% while the anchor still held offsets from the preceding 200.96% fit. At those offsets the smaller map temporarily fell inside the portrait workspace. Restore measured it again, applied the workspace’s 152.87% Auto Fit, then anchored it on Mainhand. The Mainhand placement now passes its known destination to the fit. A regression exercises the settings and restore paths together.

On a fresh Forever process with the corrected package, clicking the 250% preset still fitted the map to 200.96% on Mainhand. Entering 10% in the percentage field then saved and rendered 50%. The visible map stayed at 50% through reopen, UI reload and a full client restart. Both position records remained empty and the workspace preference stayed on Auto Fit. An earlier in-place reload still showed the old result. The acceptance measurement used a cold launch with the candidate installed.

BugSack reads captured errors from the account’s `!BugGrabber.lua`. The prior centre-line, bag and map QA sessions 515, 516, 518 and 525 contained 15 distinct QA-command errors with 17 occurrences. The commands were truncated or called missing helpers. Earlier history also contained an Offhand bag diagnostic error involving EllesmereUI and a forbidden SpellStopCasting action attributed to Offhand in the Escape/Game Menu path. The current bag diagnostic guards the optional addon. Neither error recurred in the final replay. An older QA probe also attempted the protected RunBinding action. The saved entries cannot identify which error sounded the alert.

During this investigation, six failed diagnostic commands added 13 occurrences in sessions 533 and 540. After replacing those commands, the per-message counters did not increase from the end of session 540 through logout in session 543. On that replay, M and B opened OpenMap and Bagnon on Offhand and kept both open on repeat. Explicit close restored the original bindings, and both keys reopened their windows. F11 expanded the map and Escape returned it to compact on Offhand with the Game Menu closed. The visible centre line stayed on the same 2560 × 1440 Mainhand rectangle while the HUD changed from 70% to 56% and back. Restore returned the original window. All 149 backed-up files and the portable preferences matched after cleanup. BugGrabber history was retained.

### Gold and Silver trim on Forever

The earlier Classic Gold check missed a white tint on the native dialog border. With the corrected addon, clicking Classic Warcraft or its Gold swatch on Noggaholic Naux applied RGB (1.000, 0.820, 0.000) to the canvas, settings window and header. Clicking Silver changed all three to (0.722, 0.749, 0.780). Switching back to Gold and reloading the UI preserved the selection and tint. Pitch Black applied its default Silver swatch and accepted an explicit Gold selection.

The canvas screenshots also show the rendered difference. At pixel (101, 8) on the same 4000 × 2560 span, the Classic border measured RGB (125, 119, 117) in the earlier Gold run, (125, 98, 0) in the corrected Gold run and (90, 89, 92) with Silver selected. BugSack recorded zero new occurrences from session 555 through final logout in 558. Companion restored the original window rectangle. All 131 backed-up files and the portable preferences matched after cleanup.

## Original session

The subsequent unpinned-map, Mainhand keybind and canvas appearance runs added zero BugGrabber error occurrences from session 543 through 555, including final logout. The original window rectangle, installed media, portable preferences and 158 backed-up files were verified after cleanup. The temporary diagnostic addon was removed from the client.

| Request | Current evidence and remaining work |
| --- | --- |
| Easier first map scaling and finer slider sensitivity | Physical drag, focused keyboard adjustment, typed input, limits and reopen passed with OpenMap and the pinned Blizzard map. The unpinned Mainhand lower bound passed separately on the corrected package. In a simulated 1000 × 300 workspace, a 160% request fitted a 600-unit-high map to the 276 usable units. First-run discovery and a physically short workspace remain open. |
| Theme labels and Studio opacity | Classic Gold, explicit Silver and the Pitch Black trim passed on Forever as detailed above. Forged Brass produced a brass border and blue fill. Slate and Obsidian shared the charcoal and silver palette with different border artwork. Both Classic and a schema-2 Studio export visibly disappeared at 0% and returned at 100%. The installed legacy schema-1 image was unavailable to this build. |
| XP bar under action bars | Beta 36 fits the generated XP and reputation anchors and preserves custom positions. The merged regression checks cover existing layouts and other visible bars. Capture the reported character’s actual XP owner and action bars if overlap persists. |
| Spoken addon placement | Identify the addon, frame and action that opens it. Capture the position with the native Talking Head and with Spoken enabled before choosing an owner-specific placement fix. |
| Block map and bag keybinds | OpenMap and Bagnon passed on the physical Offhand. With both keep-open settings active, dragging the visible Bagnon inventory from Offhand to Mainhand restored the native B binding. On Mainhand, pressing B and M closed Bagnon and the Blizzard map. Combat transitions and other providers remain open. |
| Shared profile visibility and numeric Edit Mode labels | Both native pickers showed named account and character layouts on the paired build. Profiles now labels account-wide settings, the character’s selection and its saved HUD by name. Add a reviewed copy/reuse action for compatible HUD layouts. Keep Blizzard layout ownership intact. |
| Profile selection after switching characters | GUID-matched legacy and all-character recovery is in the branch. Cold-launch recovery passed in both directions with distinct shared settings profiles and character HUD names on the paired build. See the [two-character test record](FOREVER-PROFILE-LIVE-QA-20261118.md). |
| Expanded/compact map hotkey | Passed on the physical portrait Offhand on Noggaholic Naux, outside combat. In Keybindings → Offhand, assign “Toggle expanded map (return to compact map on Offhand)”. With F11 temporarily assigned, both Blizzard’s map and OpenMap 0.8.10 expanded. A second press, Escape and the map’s close button each returned the compact map to Offhand. Escape kept the Game Menu closed. Closing the compact map itself kept it closed, and M reopened it in compact mode. An OpenMap window at 150% on Mainhand fitted to 110.86% on return to Offhand. Combat and other clients have separate acceptance. |
| Professions bag follows Offhand with combined bags on Mainhand | Capture the detached frame and its owner on both displays. Verify native bags, BagSmith and ArkInventory separately, with combined and separate bags. |
| Shorter Companion tutorial and prominent Windows display settings | The packaged 2.1.9.1 dashboard showed four steps on a fresh preference file. Each action was enabled and keyboard-focusable, Finish was remembered on relaunch, and Windows Display Settings was visible on Setup. The source layout suite covers 100–200% scaling. |
| Website Studio entry | Passed on the deployed website. The homepage link opened Background Studio. Edge exported a four-file media ZIP and the Studio successfully re-imported it. |
| Donation buttons | Companion links to the website support section with the Ko-fi action. The deployed homepage has the Ko-fi link. Its footer still needs the QA branch’s `id="support"` to make the packaged `/#support` link scroll to it. The project’s addon policy keeps donation requests outside the game. |
| Clear/reset guidance | The candidate’s Profiles panel fixture displayed “Copy current settings” and “Start from defaults”. The wizard uses “Create Mainhand HUD Layout”. Opening Reset identified the selected profile, every character using it, and Blizzard Edit Mode’s separate layouts. Opening the prompt caused zero resets. Changing the active profile before acceptance also caused zero resets. Accepting a fresh prompt for the current profile called Reset once. Fresh-profile help and shared reset copy are present in all eleven locale files. First-time player comprehension remains a usability check. |
| In-game centre line | The Display settings button and `/offhand centerline` control the same guide. Show/hide and live HUD scale changes passed on Naux’s mixed-height desk. |
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

Use the standalone development executable with the addon ZIP built from the same QA commit for the remaining tests. Four-monitor layouts have generated-bridge coverage for schemas 2 and 3. Physical monitor hotplug and the reporter’s mixed-refresh desk still need live acceptance. The two-character cold-start and local span results are recorded above. The Store package remains the comparison build.

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
