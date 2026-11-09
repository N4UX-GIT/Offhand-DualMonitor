# Companion 2.1.4 release preparation, 2026-11-09

Status: candidate 1 superseded after owner-reported transition defects. The
corrected build 2.1.4.2 passed fresh package preflight and owner visual verification
in UI Preview 4. Candidate 2 is ready for release review, unpublished.
Candidate 1's hashes and passes below remain
historical evidence, not readiness for the corrected build. No GitHub or Store publication is
authorized by this record. The owner requested remaining UI checks and next
release preparation after reviewing local UI Preview 2.

## Candidate 1 scope and identity (superseded)

Product 2.1.4, assembly 2.1.4.0, exact production file build 2.1.4.1, proposed
Store package 2.1.400.0. Protocol 1 and supported topology schemas are unchanged.
The existing add-on remains compatible; its independent pending source changes
are not part of this Companion-only candidate. Frozen 2.1.3 and earlier
published artifacts remain untouched. Release copy is in
`Companion/RELEASE-NOTES-2.1.4.md`.

The dashboard changes are recorded in
`COMPANION-DASHBOARD-ACTIONS-20261109.md`. Added a native dark-scrollbar treatment
for the dashboard, log, Help and workspace dialogs. This retains Windows
scrolling, text selection, keyboard operation and accessibility. High contrast
resets the theme to the system default. Missing theme exports fall back without
blocking the interface.

