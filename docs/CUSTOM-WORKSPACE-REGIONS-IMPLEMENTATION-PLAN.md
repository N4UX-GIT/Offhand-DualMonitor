# Custom Workspace Regions Implementation Plan

Status: **Approved for future development; deliberately deferred until the current single-workspace architecture is stable and its known bugs are resolved.**

This document records the intended design, implementation sequence, compatibility requirements, risk assessment, validation matrix, and release gates for partial-monitor and multi-monitor Offhand workspace regions. It is not authorization to begin implementation on the current stabilization branch.

When work begins, create a dedicated feature branch from the then-current, tested `main` branch. Do not develop this feature directly on `main` or on a release-stabilization branch.

## 1. Objective

Allow users to define one or more rectangular Offhand workspace regions instead of requiring the entire secondary display to be used as one workspace.

The feature must support:

- Reserving only part of a monitor for Offhand while leaving the rest visible and interactive for other Windows applications.
- Creating workspace regions on multiple monitors.
- Selecting one region as the primary/default workspace.
- Dragging supported frames between the Mainhand and any workspace region.
- Persisting a frame's assigned region and relative position across reloads, cold launches, topology changes, and Forever recovery.
- Preserving the current full-display workspace and single-display super-ultrawide modes without changing their default behavior.
- Showing the user the presentation-surface cost of a proposed topology before it is applied.

Partial regions may also reduce the spanned WoW window's backing surface when the selected regions reduce the outer bounding rectangle. This is a secondary benefit, not the primary feature promise.

## 2. Preconditions and branch strategy

Implementation must not begin until the current architecture has a reliable baseline.

### Entry criteria

- Current reported frame snapping, persistence, recovery, map, professions, cinematic/fullscreen, raw-mouse, and Companion window-control issues are either fixed or explicitly documented as unsupported.
- The latest stabilization beta has completed an adequate live test period across supported clients.
- The standard two-display workflow has no unresolved critical or high-severity regression.
- `main` contains all accepted stabilization changes and is passing the repository's automated tests.
- A rollback-capable release is available before schema 2 testing begins.

### Branch plan

1. Update and verify `main` with all accepted stabilization work.
2. Do not create the feature branch during the stabilization period.
3. When implementation is authorized, create `codex/custom-workspace-regions` from the latest verified `main`.
4. Keep bug fixes that also affect the stable architecture separable from region-feature commits where practical.
5. Do not merge the feature branch until the compatibility and release gates in this document are satisfied.

## 3. Current architectural assumptions

The existing system assumes:

- One Mainhand game rectangle.
- One contiguous workspace rectangle.
- Exactly two selected displays, or one display in explicit 50/50 super-ultrawide mode.
- One `OffhandCanvasFrame` covering the entire workspace.
- Workspace membership determined against one set of left/right/bottom/top bounds.
- Saved frame positions recorded against one canvas origin and size.
- Popup routing, seam redirection, off-screen recovery, map placement, bag placement, chat persistence, and Forever CVar persistence all target one workspace.
- Missing any saved display invalidates the span and restores WoW to the surviving Mainhand.

Custom regions must replace none of these assumptions for users who remain in the default mode. They must be introduced additively through a versioned topology.

## 4. User-facing model

### 4.1 Default modes

Retain the existing simple choices:

- Full Offhand display.
- Single-display 50/50 super-ultrawide split.
- Custom workspace regions (advanced, opt-in).

Users who never enable custom regions must retain the current setup and generated schema 1 topology.

### 4.2 Partial-monitor workspace

A user may create a region covering only part of a physical display. The excluded portion must remain outside the native WoW window region so other applications remain visible and interactive there.

Example:

```text
Portrait display                    Mainhand
+------------------+          +------------------------+
| Discord/browser  |          |                        |
|                  |          |       3D game          |
+------------------+          |                        |
| Offhand workspace|          |                        |
| map, bags, panels|          |                        |
+------------------+          +------------------------+
```

### 4.3 Multiple workspace regions

A user may create regions on more than one monitor. Supported frames may be dragged between them and remember their assigned region.

```text
Workspace A       Mainhand game       Workspace B
+----------+    +----------------+    +----------+
| Map      |    |                |    | Bags     |
|          |    |    3D world    |    | Details  |
+----------+    +----------------+    +----------+
```

### 4.4 Primary workspace

Exactly one workspace region must be primary. It receives frames that do not yet have a valid saved region, including newly routed panels, default map placement, bags, and redirected dialogs.

Per-category destinations may be considered later, but are not required for the first implementation.

## 5. Companion changes

### 5.1 Display and plan model

