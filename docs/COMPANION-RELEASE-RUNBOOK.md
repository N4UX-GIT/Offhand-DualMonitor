# Offhand Companion release runbook

This document is the operational source of truth for preparing, publishing,
validating, and communicating Offhand Companion releases through GitHub and the
Microsoft Store. It covers public betas and stable releases. The CurseForge
artifact remains the in-game addon only.

## Release objectives

Every release must satisfy all of the following:

- Addon releases keep the portable Companion frozen at `v2.1.2-beta.18`
  unless the desktop application itself requires an intentional update.
- The addon's public release advances independently while compatible releases
  retain Companion protocol `1` and minimum version `2.1.2-beta.18`.
- GitHub artifacts are built once, checksummed, and traceable to the release
  tag.
- The Microsoft Store package uses the Store-assigned identity and a package
  version that is higher than the currently published x64 package.
- Store and GitHub users receive the same reviewed behavior even though their
  package bytes, signatures, hashes, and update mechanisms differ.
- Public announcements clearly distinguish the addon, Store Companion, and
  portable GitHub Companion.
- No external publication occurs until the release owner approves that action.

## Distribution policy

| Channel | Audience | Artifact | Updates |
| --- | --- | --- | --- |
| CurseForge | Normal addon users | `Offhand-v<VERSION>.zip` | CurseForge client |
| Microsoft Store | Recommended Windows Companion installation | Store-signed MSIX | Microsoft Store |
| GitHub Releases | Source review, checksums, portable Windows build, Wine, and opt-in beta testing | ZIPs, `Offhand.exe`, checksums, attestations | Manual |

The canonical portable Companion is currently:

- Release: `v2.1.2-beta.18`
- Download: <https://github.com/N4UX-GIT/Offhand-DualMonitor/releases/download/v2.1.2-beta.18/Offhand-Companion.zip>
- Standalone `Offhand.exe` SHA-256:
  `A42A45CB149C66EF884308F15A79EE8905C58A94E9B4AE1A3B05B43BAF929F37`
- `Offhand-Companion.zip` SHA-256:
  `AD49BE14A9C8ADF5A888F873CE9B99F183C4AD2924909ECDF52801F303248A93`

Microsoft Security Intelligence completed reviews of the submitted Beta 18
executable and archives without retaining a malware detection; the submission
references are recorded in `SECURITY.md` and `docs/SECURITY-FOLLOWUP.md`. Preserve
the exact bytes above. Edge's **"isn't commonly downloaded"** message for the
unsigned standalone EXE is an application-reputation notice, not a Defender
malware verdict. Prefer the ZIP in public instructions, but treat **"Virus
detected"**, a named malware detection, or a checksum mismatch as a stop
condition requiring a new investigation.

Normal addon releases include those exact bytes in the complete bundle and
reattach the byte-identical `Offhand-Companion.zip` and `Offhand.exe`. This
keeps GitHub's permanent `/releases/latest/download/...` URLs valid without
rebuilding the application.

The canonical end-user `Offhand-Companion.zip` is deliberately runtime-only and
must contain exactly `Offhand.exe`, `README.txt`, and `LICENSE`. Do not place
`build.bat`, source files, manifests, artwork, Linux guidance, or other
development material in that archive. Those files remain available through the
repository and GitHub's automatic source archives. CI and `package.ps1` enforce
the exact three-entry layout.

After the first Store publication is live, use the following links in public
documentation:

- Web listing: <https://apps.microsoft.com/detail/9PL4PW84Q90W>
- Direct Store app link: `ms-windows-store://pdp/?ProductId=9PL4PW84Q90W`
- Portable/source releases:
  <https://github.com/N4UX-GIT/Offhand-DualMonitor/releases>

The Microsoft Store signs the accepted MSIX. It does not sign the portable
GitHub `Offhand.exe`; browser, SmartScreen, or antivirus reputation warnings may
therefore remain possible for the portable channel.

## Responsibility and approval gates

Codex may prepare and validate source, version changes, changelog entries,
release notes, packages, hashes, Store listing text, certification notes, and
announcement drafts. Codex may also execute the GitHub and Partner Center
workflows when the release owner asks it to do so.

