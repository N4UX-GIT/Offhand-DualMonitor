# First-time guide and calibration UX review

## Scope and evidence

The reference path is Windows Companion, followed by the in-game guide and calibration wizard. The alternatives reviewed in source are FancyZones, manual placement, macOS, a client without a usable reload button, clients without Edit Mode, controller layouts and the optional EllesmereUI handoff.

The live subject was Noggaholic Naux on Forever 1.60.1.71139, addon 2.1.5 beta.43 and installed Companion 2.1.9-beta.4. The desk has a 2560 × 1440 Mainhand and a 1440 × 2560 portrait workspace. This character already had a HUD layout. Opening the guide again exercises the UI, but fresh-account startup is covered separately by simulation. The installed addon comparison found differences in the 11 locale files only. The checkout's English welcome paragraph about loading screens was absent on the installed client.

## What a player encounters

| Stage | Finding | Recommended change |
| --- | --- | --- |
| Welcome | The title and Start setup button are clear. The checkout puts the product description, panel ownership, loading screens, backups, optional customization and pausing on the same page. | Lead with the backup and next action. Keep the loading-screen explanation near the decision to span and put ownership details in help. |
| Method and installation | On the live desktop Companion was open. The guide still highlighted Get Companion on the installation question. A running app and a layout loaded in WoW are different signals. | With a valid loaded Companion layout, offer to continue with it. When installation is unknown, give Already installed and Get Companion neutral treatment. |
| Window mode | The live page correctly identified Windowed. It still required Place WoW, which opened instructions. The user then had to go to Companion to actually place the window. | For verified Windowed, proceed to placement after method selection. Keep mode selection and the manual check for blocked or unknown clients. |
| Before the first span | On the live Windows path the first paragraph instructed the player to rearrange the numbered displays in Windows. The diagram showed an example, and a lower status line advised restoring and spanning. The primary button was Window is positioned. | Lead with the selected method. Put Windows display arrangement in troubleshooting. Show one current instruction and identify an example diagram as such. Distinguish a pre-reload layout from a mismatch that persists after reload. |
| Troubleshooting | Having trouble? displayed the literal ONBOARD_PATH_COMPANION_4 on Forever. Source also requests an undefined ONBOARD_PATH_COMPANION_3 on the Windowed page. The locale fallback returns the key itself. The wizard test compares the UI against the same fallback, so it passes. | Supply real localized help for each state. Test for a defined English string independently of fallback and check what is rendered. Manual and FancyZones expanded help should describe the current phase instead of pointing to final confirmation before reload. |
| Reload | Window is positioned records the acknowledgement and prepares the reload checkpoint. Reload UI performs the reload. On clients without a reload function the guide instructs the player to type /reload after the checkpoint is saved. | Offer one explicit placement-and-reload action once the player has checked the window. Tell the player the guide will reopen. Keep the typed fallback and combat guard. |
| Review and handoff | The Companion branch opens a second Confirm placement button in a review dialog, then a handoff page with Start Calibration. Manual placement instead asks to Remember Window, which saves the intended canvas. | Put the visible coverage question on the post-reload review itself. A single Confirm and start calibration can recheck the layout signature, save it and open the wizard. Keep Back and an explicit save decision for a manual canvas. |
| Calibration discovery and orientation | Use Companion layout advances to a second page displaying the same arrangement. With exact geometry the orientation and aspect choices are hidden. On the manual route orientation and aspect can affect the result. | For a validated exact layout, show the arrangement once. Offer Adjust alignment and scale as an explicit path. Keep the detailed route for manual and uncertain geometry. |
| Seam and scale | Exact layout removes the seam-width controls. The seam guide, vertical offset and scale preview can still be useful on a mixed-height desk. | Preserve the current offset and scale in the quick path. Preview and adjust them on demand. Show what to look for at the physical bezel and provide Back. |
| HUD and completion | Clients with Edit Mode can require creation or selection of a HUD layout and a second reload. Other clients finish after scale. Controller and EllesmereUI paths have their own choices. The calibration close tooltip promises to discard new changes even though controls can apply changes immediately and the step can resume. | Name the reason for a HUD reload. Describe closing as pausing where appropriate. Finish with a visible test: character and HUD on Mainhand, map on Offhand. Keep HUD selection, reuse, deferral and capacity recovery explicit. |

## Shortest credible Companion path

