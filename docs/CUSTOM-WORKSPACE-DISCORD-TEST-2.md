# Offhand Workspace Test 2 (Unofficial)

This is an opt-in Discord tester package, not an official release or Store
update. It includes the updated addon, Companion 2.1.3 Beta 5 (file 2.1.3.6),
and a self-contained test Background Studio. Existing Test 1 remains available.

## Install and recover

1. Close WoW and exit the existing Companion normally. Back up your installed
   Offhand folder, WoW SavedVariables and Companion preferences.
2. Extract Offhand-Complete into a separate folder. Copy its Offhand folder
   into the target client's Interface/AddOns folder, replacing the old addon.
   Keep the folder name Offhand. Do not copy the entire complete archive there.
3. Launch this package's Offhand.exe from its separate folder. Select the game
   display, then Custom region. Use the visual overlay or numeric fields,
   save the plan and press Span WoW Now. Reload the game UI once if prompted.
4. Use Restore Window before switching back. To roll back, close both apps and
   restore your backed-up addon, SavedVariables and Companion preferences.
   Do not delete your SavedVariables as an upgrade step.

The game and each custom workspace use different monitors. One game plus two
workspace regions needs three physical displays. Each workspace must be at
least 480x600. Free desktop stays outside the selected regions. The fullscreen
taskbar behavior from Test 1 remains included.

## What changed since Test 1

- Named Companion workspace plans and named addon layouts retain placement,
  routing, region appearance and background preferences.
- Automatic panel routing supports region destinations while preserving
  manual placement intent. Oversized native panels can recover to Mainhand.
- Independent themes, image fit and optional image selection for each region.
- Companion editors share a consistent dark theme, display numbers, visual
  plan preview, readable disabled controls and validation before saving.
  Unused Workspace B fields are hidden while retaining their values.
- Overlay arrows move by 10 pixels; Ctrl uses one-pixel steps. Shift resizes.
  Enter accepts and Escape cancels. Saving a plan does not immediately span WoW.
- Optional two-image Background Studio library, with safe single-image
  compatibility and missing-image theme fallback.

## Try the optional backgrounds

Open Offhand-Background-Studio.html from the extracted package in your normal
browser. It works locally without a server, account or upload. The public
website has not been deployed with this test feature.

Choose an image and adjust its fit. For separate region backgrounds, select
Add background, choose a second image and edit it independently. Both images
share the existing texture budget. Generate one Offhand_UserMedia.zip.
With WoW fully closed, extract Offhand_UserMedia beside Offhand. Fully restart
WoW so the client can reload the textures.

In /offhand, open Themes. Each active region can inherit the shared setting,
use theme only, use the shared image, or select an installed image by name.
Fit is independent per region. Named layouts retain these choices. To edit
a library later, use Update package so the image IDs are preserved. Removing
an assigned image restores the region theme until you choose another image.

Existing single-image schema 2 packages still work. Libraries use schema 3 and
require this updated addon. Media packages contain only declarative metadata,
JSON, text and TGA images, never Lua. Open received media packages through
Studio and regenerate them before installing.

## Validation and remaining tester checks

All 90 Lua suites, Lua 5.1 syntax and all six manifests passed.
Studio checks include package safety, aggregate limits, stable image identity,
96 website-to-Lua crop/fit comparisons, two-canvas rendering and named profile
isolation, and simulated offline editor/import/export events. These simulations
do not establish browser visual acceptance.

The exact included Beta 5 Companion applied a 480x600 custom workspace on
Retail 12.1.5.70783 and restored the original native window bounds, style and
clipping. Both library images visibly rendered in that workspace, the second
image survived reload, switching profiles restored the first, and a missing
image returned to the theme while retaining its ID. All 13 historical
BugGrabber records were unchanged. The original local files were restored with
verified hashes. The level-one QA character remained idle.

Earlier native editor/planner/profile/rollback tests and Anniversary evidence
are documented separately. This package does not claim a fresh Anniversary
library acceptance, library cold relaunch, every Blizzard panel or replacement
bag integration, combat/protected-action safety, physical third-monitor render,
mixed DPI, hotplug, screen-reader/high-contrast or browser visual/export QA.
The browser tool blocked local-file access, so the remaining visual Studio
check is for testers. The HTML event/export logic passed simulation.

Please report client/build, monitor layout/scaling, region sizes, profile name,
steps, expected/observed behavior, and any fresh Lua error. Avoid credentials,
account folders or unrelated chat in shared evidence. Send feedback manually
in the Discord test discussion.

Checksums and source/component receipts accompany the downloads. The Companion
was built locally; no GitHub Actions attestation or official signing is claimed.
