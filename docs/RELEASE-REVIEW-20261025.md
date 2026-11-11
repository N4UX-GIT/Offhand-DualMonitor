# Offhand release review, 25 October 2026

Status: private review bundle prepared. Not a public release or Store submission.

## Artifacts

`dist/release-review-20261025-rc1-ready/`

- `Offhand-addon-review-rc1.zip`: installable `Offhand/` root containing the
  current addon development snapshot. Includes pending onboarding, display
  identification, HUD/window-mode recovery and menu-placement changes.
- `companion/companion-classic-graphics-test3/`: unchanged live-tested Classic
  executable, isolated configuration, original build metadata and acceptance notes.
- `companion/companion-retail-graphics-test4/`: unchanged live-tested Retail
  executable, isolated configuration, original build metadata and acceptance notes.
- `source/`: addon and Companion review source plus tests and selected evidence.
- `review-manifest.json` and `SHA256SUMS.txt`: source origins, hashes and gates.

The addon retains compatibility version 2.1.2-beta.22 and adds a private
`X-Offhand-Candidate` TOC marker. No new public version is assigned. Generated
topology/recovery files in the ZIP are inert source placeholders, not installed
monitor or account state. Do not overwrite an installed generated bridge merely
to inspect the package. The local Retail deployment already preserves those files.

Companion EXEs are copied byte-for-byte, not rebuilt or relabeled as approved
release builds. Original candidate JSON records build-time pending status;
ACCEPTANCE.md records subsequent user testing. Classic Test 3 has an earlier
source hash than the current source snapshot; its original metadata is retained.
The snapshot is the current integration proposal, not a claim to reproduce that
historical binary byte-for-byte. No logs, INI preferences, SavedVariables or
diagnostic captures are distributed in this bundle.

## Validation

- 53 addon Lua suites passed, all six TOCs and their Lua/XML references validated
  with Lua 5.1, and diff whitespace checks passed.
- Both client-specific Companion policy builds passed 91 assertions each.
- Companion preferences, topology, layout, DPI, restore, distribution and frozen
  binary packaging regression checks passed.
- Addon ZIP file count, portable paths and every entry hash verified. Accepted
  Companion EXE hashes verified before copying; bundled files have checksums.
- Public frozen Beta 20 EXE remains unchanged in both source checkouts.

## Live evidence

- Anniversary: repeated automatic graphics-reset recovery, cooldown re-arm,
  Pause/Resume cancellation and Restore Window priority confirmed by user.
- Retail: public v22 baseline reproduced the GUI VSync window reset without a
  reported BugSack error. Test 4 recovered and re-armed; repeat/cancellation and
  restore controls subsequently confirmed by user.
- Retail addon development candidate: open Graphics Options stays centered and
  usable through Restore Window and re-span; Options/Escape close/reopen checks
  confirmed with no new BugSack errors reported.
- Geometry: 2560x1440 landscape Mainhand and 1440x2560 portrait Offhand with a
  vertical offset. Results do not establish all display arrangements or clients.

## Release gates

1. Prepare a unified Companion build. Current ordinary compilation leaves
   graphics recovery disabled; accepted candidates use client-specific test
   defines, isolated configuration and disabled launch auto-span. They are not
   suitable for automatic public promotion.
2. Review production configuration migration, automatic-launch arming, inherited
   spans, supported-client scope, failure guidance and removal of test-only text.
   Retest the resulting unified artifact; existing test passes do not transfer
   automatically to changed integration behavior.
3. Complete applicable addon cold-login/reload, combat/protected-action and
   third-party ownership checks on the final candidate. Era and other display
   arrangements have not received this live recovery sequence.
4. Build and validate Store/portable packages, assign final component versions,
   and review release notes and rollback before publication.

The original tester's Midnight hang/excessive-addon-error warning remains
unreproduced. This work resolves the reproduced window-reset path on the tested
configurations; it does not establish the cause of that hang.

## Draft release notes

- Clearer first-time setup with action-led guidance, detected Windowed state,
  one-click Windowed setup and explicit window-placement method selection.
- Mainhand/Offhand labels, better recovery guidance and a resumable calibration
  flow when opening settings or postponing the Mainhand HUD layout.
- Improved HUD behavior when switching between spanned and ordinary windows.
- Open menus recenter when returning to an ordinary window.
- Companion candidate: automatic recovery for the verified graphics-reset
  signature, with bounded attempts, stability checks and manual cancellation.

These are draft claims for review, not a published changelog or a promise that
all development paths have completed live validation.

## Client coverage follow-up

The user's 4 November Forever release milestone now takes priority. See
COMPANION-CLIENT-MATRIX.md for all client families and FOREVER-GRAPHICS-TEST.md
for the next isolated candidate. The previously generated review bundle remains
an immutable earlier snapshot; it does not contain Test 5 or the newer scope
source changes. Do not distribute that snapshot as the final unified rebuild.
Retail and Anniversary live results are retained; Forever Test 5 and Era live
acceptance remain pending. Current three client-scope policy builds pass 104
assertions each. No public binaries or website/download versions changed.

## User acceptance, 25 October 2026

The user considers the structural/UI refactor, first-time setup, HUD/window
restore/menu placement, Forever Gamepad, Bagnon, Party-frame recovery, Dialogue UI,
pet battles and recorded source defect fixed and resolved. Prior pending checklists
for this scope remain historical rather than new release blockers. No additional
live tests are implied. Linux/Wine is assumed fixed with direct reporter
verification outstanding. Performance investigation is the next active work.
