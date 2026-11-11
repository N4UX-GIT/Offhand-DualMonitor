# Revision 4 Retail native-window acceptance

2 November 2026, approximately 01:08-01:30 CET. Targeted span, ordinary restore,
two reset recoveries and native restore priority passed. Overall release
acceptance remains partial, with a server disconnect recorded separately.

## Exact subject

- Companion `2.1.3-beta.1`, file version `2.1.3.1`, revision 4, source build `44f1c166c645537bb9553dec70c267a889ed9b00`.
- Executable SHA-256 `E7F40392C7CD869729485BA56432102B7FCFB46FF45D0B2DD000F843CB685436`.
- Runtime ZIP SHA-256 `F22BFA4F65E144F5C625AFE018E794B5095BF70E196156E9F1CF89EC69339B96`.
- Retail `12.1.5.70688`, D: installation, Windowed mode. Installed Offhand `2.1.2-beta.24`, protocol 1; no addon deployment.
- Same approved selected level-one Hunter, idle in Coldridge Valley. No gameplay actions or Edit Mode layout creation.
- Mainhand `2560x1440` at `(0,0)`; portrait workspace `1440x2560` at `(-1440,-1114)`. Both SDR, 100% Windows scaling.
- Combined span `4000x2560`; ordinary drawable size `2114x1353`. Auto-span off, delay 30 seconds, VSync initially Enabled.
- Existing manual-canvas/profile preferences preserved. No reload or addon geometry diagnostics in this run, so it does not establish revision 4 addon layout or direct topology consumption.

## Results

Times are Companion local log times in CET.

| Case | Observation | Result |
| --- | --- | --- |
| Manual span | 01:13:31 outer/client/region `4000x2560`, origin `(-1440,-1114)`, style `140B0000`; stable arm 01:13:36 | Pass |
| New restore transaction, connected client | Restore 01:14:50 returned a bordered ordinary window, still restored beyond eleven seconds without forced respan | Pass |
| Fresh manual span | 01:17:42, followed by stable arm before graphics changes | Pass |
| VSync Enabled to Disabled, Apply | Visible reset; recovery restored bounds/style/clipping 01:21:31, re-arm 01:21:42 | Pass |
| VSync Disabled to Enabled, Apply | Second reset recovered 01:25:43 without manual span; re-arm 01:25:54 | Pass |
| Final native restore | 01:28:41 returned the bordered ordinary window. Client was already disconnected according to its earlier log timestamp | Pass for native restore only |
| Normal exits | Game shutdown logged 01:30:31; candidate exited through Exit Companion | Pass |

Readbacks came from the exact candidate and were corroborated by visible changes
and the client's graphics log. No independent continuous native observer ran.
No failure was injected into WoW. Failure rollback remains synthetic-only despite
the normal-path pass. Minimized/maximized restore, display loss/reconnect, Wine,
mixed DPI, Pause/Resume, startup auto-span and full addon persistence were not
tested here. Revision 3 results remain attached to revision 3.

## Disconnect and evidence limits

Retail showed `WOW51900319` when brought forward after final Restore. Logs were
preserved before normal shutdown and again after shutdown flushed buffered data.
`Connection.log` records Handle Disconnect at **01:27:17.664**, then Glue WoW
Disconnect at 01:27:17.677. The graphics log records the final resize to
`2114x1353` at **01:28:41.240**. The disconnect preceded that restore by about
84 seconds, so that call cannot be its trigger. This does not rule out other
candidate/addon, network or server causes. Continued connectivity is not accepted.

The graphics log also records the second reset to `2114x1353` at 01:25:39.382,
recovery to `4000x2560` at 01:25:43.107, and successful D3D12 device destruction
during normal exit. No renderer crash or visible Lua error dialog was observed.
A fresh taint/BugGrabber audit was not collected.

## Cleanup