Replace the advanced plan's single `WorkspaceIndex` and `WorkspaceBounds` with a collection of stable workspace-region definitions while retaining legacy fields for schema 1 mode.

Each region requires:

- Stable internal region ID.
- Optional user-facing name.
- Stable physical monitor identity.
- Physical rectangle constrained to that monitor.
- Primary-region flag or separate primary-region ID.
- Optional creation order for deterministic UI display only.

The native WoW window bounds become the smallest rectangle containing the Mainhand game rectangle and every workspace region.

### 5.2 Advanced region editor

Add a separate editor launched by an **Advanced Workspace Regions** button. Do not place all region controls on the primary Companion dashboard.

The editor should provide:

- A visual map using Windows' relative display positions and aspect ratios.
- Mainhand selection.
- Add, remove, move, and resize workspace regions.
- Numeric X, Y, width, and height controls in physical pixels.
- Optional percentage-based sizing.
- Snap to monitor edges.
- Presets: full display, left/right half, top/bottom half, quarter, match Mainhand height, and match Mainhand width.
- Primary-region selection.
- Validation messages adjacent to the affected region.
- Preview of final window bounds.
- Bounding-surface resolution and pixel multiplier compared with Mainhand.
- Reset to the current full-display workspace.
- Explicit Save and Apply actions.

### 5.3 Validation

Refuse to save or apply when:

- No Mainhand is selected.
- No workspace region exists.
- A region has invalid dimensions.
- A region extends outside its assigned monitor.
- A region overlaps the Mainhand.
- Regions overlap each other in the initial implementation.
- A required physical display is disconnected.
- A region is below a documented minimum usable size.
- The resulting native bounds are invalid or exceed a conservative platform limit.
- The addon installation does not advertise support for the required topology schema.
- The generated topology cannot be written atomically.

### 5.4 Native window region

Continue using one native WoW window. Set its outer bounds to the combined bounding rectangle and construct its visible region from the union of:

- The Mainhand game rectangle.
- Every selected workspace rectangle.

Areas inside the bounding rectangle but outside those rectangles must be clipped away. This is what permits other applications to occupy unallocated screen space.

The implementation must correctly release temporary HRGN handles, account for per-monitor DPI awareness, use window-relative coordinates, and restore the previous style, bounds, and region if any operation fails.

### 5.5 Companion configuration

Preserve existing INI keys. Add a versioned custom-region section or key family containing:

- Region format version.
- Primary-region ID.
- One record per region.
- Stable display identity.
- Monitor-relative rectangle.
- Last validated monitor dimensions and orientation.

Write changes atomically. A partially written configuration must not replace the last valid plan.

### 5.6 Live apply behavior

Do not silently resize a running WoW client when a region is edited.

When WoW is running:

1. Save a validated pending plan.
2. Require an explicit **Apply and Resize WoW** action.
3. Write the topology and apply the native window transaction.
4. Explain that one `/reload` is required if the character UI is already loaded.
5. Roll back the topology file, window style, region, and bounds if application fails.

### 5.7 Diagnostics

Report:

- Game rectangle.
- Every workspace region and its ID.
- Physical monitor identity associated with each region.
- Primary region.
- Native window bounds.
- Visible selected pixels.
- Rectangular backing-surface pixels.
- Pixel multiplier relative to Mainhand.
- Missing or changed displays.
- Active topology schema and span mode.

## 6. Topology schema

### 6.1 Compatibility requirements

- The new addon must continue reading schema 1.
- The new Companion must continue producing schema 1 in the default full-display and existing split modes.
- Schema 2 must be produced only when custom regions are enabled.
- The Companion must refuse a schema 2 span when the installed addon lacks schema 2 capability.
- An addon/Companion mismatch must fail safely before the native window is moved.

### 6.2 Proposed schema 2 shape

```lua
OffhandCompanionTopology = {
    schema = 2,
    mode = "CUSTOM_REGIONS",
    physicalWidth = 4000,
    physicalHeight = 2160,
    mainhandDevice = "\\\\.\\DISPLAY2",
    game = {
        x = 1440,
        y = 0,
        width = 2560,
        height = 1440,
    },
    primaryWorkspace = "workspace-left-lower",
    workspaces = {
        {
            id = "workspace-left-lower",
            name = "Left Lower",
            device = "\\\\.\\DISPLAY1",
            x = 0,
            y = 0,
            width = 1440,
            height = 1440,
        },
        {
            id = "workspace-upper",
            name = "Upper Tools",
            device = "\\\\.\\DISPLAY3",
            x = 1440,
            y = 1440,
            width = 1280,
            height = 720,
        },
    },
}
```

