# Automatic zone updates on Forever

The intended behavior is for a windowed map left open on Offhand to show the player's new outdoor zone after a genuine boundary crossing. Keep the same window position, scale and open state. Moving between named places on the same map should leave the view alone. A player who has panned to a different zone to look something up should be able to keep reading it.

## Implementation sequence

1. Establish the Blizzard baseline on Beta 39. Compare the player's map ID with the displayed map ID before and after a crossing. If the map stays behind, repeat the same crossing with Offhand disabled and the same map open. Record Companion span and active map addons for both runs. This distinguishes a client limitation from interference by Offhand.
2. If Blizzard follows with Offhand disabled, trace the difference in native show, persistence and placement during the crossing and remove the interfering Offhand action. If Blizzard stays behind in both runs, inspect the target build for a Blizzard-supported navigation route before trying a native implementation. The previous automatic calls to SetMapID and ResetZoom could rebuild quest pins. Keep that protection in place. If there is no suitable route, retain the native baseline and document the limitation.
3. For OpenMap, follow movement within a zone as well as across boundaries. The continuous trial samples the player's position twice a second, converts it with OpenMap 0.8.13's public WorldFromMap and calls ShowWorld without a zoom argument. It waits for wheel zoom to settle, skips tiny position changes, and pauses when the player holds the left mouse button over the map. It applies only to the visible windowed stitched map on a spanned Offhand workspace, outdoors and out of combat. The earlier once-per-zone trial is available separately for comparison.
4. After live acceptance, decide whether the tested behavior belongs in Offhand or whether a released OpenMap follow mode covers it. A production integration should use a player preference, respect intentional browsing and yield when OpenMap provides its own active follow mode. Repeat the native quest-pin, Escape, window placement and reload checks before release.

## Crossing procedure

Use Beta 39 and the current local Companion test build. Record the actual WoW build, Companion and OpenMap versions. The separate **Offhand Zone QA** addon starts idle after every login or reload. Use the same walk between two neighboring outdoor zones in both directions. Check BugSack's session count before and after **each row** and note any yellow interface warning. If a new error appears, save its stack and the run label.

| Run | Steps | Evidence to collect |
| --- | --- | --- |
| Blizzard baseline | Disable OpenMap and other map owners for this character, reload, span, and leave the native map open on Offhand showing the current zone. Type `/ohzone watch`, walk across the boundary and wait three seconds. | Record player and displayed IDs before and after, whether the new map art appeared, and whether the window moved. If the player ID stayed the same, choose another boundary. |
| Blizzard control if stale | Disable only Offhand, reload and keep Companion spanned if possible. Open the native map on the starting zone and repeat with `/ohzone watch`. | Compare the same two IDs. Record any difference in span or map mode that prevents a like-for-like comparison. Restore Offhand afterward. |
| OpenMap baseline | Enable OpenMap and Offhand, reload, then middle-click the windowed map on Offhand in the starting zone. Run `/ohzone watch` and cross. | Record the player ID, stitched center, zoom and visible artwork. The underlying Blizzard displayed ID alone cannot establish what the player saw. |
| OpenMap trial | Middle-click to center on yourself again. Run `/ohzone trial` and walk back across the boundary. Wait three seconds. | Look for one recenter request, the marker in view, the new zone under the center, the original zoom and a stationary window. Compare with the baseline. |
| OpenMap seamless follow | With the windowed stitched map on Offhand, type `/ohzone follow`. Walk within the starting zone, cross the gate and keep walking. Change the wheel zoom, let it settle, then continue moving. | The view should track the character on both sides and at the new zoom. Check for jitter, unexpected zoom changes, and movement after stopping. Type `/ohzone status` at both zooms, then check BugSack. |
| Browsing and other controls | Pan to a distant third zone and cross again. Repeat with a closed map, on Mainhand, and across a subzone within the same map ID. Use `/ohzone status` for a manual sample. | Browsing stays where you left it, a closed map stays closed, Mainhand stays put, and a same-map transition leaves the view alone. |
| Pin and persistence checks | After a successful crossing, use a normal quest pin and Shift-click it. Check Escape and reopen, then reload with the map open. | Expected pin behavior, no new BugSack entries or blocked-action warnings, and the original window position and scale after reload. Real combat and instance transitions remain separate checks before shipping any automatic writer. |

Type `/ohzone off` to stop. Reload or log out to write the last 100 diagnostic lines to the character's `SavedVariables/OffhandZoneQA.lua`. Restore the original addon selection, span and map state. The helper can be disabled or removed independently of Offhand.

## Live results on 23 November 2026

Noggaholic Naux walked through the Ironforge gate on Forever 1.60.1.71037 with Offhand Beta 39 and Companion 2.1.9-beta.2. The player operated movement and the mouse wheel. The QA addon sampled the open map.

| Run | Observed result | BugSack |
| --- | --- | --- |
| Blizzard with Offhand, Ironforge to Dun Morogh | The player map changed from 1455 to 1426. The displayed map still read 1455 forty seconds later, and the player saw Ironforge artwork. | Zero before and after |
| Stock OpenMap 0.8.13, Dun Morogh to Ironforge | The marker moved across stationary terrain. The stitched center stayed at (0.7473, 0.5017) with zoom 9.075. | Zero before and after |
| OpenMap 0.8.13 with continuous follow, Ironforge to Dun Morogh | The player saw terrain track their movement across the gate and keep their wheel-selected zoom. Movement samples recorded zoom 27.694 on both sides, then 72.000 in Dun Morogh. The final sample also read 72.000. The QA addon used OpenMap's public API without changing its files. | Zero before, at the boundary and after stopping |

