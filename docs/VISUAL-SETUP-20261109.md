# Visual guide and wizard candidate, 2026-11-09

Status: private Test 8 packaged and installed, with scoped native observations.
Final copy/layout review and the broader native matrix remain pending. Not published.
See [live QA and current evidence](GUIDE-WIZARD-LIVE-QA-20261109.md).
Native Companion artifacts and existing independent bug investigations are intact.

## Presentation

- Setup primary actions use a gold outline, readable light text and direction
  arrow, with a stronger tint on hover. Progress markers use a subdued dark tint
  and shadow-free text. Slate secondary and disabled actions remain distinct.
- Guide content sits in a charcoal task card with a numbered progress rail.
  The established saved page IDs and Position -> Reload -> Review guards remain.
- Calibration also has a compact rail. Discovery recommends Apply recommendations;
  later steps recommend their existing Next/Finish/recovery action. Existing
  measured Next caption and optional/recovery controls remain available.
- Windowed mode illustrates the title-bar distinction. Placement draws Mainhand
  and Offhand regions, including stacked layouts, offsets and empty space. Seam
  calibration marks only a shared edge. UI scale has sample text inheriting the
  real UI scale. HUD artwork compares illustrative misplacement with the goal.
- Diagrams say Example layout when the geometry is absent, unspanned, overlapping,
  secret-sensitive, transitioning or stale. Configured regions is not a claim of
  physical monitor detection, and HUD goals are not a measured before/after.
- Artwork uses pooled addon-owned frames and localized text, not English text
  baked into screenshots. No image generation, vendor artwork editing, network
  image loading, native frame hooks, recurring timers or new binding overrides.
- All 11 locale dictionaries include the task/illustration labels. Paragraphs,
  action rows, footers, progress and illustrations contribute to dialog fitting.

## Website parity

Website/in-game-setup.html includes an accessible, responsive task-card preview
with an inline monitor diagram, clear primary action and locked review example.
It is explicitly labelled as a source-candidate illustration, not a released-build
capture. Existing screenshots remain older-version references. Companion/manual
pages link to the new sequence while distinguishing the released flow. Changes
are local source only, with no hosting deployment or release metadata change.

## Validation

- The latest revision has 104 root and 111 combined-package Lua suites passing.
  The original 103-suite visual pass included diagram geometry cases for stacked,
  unequal, negative-origin, unverified/secret and void layouts. Existing guide
  guards and modal races still pass.
- Actual UI fixtures exercise all 11 dictionaries and bounded layout. Fifty
  repeated guide/wizard layout passes retain stable frame counts and heights.
- All six manifests pass runtime paths, XML references and Lua 5.1 syntax.
- Website integrity passes for six pages and 297 local references.
- IAB browser review at desktop default width 1280 and mobile width 390 found
  no horizontal overflow. The task hierarchy, illustration, stacked mobile
  actions and readable disabled action were visually inspected. The temporary
  viewport override was reset. This browser review does not establish WoW rendering.
- Evidence: dist/visual-setup-20261109/suite-results.json and mobile-preview.jpg.
  Browser screenshot export returned the mobile capture for both output requests;
  the second copy is accurately labelled mobile-preview-secondary.jpg. Desktop
  visual evidence remains in this chat's browser trace, not a claimed saved image.

Shared KB was consulted first. Cached Forever evidence is review-due; the query
provided supporting geometry/ownership guidance, not native acceptance. Target
reference remains Forever 1.60.1.70862 plus shared manifests for other clients.

Next native matrix: both monitors and stacked layouts, each guide substep through
real reload and cancellation, calibration at supported UI scales, translated
paragraph/legend/arrow wrapping, actual mouse and controller focus, disabled
combat actions, and recovery screens. Preserve the public Beta 27 WorkspaceRegions
integration when promoting this older checkout. Re-capture actual client screens
only after native acceptance, then replace website's earlier-version references.
