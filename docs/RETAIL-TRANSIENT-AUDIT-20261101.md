# Retail transient-frame audit, 1 November 2026

## Follow-up implementation

Status: all six findings accepted as fixed on the user's explicit instruction
"Assume fixed." This is assumption-based acceptance, not a report that the
listed live tests were performed. No additional installation or release is
implied by this status update.

All six findings below now have source corrections and positive regression
coverage. All 78 Lua suites pass; six addon manifests pass paths, XML and
Lua 5.1 syntax validation. The local Retail installation has not been updated
with this follow-up. Live rendering, protected descendant actions and fresh
taint evidence for these new cases remain unrecorded.

- Pet battle ownership records the exact applied rectangle and original native
  points outside the frame. Prior owned points survive topology/scale changes.
  Feature off, addon disable and loss of span restore only still-owned native
  points; combat replay evaluates current intent before applying or releasing.
- Secure transient roots compare applied points before continuing ownership.
  Later external/user placement causes persistent yielding; reviewed native
  resets permit reacquisition. Group-loot row positioning stops on root takeover.
  The generic HUD scanner excludes these roots so it cannot bypass that policy.
- Trading Post anchors and scale restore independently when each property still
  equals its applied value. Later movers retain ownership through active refresh,
  cleanup and re-enable. Combat cleanup rechecks current enabled/span state.
- Generic popup OnShow reads current metrics, validates current span, combat,
  protection and user placement, and redirects only a single stock centered
  anchor. The scanner and existing hooks both honor `seamRedirect`.

`tests/retail-transient-ownership.lua` converts the six original detections
into positive assertions using the existing isolated synthetic-frame setup.
It covers immediate and combat-deferred topology changes, effective scale,
disable/re-enable cancellation, single-screen release, external takeover and
stock reacquisition across the secure roots, scanner arbitration, fresh popup
geometry, feature gating and current protection. `tests/retail-fullscreen.lua`
also covers external anchor-only, scale-only and combined changes plus rapid
combat off/on. Original pet battle regression coverage continues to pass.

The shared knowledge status and a fresh ownership query were consulted before
implementation. The query supplied no native declaration evidence. These
corrections use reviewed local frame/secure-handler mechanisms; synthetic
execution of their snippets is not evidence of native restricted execution or
taint safety. No new native API availability claim is made.

## Original audit

The user confirmed the pet battle disappearing-controls fix after the local
Retail addon update. This audit follows that acceptance and does not reopen
the original symptom. Six additional contract gaps were reproduced with
actual local addon functions and synthetic frames. None is claimed as a new
live-client failure. No runtime source or installed files were changed by
this audit.

## Scope and evidence

Reviewed generic HUD popup rescue, secure transient adoption, pet battle
rectangle ownership, feature disable, combat replay, topology changes,
Trading Post cleanup and the cinematic presentation boundary. Inspected the
existing panel lifecycle audit to avoid mixing its TBC findings into this pass.

Local Retail is 12.1.5.70688. The original CurseForge reporter's exact build
and environment remain unknown. Shared knowledge status and a Retail
ownership/combat query were run; the query returned authored guidance and
explicitly required runtime verification, with no implementation citations.
Findings below concern Offhand's own code. Pinned Blizzard source previously
reviewed for pet battles is 12.1.5.70575, revision
`15881d522c44cd106d3d8660106ec9f9d2f44167`; it does not establish build parity
or native taint safety for the installed client.

## Findings

### 1. P2: A topology or scale change loses pet battle ownership

`Core/HUDTransientFrames.lua`, `IsNativePetBattleBounds` and
`PositionSecureMainhandTransient`.

The matcher accepts native full-screen bounds or bounds calculated from the
current metrics/scale. It does not remember the last rectangle Offhand wrote.
Changing Mainhand's rectangle leaves the previous owned points in place, but
the next placement labels them `custom-anchor`, clears ownership and yields.
The probe reproduces this both immediately and through deferred combat replay.
Repeated combat requests coalesce; the replay still rejects the old rectangle.

Impact: changing a display layout, game-view placement or effective scale can
leave the battle interface at the old location until a native reset/reload.
Actual off-screen behavior depends on the resulting topology.

Repair: keep exact applied points in an addon-owned side table. Recognize
unchanged prior owned points before comparing against the new target rectangle;
continue yielding to actual external divergence. Test both resize and scale,
including a topology change queued during combat.

### 2. P2: Disabling seam redirection does not release pet battle bounds

`Core/HUDTransientFrames.lua`, `PositionMainhandTransientFrames` early return;
`UI/Options.lua`, Redirect Popups checkbox setter.

