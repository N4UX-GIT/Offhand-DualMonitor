# First-install Next, HUD creation and reload: native PASS

Follow-up: the separately authorised account reset/default-Companion run now
passes with zero prior native HUD rows, first HUD creation, reload and cold
restart. See [clean-account evidence](SPAN-SETUP-CLEAN-ACCOUNT-LIVE-QA-20261108.md).
The scope and cleanup below describe the earlier run only.

Verified on 8 November 2026 with the WoW test harness workflow, diagnostics
helper, actual mouse clicks and a temporary addon-owned recorder. The exact
private span-setup-test1 package was used. No further product correction was
needed during live testing.

Acceptance boundary, clarified after the owner's follow-up: this is fresh
Offhand saved state on an existing WoW character and existing Companion setup.
It is not complete never-before-used installation acceptance. Other WoW settings,
native Edit Mode layouts/caches and Companion's saved display selection remained.
Those could affect first-use paths outside the reproduced disabled-Next defect.
A separate clean-settings/default-Companion run, including native HUD creation,
reload and cold launch, is still required before closing that broader claim.

## Environment and isolation

- Forever 1.60.1 build 70862, keyboard interface, the already selected idle
  level-2 test character. No movement, combat or gameplay actions were issued.
- Store Companion package 2.1.301.0, product 2.1.3. The host exposes one physical
  2560x1440 display, so the existing explicit Companion split provided Mainhand
  right 1280x1440 and workspace left 1280x1440. This verifies the setup path,
  not the reporter's separate 4480x1440 two-monitor arrangement.
- Candidate ZIP SHA-256:
  C6B6FE2DBCA41AC60E8A4A4B3D867C53BBB640BDF6A39F36FBF37C236B2D37C1.
  All 86 installed package entries were verified before launch. It differs from
  published Beta 27 only in Wizard.lua and six candidate TOC title/marker changes.
- Closed the prior Beta 26 test19 client normally. Backed up all 222 WTF files,
  26 cache files, 83 installed-addon files including both generated bridges, and
  Store Companion preferences. Temporarily isolated eight Offhand state files
  and used the packaged inert recovery bridge. A cold process removed prior
  session CVars. Companion reported no valid recovery state to import.
- Enabled Offhand, the recorder and BugGrabber for the test character; existing
  custom UI addons were temporarily disabled. Native layouts remained available
  and were backed up, so HUD creation could retain existing rows safely.

## Actual UI path and evidence

1. Fresh login automatically opened Welcome, with setup incomplete and Offhand
   disabled. Used Start setup, Use Companion, Already installed and Place WoW.
2. Used Companion's real Span WoW Now, then the guide's Reload UI. The guide
   resumed at placement. Clicked Confirm placement and Start Calibration.
3. Clicked the ordinary Next on calibration step 1. The viewport activated on
   Mainhand. The local QA snapshot showed enabled=true, setup=false,
   viewportMatches=true and AutoConfigure calls=0. No recommendation action or
   forced SetEnabled command was used.
4. Continued with Next through orientation, seam and UI size. The final card
   correctly said the HUD had not been created. Clicked Create Mainhand HUD
   Layout outside combat, with native Edit Mode closed.
5. The real transaction cloned Modern into a new generated character layout,
   moved 54 systems, selected it, completed setup and offered Reload UI. Clicked
   that actual reload button. The generated row used a collision-free suffix,
   retaining the pre-existing Offhand row.
6. After reload the setup guide stayed closed and the viewport remained active.
   Ran /offhand diag full and an additional ordinary /reload. The final native
   recorder snapshot shows enabled=true, setup=true, viewportMatches=true,
   configured=true, currentGeometry=true, activationPending=false,
   activeMatches=true, recoveryPending=false and generated layout ID 9.
   Persistence source is savedvariables, session fallback standard, bridge
   absent, with matching disk and active revision 6.

WorldFrame measured x=1280.00004, y=0, width=1280.00004 and height=1440.00023,
matching the intended Mainhand within the existing diagnostic tolerance. The
final shutdown sample resets the viewport/native selection by design and is
not used as the settled in-world acceptance sample.

## Recorder issues, errors and limitations

The temporary recorder initially called the Edit Mode diagnostic through
Mainhand instead of HUD, producing one new BugGrabber entry with four total
occurrences. That lookup was corrected before calibration. Its initial missing
LoadSavedVariablesFirst marker also caused captured tables to be replaced at
reload; corrected the QA-only manifest for the final persisted snapshot. Early
stage evidence is retained in screenshots, not claimed as a complete persisted
event history. No whole-run HUD-call counter is inferred from the reset recorder.
The actual button transaction, generated record and selected native layout
provide the HUD creation evidence.

BugGrabber comparison against the original backup found zero new product Lua
messages or counter increases. All four new occurrences belong to Recorder.lua.
The existing taint.log predates this run, so it provides no fresh taint-safety
evidence. Combat/protected descendant use, cold relaunch persistence, other
clients and the reporter's exact physical topology are not accepted by this run.

## Cleanup and retained artifacts

Closed the test client normally, then closed Companion while restoring state.
Archived test WTF/cache, generated data, recorder and error evidence. Restored
all 222 WTF files, 26 cache files, 83 original-addon files and Companion settings
byte-for-byte. Removed the temporary QA addon. Restarted the previously running
Store Companion and rechecked every original hash. Battle.net remains open;
WoW is closed. The original test19 installation is restored. No release or
Store artifact was changed, and the private ZIP hash is unchanged.

Private evidence lives under dist/span-setup-test1/live-20261108: screenshots
01-11, after/WTF, final-qa.lua, baseline-manifest.json, acceptance.json and
cleanup.json. The original and corrected recorder sources and its failures are
retained outside the deliverable package.
