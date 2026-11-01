# Companion revision 3: Retail live acceptance

1-2 November 2026, approximately 23:53-00:03 CET. Result: targeted native-window
span, repeated recovery and Restore pass. Broader release acceptance remains partial.

## Exact subject

- Companion `2.1.3-beta.1`, file version `2.1.3.1`, revision 3, built from `f7d33ae54a66dc3657f34be4b54cd4db10956e9c`.
- Executable SHA-256: `B24A4D5B5F1B7BE732BCEB9A19074BDAE91FED83636B3BEB8E9E1F2DD1205002`.
- ZIP SHA-256: `5E2A7D61B8ECD36B61D60A281F7700E251FDDC470B3E325EE25D505D9FB6F078`.
- Retail `D:/Games/World of Warcraft/_retail_/Wow.exe`, executable/launcher version `12.1.5.70688`. Full in-game GetBuildInfo tuple was not collected.
- Installed Offhand `2.1.2-beta.24`, protocol 1. No addon deployment.
- User explicitly approved Retail and its currently selected character. Existing level-one Hunter remained idle in Coldridge Valley. No gameplay actions were automated.
- Mainhand `2560x1440` at `(0,0)`; portrait workspace `1440x2560` at `(-1440,-1114)`. Both SDR, 100% Windows scaling.
- Combined span `4000x2560`. Initial actual bordered client resolution `2114x1353`; prelaunch saved config had `4000x2560`. VSync initially Enabled; auto-span off, delay 30 seconds.

## Observations

| Case | Companion local log / visible evidence | Result |
| --- | --- | --- |
| Manual span | 23:59:01 outer/client/region `4000x2560`, style `140B0000`, origin `(-1440,-1114)`; stable arm 23:59:04 | Pass |
| VSync Enabled to Disabled, Apply | Visible reset; recovery 23:59:50 restored bounds/style/clipping; re-arm 00:00:02 | Pass |
| VSync Disabled to Enabled, Apply | Second visible reset; recovery 00:00:54 without manual span; re-arm 00:01:06 | Pass |
| Restore Window | 00:01:52; ordinary bordered window remained after eleven seconds; graphics panel reported `2114x1353` and VSync Enabled | Pass |
| Normal shutdown | Game process closed 00:03:13, generated bridge refreshed 00:03:18; candidate exited through Exit Companion | Pass |

Native readbacks came from the actual Companion and were corroborated by visible
reset/recovery transitions. No independent continuous native observer ran. Settings
panels remained usable, but their position shifted following reset. The loaded UI
was not reloaded after spanning, so this is not acceptance of full addon layout.
The expected saved-layout mismatch notice appeared in the ordinary window and
was dismissed with Not Now before the initial span.

No visible Lua error dialog appeared in inspected steps. No fresh SavedVariables
error audit, combat/taint test, reload, disconnect, display reconnect, minimization,
multi-client test, startup auto-span, restart adoption or Pause/Resume sequence
was performed in this Retail run. Anniversary evidence for those exercised cases
remains separate. Settings tooltips remain the separate issue
`OH-UI-OPTIONS-TOOLTIP-SCALE`; this run makes no root-cause claim.

## Cleanup and evidence

Private raw UI logs and backups remain ignored under
`dist/live-qa-rc3-retail-20261101`. They contain local account/device information
and require redaction before sharing. Both test processes are closed. Exact
prelaunch Companion INI, Retail Config.wtf and generated topology bytes were
restored and hash-checked after shutdown. The normal generated ForeverState
shutdown refresh was retained. SavedVariables were preserved. Battle.net remains
open. No publication, Store change or installation occurred.

Shared knowledge status was consulted on 2 November: pinned sources remained
within review windows. The scoped evidence question returned no routed source;
the logs and observed target client above are the runtime evidence, without any
API, renderer or taint-safety inference.

## Follow-up: reload and geometry, 2 November 00:08-00:19 CET

The same candidate/client/addon pairing was relaunched through Battle.net on the
same selected idle character, with fresh prelaunch config/topology backups.
Manual span at 00:11:20 was followed by `/reload`; the loading screen completed
and the addon offered Mainhand HUD layout creation. Not Now was selected, so no
Edit Mode layout was generated or selected. The Companion logged stable recovery
arming at 00:11:23 and no automatic recovery/failure during the reload.

