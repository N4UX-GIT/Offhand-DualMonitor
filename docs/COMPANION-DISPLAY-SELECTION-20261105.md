# Two selected displays rejected by Companion

Acceptance update: the second reporter's 2026-11-06 native baseline returns
duplicate IDs even with the interface-name flag, with WoW and Companion absent.
The current custom-workspace candidate still reads child index zero and is not
an adequate span repair for that observed configuration. A connected but disabled
TV is newly reported; its role needs a controlled cable-disconnected comparison.
See the [second investigation](COMPANION-DISPLAY-SECOND-REPORT-20261106.md).

Second report update (2026-11-06): full dashboard screenshots and an addon log
now confirm Beta 20, addon Beta 26, Forever 1.60.1 build 70790 and two checked
2560x1440/1920x1080 displays. Fresh released-executable and candidate probes
pass, including the exact reported modal. A later INI excerpt confirms duplicate
saved identities for the second reporter, who describes a first installation
and direct DisplayPort connections to an NVIDIA GPU.
See [the second investigation](COMPANION-DISPLAY-SECOND-REPORT-20261106.md).

Integration update: the owner requested inclusion in the main custom-workspace
rework. The adapted correction and broader hardening are committed as `89a5751`
on `codex/custom-workspace-regions`, at
`C:/Users/NAUX/.codex/worktrees/classic-graphics-recovery/Offhand`. The next build
uses that source, rather than the isolated Beta 20 candidate below. It passes
154 identity/migration/profile assertions per architecture, all 92 Lua suites,
and the existing workspace/native rollback matrix. See its
`docs/COMPANION-DISPLAY-IDENTITY-HARDENING-20261105.md` for remaining native gates.
Exact reporter monitor details are supplementary and do not block this work.

Issue: OH-COMP-003. Report supplied on 2026-11-05 as a screenshot of a private
CurseForge message, subject "Offhand App issues". The reporter says exactly two
displays are selected but Span WoW Now asks for exactly two displays. The image
does not show the Companion version, its dashboard, the verbatim dialog, OS,
display layout, monitor identities or docking hardware. No private message was
opened or sent, and no account or configuration was modified for this inquiry.

Owner clarification: use addon Beta 26, Companion Beta 20 and the Forever
client as the working versions for this CurseForge report. These are owner-
directed assumptions rather than version strings visible in the screenshot.
The remaining unknowns are the actual display identities/layout and error log.

## Confirmed defect, conditional reporter match

`MonitorSelection.CreatePlan` resolves each saved identity through `FindDisplay`.
`FindDisplay` returns the first match. With duplicate saved/current identities,
both selected displays resolve to the same index; the selection deduplication
then counts one. The code throws its ordinary exactly-two-displays validation
message even when two separate display devices were selected.

This failure was reproduced with synthetic display objects against:

- Beta 20 source at `8418e35`.
- Current `Companion/Source/Program.cs` at the unchanged branch checkpoint.
- The actual frozen Beta 20 executable, by invoking its selection planner through
  reflection without starting the application, enumerating hardware or changing
  any native window. Executable SHA256:
  `81EECE9430885CEAC178A44A42429854524279072305F9F94EE62E7CCD620CCB`.

In all three cases, distinct identities produce a valid two-display plan. Two
distinct device names with a shared synthetic identity produce:

> Select exactly two displays, or enable Single-display 32:9 split for one super-ultrawide monitor.

This establishes a real planner defect. It does not establish that this
reporter's hardware returned duplicate identities. Matching monitor models or
dock usage alone do not prove an identity collision. The previous local live
test passed with a different physical display pair, so it does not refute this
report.

## Source and upstream findings

- `ReadStableDisplayId` calls `EnumDisplayDevices(deviceName, 0, ..., 0)` and
  treats `DeviceID`, or reserved `DeviceKey`, as a stable unique identifier.
- Microsoft's [EnumDisplayDevices documentation](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-enumdisplaydevicesw)
  documents `EDD_GET_DEVICE_INTERFACE_NAME` (1) as the flag for obtaining an
  operating-system-registered per-monitor interface name in `DeviceID`.
