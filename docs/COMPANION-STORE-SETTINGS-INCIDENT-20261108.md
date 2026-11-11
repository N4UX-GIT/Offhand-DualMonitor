# Store settings persistence incident, 2026-11-08

## Reports and evidence boundary

Two Discord users reported that the Store Companion 2.1.3 cannot span after
updating. Logs repeatedly show `Cannot save settings: The parameter is incorrect.`
One user explicitly reports that the portable GitHub build works. Another log
shows Store-managed updates, Companion 2.1.3 and installed add-on beta.26.

The messages establish settings persistence failures, but do not identify the
failing filesystem call, HRESULT or affected Windows versions. In the released
source, manual display selection and identity confirmation save preferences
before spanning. A write failure can therefore block Span WoW Now. Updating the
add-on cannot repair Companion preference writes.

Local Windows 11 Pro 10.0.26200 and the installed Store identity
`N4UX.OffhandCompanion_2.1.300.0_x64__bwe0ea6astzt8` were inspected. Isolated native
probes under this identity passed staging, durable flush, File.Replace with and
without a backup, and same-directory MoveFileEx. Fresh, legacy and shadowed
AppData scenarios passed locally. A same-value write through the exact installed
production PreferenceFile implementation also passed; both real and redirected
preference paths were backed up first and restored byte-for-byte afterward.

**The exact reported failure has not reproduced locally.** MSIX AppData
redirection and replacement compatibility are investigated boundaries, not a
confirmed root cause on the reporting machines. Error87 is exercised through
explicit fault injection, not claimed as an observed local Store failure.

## Candidate mitigation

Short-lived branch: `companion/hotfix-store-settings-2131`.
Public product version remains 2.1.3; candidate EXE/manifest build is 2.1.3.10.
Proposed Store package version is 2.1.301.0, above published 2.1.300.0.

- Packaged builds resolve the current package family and use the explicit
  `LocalAppData/Packages/<family>/LocalState/OffhandConfig.ini` path. Staging and
  destination are in the same physical package-data directory.
- When that file does not exist, read the old logical AppData path through the
  package context so Windows can expose the existing redirected preferences.
  Import on the next normal save, preserving unknown keys and the old files.
  Portable paths and startup read-only behavior remain unchanged.
- If File.Replace specifically returns HRESULT0x80070057, attempt immediate
  same-directory MoveFileExW with REPLACE_EXISTING and WRITE_THROUGH. There is no
  truncate, delete-first, copy-across-volumes or reboot fallback. Other errors
  remain failures. Failed writes retain last-good data in the exercised cases.
- Save failures name the operation and HRESULT. Cleanup cannot hide the primary
  error. Startup and copied diagnostics identify exact build and storage mode;
  copied diagnostics also include the Windows version.

The native import tripwire explicitly reviews GetCurrentPackageFamilyName and
MoveFileExW. Both are package/filesystem operations. Existing process/input
restrictions remain in force; no memory access, game input, injection or new
WoW integration is introduced.

## Verification

- `tests/companion-store-persistence.ps1`:25 checks in ordinary portable context.
- The same fixture with `-InstalledStoreContext`:47 checks under the installed
  Store identity, including writes inside its real LocalState. The fixture never
  installs/replaces a package or writes the real Companion preferences.
- Both cover legacy import, repeated saves, Unicode/unknown keys, interrupted
  import, real locked-file failures, simulated error87/native rename success,
  sharing/access/disk-full rejection, cross-directory refusal and preservation.
- Existing preference/dashboard tests passed, including100%-200% scaling.
  Display selection, partial/multiple/flexible plans, named profiles, layout
  documents, third-monitor policies and taskbar presentation passed.
- Native span/Restore rollback fixtures passed3057 assertions per architecture,
  including custom clipping and failure stages. Production/experimental recovery,
  color/diagnostics and restricted-interaction checks passed.
- The candidate portable ZIP and unsigned MSIX were prepared. The MSIX identity,
  startup/capability/file boundaries and embedded EXE hash matched the candidate.
  No candidate package installation, WACK result, Store submission or new WoW
  live acceptance is claimed.

The original2.1.3 frozen runtime and receipt remain immutable. Historical CI
verification pins the original receipt and exact artifacts while allowing new
native source development. That validation mode cannot prepare packages. The
ordinary2.1.3 packaging path still rejects changed source; its explicit rejection
is tested so this candidate cannot masquerade as the old Store submission.

## Artifacts and publication status

Local directory: `dist/store-settings-hotfix/`.