The release owner must explicitly approve these external actions at the time
they are performed:

1. Push the release tag or publish/edit a GitHub release.
2. Upload a package or change public Store metadata.
3. Submit a Store update for certification.
4. Publish or replace a CurseForge file or public announcement.
5. Cancel certification, withdraw a release, or remove an existing artifact.

The release owner also performs any CAPTCHA, identity, age, legal, or account
declaration that Partner Center requires personally.

## Version policy

### Public version

The source, addon metadata, UI, Git tag, and GitHub release use semantic release
identifiers such as:

```text
2.1.2-beta.19
v2.1.2-beta.19
```

For an addon-only beta release, update at least:

- Every supported `Offhand*.toc`: `## Version`, `## X-Offhand-Release`, and
  `## X-Offhand-Addon-Release`. These fields identify the actual addon release.
- Keep `## X-Offhand-Companion-Release: beta.18`,
  `## X-Offhand-Companion-Protocol: 1`, and
  `## X-Offhand-Companion-Min-Version: 2.1.2-beta.18` unchanged while the
  frozen Beta 18 Companion remains compatible.
- The addon may advance to another beta or base version without forcing a new
  Companion. Compatibility is determined by protocol and minimum version, not
  by matching the addon's release label.
- Do not change `Companion/Source/Program.cs`, rebuild the executable, or make
  a new Store submission.
- Update `package.ps1`'s default addon version when useful for local packaging.
- Update `CHANGELOG.md` and affected user documentation.

Only when Companion behavior itself must change, update:

- `Companion/Source/Program.cs`:
  - `AssemblyVersion` for the compatible base release.
  - `AssemblyFileVersion` for the exact build.
  - `AssemblyInformationalVersion` for the full public version.
  - the supported Companion protocol only when the integration contract changes.
- The TOC Companion release, protocol, and minimum-version fields as required.
- The frozen tag and SHA-256 in `.github/workflows/release.yml`,
  `package.ps1`, and this runbook after the new artifact is approved.

### Microsoft Store package version

The Store package version is an independent, monotonically increasing delivery
version. Its fourth component must remain `0`.

| Public version | Store package version |
| --- | --- |
| `2.1.2-beta.13` | `2.1.13.0` |
| `2.1.2-beta.14` | `2.1.14.0` |
| `2.1.2-beta.15` | `2.1.15.0` |
| `2.1.2-beta.18` | `2.1.18.0` |
| `2.1.2` stable | The next unused version greater than the published package |

Never reduce the Store package version to match the public patch number. For
example, after publishing `2.1.13.0`, do not submit `2.1.2.0`; existing users
would not receive it as an upgrade. Record the last submitted Store version in
the release record at the end of this document.

## Release lanes and cadence

Use two release lanes:

### Beta lane

1. Publish a GitHub prerelease for opt-in testers.
2. Allow a minimum soak period appropriate to the change. Use 24–48 hours for
   ordinary fixes and longer for topology, recovery, protected UI, saved-data,
   or security-sensitive changes.
3. Resolve critical regressions and repeat validation.
4. Submit the accepted candidate to the Microsoft Store.
5. Publish the CurseForge addon beta only when addon files changed.

### Stable lane

Promote only a tested beta or release candidate. Do not rebuild unrelated
source merely to remove a beta label: version changes require the same complete
validation and packaging workflow as any other release.

## Per-release execution checklist

### 1. Define and freeze the candidate

- [ ] Record the public version, Store version, target commit, branch, and
      intended release channels.
- [ ] Confirm whether the release changes the addon, Companion, Store listing,
      privacy disclosure, capabilities, supported clients, or screenshots.
- [ ] Review `git status`; preserve unrelated user work.
- [ ] Update the source and documentation version surfaces listed above.
- [ ] Complete `CHANGELOG.md` before tagging.
- [ ] Confirm no secrets, local logs, generated SavedVariables, test captures,
      temporary MSIX staging, or development-only files will enter artifacts.

### 2. Validate the addon

