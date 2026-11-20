# Offhand QA task list

Updated 20 November 2026 for the Forever integration branch. The shared addon baseline is Beta 36 (`f3dba2e`). The Discord comparison used the matched Test 7 addon and private Companion 2.1.8.8107. The combined development candidate uses Companion 2.1.9 Beta 1 (Windows file version 2.1.9.1). The earlier Store comparison used package 2.1.801.0. The live results below use the paired development executable.

## Live acceptance with Companion 2.1.9 Beta 1

Use the Beta 36 QA ZIP and Companion in `dist/qa-companion-219-settings-trim/` for continued testing. The settings trim ZIP SHA-256 is `522093e60f84d0f19698f70dbffae19dcdd1f9015cf4b0e2bf7e459bdff77219`. The preceding numbered bag key ZIP SHA-256 is `57eac308a8946d51bdbb8e34e741a2fd27b48df90ead926bff712e41f13d129f`. The preceding book-fit ZIP SHA-256 is `c68d6957fd736c0ac94ff89f38e44a1bd872ad524f9faae7c9b000e3d42b73b5`. The preceding Mainhand chat ZIP SHA-256 is `e0299d639fb5097143e239e4731d560512120fab02fbdf9cc8aa23aa879dbfda`. The corrected standalone Companion executable has SHA-256 `24547fb66b0b6c2e7aaf8457593f15fc901e286e7fdcfccf7cc78189e5bc62e2`. The short-workspace panel ZIP SHA-256 is `b91d2b53636cdb33eaaaa8c8c227cea266b3af26682d8757ac166da1bff03cd3`. The preceding Spellbook ZIP SHA-256 is `357bd26964f38c25cca00f1636e2e3128e3710031585044330d28f829b8bcf25`. The preceding native map drop ZIP SHA-256 is `4b496024d2f8955a678a7617bbff58b2db3469a3b7baa55e44a68511234062bf`. The preceding Spoken Places ZIP SHA-256 is `dafc2856c63ac68e6da9c8aae2b4b92f63d2ecbb680fdb6ddbc974d4c07dd729`. The preceding reset confirmation ZIP SHA-256 was `afdd9dd8ad5c408c5dcf5cf778e9def372b2ef57028b4930f8a3428df4b147c5`. The preceding HUD chooser ZIP SHA-256 was `5c32ec8262ffb7146878396b8f7e8d7d197a571726e1f4c8ec2c02a6efa992e3`. The preceding HUD review ZIP was `6c66341c0743fb525a72b1e8377a768cdfc342f09535acfc3f3b69b65026c2bf`. The preceding map settings ZIP was `675b9cad017f790b716ba288c8520cc01dfa8b25bee6771c19ea5f43e5bc561a`. The preceding Gold trim ZIP was `d564d6d9013edf6ee101fc2af0e4362d94c07da1e1ecf949c2b9b4347e455bbd`. The preceding Companion executable SHA-256 is `08602635f061aa7d278dd8a74d6bc6aebbd0bf304e55d3fe1266d0f60bce4f66`. The preceding unpinned-map ZIP had SHA-256 `92df2079ab26a4e799fa670751d44a7b3bbaaa0ae277d7d4b0c957465172bb65`. The earlier map-slider ZIP had SHA-256 `d9e4de0bc2e153b4543fd33e972aec8f02fc3c48a0facabdd57ac40afd907728`. Prior addon ZIPs used for the expanded-map and programmatic scale checks had SHA-256 `9ff5c4d90f14c08b40ba79b3c8c733f7d86a9d336363b7abf203e56d1e61a28a` and `46e8f0fdb5abedb8fe57a29a5921ae4f05713e323f176fbfdae57efb787e798f`, respectively.

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

### Map setup and legacy Studio media on Moonweaver

On Forever 1.60.1.70959 with OpenMap 0.8.10 and Companion 2.1.9.1, the workspace-ready prompt opened World Map Scaling & Navigation. We set the pending prompt flag on an already configured character. With the page still open, selecting Dun Morogh (map 1426) made OpenMap report 100% and available, while the controls stayed disabled at 59%. With the corrected addon the controls showed 100% and enabled Auto-Fit on the stitched map. Clicking Auto-Fit saved 110.86% in OpenMap and rendered 110.86% on the frame. Returning to map 2521 disabled the controls on the open page. This exercises the handoff after setup. A new player's ability to discover and complete it still needs observation.

Edge rejected the Windows-built offline Studio's inline script because HTML parsing changed its line endings after hashing. With the corrected generator, Edge imported the installed schema-1 package and exported a four-file schema-2 package. The TGA bytes and image settings survived conversion. On the spanned client the same background pixel measured RGB (76, 73, 65) at 100%, (47, 45, 43) at 50%, black at 0%, and (47, 45, 43) again when restored to 50%. The saved setting remained 0.5 and the texture layer reported alpha 0.50196 after UI reload.

BugSack recorded zero new occurrences from session 577 through logout in 581. Companion restored the original 2130 × 1392 window at (215, 0). Cleanup verified all 144 backed-up files, including the original installed media, and the portable preferences.

### Reviewing a saved HUD from Profiles on 20 November

On Forever 1.60.1.70959 with Companion 2.1.9.1, Moonweaver opened Profiles with Default selected. Review offered “Offhand Main - Moonweaver”. Cancel kept layout 5 active. After switching to Modern (1), accepting the named layout restored 5 and it persisted through UI reload. On the final package we repeated the switch from Modern and verified the reload prompt identified the selected HUD correctly. Noggaholic Naux had native layout 6 active and no compatible Offhand record. Review offered Customize HUD or Later, and layout 6 remained active. The original account had no registered shared HUD. The follow-up below used a temporary account layout.

The regression fixture covers accepting a named account layout, a candidate changing while the confirmation is open, unchanged settings-profile selection, and zero native layout saves. The build-filtered knowledge query provided no runtime evidence. The installed-source preflight found 34 differences. QA preserved the original addon directory and verified the staged install against the clean candidate. BugSack gained zero occurrences from session 581 through logout in 585. Companion restored the 2130 × 1392 window at (215, 0). Cleanup verified the 98 original addon files, 33 settings files and portable preferences.

### Cross-character use of a registered account HUD on 20 November

On Forever 1.60.1.70959, Beta 36 with Companion 2.1.9.1, the QA fixture copied Moonweaver’s existing HUD into a temporary Blizzard Account layout named `Offhand (72)`. It checked the native account type and copied systems, then registered the layout for the current monitor geometry, input mode and HUD ownership. Both characters used the same account entry at native ID 5 on the same 4000 × 2560 span.

