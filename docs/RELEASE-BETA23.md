# Beta 23 release preparation, 26 October 2026

Status: prepared addon-only release candidate. GitHub release remains a draft;
no release tag or public publication is authorized by this preparation step.

## Source and contents

- Release branch: `codex/release-beta23`, based on `addon/develop` `e910655`.
- Proposed tag: `v2.1.2-beta.23`; addon metadata is `2.1.2` plus `beta.23`
  consistently across all six manifests. Package default also targets Beta 23.
- Includes the integrated structural/UI refactor, setup/HUD/menu corrections
  and performance work described in `CHANGELOG.md`.
- Frozen Companion remains `2.1.2-beta.20`, protocol 1, minimum beta.19.
  Experimental VSync/graphics recovery and graininess work are excluded.
- No client interfaces, SavedVariables schema, installed files or public
  Companion binaries are changed by release preparation.

## Artifacts

Local output: `dist/release-v2.1.2-beta.23/dist/`.

| File | SHA256 |
| --- | --- |
| `Offhand-v2.1.2-beta.23.zip` (CurseForge addon-only upload) | `D1C4E20D91CBDBA89B78F2F32B5DAAE4AB28537BE9DA68CEC4EC445871228174` |
| `Offhand-Complete-v2.1.2-beta.23.zip` | `02C708E93E3A3C6D29F7F7303B39D996E5AB2A62F60DBEABE4CC292F8328516C` |
| `Offhand-Companion-v2.1.2-beta.20.zip` (unchanged published bytes) | `C726444612DD740BE3F923B83704D155E21BC017F7C5FE245379B19DBECC76E3` |
| `Offhand.exe` (unchanged published bytes) | `81EECE9430885CEAC178A44A42429854524279072305F9F94EE62E7CCD620CCB` |

GitHub also receives the checksum file. Separate release notes and a concise
CurseForge changelog are provided beside the packages. Local draft assets have
not received GitHub Actions build-provenance attestations.

## Validation

- All 55 Lua suites pass.
- All six manifests pass paths/XML and Lua 5.1 syntax validation.
- Companion preference/topology/restore/distribution checks pass without a rebuild.
- Release metadata covers the Beta 23 scope, frozen Companion and punctuation.
- All 74 installable addon files match the release source by hash, including
  their duplicates in the complete bundle. No private candidate markers appear.
- Archive roots/portable paths and exclusion of test tools, developer source and
  player state are checked. Generated bridge files are inert source placeholders.
- Complete bundle Companion and the attached portable archive match their
  frozen hashes. Existing user acceptance remains recorded separately.

## Before publication

Review the release PR and draft, then perform the final packaged-build smoke
test. Merge through the protected `main` release workflow and publish only when
ready. Do not push the tag merely to prepare the draft: the current tag workflow
publishes a prerelease automatically. CurseForge upload uses the addon-only ZIP
and Beta release type; no upload to CurseForge is performed in this preparation.
