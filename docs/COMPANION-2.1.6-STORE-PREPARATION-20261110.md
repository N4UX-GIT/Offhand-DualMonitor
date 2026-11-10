# Companion 2.1.6 Store preparation

Date: 2026-11-10, Europe/Berlin. Owner approved the UI Preview 8 layout and requested remaining checks and Store submission preparation. This authorizes preparation/testing; no upload, certification submission, public release or website deployment has been performed.

## Planned identity and scope

Product 2.1.6; executable 2.1.6.1; assembly 2.1.6.0; Store MSIX 2.1.600.0, x64. The installed production baseline was independently read as N4UX.OffhandCompanion_2.1.500.0_x64__bwe0ea6astzt8. Store identity, publisher, application ID, minimum Windows version, capabilities and disabled-by-default Windows startup task are retained. Candidate output is separate from all frozen published artifacts.

The new UI includes Setup/Advanced navigation, balanced 32px tabs and 44px actions, updated branding/detected addon metadata, a replayable first-run tutorial and removal of persistent captions/instructions. Advanced holds custom layouts/profiles, standard-layout reset, Auto-span and troubleshooting. New two-monitor custom drafts cover the full Offhand monitor; saved areas remain unchanged. The final tutorial button also exposes Finish as its accessible name.

Companion protocol 1 and topology schemas remain unchanged. Current addon 2.1.5 Pre-Release Beta 28 is compatible: Core/Viewport.lua compares the writer semantically against X-Offhand-Companion-Min-Version (2.1.2-beta.19), rather than requiring equal addon/Companion patch versions. No addon files or release labels are changed; published add-on and website download references stay on their currently published 2.1.5 assets until the new Companion is actually released.

## Version and package references

