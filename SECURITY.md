# Offhand Security and Companion Verification

## Download only from official sources

Obtain the Offhand Companion from the project's official GitHub Releases page:

https://github.com/N4UX-GIT/Offhand-DualMonitor/releases

Do not bypass a browser, antivirus, or SmartScreen warning for an executable
obtained from another source. Official releases provide the source code,
and `checksums-sha256.txt`. A release built by GitHub Actions may additionally
provide a build-provenance attestation when its release notes explicitly say so.

## Verify a release

In PowerShell, calculate the downloaded executable's SHA-256 digest:

```powershell
Get-FileHash -Algorithm SHA256 -LiteralPath .\Offhand.exe
```

Compare the complete digest with the `Offhand.exe` entry in the release's
`checksums-sha256.txt`. A mismatch means the file must not be run.

The executable stored in a source checkout is a convenience build and may have
a different hash because .NET Framework compiler metadata changes between
builds. The executable attached to the GitHub release is canonical. Release
packaging builds it once, reuses those exact bytes in every archive, and records
that hash in `checksums-sha256.txt`.

If the release notes identify the artifact as a GitHub Actions build, use GitHub
CLI to verify its attestation:

```powershell
gh attestation verify .\Offhand.exe --repo N4UX-GIT/Offhand-DualMonitor
```

An attestation proves build provenance and integrity; it is not an antivirus
verdict or an Authenticode publisher signature. A locally compiled release may
have an official checksum without an attestation.

## Current Beta 18 security status

The canonical portable release is **Offhand Companion v2.1.2 Beta 18**. Use the
ZIP as the primary download:

https://github.com/N4UX-GIT/Offhand-DualMonitor/releases/download/v2.1.2-beta.18/Offhand-Companion.zip

Canonical SHA-256 digests:

- `Offhand.exe`: `A42A45CB149C66EF884308F15A79EE8905C58A94E9B4AE1A3B05B43BAF929F37`
- `Offhand-Companion.zip`: `AD49BE14A9C8ADF5A888F873CE9B99F183C4AD2924909ECDF52801F303248A93`

On 2026-10-04, Microsoft Security Intelligence had completed its reviews of
the submitted Beta 18 executable and archives without retaining a malware
detection. The authenticated submission records are:

- https://www.microsoft.com/en-us/wdsi/submission/5520a8b4-e4fa-44a1-aa61-09a9e8078998
- https://www.microsoft.com/en-us/wdsi/submission/c874681f-5e6e-4c5f-9984-354dc76f85c0
- https://www.microsoft.com/en-us/wdsi/submission/ef82d479-bd24-42ab-b4c0-beaee069f869

These determinations apply to the submitted file hashes. They do not transfer
automatically to a rebuilt executable or newly generated archive, and they do
not replace checksum verification or independent review of the source.

## Beta 19 reviewed release candidate

On 2026-10-06, Microsoft Security Intelligence also completed review of the
current Beta 19 release-candidate executable and minimal archive without
retaining a malware detection. Cloud and client reported no malware detected:

- `Offhand.exe` SHA-256:
  `658B633783CA388C3E525B565D6061D8F75D9DEBB34E0489E04F046218AAF3E3`
  ([submission record](https://www.microsoft.com/en-us/wdsi/submission/0f90acbe-658a-423b-9430-ea02125a9fc4))
- `Offhand-Companion.zip` SHA-256:
  `5AFB9C4DED3BC7EB4C05B5758501E94DCD414E21B13A4A105CEE215ED166D87B`
  ([submission record](https://www.microsoft.com/en-us/wdsi/submission/4e76f681-9e40-4287-b0d4-14c15de4804d))

These results apply only to those exact bytes. Until Beta 19 is deliberately
published, the Beta 18 links and hashes above remain the public baseline.

Microsoft Edge may still describe the standalone unsigned executable as
**"isn't commonly downloaded."** That is a SmartScreen application-reputation
notice, not a Microsoft Defender malware detection. Prefer the official ZIP and
verify its checksum. A message such as **"Virus detected"**, a named malware
detection, or a checksum mismatch is different: stop, retain the exact URL and
hash for investigation, and do not advise users to disable security software.

## What the Companion does

The Windows Companion is a small .NET Framework application. Its source is in
`Companion/Source/Program.cs`, with the build script and manifest alongside it
in the public repository. The end-user `Offhand-Companion.zip` intentionally
contains only `Offhand.exe`, a quick-start/security `README.txt`, and `LICENSE`;
development source and scripts are distributed through the repository and
GitHub's source archives rather than mixed into the runtime package.

It performs the following operations:

- Enumerates known World of Warcraft processes and their visible top-level
  windows.
- Changes the selected WoW window's border style, position, dimensions, and
  clipping region across the displays selected by the user.
- Reads the connected displays' Windows device names and rectangles so an
  explicit Mainhand/workspace selection survives display reordering and fails
  safely when a saved display is disconnected.
- Shows temporary, click-through display-identification overlays only when the
  user clicks **Identify Displays**.
- Reads Offhand's installation markers and, for Forever recovery, reads the
  newest valid Offhand SavedVariables only while WoW is fully closed.
- Writes preferences to `%LOCALAPPDATA%\Offhand\OffhandConfig.ini`.
- Generates `Core\ForeverState.lua` and its backup inside the detected Offhand
  installation when the guarded Forever recovery bridge is needed.
- Generates `Core\CompanionTopology.lua` inside the detected Offhand
  installation when spanning. It contains only selected display device names,
  normalized rectangles, dimensions, mode, and generation time; it contains no
  gameplay, account, character, or chat data.
- Makes one HTTPS request to the official GitHub Releases API only when the user
  clicks **Check for Updates**. It opens the official release page only after an
  update is found and the user confirms.

The application requests ordinary `asInvoker` privileges and does not request
administrator access. It does not install a service, configure startup
persistence, inspect process security tokens, inject code, read browser data,
collect telemetry, inspect chat or gameplay, or handle account credentials.

## Why antivirus false positives can occur

Window-management utilities commonly enumerate processes, manipulate another
application's window, and remain in the notification area. Those legitimate
capabilities can overlap with broad heuristic or
machine-learning rules. A new or unsigned executable also lacks established
publisher and file reputation.

VirusTotal aggregates vendor verdicts and does not create or remove those
verdicts. Generic labels should be investigated, not ignored. The project will
publish checksums for each release, publish provenance for CI-built artifacts,
and submit stable release candidates directly to any vendors reporting a
suspected false positive.

## Build from source

From a repository checkout on Windows 10 or 11 with .NET Framework installed:

```powershell
cmd /c Companion\build.bat
```

The script invokes the Windows .NET Framework C# compiler directly and embeds
the application manifest and artwork stored in this repository. Review the
source and build script before compiling.

## Report a vulnerability

Please use GitHub's private vulnerability reporting flow rather than posting
exploit details in a public issue:

https://github.com/N4UX-GIT/Offhand-DualMonitor/security/advisories/new

Include the affected version, reproduction steps, impact, and any suggested
mitigation. Do not include World of Warcraft credentials, tokens, or unrelated
personal data.
