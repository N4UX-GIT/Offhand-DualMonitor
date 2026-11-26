# Built-in Baganator Bridge

Built-in Offhand bridge for **Baganator**. `Data.lua` supplies facts only (bag
ownership roles, bag name rules, the popup rule, the catalog entry and the
custom bag workspace record setting, whose stored key stays
`baganatorWorkspacePanels`). It also shares Baganator's backpack root name
patterns in the `Baganator` bridge namespace (`backpackRoots`). `Bags.lua` is
the bag persistence provider: the former Baganator branches of
`Core/BagPersistence.lua` and `Core/CanvasPersistence.lua`, moved behind the
bridge contract with unchanged behaviour.

## What Bags.lua does

- Its backpack roots are the names matching `backpackRoots` that are direct
  `UIParent` children. Baganator names every child region after the backpack
  root, so a name match alone (title text, textures, buttons) is not a root;
  saved records under such a child name are pruned.
- Persisted root names resolve directly, which is enough for reload
  restoration before Baganator announces a frame replacement. The one
  global-table scan runs only in a deep discovery pass: after Baganator's own
  `ADDON_LOADED` and after login. Its `BackpackFrameChanged` callback registers
  replacement roots; `BagShow` asks for one deep pass while no root is known
  yet (load orders where Baganator creates its first frame after Offhand's
  login handler).
- Baganator keeps its own native Escape registration and anchor: it is first
  in the escape order, its Escape observer label is
  `baganator_toggle_observer`, workspace restoration leaves its registration
  and a native title drag on Mainhand alone (`selfAnchored`), and on Forever
  its drag-stop reconciles ownership before the next Escape
  (`dragStopCapture`). While Offhand protects a workspace root, the native
  bags parked with the combined backpack are closed.
- It is preserved through the Options panel only, opens through the shared
  bag toggle and claims that toggle, so a second claimant (EllesmereUI on
  Forever) blocks the toggle. A visible root without a rectangle keeps its
  saved open state while Baganator rebuilds its anchor.

## How core reaches it

`bagProvider` (docs/BRIDGES.md, section 4), each call in `pcall` from the bag
persistence engine: `IsRoot`, `IsRootName`, `Discover`, `InstallCallbacks`
(`loadAddon = "Baganator"`, `deepDiscovery`), `IsDirectEscapeRoot`
(`escapeOrder = 10`, `escapeSource`), `CloseParkedBags`, `ClaimsSharedToggle`,
`selfAnchored`, `dragStopCapture` and `panelTransitions = "options"`. It
registers on every client before Baganator exists and reads Baganator's
global when asked, so a Baganator that loads after Offhand is still served.

## Evidence

Automated tests pass (tests/baganator-persistence.lua,
tests/canvas-persistence.lua, tests/bag-discovery-performance.lua with its
memory probe stubbed, tests/bridges-contract.lua). The move itself has not
been run in a live client.
