# Guide and wizard usability QA, 2026-11-09

Current candidate: private Guide & Wizard Test 11, installed locally. Not published.
Latest follow-up: docs/SETTINGS-USABILITY-20261109.md.
The earlier sections retain the Test 8 history; the current dialog follow-up is below.

## Result and scope

The setup guide has spaced method descriptions and placement instructions. The
Companion placement task highlights the actual external button, Span WoW Now,
while the final instruction inserts the localized in-game acknowledgement label.
Reload and confirmation instructions are separate short paragraphs. All 11 locale
dictionaries carry this revision.

Action buttons have readable light text, a gold outline and a stronger hover tint.
Current-step markers have a subdued dark tint and larger shadow-free text. The
close button is inside the header. Borders use a thicker, more visible stroke.
Window-mode examples are explicitly illustrations with decorative window chrome;
the redundant disabled Already Windowed control is hidden when no action is needed.

Companion calibration hides manual layout and aspect choices on the layout page.
The seam page hides manual width controls but retains the guide and vertical
alignment. These controls remain available for manual geometry. Discovery uses a
short Companion summary. Native paragraph height is reserved explicitly, rather
than trusting already-truncated FontString metrics. The scale preview shows the
current percentage and the HUD page uses concise instructions without a readiness
dump. Existing controller, Ellesmere and error/recovery paths are preserved.

## Package and installation

- ZIP: dist/guide-wizard-live-20261109/Offhand-v2.1.3-beta.27-guide-wizard-test8.zip
- SHA256: 584055caeed4cffc923c476ab799e0a234fbdf8c16023672e211f8cc43784fd9
- Archive: 88 addon-only entries, each verified against the staging source.
- Baseline: accepted Beta 27 span-setup-test1, preserving WorkspaceRegions and
  activation through ordinary wizard Next. Only scoped guide/wizard changes were
  merged onto that newer baseline. The older dirty root checkout was not installed.
- Live target: C:/Games/World of Warcraft/_forever_/Interface/AddOns/Offhand.
- Test 8 updates 11 locale files and six manifests from Test 7. Concurrent changes
  are checked before replacement. Generated topology/recovery files are preserved.
- No native Companion binary, third-party addon patch, account data, QA helper,
  test fixture or shared knowledge cache is included.

## Native observations, separate from simulation

Target Forever: GetBuildInfo returned 1.60.1, 70862, Nov 6 2026, interface 16001;
locale enUS on Windows. The available physical display was 2560x1440, using
Companion's single-display split, with 1280x1440 game and workspace areas. This
is not native mixed-monitor or stacked-layout acceptance.

Earlier Test 2 native sequence:

1. Welcome, method choice and Windowed preparation opened in-world.
2. Confirm placement remained disabled before spanning.
3. Store Companion 2.1.3 Span WoW Now changed the native window to the split layout.
4. Window is positioned advanced to Reload UI; confirmation remained disabled.
5. The guide's Reload UI button performed a real reload and reopened at review.
6. Cancelling final placement review kept the guide on review. Accepting it opened
   the calibration handoff. No HUD layout was created by the agent.

Test 6 native sequence after its installation and a real reload:

- Wizard discovery showed the short Companion summary without truncated text.
- Layout review had no disabled manual preset/aspect controls.
- Seam review hid width controls and retained guide/vertical alignment controls.
- Scale preview and numeric input both showed 70%, changed to 71%, then returned
  to 70% with Reset. The sample inherited the actual UI scale.
- HUD setup displayed the short instructions, existing layout name and complete
  diagram, with no technical readiness block. The HUD creation button was not used.
- A middle click on Next positioned the pointer without advancing; its native
  hover tint appeared and its light text remained readable.
- The guide welcome showed its contained close control and complete panel borders.
- No new Lua error dialog was visible during these checks. The private QA capture
  contains 11 snapshots and zero recorded Offhand blocked/forbidden events. This
  is not combat, protected-action or comprehensive taint acceptance.

