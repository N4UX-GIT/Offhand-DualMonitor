# Beta 38 out-of-combat retest on Forever

Tested Moonweaver on Forever 1.60.1.71037 with the public CurseForge ZIP (file 9729081, Offhand 2.1.5-beta.38) and Store Companion 2.1.9-beta.2 (2.1.901.0). The ZIP SHA-256 was `cd211e925fcb986ce915eeb5296ec6e1cbbabec9d04bd330c3648940aa31c70d`. The installed add-on matched the release for the runs. OneForAll was active. The two physical displays were 2560 × 1440 and 1440 × 2560.

## Bags

| Configuration | Observed on the public package |
| --- | --- |
| Blizzard separate bags | Start with only the backpack open on Offhand, an empty target and the pointer away from its X. Press Escape. The Game Menu opens. The backpack hides and shows again in the same timestamp, and the previously closed Simple Leather Satchel opens too. A second Escape dismisses the menu. Reproduced with OpenMap disabled and enabled. Disabling both the B keep-open setting and Escape persistence still produced the hide/show sequence. |
| Blizzard separate backpack X | Clicking the visible X closed the backpack. The open satchel snapped to the game's lower-right bag anchor. That put it on Mainhand in the original monitor arrangement. Switching the monitor assignments also changed which display contained that anchor. |
| Blizzard combined bag | With the pointer away from the X, Escape opened the menu and produced the same hide/show sequence. A physical click on the X closed the bag and it stayed closed. With the pointer parked over the X after reopening, Escape closed the bag. Invoking the button in Lua with the pointer elsewhere gave a different result and does not represent a mouse click. |
| Baganator 862 with Syndicator 291 | In both Single and Category views, the backpack stayed visible on Offhand through Escape with keep-open enabled and search unfocused. The Game Menu opened and closed with no hide/show events on the Baganator window. Both views reopened after reload when left open. With search focused, the first Escape was consumed by search. In Category view, disabling B keep-open allowed B to close and reopen the bag. Disabling Escape persistence allowed Escape to close it. |

The occupied backpack slot tested allowed pickup and return with the item and count preserved. A short combined-bag title drag delivered drag-start and drag-stop events but did not establish sustained movement. Inventory interaction, window movement and window dismissal are different interpretations of the reported lock. Only the dismissal and satchel placement problems were reproduced conclusively.

The native recovery path in `Core/CanvasForeverBags.lua` can call `OpenAllBags()`. That fits the extra satchel appearing. A fix should preserve which individual bags were open and distinguish a physical X close from Escape. The observed footprint differs from Baganator’s own backpack window.

## Map and loading screen

- With the Blizzard map alone, leaving it open on Offhand across `/reload` restored it to the same position. Closing it before reload kept it closed.
- With OpenMap 0.8.10, M opened the compact map on Offhand. After `/reload` it stayed closed in two runs, including one starting with the Game Menu closed. On Forever, the externally positioned map branch in `Core/Canvas.lua` preserves an already visible map and skips opening a hidden one. This result covers reload. The reporter's meaning of “open by default” at a fresh login is still unknown.
- In a single window, the native loading artwork and progress bar fit. Spanning the unequal monitors produced cropped artwork on the primary display, including when that display was assigned to Offhand. The in-world view returned to its assigned display after loading. Only the primary monitor was captured at a time. This limitation was previously documented in the README. The tester's earlier working ZIP was unavailable for direct comparison.

BugSack recorded no new production add-on errors in the valid runs. An early Baganator run produced errors in the temporary QA observer when it selected a text region. Both views were repeated with the actual backpack window observed. Combat was excluded. The original client add-ons, test-character settings, bag mode and Companion display assignment were restored after testing.

## Discord build comparison and candidate

The archived `Offhand-Forever-Discord-QA-178bf64.zip` contains the Beta 36 QA add-on. Its map, native bag, viewport and seam-redirection sources matched commit `178bf64`. The outer ZIP SHA-256 is `58cfb67d4ebcf881dfd8c7f9de9f1f6b8aaa908e0319c5ecc486ee69ff3799b1`. The Store Companion and physical display arrangement were held constant across these comparisons.