- [ ] Parse loaded Lua with Lua 5.1 and verify every TOC path and load order.
- [ ] Run all repository Lua test suites.
- [ ] Run the addon manifest validator across the supported Offhand TOCs.
- [ ] Check localization keys, saved-variable migrations, and compatibility
      metadata.
- [ ] Complete risk-based live testing: cold login, `/reload`, relog, client
      restart, combat/taint, Edit Mode, recovery, and affected client branches.
- [ ] Record unavailable hardware or clients as explicit validation gaps, not
      passes.

Baseline commands from the repository root:

```powershell
$failed = 0
Get-ChildItem .\tests -Filter '*.lua' | ForEach-Object {
    lua.exe $_.FullName
    if ($LASTEXITCODE -ne 0) { $failed++ }
}
if ($failed -gt 0) { throw "$failed Lua test suites failed." }

powershell -NoProfile -ExecutionPolicy Bypass -File `
  "$env:USERPROFILE\.agents\skills\n4ux-wow-addon-development\scripts\validate-addons.ps1" `
  -ProjectPath (Get-Location)
```

### 3. Validate the Companion

For an addon-only release, do not rebuild. Run the policy tests and verify the
frozen hash. Perform the remaining Companion checks only for an intentional
Companion change.

- [ ] Run `tests/companion-preferences.ps1`.
- [ ] Build `Companion/Offhand.exe` successfully.
- [ ] Visually test normal and high-DPI layout when UI changed.
- [ ] Test launch detection, manual span, delayed auto-span, restore, pause,
      tray, display identification, help, update check, monitor
      disconnect/reconnect, and exit.
- [ ] Verify ordinary `asInvoker` behavior and do not test only as
      administrator.
- [ ] Verify the addon/Companion release mismatch guard.
- [ ] Confirm the documented privacy and network behavior still matches source.

Baseline commands:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File .\tests\companion-preferences.ps1
cmd /c .\Companion\build.bat
```

### 4. Build and inspect GitHub artifacts

The tag-triggered GitHub workflow restores and hash-verifies the published Beta
18 executable for ordinary addon tags. The explicit Companion release lane also
validates and packages the checked-in reviewed executable; it must never rebuild
different bytes after antivirus review.

- [ ] Run release metadata tests.
- [ ] Tag only the reviewed commit using `vMAJOR.MINOR.PATCH`,
      `vMAJOR.MINOR.PATCH-beta.N`, or another supported prerelease form.
- [ ] After approval, push the tag and wait for the release workflow.
- [ ] Verify the workflow succeeded.
- [ ] Download and inspect every addon release's:
  - `Offhand-v<VERSION>.zip`
  - `Offhand-Companion.zip` (frozen Beta 18)
  - `Offhand-Complete-v<VERSION>.zip`
  - `Offhand.exe` (frozen Beta 18)
  - `checksums-sha256.txt`
- [ ] Confirm the complete bundle contains the frozen Beta 18 executable with
      the SHA-256 recorded in the release workflow and package script.
- [ ] For an intentional Companion release only, also inspect
      `Offhand-Companion.zip` and `Offhand.exe` and confirm every container has
      identical executable bytes.
- [ ] Confirm `Offhand-Companion.zip` contains exactly `Offhand.exe`,
      `README.txt`, and `LICENSE`, with no source or executable scripts.
- [ ] Verify the GitHub build-provenance attestations.
- [ ] Confirm the release is marked prerelease or stable correctly.
- [ ] Confirm the release notes contain the hidden
      `offhand-companion-version` marker. For addon-only releases it must remain
      the frozen Companion version; for Companion releases it must match the
      new build.
- [ ] From a beta Companion, confirm **Check for Updates** considers published
      prereleases. From a stable Companion, confirm prereleases are ignored.
- [ ] Test the exact public download links before announcing them.
- [ ] Test the canonical ZIP and standalone EXE in Chrome, Edge, and Brave.
      Record reputation-only warnings separately from antivirus detections.
- [ ] Preserve screenshots and exact hashes for any **"Virus detected"** or
      named-malware result; do not tell testers to disable security software.

Local metadata and packaging checks before creating the tag:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File .\tests\release-metadata.ps1

.\scripts\Restore-FrozenCompanion.ps1
.\package.ps1 -Version 2.1.2-beta.19
Get-Content .\dist\checksums-sha256.txt
```

