# Ongoing Companion build

## Custom-region continuation, 2 November 2026

The user subsequently authorized an initial working custom-region implementation.
The active feature branch is `codex/custom-workspace-regions` in
`C:/Users/NAUX/.codex/worktrees/classic-graphics-recovery/Offhand`, retaining the
prepared Companion baseline and its fixes. Prototype 5 is the current unpublished
portable artifact, built from `0df1f29ce7240f6e791ace6bd9b652db61037818`.

It supports a contiguous single-monitor split and a full game monitor with one
movable/resizable rectangular workspace on a second monitor. Visual selectors,
exclusive-mode Save, current-display save validation, manual Span and native
Restore are implemented using schema 1. Exact prototype 5 Retail evidence covers
two-monitor apply/reload, replacement single-monitor Save/apply/reload, matching
viewport diagnostics and exact original native Restore. Earlier Retail cold-start
and Anniversary results retain their original prototype hashes.

An exact prototype 5 Anniversary attempt subsequently passed native custom apply
and exact native Restore, but world QA stopped when another player attacked the
selected character. Diagnostics/reload were not run. Both apps closed normally
and fourteen original files were restored and hash-verified. A subsequent run on
an authorized existing level-1 Paladin passed apply, reload, a fresh matching
viewport diagnostic, Character panel persistence and exact native Restore.
Temporarily enabled error capture recorded no new errors. Both apps closed;
18 originals and two original profile absences were restored. No combat
acceptance is claimed.

Follow-up automated native coverage passed 60 production-custom-clipping Restore
cases on normal/minimized/maximized hidden windows per architecture, including
four injected failure stages and success. The rollback suite now passes 3,057
assertions each on x64 and x86. Production source and prototype 5 bytes are
unchanged. These are native fixture results, not additional WoW lifecycle or
failure-injection acceptance.

An unsigned MSIX structural validation package embeds the exact prototype 5
portable executable. File boundaries, identity, capabilities, opt-in startup and
executable parity passed. It was not installed or submitted. See
[the prototype record](CUSTOM-WORKSPACE-REGIONS-PROTOTYPE.md) for artifact hashes,
evidence limits and remaining release gates.

Targeted Retail HUD follow-up regenerated 47 systems in a prepared legacy-row
fixture and retained them after reload. Fresh row creation was refused at the
account's five-layout cap. Character/bags/spellbook and the Offhand-owned default
map fit the workspace; OpenMap retained its existing oversized external layout.
Native Restore automatically returned to Modern and a fresh full-client viewport
match, with the existing stale-layout notice still visible. All five original
Edit Mode rows and 18 backed-up files were restored. No fresh captured errors
were found. The tested installed addon is newer than the worktree addon; see
[Retail HUD QA](CUSTOM-WORKSPACE-REGIONS-RETAIL-HUD-QA.md) for exact source hashes
and the deliberately prepared fixture boundary.

The initial schema 1 implementation works on the recorded setup. Physical
hotplug, mixed DPI, broader exact-artifact client coverage, fresh HUD creation,
protected actions and Store runtime acceptance remain open. Schema 2 and multiple
independent regions remain deferred. Forever live testing remains deferred until
November 4. Public Beta 20 is unchanged; no promotion or publication occurred.
The release-preparation and historical records below retain their original scope.

## Release preparation, 1 November 2026

Continuation: the ordinary combined candidate now identifies as `2.1.3-beta.1`.
Bounded recovery is integrated for Retail and Anniversary, with manual/auto-span
arming, unchanged production preferences and immediate cancellation on display
edits. Experimental configurations remain separate. See
[production recovery QA](COMPANION-PRODUCTION-RECOVERY-QA.md) for the current
contract and pending final-artifact live acceptance. Public Beta 20 remains frozen.

The candidate branch `codex/companion-next-candidate` reconciles current Companion
integration, the released main baseline, and preserved Wine/auto-span fixes.
See [the preparation record](COMPANION-NEXT-RELEASE-PREPARATION.md) for source
inventory, local builds, validation and remaining production gates. The resize
handshake is now exclusive to the graininess experiment. The later custom-region
continuation above adds schema 1 support; no schema 2 runtime is included.
The older records below remain historical. Forever live testing is still
deferred until November 4, and public Beta 20 bytes are unchanged.

## Source integration, 25 October 2026

The user authorized committing and merging all post-v22 work. Graphics-reset
recovery (`0c41626`) and the graininess experiment (`ed0f189`) are committed and
reconciled on `companion/develop` at `8e9b925`. The descriptions of uncommitted
work below are historical. The original source branches and artifacts are kept.

