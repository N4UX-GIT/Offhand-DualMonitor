# Offhand Companion 2.1.4

Prepared release notes, unpublished candidate.

- Larger Span WoW Now button and Restore Window near the top of the dashboard.
- Separate guidance beneath each action, including the `/reload` handoff.
- System Status starts collapsed with a readable status indicator. Configuration
  is the only expanded panel for fresh settings; saved panel choices are kept.
- Show/Hide and status updates keep the window's size and position stable.
  Expanded content scrolls inside the window.
- Reserved scrollbar space keeps panel widths stable as scrolling appears.
  Hidden scroll controls are initialized and themed before first expansion.
- Dark native scrollbars for the dashboard, Activity Log, Help and workspace
  screens where Windows supports the theme. Native scrolling and accessibility
  remain available; high contrast retains system styling.
- Pause/Resume background monitoring moves to the tray menu. Its paused state
  is shown in the collapsed status summary.

The 2.1.3 Store settings-persistence hotfix is retained. Companion protocol 1
remains compatible with the existing add-on, including Pre-Release Beta 27.
No new add-on installation is required for these Companion UI changes.

After applying or changing a layout, click Span WoW Now and type `/reload` in
WoW. Use standard Windowed mode for spanning. This UI update does not claim to
resolve the separately reported, uncharacterized portable Forever issue.