| Character | What Profiles offered | Result after accepting and reloading |
| --- | --- | --- |
| Moonweaver Noggaholic | With her original Offhand HUD record, Review offered only `Offhand Main - Moonweaver`. After temporarily setting aside that record and its standard-input entry, Review offered `Offhand (72)`. | Blizzard’s active layout and Offhand’s saved HUD both read `Offhand (72)`. The settings profile remained Default. |
| Noggaholic Naux | With his original Offhand records, Review offered `Offhand (72)`. | Blizzard’s active layout and Offhand’s saved HUD both read `Offhand (72)`. The settings profile remained Default. |

Cleanup removed the temporary layout and its registration. Moonweaver finished on `Offhand Main - Moonweaver` (5) and Naux on `Offhand Main - Noggaholic` (6). For both characters, the serialized native layout list, layout contents and active selection matched the snapshots taken before creation.

Moonweaver’s live API readback differed from the saved snapshot only in 14 floating-point values, by at most 4.55 × 10⁻¹³. After quitting, BugSack’s BugGrabber data showed zero new occurrences between sessions 585 and 593. The original 98 addon files, 33 saved settings files and portable Companion preferences matched their backups after restoration. The WoW window returned to its original bounds and the test helper was removed.

### Choosing personal and shared HUDs in Profiles on 20 November

On Forever 1.60.1.70959 with Beta 36 and Companion 2.1.9.1, **Profiles → Review saved HUD layout** listed compatible layouts by name with personal or shared account labels. The selected Blizzard layout had a filled radio button. Choosing a row opened a confirmation naming that layout. Selection used the existing native layout and kept the Default settings profile.

| Character | Starting state and live result |
| --- | --- |
| Moonweaver Noggaholic | Her existing personal Offhand record stayed in place. She chose the temporary account layout `Offhand (72)`, reloaded, saw the account layout still selected, and chose `Offhand Main - Moonweaver` again. |
| Noggaholic Naux | His original records offered only the account layout. Cancel kept the current selection. To exercise both choices, QA temporarily registered his existing native personal HUD for the tested span. Naux chose `Offhand (72)`, reloaded, then chose `Offhand Main - Noggaholic` from the same menu. |

Both original native layout lists, contents and active indices matched their saved snapshots after removal of the temporary account layout and registration. Moonweaver finished on slot 5 and Naux on slot 6. The 98 original addon files, 33 settings files and portable Companion preferences were restored and compared with their backups. BugSack recorded zero new Lua error occurrences between sessions 593 and 599. All 139 Lua suites and 10 compatibility-checker tests passed on the candidate.

### Original-list replay on Moonweaver, 20 November

Forever 1.60.1.70959 ran Beta 36 with the standalone Companion 2.1.9.1 named above. Before staging, the installed-source check reported 34 differences. The original install was parked intact. The corrected package passed the installed-source comparison, six manifest checks, 139 Lua suites and ten checker tests.

| Live action | Observation |
| --- | --- |
| Windows placement guide | On an already configured character, the placement page was legible windowed and on the full mixed-height span. Window is positioned, Reload UI, Confirm placement and Start Calibration led to the wizard. Companion exposed Windows Display Settings directly on Setup. The Windows arrangement stayed unchanged. |
| Start from defaults, then Reset | The prior reset prompt was active outside the visible Mainhand on this geometry. Fresh profiles start with Offhand disabled. The corrected addon uses its Mainhand confirmation for the profile action in this state. Cancel kept the temporary profile’s 31% opacity. Accept restored 95%. Default stayed at 95% and Blizzard layout 5 stayed selected. The temporary profile was removed. |
| XP on the standard span | At 902/4500 XP on layout 5, the visible tracking bar’s bottom was 79.30 and Action Bar 1’s top was 76.30 in UIParent coordinates. |
| Spoken 3.10.0 quest recording | Playing Constable Aonda’s “Welcome to Shen’dar Village” in the Compendium placed Subtitle, Small Window and Large Window wholly on Mainhand. The DialogueUI playback style required its uninstalled dependency. The original Subtitle setting was restored. |
| BetterBags 0.9.5 | B opened the backpack on Mainhand. After dragging it to Offhand, B kept it open. X closed it and released the override. B reopened it there. After dragging it back to Mainhand, B closed it. BetterBags owned the normal binding throughout this mixed-provider test. |
| Map on a physical 1440 × 600 Offhand area | At 100%, OpenMap 0.8.10 on Dun Morogh extended below the visible area. Clicking Auto-Fit saved and rendered 79.92%. With OpenMap disabled, dragging the native map to Offhand fitted it to 81.11%, leaving 12 UI units above and below. Clicking Auto-Fit retained that fit. Both map roots reopened at the fitted bounds. |
| Spoken Places 3.10.0 map panel | On the native map the attached Places panel extended past Offhand’s right edge. Live mouse focus identified `SpokenPlacesPanel` under `WorldMapFrame`. The installed provider’s `UI/MapPanel.lua` anchors it to the map’s right edge. Track fitting the open attachment or collapsing it separately from narrator placement. The original reporter’s frame is unknown. |

BugSack was checked by per-message occurrence counts at each checkpoint. The initial placement run added zero. During the first reset investigation a QA command treated the name returned by the popup lookup as a frame, adding one Lua error. The corrected probe, fixed reset, XP, Spoken playback, BetterBags, short span, both map-owner checks and final logout each added zero (saved sessions 601 through 611). BugGrabber history was retained. Companion restored the original 2130 × 1392 window at (215, 0). After normal exit, cleanup verified the 98 original addon files, all 97 backed-up settings files and the portable preferences.

### Spoken Places and tooltip replay on Moonweaver, 20 November

Forever 1.60.1.70959 ran Spoken Places 3.10.0 and the packaged Beta 36 addon with Companion 2.1.9.1. The physical Offhand area was 1440 × 600 in a 4000 × 1440 span. Its bounds in UIParent units were x = 0–1097.14 and y = 640–1097.14.

