# Companion HDR/SDR and display-scale detection

Implemented 2026-10-28 on `codex/companion-hdr-detection`, based on
`companion/develop` at `bd04486`. This is a source candidate, not a published
Companion release. Public Beta 20 artifacts remain untouched.

## Test 3: compact, collapsible dashboard

Reporter feedback on Test 2 identified unused space on the right and requested
a more compact layout with collapsible panels. Test 3 replaces the fixed outer
card coordinates with a single-column table inside a scrolling viewport. Cards,
action rows and footer buttons use the available width. Status/diagnostic labels
are measured for their text and current font; the configuration uses measured
flow columns. The dashboard is resizable/maximizable and starts at its compact
preferred height rather than reserving the entire expanded-log height.

All four sections have keyboard-accessible Show/Hide buttons. Activity Log
starts collapsed. Choices are saved as `DashboardCollapsed.<section>` in the
existing Companion settings, which remain isolated beside diagnostics candidates.
Normal windows refit to the working area on a toggle while retaining their top
left position where possible; maximized windows retain their maximized state.
The main actions are outside collapsible sections, and Minimize/Updates/Exit
remain pinned below the scrolling content. No HDR/DPI, WoW window or bridge
behavior changes are intended.

Test 3 is `HDR / DPI DIAGNOSTICS TEST 3`, file version `2.1.2.2005`, built under
`D:/Tools/Code/Offhand/dist/companion-hdr-dpi-test3/`. Earlier candidates are
preserved. The ZIP remains a three-file portable runtime archive.

Validation: complete-dashboard regression covers 100/125/150/200% scaling,
three work areas including the negative-origin portrait display, resize widths
of 500/640/800 logical pixels, collapse/expand restoration, horizontal overflow,
header help containment and pinned-footer visibility. Full-dashboard offscreen
render reviewed. Diagnostics candidate checks pass 232 assertions per
architecture; ordinary preference/layout and all three recovery scopes pass.
Live Test 3 resizing, keyboard navigation and persisted collapse-state acceptance
remain pending. Public Beta 20 artifacts are unchanged.

## Test 2: dashboard overflow correction (historical)

Reporter feedback on 2026-10-28 confirmed that Test 1 displayed and copied the
two selected outputs as SDR at 100% Windows scale, with Mainhand reporting HDR
capability. The portrait Offhand had a negative desktop origin. This is evidence
of visible status and clipboard behavior on that setup, not mixed HDR/DPI
acceptance. The screenshot also exposed vertical and horizontal outer scrollbars.

Cause: diagnostics extended the dashboard below the original 824-pixel client
height, while the vertical scrollbar consumed the original right margin and
introduced horizontal overflow. Test 2 measures the complete scaled dashboard
at load, reserves a scrollbar gutter, fits its window to the active monitor's
work area, and keeps vertical scrolling as a fallback when height is limited.
The initial dashboard size is now 544x1048 logical pixels. No WoW geometry,
HDR detection, DPI detection or saved scale setting is changed by this correction.

Test 2 artifact: `D:/Tools/Code/Offhand/dist/companion-hdr-dpi-test2/`, ZIP
`Offhand-Companion-v2.1.2-beta.20-hdr-dpi.test2.zip`, file version `2.1.2.2004`.
The title identifies HDR / DPI DIAGNOSTICS TEST 2. Test 1 remains preserved.
The build script now produces Test 2; candidate settings remain local and
automatic spanning remains disabled.

Complete-dashboard regressions cover 100/125/150/200% scaling and simulated
2560x1400, 1920x1000 and negative-origin 1440x2520 working areas. They verify
work-area containment, horizontal fit with a vertical-scrollbar allowance, and
no vertical scrollbar when the full dashboard fits. The full 100% dashboard was
rendered offscreen and visually reviewed. Existing preference/layout checks and
228 candidate color/scale assertions per architecture pass. Test 2 ZIP structure,
metadata and embedded EXE hash were verified. Live Test 2 acceptance is pending;
the candidate was built but not launched against the reporter's running WoW.

