# Combined Forever Discord test candidate

The later [combined test.2 candidate](EXTERNAL-ADDON-REPORTS-20261105.md) supersedes
this test.1 checkpoint and adds external-map persistence corrections plus
read-only guide diagnostics. The following artifact evidence is retained.

The combined candidate includes the current Beta 26 Forever controller changes,
automatic first-launch preparation and the short character HUD check. It replaces
the separate Gamepad test.2 and onboarding test.1/test.2 packages for this test
round. It is ready to distribute for testing; native acceptance is pending.

## Artifacts

- Complete Discord bundle:
  `dist/Offhand-Complete-v2.1.2-beta.26-forever-discord.test1.zip`, 1,083,177 bytes.
  SHA256: `F3B7F1308A87AB8970E95B2EAA5D1F0D16E83EF354AE1827E82698BE17C88BF6`.
- Addon only:
  `dist/Offhand-v2.1.2-beta.26-forever-discord.test1.zip`, 823,481 bytes.
  SHA256: `22ED6DF898AA904007523DC2FC7716839B33CCE84F400CF5272D478DD1B56B79`.
- External checksums: `dist/checksums-forever-discord-test1-sha256.txt`.
- Copy-ready announcement:
  `dist/forever-discord-test1-20261105/DISCORD-POST.txt`.
- Install, focused retests, reporting and rollback:
  `dist/forever-discord-test1-20261105/TESTING.txt`.

The complete bundle contains one `Offhand/` addon folder, the optional portable
`Offhand.exe`, README/security/license material, Companion guidance, testing
instructions, a Discord post draft and content checksums. Only `Offhand/` belongs
in `Interface/AddOns`. Existing Companion users can retain their installed app.
The native executable is the unchanged released 2.1.2-beta.20 binary, SHA256
`81EECE9430885CEAC178A44A42429854524279072305F9F94EE62E7CCD620CCB`.
No experimental Companion graphics, HDR or loading-art work is included.

## Candidate behavior

- New/incomplete installations open the preparation guide with the viewport
  inactive until calibration. Placement reloads resume setup. Explicit disable
  is stored separately and remains respected.
- New characters on configured accounts receive Use existing setup, Customize
  HUD and Later. Choices remain outside profiles. Reuse selects a verified
  compatible HUD layout without creating, rewriting or promoting a layout.
- Native Gamepad radial-menu discovery rejects secret/unreadable text before
  lookup or comparison.
- Map presentation, queued keyboard work and grips yield to native Gamepad
  ownership. Keyboard handling can resume after an input mode change.
- Eligible stock loot windows that overflow Mainhand receive bounded correction
  during opening. Protected, externally owned, oversized and other unsafe states
  retain native placement.
- This consolidation adds two small support improvements: blocked layout reuse
  points to combat/Edit Mode recovery, and full diagnostics include account
  setup, automatic guide suppression, resume step and character decision.

The map warning still lacks a complete first error trace. Its resolution and
real menu/map/loot protected-action behavior must be established by native tests.
The black-screen report likewise has no confirmed runtime cause. This package
does not establish that every Forever report is resolved.

## Source and validation

- Base: `9c7e83c9757901f262d568941db56a7bf7272b6f`, the integrated Beta 26 source.
  Candidate source is a frozen working-tree snapshot on
  `addon/forever/gamepad-reports-20261105`, not a new source commit or public
  release. Production files use the known release manifest plus CharacterSetup.
- All 88 Lua 5.1 suites pass in the combined snapshot. This includes the Gamepad
  map/loot/menu changes and the onboarding/character interaction paths together.
- Twelve targeted suites pass against the extracted addon ZIP: first launch,
  minimap entry, character setup/reuse, wizard, lifecycle, diagnostics, Gamepad
  menu secrets, loot, map escape, shared identity and Forever persistence.
- All six manifests pass path, XML and Lua 5.1 syntax validation.
- All 77 addon entries match the validation tree and both extracted archives.
  The complete bundle has 87 portable entries, with 86 internal content checksums
  independently verified. The bundled native executable matches the frozen hash.
- Source bytes stayed unchanged during the build. Only the six staged TOC
  candidate identifiers differ from the source snapshot. Generated topology and
  recovery placeholders match the inert Beta 26 files. No reference cache,
  developer tools, tests, WTF settings or machine recovery snapshot is packaged.
- Snapshot, source hashes, validation tree and verification receipt:
  `dist/forever-discord-test1-20261105/`.

The source tests use synthetic identities where client tuples are needed. The
reporting users' exact release builds remain unknown. Shared knowledge status
and its packaging/persistence guidance were consulted; neither that guidance nor
the simulations establish native behavior or taint safety.

## Acceptance still required

Use the bundled checklist to cover first setup and placement/HUD reloads, two
new characters on a configured account, an existing configured character,
profile creation, Later across reload/cold launch, native menu/map actions,
real loot item selection, input-mode transitions, combat/cinematics and French
wrapping on a narrow Mainhand display. Record the actual client/build, topology,
UI addons and the first fresh error/taint evidence.

No client was launched, installed addon changed, Companion rebuilt, Discord
message sent or public release published as part of this build.
