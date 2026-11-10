# Beta 30 loot-roll hotfix preparation

Beta 29 is already published on CurseForge as file 9545550. Its frozen local
addon ZIP, GitHub draft, source PR 109 and prepared Companion assets are retained
unchanged. This follow-up uses a new Beta 30 identity and draft prerelease.
No public release, tag, source merge or CurseForge upload is part of preparation.

## Scope and exact artifacts

The release branch starts at the frozen Beta 29 source `e46ff590` and applies
only the native managed-container ownership correction from `4cac7f1`, plus
its existing regression fixture. No later EllesmereUI layout-transfer or
Questie/Social recovery implementation is replayed. The Retail friendly-name
correction and further Daylight testing remain deferred. Previously published
Beta 29 functionality, including its Daylight module, is unchanged.

The addon has the same 93 entries as Beta 29. Exactly nine differ: the six TOCs
(release labels only), CHANGELOG.md, README.md and HUDTransientFrames.lua.
Every other entry is byte-identical to the published-release baseline. The
publisher checks this allowlist, the exact native-tested loot module and inert
topology/recovery placeholders, rejecting runtime, native and inventory drift.

| Artifact | SHA-256 |
| --- | --- |
| Offhand-v2.1.5-beta.30.zip | `115b377cadc6df3de9c44f89b2495b760bcb0c1df9075015af22732538f6df71` |
| Native-tested HUDTransientFrames.lua | `377b44efb59d5cb660cccc3c159cc2f1f3e790f48962d55e26278f7e09342ff6` |
| Unchanged Companion 2.1.5 executable | `95811dbb7020a20e2541ae123e69fe80721c83a0fd52d0ee5557dd6d54dccc2a` |
| Unchanged Companion 2.1.5 portable ZIP | `9a8ad31226c659be9dd30f626033118ede597993caf41dc138d329642a361c8f` |

The frozen addon is in `Release/Prepared/2.1.5-beta.30/` with its receipt.
The complete bundle contains the exact addon entries, unchanged Companion EXE,
license, installation instructions and publication receipt. The portable ZIP
and standalone EXE are also separate download options. No native rebuild,
Store submission or compatibility requirement change is included.

## Evidence and limits

The isolated release source passes 122 Lua suites, including the expanded
production loot regression, and six manifest/path/XML/Lua 5.1 syntax checks.
The development branch's two later EllesmereUI suites are intentionally absent.
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

Actual item roll choices, expiration/queue behavior, combat/taint acceptance,
controller paths, reporter-specific profiles and physical portrait/4K layouts
remain unverified. Changelog and release notes state these limits. The change
does not force-show expired/cancelled rolls or alter item IDs or roll decisions.

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
