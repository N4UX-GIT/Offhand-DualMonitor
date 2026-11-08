# Display identity hardening in the custom-workspace Companion

## Acceptance update, 2026-11-06

The reporter subsequently confirms successful monitor selection and spanning
with the TV unplugged on the existing setup. Temporary native span recovery is
therefore reporter-confirmed. This is not acceptance of this candidate with
the TV connected. Reload/calibration/persistence/Restore/reconnect outcomes and
exact active-child/path attribution remain unverified.

The subsequent TV-disconnected capture at 01:05:38 UTC returns distinct
legacy and interface IDs for the same DISPLAY13/14 sources: HWV62F5/UID4357 and
BNQ7F2B/UID4355, replacing repeated SNYA401/UID4352. WoW/Companion are absent
in both captures. Disconnecting the disabled TV clears this observed collision;
active-target mapping is the needed permanent repair direction. Temporary
Beta 20 reselection with TV unplugged passes pure-planner checks and now has
reporter-confirmed native span success. Restore, reconnect repeatability and
exact child attribution remain pending. Interface-flag-only enumeration remains
inadequate with TV connected.

The second reporter's native diagnostic v2 baseline now returns identical
interface IDs for both active GDI display names as well as identical legacy IDs,
with no WoW or Companion process detected. A connected but disabled TV is newly
reported. This source's ReadStableDisplayId still queries monitor child index
zero, so changing EDD_GET_DEVICE_INTERFACE_NAME alone does not resolve that
configuration. Ambiguity refusal is the expected defensive result, not a working
span repair. Do not distribute this candidate as a verified fix for this case.

Next evidence: reconnect repeatability, monitor children/state flags and active
source-to-target mapping. A wrong first-child association is a supported
hypothesis, not yet an observed native call-by-call attribution.
QueryDisplayConfig is already used for colour diagnostics but not identity reads.
Further identity resolution work and native acceptance remain required.
Full evolving evidence:
`D:/Tools/Code/Offhand/docs/COMPANION-DISPLAY-SECOND-REPORT-20261106.md`.
No runtime source or native artifact was changed by this acceptance update.

The owner requested that the CurseForge display-selection correction be included
in the main custom-workspace rework and hardened without depending on the reporter
providing exact monitor or dock details. Integrated on
`codex/custom-workspace-regions`, based on `e10d0de`, in
`C:/Users/NAUX/.codex/worktrees/classic-graphics-recovery/Offhand`.

Working reporter versions are Forever, addon Beta 26 and Companion Beta 20, as
directed by the owner. These versions do not establish the reporter's actual
display identities. The confirmed defect is conditional: two checked devices
with the same stored identity resolve to the first display and collapse to one.
Synthetic execution reproduced the misleading two-display error in the actual
released Beta 20 planner. Its executable remains unchanged.

## Integrated behavior

- Windows enumeration requests the documented per-monitor interface name using
  `EDD_GET_DEVICE_INTERFACE_NAME`. The zero-flag ID is retained only as a legacy
  read/migration alias. Reserved `DeviceKey` is not used as a fallback identity.
- One shared resolver handles ordinary spans, partial single/secondary regions,
  schema 2 workspaces, schema 3 flexible documents and editor selections. It
  rejects multiple matches across current IDs and legacy aliases, including
  case variants and cross-namespace collisions. It also rejects ambiguous device
  names and missing current interface IDs before applying a plan.
- Identity preferences use schema 2. Existing schema 1 selections remain readable
  for preview and migration, but cannot arm automatic span without review. An
  unknown future identity version refuses changes rather than being downgraded.
- Migration builds a copy, validates the full active plan, changes active monitor
  bindings to canonical IDs, and preserves physical-pixel region geometry,
  Mainhand/workspace roles, profile IDs, names and unrelated preferences.
- Inactive named-profile stores and flexible fallback snapshots remain byte for
  byte intact. Their uniquely resolvable legacy bindings remain readable; loading
  one still requires review when its identity settings are old. Flexible Save
  writes canonical display bindings without altering region geometry.
- The existing custom editors resolve legacy bindings consistently and retain
  saved numeric rectangles. Missing or ambiguous remembered roles are not silently
  replaced with the primary/first monitor. Ordinary checklist edits are disabled
  while a custom mode owns the display plan.
- Manual Span captures committed controls, invalidates stale identity markers,
  detects a changed display snapshot and preserves untouched missing-display
  evidence. A deferred checkbox callback from a superseded refresh cannot save
  over the newer selection. Cancellation discards staged migration, and a failed
  atomic preference write blocks Apply before any native resize.
- Custom layouts retain their manual-only apply/recovery contract. Native window
  mutation, taskbar handling, clipping rollback and the addon bridge schemas are
  otherwise unchanged. No new process/input/import surface was introduced.

The [Microsoft API contract](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-enumdisplaydevicesw)
documents the per-monitor interface-name flag. The shared knowledge project was
consulted first; the prior investigation records its Windows-specific evidence
gap. Local source, synthetic planner execution and the existing fixtures supply
the engineering evidence. The previous native read-only probe found distinct
old and new IDs on the local display pair, so it does not reproduce the reporter's
physical hardware collision.

## Verification

- `tests/companion-display-selection.ps1`: 154 assertions on each of x64/x86.
  Cases include identical legacy IDs with distinct current IDs; ambiguous current
  IDs and aliases; repeated/malformed selections; missing interface IDs/devices;
  ordinary, split, partial-secondary, multi-region and flexible migration; changed
  resolution; dock-style device renumbering; reorder/missing/reconnect; unknown
  schemas; profile/fallback byte preservation; and editor geometry preservation.
- Existing preferences/dashboard suite passes, including layouts at
  100/125/150/200 percent scaling. Public preferences were protected and restored
  byte for byte around the existing constructor fixtures.
- Existing suites pass: schema 2 workspace regions (352 per architecture),
  flexible layouts (45), named profiles (25), layout documents (239), third
  monitor selection (40), workspace UI (67), partial-topology C# to Lua fixtures,
  taskbar (25), colour/DPI (228), production recovery (121), interaction-boundary
  audit, and native rollback/Restore (3057 per architecture).
- All 92 top-level Lua suites pass. Schema 1 partial-plan, schema 2 and schema 3
  C# bridge fixtures are consumed by the real Lua readers.
- CI now runs the identity suite and the flexible/document suites alongside
  the existing workspace/profile checks.
- Test output is local in `dist/display-identity-integration-20261105/`.

These are source, synthetic topology, editor-construction, native fixture and
bridge-consumer checks. They are not affected-hardware, WoW lifecycle, Store,
Wine or reporter acceptance. Physical docks and identical panels may still
change their interface identities after a port/driver change; a missing or
ambiguous binding refuses Apply and asks for review rather than guessing by
model, resolution, DISPLAY number or enumeration order.

## Release acceptance and artifacts

The next custom-workspace candidate must include this source and be validated
as an exact artifact. Existing Beta 20 and historical workspace test packages
are unchanged and do not gain this fix retroactively. No production executable
was rebuilt or replaced and nothing was published.

Remaining native matrix: migrate/review/cancel/restart; failed settings-write
feedback; normal and custom manual Apply/Restore; identical panels; dock unplug,
replug and port changes; temporarily missing interface IDs; mixed DPI/offset
monitors; and supported Wine behavior. Use available controlled configurations
and failure injection where practical. Reporter details are supplementary evidence,
not a prerequisite for the defensive implementation or this acceptance matrix.