| Action | Final package observation |
| --- | --- |
| Drag the Blizzard map onto Offhand | The Places text, art and close button stayed visible. Where the provider’s right-side attachment overlapped the quest list, Places drew in front. The map and panel remained usable. |
| Click the Places X, then its reopen tab | The tab stayed inside the workspace and reopened Places. Closing and reopening the map, then reloading the UI, retained panel bounds x = 805.14–1097.14 and y = 652–1085.14. |
| Drag the map back to Mainhand | The map ended at x = 2708.35 and Places began at x = 2710.35. The panel released the workspace clamp and recovered the provider’s MEDIUM drawing layer. |
| OpenMap 0.8.10, Dun Morogh | At 100% the map was taller than the workspace. Its Places panel fitted the full available height from y = 640 to 1097.14. After Auto-Fit it sat beside the map, ending at x = 1076.46. |
| Compare action-bar and bag tooltips | With OneForAll 6.2.11’s cursor tooltip off, ActionButton2 showed Wrath near the lower-right of Mainhand. Earthroot appeared next to its BetterBags slot. With the cursor tooltip on, Wrath moved to the cursor and Earthroot kept the same bag-relative bounds. Both remained visible. The original OneForAll setting was restored. MoveAny and the reporter’s independent tooltip configuration were unavailable here. |

A native map drop near the top edge also put its title above the workspace while Places stayed within bounds. Reopening the map restored the saved position. A later traced drop rendered at the saved top of 1085.14 immediately. The native map drop replay below reproduced this on the first drag after reload.

BugSack was checked after each run. A pre-fix candidate logged one Offhand error 274 times while releasing the Places clamp. The corrected package added zero Offhand errors through logout in session 626. During a later drag investigation, a QA-only frame-reading command logged three errors in session 624. The repeated trace and logout added zero. The clean package passed 139 Lua suites, all six manifests and ten checker tests. The staged addon matched the candidate. Cleanup restored the original 2130 × 1392 window at (215, 0), all 98 installed addon files, 97 backed-up settings files and Companion preferences.

### Native map drop and window placement on Moonweaver, 20 November

Forever 1.60.1.70959 ran the paired Beta 36 addon and Companion 2.1.9.1 on the 1440 × 600 Offhand workspace. Its upper edge was y = 1097.14 in UIParent coordinates. All interactions were outside combat.

| Live interaction | Observation |
| --- | --- |
| First native map drop from Mainhand near the top of Offhand after reload | On the previous package, the map saved y = 1085.1 at 81.11% scale. A later anchor moved its visible top to 1203.7, where it stayed. On the corrected package, the release sample showed the same transient displacement. By the 80 ms sample the visible top matched the saved y = 1085.1 and stayed there, leaving 12 UI units above the map. |
| Grab the native title again, then reopen and reload | A second real drag moved the map from x = 212.8 to 101.5 without reopening. The title stayed at y = 1085.1. Closing and reopening with M, then reloading and reopening, retained the second position. |
| OpenMap 0.8.10 with OneForAll 6.2.11 window movement enabled | On Dun Morogh at 60%, the dragged map kept its top left at (155.72, 1018.40) after folding the quest list, closing and reopening with M, expanding the quest list and reloading. |
| Game Menu and AddOns on Mainhand | The Game Menu centered on Mainhand. Closing AddOns after dragging it returned to the centered menu. Reopening AddOns restored its dragged bounds (1638.67, 392.95)–(2238.67, 942.95). |
| Spellbook expand and collapse on Mainhand | With an existing Offhand position saved, both resize buttons moved the book back to Offhand within 100 ms. Its title ended at y = 1372.00, above the workspace. When QA temporarily cleared only the saved Offhand position, both buttons kept the book on Mainhand at (1363.00, 806.00) top left. The original record was restored. This leaves a reproducible Spellbook placement issue with OneForAll window movement enabled. |

BugSack’s per-message counts increased by zero at every checkpoint, from session 626 through logout in 642. The staged addon matched the candidate, which passed six manifests, 139 Lua suites and ten checker tests. Companion restored the 2130 × 1392 window at (215, 0). Cleanup verified the original 98 addon files, 103 saved settings files and portable Companion preferences against their backups.

### Spellbook resize with OneForAll on Moonweaver, 20 November

Forever 1.60.1.70959 ran Beta 36 with Companion 2.1.9.1 and OneForAll 6.2.11 window movement enabled. On the physical 1440 × 600 Offhand area, a trace showed the native resize re-showing the panel. Both OneForAll and Offhand restored it. Offhand's show and deferred anchor callbacks reapplied the old workspace position after OneForAll had restored the Mainhand drop. Skipping a size callback alone still reproduced the snap.

On the corrected package, the compact book initially had a saved Offhand x of 87.43. A real parchment drag transferred it to Mainhand at (1441.33, 917.33) top left and cleared the superseded workspace position. Clicking expand changed the width from 577 to 1154 UI units. Clicking collapse returned it to 577. Each kept the same top left in all four samples, from the next frame through one second. Closing and reopening with P, and reopening with P after UI reload, returned to the same Mainhand bounds.

Further out-of-combat checks on the same package found:

| Normal interaction | Live result and follow-up |
| --- | --- |
| Shift+P, close and reopen Collections | Both opens put the journal at x = 99.81–802.81 and y = 652.00–1258.00. The title exceeded the workspace top of 1097.14. Track oversized native windows restoring into short workspaces. |
| O for Social, then C for Character | Both opened on Offhand. Their rectangles overlapped from x = 530.24 to 722.36, and both titles exceeded the workspace top. Check recovery of saved workspace positions separately from the pending combat slot test. |
| L for Quest Log | The map and quest list opened on Offhand and extended below y = 640. The attached Spoken Places panel stayed within y = 640–1097.14. The reporter's quest window and opener remain unknown. |
| I for Group Finder | Moonweaver's binding resolved to Group Finder. No visible panel opened on this level-7 character. Repeat on an eligible character. |

BugSack showed zero new errors in the failed candidate, trace, and successful expand, collapse and reopen checks. A separate QA binding lookup after reload added one error in session 649 when it formatted an unbound action. The corrected lookup, all further panel checks and logout added zero in sessions 650–652. The original install differed from the test source in 36 files. The staged candidate matched the checkout and passed six manifests, 139 Lua suites and ten checker tests. Cleanup verified all 98 original addon files, 39 backed-up settings files and Companion preferences. Restore returned the window to (215, 0) at 2130 × 1392.

### Short-workspace panel and quest placement on Moonweaver, 20 November

The 1440 × 600 test uses a custom area of the physical 1440 × 2560 portrait display. Mainhand retains its full 2560 × 1440 area. Companion accepts 600 pixels as its minimum custom workspace height. On this span, the workspace occupies y = 640–1097.14 in UIParent units. Windows can extend outside those bounds while remaining inside WoW’s overall window.

