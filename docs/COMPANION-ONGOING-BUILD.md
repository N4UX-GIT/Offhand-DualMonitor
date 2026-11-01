# Ongoing Companion build

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
