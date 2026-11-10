# Companion Advanced options UI review

Date: 2026-11-10. Unpublished local preview, product 2.1.5, file 2.1.5.8002.

The original collapsed-card design below is historical evidence for UI Preview 2. The approved follow-up replaces it with Setup and Advanced navigation in UI Preview 3, file 2.1.5.8003. Neither preview is a public release.

## Behavior

- Configuration retains Span displays, Mainhand (game), Identify Displays, the ordinary single-display split and Game side.
- Advanced options starts collapsed. It contains Workspace layout, Workspace profiles, Auto-span WoW on launch, its delay, and Use standard display layout.
- The Advanced options heading includes Custom layout active when a custom plan is saved, including while collapsed. Custom settings remain effective until explicitly changed.
- Use standard display layout reuses the existing reviewed, validated save transaction. It preserves named profiles and only changes saved settings. Span WoW Now applies the saved layout; the user then reloads the WoW UI.
- New two-monitor custom drafts start at the workspace monitor's full bounds, with zero offsets. Existing saved custom rectangles remain intact. Opening an editor does not commit its draft.
- Auto-span stays off by default. Existing saved preferences and the production restrictions for custom layouts and remote sessions are retained. Show/Hide changes disclosure state only.
- Help and actionable status messages identify Advanced options as the route to custom layouts.

## Validation

- Dashboard layout and preferences: passed at 100%, 125%, 150%, 175% and 200% scaling, including enlarged child controls, minimum width, work-area fitting, and stable bounds through section toggles.
- Workspace UX: 111 assertions passed for each x64 and x86 test executable, including full-monitor initial secondary area, draft isolation and saved-area preservation.
- Partial topology suite: passed, including ultrawide geometry, clipping, persistence and standard-layout switching.
- Store update service: 472 assertions passed across production/preview and x64/x86 variants, without real Store availability requests.
- Persistence: 25 portable checks passed.
- Frozen 2.1.5 publication checks: passed in historical-artifact mode. Current development source is rejected as the original submitted source. CI now uses historical mode for this frozen release, matching the existing 2.1.3 pattern.

## Local build isolation

The preview uses its own mutex and DashboardPreviewConfig.ini beside its executable. It does not import installed Companion preferences. Automatic spanning, graphics recovery and automatic Store update checks are disabled in the preview. Manual Span and Restore remain available for the owner's intentional testing.

Published Companion artifacts, production version metadata, the Store submission, and the Beta 28 addon remain unchanged. No live WoW testing is necessary for the dashboard grouping changes; no game interaction is part of this review.

## Knowledge evidence

Consulted the shared knowledge README, research skill, status, and the existing authored dashboard-actions finding. The shared search index was stale, so the attempted dashboard search failed. Current Companion source and the native test results above are authoritative for this change; no new game API or safety claims are made.

Native preview review and artifact hashes are recorded after the build in the local preview receipt and follow-up evidence below.

## Built and reviewed

Built from commit `ba3d998147afe9957e2a969fefc2efc0c0992f16` into ignored `dist/companion-advanced-options-preview-1-20261110`. The native interaction audit passed for four source files and 45 reviewed declarations, with restricted process/input symbols absent.

Computer Use verified the running UI Preview 2 window, default collapsed Advanced options, expanded tool grouping, disabled preview auto-span and disabled standard-layout reset in standard state. Screenshots of both states were saved beside the executable. The window was returned to the default collapsed view and left running for owner review. The local machine exposed one 2560x1440 display, so two-monitor defaults were verified with native synthetic display fixtures rather than physical dual-monitor QA. No Span/Restore or game input was performed. Captures establish the settled layout; they do not prove absence of subsecond animation artifacts.

Installed portable/Store preference files were hash-compared before and after and remained unchanged (including absent paths). The preview builder verified unchanged public Beta 20 and prepared 2.1.5 artifacts. Prepared 2.1.5 EXE/ZIP hashes also match the frozen release records.

- Preview EXE SHA256: `A0E6025059C8A40A2ACA6D03D10FCC6B166ACBD61E6896923F6B27CF87DC2AB3`.
- Preview ZIP SHA256: `A17FCF16F36C18CEB8CB55126C417D017A0A1501BB1641654F20248CEC7176B9`.
- ZIP entries are exactly `LICENSE`, `Offhand.exe`, `README.txt`; the embedded EXE hash matches. No user preferences are included.

## Setup and Advanced tabs follow-up

- Two themed navigation buttons below the header act as Setup and Advanced tabs. Setup opens on every launch; changing pages does not persist or alter the chosen layout.
- Header, Span/Restore actions and their guidance, System Status and footer actions are shared. The Advanced tab says Custom layout active when appropriate, including while Setup is selected.
- Setup contains ordinary display controls and a measured, wrapping Apply your layout guide. Instructions adapt to a two-monitor standard plan, the ordinary single-display split, or an active custom plan. They explain Windowed mode, Span WoW Now, `/reload`, and completing `/offhand` setup for first-time users. Custom instructions identify the standard-layout reset action.
- Advanced contains workspace layouts, named profiles, standard-layout reset, Auto-span/delay, and the existing collapsible Display Diagnostics and Activity Log cards. Configuration and Workspace and Startup cards are always expanded within their page. Prior saved collapse keys are retained but no longer control these two cards.
- Tab selection uses the same gold/dark styles as the existing interface. Tab buttons expose navigation names and selection descriptions; Left/Right and Home/End switch pages. No new window-management or addon behavior is introduced.
- Updated Help and actionable messages use the Advanced tab location.

Validation rerun for this follow-up: preference/layout checks pass at 100%-200% scaling, enlarged native children and minimum width. Repeated page changes and Show/Hide produce no outer size/location changes, content-width changes or late log handle creation. Tests cover isolated page contents, shared actions, tab text and selected-state descriptions, wrapped guidance, custom state/reset instructions and preservation of saved settings. Workspace UX passes 111 checks per architecture. Store update tests pass 472 checks across production/preview and x64/x86 variants, without real Store queries. Historical 2.1.5 EXE/ZIP/receipt and source-drift rejection checks pass.

The shared knowledge index was stale again at the start of this follow-up. The existing authored Advanced options finding was read directly; current source and native test evidence govern this native-only UI change.
