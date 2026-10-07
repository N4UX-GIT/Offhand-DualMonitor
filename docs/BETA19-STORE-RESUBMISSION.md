# Offhand Companion Beta 19 — Microsoft Store resubmission

Prepared: 2026-10-06

## Submission status

- Submitted for Microsoft Store certification: **2026-10-06**
- Partner Center product: **Offhand Companion** (`9PL4PW84Q90W`)
- Submission: **Submission 1**
- Current state: **Sent for certification**
- Publishing behavior: publish after successful certification, as configured in
  Partner Center

Do not modify or cancel the submission while certification is running. Record
Microsoft's certification result and publication time when they become
available.

This submitted package predates the final topology-bridge repair. Allow its
certification to complete unchanged. Afterwards, prepare a higher Store package
version containing the reviewed `89C065D28D5EB37A3CCBF868DA006C64E7FD403A50417E8799806DF92E46BF52`
executable; do not attempt to replace the in-certification `2.1.19.0` package.

## Frozen package

- Package: `dist/store/Offhand-Companion_2_1_19_0_x64.msix`
- Package version: `2.1.19.0`
- Package SHA-256:
  `354DD0C3D28221B0F6E15AFD90B75790A9A7FB5A1704537B5DA427F1D20E6E8D`
- Embedded `Offhand.exe` SHA-256:
  `658B633783CA388C3E525B565D6061D8F75D9DEBB34E0489E04F046218AAF3E3`
- Identity: `N4UX.OffhandCompanion`
- Publisher: `CN=E7BD7796-76DA-40C2-B114-9DD85609CD7F`
- Architecture: `x64`

The embedded executable is byte-identical to the executable reviewed by
Microsoft Security Intelligence. The MSIX is intentionally unsigned; the
Microsoft Store signs an accepted production submission.

Before upload, confirm in Partner Center that `2.1.19.0` is higher than every
package version previously submitted for this product. Do not rebuild or edit
the frozen MSIX after recording its hash.

## Defender review evidence

- Executable submission:
  <https://www.microsoft.com/en-us/wdsi/submission/0f90acbe-658a-423b-9430-ea02125a9fc4>
- Minimal portable archive submission:
  <https://www.microsoft.com/en-us/wdsi/submission/4e76f681-9e40-4287-b0d4-14c15de4804d>

Microsoft completed both reviews without retaining a malware detection. Cloud
and client reported no malware detected. The archive review is supporting
evidence; the Store package embeds the separately reviewed executable hash.

## What's new

```text
Improves multi-monitor selection on systems with two or more displays,
including high-DPI and mixed-scaling configurations. Adds clear display
identification, repairs the user-initiated beta update check, and improves the
in-game Companion status guidance. Global hotkey registration has been removed.
```

## Certification notes

```text
Offhand Companion is an open-source, user-controlled window-management utility
for the Offhand World of Warcraft addon. This update replaces the package that
previously failed the Store security scan.

Microsoft Security Intelligence reviewed the exact Offhand.exe embedded in this
MSIX under submission 0f90acbe-658a-423b-9430-ea02125a9fc4. Its SHA-256 is
658B633783CA388C3E525B565D6061D8F75D9DEBB34E0489E04F046218AAF3E3.
Microsoft completed that review without a positive detection; cloud and client
reported no malware detected. Microsoft also reviewed the minimal portable ZIP
under submission 4e76f681-9e40-4287-b0d4-14c15de4804d without retaining a
malware detection.

The app enumerates only known World of Warcraft processes. After the user
selects displays or enables auto-span, it uses standard Win32 window APIs to
resize and position the visible WoW window. It does not inject code, inspect
security tokens, install a service, collect telemetry, or handle credentials.

The runFullTrust capability is required for the desktop window-management
operations described above. internetClient is used only when the user clicks
Check for Updates, which queries the official GitHub Releases API. The declared
startup task is disabled by default and can be enabled or disabled through
Windows Settings > Apps > Startup.

Source code: https://github.com/N4UX-GIT/Offhand-DualMonitor
Security details: https://github.com/N4UX-GIT/Offhand-DualMonitor/blob/main/SECURITY.md

Suggested test:
1. Launch Offhand Companion.
2. Select exactly two displays and a Mainhand display.
3. Click Identify Displays and confirm the temporary labels match the selectors.
4. Launch World of Warcraft, then click Span WoW Now.
5. Click Restore Window and confirm the original window is restored.
6. Enable Auto-span, set a delay, restart WoW, and confirm the delay is observed.
7. Click Check for Updates and confirm the official release check completes.
```

## Submission record

The release owner submitted this package for certification on 2026-10-06. The
next action is monitoring only: preserve the submitted bytes and metadata until
Microsoft reports a certification outcome.
