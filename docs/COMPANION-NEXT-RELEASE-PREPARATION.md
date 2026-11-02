# Next Companion release preparation

Started 1 November 2026; status reconciled 2 November. Source is consolidated,
bounded production recovery is integrated, and revision 3 has targeted Retail
and Anniversary native passes. Full release acceptance remains open.

## Continuation: combined runtime candidate

Current candidate is **revision 4**, built from `44f1c16`. Source review found
that a failed Restore Window could discard the prior native clipping shape.
Restore now uses the same complete native snapshot rollback as span; 181
synthetic assertions pass on each architecture. Portable ZIP and unsigned MSIX
parity checks pass. See [revision 4 evidence](COMPANION-RC4-RESTORE-EVIDENCE.md).
Its live acceptance is pending. Revision 3 results below remain attached to
revision 3; neither its bytes nor public Beta 20 bytes were replaced.

On 2 November, the same revision 3 also passed targeted Retail `12.1.5.70688`
manual span, two consecutive VSync reset recoveries and Restore priority. See
[the Retail live record](COMPANION-RC3-RETAIL-LIVE-20261102.md). Original settings
were restored and both test processes closed. A follow-up spanned reload and
viewport diagnostic passed under the existing FancyZones manual-canvas profile.
Subsequent temporary Companion selection confirmed direct schema 1 consumption
and viewport matching after cold relaunch. An unexplained disconnect interrupted
direct-mode reload. Full layout, persistence and remaining live matrix cases
are still open; all original profile/config files were restored exactly.

Revision 3 now has a targeted Anniversary `2.5.6.70577` live pass for native
spanning, repeated graphics-reset recovery, Restore/Pause/Resume priority,
manual re-arm and delayed auto-span. The exact artifact is unchanged. See
[the live acceptance record](COMPANION-RC3-ANNIVERSARY-LIVE-20261101.md) for scope
and remaining gates. The test client/candidate are closed, original preferences
and topology are restored, and no publication or Store change occurred.

Revision 3 artifact: `dist/companion-2.1.3-beta.1-rc3`, source build revision
`f7d33ae`. Settings writes are now staged, flushed and atomically published;
interrupted or locked-file saves retain the previous file. Unknown settings and
Unicode values round-trip. This supersedes rc2 for further candidate acceptance.

An unsigned MSIX structural test uses the separate identity
`N4UX.OffhandCompanion.Validation`, package `1.0.0.0`. Its executable exactly
matches the rc3 portable candidate, and file boundaries, desktop target,
capabilities and opt-in startup were verified. This package is neither a Store
submission nor an install/update candidate. Installed production Store version
was read as `2.1.20.0`; that does not establish the latest Partner Center state.
No production Store delivery version is reserved. See
[persistence and package evidence](COMPANION-PERSISTENCE-AND-PACKAGE-EVIDENCE.md).

Further continuation adds operation-level span rollback before generated-file
and native-window changes. Previous topology bytes, exact clipping, style,
bounds and placement are restored on failure; detected external file edits are
preserved and rollback failures are surfaced. x64/x86 synthetic failure tests
each pass 113 assertions. This is a shared stabilization prerequisite for
future custom sizing. It does not establish actual WoW rollback acceptance.
Rollback first shipped locally in rc2; rc3 is the current acceptance artifact.
Retain rc1 and rc2 as historical comparisons.

The new ordinary runtime is now `2.1.3-beta.1` (file/manifest `2.1.3.1`), with
bounded recovery integrated for Retail and Anniversary. Test-only settings,
titles and startup restrictions are separated from production recovery.
Manual and delayed automatic spans can arm after stable verification; adopted
spans after restart cannot. Restore, Pause and display edits cancel ownership.
Unaccepted clients retain normal span/restore without automatic graphics recovery.

See [production recovery QA](COMPANION-PRODUCTION-RECOVERY-QA.md) for the current
contract, automated checks and pending combined-artifact live procedure.
Build with `scripts/New-CompanionReleaseCandidate.ps1` into a fresh directory.
Earlier Beta 20 source-review builds below are historical comparison artifacts.
The historical version-selection and production-integration tasks below are now
implemented locally. Live acceptance, Store delivery version/acceptance and public
promotion remain pending. Custom-region runtime work remains deferred.

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
addon and Companion integration branches. The candidate public identifier is now
`2.1.3-beta.1`; no Store delivery version is reserved. These newly compiled bytes
must never replace the canonical public Beta 20 bytes.

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

## Historical source-review verification and artifacts

The counts and comparison builds in this section predate ordinary-runtime
integration. Current policy/color/rollback counts are recorded in
[production recovery QA](COMPANION-PRODUCTION-RECOVERY-QA.md); rc3 persistence and
MSIX checks are recorded in the evidence linked above.

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
executable. No WoW client was launched during that source-review stage. Later
revision 3 live runs are recorded above. Forever native acceptance
remains deferred until the user's November 4 milestone; record the actual build
then. Historical Retail and Anniversary acceptance applies to the named old
artifacts, not automatically to these rebuilds.

Canonical public executable SHA-256 remains
`81EECE9430885CEAC178A44A42429854524279072305F9F94EE62E7CCD620CCB`.
The checked-in public ZIP is also unchanged.

## Required next release work

1. Complete direct Companion-topology layout and persistence acceptance beyond
   the confirmed schema 1/viewport check. Repeat direct-mode reload after the
   unexplained disconnect and audit fresh errors. Preserve and restore the
   existing manual profile when testing generated topology.
2. Keep the resize comparison experimental until matched logs and repeatable
   sharpness/stability evidence resolve its conflict with recovery.
3. Test the combined artifact across Retail, Anniversary, Era and the final
   Forever build, including cold launch, reload, disconnect, repeated graphics
   resets, cancellation and persistence. Keep unresolved hang/error reports open.
4. Review the already selected `2.1.3-beta.1` metadata, source scope and release
   notes before promotion. Protocol 1 and the addon minimum remain unchanged.
5. Preserve rc3 provenance and hashes. Local portable ZIP checks and unsigned
   MSIX executable parity passed. Verify Store delivery history, choose an unused
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