Use `-CompanionChanged` only after reviewing actual Companion source changes:

```powershell
.\package.ps1 -Version <new-version> -CompanionChanged
```

After the candidate commit is approved, create and push the release tag:

```powershell
git tag -a v2.1.2-beta.19 -m "Offhand v2.1.2 Beta 19"
git push origin v2.1.2-beta.19
```

Replace the example version in every command with the recorded release version.

### 5. Build the Store package (Companion changes only)

Skip this section for addon-only releases. Package the exact reviewed Companion
artifact when the application itself is intentionally updated.

Use the Store-assigned identity already encoded in the builder. Example:

```powershell
.\Companion\Store\Build-StorePackage.ps1 `
  -PackageVersion 2.1.19.0 `
  -CompanionPath .\dist\defender-beta19-current\Offhand.exe `
  -ExpectedCompanionSha256 658B633783CA388C3E525B565D6061D8F75D9DEBB34E0489E04F046218AAF3E3
```

- [ ] Use a Store version higher than the currently published x64 package.
- [ ] Confirm the package name is `N4UX.OffhandCompanion`.
- [ ] Confirm the publisher is
      `CN=E7BD7796-76DA-40C2-B114-9DD85609CD7F`.
- [ ] Confirm architecture `x64`, target family `Windows.Desktop`, expected
      capabilities, and the Windows-managed startup task.
- [ ] Confirm the embedded `Offhand.exe` hash is identical to the reviewed
      portable executable.
- [ ] Inspect the packaged manifest and file list.
- [ ] Record the MSIX filename and SHA-256.
- [ ] Do not sign the production submission with a self-signed certificate.
- [ ] Do not attach the unsigned Store MSIX to a public GitHub release.

The Store package and GitHub executable can have different hashes because the
Store container is separate and Microsoft re-signs accepted packages. They must
nevertheless be built from the same reviewed source and public release version.

### 6. Create the Partner Center update

After explicit approval:

1. Open the existing **Offhand Companion** product. Do not reserve another app
   name or change its package identity.
2. Select **Start update** or **Create a new submission**.
3. Retain the existing free price, markets, discoverability, category, privacy
   statement, age rating, and listing unless behavior changed.
4. Upload the new higher-versioned MSIX and wait for validation.
5. Update **What's new** with user-visible changes.
6. Replace screenshots only when the UI materially changed.
7. Recheck the `runFullTrust` explanation if capabilities or behavior changed.
8. Update certification testing notes with the release version, relevant test
   path, known environmental requirements, and source link.
9. Confirm publishing behavior. The default is to publish automatically after
   certification; use a manual hold only when the release owner requests it.
10. Review every section and stop before **Submit for certification**.
11. After explicit final approval, submit and record the submission date.

Partner Center may display optional **Submission options** as `Incomplete` even
when its information is saved. Treat the active **Submit for certification**
button, absence of validation errors, and persisted capability explanation as
the authoritative readiness signals.

### 7. Monitor certification and publishing

- [ ] Confirm the state changes to **In certification**.
- [ ] Monitor preprocessing, certification, and publishing without cancelling
      or modifying the submission.
- [ ] Review certification failures before changing source or metadata.
- [ ] If approved, wait for **In the Store** and public listing propagation.
- [ ] Record the certification outcome and publication time.

### 8. Post-publication acceptance

- [ ] Open <https://apps.microsoft.com/detail/9PL4PW84Q90W> while signed out or
      in a clean browser session.
- [ ] Exit any portable Companion before installing the Store copy.
- [ ] Install from the Store and confirm the displayed publisher and version.
- [ ] Launch normally and repeat the critical Companion smoke test.
- [ ] Confirm Microsoft Store update behavior and the Windows-managed startup
      entry under **Settings > Apps > Startup**.
- [ ] Confirm Chrome, Brave, and Windows Security no longer block the install
      path. The Store route should not require downloading a ZIP or EXE.
- [ ] Check that the Store listing, screenshot, description, privacy text, and
      support links are correct.

### 9. Publish the addon to CurseForge when required

The CurseForge upload is `Offhand-v<VERSION>.zip`; it does not contain the
Companion executable.

- [ ] Upload only when addon files or compatibility metadata changed.
- [ ] Select **Beta** for beta builds and the appropriate supported game
      versions.
- [ ] Use the same public version and changelog as GitHub.
- [ ] Point the project description's recommended Companion button to the
      Microsoft Store listing.
- [ ] Keep GitHub Releases as the secondary portable/source link.
- [ ] Test the CurseForge file contents and both external links after publish.

### 10. Communicate the release

Do not announce Store availability when a package is only submitted or in
certification. Use two announcements when appropriate.

#### GitHub beta available; Store pending

```text
Offhand <VERSION> is available for opt-in testing through GitHub Releases.
The Microsoft Store update has been submitted and is awaiting certification.
Existing Store users can remain on the current certified build until the update
is delivered automatically.

