# Companion graininess investigation, 2026-10-22

## Test2 correction, 2026-10-23

Reporter comparison: the supplied wizard/single-screen diagnostics were identified
as coming from launcher #1. The reporter then ran launcher #2 and reports that
visual quality was significantly improved. Baseline and extra-resize modes both
remove borders and retain the display clipping region; only #2 adds the one-pixel
height nudge, 50 ms pause and return to exact bounds. This supports the resize
sequence as a practical mitigation and weakens border removal alone as the cause.
It does not prove correct DirectX buffer sizing or fully restored native sharpness.

Candidate logs and equivalent client-area evidence for the two runs have not yet
been received. In particular the #1 addon screenshots show single-screen recovery,
so native test completion and equal resulting dimensions need log confirmation.
Request #1/#2 logs from GraininessTest2, whether #2 is fully sharp or only improved,
and a repeat #1 then #2 in the same scene with unchanged addon/display state.
If #2 remains sharp, verify it with the addon enabled/reloaded and after a cold
launch. Defer further speculative fixes or broad test expansion until these
results are reconciled. Status: reporter improvement, live acceptance incomplete.

Test1 is superseded. The reporter was blocked before spanning: AddonInstallation
parses AssemblyInformationalVersion, and the experimental suffix was unsupported,
so CurrentCompanionVersion returned null and the normal beta.19 minimum check
rejected the candidate. The earlier expectation of only an addon UNKNOWN notice
was incomplete. No graininess evidence was obtained from this attempt.

Test2 retains the supported `2.1.2-beta.20` compatibility/writer identity, with
experimental file version `2.1.2.2002`, Test2 title and log identity. The strict
release parser and protocol/minimum checks are unchanged. Preferences/logs are
isolated under `GraininessTest2`. The four presentation modes are unchanged.

The added regression invokes AddonInstallation.Inspect using the candidate
assembly and a temporary fixture matching the reporter's topology-test1 manifest.
It reproduced the exact beta.19 rejection before correction and passes afterwards.
It also proves that protocol 2 and a beta.21 minimum remain rejected. Existing
Companion checks and the candidate native hidden-window checks passed again.

Replacement ZIP: `Offhand-Companion-v2.1.2-beta.20-graininess.test2.zip`.
All eight entries were byte-verified; the frozen canonical binary is unchanged.
ZIP SHA-256: `68BDB97287CF54A29AED17D95594F4C52F1F33BB3D42AEB7551F1F782FA836B4`.
EXE SHA-256: `C23C7AA26B534C7A41B738F9D2B7FE361E1F6F4EA2D953DA81D501F0DC810724`.
Use a fresh extracted folder, and keep the topology-test1 addon. Live testing
remains pending. The original test1 design and hashes below are historical.

Source branch: `companion/graininess-test`, based on `companion/develop`
`4ae9d3861b1bda5a1bbedbd5ef5d5748fdfe6eb3`. This is an isolated candidate,
not a change to the frozen public Beta 20 executable.

## Reporter evidence

Forever 1.60.1 build 70450, landscape Mainhand 2560x1440 and ASUS GlideX tablet
workspace 1080x1816, current span 3640x1824 with an eight-pixel tablet offset.
The topology-test1 addon resolves the span block. UI and world are reported grainy
on physical Mainhand while the tablet stays sharp; Restore Window restores sharpness.
Both Windows scales are 100%. USB and Wi-Fi give the same result. The defect
persists after a cold launch with Offhand disabled. Login is sharp but world entry
is grainy even when spanning before login. Manual ordinary bordered spanning was
reported sharp, but matching native client dimensions were not measured.
FancyZones was abandoned without a valid configured comparison.

## Code findings

The approved Beta 20 source removes WS_CAPTION and WS_THICKFRAME, installs a
union-of-displays window region, then calls SetWindowPos with SWP_FRAMECHANGED
and the target full desktop dimensions. It checks GetWindowRect only. The
experimental one-pixel height nudge in current Companion source is absent in
the approved Beta 20 binary and release tag.

Microsoft documents that frame changes require SetWindowPos and that
SWP_FRAMECHANGED sends WM_NCCALCSIZE. GetWindowRect measures the whole window;
GetClientRect measures its drawable area. Therefore an outer-bounds pass is
not evidence of correct drawable dimensions or a correctly resized DirectX buffer.
Border removal is a plausible trigger through client-size notification and
presentation behavior, not an inherent resolution reduction. Border thickness
alone does not establish the cause of whole-image graininess. Region clipping
normally affects visibility, not pixel density, but its interaction with this
client/virtual-display stack needs isolation.

References:

- https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-setwindowpos
- https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getclientrect
- https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-setwindowrgn
- https://learn.microsoft.com/en-us/windows/win32/api/dxgi/nf-dxgi-idxgiswapchain-resizebuffers

## Candidate design

`GRAININESS_TEST` guards every Program.cs change; normal compilation excludes
the diagnostic hooks and retains the existing production behavior. A separate
source module is explicitly included by the candidate builder. Four launchers
select a mode before initialization:

| Mode | Remove borders | Clip to displays | Additional resize |
| --- | --- | --- | --- |
| Baseline | Yes | Yes | No |
| Extra resize | Yes | Yes | One-pixel height nudge, 50 ms, exact return |
| No clipping | Yes | No | No |
| Keep borders | No | No | No |

All target the same client rectangle. Bordered mode uses AdjustWindowRectEx
to compensate the caption and frame in the outer coordinates. The initial
measured client rectangle must equal the plan, or the test restores the window
and reports an invalid comparison. Logs include outer/client bounds, style
and window DPI immediately and at two-second intervals for one minute.
Delayed sampling only reads geometry, has a generation guard, and stops on
restore, a superseding span, or disposal. It never manipulates renderer resources.

Candidate preferences and logs are isolated under
`%LOCALAPPDATA%\Offhand\GraininessTest1`. Existing desktop preferences are copied
only on first use. Auto-span is disabled. Store files, the canonical binary and
addon source are untouched. The usual generated topology/recovery behavior remains.
Public-version parsing can label the experimental writer suffix UNKNOWN in the
addon; this is documented and distinct from geometry readiness.

## Validation and artifact

- Existing Companion preference, topology, restore, scaled-layout and source-boundary checks passed.
- Candidate compilation and hidden synthetic-window tests passed for mode isolation,
  unknown-mode refusal, negative-origin outer/client conversion, equal native client
  origin/dimensions across all four modes, and the resize return.
- All 30 existing Lua suites in the Companion checkout passed; all six manifests
  passed paths/XML/Lua 5.1 validation. This checkout ships no addon in the candidate.
- All eight ZIP entries were verified byte-for-byte against staging. No test
  executables, preferences or personal state are included.
- Frozen executable SHA-256 remains
  `81EECE9430885CEAC178A44A42429854524279072305F9F94EE62E7CCD620CCB`.
- Artifact: `Offhand-Companion-v2.1.2-beta.20-graininess.test1.zip`.
- ZIP SHA-256: `A22FE893456B87BE362334E5F941CFA6D0637219DC5E863E1247A1AC493701A4`.
- EXE SHA-256: `C8A361E3F4FAA76492D61E7F91E211A10F7992CB65097F4D4BF2DFEE26843087`.

No WoW or GlideX runtime was operated. Synthetic native-window geometry success
does not establish sharpness, driver behavior, taint safety, cold-launch persistence,
or a renderer fix. Follow the packaged test procedure and record results per mode.
