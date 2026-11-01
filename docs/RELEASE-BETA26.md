# Beta 26 release preparation, 1 November 2026

## Source inventory

Consolidates the local primary snapshot 3826dfe with addon/develop 202006e,
including the already-integrated Beta 25 guidance and recovery changes. Latest
published website source from main is reconciled without reverting its screenshots
or simplified guide navigation. All dirty local addon source, tests, audit tools
and evidence documents found during the inventory are preserved in Git.

The other active Companion worktrees were clean. Their previously committed
experimental source remains separate; Beta 26 retains the exact published
Beta 20 Companion executable and archive. No native build promotion is intended.

## Validation and evidence

- All 82 Lua 5.1 suites pass on integrated source.
- The panel lifecycle and Retail transient contract audit commands pass. These
  cover named source/model contracts, not unrestricted native-client safety.
- Six manifests, 64 runtime Lua files, referenced XML and paths pass validation.
- Release metadata includes Beta 26 scope, assumption-based acceptance and frozen
  Companion boundaries. Website integrity covers six pages and 295 references.
- Verify all addon archive bytes against source and run the complete suite against
  extracted runtime with development-only helpers kept outside the distributable.
- Verify complete-bundle addon parity and the canonical Beta 20 executable hash.
  Record package hashes and final source commit in the dated output manifest.

The reported Retail pet-battle disappearance has user acceptance. Anniversary
test.11 default bags and the reported Baganator/Bagnon reload/Escape cases have
user acceptance; exact replacement versions and broader live dimensions were not
recorded. Six later Retail ownership findings have assumption-based acceptance
on the user's instruction, not a newly observed live test matrix. The relevant
issue documents retain this distinction.

Remaining gaps include native actions, combat/taint, cold login, bank and broader
topology/compatibility coverage, help-card visual fit, translation expansion,
Forever release-client testing and direct Linux/Wine verification. The separate
Anniversary memory-crash report remains unresolved.

## Release boundary

Merge the reviewed candidate into addon/develop through required CI and security
checks. Keep the release PR to main in draft pending remaining live checks. Prepare
the CurseForge addon-only ZIP, complete bundle, changelog, release notes, checksums
and GitHub draft without pushing a version tag or publishing. Prior Beta 25
artifacts remain preserved for comparison and rollback.

## Shared knowledge

The shared knowledge README/research skill and development/testing/Offhand
references were consulted in this conversation. Current status and the checked
package-transformation method study were consulted for this release. The source
study supports separate artifact verification; it supplies no native or taint pass.