GitHub beta: <RELEASE URL>
Microsoft Store: https://apps.microsoft.com/detail/9PL4PW84Q90W
```

#### Store update published

```text
Offhand Companion <VERSION> is now available in the Microsoft Store.
Store installations update automatically; users can also open Microsoft Store,
go to Downloads/Library, and check for updates.

Recommended Companion install:
https://apps.microsoft.com/detail/9PL4PW84Q90W

CurseForge continues to provide the in-game addon. GitHub remains available for
source code, checksums, portable builds, and opt-in testing releases.
```

Every announcement must state:

- Whether the build is beta, release candidate, or stable.
- Whether both addon and Companion changed.
- Whether the Store update is pending, certified, or live.
- The correct install link for each channel.
- Any migration, restart, `/reload`, display reselection, or known-issue steps.

## Failure and rollback policy

### Before publication

- Fix the candidate, increment the Store package version, rebuild, and create a
  new submission. Never replace the contents behind an already-published GitHub
  asset without changing the version and documenting it.
- A failed Store submission does not affect the currently published Store
  version.

### After GitHub publication

- Prefer a new release containing the fix.
- If a release is critically unsafe, stop directing users to it and mark it
  clearly. Deleting or replacing assets requires explicit release-owner
  approval and must be documented.

### After Store publication

- For an urgent fix, produce a higher-versioned package and submit it normally.
- Do not expect a lower-versioned package to downgrade users who already
  received the faulty package.
- Microsoft can make an older package available to new acquisitions, but users
  already on a higher version require a higher-versioned corrective release.
- Cancel certification or change publishing time only with explicit approval.

## One-time implementation backlog

Complete these improvements before or as part of the next beta cycle:

1. Make update messaging channel-aware: Store users should rely on Store
   updates, while portable users may check GitHub prereleases.
2. After the first Store publication is verified, change the primary Companion
   links in the root README, CurseForge description, and pinned Discord guidance
   to the Microsoft Store listing.
3. Extend CI to build the Store MSIX from the same reviewed source/canonical
   Companion build and retain it as a private workflow artifact. Never publish
   the unsigned MSIX as a normal GitHub release asset.
4. Add automated validation for public version parity, monotonically increasing
   Store version input, Store manifest identity, and release-note consistency.
5. After at least two successful manual Store updates, evaluate Microsoft Store
   Developer CLI automation. Do not add persistent Partner Center credentials
   until the manual process is stable and the release owner approves that
   security tradeoff.

## Release record template

Copy this section for every candidate and retain it in the release issue, QA
notes, or other durable release record.

```text
Public version:
Release channel: beta / rc / stable
Target commit:
Git tag:
Store package version:
Store package filename:
Store package SHA-256:
GitHub workflow run:
GitHub release URL:
GitHub canonical Offhand.exe SHA-256:
CurseForge file URL or N/A:
Store submission date:
Store certification result:
Store publication date:
Store listing verified by:
Addon automated tests:
Companion automated tests:
Live tests completed:
Known gaps:
Release-owner approvals:
Announcement URLs:
Rollback package retained:
```
