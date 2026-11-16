# Beta 33 contributor candidate live QA

13 November 2026. WoW Forever 1.60.1.70888 on Windows. The addon came
from b7c2b4f, archive SHA-256
514C41B7326C0F56E1D23F6A94A69361EB0175D4D730086F28B9A94E25C0C37E.
The initial launch used the existing Companion topology and Forever bridge.
The installed Store Companion 2.1.7 remained in the tray, and the portable
2.1.8.1 candidate was not run.

- On a single unspanned 2114 by 1353 client canvas, the addon loaded and
  /offhand centerline printed its span requirement. From Options, Advanced
  Cooldown Settings opened outside Edit Mode. Import and New Layout opened
  at their reachable default locations and were canceled.
- A temporary schema 3 fixture then described that same physical window as a
  1134 by 700 Mainhand and three distinct workspace rectangles on one
  physical display. After /reload, the client drew all three workspace
  canvases. The central and quarter lines rendered inside Mainhand at the
  expected locations. The same slash command hid them.
- With Edit Mode closed, Cooldown Settings opened in the upper-left workspace.
  Its Import and New Layout actions each presented the dialog centered on
  Mainhand. The native location observed in the single-screen baseline would
  extend into the fixture's void. Both Cancel controls worked. No layout was
  created or imported.
- OpenMap 0.8.6 stayed visible in the upper-left workspace through Escape,
  Game Menu, and entering and leaving Edit Mode. No Edit Mode changes were
  saved. This run establishes behavior for this configuration.
- Forever closed normally. The original Beta 32 addon folder, generated
  topology and pre-test Offhand saves and configuration were restored and
  verified by hash. FrameXML and taint log lengths and timestamps stayed
  unchanged. BugGrabber flushed on close and had zero new error timestamps.

## Companion span and restore

13 November 2026. WoW Forever 1.60.1.70938 on Windows with the same addon
archive and the portable Companion 2.1.8 (file version 2.1.8.1), SHA-256
43C21651391A8646F4005886C8DEB35E67A4C0A87CA63C7E63529BC77F8E78D8.
The connected displays were a 2560 by 1440 landscape Mainhand and a 1440 by
2560 portrait display, both at 100% Windows scaling. The custom plan used
an 800 by 1080 workspace on the portrait display.

- Enabling workspaces B and C with two displays available kept the workspace
  A preview visible. The planner reported the missing third display and
  disabled Save plan. Disabling B made the one-workspace plan valid again.
- Span WoW Now placed the game across both physical displays. The dashboard
  confirmed it sent the layout. After `/reload`, the addon reported schema 2
  as ready, with a 4000 by 2554 canvas, a 2560 by 1440 Mainhand, and one
  workspace. The centerline crossed the center of Mainhand.
- Restore Window returned WoW to its previous bordered window, with a
  2114 by 1353 client area. The centerline disappeared.
- The FrameXML and taint log sizes and write times stayed unchanged. The
  newest saved BugGrabber error predated this run. After the test, the
  original Beta 32 addon and bridge, the backed-up WTF files, and both
  Companion configuration files were verified by hash. Store Companion
  2.1.7 was restarted after closing the portable build.

Physical four-monitor spanning, the mixed-DPI HDR/SDR Windows bounds
mismatch, and native combat confirmations remain unverified in the live
client.