- The [DISPLAY_DEVICE documentation](https://learn.microsoft.com/en-us/windows/win32/api/wingdi/ns-wingdi-display_devicew)
  labels the ordinary `DeviceID` member unused and `DeviceKey` reserved. The
  existing zero-flag path is not a documented unique physical-identity contract.
- `ItemCheck` saving is already deferred with `BeginInvoke`, consistent with
  Microsoft's [check-state event timing](https://learn.microsoft.com/en-us/dotnet/api/system.windows.forms.checkedlistbox.itemcheck).
  A normal one-event-behind checkbox count was not established by source review.
- `CreatePlan` prefers saved identities over device names and ignores the latter
  when resolving the saved selected pair. Therefore two correct device names do
  not rescue a duplicated identity in the current implementation.

The shared WoW knowledge project was consulted first (`status` and `ask`), but
had no Windows selection-identity evidence. Microsoft documentation and the
actual Companion planner supply the relevant evidence here. No WoW API or
Forever-build-specific conclusion is required for this desktop pre-span failure.

## Repair scope and remaining evidence

This requires Companion work, not another Lua addon build. A separate Companion
candidate should obtain documented per-monitor interface identities, validate
uniqueness, and make planner resolution reject ambiguous identity matches
explicitly. Legacy identity migration must preserve both checked devices and the
chosen Mainhand, require review where physical identity cannot be established,
and keep missing-display and renumbering protections. Manual Span should consume
the current committed controls rather than trusting an older saved selection.
Do not silently map an ambiguous saved identity to an arbitrary display.

Required regressions include duplicate/case-variant/missing identities, existing
settings migration, two versus three checked devices, Mainhand ambiguity,
disconnect/reconnect and Windows display renumbering. Native acceptance needs an
affected display pair and confirms span/restore and role stability after restart.

Reporter follow-up: Companion version and Store/portable source; screenshot of
the full Companion dashboard, exact error and recent activity log; Windows
Extend versus Duplicate arrangement; monitor models and dock/adapter usage.
No settings deletion is needed for gathering this evidence.

The addon working tree's Companion source, frozen executable and existing
Discord test.2 archives were not changed. Reproduction fixtures/results are local under
`dist/companion-selection-investigation-20261105/`.

## Isolated source correction, owner working versions applied

A managed worktree was created from the Beta 20 source checkpoint `8418e35`:
`C:/Users/NAUX/.codex/worktrees/companion-display-selection/Offhand`.
This avoids pulling later resize/recovery experiments or the pending Forever
addon work into a desktop correction. No production executable was built.

Candidate changes:

- Request documented per-monitor interface IDs with
  `EDD_GET_DEVICE_INTERFACE_NAME`; remove the reserved DeviceKey fallback.
- Refuse ambiguous live identities, repeated saved identities and ambiguous
  Mainhand roles explicitly. Never deduplicate two physical displays into one.
- Use identity schema 2. Existing Beta 20/device selections require one-time
  review before automatic spanning resumes. Preserve the saved Mainhand device
  as the review selection rather than defaulting an existing role to primary.
  Leave a missing remembered role unselected for review.
- Save committed controls on manual Span, with topology-change and untouched
  missing-display guards before saving. Incomplete/invalid edits cannot retain
  a previously valid identity-schema marker.
- Ignore deferred checkbox saves from a superseded topology refresh, so an old
  callback cannot overwrite the refreshed selection.

Validation completed:

- 28 targeted planner/schema checks pass, covering duplicate/case-variant IDs,
  ambiguous roles, missing displays, device renumbering, reordered enumeration,
  explicit split mode, extra displays, and old/partial/future schema rejection.
- The existing `tests/companion-preferences.ps1` suite passes, including layout
  checks at 125%, 150% and 200%. User settings were protected and restored byte
  for byte around the existing form-construction tests.
- A native read-only enumeration probe returns two distinct per-monitor
  interface IDs for the two local displays. The old zero-flag IDs are also
  distinct locally, so the reporter's identity collision is not reproduced on
  this hardware. No app or native window was controlled by the probe.
- Released Beta 20 executable hash remains unchanged. No Store/GitHub/CurseForge
  artifact or message was published.

Still pending: native migration confirmation/cancel/restart, manual and automatic
span/restore, disconnect/reconnect, dock/affected-monitor/Wine coverage, and
reporter acceptance. This is a tested source candidate, not a released fix.

## Suggested reply, not sent

Thanks for reporting this. I found a display-identification issue in Companion
Beta 20 that can produce that message even with two displays selected. I have
prepared a correction for testing. Could you send a screenshot of the Companion
dashboard and exact error/activity log, and whether the monitors are the same
model or connected through a dock? Please also confirm Windows is using Extend
displays. This will help me check whether your setup is hitting the same issue.
