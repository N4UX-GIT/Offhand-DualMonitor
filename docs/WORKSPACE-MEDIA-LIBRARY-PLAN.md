# Optional workspace background library

4 November 2026. Implemented for the updated unofficial workspace test package.
The single-image workflow remains schema 2. Adding a second background creates
a code-free schema 3 library, limited to two images sharing a 2,097,152 texture
pixel budget. The published website has not been deployed with this change.
The test package includes a self-contained offline Studio HTML file.

## Player workflow

Keep one shared image as the default. Studio remains an editor for one selected
image at a time. An optional Add background action opens a small library,
initially limited to two images for the two supported workspace regions. Export
one User Media package. Preview the selected image against each region's shape.
No account, upload, image persistence service or Companion image editor is needed.

The addon's Themes page chooses inherit, theme only, or an installed library
image for each region. Fit remains independent. Named workspace layouts retain
image assignments. The ordinary shared-image path should need no extra steps.
The feature styles workspace canvases; individual Blizzard panels are outside
its scope.

## Compatibility and implementation boundaries

Preserve schema 2 single-image packages and their fixed Background.tga consumer.
Introduce a separately validated declarative schema for a bounded library. Keep
stable asset IDs separate from fixed, allowlisted texture filenames. Store IDs
in region appearance records, not arbitrary filesystem paths. Missing images
fall back to the region theme while retaining the assignment for recovery.

Package import still validates and regenerates locally. Exported media contains
no Lua or executable code. Existing aggregate byte/pixel limits remain hard
constraints; normalization must budget the entire package rather than multiplying
limits per image. Declared dimensions, texture padding, presentation settings,
filenames, asset counts and duplicate IDs need explicit validation. Older addons
must reject the new schema and fall back safely.

Replacing, removing or reopening a package must preserve asset identities where
appropriate. A missing ID must not silently select a different image. Old
workspace snapshots retain the existing global media compatibility contract.
No Companion topology, display planner or fullscreen protocol change is needed.

## Acceptance before shipping

- One-image creation/import/export remains simple and byte/schema compatible.
- Two-image export/import preserves identity, edge crop focus and per-image fit.
- Aggregate size limits and path/manifest validation cover malformed packages.
- Different aspect-ratio regions render independent textures without bleeding
  into free desktop or one another; fallback restores the correct theme fill.
- Named profiles retain image/fit choices through switching and reload.
- Verify a generated package in supported native clients and inspect fresh errors.
- Browser visual/export interaction and physical multi-region acceptance must be
  distinguished from the existing 96 website-to-Lua geometry comparisons.

Source reference: Core/UserMedia.lua and Website/background-studio-core.mjs at
651321d define the current schema 2 contract. The shared KB media query had no
exact integration record; this plan follows that local contract and does not
infer API support or taint safety from retrieval.

## Implementation and current evidence

Schema 3 carries one or two stable IDs and names in a JSON recipe and numbered
TOC metadata fields. Only Background.tga and Background2.tga can be rendered.
The addon never loads media Lua. The importer checks file/manifest parity,
dimensions, duplicate IDs, presentation bounds and the aggregate pixel budget
before regenerating a clean package. Existing byte, entry and CRC limits remain.
Removing an image retains the surviving ID even when its numbered file changes;
the package remains schema 3. Failed import leaves the existing editor intact.

Themes offers global inheritance, theme only, shared image, or an installed
image by name for each region. Assignments live in workspaceRegionThemes and
are included in named layout snapshots. Missing IDs retain their saved value
and restore the region theme fill. Global image preferences are unaffected.

All 90 Lua suites, six manifests and Lua 5.1 syntax checks pass.
The four Studio suites cover core safety, 96 website-to-Lua geometry comparisons,
two-image TOC-to-Lua rendering/profile/fallback checks, and simulated editor
events through exact offline download bytes. The offline file embeds reviewed
source and styles, has no external code dependencies, uses a script hash CSP
and blocks script network connections. Simulation does not establish visual
browser acceptance. The browser tool rejected local-file access; no alternate
browser route was used to bypass that restriction.

Retail 12.1.5.70783 discovered both images, visibly rendered the warm landscape
and cool portrait fixtures in the real 480x600 workspace, retained the cool
assignment through reload, and recorded schema 2 spanned topology. The first
fresh error comparison retained all 13 historical records unchanged. Final
cleanup and follow-up acceptance are recorded in the Test 2 QA document.

Two independent renderer canvases pass simulation. Simultaneous physical
two-workspace rendering requires three monitors: each workspace and the game
must use a different display. This two-monitor machine cannot accept that
hardware case. Mixed DPI, physical hotplug, combat/protected actions and a
fresh Anniversary library run remain unverified.
