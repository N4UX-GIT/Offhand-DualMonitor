# Standard layout and optional custom areas

The home, Companion, custom-workspace and in-game reference pages now make
standard layout the starting point for fresh settings. Two full monitors use
Span displays and Mainhand on the dashboard; the custom Two monitors editor
means a chosen rectangle on a second screen. Custom cards explain the reason to
use each editor and retain the currently published control names alongside the
clearer headings.

The Companion recovery section owns the return-to-standard sequence. Other
pages link there rather than repeat it. Saved custom plans persist across
launches, and Restore Window alone does not select standard layout. Named plans
remain saved when switching back.

These pages describe the published controls, not the draft native chooser in
PR #92. The next native build adds explicit custom opt-in and standard-first
focus. No new native screenshot is published before that build ships.

Validation: website-integrity passes seven pages and 331 local references;
git diff --check passes. Local browser review confirmed the standard/custom
comparison, the first-run callout and the return-to-standard link. The recovery
anchor has a sticky-header offset. Existing full dashboard, non-clickable image
wrappers and comparison panel are retained. Preview evidence is under ignored
dist/standard-layout-20261108 in the primary checkout.
