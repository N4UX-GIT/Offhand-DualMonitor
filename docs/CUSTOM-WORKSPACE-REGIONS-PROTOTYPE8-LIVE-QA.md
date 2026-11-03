# Prototype 8 live QA and review readiness

3 November 2026. Exact unpublished Companion `2.1.3-beta.3`, file `2.1.3.4`,
built from `73f2b9e69a3d8ef938b4d247d79ee26f5bb9c30f`, paired with the unchanged
77-file persistence addon from `7146cc4`. This supplements the
[editor recovery report](CUSTOM-WORKSPACE-REGIONS-PROTOTYPE8-RECOVERY.md);
earlier packets and their build-time metadata remain immutable.

## Live results

Both clients used an existing level-one character, two physical displays at
100% Windows scaling, one full game monitor and one custom workspace. No gameplay,
combat, character dragging or HUD setup action was performed. The user's prior
manual Character-drag verification was not repeated.

| Check | Retail 12.1.5.70688 | Anniversary 2.5.6.70577 |
| --- | --- | --- |
| Manual span and bridge reload | PASS | PASS |
| Saved schema 2 diagnostics | READY; viewport matches | READY; viewport matches |
| Both apps exited, relaunched, same plan manually applied and reloaded | PASS | PASS |
| Ordinary cold launch with auto-span off | Original native bounds | Original native bounds |
| Native Restore, first and cold-start cycles | Exact baseline | Exact baseline |
| Ordinary fallback after Restore | MISMATCH; full-client viewport matches | MISMATCH; full-client viewport matches |
| Foreground taskbar samples on both participating displays | Both covered, first and cold cycle | Both covered, first and cold cycle |
| Fresh BugGrabber capture | Loaded; session 352 to 360 | Loaded; session 550 to 558 |
| Captured errors | 13 historical records identical | 100 historical records identical |

Retail native HUD snapshots were recursively equal before the first span and
after both span cycles: four layouts, active layout 1. No layout was created,
deleted or selected. Two region-tagged saved panel positions and two preserved
legacy copies were present after the first span and cold restart. Anniversary
had no region-tagged panel positions at the first snapshot; its final snapshot
contained one migrated position with one legacy copy. This is not acceptance
of every adapter or a second physical workspace.

The Anniversary secondary historical error file remained at session 3 with two
identical records. It is supplementary only. Fresh-capture evidence comes from
the active account's advancing session and the saved second `IsAddOnLoaded`
return value, confirmed true. Merely unchanged historical errors were not used
as evidence that capture was enabled.

The first Anniversary taskbar probe sampled while WoW was not foreground and
reported uncovered points. That probe is not a fullscreen acceptance sample.
Subsequent foreground probes after reload and cold restart covered both points.
The result establishes this foreground configuration, not global taskbar hiding
or behavior while another application owns the foreground.

## Geometry and cleanup

Game display: desktop `(0,0) 2560x1440`. Portrait display:
`(-1440,-1114) 1440x2560`. Workspace local top-origin rectangle:
`(9,1108) 1418x1440`, desktop `(-1431,-6) 1418x1440`.

Both clients produced native bounds `(-1431,-6) 3991x1446`, style `140B0000`,
complex clip type 3. The bridge's bottom-origin game rectangle was
`(1431,0) 2560x1440`; workspace `workspace-a` was `(0,6) 1418x1440`, primary A.
Saved diagnostics matched the WorldFrame and region geometry after reload in
both sessions. Native taskbar probes sampled `(-722,1416)` and `(1280,1415)`.

Retail restored `(0,215) 2560x961`; Anniversary restored `(215,0) 2130x1392`.
Both returned style `14CF0000`, clip type 0 and ordinary non-maximized state.
Both apps exited normally. Retail's 18 original state files and 78 addon files,
and Anniversary's 20 original file states and 87 addon files, were restored with
every original hash verified. Originally absent files were returned to absence.
Battle.net remains open. Raw profiles, account paths, screenshots and logs are
private QA evidence, excluded from the review packet and shared knowledge.

## Adapter review

Source review at the unchanged addon revision confirms the following routing.
Existing automated evidence belongs to the 85-suite persistence build; this
documentation pass does not claim another full test run or new runtime behavior.

| Consumer | Region routing and boundary |
| --- | --- |
| Generic panel drag and restore | `CanvasPersistence` resolves destination and saved region before placement; successful migration retains the legacy record. Existing lifecycle fixture covers primary changes, missing/reconnected IDs, failed anchors and ownership guards. |
| Map presentation | `CanvasMapPresentation` resolves the saved/current region before available-size and return-position calculations. Maximized maps and external map ownership retain their existing guards. |
| Retail PlayerSpells | Restore supplies destination-region metrics to the existing fit adapter. Scale ownership and combat guards remain. A readable minimum scale is still unaccepted, so containment alone does not establish usability in narrow areas. |
| Replacement bags | `BagPersistence` captures the actual region and preserves passive missing-region fallback intent. The production lifecycle fixture covers that regression, close/open state, ordinary fallback and genuine external movement. |
| Forever native bags | `CanvasForeverBags` resolves saved-region metrics before target placement and tags capture. These paths have source/fixture evidence; this run did not launch Forever. |
| Popups | `PopupBounds` resolves owner/frame region for workspace bounds. Menu placement intentionally centers supported ordinary menus on the game rectangle. |
| Professions and protected/native trees | Existing adapters use shared restore/drag services and retain client, combat and ownership restrictions. Source routing does not establish protected-action or combat safety. |

No additional runtime change was justified by this bounded review. Broad
adapter acceptance still needs representative panels, readable sizes, input,
external-owner combinations and exact-client evidence. The oversized options
tooltip report remains separate as `OH-UI-OPTIONS-TOOLTIP-SCALE` in
[the issue ledger](ISSUES.md).

## Remaining acceptance

The initial implementation is ready for local review on the recorded two-display
configuration. One game plus two independently defined workspaces is implemented
and covered by synthetic planning, bridge, clipping and lifecycle fixtures.
Only two physical monitors are available here. A real third display still needs
rendering/input, placement and persistence in A and B, primary switching, taskbar
samples on all participating displays, excluded-area interaction and Restore.
Physical monitor loss/reconnection and native mixed-DPI/orientation changes also
remain unverified. Those checks require the hardware and hands-on availability.

Protected descendant actions and combat require human input and their own
current error/taint evidence. Narrow-panel readability, Store installation and
Wine runtime remain separate gates. The unsigned MSIX has structural/executable
parity evidence only. No release, push, tag, installation or promotion occurred;
public Beta 20 and the primary checkout are unchanged.

Shared knowledge was consulted before API/engineering decisions. Anniversary's
API declaration source matches 70577. Retail's pinned declaration source is
70575; this run records observed 70688 behavior separately and does not claim
that the pinned corpus itself covers that exact build.
