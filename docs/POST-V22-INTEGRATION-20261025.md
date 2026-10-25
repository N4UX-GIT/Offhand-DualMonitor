# Post-v22 integration, 25 October 2026

User authorization: include all changes after the released v22 checkpoint,
including performance and VSync handling, and commit and merge the work.

## Included source

| Work | Integration location | Evidence |
| --- | --- | --- |
| Structural refactor, 33 increments | `addon/develop`, PR #34 merge `d991de7` | Characterization, manifests and packaging; user acceptance recorded |
| Visual controls, navigation and dialogs | `addon/develop`, PR #35 merge `d197f8d` | User accepts the refactor/UI scope; original tests and evidence retained |
| Setup, display labels, HUD restore/span, menus and legacy bag-provider scope correction | `addon/develop`, source `8e0954c` | Recorded user acceptance, including Retail/Anniversary restore, reload, restart and combat/error checks |
| Verified Retail periodic CPU correction | `addon/develop`, PR #37 `66f413c` | Matched Retail capture plus user acceptance; original `12493b2` is patch-equivalent to the promoted change |
| Remaining performance source and tools | `addon/develop`, merge `4a7b200` of PR #36 branch | Lazy idle snapshots, unchanged proxy-write avoidance, controller scalar fast path, explicit opt-in timing and standalone tools; 55 Lua suites pass |
| VSync/graphics-reset recovery | `companion/develop`, source `0c41626`, merge `8e9b925` | Historical Retail/Anniversary candidate acceptance; three merged-source configurations pass 105 assertions each |
| Graininess/span-presentation comparison | `companion/develop`, source `ed0f189`, merge `1c22ca3`, reconciled at `8e9b925` | Reporter improvement retained as partial evidence; merged-source mode/hidden-window/package checks pass |
| Existing tester acknowledgements | `addon/develop`, `df85227` | Previously uncommitted description retained with requested punctuation style |

The Companion source merge keeps the competing experiments isolated. Recovery
builds omit the experimental resize handshake, while the graininess resize mode
retains it. Configuration paths and diagnostic logging remain isolated; invalid
combinations of experiment/client defines fail compilation. Ordinary builds keep
automatic graphics recovery disabled until production integration is reviewed.

## Validation and scope

- All 55 addon Lua suites and six manifests pass with Lua 5.1 syntax validation.
- Isolated addon-only archive: all 74 extracted files match merged source and
  the extracted addon passes validation. Archive SHA256
  `B116814FC5C0F58ED49C11524B613320D5AC7295FD3BAD5965BF65957518D5C5`,
  stored under
  `D:/Games/World of Warcraft/_offhand_deploy_backups/post-v22-integration-20261025-222240-582/dist/`.
  Its existing Beta 22 metadata identifies a local audit artifact, not a release.
- Companion preferences, topology, restore, distribution and release metadata
  checks pass. Synthetic measurements do not establish native CPU/FPS or taint
  behavior on untested clients.
- Three merged-source recovery configurations pass 105 assertions each. The
  graininess package verifies all eight entries and its isolated-mode checks.
  Both conflicting experiment modes and multiple recovery scopes are rejected
  by explicit compiler guards. Frozen binary hashes are unchanged in both
  integration checkouts.
- Existing functional acceptance is retained. Historical pending lists for the
  user-accepted refactor/UI scope are not reopened as new blockers.
- Forever live testing remains deferred until the user's November 4 milestone.
  Unified Companion production configuration/startup arming and final-artifact
  acceptance are still release work. Original hang/excessive-error reports and
  unverified Linux/Wine cases retain their separate evidence status.
- Public Beta 20 Companion SHA256 remains
  `81EECE9430885CEAC178A44A42429854524279072305F9F94EE62E7CCD620CCB`.
- This integrates source on `addon/develop` and `companion/develop`. It does not
  assign a new version, alter v22/main, publish a release or replace installed
  addons, generated bridges, SavedVariables or public Companion binaries.

## Older branches

The FancyZones website step, Background Studio clarification, Wine candidate,
contributor Gamepad PR and dependency updates predate the v22 checkpoint or are
separate release/dependency work. They are not silently merged as post-v22 addon
changes. Existing branches are preserved; the superseded Retail CPU source is
accounted for by patch equivalence rather than applied twice.
