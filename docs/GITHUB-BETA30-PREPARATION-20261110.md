# Beta 30 UI compatibility hotfix preparation

Beta 29 is already published on CurseForge as file 9545550. Its frozen local
addon ZIP, GitHub draft, source PR 109 and prepared Companion assets are retained
unchanged. This follow-up uses a new Beta 30 identity and draft prerelease.
No public release, tag, main merge or CurseForge upload is part of preparation.

## Scope and exact artifacts

The owner requested the previously deferred addon changes on 11 November.
The release starts at frozen Beta 29 source `e46ff590` and now includes:

- Native loot-container ownership correction from `4cac7f1`, unchanged from the
  verified private-row test.
- Expanded EllesmereUI transfers and dependency guidance from `a604625`.
- Questie and linked Social/Quick Join anchor preservation from `6cc8fda`, with
  completed cleanup evidence from `019110e`.
- EllesmereUI linked-anchor/profile-override guidance from `e61bac1`.
- The Retail friendly-name preference correction and migration/logout tests,
  imported selectively from the original local development source.

Unrelated Companion, workspace-sizing, guide-refresh and diagnostics work is
excluded. Previously published Daylight code is unchanged; further testing
remains deferred. The earlier loot-only Beta 30 ZIP is superseded while the
GitHub release is still a draft. Its bytes remain in Git commit `7dc5025` and
an ignored local backup; no published release asset is replaced.

The addon has the same 93 entries as Beta 29. Exactly 25 differ: six TOCs
(release labels only), CHANGELOG.md, README.md, five Core modules, the
EllesmereUI preview and eleven locale dictionaries. The other 68 entries are
byte-identical to the Beta 29 baseline. The publisher checks this explicit
allowlist, exact native-tested loot module, frozen Companion inputs and inert
topology/recovery placeholders, rejecting runtime and inventory drift.

| Artifact | SHA-256 |
| --- | --- |
| Offhand-v2.1.5-beta.30.zip | `4d64f8fa19ae6055c99af75a3346ad2701d76576a664cd8520cd044a255050ed` |
| Native-tested HUDTransientFrames.lua | `377b44efb59d5cb660cccc3c159cc2f1f3e790f48962d55e26278f7e09342ff6` |
| Unchanged Companion 2.1.5 executable | `95811dbb7020a20e2541ae123e69fe80721c83a0fd52d0ee5557dd6d54dccc2a` |
| Unchanged Companion 2.1.5 portable ZIP | `9a8ad31226c659be9dd30f626033118ede597993caf41dc138d329642a361c8f` |

The frozen addon is in `Release/Prepared/2.1.5-beta.30/` with its receipt.
The complete bundle contains the exact addon entries, unchanged Companion EXE,
license, installation instructions and publication receipt. The portable ZIP
and standalone EXE are also separate download options. No native rebuild,
Store submission or compatibility requirement change is included.

## Evidence and limits

The combined release source passes 125 Lua suites, including the expanded
production loot regression, EllesmereUI dependency/transfer/blocker fixtures
and Retail legacy-preference migration/logout checks, plus six manifest/path/
XML/Lua 5.1 syntax checks.
Beta 29 and Beta 30 each pass eight publication rejection tests. Historical
metadata and both beta metadata checks pass. The Beta 29 fixture now reads its
own frozen product bytes, preserving historical acceptance after the version bump.

The native comparison used Forever 1.60.1.70862 and a Companion 2.1.6 spanned
single-display 32:9 split, Mainhand RIGHT. The affected baseline module matched
Beta 29, although other installed private region-sizing work meant this was
module acceptance, not a full frozen-package run. Native add/reflow/removal of
three private frames reproduced baseline seam drift. The corrected module kept
the two remaining rows visible inside Mainhand before and after maintenance.
BugGrabber entry count stayed at the existing four. All 263 original client
files were restored by hash and the private helper was removed after normal
client shutdown. See `FOREVER-LOOT-CRITICAL-20261110.md` for full provenance.

Earlier scoped spanned Forever checks also cover supported EUI cooldown/cast
imports and reload, disabled-module guidance, controlled linked-anchor/override
messages, and native Social/Quick Join anchor-chain preservation. Those are
separate recorded runs, not new full-package native acceptance. Their exact
scope and cleanup are in FOREVER-ELLESMERE-HUD-REFINEMENT-20261110.md,
FOREVER-ELLESMERE-BLOCKERS-20261110.md and FOREVER-QUESTIE-SOCIAL-20261110.md.

Actual item roll choices, expiration/queue behavior, combat/taint acceptance,
native Retail preference behavior, active Questie-objective dragging, populated
or spec-changing tracking-bar imports, exact controller paths, reporter-specific
profiles and physical portrait/4K layouts remain unverified. Global tracking-bar
groups are not transferred. Changelog and release notes state these limits.
The loot change does not force-show expired/cancelled rolls or alter item IDs
or roll decisions. See RETAIL-FRIENDLY-NAMES-20261111.md for one-time migration
semantics and its native evidence gap.

## Reproduction and handoff

From the clean committed release source:

```powershell
python tests/publication-beta29.py
python tests/publication-beta30.py
./tests/release-metadata-beta30.ps1
python scripts/Prepare-Beta30Publication.py --output dist/publication-2.1.5-beta.30
./scripts/New-ReleaseMetadata.ps1 -Tag v2.1.5-beta.30 -CompanionReleaseTag v2.1.5 -ChangelogPath docs/RELEASE-CHANGELOG-BETA30.md -OutputPath dist/publication-2.1.5-beta.30/release-notes.md
```

Upload the files named in checksums-sha256.txt and the checksum file itself to
the draft GitHub prerelease. Use release-notes.md as its body. The separate
curseforge-changelog.md is the friendly CurseForge upload text; use the addon
ZIP as a Beta file when publication is authorized. Do not replace Beta 29.
The tagged Beta 30 workflow also prepares a draft, refuses an already-published
Beta 30 and preserves the historical release lanes. Local assets do not claim
GitHub Actions attestations. Source promotion and publication remain separate.