Coordinates remain physical pixels normalized to the native WoW window's bounding rectangle.

## 7. Addon geometry changes

### 7.1 Viewport metrics

Add `workspaceRegions` and `primaryWorkspaceRegion` to viewport metrics. Each region exposes logical and physical bounds.

Keep the existing singular `workspaceLeft`, `workspaceRight`, `workspaceBottom`, `workspaceTop`, `workspaceWidth`, and `workspaceHeight` fields as aliases for the primary region. This reduces regression risk in modules that can continue targeting only the primary region.

### 7.2 Mainhand viewport

Keep one Mainhand game rectangle and the current `WorldFrame` anchoring behavior. Do not allow multiple game regions. Raw-mouse handling remains tied to a valid active span.

### 7.3 Canvas frames

Create one background canvas per workspace region. A single rectangular canvas must not span holes or application-reserved areas.

Retain `Offhand.canvas` as an alias for the primary canvas for compatibility. Apply the shared theme to all region canvases in the initial implementation; independent region themes are out of scope.

### 7.4 Geometry helpers

Centralize region operations:

- Find region containing a point.
- Find region containing a frame centre.
- Calculate overlap area.
- Select region with greatest overlap.
- Clamp a frame to a region.
- Resolve the primary region.
- Resolve a missing saved region safely.
- Enumerate game and workspace areas for rescue logic.

Avoid duplicating region-selection logic across Canvas, SeamRedirect, bags, chat, and panels.

## 8. Frame placement and persistence

### 8.1 Saved position extension

Extend workspace position records with:

- `regionId`.
- Region-relative or normalized X and Y.
- Saved region origin and dimensions for compatibility and rescaling.
- Existing absolute X/Y and optional frame dimensions.

Stable region IDs must not depend on list order. User-facing names must not be used as persistence keys.

### 8.2 Existing position migration

Only migrate when a user explicitly activates schema 2.

For every legacy workspace position:

1. Assign the containing region when exactly one contains the saved point/frame.
2. Otherwise select the region with the greatest overlap.
3. Fall back to the primary region when no region contains it.
4. Convert the saved position into the destination region's coordinates.
5. Clamp it safely.
6. Preserve the legacy data until the migrated placement succeeds.

Schema 1 users must not run this migration.

### 8.3 Drag destination

Resolve the destination only when dragging stops:

1. Prefer the workspace containing the frame centre.
2. Otherwise choose the workspace with greatest overlap.
3. Treat a frame over the Mainhand as a Mainhand placement.
4. Clamp the complete frame to the chosen region.
5. Save its region ID and relative position.

Optionally highlight the prospective destination region during dragging. Do not continuously rewrite saved positions during the drag.

### 8.4 Region deletion

When deleting a region containing saved frames, prompt the user to move them to the primary region or another selected region. Never silently discard their positions.

### 8.5 Escape and independent panels

Workspace membership must mean membership in any valid workspace region. Existing independent-open and Escape-protection behavior must apply consistently in every region without expanding direct mutation of protected frames.

### 8.6 Forever persistence

Add a compact versioned record, tentatively `W5`, containing a short internal region ID. Continue reading all existing W/W2/W3/W4 records. Validate CVar lengths and fall back to the primary region when a saved region is unavailable.

## 9. Affected subsystems

### World Map

- Default to the primary region.
- Remember a manually selected region.
- Size against that region.
- Preserve movement illumination, reload persistence, Escape protection, and Forever taint boundaries.

### Bags

- Store region IDs for native and supported third-party bag windows.
- Preserve combined backpack and Baganator/Bagnon/BetterBags behavior.

### Chat

- Store region IDs and clamp chat/edit boxes within the chosen region.
- Preserve Retail Edit Mode ownership when chat is on Mainhand.
- Avoid overwriting Blizzard anchors during Mainhand transitions.

### Blizzard panels

- Route unsaved panels to the primary region only when existing settings request workspace behavior.
- Remember manual placement in any region.
- Preserve normal Mainhand anchoring when moved out of all workspace regions.

### Popup and seam redirection

- Select a safe target region large enough for the popup.
- Prefer the primary region unless a saved rule exists.
- Render seam guides only where a workspace boundary actually touches the Mainhand.

### Off-screen recovery

- Evaluate the Mainhand and every workspace region.
- Preserve frames already wholly contained in a valid area.
- Use greatest overlap for partially visible frames.
- Move frames assigned to missing regions to the selected fallback.

### Wizard and in-game options

