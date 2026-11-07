# Companion Microsoft Defender review preparation, 2026-11-07

The initial Beta 6 preparation below is superseded by the clean, matched
[2.1.3 Beta 7 candidate](COMPANION-2.1.3-BETA7-CANDIDATE.md). Retain its old
hashes as historical evidence. Use the separate Beta 7 samples and submission
record for a new review; neither set has been submitted to Microsoft.

Status: preparation only. No file has been uploaded and no Microsoft result is
claimed for this candidate. The user requested preparation of the latest
Companion, including the active-display identity correction and reload guidance.
Published Test 3 Revision 4 and the canonical Beta 20 artifacts stay unchanged.

## Candidate and freeze

Prepare a clean-source ordinary Companion 2.1.3 Beta 6 build, file version
2.1.3.7, through `scripts/New-CompanionReleaseCandidate.ps1`, using
`-CustomRegionsPrototype`. The builder compiles the ordinary runtime; that switch
selects the matching runtime README. No graphics experiment or RDP-only test
define is enabled. All supported workspace modes remain in the ordinary binary.

The submission bundle records the clean source revision, source/resource/compiler
hashes, version, unsigned status, native import audit and exact-artifact scan
evidence. The standalone EXE and minimal runtime ZIP contain the same executable
bytes. The ZIP contains exactly `LICENSE`, `Offhand.exe` and `README.txt`.

Use the frozen files for any later submission/distribution. Recompiling, signing,
changing resources/version metadata or repackaging produces a different sample;
record and review that new hash separately. Do not transfer old Beta 18/Beta 20
Microsoft determinations or Revision 4 scan results to this candidate. The
version label alone does not distinguish these builds.

Output: `dist/defender-companion-20261107/`. Start with `README-FIRST.txt`.
Only files under `upload/` are intended as samples. The outer preparation ZIP
and `evidence/` are a handoff for the maintainer, not the runtime sample.

## Microsoft route, verified 2026-11-07

Use the [Microsoft Security Intelligence submission portal](https://www.microsoft.com/en-us/wdsi/filesubmission)
and select Software developer. It accepts specific samples up to 50 MB and asks
for English context in an additional-information field limited to 1900 characters.
The prepared EXE/ZIP text is checked against that limit. Prefer the standalone
EXE; use the minimal runtime ZIP for a separate archive-specific concern. Do not
submit an entire source tree or Discord add-on bundle as the Companion sample.

Select the product matching the observed issue: Defender Antivirus for an AV
detection, SmartScreen for a download-reputation warning. Preserve any real
threat name, engine/definition version and reproduction steps. No current
detection has been supplied, and local scans must be described as local results.
Do not invent a detection or misclassify this as an active false positive. If
the available account/form requires a real detection that does not exist, retain
the prepared bundle rather than fabricating the required field.

The [developer FAQ](https://learn.microsoft.com/en-us/defender-xdr/developer-faq)
does not offer a general known-list/false-positive prevention program and
distinguishes SmartScreen from antivirus detection. Submission is not signing,
Store certification, Blizzard approval or a promise to remove reputation warnings.

Sign-in is required according to the [submission guide](https://learn.microsoft.com/en-us/defender-xdr/submission-guide).
The maintainer supplies their account/contact identity and any required consent.
After any authorized upload, record the submission ID/URL, exact hash and dated
determination in `submission-record.json`; leave the verdict unset until received.

## Behavior disclosure for the reviewer

- Windows .NET Framework WinForms window-management companion for the Offhand
  WoW add-on. Requests asInvoker privileges, with no installer or driver.
- Locates known WoW processes and visible windows. Executable-path lookup uses
  framework metadata and a limited `PROCESS_QUERY_LIMITED_INFORMATION` fallback,
  not game-memory read/write requests.
- Enumerates Windows display geometry, active paths, scaling, colour modes and
  Remote Desktop session state. Shows optional monitor identifiers/area-selection
  overlays. Applies/restores ordinary window bounds, styles and clipping and
  notifies the Shell of fullscreen presentation.
- Optional configured auto-span/recovery runs while Companion is open. Tray,
  restore, pause and missing-display safeguards remain available.
- Stores preferences in `%LOCALAPPDATA%/Offhand/OffhandConfig.ini`. Writes
  addon-owned `Core/CompanionTopology.lua`. The Forever compatibility bridge
  reads Offhand account/character SavedVariables while WoW is closed and writes
  addon-owned `Core/ForeverState.lua`.
- Portable update checks fetch GitHub release metadata only on explicit user
  action; download navigation opens the browser. Header/help links and display
  troubleshooting open their documented website/Discord/CurseForge/Windows
  Settings targets. It does not download and execute a replacement binary.
- No game-memory inspection/modification, injected DLLs, remote threads,
  synthetic keyboard/mouse/chat commands or gameplay automation is added. The
  user types `/reload` themselves. No AV exclusions/protection changes, startup
  service/task or obfuscator/packer is part of the candidate workflow.

The native-boundary audit is a bounded textual check, not a complete security
audit or vendor certification. Keep the exact scope in the evidence receipt.

## Validation boundaries

Retain the published Revision 4 integration evidence, the subsequent messaging
preferences/dashboard checks and a fresh exact-candidate compatibility probe.
Run local Defender scans separately on the exact EXE and minimal ZIP and verify
that scanning did not change their hashes. Record definitions, engine, timestamp
and signature status. Validate every ZIP entry and the embedded EXE hash.

Full combined live WoW acceptance, affected reporter hardware, physical mixed
DPI/hotplug/three-monitor configurations, Wine and complete protected-action
coverage remain separate. Preparing or scanning a sample does not complete them.