Moonweaver Noggaholic ran Forever 1.60.1.70959, Beta 36 and Companion 2.1.9.1 with OneForAll 6.2.11. The following measurements came from physical keypresses, folds, reopens and drags outside combat.

| Check | Final candidate |
| --- | --- |
| Collections, Social and Character titles | All three native frames fit between y = 652.00 and 1085.14. Collections reopened at the same bounds. Dragging Collections to Mainhand restored 100% scale. Dragging it back applied the 71.48% short-workspace fit. |
| Social then Character | Character’s right-side tabs ended at x = 633.97. Social started at x = 641.97. |
| Character then Social | Character’s tabs ended at x = 713.33. Social started at x = 721.33. Both windows remained visible with the same eight-unit gap. |
| L with OpenMap 0.8.10 | At the existing 100% map scale, the quest panel bottom rose from 558.14 to 643.00 and the scroll area bottom from 567.14 to 652.00. Folding and reopening refitted the list. Moving the map to Mainhand restored the provider’s three-unit bottom offset. |
| L with the native map | After disabling OpenMap and confirming it had unloaded, a physical drag to Offhand fitted the map at 81.11%. Its quest panel bottom was 654.43 and scroll area bottom 661.73. |
| Full 1440 × 2560 portrait control | Collections, Character and Social opened at 100%. Character and Social occupied separate vertical areas. The first Standard span rolled back after WoW shrank its window. Reloading and retrying in Companion produced the expected 4000 × 2560 window, confirmed against the generated topology before testing. |

The exact-build knowledge query supplied no placement contract. On this client the quest panel had two right-edge anchors to WorldMapFrame. The fit adjusts its lower anchor and releases it on Mainhand. The OpenMap test retained the player’s map zoom. The reporter’s exact quest window and opener still need confirmation.

The install preflight found 36 differences. QA parked the installed addon and verified the clean candidate against the staged install. The candidate passed 139 Lua suites and ten checker tests. The working checkout passed 140 suites and the same checker tests. BugSack recorded zero new occurrences across checkpoints from session 652 through final logout in 674. Companion restored the original 2130 × 1392 window at (215, 0). Cleanup verified all 98 original addon files, 79 settings files and the portable Companion preferences.

### Character and Social through combat, and Companion dashboard rendering

Moonweaver Noggaholic ran Forever 1.60.1.70959 with the addon ZIP from `901ed01` and Companion 2.1.9 Beta 1 on the 1440 × 600 workspace. The native Character panel opened first, followed by Social. The player handled the fight. A temporary read-only observer sampled visible frame bounds, including Character’s right-side tabs, between the actual PLAYER_REGEN_DISABLED and PLAYER_REGEN_ENABLED events. It collected 127 samples. Both windows stayed visible in every sample. The minimum separation was 8.000 UI units. At entry, exit and one second afterward, Character’s tab strip ended at x = 713.33 and Social began at x = 721.33. The client reported false for InCombatLockdown() in both event callbacks. This run exercised panels opened before combat. Opening or dragging panels during lockdown requires a separate test.

On the standalone Companion, expanding the Advanced card exposed the Store update label at its default location behind Workspace and Startup. The client dropdown had a native height of 28 pixels in a 26-pixel row at 100% Windows scaling. The corrected build respects the Store-only label’s visibility and sizes the row to the native control. With Forever selected, the heading was clear and the bottom border visible. Opening and dismissing the dropdown retained the selected client. Span and Restore returned the client to its original rectangle at (215, 0), size 2130 × 1392. The border remained visible after the client exited. The WinForms layout suite passed at 100%, 125%, 150%, 175% and 200%. Store update presentation and both native client-selector architectures passed their separate regression tests.

BugSack gained zero occurrences from session 674 through final exit in 678, with checkpoints after setup, combat, the dashboard replay and exit. One post-combat screenshot failed to save and a later harness command lost foreground focus. The combat measurements above came from the character’s saved trace. The later input was excluded from panel acceptance. The original 98 addon files, 79 settings files and portable Companion preferences were verified after cleanup, and the previously running Store Companion was relaunched.

The Social-first reopen check was repeated on Moonweaver with the corrected Companion executable. Window-targeted O and C keys opened the panels. A temporary observer recorded their bounds directly in the client. With Social alone its left edge was x = 530.24. Opening Character moved Social to x = 641.97, leaving 8.000 UI units beyond Character’s tab edge at x = 633.97. Both panels stayed within y = 652.00–1085.14 on the 1440 × 600 workspace. BugSack gained zero occurrences from session 678 through logout in 679. Cleanup removed the observer, restored the original install, settings and window, and restarted the Store Companion. The earlier combat trace remains the evidence for the player-driven fight.

### Primary chat outside its configured display on the short workspace

Reproduced on the preceding candidate on Moonweaver, Forever 1.60.1.70959 with Companion 2.1.9.1 and the 1440 × 600 workspace. The active settings reported Mainhand (`GAME`), chat docking enabled, no saved ChatFrame1 workspace position and no detected replacement chat addon. The live message frame anchored to UIParent’s bottom-left, at x = 53.3–662.3 and y = 56.8–856.8. Mainhand began at x = 1097.1. Offhand’s visible area began at y = 640.0, so only the upper part of the frame intersected it. The input box was entirely below Offhand at y = 22.8–54.8, including after opening chat with Enter. The primary frame was shown at full opacity. The trace establishes the final anchor and leaves its writer unresolved. Acceptance requires the primary frame and edit box to be reachable on the configured display while respecting deliberate workspace placements. BugSack gained zero occurrences between sessions 679 and 680. Original settings and the game window were restored.

The corrected Beta 36 candidate passed on the same desk with Companion 2.1.9.1. Closing both Character and Social reproduced the original failure. Re-enabling native screen clamping with Mainhand insets still left chat at x = 53.3. Applying a temporary offset to the native root anchor moved the entire dock. The messages stayed 609 × 800 UI units. Their left edge moved to x = 1150.4, and the input occupied x = 1145.4–1775.4, y = 22.8–54.8 on Mainhand (x = 1097.1–3047.6). Enter focused the input at full opacity with both panels closed and with both open on Offhand. No text was sent. UI reload and a cold Moonweaver login repeated the result. Restore Window returned chat to x = 53.3 in the original single window, and Span WoW Now moved it back to x = 1150.4 without a reload.

With L opening Map & Quest Log on Offhand, the focused edit box stayed on Mainhand. Further panel checks remain open on this level-7 character. Y was bound to the Legacy System and Achievements had no key assigned. Invoking the native Achievements toggle and pressing I (bound to Group Finder) both yielded no visible panel for measurement. Existing regression coverage now also exercises deliberate reachable workspace placements, Edit Mode, ownership changes and replacement chat. Combat and third-party chat rendering were outside this live run.

