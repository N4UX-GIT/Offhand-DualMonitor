# OpenMap drag snap-back follow-up, 2026-11-08

Status: Native hidden-title reset failure reproduced on Forever 70862, including
with Offhand disabled. The earlier local OpenMap patch passed native recovery,
reopen, reload and span/restore checks. A subsequent built-in Offhand recovery
candidate now avoids needing that source patch, with automated acceptance only.
The built-in path is not yet installed or live-tested. The reporter's exact
configuration remains unverified.

## Report and target

Forever 1.60.1 build 70862, interface 16001, Offhand 2.1.3-beta.27,
Companion paired 2.1.3. The map moves while dragging its bottom black bar but
returns on release. Its title bar is above the visible window. Character
movement works. The fault predates installing Leatrix Maps, and Companion
Restore Window followed by Span WoW Now did not resolve it. MoveAny was never
installed according to the reporter.

Diagnostics identify `WorldMapOwner=OpenMap`, with both OpenMap and Leatrix
Maps loaded. They also show single-screen recovery: `Spanned=0`,
`Source=Recovery`, workspace 0x0 and topology MISMATCH, expected 3440x2520
versus live 3440x1369. The intended stack is 3440x1440 game and 2560x1080
workspace, game below. These diagnostics describe the restored window, not
an observed active span. Stale HUD geometry is not evidence that HUD repair
causes the map drag failure. A passing viewport-bounds check does not establish
that an externally owned map has a reachable title bar.

## Source findings

The previous OH-FOR-013 fix is present in the local beta.27 public-readback ZIP:
`Core/CanvasCompatibility.lua` identifies OpenMap ahead of Leatrix, and Canvas
drag, configuration and restore paths yield map geometry to it. Relevant
ownership and Forever-map suites pass against both the current checkout and
the extracted beta.27 runtime. This is not evidence of the reporter's exact
runtime file bytes or addon settings.

Locally installed OpenMap is v0.7.5-beta. The reporter's OpenMap version is
unknown. In its `Map/Window.lua`:

- `Apply` restores the private `mod.db.window` anchor and window scale.
- `Hold`, hooked after root SetPoint/size/scale writes, calls Apply unless
  OpenMap's own title gesture or resize transaction is active.
- Only its own top title handle sets the local `dragging` flag and saves the
  resulting anchor at drag completion. A foreign mover does not participate.
- `TOP_OFF=68` and the configured clamp deliberately allow the title and bar
  below it above the screen. The source itself directs users to reset the
  window when its bar becomes unreachable.
- Original `ResetWindow` clears OpenMap's window anchor, size and scale only; when shown
  and out of combat it asks native HideUIPanel/ShowUIPanel to place the map.

`Map/Panel.lua` exposes that action as **Reset size and place**, in the map's
menu opened through `/openmap`. Older OpenMap versions may label it differently.
`Map/Compat.lua` warns about Leatrix UnlockMap, ScaleWorldMap and SimpleMapFrame.
Those options are potential additional writers, not an explanation established
by the fact that Leatrix is loaded. The original failure predates Leatrix.

## Offline characterization and limits

The ignored fixture `dist/openmap-snapback-20261108/probe.lua` loads the exact
installed Window.lua into a restricted Lua 5.1 environment with synthetic
frames and no Offhand code. It demonstrates:

1. A foreign SetPoint is restored to OpenMap's saved anchor by Hold.
2. OpenMap's own title gesture accepts and saves that same new anchor.
3. ResetWindow on a hidden map clears its window anchor/size/scale state.

This establishes a source-level mechanism without Offhand. It does not identify
the reporter's bottom control, emulate native StartMoving/StopMoving behavior,
prove visible reset placement, or establish protected-action safety. In
particular, native SetUserPlaced(false) behavior is not simulated.

Evidence hashes (SHA-256):

| Subject | Hash |
| --- | --- |
| Local beta.27 public-readback addon ZIP | `BC9C11361C3658A249C1C593108985498E85FAB51662DBF1431C03D548D864EF` |
| Original OpenMap Map/Window.lua | `14550426084949EE95C6D0B3B2F1CAAB7085D50AE5825C5A4DF83BA18792183B` |
| Native-tested local reset patch | `5E8D073C4A4E208233C955F093CECC397C1CC2DD07E6DD4C7A7CC3F64E4B6251` |
| Installed OpenMap Map/Panel.lua | `D0E556F30B0D11CC727D7F920928B5ED8D665F39545F3D1395316089D1E57658` |
| Installed OpenMap Map/Compat.lua | `EDF252DC7A222EC0BACDEA09D4EC1CC503E689B22E691FAD2D8F54796289D995` |

