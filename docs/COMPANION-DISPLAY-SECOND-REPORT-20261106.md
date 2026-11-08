# Second report: two checked displays rejected by Companion Beta 20

Issue: OH-COMP-003. Evidence supplied on 2026-11-06: four screenshots
(`9062.jpg` through `9065.jpg`) and `Glarth log offhand.txt`. This is the second
reported instance of the exactly-two-displays error. No support message was sent.

## Conclusion

**Reporter-confirmed native workaround:** the owner now relays that, with the TV
unplugged, monitor selection and spanning both succeed. This closes the native
span acceptance gap for the temporary TV-disconnected/reselection path on this
reporter's existing setup. It is reporter-observed runtime evidence, not an
agent-controlled test. No new binary hash, successful calibration completion,
reload/cold-launch persistence, Restore Window result or reconnect result was
supplied with this confirmation. Do not infer those passes.

The failure is reproducible as a connection-dependent identity collision with a
physically connected but disabled TV; removing it produces distinct monitor IDs
and permits span. The exact low-level child/path association remains unobserved.
This establishes the current hardware/topology trigger, not when it first arose
or that Forever release introduced it. The permanent correction must work with
the disabled TV still connected and preserve Mainhand/workspace roles.

**TV-disconnected comparison received:** at
`2026-11-06T01:05:38.1970494Z`, label `2-tv-disconnected`, the same
DISPLAY13/14 screen names now return **two distinct legacy IDs and two distinct
interface IDs**, with no WoW/Companion detected. Primary DISPLAY13 maps to
HWV62F5 (UID4357 interface), secondary DISPLAY14 to BNQ7F2B (UID4355 interface).
The connected-TV baseline mapped both to SNYA401 (UID4352 interface).
Disconnecting only the disabled TV removes the observed collision in this
comparison. This supports incorrect association with an inactive output in the
index-zero read path. Exact child attribution and reconnect repeatability remain
unmeasured; no driver or Forever defect is established.

Temporary recovery to test: TV physically disconnected, Beta 20 reopened, both
monitor boxes explicitly reselected and Mainhand chosen correctly, then manual
Span with WoW Windowed and one reload. Reselection matters because the saved
SNYA401 identities become unavailable after unplugging. Pure-planner execution
with the reported disconnected IDs accepts the reselected pair and Mainhand,
while old TV identities refuse as disconnected (15 released-executable checks
total). The reporter subsequently confirms native selection/span success; Restore
Window and the other lifecycle checks remain unverified.
Keep the TV unplugged during recovery; reconnecting may restore the bad mapping.
Any reconnect comparison should happen with WoW and Companion closed.

**Latest acceptance finding:** the reporter's v2 native baseline at
`2026-11-06T01:00:05.0625066Z`, label `1-wow-closed`, finds the same identity
for both active screen names using **both** legacy and interface queries.
No supported WoW or Companion process is detected. The interface-flag-only
enumeration correction in candidate `89a5751` is therefore insufficient for
this observed configuration. Its ambiguity guard should refuse the selection;
do not describe it as a verified repair for this reporter or distribute it on
that premise. See the baseline findings below before earlier candidate evidence.

The screenshots confirm that the Companion displays two checked monitors while
rejecting the span. This matches the existing confirmed Beta 20 planner defect:
two selected devices sharing an identity resolve to the first matching monitor,
then deduplicate to one. It is a Companion selection/planning failure before
topology writing and native resizing. The addon wizard cannot progress until
placement succeeds.

The subsequent INI excerpt confirms the duplicate saved identities for this
reporter. `MonitorDevices` contains two distinct devices, DISPLAY2 and DISPLAY1,
but both `MonitorIdentities` entries contain the identical SNYA401 legacy ID
ending in `0001`. `MainhandIdentity` repeats that same ID; identity schema is 1,
legacy indices are `0,1` and split mode is false. Fresh execution with the
supplied identity values reproduces the exact dialog in the released executable.
The preference values establish the collision in the saved selection. The later
native baseline also confirms colliding interface-query results on his hardware.

A stale one-monitor saved selection was an alternative before the INI arrived.
It is no longer necessary to explain this case. Beta 20's identity-first resolver
ignores the two distinct selected device names once saved identity values exist.
The candidate already addresses identity ambiguity and committed-control capture.

## Reporter follow-up received 2026-11-06

### Native baseline and newly reported disabled TV

