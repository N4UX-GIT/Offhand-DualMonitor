# Companion atomic preferences and MSIX structural parity

1 November 2026. Candidate source build: `f7d33ae` on
`codex/companion-next-candidate`. Ordinary public candidate identity remains
`2.1.3-beta.1`, file version `2.1.3.1`. Artifact directory:
`dist/companion-2.1.3-beta.1-rc3`. Earlier candidate iterations remain available.

## Preferences

PreferenceFile.Write validates serializable keys/values before touching disk,
keeps unknown settings keys, sorts deterministically, writes UTF-8 into a unique
sibling temporary file, flushes it and uses File.Replace for an existing target
or File.Move for first creation. No fallback truncates the live file when atomic
replacement is unavailable. SaveConfig retains its ordinary error reporting.
No schema migration, default changes or user configuration reset is introduced.

Preference regression cases passed for Unicode and equals signs in values,
unknown-key retention, interrupted staging, locked destinations, rejected
multiline values, successful replacement, first creation and temporary-file
cleanup. Interrupted and locked writes preserved exact prior bytes. Filesystem
atomicity does not establish survival of every power-loss scenario or Wine
compatibility; live cold-launch and matching-runner tests remain pending.

## Package structure

The installed Store package was read without changing it: production identity
N4UX.OffhandCompanion, version 2.1.20.0. This is local installed evidence only;
it is not a query of the latest Store/Partner Center delivery state.

For structural testing only, MakeAppx built an unsigned MSIX with identity
`N4UX.OffhandCompanion.Validation`, package version `1.0.0.0`. It was not installed,
uploaded, signed or submitted. Its production publisher string, architecture,
capabilities, assets, startup task and executable payload use the existing
packaging path. The separate identity/version are intentional test metadata;
this is not a production update and reserves no production Store version.

`tests/companion-store-package.ps1` verified:

- Exactly the executable, five artwork assets, manifest, block map and content-types file.
- Expected identity/version/publisher, x64 architecture and Windows.Desktop target.
- Only internetClient and runFullTrust capabilities.
- Offhand.exe entry point and disabled Windows-managed startup task.
- Exact embedded executable hash matches the portable candidate.
- Wrong executable hashes and validation/production identity confusion are rejected.

The Store builder now checks its resolved temporary staging path before recursive
cleanup. CI runs the same structural package validation after compilation.
This validator targets unsigned local/submission packages; Microsoft-signed
Store artifacts have additional signing metadata and require post-publication QA.

## Evidence boundaries

Existing Companion preferences/layout, 121 production recovery assertions,
112 per scoped experiment, x64/x86 color/DPI checks (228 ordinary, 232 diagnostic),
113 rollback assertions per architecture and release metadata checks pass.
The package record in `store-validation/store-validation.json` links executable
and MSIX hashes to the candidate. Public Beta 20 executable and archive hashes
remain unchanged. No game process or user preference file was intentionally
modified by these temporary-file and synthetic-window tests.

Pending: real WoW acceptance, Store-channel runtime behavior, signing/certification,
the actual unused delivery version and Wine. Custom-region runtime implementation
remains deferred under its stabilized-main entry criteria.