## Test 1 (historical candidate)

Built 2026-10-28: `D:/Tools/Code/Offhand/dist/companion-hdr-dpi-test1/`.
Portable ZIP: `Offhand-Companion-v2.1.2-beta.20-hdr-dpi.test1.zip`.
The extracted `Offhand-HDR-DPI-Test1/Offhand.exe` has file version
`2.1.2.2003`, a distinct HDR / DPI DIAGNOSTICS TEST 1 title, and the unchanged
parseable Beta 20 protocol/writer identity. It has not been launched for live QA.

The `HDR_DPI_DIAGNOSTICS_TEST` build imports public display preferences as
defaults, saves changes only to `DiagnosticsTestConfig.ini` beside the test
executable, and disables auto-span in both dashboard and tray. The ordinary
single-instance guard is retained; exit the usual Companion before running it.
Manual Span/Restore and normal addon bridge behavior remain available. The build
cannot be combined with the graininess or graphics-recovery experiment defines.

Rebuild into a fresh directory with
`powershell -NoProfile -ExecutionPolicy Bypass -File Companion/Build-DiagnosticsTest.ps1 -OutputDirectory <absolute-new-directory>`.
The script verifies candidate metadata, the exact three-file runtime ZIP layout
and embedded executable hash. SHA-256 checksums and source/build metadata are
written beside the ZIP. `tests/companion-color.ps1 -DiagnosticsTest` passes 228
assertions per architecture, including the distinct title, settings isolation
and disabled automatic spanning. Ordinary Companion preference/layout checks
also pass after adding the candidate configuration. No public artifact changed.

## Behavior

- The Display Diagnostics card describes only the selected outputs, using their
  Mainhand/Offhand roles and existing Windows display numbers.
- HDR on + SDR (including wide color SDR) shows a mixed-output advisory.
  Two SDR outputs, two HDR outputs, or one physical display split into two
  workspaces do not. An unknown mode never silently becomes SDR.
- Display Troubleshooting provides Auto HDR / RTX HDR and Windows HDR comparison
  steps, a Windows Display Settings action, and a diagnostics-copy action.
- Windows scale percentages appear alongside color modes. Different percentages
  are informational, not a failure or proof of blurry output. Equal scales above
  100% are reported too. Scaling troubleshooting distinguishes Windows scale
  from WoW UI/render scale and physical pixel density.
- Changes are logged once per distinct observed status. The existing 2-second
  running-game / 5-second idle polling reads fresh state; selection changes,
  pre-span checks and diagnostics copying also refresh. Help dialogs retain the
  existing temporary polling pause. No additional timer or background task.
- Spanning remains available. No display, driver, game or HDR setting is changed
  by detection, including Windows scale and WoW UI/render scale. Opening Windows Settings and clipboard writes require button
  clicks. No game renderer access or network requests are added.

## Implementation

`Companion/Source/Program.cs`, `DisplayColor`, enumerates active paths using
`GetDisplayConfigBufferSizes` / `QueryDisplayConfig(QDC_ONLY_ACTIVE_PATHS)`.
Source GDI names map each path to `Screen.DeviceName`. Color queries address the
target's adapter LUID and target ID, rather than transient enumeration order.
Duplicate source names, such as cloned targets, stay unknown rather than taking
whichever target was enumerated last. Buffer-size churn gets at most three tries.

`DisplayConfigGetDeviceInfo(GET_ADVANCED_COLOR_INFO_2)` supplies the active SDR,
WCG or HDR mode. HDR capability is separate from active mode and the user's HDR
preference. On unsupported modern queries, the legacy advanced-color query is
used conservatively: disabled advanced color is SDR; enabled advanced color is
unknown because that older structure cannot reliably distinguish HDR from WCG.
Legacy support flags are not advertised as HDR capability. Failed queries and
missing APIs, including Wine gaps, produce unavailable state and diagnostic
detail. No OS-version guesses are used.

