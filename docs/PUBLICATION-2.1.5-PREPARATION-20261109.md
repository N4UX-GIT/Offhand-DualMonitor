# Offhand 2.1.5 Pre-Release Beta 28 and Companion 2.1.5

## Reconciliation and component identity

The owner authorized merging and committing local changes, publishing GitHub
releases, and preparing the CurseForge release. CurseForge upload itself is not
part of that request. The add-on remains a Beta file, not a stable Release.

| Local work | Disposition |
| --- | --- |
| Dirty dashboard/add-on checkout | Committed as `b3080f5`, merged into the release branch. Includes first-install Next activation and scoped native QA. |
| Dirty main add-on checkout | Committed as `70d2816`, merged in `5502fbe`. Includes map scale/OpenMap recovery, Forever panel guards, setup placement/visuals, settings/locale improvements, tests and investigations. |
| Companion 2.1.4 dashboard and 2.1.5 Store detection | Preserved through `4bb1ec9`, with the exact Store-submitted 2.1.5 binary unchanged. |
| Current published website/mainline | Merged through `origin/main` at `1f0d000` in `d1cae58`. Kept the new sequential guide plus current links, screenshot-reference guidance and style rules. |
| Other clean historical worktrees | Already committed and preserved. Superseded display investigations and experimental binaries were not replayed over current production source. |
| Clean draft Help PR 100 | Separate proposed next-build Companion source, not uncommitted work. It changes the frozen native runtime and was not replayed into the already-submitted 2.1.5 package. Current Beta 28 guide/settings work is integrated independently. |

Conflict review kept custom-workspace locale keys and new setup/map keys, both
sets of UI regressions, all workspace/runtime modules and the newer published
website. The earlier span report is retained beneath its later confirmed fix.
The reconciled runtime passes 114 Lua suites. Six manifests load 79 runtime files
(78 Lua and one XML); the add-on publication contains 90 files including artwork,
metadata and documentation.

All six TOCs identify add-on `2.1.5-beta.28`, paired clean Companion `2.1.5`,
protocol 1 and unchanged minimum `2.1.2-beta.19`. Core/Init.lua derives the portable
URL from that metadata, resolving to the v2.1.5 Companion asset. Compatible older
standard layouts are not rejected solely because the paired version advanced.

## Frozen native assets and packaging

`Companion/Prepared/2.1.5/` contains the exact submitted EXE, a final minimal
portable ZIP and a source/resource fingerprint receipt. No native rebuild was
performed during this reconciliation.

- Runtime source: `7bc07a60113c7c990067d5fd86215ace310399cc`.
- Product 2.1.5, file 2.1.5.1, Store MSIX 2.1.500.0, Submission 6.
- EXE SHA-256: `95811DBB7020A20E2541AE123E69FE80721C83A0FD52D0EE5557DD6D54DCCC2A`.
- Final portable ZIP SHA-256: `9A8AD31226C659BE9DD30F626033118EDE597993CAF41DC138D329642A361C8F`.
- Store MSIX SHA-256: `9AD0A4F561C27A750885E8030B5E72DFC4FBD80DF8CD507FEB26FB1D335B71CA`.

The ZIP differs from the earlier candidate ZIP only through final portable
guidance; its EXE is unchanged. It contains exactly LICENSE, Offhand.exe and
README.txt. Historical Beta 20 and 2.1.3 prepared files remain untouched.

From a clean committed checkout:

```powershell
./tests/publication-215.ps1
./scripts/Prepare-215Publication.ps1 -OutputDirectory dist/publication-2.1.5
./scripts/New-ReleaseMetadata.ps1 -Tag v2.1.5-beta.28 -CompanionReleaseTag v2.1.5 -OutputPath dist/publication-2.1.5/release-notes.md
```

The builder checks exact native hashes/versions, source/resource fingerprints,
the six manifests, inert generated bridges and the reviewed 90-file inventory.
It refuses dirty source and existing output directories, and reads back/hashes
every ZIP entry. No installed add-on, SavedVariables, user preferences, caches,
private QA files, tests or third-party patch scripts enter runtime archives.

Tag lanes `v2.1.5` and `v2.1.5-beta.28` prepare separate drafts and provenance
attestations using these frozen bytes. Companion is a clean stable component;
the add-on release is explicitly prerelease. The Companion release is published
first so the add-on's portable link has a real destination. The add-on-only ZIP
is also the CurseForge Beta upload artifact; the complete bundle is for GitHub.

## Validation and limits

Before final packaging, 114 Lua 5.1 suites and all six path/XML/syntax checks
passed. All four Studio suites passed, including 96 website-to-Lua crop/fit
comparisons and background-library reload/fallback checks. Website integrity
passed for seven pages and 342 references. Publication checks passed exact-byte,
receipt/source-drift rejection, minimal ZIP and prerelease safeguards, with
historical 2.1.3 preservation tested separately.

Companion's prior exact-candidate WACK, 472 Store fixtures, real identity-bound
NoUpdate/cached-relaunch and 47 Store-identity persistence checks are recorded
under `docs/evidence/companion-215-*.json`. These are not a new normal Store
installation or live WoW run. Full CI and final readback evidence are recorded
after publication in the release receipt.

Store 2.1.5 remains in certification with automatic publication after approval.
The owner chose public submission without waiting for the internal flight.
Actual Store-delivered 2.1.5 upgrade, real Available and real signed-out/offline
behavior remain unverified. Existing fixture failures/timeouts and diagnostic
identity evidence do not close those observations. Full combined exact-package
native WoW, physical mixed-DPI/hotplug/three-monitor, Wine and complete supported-
client combat/taint acceptance also remain open. Existing live evidence retains
its exact client/build/package scope, especially the later settings Test 11 and
dialog Test 9 installed candidates awaiting visual review.

The portable EXE is unsigned. A local exact-build Defender scan found no threats;
there is no Microsoft file-review verdict for this build. Neither a clean scan,
WACK nor Store certification guarantees future antivirus/reputation outcomes.
No security settings were weakened and no installed third-party source was
patched by this publication task.