BugSack gained zero error occurrences across sessions 680–691, including the interim clamp attempts, window transitions, cold login, panel probes and final exit. Cleanup removed the temporary observer, restored the original 98-file addon and 79 backed-up settings files, verified portable Companion preferences, and restarted the Store Companion.

### Achievements and Group Finder eligibility on Forever

The live selector offered Moonweaver Noggaholic (level 7) and Noggaholic Naux (level 1). Nogg Tester appeared in older local settings only. Both available characters ran the packaged addon from `30ce240` with Companion 2.1.9.1 on Forever 1.60.1.70959. The 1440 × 600 Offhand measured x = 0–1097.1 and y = 640–1097.1 in UIParent units.

| Panel | Live result on both characters | Remaining placement check |
| --- | --- | --- |
| Group Finder | I was bound to Group Finder. The button was disabled. The client reported Vanilla-style groups enabled, denied premade-group access and gave level 10 as the unlock. Pressing I left `LFGParentFrame` hidden. | On a character with premade-group access, press I and measure the visible `LFGParentFrame`, its tabs and close control. |
| Achievements | The native Achievements toggle opened no panel. The global disable rule was off, both characters had Legacy renown 0, and the Legacy button indicated that the first character must reach level 25. | On an account with Legacy unlocked and positive Legacy renown, open Challenges and measure `LegacySystemFrame` with its Challenges page selected. |

