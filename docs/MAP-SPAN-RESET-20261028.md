# Retail map opening and span loss, 28 October 2026

Status: graphics-device recovery and resulting window-size change established;
the initiating map/rendering fault is not yet identified. No product behavior
change or Companion rebuild is proposed on this evidence alone.

## Observations

The developer initially described the game/UI area changing while the window
appeared to remain spanned. The screenshot shows the scene and HUD near the
upper-left, with desktop visible around and through the old display-mask shape.
The developer then confirmed no recovery button was required, and a later
re-span allowed the map to open normally. A continuously reproducible map-open
regression has therefore not been established.

The current Retail graphics log records these local times:

- 10:29:32.885: render target changes to 4000x2560.
- 10:30:04.405: CpuResolveQueries Map fails with DXGI_ERROR_DEVICE_REMOVED.
  The recorded removed reason is 0x887A0001, an invalid application call/state.
- 10:30:04.422: device context lost; GxRestart reason DeviceRecovery.
- 10:30:06.355: rendering returns to 2114x1353.
- 10:30:49.936: rendering returns to 4000x2560 after another span.
- 10:30:53.992: the same device-removed failure occurs a second time, followed
  by another DeviceRecovery restart.

This establishes the immediate failure mechanism. It does not identify the
offending rendering call or establish a driver, addon or map implementation as
the original cause. `CpuResolveQueries Map` names the graphics-buffer mapping
operation; the word Map in that log line is not evidence about WorldMapFrame.

## Native window evidence

A read-only observer at 10:35:31 reports the same running WoW process with:

- Window: left -1440, top -1114, width 2114, height 1353.
- Client area: 2100x1339; native style 336527360.
- Explicit clipping region: 4000x2560, three rectangles.
- Not hung or minimized.

The application window had actually shrunk while retaining the old clipping
region, explaining why this could appear to be a UI-only failure. The observed
window size also matches the saved GxWindowedResolution. This is consistent with
WoW restoring its saved window geometry during graphics-device recovery; the
precise native call sequence was not captured.

After the developer's successful re-span, the same observer at 10:43:17 reports
window and client both 4000x2560, the matching three-rectangle region, and no hang.
The observer never moved windows, changed focus, sent keys or wrote game settings.

## Source and installed candidate

The inspected map-opening code contains no UpdateWindow, RestartGx or graphics
resolution-setting call. The onboarding window-mode action can invoke those
APIs only through its explicit setup button. The new recovery module runs on
accepted recovery actions and does not run automatically when the map opens.
This review does not rule out an indirect addon-triggered rendering fault.

Installed Retail hashes match the reviewed Canvas, CanvasMapPresentation,
CanvasPanelLifecycle, CanvasPanelPlacement, CanvasPanelRegistry,
CanvasPersistence and Recovery modules. The generated Companion topology still
describes the expected 4000x2560 span. Init has a separate installed-only
layout-capacity recovery callback; it was preserved and is not on map opening.

Evidence preserved under `dist/map-reset-20261028/`:

- `retail-gx.log`: graphics log copied before another launch could replace it.
- `failed-window.jsonl`: the 10:35 native snapshot.
- `window-20261028-104317-206.jsonl`: the restored 10:43 snapshot.
- `module-hashes.json`: source versus installed fingerprints.

## Next controlled capture

The existing temporary OffhandDisplayProbe source now records native
WorldMapOnShow/OnHide/Minimized/Maximized callback events and UIParent,
WorldFrame and WorldMapFrame geometry while an opt-in capture is active. It
also includes miniWorldMap in its read-only CVar snapshot. It uses callback
registration rather than native-frame hooks or field writes. Stop, logout,
timeout and record-limit completion unregister those callbacks.

This helper update is prepared in source, not installed in the active client.
Its installer requires normal WoW exit. No client was closed or controlled for
this investigation. Probe simulation and Lua 5.1 syntax checks pass; native
callback execution and taint behavior remain unverified.

On a subsequent user-controlled reproduction:

1. After a normal client exit, install the updated temporary probe using
   `tools/display-capture/Install-Probe.ps1`.
2. Start from a healthy span. Start the native window observer and use
   `/ohcapture start` in WoW.
3. Open the map once without changing graphics settings or using recovery.
4. If it fails, stop the capture before re-spanning, preserve gx.log and the
   Companion activity log, and record whether map opening preceded device loss.
5. Exit normally when convenient so the probe's bounded SavedVariables flush.

If reproducible, compare the same client and scene with the previous candidate
and with Offhand disabled, preserving all original settings. Do not infer a
specific source fix from a device reset alone or apply graphics changes during
this capture.
