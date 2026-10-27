# First-time setup and guidance gap audit, 27 October 2026

## Scope and evidence

Reviewed candidate `ee5f24e` on `codex/setup-recovery-guidance` (draft PR #41),
including onboarding, calibration, recovery, completion, locale keys, and public
website/CurseForge guidance. The candidate is not the published Beta 23 package.
The existing unrelated functional fixes are not reopened by this review.

No game was launched and no native settings, layouts, installation or live page
were changed. Source findings were checked with the existing headless wizard
harness. A temporary copy of that harness reproduced the recovery navigation,
primary action, pause/resume and error-text cases below. The full 55-suite result
does not establish native execution, visual fit or taint safety.

Public pages read during this audit:

- https://offhand-wow.onrender.com/in-game-setup.html
- https://offhand-wow.onrender.com/companion.html
- https://www.curseforge.com/wow/addons/offhand

## Findings requiring attention before recording

### A01, P2: Back stays hidden after recovery

Confirmed regression in the draft candidate. `ShowRecovery` hides `backBtn`;
`SetStep` subsequently enables it but never shows it again. Reproduction:
start with a visible Back button, show a recovery card, return to valid calibration
step 3. `backBtn:IsShown()` remains false. The full-layout recovery and same-session
return from Edit Mode can therefore remove backward navigation. A fresh UI reload
recreates frames, which can conceal this in manual testing.

Source: `UI/Wizard.lua`, ShowRecovery and SetStep, around lines 1088 and 1190.
Correction: restore visibility as well as enabled state when entering a normal
step. Add assertions for Back after every recovery route, including Edit Mode
closure, retry, guide return and reopening in the same UI session.

### A02, P2: Several HUD failures still expose internal reason codes

Confirmed source and harness output. `Options:GetMainhandLayoutFailureText`
special-cases maximum/gamepad/span, but produces messages such as:

- Could not create the Mainhand HUD layout (combat).
- Could not create the Mainhand HUD layout (open).
- Could not create the Mainhand HUD layout (read-api).
- Could not create the Mainhand HUD layout (save).

These are distinct situations requiring different actions. Existing tests verify
that a combat failure remains visible but currently accept the raw token.

Source: `UI/Options.lua:150`, `Core/MainhandEditMode.lua:685`.
Correction: explain leaving combat, closing Edit Mode, absent/unsupported APIs,
missing source layouts and save/activation failures separately. Keep the raw
reason in support diagnostics. Never advise deleting layouts for an unrelated
save/API failure. Test every emitted reason, not only maximum and span.

### A03, P2: Missing-placement recovery is not led by the selected method

Confirmed source and harness output: selecting Manual and showing span recovery
still makes Reload UI the primary action. The text presents Companion first,
then FancyZones/manual instructions, despite the stored method being available.
Reloading an unplaced manual window cannot make its placement correct. The guide
already distinguishes methods; the recovery screen should preserve that clarity.

Source: `UI/Wizard.lua:1083`, `Locales/enUS.lua`, WIZARD_RECOVERY_SPAN_BODY.
Correction: Companion should lead with Span WoW Now followed by Reload UI;
FancyZones/manual should lead with Return to window setup and placement
confirmation. Unknown methods should lead to method selection. Preserve the
explicit user confirmation for manual/ultrawide arrangements and never claim
automatic monitor detection in that path.

### A04, P2: Ordinary calibration interruption loses the current step

Confirmed source and harness behavior: open calibration, navigate to step 3,
close it, reopen the wizard; it starts at step 1. Values remain saved, so this
is loss of navigation progress, not loss of the user's calibration data.
The special recovery reload and All Settings return retain a step; ordinary
close/reopen or interruption does not consistently do so. A new user can think
the previous work failed, or repeatedly apply the recommendation again.

Source: `UI/Wizard.lua:1416`, `UI/Wizard.lua:1480`, `UI/Wizard.lua:1502`.
Correction: persist the last incomplete calibration task with clear Continue
setup and Restart calibration semantics. Completed users who deliberately rerun
calibration should retain an intentional restart option. Revalidate geometry
before resuming; do not equate a stored step with successful setup.

### A05, P2: Public instructions and the current guide describe different orders

Confirmed on public pages, not just local source. The in-game setup page assumes
the window was already placed, while the current guide starts with method
selection, software preparation and Set to Windowed. It names Remember Current
Window instead of walking through Confirm placement and the confirmation dialog.
The Companion page directs the user through graphics settings first and describes
reloading from the ambiguous "character UI" state rather than clearly entering
the game world before spanning and reloading. Those passages can make a reader
skip the action-led guide and the important reload handoff.

Source: `Website/in-game-setup.html:35`, `:45`, `:46`;
`Website/companion.html:79`, `:83`, and the corresponding public pages.
Correction: align the written steps, screenshots, button labels, recording script
and in-game flow. Show Set to Windowed as the main supported route with manual
graphics settings as fallback. Keep placement, geometry loading and calibration
visibly separate. Explain the manual confirmation dialog after Confirm placement.

### A06, P3: CurseForge description still identifies Beta 22

The public page's main download is Beta 23, but its description heading and
release summary still say Beta 22. The YouTube embed is absent from the current
description, consistent with moving the video to the featured gallery.

Correction: update the description's version context or remove the easily stale
release-specific banner. Explain the new setup workflow without advertising
unreleased draft #41 recovery controls as already available. Preserve the featured
video and existing tour/website links.

## Improvements and live questions, not established defects

### A07, P3: Completion is predominantly a chat message and reload prompt

The source marks setup complete after layout creation and emits chat status,
readiness and cold-start advice. There is no equivalent final action screen that
walks a beginner through moving the map/bags and verifying the saved arrangement.
The guide offers handoff guidance, so this is a design improvement rather than
evidence that panel movement is broken.

Consider a brief completion card with Arrange your panels, Test after relaunch,
Reopen setup and Done. Do not make a user repeat calibration or present a failed
HUD generation as complete. Measure actual use before adding more mandatory steps.

### A08, P3: New recovery text is English fallback in other locales

All 11 dictionaries contain matching keys and placeholders, but the new recovery
paragraphs are explicitly English fallback in non-English dictionaries. Key
completeness is not translation completeness. Prioritize real translations and
live text/scale checks as the release approaches. This need not block an English
recording once the behavior is verified.

### Live matrix still required

Verify native Edit Mode entry/exit and locked entry, no available custom-layout
capacity, combat interruptions, failed/successful Companion reload, cold relaunch,
and small/large UI scales. Use default keyboard UI plus the relevant supported
controller/client variants. Never delete a valued layout to manufacture a test.
Inspect fresh Lua/taint evidence; headless tests cannot establish protected-action
safety. The unavailable release Forever client remains deferred as instructed.

## Recommended order

1. Correct A01 and add visibility assertions before merging PR #41.
2. Address A02 and A03 with action-led messages for each recovery state/method.
3. Implement intentional incomplete-task resume for A04.
4. Align website and CurseForge wording (A05/A06), staged locally before publishing.
5. Run the live acceptance matrix, then record the installation walkthrough against
   the exact candidate that will be distributed. Use that footage to capture the
   final screenshots; avoid recording obsolete labels or navigation.

Audit outcome: the two Discord blockers have draft recovery implementations, but
the surrounding navigation and guidance still need the corrections above. The
audit does not justify merging or publishing the draft automatically.
