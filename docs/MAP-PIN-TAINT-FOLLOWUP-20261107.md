# Mort's quest-pin protected-action report, 7 November 2026

## Status

Mort reports one ADDON_ACTION_BLOCKED attributed to Offhand at
Button:SetPassThroughButtons(). The native stack is QuestDataProvider refresh,
AddQuest, MapCanvas AcquirePin and CheckMouseButtonPassthrough. It could not be
reproduced. This matches the failure signature tracked as OH-FOR-001; it does not
establish the same initial taint source or a relationship to group invitations.

Exact reporter client/build, private test version, combat state, zone change,
native Gamepad mode and loaded map owners were requested. Provisional source
target is Forever 1.60.1.70862, consistent with prior testing in this chat.

Source hardening is included in private test14. The blocked action itself has not
been reproduced or verified fixed. Test14 is packaged and installed locally;
live QA reached a login error before in-world addon loading. No publication.
See [candidate verification](FOREVER-DISCORD-TEST14-20261107.md).

## What the stack establishes

Offhand does not directly call SetPassThroughButtons. Blizzard clears and sets
pin passthrough buttons each time it acquires a pin. The blocked native call
occurs during a data-provider event traversal; this stack records where the
tainted execution was rejected, not necessarily where taint began. It does not
identify the event, pin pool state, map owner, combat or action before the error.

The exact 70862 generated declaration marks SetPassThroughButtons protected and
restricted. An out-of-combat call, pcall or deferred timer does not establish
that invoking the surrounding native content pipeline from addon code is safe.
Do not replace the function, force passthrough flags, suppress the blocked action
or treat secure execution helpers as a way to sanitize addon-tainted state.

## Audit and source correction

Existing Forever isolation already excludes native map scripts, mouse-wheel
hooks, movement-event registration changes and frame-local addon bookkeeping.
Map dragging and recovery controls are separate UIParent children. No pin-pool,
pin-mixin, quest-provider or canvas input-registry replacement was found.

Two remaining content entry paths were identified:

1. RefocusPersistentWorldMap calls native SetMapID/ResetZoom after zoning while
   the persistent map remains open. SetMapID can refresh native data providers.
2. RepairYieldedWorldMapAnchor schedules OnCanvasSizeChanged, ResetZoom and
   RefreshAllDataProviders after an anchorless MoveAny map receives geometry.
   Its deferred callback also lacked a new combat check.

The candidate returns before direct or scheduled content refocusing on Forever.
Its anchor-only MoveAny bootstrap remains, but no content refresh is scheduled
on that client. Other clients retain refocusing and the bootstrap callback now
rechecks combat, enablement and visibility before invoking native refreshes.

Tradeoff: Forever no longer automatically changes the displayed map to the
player's new zone from Offhand's zone callbacks. Native map opening/navigation
and native quest-pin updates remain owned by Blizzard. Map placement, scaling,
workspace persistence, external ownership and Escape behavior are retained.

These are conservative changes to avoid entering native pin setup from these
addon paths, not a demonstrated causal fix for Mort's error. In particular,
Leatrix Maps/OpenMap already excluded the automatic refocus path, and MoveAny
excluded it on Forever too. If Leatrix was active for the report, neither
identified entry path necessarily ran. Chrome mouse-state writes and other
native ancestor changes cannot be ruled in or out from this stack alone.

## Validation and remaining evidence

The new forever-map-content-boundary.lua simulation fails against frozen test13
independently for refocusing and bootstrap content refresh. It passes with the
candidate, retains non-Forever content refreshes and proves delayed bootstrap
work aborts if combat begins before its timer executes. Existing Forever map
Escape/reload/external-owner checks pass. All 99 suites and six manifests pass.
These are source and mocked ownership checks, not native taint propagation.

The initial source pass launched no client. The later test14 attempt reached
WOW51900308 and stopped before in-world addon loading; client/settings cleanup
completed. No combat, quest acceptance/completion, level-up, map-pin action or
reporter-specific native configuration was exercised. Native taint acceptance
remains open. Reload is needed when testing a candidate because
removing a writer does not retroactively clean tainted native state in-session.

For a recurrence, capture the actual version/build and map owner, enable
`/console taintLog 2`, reload and test normal map opening, native quest refreshes,
zone changes and pin interaction. Keep the first matching Logs/taint.log trace
alongside BugGrabber output before reloading again. Disable logging afterward
with `/console taintLog 0`. Inspect/redact private data before sharing logs. A
clean short run cannot close an intermittent issue without the failing workflow.

## Source provenance

Shared knowledge status and SetPassThroughButtons/map-taint queries were consulted.
Collected 70532 declarations are review-due. Exact 70862 primary source was checked
at Gethe/wow-ui-source revision 9dc84f0d3bbae1768ac3405b3716000bd93eda06:

- [MapCanvas_DataProviderBase.lua](https://github.com/Gethe/wow-ui-source/blob/9dc84f0d3bbae1768ac3405b3716000bd93eda06/Interface/AddOns/Blizzard_MapCanvas/MapCanvas_DataProviderBase.lua),
  CheckMouseButtonPassthrough.
- [Blizzard_MapCanvas.lua](https://github.com/Gethe/wow-ui-source/blob/9dc84f0d3bbae1768ac3405b3716000bd93eda06/Interface/AddOns/Blizzard_MapCanvas/Blizzard_MapCanvas.lua),
  SetMapID, AcquirePin and native event/provider dispatch.
- [QuestDataProvider.lua](https://github.com/Gethe/wow-ui-source/blob/9dc84f0d3bbae1768ac3405b3716000bd93eda06/Interface/AddOns/Blizzard_SharedMapDataProviders/QuestDataProvider.lua),
  native quest event registration and refresh.
- [SimpleScriptRegion API](https://github.com/Gethe/wow-ui-source/blob/9dc84f0d3bbae1768ac3405b3716000bd93eda06/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleScriptRegionAPIDocumentation.lua),
  protected SetPassThroughButtons declaration.

No upstream expressive code/assets or private log contents are copied into packages.