Private before/after files, logs and cleanup checks remain ignored under
`dist/live-qa-rc4-retail-20261102`. They contain local account/device metadata and
require redaction before sharing. Both test processes are closed. Original
Companion INI, Retail Config.wtf, account SavedVariables, CompanionTopology.lua
and ForeverState.lua were restored exactly and hash-checked after shutdown.
VSync was returned to Enabled through the UI before the second recovery.
Battle.net remains open. Candidate bytes are unchanged. Nothing was installed,
submitted or published.

## Direct-geometry follow-up, 01:48-01:52 CET

Revision 4 and the same Retail build were launched through the authenticated
launcher, using the already selected idle level-one Hunter. Original settings,
account and character profiles, and generated bridges were backed up first.
Window Setup opened, but the client disconnected at 01:50:31.852 before
Companion geometry selection, span or reload acceptance. No new acceptance
result is claimed. Per the user's Starlink report, the network disconnect is
excluded from release blockers; this does not complete the missing test.

The test game exited normally (`GxShutdown` 01:51:02.733), then Companion exited.
All six backed-up files were restored exactly and hash-checked after process
exit. Battle.net remains open. Private evidence is ignored under
`dist/live-qa-rc4-retail-direct-20261102-014829`.
BugGrabber's before/after content differs only in its session counter, from 332
to 333; no new captured error record or existing-error counter changed. This
short idle attempt establishes no combat/taint acceptance.

## Successful native show-state restore, 02:12-02:18 CET

The same exact revision 4 executable and Retail `12.1.5.70688` were tested at
character selection. No character entered the world and no addon commands ran.
Auto-span stayed off; the two selected SDR displays retained 100% scaling.
Nine original files were backed up, including account/character profiles,
configuration, generated bridges and their existing `.bak` files.

A separate read-only observer used the candidate's public Win32 bindings to
record bounds, client size, style, visibility, `IsIconic`, `IsZoomed`, placement
and clipping-region type. Inputs used normal Companion and native title-bar
controls. The observer did not change the client window.

| Readback time | State and result |
| --- | --- |
| 02:12:39 | Original outer `(215,0) 2130x1392`, client `2114x1353`, style `14CF0000`, normal state, no region |
| 02:13:18 | Manual span: `(-1440,-1114) 4000x2560`, style `140B0000`, complex region; Companion armed at 02:13:22 |
| 02:14:23 | Ordinary Restore returned exact original outer/client/style, normal state and no region |
| 02:14:45 | Native title-bar Minimize established `IsIconic=true`, style `34CF0000` and minimized bounds `(-32000,-32000) 160x28` |
| 02:15:11 | Companion Restore returned exact original outer/client/style, show command 1, `IsIconic=false`, `IsZoomed=false`, no region |
| 02:15:45 | Native title-bar Maximize established `IsZoomed=true`, style `15CF0000`, bounds `(-8,-8) 2576x1408` |
| 02:16:16 | Companion Restore again returned exact original outer/client/style, show command 1, neither minimized nor maximized, no region |
| 02:16:48 | Same normal geometry remained stable beyond 30 seconds |

Both successful show-state restores pass for this Retail character-selection
context with a remembered original window. The minimized/maximized inputs were
ordinary bordered windows following the first span/restore. This does not test
minimizing a still-clipped span, Companion restart adoption, in-world addon
placement, reload, protected actions or failure rollback in WoW.

An attempted Alt+Space system-menu shortcut was intercepted by a global desktop
shortcut. It was abandoned; state changes used the visible native title bar.
No authentication, character selection changes, gameplay or graphics-option
changes were performed.

Normal game shutdown was logged at 02:17:42.773; Companion then exited normally.
All nine original files were restored exactly and hash-checked after both
processes exited. Battle.net remains open. Private evidence, native JSON
readbacks, activity text, original/after files and cleanup checks remain ignored
under `dist/live-qa-rc4-retail-showstate-20261102-021121`. No fresh in-world error
or taint acceptance is claimed. Candidate bytes and public artifacts are unchanged.
