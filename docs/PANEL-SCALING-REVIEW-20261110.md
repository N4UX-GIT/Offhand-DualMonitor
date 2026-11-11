# Workspace panel scaling review and integration proposal

The supplied feature is a viable foundation for independently sizing supported workspace windows. Adopt its native-scale bookkeeping and scale-before-measure principle, then integrate those concepts with Offhand's region placement and ownership policies. The supplied patch needs changes before integration, particularly around drag fitting, delayed refreshes, chat, and custom layouts.

This review covers the four-commit patch in `C:/Users/NAUX/Downloads/Offhand-panelsize/0001-workspace-panel-size.patch` and its accompanying description. No feature code, installed addon, Companion executable, or release artifact was changed. The unrelated centerline command should be reviewed separately.

## What the feature provides

The implementation multiplies the local scale of ordinary windows on a workspace, restores their native scale on Mainhand, and retains positions in UIParent coordinates. It does not change the global HUD scale, monitor resolution, game rendering, or the physical window span.

The setting is one multiplier for all eligible workspace windows. It is not currently an independent setting for every individual panel or workspace region. CharacterFrame and PlayerSpellsFrame retain their existing dedicated sizing behavior. World Map Auto fit receives the multiplier through its own owner; an explicit map size remains unchanged. Chat receives special handling for its dock, tabs, and edit boxes.

Auto uses `workspace Windows scale / Mainhand Windows scale`, bounded to 40–150%. For example, 100% divided by 175% gives approximately 57%. This is a reasonable initial preference, not a measurement of physical pixel density. Two displays can use the same Windows percentage while having different physical densities. The UI should describe Auto as an estimate based on Windows settings, provide manual adjustment, and show when a bound limits the result. Fractional sizing also needs visual checking for text and texture quality.