The reviewed new import is exported `uxtheme.dll!SetWindowTheme`, called only
through private code taking managed Companion controls. There are no new game
inputs, process-memory operations, ordinal exports or hooks. Microsoft documents
[SetWindowTheme](https://learn.microsoft.com/en-us/windows/win32/api/uxtheme/nf-uxtheme-setwindowtheme).
The `DarkMode_Explorer` class is used by
[Microsoft PowerToys](https://github.com/microsoft/PowerToys/blob/main/src/modules/ZoomIt/ZoomIt/Utility.cpp),
but its availability across Windows/Wine versions is not a documented promise.
The local Windows 11 preview visibly showed dark dashboard and Activity Log
scrollbars, and wheel scrolling worked. Other OS versions and a physical
high-contrast transition have not been observed in this run.

## Reproduction and artifacts

Build production runtime and portable archive using
`scripts/New-CompanionUiCandidate.ps1 -OutputDirectory <fresh-directory>`.
This builds the ordinary runtime and records source hashes, source revision,
EXE/archive hashes and dirty-tree state. It refuses public artifact directories
and verifies canonical artifact hashes remain unchanged. The runtime archive
contains only Offhand.exe, README.txt and LICENSE.

Build the unsigned Store candidate from that exact EXE with
`Companion/Store/Build-StorePackage.ps1`, explicit package version 2.1.400.0,
CompanionPath and ExpectedCompanionSha256. Validate using
`tests/companion-store-package.ps1` with the same hash and version. Do not install
or replace the live Store app for structural validation.

The isolated review build is a separate `UI_PREVIEW` configuration, file
2.1.4.8001. It uses its own settings, auto-span/recovery disabled, and a separate
instance mutex. Do not ship this preview as the production candidate.

## Evidence and release gates

Current local logs are under ignored `dist/companion-ui-214-checks/`. Final
candidate hashes and the completed validation result must be recorded alongside
the staged artifacts. Historical 2.1.3 WACK, Defender and upgrade passes do not
automatically certify this new EXE. New Store submission/certification and public
publishing remain separate actions. No fresh live WoW acceptance is claimed for
this UI-only change.

## Completed preflight

Production runtime source commit `4738e8037b61f0951d027bf206713f647ef8edf8`.
Prepared output: `dist/companion-2.1.4-candidate-1/`.

| Artifact | SHA-256 |
| --- | --- |
| Offhand.exe | 2DC918A910FF587E850737CC162598286D8BD4511DB07EB629A1D65833B5CBAE |
| Offhand-Companion-v2.1.4-candidate.zip | 45529175A894BA20A28BB21028757C7D0337A8A1546771110BBAC119FEA8A6B0 |
| Store package 2.1.400.0 x64 | 082E4FA428E56EDF2D573C3B9914974BF255697416E6A7BF51EC9816D5EBDD13 |

- All 22 native/metadata regression runs passed, covering preferences/dashboard,
  identity, topology, all workspace modes/profiles, third-monitor/taskbar policies,
  native rollback, workspace UX, RDP, diagnostics, production/experimental
  recovery, interaction boundaries and frozen historical publication checks.
- All 109 current-tree Lua suites passed. Existing pending add-on changes were
  present during these tests and remain separate from this Companion candidate.
- Persistence: 25 portable and 47 installed-Store-identity checks passed.
- Unsigned MSIX boundaries, capabilities, identity and exact EXE parity passed.
- Local Defender scan found no threats in EXE/ZIP/MSIX output, exit 0,
  signatures `1.463.191.0`. This is a local scan, not a Microsoft file-review
  determination or a guarantee of application reputation on other machines.
- WACK overall PASS, PARTIAL_RUN FALSE, all 13 required tests passed. Ten optional
  tests passed; one existing optional blocked-executable finding was reviewed:
  existing URI Process.Start calls and `CsI` inside the unchanged 9,408-byte icon
  PNG (SHA-256 `5A07E4979187D0DEEC6F098EB8EBE1A0E47ABFA622C753F6CAE3882BEB3DEAC8`).
  The PNG exists byte-for-byte in both this EXE and the prior hotfix EXE; the
  current marker offset is 456014. It is not a new executable launch feature.
- The elevated WACK runner used `-noinstallappx`. Installed Store package
  2.1.301.0, its preferences and the candidate hash were unchanged afterward.
  This does not establish a production-PFN upgrade to 2.1.400.0.
- Native preview observed dark dashboard, Activity Log and Help scrollbars,
  functioning wheel scrolling, readable Help, fixed window bounds, and the
  corrected guidance. Final isolated UI Preview 3 is under
  `dist/dashboard-ui-preview-20261109-4-final/`, file build 2.1.4.8001.

Sanitized results: `docs/evidence/companion-214-ui-validation.json` and
`docs/evidence/companion-214-ui-wack.json`. Exact artifact/acceptance receipts
are alongside the candidate. Original prepared 2.1.3 build9/build10 and Beta20
artifacts were preserved.

Candidate 1 was superseded after that review. Store submission/certification,
public GitHub release/tag, and rollout are still separate actions. Windows 10,
Wine, physical mixed-DPI and high-contrast visual transitions were not observed
in this UI pass; native system-theme fallback is retained. No live game action
was added to or performed by these UI checks.

## Transition correction, build 2

The owner's subsequent review found a brief white scrollbar and apparent
resizing during Show/Hide. Endpoint-only bounds checks missed the scrollbar
gutter changing every card's width. The corrected dashboard reserves a constant
gutter using the documented
[GetSystemMetricsForDpi](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getsystemmetricsfordpi)
metric, with an older-platform fallback. The content stack no longer docks to
the changing client width. It keeps a constrained width, batches panel layout,
and buffers managed background painting.

Hidden log/scroll-control handles are created and themed during form Load,
before the first visible expansion. Handle recreation retains the existing
theme handler. This addresses late first-show native creation rather than
reapplying the dark theme after showing a control.

The layout fixture now observes intermediate SizeChanged/LocationChanged events,
content-width changes and late log HandleCreated events across every panel at
100%-200%. All three counters remain zero. These checks are stronger than only
comparing final bounds, but are not a claim about every subsecond rendered frame.
Ten native screenshot samples of expansion stayed 550x704 and were dark at
capture; the first arrived 671ms after starting the click, so this sampling
cannot rule out a shorter first-frame flash. Owner visual review remains needed.

New isolated preview: `dist/dashboard-ui-preview-20261109-5-transitions/Offhand.exe`,
UI Preview 4, file 2.1.4.8002. New ordinary runtime identity is 2.1.4.2. Prior
candidate 1 and all published artifacts are preserved. The new import is only
the UI metric query `user32.dll!GetSystemMetricsForDpi`; no input/process-memory
capability was added.

Corrected runtime commit: `eeea341`, file 2.1.4.2. Draft portable output is under
`dist/companion-2.1.4-candidate-2/`, with its own source/hash receipt. Seven
focused runs passed after this correction: preferences/dashboard, workspace UX
(both architectures), ordinary and diagnostics color checks, Remote Desktop,
interaction boundaries, and portable persistence. The stronger transition
checks pass at every tested scale. Candidate 2 has not inherited candidate 1's
WACK/Store-package verdict. Keep release on hold until the brief-flash review is
complete. Preview 4 is open for that review.

Fresh build-2 preflight subsequently passed all 22 regression runs, MSIX identity
and exact EXE parity, local Defender scan, and WACK overall PASS (13 required
passes; the same reviewed optional process-launch/icon finding). The runner
used noinstallappx and verified the installed 2.1.301.0 package, preferences and
candidate hash remained unchanged. New sanitized records are
`docs/evidence/companion-214-ui-build2-validation.json` and
`docs/evidence/companion-214-ui-build2-wack.json`. The candidate remains unpublished
with `briefFlashVisualReview=pending` at that stage of its acceptance receipt. Prior Lua and
installed-identity persistence evidence remains separately scoped; these native
UI corrections did not change add-on or persistence source.

Build-2 EXE SHA-256: `2D1FB0DE3A2BF6340D8EB4BF28D751C602C8DF66BD1947D0B43FB0A8DA709D5D`.
ZIP SHA-256: `D02DA1C5B31CD69875FAC4C04B8229259AE1AAF446B135B53ABC6A9F8752D53B`.
MSIX SHA-256: `EDE193AA3AF4ADC90264A950CB8B8BB282D24A1BD4E0C4F6A9CA452BE5AB14EA`.

## Owner transition verification complete

On 9 November, the owner answered the question specifically naming UI Preview 4
(file 2.1.4.8002): **"No flash or jitter"**. This closes the visual transition
gate left open above. The acceptance and transition-readiness records now mark
visual review PASS, with the exact preview version and owner response recorded.
The EXE, ZIP and MSIX hashes were rechecked and remain unchanged; no rebuild or
repeat test run was needed for this evidence-only update.

Candidate 2, production file 2.1.4.2 / proposed Store package 2.1.400.0, is ready
for release review. GitHub/Store publication, source promotion and rollout remain
separate actions. The owner's UI confirmation is not a new live WoW, different-OS,
mixed-DPI or production-PFN upgrade acceptance claim.
