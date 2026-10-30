# OpenMap Retail errors, 30 October 2026

Status: reported independently of Offhand. User confirmed the same errors occur
with Offhand disabled while retaining the monitor span. This establishes that
Offhand is not required to reproduce them; it does not rule out further addon
interactions. No OpenMap implementation or installed files were modified.

## Environment and observations

- Retail test environment: 12.1.5 build 70575, interface 120105. The supplied error
  itself does not contain a build tuple; confirm the build when forwarding it.
- Installed OpenMap: v0.7.1-beta, OpenMap_Mainline.toc, interface 120105.
- User opens World Map in Retail. Error at Map/WorldMap.lua:155:
  `Frame:SetScale(): Scale must be > 0`, with scale, currentScale, targetScale,
  zoomTarget and baseScale all zero. Stack includes native OnCanvasSizeChanged
  and SetMapID during map opening. Reported mapID: 37.
- Separate reported failure: OpenMap grain texture coordinates out of range,
  reported by the per-step error boundary at Map/Close.lua:570.

## Installed-source findings

- WorldMap.lua:153-155 sets the scroll container's current/target zoom fields
  and calls Child:SetScale(scale) without rejecting nonpositive scale first.
- FitPx around line 80 derives the fit scale from current container dimensions.
  OnCreateZoomLevels around line 595 derives each level from that fit scale and
  assigns the first level to baseScale. ResetView around lines 611-638 can apply
  the derived scale while native canvas sizing is in progress.
- A transient zero-size container is a plausible source of the observed zero
  scale. Timing and actual dimensions at the failing call remain unmeasured.
- Close.lua:394-427 computes repeated grain UV coordinates from view/world
  extents and passes them to SetTexCoord without a finite/range check. Determine
  whether this failure follows the invalid view state or reproduces separately;
  the two supplied traces alone do not prove a shared cause.
- Do not repair this by passing an arbitrary scale of 1 or simply clamping all
  grain UVs to 0..1. Those changes can alter framing and break repeated textures.
  An OpenMap fix should defer invalid layout/view work until dimensions are valid,
  avoid committing zero zoom state, recover after layout settles, and validate
  texture inputs while preserving repeat phase and density.

Inspected SHA256:

| Installed source | SHA256 |
| --- | --- |
| Map/WorldMap.lua | CEB4E17C79D086134A3230636BD0A408904D8762CEDEAC96B80EC392BF8C2D95 |
| Map/Close.lua | F5D9DB18E236D06EE6F6EDFCB60821C7BE98EBD40E98E3F51BC9D401DC28FF32 |

Offhand already detects OpenMap as the external geometry owner. The installed
and working-tree CanvasCompatibility.lua matched during inspection. Old
_OffhandMovable/handle fields in a stack dump are not evidence of which addon
wrote the failing child scale. OpenMap's taint attribution identifies the error's
execution context; it does not by itself establish a protected-action failure.

## Focused OpenMap retest

1. Retain the existing span and reproduce with Offhand disabled, as confirmed by
   the user. Record whether the failure occurs on first opening or each opening.
2. Check normal window size, then spanning, and opening/closing map repeatedly.
3. Check minimized/maximized map, resize, zoom out/in, and a reload with map closed.
4. Record whether grain fails without an earlier scale error. Preserve the full
   error separately; redact personal/account/chat data before sharing it.

No upstream issue was posted and no third-party messages were sent.

## Local candidate, 30 October 2026

User explicitly requested continuation of OpenMap fixes. The project's linked
GitHub repository, jiforever/wowforever-openmap, returned 404. CurseForge lists
v0.7.1-beta-retail as the Retail release; inspected the installed copy and its
LICENSE.txt (MIT) rather than substituting the newer Forever release.

Prepared and locally deployed a reversible two-file candidate, outside Offhand's
runtime package:

- Reject zero, negative or nonfinite scales and invalid pan coordinates before
  committing canvas zoom state. Skip view/layer updates while layout is invalid.
- Retry canvas layout after 0.1 seconds, coalesced and bounded to eight attempts;
  cancel when the map closes, defer during combat and avoid invented fallback zoom.
- Do not commit generated OpenMap zoom levels while dimensions/scales are invalid.
- Rebase repeating grain UV origins modulo one, preserving phase and repeat span.
  Reject invalid/degenerate view inputs, hide invalid grain without caching it as
  successful, and allow the next valid view to redraw. An extreme repeat span
  above 1024 is skipped rather than clamped; that is a candidate limit, not a
  claimed native SetTexCoord API boundary.

Focused tests execute the reviewed candidate functions with mocked native sinks:
invalid scales do not poison existing state; deferred valid layout recovers;
callbacks coalesce/cancel and remain bounded. High-zoom/far-origin grain retains
phase and density, and recovers after invalid input. Both pass with Lua 5.1 and
both complete candidate files pass luac. These simulations do not establish
live timing, image fidelity, combat/taint or general OpenMap compatibility.

Backups, candidate files, MIT notice, exact diff, hashes and test drivers remain
under ignored dist/local-deployments/20261030-openmap-candidate/. Installed
version text is unchanged; candidate hashes identify this local build. Nothing
was published, no third-party code was added to Offhand's addon package, and no
OpenMap profiles were edited. Manual live reopen/zoom retest requested.

### Candidate withdrawn after live report

User reports the map does not display when opened after loading the candidate.
The smaller recovery text is accepted. This fails candidate acceptance despite
passing focused simulations. Restored both installed OpenMap files byte-for-byte
to the original hashes above. The candidate remains private for investigation.

