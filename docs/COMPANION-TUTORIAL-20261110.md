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
