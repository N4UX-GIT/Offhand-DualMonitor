# Help alignment with website and dashboard redesign

Source candidate based on codex/companion-dashboard-actions at 8c6e089. Carries
forward the earlier single-method help and guarded custom-entry work from draft
PR 92, then aligns it with the revised website flow. It supersedes that older
source proposal without rebasing or rewriting its remote history.

## Changes

- Companion Help uses the same five first-time tasks as the website, then
  calibration, next-launch verification, optional layouts and symptom recovery.
- Top-level Span/Restore, Configuration, default-collapsed System Status,
  Diagnostics/Activity Log, Show controls and tray monitoring match the redesign.
  File installation is distinguished from enabling Offhand inside WoW.
- In-game placement text references those controls. Expanded help contains
  correction advice rather than repeating the normal placement instructions.
- Calibration step 1 reviews the already-placed window rather than instructing
  another backup, Windowed-mode change or placement-method switch.
- Handbook order is setup, placement reference, panel arrangement, relaunch,
  optional HUD reference, recovery and guide-resume reference. Rebuilding a HUD
  is not presented as a required second pass after successful wizard creation.
- Seven further locale keys change. EFIGS are authored; other locales retain
  explicit English fallback for the revised paragraphs. Previous localized
  single-method keys and existing format/color contracts are preserved.

Shared KB README/research routing and status were consulted. Its generic query
returned no current-source evidence, and Blizzard snapshots are review-due.
Current Onboarding/Wizard/Options, localized strings and the dashboard source
are the authority for these copy changes. No new WoW API decision is introduced.

## Validation and limits

109 Lua suites pass, including EFIGS/locale coverage. Generic validation passes
six manifests, 74 Lua files and one XML file. Native preference and Help/DPI
checks pass at 100, 125, 150, 175 and 200 percent. Workspace UX passes 117 checks
on each architecture, including standard default and guarded custom entry.
Historical artifact/source-drift safeguards pass. Re-run after integration if
other source changes intervene.

No new native binary, Store package, addon release or installed client files are
published here. Live text wrapping, game behavior, taint and cold-launch evidence
remain unverified for this candidate. Existing dashboard release receipts cover
their original bytes, not the edited Help source.

## Replacement capture checklist

Do not retouch old screenshots to appear current. Capture after this source is
integrated into the next tested build, using one client and consistent UI scale.
Avoid account/chat details; keep the complete dialog and its navigation buttons.

First-time guide: welcome, choose one method, Windowed mode, Companion placement,
and calibration handoff. The placement capture must show the revised standard
layout/top-action instructions and Confirm placement wording.

Calibration wizard: display detection/recommendation, Mainhand orientation,
physical seam, UI size and Mainhand HUD creation. Include the reload prompt if
its wording changed. Geometry controls may correctly be locked with Companion.
Clients without Edit Mode have a different final step; EllesmereUI may offer an
additional transfer step. Label those as client-specific rather than universal.

The dashboard image on the website already shows the redesigned native window.
First-time and calibration galleries remain explicitly labelled reference
captures until fresh in-game captures are supplied. Replace each entire set
coherently after live verification; do not claim old pixels show the new copy.