Microsoft reserves the final MSIX version component for Store use and requires submission packages to end in zero; the applicable highest version is selected for delivery. See [Microsoft package version guidance](https://learn.microsoft.com/en-us/windows/apps/publish/publish-your-app/package-version-numbering). Account-side highest published/in-flight ordering must still be checked before a future upload; installed-package ordering is not an account-side query.

WACK is a local preflight, not Store certification. The configured Desktop Bridge required and optional tests are described in [Microsoft's Desktop Bridge test guidance](https://learn.microsoft.com/en-us/windows/uwp/debug-test-perf/windows-desktop-bridge-app-tests). Exact artifact hashes, complete report status and optional findings must be retained.

## Validation plan and preservation

Run the current Companion suites and Lua regression corpus, freeze the production EXE/portable ZIP, build the exact unsigned production MSIX, validate manifest/boundaries/payload parity, and run an exact-candidate Defender scan. The isolated package probe loads the hash-pinned payload under package identity with monitoring disabled and never calls Span/Restore or game commands. It tests existing custom/profile/Unicode settings, tutorial completion/relaunch/replay, Store routing, locked-save preservation and retry.

The elevated preflight installs and upgrades only N4UX.OffhandCompanion.UpgradeValidation216, from 2.1.500.0 to 2.1.600.0 with exact old/new EXE payloads, then removes that private identity. It does not replace the real Store app, import a certificate or change Developer Mode. WACK analyzes the exact production submission MSIX with -noinstallappx. Real app identity/EXE/preference hashes are checked before/after. A concurrent owner preference change is reported rather than overwritten.

Store certification, production-PFN delivery/upgrade, physical mixed-DPI/hotplug/three-monitor acceptance, Windows 10/Wine runtime acceptance and security reputation remain separate evidence boundaries. This native UI update does not expand prior game/renderer compatibility claims. Current-source native/synthetic tests are distinct from scoped previous game evidence. Shared KB status, Store-preflight findings, runbook and current live source were consulted.

## Results

Prepared from clean source `a43e4fea4e7ddd4f8da8470c2275732c75ac458d`, without preview or diagnostic compilation flags. Product/file/package versions were checked separately. The exact executable was packaged once and was not rebuilt after testing.

| Artifact | SHA-256 |
| --- | --- |
| `dist/companion-2.1.6-candidate-1/Offhand.exe` | `166C6BD750282C4EFDDE12BBE4A64DAFB1E88B2A29C826A86365FEFF741D4879` |
| `dist/companion-2.1.6-candidate-1/store/Offhand-Companion_2_1_600_0_x64.msix` | `87866739AFBA3BD6C9C73FA39F37C4E11CCE80D25A58A3E45C6B21F4234F2691` |
| Internal candidate ZIP | `09F5E72FF8744C1BFDF3D7AE07FE0CD79091E7C26DB17DE072441B77221F8CB4` |

- All current Companion regression groups passed, including layout/tutorial at 100%-200%, settings, monitor identity, regions, profiles, flexible layouts, three-monitor geometry, taskbar presentation, remote desktop policy, rollback, graphics recovery guards, Store update policy and native interaction boundaries. These are native/synthetic checks, not a new physical-monitor or game acceptance run.
- All 114 standalone Lua suites passed. Historical 2.1.3/2.1.5 publication and release metadata checks passed; their frozen binaries were not changed.
- The initial color tests measured a hidden Advanced diagnostics panel. Correcting the fixture to select Advanced before measuring produced passes for production (228 assertions per architecture) and diagnostic (232 per architecture) x64/x86 runs. No product color logic was changed for this failure.
- MSIX identity, application/target family, minimum Windows version, capabilities, disabled startup, file boundaries and exact executable parity passed. Version `2.1.600.0` sorts above installed `2.1.500.0`.
- Under the real installed Store family, the exact candidate passed first-run completion (40 checks) and seen-state relaunch/explicit replay (41 checks) using an isolated configuration. A further package-identity fixture passed 47 persistence checks, including the previous error-87 path, legacy import, Unicode, locks, interruption and failure preservation.
- The separate unsigned validation identity upgraded from package `2.1.500.0` with the frozen published EXE to `2.1.600.0` with the exact candidate. Settings bytes survived deployment unchanged. Baseline, first upgraded launch and relaunch/replay passed 40, 40 and 42 checks respectively. Existing custom/profile/unknown/Unicode keys and Auto-span settings survived tutorial completion and save/retry. The private package was removed afterward. This used a separate diagnostic host loading the hash-pinned payload; it is not acceptance of signed Store delivery or normal production activation.
- WACK `10.0.19041.685` completed with `OVERALL_RESULT=PASS`, `PARTIAL_RUN=FALSE`, exit 0, all 13 required checks passing, 10 optional passing and one optional finding. The exact production MSIX was analyzed with `-noinstallappx`.
- The optional Blocked executables finding reports existing `Process.Start` references and `CsI`. Source review confirms user-triggered external links/settings/update-page opening. The sole case-insensitive ASCII `csi` marker in the exact EXE is at byte 490318, inside the unchanged 9408-byte logo PNG (SHA-256 `5A07E4979187D0DEEC6F098EB8EBE1A0E47ABFA622C753F6CAE3882BEB3DEAC8`), identical to the published 2.1.5 EXE and source icon. It is not an executable payload. This is a reviewed informational finding, not a claim that every WACK check passed.
- A fresh Defender custom scan of the candidate EXE/ZIP/MSIX directory exited 0 and found no threats (engine `1.1.26100.4`, signatures `1.463.220.0`, real-time protection enabled). No Microsoft analyst verdict or reputation guarantee is claimed.
- Final elevated-run preservation checks confirmed the real installed Store package, its EXE and existing portable/Store preference files were unchanged. Frozen published 2.1.5 and canonical Beta 20 artifacts also retain their recorded hashes. No certificate import, Developer Mode change, production package installation or game input occurred.

Machine-readable summary: [companion-216-preflight.json](evidence/companion-216-preflight.json). Raw local reports, fixture receipts and the reviewed plan are under `dist/companion-216-preflight-1`; production artifacts are under `dist/companion-2.1.6-candidate-1`.

## Submission handoff

The local `dist/companion-2.1.6-store-submission` directory contains a byte-identical copy of the checked MSIX, checksum file, What's new text, certification notes, complete WACK report and local evidence. [Submission copy and instructions](../Companion/STORE-SUBMISSION-2.1.6.md) are prepared. Upload only the production MSIX; the private validation packages and diagnostic host are excluded from this handoff.

Ready for the owner's submission step. Immediately before upload, check Partner Center's highest published/in-flight package version and verify the product identity against this record. A read-only account-side check was attempted: the existing overview rendered Submission 6 and Start update, but navigating to Current packages produced Sign in required / session expired. Authentication was not automated and no update draft was created. Consequently no fresh account-side version-ordering acceptance is claimed. Certification, signing, publication and Store-delivered upgrade acceptance remain pending. The current request did not authorize those actions; no new submission, GitHub release, addon publication or website deployment was made.