- Treat Companion topology as authoritative.
- Present a read-only region summary.
- Direct physical-region edits to the Companion.
- Keep themes, UI scale, panel behavior, and profiles editable in-game.

## 10. Setup and migration experience

### Existing user

- No new prompt.
- No automatic conversion.
- No frame migration.
- Same monitor choices, window bounds, schema 1 topology, and wizard workflow.
- Custom regions appear only as an optional advanced action.

### New ordinary user

Retain the current two-display setup flow. The advanced editor must not become mandatory.

### Advanced user

1. Select Mainhand.
2. Open Advanced Workspace Regions.
3. Add/resize one or more regions.
4. Select the primary region.
5. Review dimensions, window bounds, and performance estimate.
6. Save and apply.
7. Reload once if WoW was already at the character UI.
8. Arrange frames and verify a cold launch.

### Recovery

Always provide:

- Restore Window.
- Ctrl+Alt+R.
- Reset to Full-Display Workspace.
- Previous topology backup.
- Previous window style/bounds/region rollback.
- Primary-region fallback.
- Schema 1 fallback for default mode.

No recovery path may require deleting SavedVariables or manually editing the INI.

## 11. Performance behavior

Partial regions reduce presentation cost only when they shrink the native window's outer bounding rectangle.

Example for a 1440x2560 portrait workspace beside a 2560x1440 Mainhand:

- Current full workspace: 4000x2560 = 10.24 million backing pixels.
- Workspace cropped to Mainhand height: 4000x1440 = 5.76 million backing pixels.
- Reduction: approximately 44%.

Cutting holes from a window region does not necessarily shrink the rectangular swapchain. Small regions at distant extremes can retain or enlarge the backing surface. Multiple distant displays can therefore reduce performance.

The editor must show the projected surface and warn at sensible thresholds. Initial guidance:

- Above 2x Mainhand pixels: informational warning.
- Above 3x: elevated warning.
- Above 4x or an unsafe platform dimension: require explicit confirmation or refuse.

These thresholds must be validated rather than treated as final constants.

## 12. Risk assessment

| Risk | Severity | Unmitigated likelihood | Required mitigation |
|---|---:|---:|---|
| Existing panels migrate unexpectedly | Critical | Medium | Keep schema 1/default mode untouched; migrate only after explicit opt-in |
| Companion/addon schema mismatch | Critical | High | Capability check and refuse custom span before moving WoW |
| Invalid native region hides or blocks WoW | Critical | Medium | Validate and transactionally roll back bounds, style, region, and topology |
| Reserved application space remains blocked | High | Medium | Build HRGN from exact game/workspace rectangles and live-test click-through |
| Frames snap to the wrong region | High | Medium | Centre/overlap selection, drag-stop resolution, destination highlight |
| Deleted region strands panels | High | High | Migration prompt and primary-region fallback |
| Missing monitor invalidates saved regions | High | High | Retain fail-closed restore-to-Mainhand behavior initially |
| Forever protected-frame taint | Critical | Low-Medium | Do not extend region mutations to protected Edit Mode frames |
| World Map protected-action regression | High | Medium | Preserve Blizzard handlers; change geometry only; extensive Forever testing |
| Chat/Edit Mode ownership conflict | High | Medium | Preserve client-specific Mainhand rules |
| Rescue logic moves valid frames | High | Medium | Evaluate all valid areas and use greatest overlap |
| Canvas covers holes between regions | High | High with one canvas | One canvas per region |
| Distant regions worsen rendering performance | High | Medium | Show backing-surface cost and warnings before apply |
| Region is too small for a frame | Medium | High | Minimum-size checks and deterministic fallback |
| DPI conversion corrupts geometry | High | Medium | Continue physical-pixel planning and Per-Monitor V2 awareness |
| Windows display renumbering changes ownership | High | Medium | Bind regions to stable physical IDs |
| Advanced setup overwhelms ordinary users | Medium | High | Keep editor optional and preset-driven |
| Resolution/orientation change invalidates profile | High | Medium | Store monitor-relative geometry and require review when changed |
| Forever CVar record exceeds limits | Medium | Low-Medium | Short IDs, compact format, length validation |
| Complex regions differ under Wine | High | Medium | Mark experimental until tested with matching prefix/runner |
| User cannot recover from a bad plan | Critical | Low with controls | Restore hotkey, reset, backups, and automatic rollback |

### Risk to the current standard experience

Target: **low**, provided schema 1 remains the default and internal refactoring is additive.

### Risk to Forever

Target: **medium-high** until live acceptance. Forever's protected UI, CVar fallback, cold-start snapshot, map behavior, and load timing require dedicated validation.

