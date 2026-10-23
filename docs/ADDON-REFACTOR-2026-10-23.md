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

## Ninth increment

The ninth extraction consolidates Forever Professions and Edit Mode ownership predicates into `Core/CanvasCompatibility.lua`. Canvas continues to own every movement, restore, registration, and protected-frame operation. The compatibility service now provides one client-policy boundary for external map owners and Blizzard-owned panel families.

## Tenth increment

The tenth extraction moves saved Canvas position validation, creation, relative scaling, and boundary clamping into `Core/CanvasPersistence.lua`. `Core/Canvas.lua` retains drag lifecycle, frame mutation, panel ownership, open-state policy, and client adapters. SavedVariables field names and coordinate semantics remain unchanged, while the deterministic persistence calculations now have focused characterization coverage.

## Eleventh increment

The eleventh extraction moves native backpack root identity, mode-independent position lookup, root ownership transfer, open-state normalization, and preferred-root selection into `Core/CanvasBackpackState.lua`. `Core/Canvas.lua` retains all native frame hooks, movement, proxy controls, persistence callbacks, and protected interaction boundaries.

## Twelfth increment

The twelfth extraction moves the reusable bottom-offset calibration control into `UI/Controls.lua`. `UI/Options.lua` retains its public method as a compatibility delegate, while the shared module now owns the input, pixel-step buttons, physical-height clamp, refresh behavior, and layout application callback.

## Thirteenth increment

The thirteenth extraction moves native Gamepad interface and controller-layout capability detection into `Core/MainhandCompatibility.lua`. `Core/Mainhand.lua` retains every focus adapter, frame mutation, Edit Mode transaction, binding decision, and public Mainhand method. The new service is read-only, fails closed when APIs are absent or restricted, and preserves the existing `Offhand.IsGamepadUIEnabled` override priority.

## Fourteenth increment

The fourteenth extraction moves the Mainhand transient-frame registry, nested-frame resolution, protected eligibility policy, and owned scale normalization into `Core/HUDTransientPolicy.lua`. `Core/SeamRedirect.lua` retains secure handlers, preload timing, event hooks, frame positioning, group-loot layout, Pet Battle bounds, and combat deferral. Protected roots remain opt-in through reviewed registry entries.

## Fifteenth increment

The fifteenth extraction moves selected-choice presentation and vertical card stacking into `UI/Controls.lua`. `UI/Options.lua` retains both public methods as compatibility delegates. Selection remains actionable rather than disabled, and card spacing retains the established twelve-unit default while allowing future screens to supply an explicit spacing rule.

## Sixteenth increment

The sixteenth extraction moves the complete settings slider implementation into `UI/Controls.lua`, including typed values, step buttons, physical-pixel dragging, release-time commits, tooltips, and theme refresh. Options retains its local slider registry and construction delegate so settings refresh ownership stays with the screen. Existing slider and theme regressions exercise the extracted implementation.

## Seventeenth increment

The seventeenth extraction moves the complete native Gamepad presentation adapter and its weak-key state into `Core/MainhandGamepad.lua`. The module installs the existing public Mainhand methods before Mainhand creates its event controller. Polling, interface settlement, native anchor restoration, destination drag handles, saved offsets, and ownership checks retain their original sequence. Mainhand diagnostics now obtain menu and reticle status through adapter getters. Existing placement and taint-boundary regressions cover both modules together.

## Eighteenth increment

The eighteenth extraction moves the complete Forever native-bag proxy into `Core/CanvasForeverBags.lua`. Its installer receives explicit Canvas services and installs the existing public methods at the original definition point. The adapter owns its weak-key state, external drag handles, native close observers, bounded reopen attempts, transition reconciliation, and diagnostics. Canvas retains shared geometry, position storage, and generic panel orchestration. Dedicated bag and taint regressions exercise the extracted implementation.

## Nineteenth increment

The nineteenth extraction moves Forever World Map visibility observation, bounded position settlement, external drag and minimize controls, and UIPanel transaction dispatch into `Core/CanvasForeverMap.lua`. The adapter installs at the original definition point with explicit Canvas callbacks. It retains the existing timer sequence, generation cancellation, frame-state service, and external map ownership policy. The map and panel integration suites exercise the extracted implementation.

## Twentieth increment

The twentieth extraction moves topology recommendations from Options into `Core/TopologyDetection.lua`. The existing `Options:DetectTopology` entry point delegates to the service. Exact Companion geometry, mismatch recovery, physical-resolution fallbacks, monitor presets, and aspect-ratio heuristics retain their current behavior. Existing wizard regressions cover these cases through the public settings method.

## Twenty-first increment

The twenty-first extraction moves chat dock ownership, two-observation dock settlement, detached-window presentation, Combat Log reconciliation, and stale chat-position cleanup into `Core/CanvasChat.lua`. The adapter installs the existing Canvas methods and returns the helpers used by drag and restore orchestration. Timer delays, native chat operations, SavedVariables keys, and Chattynator handoff retain their original behavior. Existing chat regressions exercise the extracted implementation.

## Twenty-second increment

The twenty-second extraction moves Edit Mode layout generation, serialized layout transforms, per-character layout records, diagnostics, and user prompts into `Core/MainhandEditMode.lua`. Mainhand retains safe gathering and event coordination. The new module installs the existing public methods before Mainhand registers its event handler, and preserves the layout transaction and persistence sequence. Existing Mainhand placement and taint-boundary regressions cover the module.

## Refactor candidate smoke status

Candidate commit `10453d0941213916f1d7b060b64fc3eeb705bcc2` completed the structural boundary pass on 2026-10-23.

- All 42 Lua suites passed.
- All six manifests passed path, XML, and Lua 5.1 syntax validation with 43 runtime files, including 42 Lua files and one XML file.
- Companion preference and release-metadata tests passed. The frozen Companion remained SHA-256 `81EECE9430885CEAC178A44A42429854524279072305F9F94EE62E7CCD620CCB`.
- Retail and Forever installations were synchronized across 52 packaged files with no hash differences. Their generated `CompanionTopology.lua` and `ForeverState.lua` files were preserved.
- Forever 1.60.1 build 70532 loaded the candidate, completed `/reload`, rendered the Offhand settings panel, and opened Map, bags, and Character. The run used safe single-screen recovery because the window was not spanned, so workspace placement and scaling remain unverified. The only fresh BugGrabber record was attributed to the client's `*** ForceTaint_Strong ***` sentinel rather than Offhand.
- Retail 12.1.5 build 70529 could not reach character selection. Battle.net reported that its configured folder did not contain the correct game version. The direct client remained unauthenticated, so the live-testing workflow stopped without entering credentials. Retail lock, close-reopen timing, Character scaling, and lock-enabled `/reload` remain pending.

The candidate is not ready for promotion until the Retail launcher is repaired and the remaining spanned Retail smoke passes. A spanned Forever placement pass is also still required if the Forever Beta remains available.

## Branch policy

Structural refactor work targets `addon/develop`. Visual redesign work begins only after the structural phases are accepted and live-client checkpoints are clear. Companion work remains isolated on `companion/develop` and must not be merged into this branch as an incidental dependency.