After **Span WoW Now**, target two deliberate in-game actions for an ordinary exact layout. **Window fits · Reload UI** records the current layout before reloading. **Confirm and use this layout** accepts the visible result and applies supported defaults while preserving the user's scale. Provide **Adjust alignment and scale** alongside the second action. Hand off to the appropriate HUD step only when the client and character need it.

This is a proposed interaction, not measured completion time. WoW can read geometry after reloading. The player can verify which physical screens the window actually covers. The quick path needs both checks. It must revalidate after combat, size changes or an invalidated checkpoint. A reopened guide, a stale custom workspace of the same dimensions, or an old HUD record must never count as a fresh confirmation.

On the present ordinary Companion route, count five player clicks **after Span WoW Now and before the wizard opens**: Window is positioned, Reload UI, Confirm placement, Confirm placement in the popup, Start Calibration. This count excludes typing a manual reload, correcting the span and any later HUD operation. Combining placement acknowledgement with the reload, and combining post-reload review with starting calibration, would reduce those five clicks to two. Finding and operating Companion is a separate task.

There is an important difference between the two actions on the discovery screen. The recommended button calls [AutoConfigure](../UI/OptionsActions.lua), which writes a HUD scale of 0.70 even when a returning user had chosen another scale. Ordinary Next takes the calibration path that retains manually chosen values. On the exact Companion route the recommended button reads “Use Companion layout,” which gives no indication that text size may change. A shorter setup should apply the confirmed geometry separately from any optional reset of UI size.

## Live walkthrough on the portrait and landscape pair

1. The selected character already had an Offhand HUD. On login, a single-screen recovery dialog offered Use Modern, Reload UI and Keep Current Layout. Keep Current Layout allowed the guide walkthrough to begin without replacing the existing HUD.
2. Opened `/offhand guide` and followed Start setup, Use Companion, Already installed and Place WoW. Even though the app was running, Get Companion was highlighted on the installation question. Ordinary Windowed mode was already correctly identified.
3. Opened Having trouble? and observed the raw localization key on the placement page. An independent Lua lookup confirmed the page 3 and page 4 keys fall back to their names. Neither literal is defined in the locale files.
4. Companion had two candidate game processes. Selected the Forever client, kept Display 1 as Mainhand and clicked Span WoW Now. A native WoW screenshot measured 4000 × 2560. At this moment the guide still showed an example layout, a highlighted Window is positioned button and a separate status advising a restore and re-span. The status should explain which instruction wins before the first reload.
5. The tester operated the placement and reload controls and reported “Step 4 out of 5, 3 out of 3.” This is the post-reload review in the state machine. The two progress counters describe different scopes, but the reported numbers alone say little about what to do. Lead with “Check your screens” and the next action.
6. On the next agent observation the client had returned to a smaller bordered window, placement phase 1 and a separate per-character HUD prompt. A single-screen recovery dialog also appeared. The window-size change was observed; its cause and timing were not established. Treat this as a returning-character overlap. The source checks whether the wizard is open before showing character setup but also needs to account for the onboarding guide. Give window placement priority over HUD decisions.
7. The Windows control surface could see only the primary monitor while WoW spanned both. Companion later showed the other running game as its selected client. Further desktop actions were paused. Final placement acceptance, calibration completion, the HUD reload and an end-of-run error check are outstanding for this live session. Later wizard stages in this review are supported by source, simulations and earlier native captures.

## Acceptance checks for the proposed shorter path

| Case | Observable success |
| --- | --- |
| Fresh Windows Companion setup | A player can identify the one enabled action after spanning, reload once for placement, return to the review and accept the visibly correct layout. The character stays on Mainhand and the map opens on Offhand. |
| Changed monitor roles or workspace rectangle | Change the layout between acknowledgement and confirmation, including a different region on an equal-sized canvas. The old confirmation cannot apply. Recovery tells the player which app to use and what to click. |
| Interrupted setup | Closing the guide, a delayed window resize, combat or a failed span must leave a recoverable step. A stale confirmation popup cannot commit an earlier layout. |
| Manual or FancyZones, including macOS manual | Visually confirm coverage, explicitly remember the canvas and retain access to orientation and seam adjustment. Unknown window mode and manual reload remain usable. |
| Already-configured character | Use the same loaded layout without repeating calibration. Opening window setup must not compete with character HUD creation. A deliberate change of layout still requires revalidation. |
| HUD branches | Exercise reuse, creation, deferral, Edit Mode already open, layout capacity reached and optional HUD-addon review. A client without Edit Mode finishes after scale. If a HUD reload is required, explain why and preserve progress. |