`DisplayScaling` reads `GetScaleFactorForMonitor` for each selected monitor.
`MonitorFromRect` locates the handle from the display bounds without a nearest or
primary fallback; `GetMonitorInfoW` verifies its device name before querying.
Only successful results become observed percentages. The Windows API can return
a default scale even on failure; that value is deliberately ignored. Missing
APIs, missing monitors and mismatched device names remain unavailable. No scale
is inferred from display resolution, and no process DPI-awareness override is
introduced. The public manifest already declares Per-Monitor V2 awareness.

Scaling shares the existing refresh, copy and change-only logging path with HDR.
It never triggers the amber HDR warning. The troubleshooting guide offers an
optional same-scale comparison for blur reports, with instructions to restore
the user's settings, rather than automatically changing scaling or claiming
that all mixed-DPI setups need a fix.

The existing WinForms dashboard retains its client size and scrolling behavior.
A dedicated diagnostics card follows the span controls; the activity log and footer
move down to make room. The help dialog reuses the existing scrollable guide.
The Companion currently uses English UI strings throughout; new copy follows
that existing convention. No addon locale files or generated bridge schema change.

Windows output state does not establish whether WoW is rendering HDR, whether
Auto HDR / RTX HDR is enabled, or what luminance reaches the physical panel.
This feature diagnoses a possible compatibility risk; it does not fix rendering.

API references:

- [Microsoft QueryDisplayConfig](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-querydisplayconfig)
- [Microsoft Windows SDK structure definitions](https://github.com/microsoft/win32metadata/blob/main/generation/WinSDK/RecompiledIdlHeaders/um/wingdi.h)
- [Microsoft Advanced Color behavior](https://learn.microsoft.com/en-us/windows/win32/direct3darticles/high-dynamic-range)
- [Microsoft GetScaleFactorForMonitor](https://learn.microsoft.com/en-us/windows/win32/api/shellscalingapi/nf-shellscalingapi-getscalefactorformonitor)

## Evidence and remaining QA

`tests/companion-color.ps1` compiles and runs in x64 and x86. Each run checks
native structure sizes/offsets, active-mode versus capability/preference,
all HDR/SDR/WCG/unknown combinations, single-display split, case-insensitive
source mapping, duplicate target ambiguity, missing outputs and 100/125/150/200%
card layout. Scaling cases cover differing and matching 100/125/150/175/200/225%
scales, single-display split, invalid/failed scale responses and device mismatch.
The test executable uses the application's DPI-awareness manifest and performs
real read-only Windows color and scale queries. On the development
desktop, both outputs were SDR at 100% scale, with one reporting HDR capability. Their state
was not changed. An optional `-PreviewPath <absolute PNG path>` renders the hidden
test card for visual review, with synthetic warning text.

Validation passed: 212 color/scale/interop/layout assertions in each architecture;
the existing Companion preference and 125/150/200% configuration-layout suite;
all three graphics-recovery scopes (Anniversary, Retail and Forever), each with
105 assertions; and `git diff --check`. The synthetic card render was visually
reviewed. Automated layout and read-only interop evidence do not establish mixed
HDR/SDR or mixed-scale hardware acceptance, live WoW behavior, or packaged portable/Store parity.

Before release, test the candidate on a real mixed-output pair: HDR on/off while
idle and while WoW runs; Mainhand role swaps; unselected HDR displays; two SDR
and two HDR outputs; one-screen split; disconnect/reconnect; copied diagnostics;
unchanged log deduplication; keyboard access, scrolling and troubleshooting at
100-200% DPI. Test scale changes during the session, mixed 100/150% displays,
equal 150% displays, swapped Mainhand roles and an unselected differently scaled
monitor. Confirm window spanning and graphics recovery retain their previous
behavior. Exercise missing APIs on Wine/older Windows, and minimum-size help
dialog buttons. Restore all user HDR and scaling settings after the comparison. A screenshot
alone does not establish physical HDR appearance.
