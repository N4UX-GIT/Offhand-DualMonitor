# Offhand 2.1.2 Beta 24 release

Prepared for GitHub publication on 2026-10-31 from the already tested and
CurseForge-published Beta 24 artifact dated 2026-10-30.

## Scope

The addon payload is the exact 75-file contents of the reviewed Beta 24 ZIP.
It includes the changes and limitations recorded in CHANGELOG.md. Native
Companion binaries and behavior remain the frozen 2.1.2-beta.20 release. Draft
PR #41 is separate work and is not silently merged into this payload. The latest
website publication remains on main and must be retained during promotion.

Tests, packaging/release metadata, supporting QA evidence and the canonical
shared knowledge routing accompany the source commit. The primary working tree
is preserved, including its uncommitted state.

## Evidence

- All 63 Lua suites pass.
- Six manifests, 63 runtime Lua files and referenced XML/path checks pass with
  the Lua 5.1 compiler.
- Standardized release metadata regression passes for Beta 24 and older lanes.
- The local addon-only rebuild matches the tested archive byte-for-byte:
  E8D292748F2A9BB1DF295CFAFAAE6C53315054ADBAF048E6CC7C5E7E88AAD403.
- All 75 archive entry hashes match the retained release manifest; CRC passes.
  No Companion executable, temporary diagnostics or knowledge cache is included
  in the addon-only ZIP.
- Four source paths explicitly preserve their reviewed newline bytes in Git
  attributes so checkout cannot normalize the tested payload.
- Targeted live acceptance: the user tested packaged Beta 24 with stock OpenMap
  v0.7.1-beta on Retail 12.1.5 build 70575 after a restart. Map reopen/close, zoom
  and hover were visible with no fresh errors reported. No local OpenMap patches
  were used. See tests/QA-notes.md for provenance and limitations.

Remaining live coverage includes incoming multi-tab chat and zoning persistence,
two-character shared-layout reuse and rollback, mixed-landscape borders,
combat/taint, physical stacked tooltip/bubble behavior and other client builds.
These are explicit beta limitations, not implied passes.

## Knowledge routing

Consulted the shared knowledge README and research skill, ran wowkb status and
the checked package-transformation method study. That study supports validating
the actual release artifact separately from source. It supplies no native-client
or taint safety evidence. Live source, the tested ZIP and user QA remain the
release authorities.

## Publication

Promote the reviewed release source through addon/develop and a release PR to
main. Tag the main release commit as v2.1.2-beta.24. The existing tagged workflow
builds/attests the addon and complete bundle, restores the frozen Companion
assets, publishes checksums and creates the GitHub beta prerelease. Verify the
published assets and their version/Companion boundary before reporting success.