After adoption, setting `seamRedirect=false` makes placement return without
restoring native bounds or clearing ownership. The probe confirms the old
Mainhand points and `boundsPrepared=true` remain. A non-spanned metrics result
also returns before the pet battle branch; the original rectangle may remain
relevant to single-screen transitions. The checkbox itself only updates the flag.

Repair: add a combat-aware release path that restores the captured native
points only when the current points still equal Offhand's applied points.
Cover disable, loss of span, re-enable, custom takeover and cancellation of
pending combat work. Do not rely on a future native reset to perform cleanup.

### 3. P2: Already-adopted secure transient roots overwrite later owners

`Core/HUDTransientFrames.lua`, `IsStockSecureTransientAnchor`.

The first branch returns true for an entry in `secureTransientOwned`, before
checking user placement or current anchors. The probe adopts PVPMatchScoreboard,
then gives it an external relative anchor and `userPlaced=true`. The next
placement replaces that external anchor with Offhand's point. The same predicate
serves GroupLootContainer, UIWidgetTopCenterContainerFrame and PVPMatchResults;
their actual runtime protection and replacement-addon interactions are untested.

Repair: replace the boolean ownership shortcut with applied-point comparison.
Permit reviewed native resets separately from external/user takeover. Retain
the existing combat gate and explicit stock eligibility rules.

### 4. P2: Trading Post cleanup overwrites a later mover

`Core/RetailFullscreen.lua`, `Restore`.

Once `modified` is true, cleanup restores the saved scale and anchors
unconditionally. The probe loads the real local adapter, adopts PerksProgramFrame,
changes its anchor and scale externally, then disables Offhand. Both external
values are overwritten by the old native state. This differs from the cinematic
adapter, whose restore path checks that its applied points are still current.

Repair: retain applied anchors and scale and restore each property only while
still owned. Validate another mover changing anchors alone, scale alone or both,
including queued cleanup during combat and a quick disable/re-enable.

### 5. P2: Generic popup OnShow uses stale display geometry

`Core/SeamRedirect.lua`, `RedirectExternalPopups`, UISpecialFrames hook.

The installed OnShow closure captures `cx`/`cy` from the scanner pass that first
found the frame. Its body does not obtain current viewport metrics. The probe
installs the real hook, changes Mainhand's center, then shows the popup: it is
placed at the old center. A later scanner may repair void placement, but it is
not a reliable repair if the stale position remains on a visible display.

Repair: resolve current metrics inside the callback, validate span/scale and
use an ownership-aware placement helper instead of keeping geometry in closures.

### 6. P2: Generic popup rescue ignores the Redirect Popups switch

`Core/SeamRedirect.lua`, `RedirectExternalPopups` and its UISpecialFrames OnShow.

Both paths check addon enabled state but omit `seamRedirect`. The probe turns
the option off and shows a centered popup: the installed hook still writes a
Mainhand anchor. This is separate from finding 2, which concerns releasing an
already-owned root. The generic scanner's live pass also lacks this feature gate.

Repair: honor the option in both the scanner and existing callbacks. Define
whether disabling only stops new redirects or also restores still-owned popup
placement, and test re-enable plus single-screen recovery independently.

## Reproduction and next candidate

Originally, `lua tools/audit-retail-transient-contracts.lua` from the repository
root exited 1 when it detected the six gaps. That command now runs the positive
regression suite and exits 0 on success. The suite reuses the existing
frame/timer fixture prefix in a separate Lua environment and calls local modules;
it does not execute Blizzard source or interact with WoW. Probe labels are
PET-TOPOLOGY, PET-RELEASE, SECURE-TAKEOVER, FULLSCREEN-RESTORE,
POPUP-STALE-GEOMETRY and POPUP-FEATURE-OFF. Its fixture dependency is explicit
and assertions fail if the setup contract changes.

At the original audit: all 77 existing Lua regression suites passed, the audit probe
passes Lua 5.1 syntax validation, and git diff whitespace checks pass. Passing
the existing suites does not invalidate the six additional audit detections.
Reviewed local-file SHA256 hashes and the six-finding output are retained at
`D:/Tools/Code/N4UXADDONS/wow-addon-knowledge/.cache/offhand-retail-transient-audit-20261101/`.

Prioritize ownership tracking and release semantics, then fresh geometry and
option gating for generic popup callbacks. Keep source changes separate from
the accepted pet battle correction. The live candidate matrix should include
pet battles before/after a topology change and reload, PvP scoreboard plus a
custom mover, Trading Post open/close and feature off/on, ordinary popups after
display changes, combat transitions and fresh errors/taint. Cinematic/movie
roots should remain on the regression checklist; no additional native cinematic
failure was established by this audit.