| Check | Discord build | Local candidate based on Beta 38 |
| --- | --- | --- |
| OpenMap open on Offhand before reload | Reopened at (16, 1483). The released Beta 38 left it closed. | Reopened at (16, 1483). Closing the map before reload kept it closed. Only the native open request is issued. OpenMap retains placement and scale. |
| Escape with native bags and an empty target | Both open separate bags hid and immediately reopened as the menu appeared. | With persistence enabled, the menu opened and closed without hiding the backpack or opening the closed satchel. The combined bag also stayed visible for both presses. With persistence disabled, the separate backpack closed once and stayed closed. |
| Close the separate backpack while the satchel is open | Public Beta 38 had returned the satchel to the default corner. | A physical click on the backpack X moved the surviving satchel into the backpack's Offhand spot. A satchel-only reload restored it to that spot with the backpack still closed. |
| Baganator 862 | Single view stayed open through both menu presses. | Both Single and Category views stayed open, without a hide/show event, while the Game Menu opened and closed. |
| Loading artwork | Cropped on the primary monitor during a spanned reload. | The released Beta 38 showed the same symptom with the same Companion. No add-on loading-screen change was made. |

An intermediate menu implementation using `ShowUIPanel` still hid the bag on Forever. Opening the Game Menu directly passed the same live sequence. The valid candidate runs above recorded zero current-session BugSack errors. These checks cover out-of-combat use. The earlier Inspect and gossip evidence has a different source fingerprint.

### Discord package check

The packaged add-on `forever-bag-map-qa1` (SHA-256 `81399a72fc7411344cf1d53cd732fe9fc516c53ef7bd999eef51f19921ee1b7b`) was installed for a final out-of-combat check. With only the separate backpack open on Offhand, Moonweaver targeted herself. Three physical Escape presses cleared the target, opened the Game Menu and closed the menu in order. The backpack had no hide event, the satchel stayed closed, and a reload restored only the backpack. The recorder saw zero current-session BugSack errors. This run did not repeat NPC gossip or inspection of another player.

The Discord bundle includes that add-on ZIP and the published Companion 2.1.9-beta.2 portable ZIP. The portable executable and the tested Store executable matched by SHA-256. All 99 add-on archive entries were checked against the Beta 38 inventory. The differences were the three intended Lua modules and the six QA-labeled manifests.

### Pitch Black trim on November 22

Moonweaver tested `forever-bag-map-qa2` on Forever 1.60.1.71037 with Store Companion 2.1.9-beta.2. The spanned game capture was 4000 × 2560. In Appearance, the test selected the Pitch Black canvas at 95% opacity, then selected Gold and Pitch Black in the trim row. The two game screenshots show a gold edge around the portrait workspace in the first capture and a black edge blending into the canvas in the second. The section headings, selection marks, opacity value and slider thumb remained visible. The live border and fill both read RGB (0, 0, 0), and the trim section heading read approximately (0.82, 0.82, 0.82).

BugSack had zero current-session errors before the comparison, after each selection and after restoring Moonweaver’s original Gold trim and Midnight Navy canvas. The pre-test add-on files were restored and the local observer was removed. The QA2 bundle includes the same portable Companion as QA1. The add-on archive SHA-256 is `b4ab5ccb1cfa5c5db713b777ca0648d2d558fd76044c19630bab37a6c0c6b244`. The Discord bundle SHA-256 is `ddf9df6fc865b7db96f8fc467cb8478ac7d38c1d2cceba69e538d75c5f945438`.

### Classic Warcraft header on November 22

Moonweaver selected Gold, Cyan, Emerald and Pitch Black on Forever with Store Companion 2.1.9-beta.2. Four native 4000 × 2560 screenshots captured the Classic Warcraft settings header with the Pitch Black canvas. The colored header lines closely matched the highlights of the textured outer frame. Pitch Black blended into the canvas. The header title, button labels and close button remained readable in all four captures. The header border reported RGB (120, 98, 0), (0, 98, 120), (26, 98, 42) and (0, 0, 0), respectively. The Pitch Black section heading reported RGB (209, 209, 209).

BugSack recorded zero current-session errors before the first selection, at each capture and after restoring Moonweaver's original Classic Warcraft theme, Gold trim and Pitch Black canvas. The temporary observer was removed and the game returned to its spanned layout.

