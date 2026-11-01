# Retail scenario toast candidate, 1 November 2026

Reporter evidence from retail-test.4 identifies the earlier notification as a
pooled EventToastManagerFrame toast with displayType=6 (Scenario), distinct from
the later ChallengeModeCompleteBanner. Previous reporter environment was Retail
12.1.5 build 70688, Interface 120105; these capture screenshots do not repeat the
build identity, so that remains the last reported environment.

At +479.29 the UpdateAnchor hook places the manager at
TOP/UIParent/BOTTOMLEFT/2925.7/907.1. The subsequent DISPLAY_EVENT_TOASTS sample
records TOP/UIParent/TOP/0/0. At +170.93 an earlier callback deferred in combat.
At +1089.58 the separate completion banner is placed on Mainhand. The exact
caller resetting the toast after UpdateAnchor is not identified by this capture.

Source study: Blizzard live revision
15881d522c44cd106d3d8660106ec9f9d2f44167 (12.1.5.70575, not reporter build
70688). FrameXML/EventToastManager.lua:169-176 resets manager anchors;
327-366 calls UpdateAnchor before pooled toast Setup, Show and final Layout.
Enum.EventToastDisplayType declares Scenario=6 and ChallengeMode=7. The pinned
source establishes the later transaction boundary, not the resetting caller in
the reporter's addon environment.

The candidate adds a secure post-hook to the manager's completed DisplayToast,
retaining UpdateAnchor for independent native refreshes. It translates the final
offsets rather than imposing a fixed vertical offset. Hook bookkeeping is per
frame and method. Closing an empty toast restores owned native geometry.
Combat-time native requests coalesce to one replay per root after combat, with
no captured geometry. Replay requires the same eligible visible root and a known
stock anchor (-190 or the captured 0 offset), then rechecks enabled/span/ownership
state. Hidden/expired toasts and custom placements are not adopted by replay.
No pooled toast scripts, buttons, text, animations or queue lifecycle are replaced.

Validation: all 73 current Lua suites pass, including the captured reset sequence,
combat replay/coalescing, expiration, custom-owner handoff, disable and restoration.
Six manifests pass path/XML/Lua 5.1 validation. These are simulated/static checks;
real timing, rendered placement and taint/protected-action acceptance remain pending.

Artifact: dist/Offhand-v2.1.2-beta.24-retail-test.5.zip, 772822 bytes.
SHA256: D9526A129211C32915F3825E33F73B1081D308A38EAA409A5F02917306A64A2C.
All 76 extracted files match the isolated snapshot and extracted validation passes.
Build snapshot: D:/Games/World of Warcraft/_offhand_deploy_backups/retail-reporter-test5-20261101-015833-132.
Only snapshot TOC release labels change; canonical release metadata stays Beta24.
Previous test packages and native Companion are preserved. No local installation
was changed in this follow-up. Verify both consecutive popups on the next intended
run, including a combat transition if it occurs naturally. Retain the opt-in
capture if placement fails again; do not request extra keys just for this test.
