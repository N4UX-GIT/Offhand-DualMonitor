# Prototype 6 fullscreen taskbar presentation

3 November 2026. The user requested that custom spanning hide the taskbar where
possible, matching the expected fullscreen experience. Prototype 6 adds an
explicit Windows Shell fullscreen notification for the actual WoW window.

## Behavior and scope

After a verified successful span, Companion calls
`ITaskbarList2.MarkFullscreenWindow(hwnd, true)`. It does this after the native
transaction commits; failed span transactions do not acquire a new fullscreen
mark. After a successful Restore, Companion clears the mark. Failed Restore
transactions leave the prior presentation intact.

The Shell controls taskbar ordering. Companion does not change global auto-hide
preferences, hide Explorer windows, make WoW topmost or intercept input. Existing
manual, automatic and graphics-recovery span paths share the same notification.
The span and marking remain if Companion exits; a restarted Companion can clear
the marking through Restore. Windows owns the mark's lifetime when WoW's HWND is
destroyed. There is no background taskbar-hiding loop.

COM initialization or notification failure is nonfatal: native span/Restore still
works and the activity log reports the unavailable notification. Wine and other
shells retain this fallback; their runtime behavior remains unverified.

The earlier region offset is separate. The tested saved secondary area was local
`(9,1108) 1418x1440` on the `1440x2560` portrait display, leaving a 12-pixel bottom
margin. This change does not move, enlarge or snap that selection.

## Exact artifact

- Version `2.1.3-beta.1`, file/application manifest `2.1.3.2`, protocol 1.
- Build source `4a27ed0e9b5418d7830e84334a812c16838b71f7`.
- EXE SHA-256 `634EFED06267E746EF968B0849F2ABF1F4EA518B5B01E64111B54F242ABEA274`.
- Runtime ZIP SHA-256 `A03E7845A47458587DC981BD0669A0B317ED12F8F8FAB47508F8A805F2BA4939`.
- Local output: `dist/custom-workspace-regions-prototype-6/Offhand.exe` and
  `Offhand-Companion-v2.1.3-beta.1.zip` in that directory.
- The ZIP contains exactly Offhand.exe, README.txt and LICENSE. Embedded EXE parity
  was checked. Build-time `liveVerification=pending` is retained in candidate.json;
  subsequent acceptance is recorded here.

Prototype 5 and frozen public Beta 20 artifacts remain byte-identical. The prior
Prototype 5 review bundle remains a historical snapshot with its original source
and MSIX. No Prototype 6 Store package was installed or submitted, and nothing
was published.

## Validation

`tests/companion-taskbar-presentation.ps1` passed 25 assertions each on x64/x86
against the local Windows Shell: repeated mark/clear, absent and destroyed HWNDs,
unchanged native bounds/style/clipping, no focus stealing and no showing hidden
windows. This is a desktop integration test requiring Shell COM availability;
it is not a cross-shell simulation or a default headless-CI requirement.

The unchanged transaction suite passed 3,057 assertions per architecture.
Preferences/dashboard, partial topology and Lua consumer/persistence fixtures
passed. Production graphics-recovery policy passed 121 assertions. File and
manifest build identities were advanced together and checked.

A standalone visible desktop fixture used the production clipping builder and
notification helper. Taskbar sample points were behind the fixture while spanned
and returned to Shell taskbar windows after Restore. Its unmarked baseline also
hid the taskbars, so that fixture is not causal proof of the user's original WoW
symptom or a rendering-client acceptance pass.

The exact Prototype 6 then passed a native Retail `12.1.5.70688` check on the
confirmed WoW1 launcher account. It stayed at character selection throughout;
no character, realm or account was changed and no world entry or gameplay input
occurred. Installed addon files were unchanged, identified by Companion as Beta
24. No in-world addon, HUD, persistence, protected-action or taint acceptance is
inferred from this test.

| Observation | Result |
| --- | --- |
| Ordinary window before apply | Outer `(0,215) 2560x961`, style `14CF0000`, no clip; both taskbar sample points hit Shell taskbar windows |
| Custom apply through actual Span button | Outer `(-1431,-6) 3991x1446`, style `140B0000`, complex clip type 3; full game `(0,0) 2560x1440`, workspace `(-1431,-6) 1418x1440` |
| Taskbar coverage | Physical points `(-722,1416)` and `(1280,1415)` both hit the actual WoW root after apply, with WoW active and with Companion/Battle.net active |
| Companion exit | WoW retained exact custom bounds/style/clip and covered both sampled taskbar positions after Companion exited normally |
| Companion restart and Restore | Both points hit Shell taskbars again; ordinary style and no clip. With no surviving in-memory original snapshot, existing Restore behavior used the safe `(0,0) 1920x1080` fallback |
| Error store and cleanup | No world entry; BugGrabber session 352 and all 13 historical records unchanged. Both test apps and the desktop fixture closed normally. All 18 backed-up files restored and hash-verified; Battle.net left open |

Private evidence: `dist/live-qa-prototype6-taskbar-*`, native JSON point/bounds
readbacks and `dist/taskbar-desktop-probe/desktop-probe.log`. Profiles, account
paths and raw UI evidence are excluded from the runtime ZIP.

## Evidence routing and limits

Shared knowledge status and the relevant ask were consulted first; the broad
taskbar query returned unknown. Implementation follows Microsoft's
[fullscreen notification contract](https://learn.microsoft.com/en-us/windows/win32/api/shobjidl_core/nf-shobjidl_core-itaskbarlist2-markfullscreenwindow),
[required initialization](https://learn.microsoft.com/en-us/windows/win32/api/shobjidl_core/nf-shobjidl_core-itaskbarlist-hrinit)
and [SDK interface declaration](https://github.com/microsoft/win32metadata/blob/main/generation/WinSDK/RecompiledIdlHeaders/um/ShObjIdl_core.h).
Source declarations, native fixtures and actual Retail observations remain
distinct. Successful notification alone is not a visibility guarantee on every
Windows/shell configuration.

Confirmation in the user's original in-world scene, other clients, Explorer
restart, auto-hide variants, mixed DPI and physical hotplug remain unverified.
Earlier Prototype 5 acceptance stays attached to its original bytes. The wider
custom-region release gates and separate oversized-tooltip issue remain open.