Subsequent supplied display-layout screenshot (clipboard image
`codex-clipboard-ae76672d-c0e1-4f7c-becb-a68edce0c344.png`) shows a header
`Displays (2/3)` and two adjacent display rectangles: larger display 2 on the
left, marked with an asterisk, and smaller display 1 on the right, approximately
vertically centered. This is consistent with two enabled displays among three
detected and with the reported primary 2560x1440 plus 1920x1080 pair. The image
does not provide exact pixel coordinates, numeric resolutions or an explicit
Windows Extend/Duplicate control. Treat primary marking and enabled count as
layout-UI observations; do not derive exact native rectangles from screenshot
pixels or equate its labels with the diagnostic's DISPLAY13/14 names. A mixed-
height/offset extended arrangement is a supported geometry and does not explain
the duplicate identity values. The later cable comparison establishes a
connection-dependent difference in the identity results.

The owner supplied the v2 JSON report, not merely an addon log. It contains two
Screen.AllScreens entries (`DISPLAY13`, primary, and `DISPLAY14`), two successful
legacy reads and two successful interface reads. Each method has two present IDs
but only one distinct ID, with both devices in its duplicate group. Both legacy
IDs are the same SNYA401 value from the INI; both interface paths are identical
and end with the same UID4352 monitor instance. JSON `\u0026` is the normal
serialization of ampersands, not corrupted identity data. Do not infer physical
display roles from the changed DISPLAY numbers.

`WowProcesses` and `CompanionProcesses` are empty. This establishes that the
collision is observable before another WoW launch/setup action. It does not
reconstruct when the system first entered this state or prove that a past
graphics transition never contributed. The owner also relays a **connected but
disabled TV**. That is a new relevant topology dimension, not proof of cause.
The original connection description omitted that additional device.

Both the diagnostic and current candidate query only monitor child index zero
for each GDI display name. The candidate changes the interface flag, not this
first-entry selection. A wrong/repeated child association, possibly involving
the connected disabled output, is a hypothesis requiring additional evidence.
Do not conclude that two active physical monitors genuinely have the same unique
hardware identity, that NVIDIA is faulty, or that SNYA401 must be the TV from
these results alone.

Immediate controlled comparison: retain the supplied connected-TV baseline;
with WoW and Companion closed, physically disconnect only the TV cable, wait
for Windows to settle, and rerun the same v2 Capture.cmd with label
`2-tv-disconnected`. Leave the two active monitor connections and the INI alone.
Return the JSON privately; reconnect the TV afterward. This changes hardware
topology intentionally and may renumber DISPLAY devices. Compare identity
sets/duplicate groups rather than assuming stable DISPLAY numbers.

The returned disconnected capture shows distinct IDs by both methods, associating
the TV connection with this failure state. A reconnect capture can confirm
repeatability. Monitor children/state flags and active source-to-target paths
are still needed for exact call-by-call attribution. Addon-disabled/window-mode
reproduction is deprioritized because both states were captured without a game
process detected.

