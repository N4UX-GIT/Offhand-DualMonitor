# Region panel sizing implementation and validation

Calibration step 4 and Workspace settings now offer independent panel sizes for each workspace region. Users select a region, preview a manual percentage or a Windows-based estimate, and choose Apply size. Preview, reset preview, and discard do not change saved settings or native windows. An addon-owned sample and layout thumbnail show the proposed size and destination.

Existing configurations resolve to 100%, including when a newer Companion starts reporting mixed Windows percentages. Opening calibration or settings does not opt users in. Chat defaults to excluded and has a separate experimental checkbox for each region. Character and PlayerSpells retain their dedicated controls; protected HUD/Edit Mode systems retain their native sizing ownership.

## Source changes

- `Core/WorkspaceScale.lua` owns versioned region preferences, sanitized scale metadata, native-scale bookkeeping, guarded deferred work, conditional restoration, optional chat clusters, and sizing diagnostics.
- `UI/WorkspaceScaleControls.lua` provides the same preview and Apply/discard control to calibration and settings. It reflows translated help/status/button text and follows theme changes.
- All six TOCs load the new core and UI modules. The 11 locale dictionaries contain the new controls and explanatory text.
- Companion source writes optional `panelScaleMetadata` version 1 for Mainhand and every workspace region. Each record carries the selected device, stable identity, and a percentage only when detection succeeds. Several regions on one display reuse one observation. The metadata participates in topology freshness checks.
- `Viewport` copies optional metadata only after accepting the topology. Geometry stays in physical pixels and UIParent units. Old topology files remain usable. Invalid, absent, or unsupported scale metadata makes Auto resolve to 100%; manual values remain available.

Manual sizes and Auto results are bounded to 40–150%. Auto resolves the destination display's Windows percentage divided by Mainhand's percentage. It is an estimate of the user's preferred desktop sizing, not measured physical pixel density. Its status explains the bound and unavailable-data fallback.

## Persistence and compatibility

The active Offhand profile contains `workspaceRegionScales = {version=1, layouts={...}}`. Each layout maps region IDs to `{size=<number or AUTO>, chat=<boolean>}`. Missing entries mean native size and no chat scaling.

Companion preset IDs scope preferences across renames and display enumeration changes. Unsaved layouts use their topology geometry and device mapping. Manual layouts have their own geometry-based scope. Workspace preset save/activate/copy includes the setting table, and preset transitions invalidate old scheduled work. Missing-region entries remain stored. The normal SavedVariables and complete Forever profile recovery preserve explicit choices; old snapshots without sizing retain native defaults.

No public version or protocol bump is included. The existing topology schemas remain unchanged because sizing metadata is optional. Current source supports the complete existing Companion layout scope: schemas 1, 2 and 3, including partial areas, one-display splits, two workspace regions on one display, and regions across three selected displays. Increasing the topology's region/display limits is separate work.

## Placement and ownership

Generic restore resolves a destination, applies the eligible root's scale, then measures, fits, clamps, and anchors. Drag completion resolves its destination from the captured drop geometry before resizing and keeps that destination through the transaction. Mainhand measurements use native size. Oversized custom-region panels use the existing Mainhand fallback while retaining workspace intent.

Queued reset repairs re-enter the same placement/controller policy. They recheck profile/layout generation, current ownership, visibility, combat, and intentional fit fallback. A rejected SetScale is not published as applied state. A known native bag scale reset can be repaired; another owner's changed final scale is respected instead of repeatedly multiplied.

Forever bags use their dedicated native controller for sizing, drag capture, reopen repair, and fit fallback. No new bag-root fields, scripts, or SetScale hooks are installed. Combat repair retains the existing anchor-only path and does not change scale. Saved and default fit fallbacks avoid repeated scale/unscale writes while the observer runs. Player combat that appears before lockdown defers work through an addon-owned regeneration listener, avoiding recursive use of a lockdown-only queue.

Optional chat sizing reconciles the dock primary, dock manager, floating windows, separate tabs, and separate edit boxes. Inherited children do not receive another multiplier, and members transfer correctly after docking changes. Custom chat owners and protected roots cause sizing to yield.

The map controller applies region sizing to Auto fit, refreshes an open map when preferences change, and preserves existing explicit-map-size policy. Width, height, inherited scale, and the final map fit determine the recorded baseline. Disable restores only sizes still owned by Offhand; external map owners retain their state. Ordinary panel and map restoration preserve the visible top-left where the scaler owns that anchor.

`/offhand diag` reports each region's setting, resolved percentage, Auto source, optional chat state, active scale ownership, released ownership, and last rejected scale write. Resolved percentages describe region policy, not a claim that every native/replacement window accepted that size.

## Automated evidence

On 2026-11-10, all 128 root Lua suites passed under Lua 5.1.5. New and expanded coverage includes:

- `tests/workspace-scale.lua`: native defaults, independent region settings, shrink-to-fit, enlargement clamps, region transfer, coalesced reset repair, external ownership, protected/changed ownership, stale timers, combat deferral, rejected writes, chat redocking/edit boxes, preset isolation, Auto fallback/bounds, and disable restoration.
- `tests/workspace-scale-ui.lua`: real shared control callbacks, preview-only behavior, Apply/discard, separate regions, stale draft reconciliation, and reflow across all 11 locales.
- `tests/workspace-scale-map.lua`: open-map settings refresh, region-specific Auto fit, width/height containment, explicit size policy, and conditional restoration.
- `tests/forever-native-bag-proxy.lua`: dedicated bag sizing, native reset handling, no new hooks/scripts on the bag tree, combat isolation, shrink-to-fit, retained fallback intent, and no fallback scale churn.
- Existing wizard/settings fixtures now load the new control and verify its presence. Complete Forever CVar recovery verifies nested region preferences and the chat choice.

`tests/companion-region-scale.ps1` passes with C# 5 on x86 and x64. It verifies all-region metadata, shared-display query caching, unavailable queries, stable identities, and single-display scale identity. Its exact generated schema 2 and 3 files are accepted by the real Lua viewport and resolve different Auto percentages independently, without changing defaults.

Existing Companion display selection, partial topology, workspace region, flexible layout, named preset, and layout-document fixtures also passed on their applicable architectures. Six-manifest path/XML/Lua 5.1 validation passed for 83 loaded Lua files and one XML file.

## Native QA and release boundary

Implementation and automated validation are complete in the working checkout. No native game session was run for this feature. The contributor's earlier partial Forever 1.60.1 build 70862 demonstration remains evidence for that contribution only.

Before release, verify mixed physical DPI and offsets on the named target builds; drag between every region and Mainhand; switch bag modes; reopen bags and use actual items; dock/undock chat and use links/input; interact with map pins; enter/leave Edit Mode; change settings in combat; disable/re-enable; reload; cold-launch; change presets; and disconnect/reconnect displays. Inspect current taint/errors and the actual descendant actions, not only successful root writes. Include supported replacement addons and text/texture readability at scale extremes.

The checked-in Companion executable, prepared packages, installed addons, and public artifacts were not rebuilt or replaced. The new metadata writer is source for the Companion candidate workflow. Until a candidate containing that writer is used, older Companions support manual region sizing and Auto's 100% fallback.

Research routing used the shared knowledge README and skill, status, and exact API queries. Exact Forever 70862 SetScale declaration coverage remains unavailable; the pinned Retail declaration cited in the preceding review does not establish Forever runtime or taint safety. The earlier review is `docs/PANEL-SCALING-REVIEW-20261110.md`.
