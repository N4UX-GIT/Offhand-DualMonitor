# Installation walkthrough recording sequence

Record against the final tested addon candidate and Companion Beta 20. Do not
advertise draft controls as part of the published Beta 23 until they are released.
Use the exact on-screen labels if a supported client presents a different path.
The complete v23 CurseForge description supplied on 27 October deliberately
describes published behavior, not the additional recovery changes in PR #41.

## Preparation

Back up existing settings and use a dedicated clean test setup. Do not delete
valuable HUD layouts. Begin in Windowed (Fullscreen) so the Windowed action is
visible. Disable diagnostic overlays and notifications, hide private chat and
capture the cursor and both displays. Keep auto-span off during initial setup.
Record continuously and trim waits afterwards. Pause before clicks and hold the
result for a few seconds. Do not skip a required action through an unexplained cut.

## Main Companion path

| Shot | Action | Caption |
| --- | --- | --- |
| Result preview | Record the completed layout separately after setup | Set up Offhand across two monitors |
| Install addon | With WoW closed, select the intended WoW installation in CurseForge and install Offhand | Install Offhand for your WoW client |
| Install Companion | Follow the official website's Microsoft Store link, install and open Companion | This walkthrough uses Companion |
| Enter world | Launch WoW and log into a character; trim account selection/loading | Enter the game world |
| Choose method | Welcome guide or /offhand guide; Start setup, Use Companion, Already installed | Choose Companion |
| Windowed | Set to Windowed; show the movable window/title bar; continue with Place WoW | Click Set to Windowed |
| Displays | In Companion, Identify Displays, select the intended screens and Mainhand (game) | Select your screens and Mainhand |
| Span | In the game world, Span WoW Now; show both screens and disappearance of the title bar | Click Span WoW Now |
| Geometry | Return to WoW; Reload UI, then Confirm placement | Reload UI, then confirm placement |
| Calibration | Start Calibration; apply recommendation and review Mainhand, seam and UI size | Check Mainhand, seam and UI size |
| HUD | Outside combat with Edit Mode closed, Create Mainhand HUD Layout; reload when prompted | Create your Mainhand HUD layout |
| Panels | Move supported map, Character and bags to Offhand using their controls | Arrange your Offhand workspace |
| Persistence | Normal exit, relaunch, enter world and reapply the span; show the returned layout | Check your saved layout |
| Ending | Hold a clean result for five seconds | Setup complete. offhand-wow.onrender.com |

If Windowed mode is already selected, use Place WoW. If automatic selection is
unavailable, show Open display settings and the client's ordinary Windowed choice.
Do not imply that maximizing a single monitor performs the span.

## Separate recovery inserts

These are optional troubleshooting clips rather than mandatory detours in the
main install video. Record them only after the relevant draft behavior is tested.

- Missing Companion geometry: show Reload UI restoring the current task. Also
  verify that a reload without a span remains actionable instead of completing.
- FancyZones/manual: show Return to window setup, actual placement, Confirm
  placement and Remember Window. Reload is not presented as window placement.
- Full native layout list: show the native Edit Mode dropdown using unwanted test
  layouts only. Export if wanted, delete one unwanted layout, close Edit Mode,
  then deliberately retry HUD creation after Offhand resumes the final step.
- Interruption: close/reopen at calibration step 3 and show the saved task return.
  Restart calibration reviews from step 1 without resetting existing values.

Use short captions first. Narration can be added after the actual footage is
reviewed. Fresh native screenshots should come from the same tested build; the
existing website example images are not evidence of the new recovery controls.