A further manual span at 00:16:12 armed at 00:16:17. The built-in
`/offhand diag full` command ran at 00:16:59. Its `lastGeometryCheck` snapshot was
read from the normal saved file after shutdown, without executing that file:

| Diagnostic | Recorded value |
| --- | --- |
| `viewportMatches` | `true` |
| Physical surface | `4000x2560` |
| WorldFrame | `(1440,0)`, `2560x1440`, scale `1` |
| Workspace | `(0,0)`, `1440x2560` |
| `topologyStatus` | `READY` |
| `manualCanvas` / source | `true` / `FANCYZONES` |
| `companionTopology` | `false` |

This passes the spanned reload smoke check and viewport match under the user's
existing manual-canvas profile. It does **not** establish direct generated
Companion topology acceptance. `READY` alone is insufficient to identify the
geometry source. A separate run should temporarily select Companion geometry
through the supported settings UI, preserve/restore the manual profile, and
require `companionTopology=true` before accepting that path. This run did not
alter the manual-canvas preference. It also does not validate a partial window
on a 5120-wide display.

Restore at 00:18:01 returned the bordered window and its expected mismatch
notice. The client and candidate exited normally; shutdown was logged 00:19:10.
Original Companion INI, Retail Config.wtf and generated topology were restored
and hash-checked. Normal SavedVariables and the generated shutdown bridge refresh
were retained. No graphics settings were changed. Private evidence is ignored at
`dist/live-qa-rc3-retail-reload-20261102`. No visible Lua dialog appeared, but no
fresh taint or error-log audit was performed.

## Follow-up: direct Companion geometry, 2 November 00:27-00:44 CET

The same candidate and installed addon were tested again on the same idle
character. The supported Window Setup UI was used to select Use Companion,
which selects automatic geometry without deleting the remembered manual canvas.
The original account SavedVariables, config, Companion preferences and both
generated bridge files were backed up before this temporary change.

The first session spanned at 00:32:17 and armed at 00:32:20. Submitting the
visibly prepared `/reload` command led to a Reconnect screen, rather than a
completed reload. The preceding UI showed increased latency. No disconnect code
or causal error was captured; network, server and addon causes remain unproven.
The client was restored and closed normally at 00:34:12. This attempt is
inconclusive, not a direct-mode reload pass.

One retry was launched through Battle.net. The Companion selection persisted
through that cold process launch. The preexisting generated bridge was loaded
before spanning; no second reload was needed for the following diagnostic.
Manual span at 00:40:45 armed at 00:40:50. At 00:41:55,
`/offhand diag full` captured:

| Diagnostic | Recorded value |
| --- | --- |
| `viewportMatches` | `true` |
| `companionTopology` / `topologyStatus` | `true` / `READY` |
| Writer / compatibility | `2.1.3-beta.1` / `MATCH` |
| Topology mode | `DUAL_DISPLAY` |
| Physical surface | `4000x2560` |
| WorldFrame | `(1440,6)`, `2560x1440`, scale `1` |
| Workspace | `(0,0)`, `1440x2560` |

The six-pixel game bottom is consistent with the actual offset display union:
its desktop bottom is 1446 while Mainhand ends at 1440. The previous manual
profile used bottom zero. The result confirms direct schema 1 consumption and
viewport placement for this pairing and geometry. It does not accept all panel
placement, protected HUD actions, direct-mode reload, graphics recovery while
using this source, or the partial-monitor feature.

Restore was logged at 00:43:17, normal game shutdown at 00:44:19. The candidate
also exited normally. All five backed-up files, including the full account
SavedVariables and original generated recovery bridge, were restored exactly and
hash-checked after both processes exited. Thus the temporary Companion selection
and diagnostic snapshot were not left in the user's active profile. Private
after-copies and native logs remain ignored at
`dist/live-qa-rc3-retail-topology-20261102`. No addon source or Edit Mode layout
creation was performed, no fresh error/taint audit was collected, and no visible
Lua error dialog appeared. Battle.net remains open.