The QA3 Discord bundle contains the tested header code and the matching portable Companion 2.1.9-beta.2. Compared with QA2, the add-on archive changed only UI/Controls.lua and six manifests carrying the QA3 label. This live run covered appearance. The outer ZIP SHA-256 is `2e168574cb8f66cafb2be3c0d32edb13996d0e9b7d746497066c0f87ae58e8bf`.

### Restore Window and Span WoW Now on November 22

Moonweaver reproduced the loss of the open Offhand map on Forever 1.60.1.71037 with OpenMap 0.8.10, the QA3 development files and Store Companion 2.1.9-beta.2. The initially closed map stayed closed on the first span. Opening the map on Offhand set its saved open flag. On Restore Window the flag cleared while the map was still visible, then the map hid. It stayed hidden after Span WoW Now. After manually reopening it on Offhand, repeating Restore Window, reloading in the single window and spanning again gave the same result. The trace recorded zero BugSack errors throughout. The private observer was removed and Moonweaver returned to her original spanned layout with the map closed.

The external map observer interprets a visible map outside the workspace as a move away from Offhand. That interpretation also runs when the workspace disappears. The settled display-size handler additionally calls ordinary frame restoration, which skips a hidden Forever map. A correction should preserve a previously open workspace map through temporary single-window recovery, including a reload there, and reopen it once when the workspace returns. A map deliberately closed while spanned should stay closed. OpenMap should retain ownership of geometry. This run covered OpenMap. The native-map-only display transition still needs its own check.

### Restore Window and Span WoW Now retest on November 23

Moonweaver used OpenMap 0.8.10 and Blizzard's combined backpack on Forever with Store Companion 2.1.9-beta.2. The development add-on kept the open flags for both panels when Restore Window hid them. Span WoW Now reopened both on Offhand. Repeating the same sequence with a UI reload in the single window also returned both to Offhand. After explicitly closing both while spanned, neither reopened on the next span. The recorder sampled the shown roots, their workspace location and current-session BugGrabber errors. All three runs had zero errors. The combined backpack briefly appeared on Mainhand during one sample before settling on Offhand.

The temporary recorder was removed. Moonweaver was left spanned with both panels open for local testing. The Lua regression also covers the native map and separate equipped bag IDs through a repeated recovery layout pass. Those configurations were simulated in this retest.

### Full client restart with the span applied after login on November 23

Moonweaver quit Forever 1.60.1.71037 with OpenMap 0.8.10, Blizzard's combined backpack and Character visible on Offhand. Social was closed. After relaunching from Battle.net, Moonweaver entered the world on one screen at 01:17:40. All three windows were hidden and all three saved open flags were intact. With Store Companion 2.1.9-beta.2, the span became active at 01:19:30. The map appeared on Offhand at 01:19:31, followed by Character and the combined backpack at 01:19:32. Social stayed closed. No manual panel open or UI reload was needed after applying the span.

BugSack recorded zero errors in the session that quit and zero during the cold login and span. An earlier setup session recorded three Blizzard status-bar errors when the QA slash command opened Character. Automatic Character restoration did not reproduce them. This live run covered OpenMap and combined bags. The native map and separate bags were not exercised in this full restart.

After QA, the original recorder file was restored and its hash verified. The three open flags were cleared, and Moonweaver was returned to the original single window measuring 2130 × 1392 pixels.

### Manual Mac calibration report on November 22

In the supplied screenshot the macOS title bar ends at row 28, Mainhand is black from rows 29 through 90 at x=1100, and the world begins at row 91. The workspace border starts immediately below the title bar. The player's full display arrangement, selected aspect and client build were unavailable.

A local Lua simulation using the actual manual viewport calculation produced a 61-pixel top gap with an illustrative 3624 × 1080 canvas, a 50% seam, a 16:9 Mainhand and a zero bottom inset. Mainhand measured 1812 × 1019. Fill with the same geometry left 472 pixels above it at the default 56.25% height and zero pixels at 100%. The wizard's Fill button only selects the mode. It exposes no corresponding height percentage control there. This establishes how the reported symptom can arise. Confirmation on the player's Mac requires the physical canvas and Mainhand rectangles from /offhand diag full, the selected aspect and the display arrangement. A full-height default would also affect deliberately shorter displays.