The shared knowledge project's cached Blizzard Forever source identifies build
70532 and is review-due. It is not substituted for native 70862 evidence.

## Earlier native vendor-patch investigation

Tested Forever 1.60.1 build 70862 with the released Offhand beta.27 ZIP,
OpenMap v0.7.5-beta and Leatrix Maps 1.60.28. Leatrix UnlockMap,
ScaleWorldMap and SimpleMapFrame were off for compatibility checks. A temporary
read-only addon sampled map bounds, anchors, owner, client build and loaded
addons; it did not hook or write map geometry. Test anchors were staged in
OpenMap SavedVariables only while WoW was closed.

The deliberately hidden title used a saved TOPLEFT-to-TOPLEFT anchor of
120, 60. The map opened at top 1980 with UIParent height 1920. Clicking the
original **Reset size and place** changed size but retained that hidden title.
The same native failure occurred with Offhand disabled. In this path native
panel layout can skip a manually shown map; clearing the database is insufficient
to replace its current root anchor. The observer established the retained anchor;
the panel-layout explanation also uses inspected source.

The local fix changes only OpenMap's explicit ResetWindow action. Out of combat,
for a windowed map not owned by MoveAny, it stops movement, centers the map on
UIParent inside OpenMap's existing ownership transaction, and saves that center.
The existing scale/size reset remains. During combat the reset returns without
changing saved state. No additional Offhand geometry writer was added.

| Native case | Result and boundary |
| --- | --- |
| Original title drag in restored window | User manually confirmed release stays placed; close/reopen and reload retained its saved anchor. |
| Original title drag on Offhand after spanning | User confirmed placement; reopen/reload and Restore Window kept the title reachable. |
| Original title drag with Leatrix loaded, competing geometry options off | User confirmed release stays placed; reopening and reload retained the saved center anchor. Native default sizing after reset changed top-left bounds, not the saved anchor. |
| Original reset with title above the screen | Failed both with Offhand enabled and disabled. |
| Patched reset, identical hidden-title fixture | Passed: clicking reset visibly recovered the title at the center; close/reopen and reload retained the center. |
| Patched reset while spanned | Passed: reset, close/reopen and reload retained a reachable center; reopening after Restore Window also passed. |

The patch was exercised with Leatrix loaded. The manual title-drag checks above
precede the patch; that gesture code is unchanged. Automated native title drags
did not move the map in either version and are not counted as successful
gesture tests. The isolated candidate probe still accepts its own-title gesture
and verifies reset recovery plus the combat no-op, but is not native combat QA.

The available desktop exposed one 2560x1440 display. Companion's existing
single-display split provided left workspace and right game, each 1280x1440.
This validates the tested span/restore transitions, not the reporter's mixed-size
vertical stack. Their exact OpenMap version and bottom control remain unknown.
Leatrix's duplicate-coordinate warning was observed separately and was not changed.

Final evidence contains 109 samples and 15 PLAYER_LOGOUT records across reloads
and normal exits, not 15 independent combat runs. BugGrabber retained five error
types with zero total counter increase. The retained taint.log has no
blocked/forbidden markers; its hash did not change during later runs, so it is
supporting retained-log evidence, not complete coverage of every test interval.
No native combat or controller safety claim is made.

Cleanup restored all 34 backed-up state/cache/enablement files, all 83 original
installed Offhand files and the Companion preference file byte-for-byte. It
removed the temporary QA addon and moved its two created SavedVariables files
to the private evidence directory. The tested WoW client was closed normally.
At the end of that run only the verified OpenMap Window.lua patch remained installed, with its original
source backed up. Native Companion artifacts were not rebuilt or replaced.

## Built-in Offhand recovery candidate

`Core/OpenMapRecovery.lua` provides an explicit **Recover OpenMap title** button
in Offhand's map settings and `/offhand recovermap`. It does no startup work,
installs no map hooks and schedules no mover. It recovers an already open,
windowed map to the top center of the current visible Mainhand rectangle. It
preserves OpenMap's scale, size and other settings.