Merge resolution preserves isolated preferences and logs, disables the resize
handshake in recovery builds and retains it only in the graininess resize mode.
Conflicting experiment defines fail compilation. Each of the three recovery
configurations passes 105 policy assertions; graininess package/mode checks and
ordinary Companion regressions pass. These are merged-source checks, not new
live acceptance of a combined product. Public automatic recovery remains off
in an ordinary build, and the frozen public executable has not changed.

Final production configuration, startup arming and unified-artifact acceptance
remain separate release work. Forever live testing stays deferred until the
user's November 4 milestone. Existing historical passes remain intact.

Updated 25 October 2026. User direction: treat graphics-reset recovery and the
experimental Companion work in **Investigate v21 Forever Beta issue** as one
ongoing Companion build. Defer Forever live testing until its November 4 release
is available, then return to this work. No scheduled reminder or automatic client
launch has been requested.

This is the shared coordination record. Separate worktrees preserve experimental
source and evidence; they are not separate intended public Companion products.
Do not overwrite either candidate with the other or promote one as the final
combined build before reconciliation and final-artifact testing.

## Work to reconcile

| Work | Source | Evidence and current state |
| --- | --- | --- |
| Graphics-reset recovery | `codex/classic-graphics-recovery`, worktree `C:/Users/NAUX/.codex/worktrees/classic-graphics-recovery/Offhand` | Anniversary Test 3 and Retail Test 4 recovery/control sequences accepted on the tested offset portrait setup. Forever Test 5 built, live testing deferred by user. Three scope test builds pass 104 assertions each. |
| Graininess / span presentation | `companion/graininess-test`, worktree `C:/Users/NAUX/.codex/worktrees/companion-graininess-test/Offhand` | Conversation **Investigate v21 Forever Beta issue**, thread `01a163e9-db83-7b01-b33a-d54be5c0e10a`. Reporter says launcher #2 significantly improved sharpness; matching logs, full-sharpness comparison and repeat/cold-launch evidence remain incomplete. |

Both source branches started from `companion/develop` commit
`4ae9d3861b1bda5a1bbedbd5ef5d5748fdfe6eb3`. Each contains uncommitted work.
Inspect live status and diffs before integration; this record does not claim a
merge or a combined executable already exists.

## Important interaction

Graininess Test2 launcher #2 adds a one-pixel height resize, a 50 ms pause and
return to exact bounds. The reporter's improvement is useful evidence, but full
native sharpness is not established. Its unchanged clipping and border removal
make the resize sequence a stronger suspect than border removal alone.

The graphics-reset candidates explicitly omit the inherited experimental resize
handshake. An earlier recovery candidate with it failed to hold the initial span.
Therefore the resize mitigation cannot simply be enabled globally during the
merge. Compare exact geometry, clipping, style and renderer presentation for
initial spanning and graphics-reset recovery separately. Retain both test results
until the conflicting behavior is understood; avoid repeated resize loops.

## Resume after Forever release

1. Record the final client's actual build and preserve addon SavedVariables,
   generated bridges, known-good public binary and rollback backups.
2. Review both experimental source diffs against their common base. Reconcile
   span sequencing, restore behavior, bridge generation, candidate/version
   identity, configuration isolation and recovery ownership in one source build.
3. Reproduce the graininess baseline and resize comparison with matching native
   dimensions/logs. Separate improved sharpness from a complete fix.
4. Test Forever graphics apply/recovery, re-arm, cancellation, menu placement,
   protected HUD, reload and normal cold-launch persistence. Reassess whether
   the old bridge workaround is needed on that final build.
5. Regress Retail and Anniversary on the combined artifact, then complete Era
   and the remaining client matrix. Existing passes apply to historical builds,
   not automatically to the merged executable.
6. Produce one versioned public Companion candidate with portable/Store parity,
   explicit eligibility for unverified clients and reviewed startup/auto-span
   behavior. Publish only after applicable final-artifact checks.

## Existing artifacts

- Graphics candidates: primary `dist/companion-classic-graphics-test3`,
  `dist/companion-retail-graphics-test4`, `dist/companion-forever-graphics-test5`.
- Graininess candidate: primary
  `dist/Offhand-Companion-v2.1.2-beta.20-graininess.test2.zip`.
- Earlier review bundle: `dist/release-review-20261025-rc1-ready.zip`; historical
  snapshot, not the merged build and not inclusive of later Forever Test 5 work.
- Frozen public Beta 20 remains unchanged. No combined build or Store update has
  been published. Original reported hang/excessive-error issue remains unresolved.

Further detail: `COMPANION-CLIENT-MATRIX.md`, `RELEASE-REVIEW-20261025.md`,
graphics worktree `docs/ISSUES.md`, and graininess worktree
`docs/COMPANION-GRAININESS-INVESTIGATION.md`.
