# Next Companion release preparation

Started 1 November 2026. State: source consolidated and local review builds
prepared; production behavior and live acceptance remain open.

## Source scope

Candidate branch: `codex/companion-next-candidate`, in
`C:/Users/NAUX/.codex/worktrees/classic-graphics-recovery/Offhand`.
The primary checkout remains on `codex/professions-quest-ui`.

| Input | Revision | Treatment |
| --- | --- | --- |
| Companion integration | `7ffeb063356a6e8ff64afd3b6e6a14664eea3bae` | Includes recovery, graininess comparisons, HDR/DPI diagnostics and compact dashboard source |
| Released addon baseline | `5a70ef641305c0a4b37cf2c7d3531746f96443cc` | Merged; current help guidance retained alongside experimental code |
| Preserved Wine fixes | `081356df05c15358a6d6fb631218cb26b72fa047` | Source, regression cases and Linux guidance transplanted without obsolete Beta 22 metadata |
| Historical recovery evidence | `docs/COMPANION-RECOVERY-SOURCE-HISTORY.md` | Retained separately from the released issue ledger |

The Companion, graininess and HDR worktrees were clean at inventory time.
The only Program.cs commit outside candidate ancestry was the Wine change above;
its behavior is now included by transplant. This is a Companion source inventory,
not promotion of all unreleased addon or website branches.

Conflict resolution keeps recovery client scopes, isolated experiment settings,
the graininess sampler and current independent-use guidance. CI retains both
addon and Companion integration branches. No public version or Store version is
reserved yet: the default build still identifies as Beta 20 for source review.
These newly compiled bytes must never replace the canonical public Beta 20 bytes.

## Changes made during preparation

- Ordinary and recovery builds omit the one-pixel resize handshake. Only the
  explicit graininess comparison can enable it. Reporter improvement and the
  recovery candidate's initial-span failure remain conflicting live evidence.
- Wine process-path probing reaches the limited-access fallback after Mono
  exceptions and supplies diagnostics when neither probe works.
- Auto-span requires a valid display plan and stops after a failed operation
  until explicit retry or a new process. Explicit restore remains authoritative.
- Deferred display-selection callbacks use a generation guard and incomplete
  stable-identity settings fall back to legacy display settings.
- Added simulation cases for the plan's 4080x1440 schema 1 partial window.

## Local verification and artifacts

All 63 Lua suites and six TOC manifests passed; Lua 5.1 syntax and XML/path
validation passed. Companion preferences, topology/bridge generation, restore,
update policy and layout checks passed. Recovery policy passed 105 assertions
for each of Classic, Retail and Forever. Color/DPI checks passed on x64 and x86:
216 assertions per ordinary build and 232 per diagnostics build. Release metadata
checks passed. Graininess mode checks include synthetic hidden native windows;
they do not establish WoW rendering correctness.

Review builds are under `dist/companion-preparation-20261101`:

- `baseline/Offhand.exe`: ordinary source build, recovery and resize nudge off.
- `final-diagnostics`: isolated HDR/DPI build and verified three-entry ZIP.
- `final-graininess`: explicit rendering comparisons and eight-entry ZIP.
- `final-classic`, `final-retail`, `final-forever`: scoped recovery builds and ZIPs.
- `preparation-manifest.json`: source hashes, artifact hashes and evidence limits.

These are comparison builds from one source baseline, not a combined production
executable. No WoW client was launched or modified. Forever native acceptance
remains deferred until the user's November 4 milestone; record the actual build
then. Historical Retail and Anniversary acceptance applies to the named old
artifacts, not automatically to these rebuilds.

Canonical public executable SHA-256 remains
`81EECE9430885CEAC178A44A42429854524279072305F9F94EE62E7CCD620CCB`.
The checked-in public ZIP is also unchanged.

## Required next release work

1. Integrate bounded recovery into the ordinary runtime with explicit client
   eligibility. Current builds enable it only through mutually exclusive test
   defines. Review manual span, startup auto-span, restart ownership and re-arm
   together; preserve Restore, Pause, rate limits and failure latches.
2. Keep the resize comparison experimental until matched logs and repeatable
   sharpness/stability evidence resolve its conflict with recovery.
3. Test the combined artifact across Retail, Anniversary, Era and the final
   Forever build, including cold launch, reload, disconnect, repeated graphics
   resets, cancellation and persistence. Keep unresolved hang/error reports open.
4. Set a new Companion public version and unique assembly/manifest identity only
   after the production behavior is selected. Update version-dependent tests,
   build metadata, release notes and compatibility declarations together. Do not
   raise the addon minimum merely because Companion has advanced.
5. Build once, verify portable ZIP bytes and Store parity, choose an unused
   increasing Store package version, then complete packaged and rollback QA.
   Follow COMPANION-RELEASE-RUNBOOK.md for publication gates.

## Workspace-regions investigation

See [CUSTOM-WORKSPACE-REGIONS-INVESTIGATION.md](CUSTOM-WORKSPACE-REGIONS-INVESTIGATION.md).
Investigation is active; runtime feature implementation has not begun. Preserve
the plan's stabilized-main entry criteria and dedicated feature branch.

## Research evidence

Shared knowledge status was consulted on 1 November. Pinned sources were within
their review windows, but full-text search reported a stale index and the broad
Companion question returned no routed evidence. Local engineering guidance and
the actual source above are the evidence used here. No WoW API/build behavior
is inferred from those retrieval gaps. A source-study gap record is also saved
in the shared knowledge project's docs folder.