OpenMapAPI major 1, version 4 has no public settings/reset operation. The adapter
therefore uses the exposed namespace's internal worldmap settings, gated to
the inspected OpenMap `v0.7.5-beta`, API 1/4 and Forever. It verifies the module's
database identity against OpenMapDB.worldmap and refuses malformed/unsettled
settings. The adapter writes the recovered anchor to the owner's database
before a single root placement. OpenMap's existing Hold hook then retains the
same anchor, including on reopen and reload, instead of restoring the hidden
one. Subsequent OpenMap title gestures continue to save their own positions.
No ResetWindow replacement, script invocation, vendor file edit or copied
OpenMap implementation is needed by this candidate.

The action refuses combat, disabled Offhand, a hidden/maximized/forbidden map,
Gamepad UI, an active mouse gesture, a different map owner, a different OpenMap
version/API, invalid geometry and size/scale state that the owner would change
while placing. It uses UIParent coordinates and current map scale, rather than
the center of the spanned canvas or stale desktop topology. If placement fails
or the title remains unreachable, it restores the previous vendor anchor and
attempts to restore the old root points. This is error containment, not a
protected-action safety claim. Unsupported versions require a new source review.

Automated evidence: tests/openmap-recovery.lua covers ownership, combat/no-write
guards, malformed/secret geometry, scaled mixed-height and restored-screen
coordinates, setting preservation, root failure rollback and localized reporting.
The private integrated probe executes the original hash-pinned OpenMap
Window.lua, including its actual Hold and title handlers, against the candidate:
recovery survives Hold, and the next owner title gesture saves normally.
This probe uses synthetic frames and does not establish native taint safety.
All six manifests load the adapter; new strings are translated in all 11 locales.
All 100 Lua suites pass. Six-manifest path/XML and Lua 5.1 syntax validation and
git diff whitespace checks also pass.

Built-in live acceptance remains: restore original OpenMap source, install the
candidate Offhand build, load the same hidden-title fixture and use the new
button/command; manually drag its title, close/reopen, reload and span/restore.
Check current BugGrabber/taint evidence and affected quest-pin actions. The
earlier vendor-patch native pass must not be presented as acceptance of this
different cross-addon call path. The locally installed vendor patch remains
unchanged until that controlled comparison. No new package or deployment was
performed for the built-in candidate.

## Earlier recovery procedure and remaining reporter acceptance

1. Out of combat, turn off Leatrix **Unlock map frame**, **Scale the map** and
   **Use simple map frame** if enabled, then reload. Alternatively disable
   Leatrix Maps temporarily to isolate it.
2. On the patched local OpenMap build, open `/openmap`, select **Look**, and use
   **Reset size and place** to recover the title bar. Original v0.7.5-beta can
   fail this step for an off-screen title. This action resets the map window's
   position, size and scale, not all addon settings.
3. Drag using the recovered OpenMap title bar. Check release, close/reopen and
   reload first in the restored window, then after spanning.
4. Use OpenMap's map-size control while OpenMap owns geometry. Offhand's map
   scale does not override this owner, explaining why that slider can have no
   visible effect here.
5. Once actually spanned, obtain fresh diagnostics. If topology still reports
   MISMATCH, investigate the actual window rectangle and display configuration
   separately; the supplied restored-window mismatch alone is insufficient.

The earlier [version-locked repair tool](../scripts/Repair-OpenMapReset.ps1) preserves a
backup, rejects different source bytes and supports Check, Apply and Restore.
Use it only with the tested source, with WoW closed for changes:

```powershell
./scripts/Repair-OpenMapReset.ps1 -OpenMapPath 'C:/Games/World of Warcraft/_forever_/Interface/AddOns/OpenMap' -Mode Check
```

Use `-Mode Apply` to install or `-Mode Restore` to undo this local source patch.
The backup is `Map/Window.lua.offhand-reset-original`. An addon updater can
replace the patched file. Recheck the source rather than applying the patch
blindly to a newer OpenMap. This is a local OpenMap fix, not an Offhand release
or an upstream OpenMap release. No public upload or vendor issue was sent.

Ignored private evidence, original MIT license, candidate source/diff and fixture
live under `dist/openmap-snapback-20261108`. Account data, QA helpers and vendor
source are not bundled into Offhand packages. Reporter confirmation on their
exact stack remains open; this local result does not close the whole report.