### Risk to Wine/Proton

Target: **high initially**. Complex regions and more than two displays must remain experimental until tested through the supported same-prefix/same-runner setup.

### Security and anti-cheat scope

The feature must remain ordinary external Win32 window management. It must not inject code, hook DirectX, forward synthetic game input, or read game memory. This keeps the security model equivalent to the current Companion.

## 13. Implementation stages

### Stage 1: compatibility foundation

- Add schema 2 parsing and validation.
- Preserve schema 1.
- Add central region geometry helpers.
- Add primary-workspace aliases.
- Add addon capability detection.
- Add automated tests without exposing the editor.

### Stage 2: one custom region

- Implement one partial region on one Offhand monitor.
- Add the visual editor and presets.
- Add native exact-region clipping and rollback.
- Add region-aware persistence and migration.
- Validate application sharing and performance behavior.

### Stage 3: multiple regions

- Permit more than two referenced displays.
- Create multiple canvas frames.
- Support dragging and persistence between regions.
- Update map, bags, chat, panels, popup routing, seams, and recovery.
- Add region deletion/migration UI.

### Stage 4: optional routing and profiles

Consider later:

- Default region per panel category.
- Named region profiles.
- Profiles selected by connected-monitor topology.
- Region-specific themes.

These are not part of the minimum viable feature.

## 14. Validation matrix

### Companion automated tests

- Schema 1 plan output remains byte/geometry equivalent.
- Existing super-ultrawide split remains unchanged.
- One partial region.
- Multiple regions on one monitor.
- Multiple regions across several monitors.
- Side-by-side, stacked, mixed-size, portrait, ultrawide, and negative-coordinate arrangements.
- Stable display identity after `DISPLAY#` renumbering.
- DPI and orientation changes.
- Region overlap/out-of-bounds rejection.
- Missing displays.
- Native region or window-move failure rollback.
- Manual and automatic span.
- Restore Window and hotkey recovery.

### Addon automated tests

- Schema 1 compatibility.
- Schema 2 validation and malformed-topology recovery.
- Primary-region aliases.
- Dragging within and between regions.
- Mainhand/workspace transitions.
- Position migration, resizing, deletion, and missing-region fallback.
- Escape protection and independent panels in every region.
- Map, bags, chat, Blizzard panels, popup routing, and seam guides.
- Off-screen gathering across irregular layouts.
- Cinematic and Retail fullscreen recovery.
- Trading Post and other fullscreen UI.
- Raw mouse behavior.
- Combat lockdown.
- Forever W5 persistence and older record compatibility.

### Live acceptance matrix

- Retail, Classic Era, TBC Anniversary, and Forever.
- Cold login, `/reload`, character swap, combat, instance/zone transitions, and clean exit/relaunch.
- Native Windows standard workflow.
- One partial region sharing a monitor with another application.
- Three-monitor multi-region layout.
- Disconnect and reconnect each non-Mainhand display.
- Restore and respan.
- Wine/Proton experimental verification before claiming support.

## 15. Merge and release gates

Do not merge to `main` until:

- Default schema 1 output and behavior are demonstrably unchanged.
- Existing SavedVariables remain intact on first upgrade.
- Companion/addon version skew fails safely.
- Restore Window and automatic rollback work after every tested failure.
- No new protected-action or taint errors appear.
- Map, chat, bags, panels, Escape behavior, and persistence pass supported-client tests.
- At least one real partial-monitor application-sharing setup passes.
- At least one real three-monitor setup passes.
- Pixel-cost warnings are accurate for tested layouts.
- Documentation clearly distinguishes visible-region pixels from backing-surface pixels.
- A downgrade/reset path has been tested without deleting user data.

## 16. Explicit non-goals

- Rendering genuine WoW addon frames in a separate Companion-owned window.
- DirectX injection or multiple WoW swapchains.
- Synthetic input forwarding to an overlay.
- Multiple independent 3D game viewports.
- Silently degrading to a subset of regions when a required monitor disappears.
- Automatically modifying WoW graphics quality without explicit user consent.
- Replacing the stable default two-display workflow.

## 17. Decision record

The feature is worth pursuing because it addresses a direct user request: reserving specific screen space for Offhand while allowing other applications to share a monitor, and distributing Offhand workspace areas across multiple monitors. It may also reduce presentation cost for layouts where partial regions shrink the WoW window's outer bounds.

Development is intentionally postponed until the current architecture and bug backlog are stable. The approved direction is to preserve the existing experience as schema 1, introduce custom regions as an opt-in schema 2 capability, and implement the feature on a new branch created from the future stabilized `main`.
