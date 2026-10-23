# Offhand addon structural refactor

## Stable baseline

The refactor begins from the released Beta v22 source checkpoint.

- Release tag and `main`: `v2.1.2-beta.22` at `62de7a3f0e850601c02e1cb7d1db713186680988`
- Addon integration branch: `addon/develop` at `c2a854e96d572c5a98cc6e498bc47c82962ee5af`
- Baseline tree: `8976b2120a771b28a426cc3ec7ee62eaf1a937c6`
- Baseline validation: 38 Lua suites passed
- Manifest validation: all 6 client manifests passed with matching runtime order
- Runtime inventory: 35 Lua files before the first extraction
- Frozen Companion SHA-256: `81EECE9430885CEAC178A44A42429854524279072305F9F94EE62E7CCD620CCB`

## Objectives

- Reduce ownership ambiguity in the largest runtime files.
- Make client-specific compatibility boundaries explicit.
- Isolate protected UI and timing-sensitive recovery behavior.
- Preserve SavedVariables, public `Offhand` APIs, initialization timing, and user-visible behavior.
- Create smaller units that can be characterized and changed independently.
- Prepare the codebase for a later UI redesign without combining structural and visual risk.

## Non-goals

- No visual redesign in the structural refactor.
- No intentional behavior changes during module extraction.
- No Companion refactor or change to the frozen Companion build.
- No SavedVariables schema migration unless it is separately justified, reviewed, and tested.
- No removal of compatibility paths based only on mocked tests.

## Current pressure points

| File | Approximate size | Responsibilities currently combined |
| --- | ---: | --- |
| `Core/Canvas.lua` | 6,527 lines | Compatibility detection, panel ownership, persistence, bag adapters, map behavior, chat behavior, dragging, and recovery |
| `UI/Options.lua` | 3,395 lines | Topology logic, reusable controls, screen construction, profile controls, and navigation |
| `Core/SeamRedirect.lua` | 3,207 lines | Edit Mode integration, protected HUD recovery, transient positioning, group loot, pet battles, and chat |
| `Core/Init.lua` | 2,102 lines | Bootstrap, event routing, popups, notices, slash commands, and shared services |
| `Core/Mainhand.lua` | 2,078 lines | Geometry anchors, Edit Mode layout generation, and gamepad navigation adapters |

Line counts are planning indicators, not extraction targets. Ownership and lifecycle boundaries determine the final modules.

## Target boundaries

### Shared UI controls

`UI/Controls.lua` owns reusable control behavior that does not depend on a particular settings screen. `UI/Options.lua` remains responsible for screen composition and navigation. The public `Offhand` entry points remain stable while implementations move.

### Canvas services

Canvas work will be separated by responsibility into compatibility detection, panel registry and ownership, persistence, client-specific bag and map adapters, drag behavior, and recovery. Extractions must preserve registration order and frame lifecycle timing.

### Protected and transient UI

Protected HUD recovery, Edit Mode integration, and transient frame positioning require explicit combat-lockdown and reload boundaries. These areas need live-client evidence before a change is considered complete.

### Mainhand services

Geometry and anchoring, Edit Mode layout creation, and gamepad navigation should become distinct services while preserving the existing public calls and initialization sequence.

### Bootstrap and runtime events

`Core/Init.lua` should retain the smallest practical bootstrap surface. Feature event handling, popup definitions, notices, and command routing can move only after their current timing and dependencies are characterized.

## Refactor phases

1. Establish documentation, load-order assertions, and reusable UI control boundaries.
2. Extract Canvas compatibility detection and panel registry behavior.
3. Extract Canvas persistence and client-specific adapters.
4. Separate protected HUD recovery and transient frame systems.
5. Separate Mainhand geometry, Edit Mode, and gamepad responsibilities.
6. Reduce Options to settings navigation and screen composition.
7. Reassess the architecture before beginning any visual redesign.

Each phase should contain small, reviewable changes. A responsibility moves only after current behavior has characterization coverage.

## Validation gates

Every extraction must satisfy all applicable gates:

- Focused characterization tests for the extracted responsibility.
- All Lua test suites pass.
- All six manifests load identical runtime files in identical order.
- All Lua files pass Lua 5.1 syntax validation.
- XML validation passes.
- Companion preference and package checks pass without changing the frozen Companion hash.
- Protected, secure, reload, or timing-sensitive changes receive live-client testing on each affected client family.
- Packaging validation passes before promotion to a release branch.

Mocked tests prove deterministic logic only. They do not prove protected frame behavior, combat-lockdown behavior, reload safety, or client-specific timing.

## First increment

The first extraction moves slider input parsing from `UI/Options.lua` into `UI/Controls.lua`. It preserves `Offhand.ParseSliderInput`, adds an explicit manifest dependency, and uses the existing slider characterization coverage. This provides a narrow load-order seam for later control extraction without changing layout or appearance.

## Second increment

The second extraction moves external World Map ownership detection into `Core/CanvasCompatibility.lua`. The module owns capability detection and priority for MoveAny, ClassicUIForever, OpenMap, and Leatrix Maps. `Core/Canvas.lua` retains all frame movement, persistence, hooks, coordinate refresh, and protected-frame decisions. Existing public Canvas methods remain stable, and focused characterization covers ownership priority, diagnostics, modern and legacy addon APIs, and fail-closed API errors.

## Third increment

The third extraction moves Canvas frame bookkeeping into `Core/CanvasFrameState.lua`. The module preserves weak-key side-table storage for Forever's native World Map so Offhand markers never enter its protected descendant chain. Ordinary Canvas-managed frames retain their existing marker fields and clearing semantics. Movement, hooks, scheduling, and persistence remain in `Core/Canvas.lua`.

## Fourth increment

The fourth extraction moves load-on-demand panel ownership and tracking into `Core/CanvasPanelRegistry.lua`. The module owns seed mappings, context-bound exclusions, learned Blizzard addon ownership, modern and legacy load APIs, and request diagnostics. `Core/Canvas.lua` retains final client policy, delayed restoration, movement, combat, and topology checks. The existing Canvas methods and profile-owned `workspacePanelLoadAddons` data remain unchanged.

## Fifth increment

The fifth extraction moves native checkbox and radio-button construction into `UI/Controls.lua`. Settings composition and refresh policy remain in `UI/Options.lua`, while click behavior, tooltip wiring, label targets, and enabled styling retain their existing contracts.

## Sixth increment

The sixth extraction moves HUD ownership and client capability predicates into `Core/HUDCompatibility.lua`. Third-party action bar, bag, Minimap, chat, and party-frame detection now share one boundary with Retail and Forever Edit Mode ownership policy. `Core/SeamRedirect.lua` retains all protected-frame positioning, recovery, hooks, and scheduling.

## Seventh increment

The seventh extraction moves the Mainhand rectangle, anchor, geometry revision, callback registry, and public `Offhand.API` geometry contract into `Core/MainhandGeometry.lua`. `Core/Mainhand.lua` retains safe gathering, Edit Mode generation, and gamepad adapters. Combat deferral and callback removal semantics remain unchanged.

## Eighth increment

The eighth extraction moves client capability detection and support diagnostic assembly into `Core/ClientRuntime.lua`. `Core/Init.lua` retains metadata initialization, SavedVariables capture, event dispatch, popups, notices, commands, and layout orchestration. The runtime module loads immediately after Init, once client identity and release metadata are available.

## Branch policy

Structural refactor work targets `addon/develop`. Visual redesign work begins only after the structural phases are accepted and live-client checkpoints are clear. Companion work remains isolated on `companion/develop` and must not be merged into this branch as an incidental dependency.