## Blizzard control on 24 November 2026

Noggaholic repeated the same outbound crossing. WoW confirmed both Offhand and OpenMap were unloaded before the recorder started, and the window still spanned the two monitors. At 03:00:39 both player and displayed map were Ironforge (1455). At 03:01:35 the player entered Dun Morogh (1426). The open map still displayed Ironforge at 03:01:37 and 03:03:09, matching the player's visual observation. BugSack recorded zero entries and zero occurrences in all four samples. The stale artwork therefore reproduces without either addon on this client and route. After reload, both addons were loaded and Offhand reported an active span.

## Integrated OpenMap follow on 24 November

On Forever 1.60.1.71037 with Companion 2.1.9-beta.2 and stock OpenMap 0.8.13, the installed Offhand candidate followed Noggaholic from Dun Morogh into Ironforge. The QA helper ran in passive watch mode. The initial zoom was 9.075. After the player zoomed in, the stitched center advanced from (0.7481, 0.5007) at the crossing to (0.7493, 0.4993) farther inside, at the same 22.155 zoom. Comparing the final view with OpenMap's stitched coordinates for the player gave a difference of 0.000000 on both axes. The underlying displayed map ID still read 1426. BugSack recorded zero entries and zero occurrences before, during and after the crossing.

For this version, the windowed outdoor map on Offhand follows when centered on the player. Panning away leaves the map available for browsing. Middle-click to center and resume. The compatibility suite models browsing, zoom, combat and monitor ownership. The live result covers the gate crossing and wheel zoom.

## Blizzard event trial on 24 November

With Offhand loaded and OpenMap unloaded, Noggaholic started in Ironforge with the native map displaying 1455 and BugSack empty. On entering Dun Morogh, the one-shot QA driver observed the old map still visible on Offhand. It requested `C_Map.OpenWorldMap(1426)` out of combat. The player saw the artwork change, and the settled and final samples both showed player and map at 1426. BugSack reported zero entries and zero occurrences. There were no blocked or forbidden actions in the recorder.

The Blizzard event handler for `WORLD_MAP_OPEN` takes the requested map ID and calls Blizzard's own map-opening function. The indexed declaration comes from 1.60.1.70938. The live request ran on 1.60.1.71037. The driver issues no direct map-ID, zoom or pin-pool writes. [Blizzard map source](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_WorldMap/Blizzard_WorldMap.lua)

This first run had zero active QuestPinTemplate pins and zero quest log entries. The earlier protected-action report involved a newly acquired quest pin, so a second crossing with quests in the destination was required.

Noggaholic also placed a manual waypoint on Dun Morogh. With the waypoint present, the native navigation request showed Ironforge and then Dun Morogh again. The player confirmed that Shift-click inserted the waypoint link, Escape discarded a draft, and the link could also be sent. The saved 03:26:47 sample showed the map and player still on Dun Morogh with zero BugSack entries and zero occurrences. This covers sharing a user waypoint.

For the quest-objective follow-up, Noggaholic accepted Dwarven Outfitters and Supplies to Tannok. Before the crossing, a read-only enumeration of the visible Dun Morogh map found two Blizzard `QuestPinTemplate` objects, with quest IDs 179 and 2160. The native quest provider acquires this template in `AddQuest`. [Blizzard quest provider source](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_SharedMapDataProviders/QuestDataProvider.lua)

Noggaholic returned to Ironforge and repeated the outbound crossing with the one-shot native trial. The player confirmed that the artwork switched and both objectives returned. Both quest pins responded to Shift-click, and the player saw no yellow interface warning.

The saved trace showed zero quest pins in Ironforge. At 03:39:50 the player entered Dun Morogh while the map still showed Ironforge. The QA addon requested map 1426 once. At 03:39:52 both map IDs read 1426. After Shift-click the active quest pin IDs were again 2160 and 179. BugSack reported zero entries and zero occurrences before the crossing, after settlement and in the final 03:45:13 sample. The event recorder captured no blocked or forbidden action during the run. OpenMap returned after reload.

## Next-release candidate

Offhand now issues the same native navigation request when a visible, windowed Blizzard map on Offhand still shows the outdoor zone the player just left. Combat and loading screens clear pending requests. The installed Forever candidate matched the checkout. The compatibility checker passed all 142 Lua suites, including delayed zone IDs, duplicate events, browsing, a closed map, external ownership and cancellation. The checker’s 11 Python tests also passed.

### Final Blizzard round trip on 24 November 2026

Passed on Noggaholic with Forever 1.60.1.71037 and Offhand commit `8f7cef2`. OpenMap was unloaded for the run. The separate recorder operated in passive watch mode and sampled Blizzard’s visible quest pins. Offhand handled both zone changes.

| Sample | Player and displayed map | Active quest pins | BugSack entries / occurrences |
| --- | --- | --- | --- |
| 04:00:09, before walking | Dun Morogh (1426) | Dwarven Outfitters (179), Supplies to Tannok (2160) | 0 / 0 |
| 04:00:49, inside the gate | Ironforge (1455) | None | 0 / 0 |
| 04:01:06, back outside | Dun Morogh (1426) | 179 and 2160 | 0 / 0 |
| 04:01:54, after pin interaction | Dun Morogh (1426) | 179 and 2160 | 0 / 0 |

Both settled samples matched the initial crossing samples. The player confirmed both artwork changes and successful hover and Shift-click on both pins, with no yellow warning. The recorder captured no blocked or forbidden action during the run. OpenMap 0.8.13 loaded again after the final reload. This closes the outdoor, out-of-combat Forever map-follow report for the native map and the tested OpenMap version.
