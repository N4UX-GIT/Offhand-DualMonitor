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

If the release notes identify the artifact as a GitHub Actions build, use GitHub
CLI to verify its attestation:

```powershell
gh attestation verify .\Offhand.exe --repo N4UX-GIT/Offhand-DualMonitor
```

An attestation proves build provenance and integrity; it is not an antivirus
verdict or an Authenticode publisher signature. A locally compiled release may
have an official checksum without an attestation.

## What the Companion does

The Windows Companion is a small .NET Framework application. Its source is in
`Companion/Source/Program.cs`, and the release archive includes that source and
the build script used to compile it.

It performs the following operations:

- Enumerates known World of Warcraft processes and their visible top-level
  windows.
- Changes the selected WoW window's border style, position, dimensions, and
  clipping region across the displays selected by the user.
- Reads the connected displays' Windows device names and rectangles so an
  explicit Mainhand/workspace selection survives display reordering and fails
  safely when a saved display is disconnected.
- Registers the user-selected global Span shortcut and `Ctrl+Alt+R` for Restore.
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
persistence, inject code, read browser data, collect telemetry, inspect chat or
gameplay, or handle account credentials.

## Why antivirus false positives can occur

Window-management utilities commonly enumerate processes, manipulate another
application's window, register global hotkeys, and remain in the notification
area. Those legitimate capabilities can overlap with broad heuristic or
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