The exact-build Blizzard UI source confirms both frame owners and the checks used by the entry points. The owner moved both checks to post-release on 20 November. Verify placement when an eligible character becomes available and hotfix if needed. [Group Finder toggle](https://github.com/Gethe/wow-ui-source/blob/3d8abb1da73acd38e412e24fb3f99454a6392346/Interface/AddOns/Blizzard_GroupFinder_VanillaStyle/Blizzard_LFGVanilla_ParentFrame.lua#L122) · [Forever Achievements toggle](https://github.com/Gethe/wow-ui-source/blob/3d8abb1da73acd38e412e24fb3f99454a6392346/Interface/AddOns/Blizzard_AchievementUI/Camelot/Blizzard_AchievementUI.lua#L3) · [Legacy Challenges page](https://github.com/Gethe/wow-ui-source/blob/3d8abb1da73acd38e412e24fb3f99454a6392346/Interface/AddOns/Blizzard_LegacySystem/Blizzard_LegacySystem.lua#L81)

BugSack gained zero occurrences on Moonweaver's Achievements check (692–693), Moonweaver's Group Finder replay (694–695), Naux's Achievements check (696–697), and Naux's Group Finder check (697–698). The first Moonweaver run added one blocked-action entry in session 694 when the temporary QA addon attempted logout. The replay used the native Game Menu after the diagnostic logout button was removed. Final logout and exit through session 699 added zero occurrences. The original window dimensions, installed addon, and 79 backed-up settings files were restored and the Store Companion restarted.

### Reachable panels on Moonweaver's short workspace

Out-of-combat replay on Moonweaver Noggaholic, level 7, on Forever 1.60.1.70959. The committed development branch at `dd25635` used the same Beta 36 packaged runtime as `30ce240` with Companion 2.1.9.1. The physical 1440 × 600 Offhand occupied x = 0–1097.1 and y = 640.0–1097.1 in UIParent units. The following bounds describe the settled state.

| Panel and action | Result |
| --- | --- |
| Professions, K, drag from Mainhand to Offhand | Reproduced on the preceding build. The window opened fully on Mainhand. After the drop the 594-unit-high root occupied y = 652–1246. Its title reached 1245 and its close button reached 1249. The clipping persisted after reload and K close/reopen. Escape opened the Game Menu and left Professions open. This is the profession book, separate from the external profession-bag report. |
| Spellbook, P, reopen on its saved Offhand placement | Reproduced on the preceding build. The 720-unit-high single-page book occupied y = 652–1372. The title reached 1371 and the close button 1375. Reproduced with Communities present and with it closed. The earlier Mainhand expand/collapse acceptance still covers a different interaction. |
| Map & Quest Log, L, select “A Little Beauty” | The quest list settled at y = 652–1072.1. The details pane occupied y = 646–1071.1 with the scroll region at 675–1028.1. Back, rewards and the lower controls were visible after folding Spoken Places. The underlying map at the character's saved scale extended down to y = 555.1. The result covers the quest UI. |
| Guild & Communities, J, drag to Offhand, open and close Spellbook | The root stayed at x = 147.8–961.8 and y = 652–1078. The close control reached y = 1081. The side tabs fit and the position survived UI reload. |
| Native Raid tab | Opened inside Social on Offhand. The root occupied y = 652–1085.1 and the close control reached 1087.1. The character was outside a raid. |
| Chat Settings | Opened fully on Mainhand at x = 1699.9–2444.9 and y = 376.1–981.1. An attempted title drag left it there. |
| Talents and Encounter Journal | N opened no talent panel. The native Talents button was disabled and reported unlock level 10. The key lookup listed Shift+J for Encounter Journal, but the reverse lookup returned no action, the native toggle was absent and no journal opened. The open guild panel was identified independently as Communities. There are no Journal placement measurements. |

BugSack gained zero occurrences at every checkpoint across sessions 699–710, including the final exit. Cleanup verified the original 2130 × 1392 window at (215, 0), the installed addon and 79 backed-up settings files. The diagnostic addon was removed and the Store Companion restarted. Achievements and Group Finder remain deferred.

### Professions and single-page Spellbook fit on Moonweaver

On Forever 1.60.1.70959, Moonweaver dragged each native book from Mainhand to the top of the physical 1440 × 600 Offhand with OneForAll enabled and Companion 2.1.9.1. The first candidate fitted Professions on drop, then yielded when reload reset it to its original 100% scale. The corrected candidate recognizes that reset for both books. Dragging either back to Mainhand restored 100%.

| Panel | Offhand scale | Root y | Title y | Close button y |
| --- | ---: | ---: | ---: | ---: |
| Professions | 72.92% | 652.00–1085.14 | 1069.83–1084.41 | 1066.91–1087.33 |
| Single-page Spellbook | 60.16% | 652.00–1085.14 | 1072.51–1084.54 | 1070.10–1086.95 |

All three rectangles stayed within the workspace at each settled checkpoint after drag, UI reload and explicit reopen. Both visible close buttons worked. K and P restored the respective books to their saved bounds. One intermediate sample on P reopen caught the Spellbook lower on the screen before its saved placement applied. Its title and close button were inside Offhand in that sample too.

BugSack gained zero occurrences for Professions drag, reload and reopen (715–718), Spellbook drag, reload and reopen (718–721), and final exit (721–722). The earlier diagnostic runs (710–715) also added zero. The staged runtime matched the clean candidate, which passed 139 Lua suites and ten checker tests. Restore returned the original window to (215, 0) at 2130 × 1392. Cleanup verified the 98 original addon files, 79 backed-up settings files and portable preferences, removed the observer and restarted the Store Companion.

### Spoken DialogueUI playback and map and bag bindings on Moonweaver

On the book-fit candidate from `c1d7ca1`, Moonweaver used Forever 1.60.1.70959, Companion 2.1.9.1, Spoken 3.10.0 and the physical portrait Offhand. For this test we loaded the author's Forever-compatible Dialogue UI package. CurseForge labels file 9666149 as 1.0.7 d. The archive's own TOC says 1.0.7 c and includes interface 16001. [Author's release](https://www.curseforge.com/wow/addons/dialogueui/files/9666149)

The temporary replay control used Spoken's quest player to play Constable Aonda's recorded offer for “Welcome to Shen'dar Village” (quest 92514). Spoken reported the active clip and displayed `SpokenDialogueUIPlayerFrame`. The separate NPC dialog was hidden. The narrator initially fit on Offhand at x = 20.4–432.7 and y = 1795.1–1931.0. Dragging the visible narrator onto Mainhand moved it to x = 1474.1–1886.4 and y = 589.0–724.9. Replaying the same recording after UI reload reproduced all four bounds. BugSack added zero occurrences at login (722–723), first playback (723–724), drag (724–725) and replay after reload (725–726).

With both keep-open settings enabled, M opened the compact map on Offhand. B opened BetterBags 0.9.5 on Mainhand. Dragging BetterBags to Offhand switched B to Offhand's temporary binding. M and B both kept their respective windows open on repeat. The observer confirmed both overrides and both visible roots at the checkpoint. BugSack added zero occurrences (726–727).

Moonweaver's first fight lasted 20.40 seconds between the regeneration events. At entry the compact map was open on Offhand, BetterBags was closed, and M still had Offhand's override. The next sample, 0.18 seconds later, showed lockdown active and M back on Blizzard's map toggle. During lockdown BetterBags opened on Offhand, the map closed, and BetterBags closed. Both windows were closed at combat exit and their regular bindings were active. The game had restarted before the fight, which discarded the temporary F11 assignment. F11 resolved to BetterBags throughout this fight. After the checkpoint reload, M and B reopened both windows on Offhand and kept them open on repeat. BugSack added zero occurrences through the restart, fight and subsequent M/B replay (727–730).

In a subsequent fight both Offhand overrides were active at entry with the compact map and BetterBags open. By the next sample 0.09 seconds later, lockdown was active, M belonged to Blizzard and B belonged to BetterBags. The map closed and reopened during lockdown. Both windows were visible and both overrides had returned at combat exit, 21.68 seconds after entry. F11 retained the expanded-map assignment through this fight. BugSack added zero occurrences at the next checkpoint (730–731).

In the final 49.76-second fight, the observer recorded an actual call to the expanded-map action with combat and lockdown both true. F11 left the map compact at its original Offhand bounds. M then closed the map and B closed BetterBags. After combat, before any reload, the same keys reopened both windows on Offhand and kept them open on repeat. F11 expanded the map onto Mainhand and returned it to the same compact Offhand rectangle on the second press.

BugSack recorded zero new occurrences at the observer setup checkpoint (731–732), the final fight and same-session replay (732–733), and client exit (733–734). The test Companion restored the restarted client to a 2560 × 1392 window. QA then restored and measured the original 2130 × 1392 window at (215, 0). Cleanup verified all 98 original addon files, 81 backed-up settings files and portable preferences, removed the temporary observer and Dialogue UI, and preserved BugSack history.

### Live NPC subtitles and numbered bag keys on Moonweaver

On Forever 1.60.1.70959 with Companion 2.1.9.1, the player opened Indari Sunseam’s gossip window. Spoken 3.10.0 began reading the NPC automatically 0.18 seconds after the window opened. On the standard portrait span, the native gossip window measured x = 1903–2241, y = 304–800. The Subtitle player measured x = 1842.6–2303.5, y = 957.2–1038.1. Both fit on Mainhand with 157 UI units of clearance between them. The native Talking Head stayed hidden.

With replacement inventories disabled and keep-open enabled, pressing the first numbered key closed the native combined backpack on Offhand on the previous candidate. Forever’s bindings map the four numbered actions to bag IDs 4, 3, 2 and 1. The fix follows Blizzard’s choice of window for each bag ID before deciding whether to intercept that key.

On the corrected candidate, F6 opened the closed backpack. All four numbered keys then kept it at x = 145–575, y = 1191–1370 on Offhand. The close button released the keys and F9 reopened it. Moving the backpack to Mainhand released the override. The native numbered key closed and reopened it at x = 1690.1–2120.1, y = 454.2–633.2. The reagent key retained its native action throughout. In separate-bag mode all five keys retained their native actions and none opened a separate window. All four equipment slots were empty. Occupied separate windows have regression coverage and still need a live character for acceptance.

BugSack recorded zero new occurrences at every checkpoint from login through exit (sessions 734–745). Companion restored the measured original 2130 × 1392 window at (215, 0). Cleanup verified all 98 original addon files, the 81 backed-up settings files, portable preferences and preserved BugSack history. The QA observer was removed.

### Naux’s first-time setup, profile reset and settings border

On Forever 1.60.1.70959, Noggaholic Naux started with temporary empty Offhand account and character data. The development Companion 2.1.9.1 showed its four-step tour. Its alignment step explained Identify, dragging the displays and Apply. Windows Display Settings was visible on Setup. Following an initial server disconnect, the retry reached the in-game welcome guide after closing the release notes. The placement page explained display height and touching edges. Span WoW Now, Window is positioned, Reload UI and Confirm placement led to calibration. Completing the seam, scale and HUD steps and reloading opened the workspace-ready prompt. Its World Map Scaling & Navigation button opened the correct settings. Opening Dun Morogh enabled the controls and Auto-Fit displayed 111% on the portrait workspace.

Profiles created “Naux QA copy” with the current Slate settings. Its reset prompt named the profile, warned about all characters using it and explained that Blizzard manages Edit Mode layouts separately. Cancel preserved Slate. Accept restored defaults for that profile. Loading Default brought back Slate. “Start from defaults” created “Naux QA fresh” with Classic Gold, and the saved HUD stayed listed across the profile changes. This was a guided functional test on an existing character with isolated first-run data. Independent new-player comprehension remains a separate usability question.

The settings window was using a flat two-unit edge for every preset. The final candidate keeps the settings background and controls and applies the preset’s edge artwork and size to the outer frame. On Naux, Classic displayed the 32-unit dialog edge tinted Gold, RGB (1.000, 0.820, 0.000). Selecting Silver changed its visible tint. Slate displayed the 14-unit tooltip edge at RGB (0.722, 0.749, 0.780) and retained it after reload and reopening. Resetting the selected Slate test profile restored the Classic outer edge immediately. All five preset edge definitions and tints passed the controls-refresh regression.

BugSack recorded zero new occurrences across sessions 746–755, including the disconnect, setup, profile changes, final border replay and exit. Cleanup removed the temporary generated HUD, confirmed the original “Offhand Main - Noggaholic” layout at index 6, and restored the original installed addon (98 files), 81 backed-up settings files, diagnostic probe and portable preferences.

## Original session

The subsequent unpinned-map, Mainhand keybind and canvas appearance runs added zero BugGrabber error occurrences from session 543 through 555, including final logout. The original window rectangle, installed media, portable preferences and 158 backed-up files were verified after cleanup. The temporary diagnostic addon was removed from the client.

| Request | Current evidence and remaining work |
| --- | --- |
| Easier first map scaling and finer slider sensitivity | Physical drag, focused keyboard adjustment, typed input, limits and reopen passed with OpenMap and the pinned Blizzard map. The unpinned Mainhand lower bound passed separately on the corrected package. In a simulated 1000 × 300 workspace, a 160% request fitted a 600-unit-high map to the 276 usable units. The workspace-ready button opened this page on Moonweaver, and the visible controls followed map availability. Both map roots fitted the physical 1440 × 600 custom area and reopened at the fitted scale. Naux followed the first-run guide directly to Auto-Fit. Independent first-time player discovery remains open. |
| Theme labels and Studio opacity | Classic Gold, explicit Silver and the Pitch Black trim passed on Forever as detailed above. Forged Brass produced a brass border and blue fill. Slate and Obsidian shared the charcoal and silver palette with different border artwork. Both Classic and a schema-2 Studio export visibly disappeared at 0% and returned at 100%. Re-exporting the installed schema-1 image in the corrected offline Studio produced a schema-2 package. That image passed the 100%, 50%, 0% and reload checks. |
| XP bar under action bars | Beta 36 fits the generated XP and reputation anchors and preserves custom positions. The merged regression checks cover existing layouts and other visible bars. Moonweaver’s visible XP bar cleared Action Bar 1 by 3 UI units on the spanned client. Capture the reported character’s actual XP owner and action bars if overlap persists. |
| Spoken addon placement | On Moonweaver, Spoken 3.10.0's Subtitle, Small Window and Large Window previews fit entirely on Mainhand. The DialogueUI preview opened on the portrait Offhand. Dragging it to Mainhand persisted through closing the preview and reloading. Spoken owns that position. The native Talking Head existed but stayed hidden during all four previews. Recorded quest playback also passed for the first three styles. Recorded DialogueUI playback and its saved Mainhand position also passed on the portrait span. Automatic Subtitle playback also passed during a live conversation with Indari Sunseam. The reporter’s intended frame and display remain unknown. The separate Spoken Places map attachment passed the 1440 × 600 boundary, fold, reopen and Mainhand return checks on the corrected package. |
| Block map and bag keybinds | OpenMap and Bagnon passed on the physical Offhand. With both keep-open settings active, dragging the visible Bagnon inventory from Offhand to Mainhand restored the native B binding. On Mainhand, pressing B and M closed Bagnon and the Blizzard map. BetterBags also passed the physical B-key sequence with multiple providers loaded. On Moonweaver, both M and BetterBags' B yielded their keep-open overrides in lockdown and reacquired them at combat exit with both windows open on Offhand. All four numbered keys passed with the native combined backpack on the portrait Offhand. Separate windows for equipped bags still need a character with bags in those slots. |
| Shared profile visibility and numeric Edit Mode labels | Both native pickers showed named account and character layouts on the paired build. Profiles now labels account-wide settings, the character’s selection and its saved HUD by name. Profiles now offers **Review saved HUD layout**. Players see the compatible layout’s name before selecting it for their character. Moonweaver passed live reactivation. The Profiles chooser passed on Forever. Moonweaver and Naux could select either compatible HUD by name, reload on the shared HUD, and select the personal HUD again. Naux’s two-choice run used a temporary personal Offhand record. |
| Profile selection after switching characters | GUID-matched legacy and all-character recovery is in the branch. Cold-launch recovery passed in both directions with distinct shared settings profiles and character HUD names on the paired build. See the [two-character test record](FOREVER-PROFILE-LIVE-QA-20261118.md). |
| Expanded/compact map hotkey | Passed on the physical portrait Offhand on Noggaholic Naux, outside combat. In Keybindings → Offhand, assign “Toggle expanded map (return to compact map on Offhand)”. With F11 temporarily assigned, both Blizzard’s map and OpenMap 0.8.10 expanded. A second press, Escape and the map’s close button each returned the compact map to Offhand. Escape kept the Game Menu closed. Closing the compact map itself kept it closed, and M reopened it in compact mode. An OpenMap window at 150% on Mainhand fitted to 110.86% on return to Offhand. The player-driven Moonweaver replay verified the guarded F11 action in lockdown and the expand/compact round trip after combat. Other clients retain separate acceptance. |
| Professions bag opens on Offhand when combined bags open on Mainhand | External player report, clarified 20 November. The bag name, inventory addon and detached window are unknown. The native combined backpack reopened on Mainhand in local QA. Naux and Moonweaver both had empty equipped bag slots, so the specialty-bag case remains open. To reproduce, use a character with the same bag and inventory addon, open combined bags on Mainhand and record which window appears on each display. |
| Shorter Companion tutorial and prominent Windows display settings | The packaged 2.1.9.1 dashboard showed four steps on a fresh preference file. Each action was enabled and keyboard-focusable, Finish was remembered on relaunch, and Windows Display Settings was visible on Setup. The source layout suite covers 100–200% scaling. |
| Website Studio entry | Passed on the deployed website. The homepage link opened Background Studio. Edge exported a four-file media ZIP and the Studio successfully re-imported it. |
| Donation buttons | Companion links to the website support section with the Ko-fi action. The deployed homepage has the Ko-fi link. Its footer still needs the QA branch’s `id="support"` to make the packaged `/#support` link scroll to it. The project’s addon policy keeps donation requests outside the game. |
| Clear/reset guidance | The candidate’s Profiles panel fixture displayed “Copy current settings” and “Start from defaults”. The wizard uses “Create Mainhand HUD Layout”. Opening Reset identified the selected profile, every character using it, and Blizzard Edit Mode’s separate layouts. Opening the prompt caused zero resets. Changing the active profile before acceptance also caused zero resets. Accepting a fresh prompt for the current profile called Reset once. Fresh-profile help and shared reset copy are present in all eleven locale files. The corrected reset confirmation passed physical Cancel and Accept checks on Moonweaver. Naux passed copy, start-from-defaults and reset in the isolated first-run replay. Independent first-time player comprehension remains a usability check. |
| In-game centre line | The Display settings button and `/offhand centerline` control the same guide. Show/hide and live HUD scale changes passed on Naux’s mixed-height desk. |
| In-game Windows monitor arrangement | The placement page now explains Identify, dragging numbered displays, matching height and touching edges, and Apply in all eleven locales. The guide was readable windowed and spanned on the local desk. The physical button sequence reached calibration. The affected player’s Windows arrangement and first-run comprehension remain open. |

### Isolated bag providers and Spoken previews

On the 4000 × 2560 span with Companion 2.1.9.1, the following windows were visible on Noggaholic Naux. Each isolated run loaded only the named bag provider and its dependencies. The mode column records the observed Blizzard `combinedBags` setting.

| Bag provider | Mode | Result |
| --- | --- | --- |
| Blizzard | Separate | The backpack opened as `ContainerFrame1` on Offhand. |
| Blizzard | Combined | `ContainerFrameCombinedBags` moved from Offhand to Mainhand by dragging its title. After UI reload, pressing B reopened it on Mainhand. |
| BagSmith 1.9.0 | Separate and combined | `BagSmithFrame` opened on Mainhand in both runs. |
| ArkInventory 31217 | Separate and combined | `ARKINV_Frame1` appeared on Mainhand in both modes. |
| Bagnon 12.1.11 with BagBrother | Separate | `BagnonInventory1` opened on Offhand. |

If one key opens two inventory windows, repeat with one bag provider enabled and compare the titles. To reposition Spoken's DialogueUI narrator, enable Preview in Spoken's settings, unlock the window if needed and drag the sample to the desired display. On Moonweaver the dragged frame returned to the same Mainhand bounds after UI reload.

BugSack recorded nine occurrences from the temporary diagnostic addon during setup. Seven came from inspecting a forbidden frame and two from formatting an absent anchor name. The corrected probe inspected named frames and handled missing values. From session 566 through final logout in 577 the counters increased by zero. The test client closed normally. Companion restored the original window rectangle, and cleanup verified all 187 backed-up files and the portable preferences.

## Game Menu chat

| Source | Integrated work | Remaining check |
| --- | --- | --- |
| Offhand PR 128, `5ee1586` | OpenMap drag persistence with OneForAll, visible party invite on Mainhand in combat | The owner independently verified in-combat invites on 20 November. No taint trace was supplied with that functional result. The 20 November replay verified map drag persistence through quest-panel changes, reopen and reload. |
| Offhand PR 129, `d5235ab` | Bag Escape priority, explicit B/Shift-B close, vendor ownership and native/replacement bag regression tests. Donor live evidence includes an NPC conversation and inspection. | Repeat the compatibility matrix on the exact combined package, including OneForAll on/off where relevant, equipped bags 1–4, flight-master interaction, actual flight and combat/control loss. Reproduce invisible Mainhand bag opening on the reporter’s geometry. Preserve stock fear/control-loss handling. [Compatibility matrix](COMPATIBILITY.md) |
| Offhand PR 130, `30c804c` | Combat panel placement candidate. Expanded Spellbook, Account Collections and Social passed the donor’s out-of-combat checks. Both Character/Social opening orders and the L quest list also passed on the 1440 × 600 workspace outside combat. | Open expanded Spellbook and Collections in combat. Character and Social stayed separate through a player-driven fight when opened before combat. Opening panels during combat and checking Talents on an eligible character remain pending. The [Professions and single-page Spellbook retest](#professions-and-single-page-spellbook-fit-on-moonweaver) passed drag, reload and reopen outside combat. The quest list and details passed. Encounter Journal lacked a working entry point. Group Finder and Achievements moved to post-release follow-up as recorded in the [Forever eligibility check](#achievements-and-group-finder-eligibility-on-forever). |
| Tooltip and quest reports | Hover diagnostics and mixed-height geometry are available. | The local Wrath and Earthroot tooltips were visible with OneForAll cursor positioning off and on. Repeat with the reporter’s MoveAny and independent tooltip settings. Identify the exact quest window and opener. |
| OneForAll | Game Menu and AddOns centering and Spellbook resize jitter belong to OneForAll. Its AddOns fix is `d885434`, Spellbook fix `af4d762`. | Track review and combined testing in that repository. Game Menu and AddOns passed on the combined candidate. The Spellbook resize replay above verified the Mainhand drop through expand, collapse, reopen and UI reload with window movement enabled. |

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
| 100 | `8a42e813` | Integrated the standard-first workspace chooser, custom-area opt-in and localized setup help with the four-step dashboard tour. Naux verified the first-run handoff with fresh Offhand data and the development Companion. |
| 103 | `382a5e8b` | Updated CodeQL initialization to 4.39.3. |
| 104 | `f4515cc8` | Updated CodeQL analysis to the same upstream commit. |
| 105 | `55d0fa92` | Updated all five release-action uses on this branch to 3.0.4. All four dependency PRs were checked against upstream tag commits. Hosted workflow execution remains pending. |
| 107 | `7d0c87ac` | Integrated the Window is positioned → Reload UI → Confirm placement → Start Calibration handoff. Verified frozen Companion 2.1.5 artifacts independently of newer source, including rejection of altered artifacts and publication from historical mode. |
| 128 | `5ee15865` | Complete patch already present. Map drag persistence passed on the 20 November candidate. The owner independently verified the in-combat invite on 20 November. |
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