## Verification

**Implementation order.** First fix the missing help and the competing instructions at placement. A confused player needs an answer even on older clients. Next suppress unrelated HUD prompts while the placement guide is active and make the two post-span actions explicit. Then shorten exact-layout calibration, keeping an advanced path for the seam and scale. Change the Companion tooltip, website walkthrough, localizations and screenshots with any renamed buttons so all surfaces use the same sequence.

- The project compatibility checker passed six manifests, 97 runtime Lua files and 151 Lua suites. All 11 checker unit tests passed.
- The targeted first-launch, placement identity, wizard and manual calibration stress suites passed. They exercise pending geometry, combat deferral, reload recovery, saved steps, changed workspaces, HUD capacity, optional EllesmereUI review and manual geometry.
- Earlier native Forever results include a real reload, Back from review and accepting placement on a single-display split. See [the November 9 walkthrough](GUIDE-WIZARD-LIVE-QA-20261109.md). This evidence is separate from the current two-display run.
- Source entry points are [the onboarding guide](../UI/Onboarding.lua), [placement checkpoint](../Core/SetupPlacement.lua), [calibration wizard](../UI/Wizard.lua), [English UI strings](../Locales/enUS.lua) and [wizard regression suite](../tests/wizard-autoconfig.lua).


## Implemented Companion flow

The first in-game click, **Window fits · Reload UI**, saves the placement checkpoint. Clients that require a chat command show `/reload` after that checkpoint is saved. After reloading, the guide shows the screen arrangement. **Confirm and use this layout** accepts it and opens HUD setup where supported. Clients without the HUD step finish immediately. **Adjust alignment and scale** opens the seam controls. FancyZones and manual placement retain their visual confirmation and calibration steps.

The wizard simulation exercises both buttons, a workspace change on the same canvas, the two HUD branches and preservation of a saved 87.3% scale. The website walkthrough was checked at 390 and 1440 pixels. The live observations above cover the earlier build. The subsequent Forever walkthrough is recorded below.

## Live retest on Forever, 27 November 2026

Noggaholic Naux used the two-display Companion layout on Forever 1.60.1.71139. The primary display was 2560 × 1440 with a 1440 × 2560 portrait workspace to its left. A native WoW screenshot confirmed the 4000 × 2560 canvas. The existing character had a saved HUD layout and an earlier placement checkpoint. The test reset the placement checkpoint to reproduce the first reload while retaining the profile and HUD.

| Check | Live result |
| --- | --- |
| Return after reload | Activating **Window fits · Reload UI** produced a loading screen. The guide reopened automatically at **Check your screens**, step 4 of 5, on both runs. |
| Accept and preserve scale | **Confirm and use this layout** opened the HUD choice at step 5. Offhand scale was 0.7, WoW's uiScale CVar was 1.000000 and UIParent effective scale was 0.39375001192093 before the placement reload and after acceptance. The existing HUD was left in place. |
| Find manual calibration | **Adjust alignment and scale** was visible under the diagram on the review screen. Selecting it opened **Physical Monitor Seam Alignment**, step 3 of 5, with Scale next in the progress rail. |
| Review the diagram | The first run showed “Example layout” despite a verified span. The adjoining screen edges differed by 0.0000302 UI units after coordinate conversion. The revised diagram treats this rounding difference as a shared edge. A second live reload showed “Configured regions” with the correct arrangement. [Review screen](../Website/assets/offhand-guide-companion-review-forever.png) |

The desktop control could see only Mainhand after spanning. The harness used local commands to activate the visible labeled addon buttons in the native client. Physical pointer hit testing on the spanned desktop and a clean-account run remain separate checks. The installed Store Companion was 2.1.9-beta.4 and displayed its released post-span text.

BugGrabber recorded an invalid callback from the QA command's optional screenshot timer after it printed the scale. Capture used the game's screenshot key instead. No new Offhand error record appeared in the run. All 151 Lua suites and 11 checker tests passed. After capture, Companion restored the prior window size, the Forever test client closed normally and the installed addon source files were restored from the pre-test backup.

## Fresh Offhand setup on Forever, 27 November 2026

On Noggaholic Naux, the isolated test started with no Offhand SavedVariables, no recovery bridge settings and no saved Companion topology. The character retained an isolated copy of its existing Blizzard HUD settings. Both the original settings tree and installed addon were parked for the test.

