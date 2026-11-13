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

Physical four-monitor spanning and native combat confirmations remain open.
The mixed-DPI HDR/SDR Windows bounds mismatch was outside the fixture.