- `candidate-build10/Offhand.exe`
  SHA256:47FF105C62B32D5A77B369DDFB1FCC2E6D14E6926CCFDEE53AC3A1C6907FA30C.
- `candidate-build10/Offhand-Companion-v2.1.3-hotfix-candidate-build10.zip`
  SHA256:18CDBF1AF04844F0DE6E2CFF615638F991F57267CA4D5FDF026DC6F76917CCD5.
- `store-build10/Offhand-Companion_2_1_301_0_x64.msix`
  SHA256:BE5F13B064CF1B208BDF3BD31A21360A216C3AACBCF8A17344FDADDACD99DA8C.

The build receipt records the original build base and dirty-source state.
The final acceptance receipt additionally binds its recorded inputs to the
committed hotfix source. Existing public releases and Store installation remain
unchanged. No add-on runtime/TOC update is needed for this settings-only change;
the existing protocol and Beta27 package remain compatible.

Before production rollout, validate the exact new package/upgrade via a Store
flight or isolated development installation, run final certification checks and
obtain affected-environment evidence. Running a portable EXE alone cannot
validate the Store data path. A new public submission remains a separate owner
action under the release runbook.

## Immediate support guidance

Exit Store Companion through its tray menu and run the published portable2.1.3
ZIP. Review displays and Mainhand, Span WoW Now and /reload. Keep Store installed
and avoid Reset/uninstall while preferences may be needed. Do not delete saved
settings, disable antivirus or elevate WoW/Companion to work around this report.

If the failure persists, request exact Windows version, Companion build,
Store/portable channel, operation and fresh activity-log/diagnostic text. A
failure with the candidate should now identify its stage and HRESULT.

References:
[Microsoft packaged desktop AppData behavior](https://learn.microsoft.com/en-us/windows/uwp/porting/desktop-to-uwp-behind-the-scenes),
[package query APIs](https://learn.microsoft.com/en-us/windows/win32/appxpkg/functions),
[MoveFileExW](https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-movefileexw).

## Packaged upgrade and WACK follow-up

The owner confirmed that the reporters used the latest Store version and
authorized the remaining upgrade/preflight checks. Partner Center Current
packages independently showed Submission3, version2.1.300.0. Its overview offered
Start update with no in-flight product update.

After owner-approved UAC elevation, a distinct
`N4UX.OffhandCompanion.HotfixValidation` unsigned-OID package was installed at
2.1.300.0 and upgraded in place to2.1.301.0. Its baseline and hotfix Offhand.exe
payloads exactly matched the frozen production/candidate hashes above. No
certificate was imported and Developer Mode was not changed. Only the isolated
test identity was installed; the production submission package was not installed.

An ordinary-user fixture loaded each installed executable's own CompanionForm
and exercised its actual settings load/save entry points. Polling was stopped
before any message loop; no WoW input, game-window change or addon write occurred.
Synthetic legacy settings survived package replacement and were imported to
LocalState. Repeated saves, process relaunch, unknown/non-ASCII values, real
locked-file rejection, staging cleanup and retry after unlock passed. The first
Windows PowerShell runner seed decoded a non-ASCII literal using its default
ANSI code page; equality against actual legacy bytes was verified, followed by
an explicit UTF8 Unicode round trip against the installed hotfix payload.

The isolated package was removed. The real Store package identity and all three
real preference-path existence/hash snapshots remained unchanged. This is a
real isolated MSIX upgrade with exact EXE payloads, not the production-PFN
upgrade or reproduction on an affected user's Windows build.

WACK10.0.19041.685 ran on the exact unsigned production submission MSIX using
`-noinstallappx`: overall PASS, PARTIAL_RUN=FALSE, all13 required tests passed,
10 optional tests passed and one optional finding was reviewed and retained.
Test88 reports existing URI Process.Start calls and CsI. Exact-byte analysis
places CsI at EXE offset453974 within image2 of the unchanged Offhand icon,
a9408-byte PNG. The complete image payload matches the source icon. These are
not a csi.exe launch or new process integration. No binary suppression change
was made. The MSIX hash remains BE5F13B064CF1B208BDF3BD31A21360A216C3AACBCF8A17344FDADDACD99DA8C.

Frozen Store-hotfix executable/receipt:
`Companion/Prepared/2.1.3-store-hotfix-build10/`.
Local upgrade and WACK evidence:
`dist/store-settings-hotfix/upgrade-validation/`.

A later screenshot was clarified to concern the portable Companion. It reports
incorrect spanning and an unspecified unrecognized in-game command. Keep that
separate from the Store persistence incident; the exact command remains unknown.
Do not claim that this hotfix resolves that distinct report.
