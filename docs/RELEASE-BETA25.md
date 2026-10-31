# Beta 25 release preparation, 31 October 2026

## Source inventory

The preparation merges setup recovery (PR #41) with the primary local addon
snapshot 09c6f31. Released Beta 24 code and current website navigation are
retained. Older primary website content does not replace the published setup
choices. The CurseForge description uses the reviewed evergreen description
and the current Discord invite, J2P3SM6pAY.

Companion HDR/DPI diagnostics and the compact dashboard were committed separately
as 8b9bb25 for companion/develop. The existing graphics-reset/graininess source
is already preserved there. No experimental native executable is included in
the addon release; the shipped Companion remains the frozen Beta 20 artifact.

## Validation

- All 69 Lua 5.1 suites pass on integrated source.
- Six manifests, 64 runtime Lua files and referenced XML/path checks pass.
- Release metadata tests include Beta 25, its pending live checks and the frozen
  Companion boundary. Website integrity checks cover six pages and 280 references.
- Companion preference/layout tests pass on the addon integration source.
- The separate HDR candidate passes preference/layout tests and 216 color/DPI
  assertions for each of the x86 and x64 builds. These are automated checks,
  not acceptance of physical mixed HDR/DPI or native game rendering.
- Package hashes and extracted-file checks are retained in the ignored local
  dist/beta25-preparation-20261031 output and its verification manifest.

## Acceptance and release gate

Anniversary and Retail setup/full-list Repair HUD acceptance is recorded in
SETUP-RECOVERY-GUIDANCE-20261026.md. Retail shared layout selection and tuned
placement acceptance is recorded in tests/QA-notes.md. The local intro cinematic
has a user-reported visual pass; this does not establish native button activation,
standalone movie playback or taint safety.

Expanded notification and vehicle behavior remains a candidate. Before public
release, complete the targeted real native-action, combat/taint, lifecycle and
rollback matrix in RETAIL-NOTIFICATION-CANDIDATE-20261031.md and the contextual
UI audit. Long translations, narrow Mainhand geometry, other client branches,
future Forever release-client behavior and direct Linux/Wine verification remain
explicit gaps. The Anniversary memory-crash report remains unresolved.

Prepare a release PR and local package without pushing the version tag: the
existing tag workflow publishes immediately. Beta 24 remains the public release
until the Beta 25 candidate is accepted and publication is requested.

## Knowledge evidence

Consulted the shared knowledge README and research skill, ran wowkb status and
the package-transformation study with checked source bytes. This supports
separate source/package verification, not native-client or taint claims.
