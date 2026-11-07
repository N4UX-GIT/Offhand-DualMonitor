# Offhand 2.1.3 final local preflight

Update 2026-11-08: [Store Submission 3 is in certification](COMPANION-2.1.3-MICROSOFT-SUBMISSION-20261108.md)
with publishing held manually. Defender remains unsubmitted. The preflight
results and statements below record the earlier 2026-11-07 state.

WACK returned **overall PASS**, with `PARTIAL_RUN=FALSE`, on 2026-11-07 at
22:31:17 Europe/Berlin. All 13 required tests passed. Of the 11 optional tests,
10 passed and one reported a finding, reviewed below. No Microsoft Store or
Defender submission has been made, and no Microsoft determination is claimed.

## Exact candidate and coverage

Source revision: `d2934ef802cf0c8deb62d29fd0c932658e64afa3`.
Companion/add-on product version: `2.1.3`; EXE version: `2.1.3.9`.
Store package: `N4UX.OffhandCompanion`, `2.1.300.0`, x64.

| File | SHA-256 |
| --- | --- |
| Offhand.exe | `88916B6FBAA4FF2E81EC574F8FA248C553ED531AD7A3DC828FF4948568797443` |
| Offhand-Companion-v2.1.3.zip | `C277105FEFA08B8A7EC7B089151D418960FF0378B449375BBBF56B2686AB816A` |
| Offhand-Companion_2_1_300_0_x64.msix | `5F77AA758BD12FB45520381CAEE9FFE1644D868B00D600710E622972708A6F68` |
| Offhand-Complete-v2.1.3.zip | `9E9CB6B8C41C8E3E31C00043BB060D83B2A710607A1232FE5A0A36E08C8BDF52` |

Microsoft WACK `10.0.19041.685` ran on Windows 11 Pro `10.0.26200.0`, using
the SDK's `-noinstallappx` mode. The 24 report test IDs exactly match the 24
Centennial tests configured in this installed SDK; all are marked file-only
by its configuration. None is missing and the test command exited zero.
The installed Store package remained `2.1.20.0`, and its identity, user
preferences and the frozen MSIX hash were unchanged. No certificate import,
sideload or installed-package replacement was used.

This is the installed SDK's complete configured Desktop Bridge file analysis.
It is not an actual Store upgrade, S mode runtime test or live WoW test.
Microsoft describes required and informational optional tests in its
[Desktop Bridge test guidance](https://learn.microsoft.com/en-us/windows/uwp/debug-test-perf/windows-desktop-bridge-app-tests).

## Reviewed optional finding

Optional test 88, Blocked executables, reported `System.Diagnostics.Process.Start`
and apparent executable references `rEG` and `CsI`. Its FAIL result is retained
unaltered in the evidence. It does not change WACK's overall PASS.

- `Process.Start` is present for user-initiated URI navigation. The source opens
  the Microsoft Store product, official GitHub release information, website,
  Discord, CurseForge and Windows display Settings. GitHub release navigation
  uses the official repository API's release URL, with an official Releases
  page fallback. It does not download and execute an update binary.
- `rEG` at EXE byte offset 94019 is inside `.text`, at IL offset 127 in
  `Offhand.Companion.CompanionForm..cctor`. The bytes `72 45 47 01 70` are
  `ldstr` and token `0x70014745`, which resolves to the string `Wow` in the
  exact executable. They are not a registry-tool command string.
- `CsI` at EXE byte offset 451406 is inside `.rsrc`. It is byte-identical to
  bytes in image index 2 of `Media/offhand-logo.ico`, a 9408-byte PNG payload
  embedded at offset 444784. The marker is 6622 bytes into that image.
  It is not a C# interactive-tool command string.

No `reg.exe` or `csi.exe` invocation was found in the compiled C# source.
These are bounded source and exact-byte findings, not a complete security audit.
The binary and icon were not modified to suppress the scanner finding.

## Other completed checks

- All 16 Companion/release regression suites and 101 top-level Lua suites passed.
- All six add-on TOCs, 72 runtime-file boundaries and Lua 5.1 syntax validated.
  All six source add-on version/Companion references resolve to 2.1.3.
- MSIX identity, version ordering against the installed package, capabilities,
  disabled-by-default startup task, boundaries and exact EXE parity passed.
- Fresh processes running the frozen EXE loaded Revision 3 named profiles with
  both game-monitor roles, preserving workspace geometry and source preferences.
- Defender scans found no threats in the exact EXE, minimal ZIP, paired ZIP and
  MSIX, with definitions `1.463.180.0`, engine `1.1.26100.4` and real-time
  protection enabled. All scanned hashes remained unchanged.

## Remaining external checks

Partner Center requires account selection before its highest published and
in-flight versions can be verified. The prepared package sorts higher than the
locally installed `2.1.20.0`; account-side ordering must still be checked before
upload. Actual Store certification, delivery and update are not established.

Defender preparation remains hash-specific and unsubmitted. No current AV
detection has been reproduced. A local clean scan is not a Microsoft review,
SmartScreen reputation result or blanket false-positive exemption. Follow the
[Microsoft developer guidance](https://learn.microsoft.com/en-us/defender-xdr/developer-faq)
and [file submission route](https://www.microsoft.com/en-us/wdsi/filesubmission)
for the actual concern without inventing a threat name.

Full combined live WoW acceptance for this exact clean candidate, affected
reporter hardware, physical mixed-DPI/hotplug/three-monitor, Wine and complete
protected-action coverage remain separate from these automated checks.

## Local receipts

`dist/2.1.3-final-preflight-20261107/` contains the raw `wack-report.xml`,
`wack-summary.json`, runner receipt, exact-byte marker receipts, regression and
scan evidence. XML SHA-256:
`ADD1148B6FA0B36A861C267237375F8F7273D4EF828547EFE8889B82751DCCF0`.
Private preference backups remain local and are excluded from handoffs.

`dist/Offhand-2.1.3-Submission-Handoff-20261107.zip` is the refreshed maintainer
handoff. Its exact Defender samples are separate from its Store MSIX and
supporting evidence. Do not submit that outer ZIP as the runtime sample.
Earlier preparation bundles are historical; their WACK-pending notes are
superseded by this receipt. No runtime rebuild accompanied these report updates.