After reload with original files, user reports the original grain error and a
native WorldQuestDataProvider OnHide warning about nil ticker. Requested explicit
confirmation whether the original map is visible, blank or invisible before
attributing causality. A screenshot without a map is not sufficient if the map
was subsequently closed. Root/canvas geometry remains unmeasured.

Saved worldmap settings: enabled=true, windowScale=1, window=false and
windowSize=false. No saved OpenMap anchor/size. No profile reset or forced frame
movement. Future investigation must separate the independent grain correction
from initialization guards and include full provider lifecycle acceptance.

## Final local retest, 30 October 2026

Target: Retail 12.1.5 build 70575, installed OpenMap v0.7.1-beta.
User confirmed the map remained invisible with original OpenMap files. Temporary
read-only diagnostics showed zero map anchors, native area none, and a zero-size
canvas. Offhand now preserves Retail WorldMapFrame native panel registration
and avoids synthetic panel eviction. User reloaded and confirmed map appears.
All 63 Offhand Lua suites and six-manifest syntax/path validation passed.

WorldMap.lua remains byte-for-byte original. Close.lua contains only the local
grain correction. A separately observed Extras.lua hover failure used a map ID
without a stitched rectangle. The local guard skips unavailable/degenerate hover
coordinates and labels, then resumes on valid input. Focused tests execute the
actual candidate functions; missing rectangles, zero bounds, missing cursor and
valid recovery pass. Extras.lua passes Lua 5.1 syntax validation.

Installed SHA256:
- WorldMap.lua: CEB4E17C79D086134A3230636BD0A408904D8762CEDEAC96B80EC392BF8C2D95
- Close.lua: E41F860878177F010380A231477F092B58D2D1790F6729825C43581ACE2A6778
- Extras.lua: F6818A2CDCF7D4A9832AE3C04C56915FA89D4B0819D5EF7C616E031B702AB237

After reload, reopen/close twice, zoom and zone hovering, user explicitly reports:
"Map visible; no new errors". This accepts this local out-of-combat workflow,
not general compatibility or combat/taint safety. Historical error entries can
remain. Temporary /offhandmapqa command removed; profiles unchanged. Third-party
patches remain outside Offhand runtime/package and addon updates may replace them.
Original backups and test drivers remain under ignored local-deployments folder.
No release, publication or upstream message occurred.

Loading comparison: user confirms artwork visible after Companion Restore Window
on one monitor. Restored span afterward using Span WoW Now (4000x2560). Windows
monitor arrangement unchanged. This verifies a manual workaround; spanned native
loading-art cropping remains unresolved. No automatic loading resize or Companion
binary change was implemented. Recovery dialog font and XP-enabled-character bar
visibility are accepted by user; closed Spellbook/Talents survive reload.
## Forever comparison, 30 October 2026

User reports successful Forever OpenMap use. Inspected actual installed Forever
Offhand beta.21 (monolithic Core/Canvas.lua), current Beta 24 source, Forever
OpenMap v0.7.5-beta Interface 16001 and Retail OpenMap v0.7.1-beta Interface 120105.
The installed beta.21 GetWorldMapExternalOwner recognizes MoveAny,
ClassicUIForever and LeatrixMaps, not OpenMap by name. It must not be described
as having the newer explicit OpenMap ownership adapter. Its Forever branch
returns before mutating native UIPanel registration. The modern shared source
retains that boundary; Beta 24 Retail WorldMap now also preserves registration
and additionally prevents synthetic HideUIPanel/Show eviction. Existing Retail
ownership tests confirm ConfigureWorldMap, saved restoration and drag completion
do not replace OpenMap scale/anchors. No additional runtime port is justified
by these reads alone; Forever-specific protected observation is not a Retail API
contract. Prior successful Forever gameplay is user evidence, not a new live test.

Inspected Forever OpenMap Extras.PlaceAt still subtracts S.Rect(id) outputs
without missing-rectangle checks. Its Close.UpdateGrain still supplies absolute
world-derived repeating UV coordinates. Its WorldMap.SetView still calls
Child:SetScale(scale) without the withdrawn candidate's readiness guard. Thus
the working Forever install does not contain equivalent grain/hover guards to
port into Retail Offhand. Different map data/client/native renderer behavior may
explain the absence of these failures, but causality was not established.
Retail user already reproduced these independent errors without Offhand.

Knowledge status consulted. Client-scoped OpenMap search reports a stale index;
comparison therefore uses direct installed source and recorded live evidence.
No third-party source copied, no runtime deployment or package modification, no
Forever client changes. Beta 24 package remains unchanged.
## Stock OpenMap with packaged Beta 24 accepted, 30 October 2026

The previous no-error map test used local OpenMap patches and was not stock
compatibility evidence. Backed up installed Offhand and OpenMap, removed local
Close.lua/Extras.lua patches, and deployed exact packaged Beta 24 to Retail.
User then reports reinstalling OpenMap through CurseForge, restarting Retail,
reopening/closing twice, zooming and hovering: "Map visible; no fresh errors".
Post-test hashes confirm WorldMap.lua, Close.lua and Extras.lua match preserved
original v0.7.1-beta bytes; all 73 non-generated Offhand package files match Beta24.
Generated bridges and profiles preserved. No local OpenMap patches remain.

This accepts stock OpenMap v0.7.1-beta plus packaged Offhand Beta24 for the
specified Retail 12.1.5 build 70575 workflow and current geometry. The downloaded
CurseForge archive was not independently available; reinstall is user-reported
and the three relevant original source hashes were independently verified.
Earlier independent error reports remain historical evidence, not proof the
current combination fails. No universal error-free, combat/taint or other-client
claim. Full deployment evidence is in ignored local-deployments/
20261030-retail-clean-openmap-beta24/deployment.json. No package/source runtime
changes, commit, upload or publication made during this acceptance.