- **After Span WoW Now.** The initial guide straddled the bezel. The corrected guide used the monitor bounds written by Store Companion 2.1.9-beta.4 and appeared fully within the 2560 × 1440 Mainhand before reload. The placement preview only positions the guide. The game layout still requires the review and confirmation.
- **Physical clicks.** The tester clicked **Window fits · Reload UI**, saw the guide return, and clicked **Confirm and use this layout**. Both clicks worked. **Adjust alignment and scale** was visible beneath the diagram on the review screen.
- **HUD handoff.** The tester reported the wizard at the lower-left corner of Mainhand. The first activation applies the game layout after opening the wizard. Re-centering at that point fixed the offset. A separate live replay used the actual confirmation button’s click handler and showed the HUD step centered. Neither HUD choice was activated.
- **Scale.** Immediately before and after confirmation, the saved Offhand scale was 0.70 and the WoW uiScale CVar was 1.0. The effective UIParent scale changed from 0.64 to 0.39375 as Offhand applied that preference to the game monitor of the 4000 × 2560 canvas. The website and review text now distinguish the saved preference from the size of the rendered UI.
- **Restoration.** The test client closed normally. All 383 original settings files and all 110 original addon files matched their pre-test SHA-256 hashes in the restored installation. The placement helper was removed from the test client with the candidate.

The shared knowledge index documents C_AddOns.LoadAddOn for Forever build 70938. The fresh guide observation above was on 1.60.1.71139. Other clients and monitor arrangements have no live acceptance from this run.

## Guarding the first Companion reload

On Forever 1.60.1.71139, the placement page showed a dimmed **Window fits · Reload UI** and a waiting message on the single-window login. The client observer recorded the button becoming enabled when the 4000 × 2560 Companion layout matched. The action rechecks the match immediately before recording the checkpoint, so an outdated enabled button cannot reload a restored single window. Simulation also covered verification using the fresh-install placement preview before the addon loads its first topology. The player still confirms that Mainhand is on the intended physical monitor. If WoW already covers the chosen screens but cannot read the match, **Having trouble?** explains how to reload the layout. The exact-build shared API lookup for GetPhysicalScreenSize had no declaration; this check uses the previously validated Viewport comparison and the live Forever result.

### Fresh-install guard cycle on Forever

Noggaholic Naux followed the welcome guide through **Use Companion** to placement on Forever 1.60.1.71139 with Store Companion 2.1.9-beta.4. The test started with zero Offhand SavedVariables, an empty recovery bridge, and no loaded Companion topology. The same placement page remained open throughout. A read-only observer sampled the native button’s enabled state.

| Action | Window fits · Reload UI | Placement preview |
| --- | --- | --- |
| Reach placement before the first span | Disabled, with the waiting message | No match |
| Click **Span WoW Now** | Enabled once the 4000 × 2560 span settled | Matches the selected layout |
| Click **Restore Window** | Disabled again, with the waiting message | No match |

The checkpoint stayed empty across all samples. There was one UI session, zero errors recorded for that BugGrabber session, and no interaction with the reload button or HUD choices. After closing the test client, all 383 original settings files and 110 original addon files matched their pre-test SHA-256 hashes. [Screenshots of the three button states](evidence/forever-fresh-reload-guard.png)

### Second span through HUD setup on Forever

A separate fresh run on Noggaholic Naux, Forever 1.60.1.71139 with Store Companion 2.1.9-beta.4, kept the placement guide open for both spans. The native reload button started disabled, enabled after the first span, disabled after **Restore Window**, and enabled after the second **Span WoW Now**. The observer saw the placement preview match on the second span before the button enabled. The checkpoint stayed empty until the click.

1. Clicking **Window fits · Reload UI** produced a loading screen and saved the reload checkpoint for the 4000 × 2560 canvas. The guide reopened automatically at **Check your screens** on Mainhand. **Adjust alignment and scale** was visible.
2. Clicking **Confirm and use this layout** opened **Create Mainhand HUD Layout**, step 5 of 5, centered on Mainhand. After closing the client, the character's test settings contained the confirmed Companion checkpoint and `wizardProgressStep = 5`. Neither HUD choice was clicked.

### Manual placement on the same Forever build