[Microsoft's GetScaleFactorForMonitor contract](https://learn.microsoft.com/en-us/windows/win32/api/shellscalingapi/nf-shellscalingapi-getscalefactorformonitor) supports reading a monitor's scale factor and explicitly requires checking the success result. The existing Companion reader correctly treats failed queries as unavailable. The API does not establish equal physical dimensions across displays.

## Findings requiring changes

### Scale before fitting on every placement path

Priority P1. In the contributed `Core/CanvasPersistence.lua`, `InstallRestore` applies scaling before measuring, but `InstallDrag` applies it after `FitsWorkspace`, position calculation, and anchoring. This discrepancy is especially significant for custom regions.

Two simulations through the real contributed drag handler reproduced the consequence:

- A panel 1200 UI units wide is rejected from a 1000-unit workspace even though its selected 50% scale would make it 600 units wide.
- A panel accepted and clamped at 600 units wide overflows the same workspace after enlargement to 150%.

Resolve the destination from the captured drag rectangle, apply its multiplier, measure the resulting effective size, then fit and clamp. Retain that destination for the transaction so resizing cannot cause region-selection oscillation. Roll back the temporary scale if placement fails.

Source: supplied patch lines 131–164; final `WorkspaceScale:ApplyKeepingTopLeft`; current `CanvasPersistence.InstallDrag` and `WorkspaceRegions:Destination`.

### Delayed work must revalidate ownership and actual placement

Priority P1. `WorkspaceScale:ScheduleReapply` checks enabled state, saved workspace intent, visibility, and span availability, then writes scale and anchors directly. It does not run the normal placement policy. `IsEligible` checks forbidden state and three named exclusions, but does not reject protected/Edit Mode roots or established replacement owners.

Saved workspace intent can deliberately remain present while an oversized panel is placed safely on Mainhand. A simulation confirmed that the watcher rescales such a Mainhand fallback. A separate simulation confirmed that the scaler accepts a protected ObjectiveTrackerFrame; ordinary initial placement normally rejects this root, but the scaler itself does not enforce that policy. Ownership changes between scheduling and execution therefore need a fresh guard.

Route delayed work through the same region-aware placement controller as ordinary restore. Recheck the frame's controller, Edit Mode state, supported replacement owner, fit fallback, current destination, and combat state. Use a generation token for superseded layout/profile work. Deferring a write or wrapping it in `pcall` does not establish taint safety.

Source: final contributed `WorkspaceScale.lua` lines 70–80, 264–335; current `Canvas.lua` functions `IsUnsafeForPanelMutation`, `IsUnsafeForDirectMutation`, and panel-controller routing; `CanvasPersistence.PreservedFitFallback`.

### Full custom layouts require scale metadata for every display

Priority P1 for the requested scope. `GetMultiplier(metrics)` ignores the destination region and always reads the single top-level `workspaceScalePercent`. The Companion queries only Mainhand and the primary workspace display. Every other region therefore receives the primary workspace's ratio.

The current schema 2/3 implementation supports up to two workspace regions and three selected displays. Schema 3 can also place several regions on one physical display, including the Mainhand display. Per-region scaling can cover all those supported layouts without lifting these topology limits. An arbitrary number of regions or displays would be a separate topology expansion.

Source: final contributed `WorkspaceScale.lua` lines 144–182; contributed `CompanionTopologyBridge.ScaleFields`; current `WorkspaceRegions.ValidateFlexibleTopology` and `ApplyMetrics`.

### Chat needs complete membership transfer and client ownership checks

Priority P2, with live protected-action validation required. In a supported hierarchy where a floating chat window has a separately parented edit box, the edit box is scaled with the floating window. When that window docks, the primary cluster includes the docked window and tab but omits the secondary window's separate edit box. A simulation reproduced that edit box remaining at 50% after the dock returned to Mainhand.

Reconcile old and new cluster membership, restore members leaving a cluster, and apply scale once per independent root. The cluster must follow the dock primary's region. Yield to custom chat owners and client-specific Edit Mode restrictions, including after hooks have already been installed. Keep chat separately switchable while its client matrix remains incomplete.

Source: final contributed `WorkspaceScale.lua` lines 110–138 and 187–201. The supplied chat test verifies the floating edit box's initial scale but does not check it after redocking and Mainhand restoration.

### Open World Map does not refresh from the new controls

Priority P2. The map's Auto-fit code reads the multiplier, but `WorkspaceScale:Refresh` excludes WorldMapFrame and never calls its dedicated owner. A simulation confirmed that changing the setting with only a saved WorldMapFrame produces no restore call. The new size becomes visible only when another path configures the map.

Explicitly notify the map controller when its applicable region multiplier changes. Retain explicit map sizing and replacement-owner rules. Recompute both width and height fit after any Auto adjustment, especially when the multiplier is above 100%.

Source: contributed `CanvasMapPresentation.lua` change; final `WorkspaceScale.lua` lines 368–397.

### Scale ownership and write failure need a stronger contract

Priority P2. When an external writer changes scale, the implementation adopts the new value as native and immediately multiplies it again. This is additive cooperation, rather than yielding to that writer's desired final size. Repeated writers can still contest the result. Known Blizzard reopen resets and an external addon's deliberate scale change need separate handling.

Also, `ApplySingle` publishes `state.applied` and returns success even if `WriteScale` catches a rejected native write. A simulation reproduced an unchanged scale being reported as applied. Publish state only after a successful write and confirm the effective result where supported. Reuse Offhand's external-owner detection and expose skipped/rejected changes in diagnostics.

Source: final contributed `WorkspaceScale.lua` lines 204–254 and 270–279.

### Persistence and upgrade behavior need explicit design

Priority P2. The new scalar lives in the normal Offhand configuration profile, but `WorkspaceProfiles` does not include it in its snapshot field list. Switching Companion-linked workspace presets can therefore retain another layout's sizing preference. Wizard scale setup is also unchanged by this patch.

Default Auto changes existing users' window sizes as soon as an updated Companion supplies different display percentages. Preserve 100% for existing configurations until the user accepts Auto or adjusts a region. New setup can offer Auto as the suggested starting value.

## Proposed integration

### Companion metadata

Add optional versioned scale metadata keyed by the selected display identity. Include every selected display in schema 3 and the relevant display/device records for older layouts. Keep region geometry in physical pixels. A region refers to its backing display; several regions on the same display share the detected percentage but can have different manual preferences.

Use the existing stable display identity for persistence and the generated topology's device mapping for the active session. Do not use display-list indices or raw region IDs globally. Reconcile metadata with the accepted topology and pass the validated result into metrics; avoid having the scaler independently consume a raw global bridge table.

These fields can be additive to the existing schemas if old/new reader tests confirm compatibility. Missing or invalid metadata yields 100% in Auto while manual values remain usable. Query failures must remain unavailable. Include all relevant scale fields in bridge freshness checks, not just the primary pair. Changes to the generated Lua bridge reach a running addon through its existing reload/reconnect lifecycle; a native file write alone is not an in-session Lua update.

### Region settings and optional panel adjustments

Store a versioned region-settings table in the active workspace preset, scoped by the Companion layout identity and region identity. Include it in preset save/activate/copy/validation and the existing persistence/Forever recovery paths. Preserve dormant entries when a monitor is missing so reconnecting can recover the user's choices. Do not reuse a disconnected region's detected scale for a fallback region.

Each region should support Auto, a manual percentage, and a reset to 100%. Regions on the Mainhand display naturally resolve to 100% in Auto. Manual layouts without Companion metadata still support manual values.

If individual window control is desired, add an advanced panel adjustment with a default of 100%. For ordinary eligible roots:

`desired local scale = native local scale × destination region multiplier × panel adjustment`

An adjustment belongs to the supported panel/root identity, not a transient child frame. Existing Character, map, PlayerSpells, and replacement-addon owners must apply the policy through their own adapters, or explicitly remain excluded. Never stack a generic writer on top of a dedicated writer. Per-panel overrides can follow after the region foundation is validated.

### One placement transaction

Use this ordering for restore, drag completion, routing, preset changes, and reopen repair:

1. Validate enabled state, combat state, and the frame's current controller and mutation policy.
2. Resolve the intended destination, honoring saved region-relative intent and intentional Mainhand fallbacks.
3. Obtain the destination's multiplier and the frame's known native baseline.
4. Apply scale through the responsible adapter and verify success.
5. Measure in UIParent units, then fit and clamp to that destination.
6. Anchor and publish ownership; retain saved intent separately from an automatic fallback.

Restore native scale before Mainhand or single-screen measurements. Disable, profile switches, replacement-owner changes, and missing displays should restore only values still owned by Offhand. Timers should schedule this controller, rather than becoming a second anchor/scale owner.

### Calibration and settings

The user's proposed location fits the existing flow. Keep the main HUD scale first in the wizard, then add a Workspace panel size section with a region picker and a highlighted destination in the layout preview. Offer Auto and manual adjustment for the selected region, a visible percentage, and Reset to 100%. When Auto metadata is unavailable, explain briefly that manual adjustment is available.

Use an addon-owned sample window/text preview so users can judge readability before changing native frames. Apply changes to eligible visible windows through the guarded transaction, defer combat changes, and support cancel/reset of the preview. Use the same sizing control and controller in Workspace settings to avoid separate wizard behavior. Reflow or scroll the current wizard card for multiple regions and translated labels.

State the scope near the control: supported workspace windows. Protected HUD/Edit Mode systems keep their existing sizing controls. Keep chat separately switchable during validation. Put detected Windows percentages, applied bounds, skipped owners, and write failures in diagnostics or an explanatory tooltip.

## Validation and rollout

The recommended first increment is the region settings/resolver plus ordinary supported windows, wizard/settings controls, and guarded native restoration. Follow with dedicated map/Character adapters and optional chat after their ownership tests. Review the unrelated centerline command separately. Companion source changes require the Companion candidate workflow; no frozen executable should be rebuilt on an addon branch.

Regression coverage should include different percentages on every display; two regions on one display; a region on the Mainhand display; negative monitor coordinates; portrait and partial regions; region-to-region dragging; shrink-to-fit and enlarge-overflow; profile switching; disconnected/reconnected displays; old/new Companion versions; invalid scale metadata; repeated reopen resets; external owner changes; and failed writes.

Live validation must exercise actual bag item actions, chat links/docking/input, map pins, and the applicable protected descendants before, during, and after combat. Include reload, cold launch, enable/disable, scale extremes, replacement addons, and supported client families. Passing simulations does not establish native rendering, secret-value handling, taint safety, or persistence on every client.

## Evidence and reproducibility

- Input patch SHA-256: `9725D36FAE13CEFF193462D41D1A9D9D1F75E6FF039E9E0534656A359B153A2F`.
- Contributor report: partial live behavior on Forever 1.60.1 build 70862 with one mixed-density span. The bag reopen watcher fix and chat/map extensions still require live retesting according to that report. This review did not run a native client.
- Reconstructed all four commits using available original Git blobs with exact hunk assertions. Unchanged dependencies came from beta.28 HEAD `dc5e9eb1526dd1ac0adad56d1021f7e9231cf5e1`. This tests the supplied implementation independently of the active checkout's substantial pending changes.
- Independently reproduced 117/117 root Lua suite passes under Lua 5.1.5, including the contributor's two scaling suites and center-guide suite. Initial missing snapshot dependencies were supplied from HEAD before rerunning the affected suites.
- The Windows `tests/companion-scale-topology.ps1` fixture compiled and passed. Six-manifest path/XML/Lua 5.1 syntax validation passed: 80 loaded Lua files and one XML file. This does not validate a rebuilt Companion package.
- Seven additional characterization checks reproduced the source gaps described above. The isolated snapshot and `review-boundaries.lua` are at `C:/Users/NAUX/AppData/Local/Temp/Offhand-panelsize-review-m6_ys9nu`; suite output is in `lua-suite-results.json` there. These checks assert the observed defects, so their success demonstrates the gaps rather than feature acceptance.
- Shared knowledge README/research skill, `wowkb status`, `ask`, and exact `api` queries were consulted. Blizzard sources were marked review-due. Retail `SimpleFrameAPI:SetScale` is declared protected and scale-secret-sensitive in 12.1.5.70575 at pinned revision `15881d522c44cd106d3d8660106ec9f9d2f44167`; [the source declaration](https://github.com/Gethe/wow-ui-source/blob/15881d522c44cd106d3d8660106ec9f9d2f44167/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFrameAPIDocumentation.lua#L1469) was also checked upstream. This is declaration evidence, not proof of behavior on the contributor's Forever build. Exact Forever 70862 lookup remained a knowledge gap.

Integrate into the current placement architecture rather than applying the mailbox wholesale over pending work. Confirm contribution rights and attribution before importing third-party source. The review approves the direction, with the findings above as implementation work and the live matrix as the release gate.
