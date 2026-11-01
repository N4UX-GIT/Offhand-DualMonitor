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