The reporter subsequently confirmed 16:9 and supplied Retail 12.1.5 build 70961 diagnostics from Beta 38. They requested a 3840 × 1138 window. WoW measured 3840 × 1140, with a remembered manual side-by-side layout. Workspace occupied (0, 0) at 1920 × 1140. Planned and actual Mainhand both occupied (1920, 0) at 1920 × 1080. This accounts for exactly 60 physical pixels above the world. The viewport bounds check passed because the renderer matched the plan.

In the Lua geometry harness, the same dimensions and seam produced a 60-pixel strip with 16:9 and zero bottom inset. Selecting Fill with the default 56.25% height produced a 499-pixel strip. Selecting Fill with a 100% height produced a 1920 × 1140 world with no strip and preserved the seam. Returning to 16:9 reproduced the original rectangle. The reporter confirmed that the supplied command resolved the top strip on their Mac. The post-change dimensions above are from the Lua harness.

The development candidate uses the measured WoW window height when calibration recommends two matching 1080p, 1440p or 4K landscape displays. The manual equal-halves preset also fills the available height when no aspect has been selected. An existing profile can select **Fit Window Height (Fill)** in the wizard or Display & HUD to apply the full height in one click. A saved aspect or custom height remains in effect until the player selects a new setting or reapplies the recommendation.

The geometry regression used a remembered 3840 × 1140 canvas and checked the resulting WorldFrame at 1920 × 1140 on the right. An explicit 16:9 selection produced 1920 × 1080, the existing 56.25% Fill height produced 1920 × 641, and full height with a 20-pixel bottom inset produced 1920 × 1120. The reporter verified the earlier command. A native macOS run of the updated setup UI is pending.

#### Manual workspace sides and window sizes

Display & HUD and the setup wizard now offer both sides for an equal horizontal split and identify the stacked choices as Offhand above or below. Reapplying calibration on the same remembered window preserves the chosen orientation, seam and aspect. A generic dual-landscape recommendation now fills the measured window at both 3840 × 1180 and 3840 × 1181. A single 3440 × 1440 ultrawide still defaults to an 880-pixel workspace beside a 2560 × 1440 game view. Players with two older displays that resemble one ultrawide can explicitly select a 50/50 split.

The Lua geometry tests exercised left and right at 3840 × 1080, 3840 × 1140, 3840 × 1180, 3840 × 1181, 3840 × 1200, 5120 × 1600, 4320 × 1440, 2560 × 1024, 3200 × 1200 and 7680 × 2160. Above and below ran at 1920 × 2160, 2560 × 3040 and 1440 × 3161. Each case checked the workspace rectangle and the applied world-frame anchors, then repeated after a one-pixel resize with a 43% workspace and a reloaded manual-canvas module. The tests also exercised both setup screens' click handlers and recalibration with a customized seam and height. These are simulated game windows. A physical macOS Retina or mixed-DPI run of this candidate is pending.

**Mac reporter follow-up for the next combined post-Beta 38 Discord package.** On the original 3840 × 1140 manual window, use Display & HUD to select the 50/50 split with Offhand left, then Offhand right. Reapply calibration and reload the UI. Confirm that the game fills the window height on each side, the selected side survives the reload, and BugSack has no new errors. If the strip returns, capture the window and the physical, planned, and actual viewport rectangles from `/offhand diag full`. Reporter confirmation is pending.

**Windows live check, November 22.** After relaunching through Battle.net, Moonweaver tested the development add-on on Forever 1.60.1.71037 with Store Companion 2.1.9-beta.2 running. A temporary profile manually split one 768 × 1353 game window. The recorder invoked the Display & HUD radio-button handlers and captured the rendered scene for each choice. Left and right each gave Offhand 384 × 1353 and the world the full height beside it. Above and below each gave Offhand 768 × 677 and the world the other 676 rows. The visible canvas and WorldFrame measurements matched the planned rectangles on every side. After reapplying calibration with Offhand on the right and reloading, the workspace still began at x=384 and the world still occupied the full left half. The current-session BugSack count was zero at baseline, after each choice, after reload and after restoring the original full-window layout. Moonweaver returned to her Default profile and the temporary observer was unloaded. The physical dual-monitor Mac check remains with the reporter for the combined Discord build.
