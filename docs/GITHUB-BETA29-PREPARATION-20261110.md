# GitHub Beta 29 preparation

This addon hotfix retains the exact CurseForge-ready package validated in the
Discord report investigation. It includes the owner's requested loot-roll
corrections while leaving real simultaneous rolls and combat lifecycle for beta
feedback. The independent Retail friendly-name preference correction is deferred.
Existing Beta 28 behavior for that preference remains in this release source.

## Components and release boundary

| Component | Version | SHA-256 |
| --- | --- | --- |
| Addon ZIP | 2.1.5-beta.29 | `004be4e1fe35dba3bc55f6579ba7d6aa5f5676328fe9c495305f18bbdba9694e` |
| Companion EXE | 2.1.5, file 2.1.5.1 | `95811dbb7020a20e2541ae123e69fe80721c83a0fd52d0ee5557dd6d54dccc2a` |
| Companion portable ZIP | 2.1.5 | `9a8ad31226c659be9dd30f626033118ede597993caf41dc138d329642a361c8f` |

Companion source is unchanged from the accepted build, revision
`7bc07a60113c7c990067d5fd86215ace310399cc`. No rebuild, new executable, Store
submission or native runtime change is part of this addon release. The existing
paired 2.1.5, protocol 1 and minimum 2.1.2-beta.19 declarations are retained.

`Release/Prepared/2.1.5-beta.29/` holds the immutable addon ZIP and its inventory.
The publication builder rejects any runtime, manifest, source, ZIP, native
receipt, executable, portable archive or native source drift. Product files have
explicit Git attributes to retain their reviewed bytes on a fresh checkout.
The complete bundle contains those exact 93 addon entries plus the frozen EXE,
Companion license, updated installation guidance and a publication receipt.
No private QA observer, logs, account data, research cache or active generated
topology/recovery state enters runtime archives.

## Validation and limits

The frozen subject passes 122 Lua suites and six manifests with Lua 5.1 syntax
checks. The previous private candidate had 123 suites; the independent deferred
Retail test is intentionally excluded. The published Retail preference contract
continues to run in the mixed geometry suite. Publication rejection tests cover
changed addon/native bytes, modified source/receipt, new runtime files, archive
boundaries, historical release lanes and refusal to overwrite a published beta.

Native acceptance uses Forever 1.60.1.70862, interface 16001, existing Shaman,
enUS, installed Companion 2.1.6, and explicit equal halves of one physical
2560x1440 display with Mainhand right. Cold launch, options, disable/re-enable,
reload, Restore Window, respan and normal exit/relaunch pass. Active root scale
0.4344242513 releases to 0.6399999857 with scale ownership cleared. EUI core,
Details and ProcDoc coexist; EUI Minimap is not loaded in the final lifecycle
pass. Separate earlier controlled minimap, ProcDoc and Daylight checks retain
their own scope and do not establish exact reporter-profile acceptance.

The final verifier originally read 34 samples across five login/reload sessions
and five logout events, including two full process launches. A cleanup retry
overwrote the last raw trace; the independently retained first-shutdown trace
has 28 samples and passes the same lifecycle checks. Final verification output
and visible relaunch observations remain recorded locally. Four historical
BugGrabber records retain message, stack, time and counter after the instrumented
checks. Initial error-capture absence is not treated as a clean capture.

Actual combat/protected descendant actions, real multi-roll choices, exact tall
set-item tooltips, controller paths, physical portrait/4K hardware and exact
reporter profiles remain unverified. No full supported-client or taint-safety
claim is made. Local state restoration verifies 149 existing paths by hash and
132 original absences, plus disabling the created helper TOC. Config and both
generated bridges are restored; the QA client is closed.

Knowledge routing used the shared WoW knowledge project; packaging guidance is
authored engineering guidance. Installed vendor source and observed Forever
70862 behavior establish the scoped runtime evidence, not the older cached
Forever declarations. No other report is closed merely by this release.

## Preparation and publishing boundary

From a clean committed source checkout:

```powershell
python tests/publication-beta29.py
./tests/release-metadata-beta29.ps1
python scripts/Prepare-Beta29Publication.py --output dist/publication-2.1.5-beta.29
./scripts/New-ReleaseMetadata.ps1 -Tag v2.1.5-beta.29 -CompanionReleaseTag v2.1.5 -ChangelogPath docs/RELEASE-CHANGELOG-BETA29.md -OutputPath dist/publication-2.1.5-beta.29/release-notes.md
```

Upload the five files named in `checksums-sha256.txt` plus the checksum file:
addon ZIP, complete ZIP, frozen portable ZIP, frozen EXE and publication receipt.
Release notes are the Markdown body. The release must be a
draft prerelease and must not replace the stable/latest release. Source promotion
and public publication remain separate owner decisions. The dedicated tagged
workflow also prepares a draft prerelease and guards an already-published tag.
Locally prepared assets do not claim GitHub Actions attestations.