Noggaholic Naux started **Configure Manually** with fresh Offhand settings and an empty Companion bridge. The tester positioned standard Windowed WoW across the portrait-left and landscape-right displays. WoW reported a 3991 × 1558 render canvas. The guide enabled **Window is positioned** when the resize settled.

**Window is positioned** exposed **Reload UI**. The guide returned after the reload at placement step 3 of 3. **Confirm placement** opened **Remember Window**. Accepting it exposed **Start Calibration**. Using **Next** through orientation, seam and scale reached **Create Mainhand HUD Layout**, step 5 of 5. The scale page showed 70%; the slider and HUD choices were left untouched. On exit the saved checkpoint was `V1|MANUAL|3991|1558|C` and the wizard step was 5.

**UX finding.** The detection page called this two-monitor canvas “Single-Display Ultrawide Split” and recommended a 30.6% workspace. The description comes from the canvas aspect ratio. WoW cannot determine physical monitor count from those dimensions. The manual wizard should identify the confirmed window and present its split as a suggestion. This run used **Next** to review the layout; it did not test the suggested one-click preset.

Both the second-span and manual tests added zero BugGrabber records across login and reload. After closing Forever, all 383 original settings files and all 110 original installed addon files matched their pre-test SHA-256 hashes. FancyZones uses its own onboarding method. The manual run does not verify the PowerToys snap.

### FancyZones through HUD setup on Forever

On Forever 1.60.1.71139, Noggaholic Naux chose **Use FancyZones** with fresh Offhand settings in an isolated copy of the client configuration. PowerToys was enabled temporarily. The tester Shift-dragged standard Windowed WoW into the existing **Offhand** canvas. PowerToys recorded Forever in zone index 0 of that layout. Windows measured a 4000 × 2512 outer frame and a 3998 × 2480 client area.

1. **Window is positioned** exposed **Reload UI**. After reload, the guide reopened at placement step 3 of 3. **Confirm placement**, **Remember Window**, then **Start Calibration** opened detection.
2. The revised label read **Remembered Window · 3998 × 2480**. The line below suggested a portrait workspace on the left, game on the right, and a 36% split. [In-game calibration screenshot](evidence/forever-fancyzones-remembered-window.png)
3. **1-Click Auto-Configure & Apply (Recommended)** applied the suggested split and opened orientation review. **Next** advanced through seam alignment and the 70% scale screen to **Create Mainhand HUD Layout**, step 5 of 5. Neither HUD choice was activated. On exit the test character had `V1|FANCYZONES|3998|2480|C` and wizard step 5.

**Remaining UX observation.** Before accepting the window, the guide centered itself on the full canvas. Its title fell in the desktop gap above the landscape monitor. The placement and reload buttons were visible. After applying the recommendation, the wizard appeared against the lower-left edge of Mainhand.

The login and reload added zero BugGrabber records. After closing Forever, all 383 original settings files and all 110 original addon files matched their initial SHA-256 hashes. FancyZones was switched off and its original layout and snap history were restored.

### Mainhand placement retest on Forever

The placement guide and **Remember Window** now fit inside the proposed Mainhand rectangle before calibration. Remembering the window still requires the player's confirmation. Applying the recommendation recenters the calibration wizard after the UI scale settles.

On Noggaholic Naux, live QA reproduced the two previously measured native window positions with FancyZones off. The earlier walkthrough covered the PowerToys snap itself. A temporary observer measured the guide, title, visible placement buttons, confirmation and wizard in client pixels. Adding the Windows client origin placed every measured rectangle inside the physical 2560 × 1440 Mainhand.

| Check | Observed result |
| --- | --- |
| Manual, 3991 × 1558 | The entire guide stayed visible, including the title and footer when **Having trouble?** expanded. |
| FancyZones, 3998 × 2480 | **Window is positioned**, **Reload UI** and the returned **Confirm placement** screen fit on Mainhand. **Remember Window** appeared over the guide. [Mainhand after reload](evidence/forever-guide-mainhand-after-reload.jpg) |
| Apply the recommendation | The orientation page centered in the proposed game area. Its bounds on Mainhand were approximately (841, 273) to (1718, 1082) pixels. |

The [full-restart rerun](COMPATIBILITY.md#both-restart-timings-on-the-onboarding-candidate-november-27) also passed on this checkout. Neither test changed the original HUD. The restored settings and addon matched all 493 original file hashes, and the isolated runs added zero BugGrabber errors. Before independent window placement has been confirmed, WoW relies on the configured side, split and offsets to estimate the physical Mainhand area.