The engineering follow-up is to resolve the active physical output for each GDI
source using active Windows display paths, with explicit clone/ambiguity/missing
handling and verified legacy migration. Enumerating all monitor children and
their state flags is useful diagnostic evidence; blindly selecting another index
is not a repair. Microsoft's
[QueryDisplayConfig contract](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-querydisplayconfig)
provides active source/target paths, and
[target-device information](https://learn.microsoft.com/en-us/windows/win32/api/wingdi/ns-wingdi-displayconfig_target_device_name)
provides the corresponding monitor path. Read-only QueryDisplayConfig is already
used for colour diagnostics in the custom-workspace source, but **not** by its
identity reader. No new runtime repair or native acceptance is claimed here.

### Earlier INI and installation follow-up

- This is his **first installation**. There is no prior successful Forever beta
  session on this same setup in the supplied history.
- Microsoft Store Companion failed first. Portable Companion tried afterward
  showed the same symptom. This is consistent with the shared Beta 20 selection
  logic; it does not establish whether their configuration files were shared.
- Both monitors connect directly to an NVIDIA GPU using DisplayPort. No dock,
  USB display adapter or KVM is reported in this connection path. The collision
  is not evidence of an NVIDIA-specific driver defect.
- The initial INI reply mentioned an attached screenshot, but no additional image
  was present. The later native JSON supplies the WoW-closed result; Windows
  Extend versus Duplicate settings still have not been directly supplied.
- The pasted text contains extra escaping/trailing backslashes. The reproduction
  preserves the repeated identity text but treats presentation escapes as chat
  formatting, not proof of malformed bytes in the original INI. No user file was
  edited, and no complete raw INI was imported.

## Observed reporter evidence

- Companion dashboard: **v2.1.2 Beta 20**, WoW running, Offhand installed and
  verified as **beta.26**, protocol 1. These versions are visible here rather
  than assumed from the first report.
- Two checked displays: **2560x1440 primary** and **1920x1080**. Mainhand is
  Display 1, 2560x1440. Single-display split is unchecked; auto-span is unchecked.
- The modal, display-plan status and repeated activity-log entries all say:
  "Select exactly two displays, or enable Single-display 32:9 split for one
  super-ultrawide monitor."
- Identify Displays shows both monitors. This establishes enumeration and labels,
  not uniqueness of their persisted identities.
- Wizard remains at placement before calibration, asking for a successful span
  followed by Reload UI. This is consistent with the failed Companion action.
- Addon log: **Forever 1.60.1, build 70790, interface 16001**, Offhand
  **2.1.2-beta.26**, paired Companion **2.1.2-beta.20**, minimum Beta 19,
  protocol 1. This is not evidence of an incompatible version pair.
- Addon state: `Enabled=0`, `Spanned=0`, `Source=Recovery`, `Setup=1`;
  Mainhand `(0,0 2380x1253)`, workspace `(0,0 0x0)`.
- Topology: `MISMATCH`, loaded schema 1, expected `2560x1440`, live
  `2380x1253`, writer not recorded, status unavailable. A previous or incomplete
  snapshot is present, but neither its contents nor provenance are supplied.
  Do not infer that the failed Span wrote it: planning throws before bridge writing.
- Persistence reports ordinary SavedVariables, bridge absent, session standard.
  The log does not implicate the Forever SavedVariables fallback in the desktop
  selection error. Missing HUD geometry and wizard blockage are expected while
  the game is unspanned; no separate addon repair is established by this report.

The later layout screenshot establishes the relative side-by-side arrangement
and approximate vertical centering, but exact desktop coordinates, scaling,
monitor models and an explicit Windows Extend versus Duplicate control remain
unrecorded. Interface-query IDs are now supplied and collide. Mixed resolutions
and the visible vertical offset are supported inputs, not an error by themselves.

## Fresh reproduction and candidate check

### Why reports started with the Forever release client remains unresolved

The owner subsequently reports **20,000+ downloads before the Forever release
client**. This is substantial prior product exposure and makes a newly
encountered hardware combination insufficient as the sole asserted explanation
for the reporting history. It is an owner-supplied download count, not a measured
count of unique Beta 20 Companion installations or monitor configurations.
The absence of previous reports and the release correlation remain evidence
to investigate; neither establishes a particular trigger by itself.

Distribution review: the checked-in frozen executable's hash matches the
original Beta 20 artifact record at `f9daa00` (2026-10-08), including the staged
Store executable. This confirms continuity of the repository's canonical bytes,
not the exact bytes currently installed on either reporter's machine.

An additional addon interaction must remain open: Beta 26 release source at
`293f566` adds `Onboarding:SetWindowedMode` compared with Beta 20 source at
`8418e35`. The player-triggered action sets supported `gxWindow=1` /
`gxMaximize=0` and calls `UpdateWindow` or `RestartGx`. The addon does not supply
or write Companion monitor identities, but can request a window/graphics state
change. No evidence currently establishes that this action changes Windows
monitor IDs. Lack of a direct data path does not prove absence of an indirect
interaction. Do not promote this source difference into a diagnosed trigger.

Targeted native comparison, with preferences preserved: capture current old-
method and interface IDs and the Companion plan before launching WoW, with the
addon disabled, and before/after the window-mode action. Check reporter executable
hashes separately. This distinguishes an already-present identity collision
from a state-dependent transition. No such native experiment was performed here.

The owner reports that Companion Beta 20 worked during Forever beta and on
other clients; this symptom has only been reported since the Forever release
client. The first-installation follow-up means this reporter provides no
same-machine beta-versus-release regression. The INI now establishes the saved
identity collision as his selection failure mechanism. It does not explain
why the first reports appeared at release, or establish the first reporter's IDs.

History review on 2026-11-06 traces identity-first selection to `a92fa85`
(2026-09-23), before the Beta 20 preparation checkpoint `8418e35`
(2026-10-08). The offending first-match/deduplication behavior already existed
in Beta 20. `CreatePlan` takes display objects and saved preferences, with no
WoW client/build input or Forever-specific branch. The released executable
reproduces the error without launching any WoW client. Conversely, that does
not exclude a new client's window/display-mode behavior affecting the inputs
Windows supplies, or different installation/preferences/setup history.

With the same executable, preferences and enumerated display inputs, the
planner should behave identically across clients. If one affected machine
worked in beta and fails in release, the investigation must identify which
input or preceding step differs. No such comparison is supplied here.

Saved selected IDs/devices and current first-entry interface-query IDs are now
supplied and contain the collision. Corrected active-output enumeration and native
candidate acceptance remain missing. A same-machine
beta-versus-release comparison would be useful if a reporter actually had a
previously successful beta setup; it is not a prerequisite to correcting this
first-installation case. A passing candidate confirms recovery, but does not
by itself explain when the first reports appeared.

The separate first-launch onboarding defect documented in
`FOREVER-ONBOARDING-INVESTIGATION-20261105.md` entered addon logic later and
must not be used as evidence for this Companion dialog's cause.

On 2026-11-06, a reflection harness invoked only `MonitorSelection.CreatePlan`
in the actual frozen released executable. It did not start the application,
enumerate physical hardware, access preferences or change any native window.
Released executable SHA256:
`81EECE9430885CEAC178A44A42429854524279072305F9F94EE62E7CCD620CCB`.

Synthetic inputs use the reported resolutions and primary/Mainhand choice. Both
left and right workspace arrangements were checked with top-aligned displays;
these coordinates are test parameters, not observed reporter geometry.

- Released Beta 20: **15 assertions pass** after the TV-disconnected follow-up
  (10 initially, then 12 after the INI).
  Two new assertions use the supplied repeated identity values and distinct
  device selection to reproduce the exact reported error. Unique identities retain both
  monitors and their rectangles; shared identities reproduce the exact modal.
  An explicitly stale one-ID selection also reproduces that modal. Three new
  checks use the native disconnected IDs: old TV selections refuse, a newly
  saved distinct pair plans successfully, and Mainhand is preserved. Fixture
  pixel rectangles are illustrative, not measured native desktop coordinates.
- Custom-workspace candidate at clean commit **89a5751**: **12 assertions pass**.
  Unique interface identities work even when legacy IDs collide. Ambiguous
  current IDs receive an explicit diagnostic and refuse the plan.
- Existing candidate `tests/companion-display-selection.ps1`: **154 assertions
  pass on x64 and 154 on x86**, including migration, ambiguity, reconnect,
  roles and profile preservation. This suite includes editor construction with
  synthetic topology; it is not affected-hardware span/restore acceptance.

Reproducible local harness and outputs:
`dist/companion-selection-investigation-20261106/run.ps1`,
`ReporterSelectionProbe.cs`, `released-beta20-results.txt`,
`candidate-results.txt`, and `candidate-regression-results.txt`.
The candidate was compiled as an isolated test library in that directory.
No production executable, archive or source code was replaced.

## Existing correction and next acceptance step

### Ready diagnostic package

Use **`dist/Offhand-Monitor-ID-Diagnostic-20261106-v2.zip`**, probe version
`2026-11-06.2`, SHA256
`8F788934790C994E9A5DECD93887260482613556F7C98419918018836E4E56A8`.
The original unversioned ZIP is superseded: its no-argument launcher fails while
evaluating `Join-Path $PSScriptRoot` in a parameter default under Windows
PowerShell. The original smoke check supplied `-OutputDirectory`, masking the
fault. No diagnostic capture was produced by that failed launcher invocation.
Version 2 resolves the default after parameter binding and preserves the
PowerShell exit status through the CMD launcher's final pause.
Source is `tools/display-identity/`. The four-file archive contains the launcher,
PowerShell capture, reviewed native enumeration source and instructions. It
contains no Companion executable, addon, original INI, captured IDs or fix.

The first reporter task is one labelled capture with WoW and Companion fully
closed. It reads both legacy and per-monitor interface IDs. If legacy IDs already
collide in that state, compare whether interface IDs distinguish the monitors and
proceed to the corrected candidate rather than requiring the full wizard matrix.
This establishes current pre-launch state, not historical cause. If the baseline
does not collide, the supplied instructions stage addon-disabled and before/after
window-mode captures to identify a transition. A separate capture with existing
Companion running attempts version/hash verification without recording its path.
No result should be labelled a graphics-reset trigger without an observed change.

Validation: executed the real Windows queries locally using Windows PowerShell
5.1, finding two connected displays with two distinct IDs by both methods.
Verified case-insensitive duplicate detection and missing-ID reporting with
synthetic records, unchanged local INI bytes during a second native capture,
and exact source-byte parity for all four ZIP entries. No game/app was launched,
closed or controlled, and no native settings were changed. These are local
enumeration and package checks, not reporter or WoW-transition acceptance.
Local receipts are under `dist/display-identity-diagnostic-20261106/`.

After the owner supplied the launcher error screenshot, reproduced the exact
failure from the original ZIP. Verified v2 by running extracted `Capture.cmd`
with no arguments from a directory containing spaces, supplying only console
input for the label/pause. It creates valid version-.2 JSON in the default
`captures` directory. Direct `-File` default-output and explicit custom-output
runs also pass, extracted bytes match source and local Companion settings remain
unchanged. Receipt: `verification-v2.json`; original and corrected launcher logs
are retained locally. No WoW action was performed during these checks.

The earlier partial correction is integrated in `codex/custom-workspace-regions` at
`C:/Users/NAUX/.codex/worktrees/classic-graphics-recovery/Offhand`, commit
`89a5751`. See its `docs/COMPANION-DISPLAY-IDENTITY-HARDENING-20261105.md` and
the [first investigation](COMPANION-DISPLAY-SELECTION-20261105.md).

It requests documented per-monitor interface IDs, checks ambiguity explicitly,
requires review for old identity settings, preserves Mainhand roles, captures
committed manual controls and blocks stale deferred saves. No additional runtime
patch was justified by the INI alone. The later native baseline demonstrates that
active-output identity resolution still needs correction. The public Beta 20 executable and
existing addon-only test archives do not acquire this correction automatically.

Next validation is the exact Companion candidate artifact: review/migrate saved
selections, manual span, correct physical Mainhand/workspace, Restore Window,
restart, missing-monitor/reconnect and affected setup acceptance. After a
successful span while logged in, reload once and confirm usable exact topology,
`Spanned=1` and a nonzero workspace before continuing the wizard.

The reporter has now supplied the display-selection keys requested from
`%LOCALAPPDATA%\Offhand\OffhandConfig.ini`: `DisplayIdentityVersion`,
`MonitorIdentities`, `MonitorDevices`, `Monitors`, `MainhandIdentity`,
`MainhandDevice`, `SingleDisplaySplit`. They confirm the duplicate saved IDs.
Remaining evidence is reconnect repeatability, active output mapping and
the corrected candidate's native result. Redact unrelated settings and review monitor
identifiers before sharing publicly.
Do not delete settings, reset the addon or enable single-display split for this
two-monitor setup.

## Knowledge and upstream evidence

### INI-only identity overwrite is not a supported workaround

Source review of Beta 20 on 2026-11-06: replacing the saved ID strings with
invented unique strings or DISPLAY device names will not change what Windows
enumeration returns. `FindDisplay` matches saved identities only against current
`StableId` values; a substituted ID therefore raises the disconnected-display
error. Blank identity values select no displays. Deleting identity keys makes
`HasStableIdentitySettings` false; manual Span enters
`ConfirmStableDisplayIdentity` and saves the same enumerated identities again.
Checkbox/role changes can also rewrite identity settings from enumeration.

The lower-level planner has a device-name fallback when the identity argument is
null, but the application requires identity settings before normal Span. The INI
reader stores every value as a string, so a blank value cannot supply that null
argument while retaining the required identity keys. No reliable configuration-
only switch to device-name mode exists in the reviewed Beta 20 flow. This is
source evidence, not a native edited-configuration acceptance test. Leave the
reporter's original settings intact and use the corrected Companion candidate
for automated two-monitor spanning. Manual window spanning remains a separate
setup method; no Windows monitor registry/EDID changes are proposed.

The required shared knowledge `status`, `search` and `ask` were run first.
Search reported a stale index; `ask --client forever --build 70790` returned
unknown with no Windows identity evidence. This was not treated as absence of
an API or a runtime guarantee. The Windows-specific gap and source-backed finding
are recorded in the shared project's
`knowledge/offhand-companion-display-selection-20261106.md`.

Microsoft's [EnumDisplayDevicesW contract](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-enumdisplaydevicesw)
specifies `EDD_GET_DEVICE_INTERFACE_NAME` for the OS-registered per-monitor
interface name. Its [DISPLAY_DEVICEW contract](https://learn.microsoft.com/en-us/windows/win32/api/wingdi/ns-wingdi-display_devicew)
marks the ordinary `DeviceID` unused and `DeviceKey` reserved. Rechecked on
2026-11-06. The zero-flag ID/reserved-key path is not a documented unique monitor
identity contract. Native observations on this reporter's setup remain pending.

## Suggested support reply, not sent

Thanks, that confirms the temporary workaround and gives us a reproducible
condition for the Companion fault. Please leave the TV unplugged for now, reload
WoW once after spanning, and continue calibration. The permanent correction
needs to identify the active monitors correctly while the disabled TV is still
connected. No addon settings reset is needed.
