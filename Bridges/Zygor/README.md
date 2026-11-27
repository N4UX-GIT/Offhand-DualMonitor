# Built-in Zygor Bridge

Built-in Offhand bridge (`Bridges/Zygor/Bridge.lua`) holding the read-only
**Zygor Guides** frame probe of the debug diagnostics. It is the former guide
addon probe of `Core/CanvasCompatibility.lua`, moved behind the bridge contract
with unchanged output.

## What it does

- `GetDebugDiagnostics()`: on `/offhand diag debug` only, it reports whether
  `ZygorGuidesViewer` or `ZygorGuidesViewerClassic` is loaded and its namespace
  exists, then up to eight named direct children of UIParent and WorldFrame
  whose name contains `zygor` (visibility, alpha, strata, level, scale and
  bounds), scanning at most 256 children of each. Secret values print as
  `unavailable`. Each line is printed as `Guide frame diagnostics: <line>.`
- Nothing when no guide is observed. A missing named root is not proof that the
  addon is absent.

It never moves, shows or hooks a frame and never reads guide contents. It
creates nothing and registers on every client.

## Evidence

Automated tests pass (tests/guide-addon-diagnostics.lua, tests/diagnostic-output.lua). Zygor's own
behaviour with Offhand is still unverified.
