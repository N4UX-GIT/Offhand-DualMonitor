# Companion dashboard action hierarchy, 2026-11-09

## Behavior

The dashboard places Span WoW Now and Restore Window directly below the header.
The action row is 44 logical pixels tall, with 64% of its width allocated to
Span. Separate guidance labels sit beneath their respective buttons, explaining
applying the layout and typing `/reload`, and returning to the previous window.

With fresh preferences, Configuration is the only expanded panel. System
Status, Display Diagnostics, and Activity Log start collapsed. Explicit saved
panel choices remain authoritative. The System Status heading retains a
colored indicator and text: WoW not running/waiting, WoW running, Check add-on,
Check display layout, or Monitoring paused. Show opens the existing detailed
status. The running indicator does not claim the add-on loaded successfully.

Pause Monitor is removed from the dashboard action row. Its existing behavior
remains available as Pause background monitoring / Resume background monitoring
in the tray menu. Pausing still clears graphics-recovery tracking and stops
automatic launch monitoring while manual actions remain available. The status
summary exposes that paused state, and Help describes the tray location.

Layout measurement uses the new action height consistently. Window fitting runs
at initial load. Panel toggles and status refreshes preserve the window's size
and position; expanded content scrolls inside that window. The scroll extent is
explicit so content remains reachable at the native window-height limit.

## Validation

- `tests/companion-preferences.ps1`: passed, including dashboard alignment,
  working-area fit and expansion at 100%, 125%, 150%, 175%, and 200%. Extended
  the layout fixture for fresh collapsed defaults, action prominence/order,
  summary bounds and status transitions, and actual tray-item pause/resume.
- The layout fixture now isolates preference reads/writes from the owner's
  existing configuration. Its rendered previews respect collapsed sections.
- `tests/companion-workspace-ux.ps1`: 108 checks passed on x64 and x86.
- `tests/companion-store-persistence.ps1`: 25 portable persistence checks passed.
- `tests/companion-interaction-boundary.ps1`: source/native boundary checks passed.
- All 109 current-tree Lua suites passed. The tree includes pre-existing pending
  add-on changes; those changes were preserved and are outside this UI change.
- Reviewed the rendered default dashboard. Logs and previews are under ignored
  `dist/dashboard-actions-20261109/`. This is fixture rendering, not a fresh
  installed-Store, live WoW, or mixed-DPI physical-monitor acceptance test.

This is source for a subsequent Companion candidate. Existing prepared EXEs,
portable archives, Store packages, and add-on runtime files were not replaced.

## Local review build

`scripts/New-CompanionDashboardPreview.ps1 -OutputDirectory <fresh-directory>`
builds a distinct `UI_PREVIEW` configuration, file version `2.1.3.8001`.
It uses only `DashboardPreviewConfig.ini` beside its EXE, ignores public/Store
preferences, forces auto-span off, disables its launch controls and graphics
recovery, and uses a separate instance mutex. Ordinary builds retain their
existing configuration paths and instance identity. Manual controls remain
available for the reviewer.

Prepared and launched `dist/dashboard-ui-preview-20261109-1/Offhand.exe` for the
owner. An executable fixture in the same directory verified the actual preview
assembly's settings path, title, disabled auto-span controls and recovery flag.
The production preference/layout regression suite passed again. Computer Use
confirmed the visible window, correct logo, action hierarchy, collapsed status,
expanded Configuration, and absence of a vertical scrollbar. The window was
left open for review. No game input or span action was performed. Fresh settings
on this host select its one active display without enabling split, so the
collapsed indicator appropriately requests a display-layout review.

## Preview 2 corrections

The owner reported jarring Show/Hide resizing and ambiguous placement of the
shared two-line action guidance. Removed both toggle-time window fitting and
queued status/shown-time growth. The layout fixture now persists toggles for
all four panels at each supported scale and asserts unchanged outer bounds.
It also checks overflowing status content scrolls without growth. Separate
guidance labels share each button's column and are checked for alignment and
text clipping at 100%-200% and several window widths.

Preference/layout checks passed. Built and launched
`dist/dashboard-ui-preview-20261109-2/Offhand.exe`, file version `2.1.3.8002`.
Computer Use verified the button guidance and System Status expansion/collapse:
the visible window stayed 550 by 704 logical pixels while expanded content
scrolled. Closed the earlier preview through its Exit Companion button and left
Preview 2 open with Configuration expanded and supporting panels collapsed.
No WoW span, game input or public/Store package replacement was performed.