Test 7 progress-label styling was installed but automated native review was
interrupted with physical Escape. Subsequent user screenshots show the subdued
progress treatment. Test 8 changes only copy, spacing and private QA cleanup;
its final native paragraph layout still needs review after reload.

Native screenshots 01 through 12 are private QA artifacts under
 dist/guide-wizard-live-20261109/screenshots. Do not publish full desktop captures
without checking incidental chat/notification content.

## Validation

- 104 root Lua suites pass.
- 111 suites pass against the combined packaged runtime, including the preserved
  newer baseline activation checks and all 11 locale layout fixtures.
- Six manifests pass paths, XML references and Lua 5.1 syntax validation.
- Test 8 archive bytes and installed locale/manifest bytes match their staging files.
- Receipts and results are in dist/guide-wizard-live-20261109.

## Cleanup and remaining native coverage

The temporary OffhandGuideQA addon was moved out of the live AddOns folder into a
private local archive. It is absent from all candidate ZIPs. The currently loaded
helper unloads on the next reload, so it cannot print world-entry status afterward.
Existing chat history is not cleared. Its SavedVariables were copied privately as
evidence; normal Offhand startup and other addons' messages were left alone.

The user interrupted automation twice with physical Escape. The client remains
open for the user's review. No further desktop input was made during the Test 8
copy pass. UI scale was restored to 70%. Existing HUD edits and concurrent
Companion development were preserved; no account-wide backup was restored over
subsequent user changes. Initial installation/settings backups remain private.

Remaining native coverage includes final Test 8 copy layout, full supported UI
scale and language combinations, fresh profiles/cold launch, manual/FancyZones,
real mixed-height/stacked displays, and controller/combat behavior. The source and
synthetic tests do not close those gaps. The public website changes remain local
source and need final released-build screenshots when this candidate is promoted.


## Test 9: stable placement and HUD dialogs

The user observed Confirm placement briefly appearing at the full-canvas seam,
then jumping to the upper Mainhand anchor. Source review found that keyboard/mouse
placement confirmations and Mainhand HUD reload/selection notices still entered
Blizzard's shared StaticPopup stack. The exact-build 70862 source study recorded
in the shared knowledge project describes its TOP/linked-dialog positioning.
That source mechanism and the user screenshot support the diagnosis; this turn
did not independently reproduce the timing in the native client.

These setup keys now use the existing Offhand-owned card in keyboard/mouse UI:
windowed confirmation, Companion placement confirmation, both manual placement
confirmations, Mainhand layout reload and Mainhand layout selection. The existing
skip-HUD prompt already used this route. The card is hidden while populated,
measured/fitted, and anchored at the Mainhand center before Show. No native pooled
popup point, script, strata or visibility is changed by this correction. Other
keyboard popup routes and controller handling are preserved. Placement acceptance
still runs the existing fresh-state, revision, combat and geometry checks. The
HUD creation and reload callbacks retain their existing execution paths.

Regression coverage verifies each affected key bypasses StaticPopup_Show,
receives its final Mainhand center before Show, can be replaced without accepting
or cancelling, and retains accept/cancel data and owned HidePopup behavior.
The unrelated keyboard-popup route remains native. The manual placement guard
suite captures the public ShowPopup boundary so it remains independent of renderer.

104 root and 111 combined packaged Lua suites pass. All six candidate manifests
pass path/XML and Lua 5.1 syntax checks. Test 9 was built from Test 8, preserving
the accepted newer span baseline. Only Core/Init.lua and six private TOC titles
were replaced after a concurrent-change comparison and private backup. Generated
Companion bridge files remain untouched. All 88 ZIP entries match staged bytes.

- ZIP: dist/guide-wizard-live-20261109/Offhand-v2.1.3-beta.27-guide-wizard-test9.zip
- SHA256: 024e9961df575e3de4a55da4db59ae441a4a3417ad4839140fc9f351b7fc600a
- Native status: installed, awaiting /reload and visual review of both prompts.
  No HUD layout was created, no reload was performed, and no desktop interaction
  was made in this follow-up. No combat/controller acceptance claim is added.
- The temporary QA addon remains outside the live AddOns folder.
