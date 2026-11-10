# Companion first-run tutorial

Date: 2026-11-10. Unpublished local UI Preview 6, file 2.1.5.8006. Production versions, submitted packages and addon source remain unchanged.

## User experience

The persistent Span/Restore captions and Apply your layout instructions card are removed. Setup now presents its controls without the repeated explanation. The subtle tab borders and selected underline remain.

On the first launch without CompanionTutorialSeen=True, a guided walkthrough highlights the actual interface and explains its controls. Next and Back navigate; Skip tour and Escape dismiss it. Finish closes the final step. Dismissal/completion saves only the tutorial-seen flag, so the introduction does not recur at every launch. Existing users see it once when they first encounter this UI; it never resets their preferences. Help has a Start Companion tutorial button that replays it regardless of the flag.

Sixteen steps cover header/community links, display selection and Identify Displays, Mainhand, single-display split/Game side, Span, Restore, status, Advanced navigation, custom layouts/standard reset, named profiles, Auto-span/delay, diagnostics, activity log, updates, tray/exit and in-game calibration/Help replay. Active-custom-layout copy explains why ordinary controls are locked. The final step distinguishes this interface tour from the required in-game setup and names /offhand guide, Companion, Reload UI, Confirm placement, Start Calibration and applicable HUD-layout/reload prompts.

The tour only navigates pages and disclosure state. It does not invoke Span, Restore, display identification overlays, update checks, external links, profile loading, layout saving or game commands. Background UI polling is suspended, underlying controls/tray actions are disabled, and only tour navigation remains interactive. The former page, panel disclosure state, scroll and focus are restored on exit. A darkened rendering of the Companion window isolates the highlighted target; no external screenshots, game capture, global input hook or overlay on the game is used. Highlight geometry follows the Companion's own control bounds and scroll offset. An unavailable tutorial rendering restores the normal interface and logs a replay hint.

## Evidence

Shared knowledge status/search and the existing Companion branding/guidance finding were consulted. The tutorial lookup did not supply a Companion tutorial implementation; current native source and explicit tests govern this design. Existing current addon source and the prior scoped Forever guide evidence remain the basis for in-game instruction wording. No new game API behavior or fresh in-game calibration acceptance is claimed.

Native preference/layout tests pass at 100%-200% scaling and enlarged-child/minimum-width cases. All sixteen steps are exercised for target visibility, card/child containment, wrapped text, action coverage, Next/Back state, settings immutability, cancellation restoration, skip/completion persistence, replay and returning to the former Advanced page. Tests reject reintroduced captions/instructions, and confirm Help replay. Store update-service fixtures pass 472 assertions across production/preview x64/x86 variants without Store availability queries. Workspace UX passes 111 assertions on each architecture. Frozen 2.1.5 publication checks pass.

Native preview review, source identity and local package receipt are recorded after building below. The preview uses isolated settings and disables automatic spanning/recovery/update checks; manual actions remain available outside the tutorial for the owner's intentional review.

## Native review and local package

The initial native review caught a duplicated title bar in the backdrop because Form.DrawToBitmap included non-client decoration. The final renderer composes only the Companion viewport and footer. A regression assertion checks that the backdrop begins with client background rather than native title-bar pixels. Highlight coordinates also use the managed control ancestry and scroll offset, avoiding native-handle positioning differences in scaled/unshown fixtures.

Final source commit: `b025ed4`. Local output: ignored `dist/companion-tutorial-preview-6b-20261110`. The native interaction boundary audit passed with four source files and 45 reviewed declarations. Computer Use observed automatic first-run startup, accurate header/display-control highlighting, Next, Back, Escape dismissal, the clean normal Setup view, the Help replay button, and successful replay to step 1. The final preview remains open on that first step for owner review. All-step completion, scale extremes and former-page restoration are covered by the native fixture matrix; they are not claimed as a complete manual walkthrough or fresh game calibration run.

Screenshots `tutorial-welcome.png`, `tutorial-displays.png` and `setup.png` are beside the executable. Actual review used one 2560x1440 display. No Span, Restore, external link/update activation, game input or addon file installation was performed. Installed portable/Store preference hashes remained unchanged. The builder verified frozen published artifacts before and after compilation.

The local ZIP contains exactly LICENSE, Offhand.exe and README.txt; its executable matches the reviewed build. It excludes preview preferences, so extraction begins with the first-run tutorial. EXE SHA256: `2BE65DC790F28B05A0014D17DFAF1E6C5F5260BF81BFAFD846D8AA9F34141A18`. ZIP SHA256: `065DD88BBF35DED7C2FB315186F9FFE13B2F578BC93BF1DA26F82F55BDA80697`. No Store/GitHub publication or production/addon version change.

## UI Preview 7 alignment refinement

The owner requested better balance and centered tabs. The former 40/60 navigation columns and 64/36 action columns are replaced with a shared 50/50 grid. Both rows now use the same centered gap and outer edges; Setup and Advanced have equal widths, heights, fonts and subtle borders. Span and Restore also have equal widths. Span retains its gold outline and bold type as the primary action, while Restore remains quieter. No captions or permanent guidance are reintroduced; the replayable tutorial is unchanged.

Layout assertions check both rows' shared edges, centers, widths, spacing and tab font weight, as well as the existing custom-state text fit, tutorial lifecycle and scale/width matrix. This is unpublished UI Preview 7, file 2.1.5.8007. No geometry/runtime behavior or release metadata is changed.
