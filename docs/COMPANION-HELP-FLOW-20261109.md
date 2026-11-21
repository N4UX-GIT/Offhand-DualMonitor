# Companion help for the next release

Source-only update based on released main `9471052`. The installed Store help
was observed to omit Window is positioned during the website capture session.
This change updates `FillSetupHelp` for the next Companion build. Existing EXE,
portable archive, Store packages, versions and installed preferences stay intact.

The help now follows the website and current in-game guide:

1. Choose one method. These instructions use Companion; FancyZones and manual
   placement are alternatives, not additional setup tasks.
2. Follow the five dashboard/setup tasks. Standard layout starts selected for
   new setups, with no custom editor required for two full monitors. Confirm
   saved displays in the Span task rather than a separate repeated recipe.
3. Return to the same guide: Window is positioned, Reload UI, Confirm placement,
   review the result, then Start Calibration.
4. Follow Detection, Placement, Seam, Scale and the client-appropriate HUD or
   Finish Setup action. Explain Use Companion layout, automatic geometry, the
   text preview and arranging panels after completion.
5. Check a later launch before enabling optional auto-span. Daily controls,
   optional custom workspaces and symptom-based recovery follow completion.

Custom editor names describe the area they use. Saved custom plans survive
reopening and updating Companion. Switching back to standard appears in
recovery, alongside the distinction between Restore Window and a saved layout
change. Recover Missing UI comes before broader gather/rebuild actions.

Validation: existing Companion preferences/layout checks pass, including help
scrolling, heading/body styling and pinned footer at 100%, 125%, 150%, 175% and
200% scale. The existing help fixture checks journey order and method choice.
Workspace UX regression checks pass on x64 and x86 (108 checks each).
No runtime topology, window operation or settings behavior changed. Review
the help in the next packaged candidate before promotion; this source-only
change does not claim a new installed-Store or in-game runtime acceptance pass.

CI now invokes the existing historical-artifact validation mode for the frozen
2.1.5 receipt, EXE and archive, matching its treatment of 2.1.3. The publication
fixture forwards that option and verifies it cannot create packages. Default
publication validation remains strict about source drift; this help change
requires a new reviewed candidate before it can ship.

Evidence: current `Website/companion.html`, `Website/in-game-setup.html`,
`UI/Onboarding.lua`, `UI/Wizard.lua`, English locale labels and the live capture
record in `WEBSITE-LIVE-CAPTURES-20261109.md`. Shared knowledge status and setup
search were requested; Blizzard snapshots are review-due and search reports a
stale index. Current source and the recorded Forever 1.60.1 (70862) UI remain
authoritative for this wording. No new WoW API decision is involved.
