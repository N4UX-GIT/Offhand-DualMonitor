# Optional workspace background library

4 November 2026. Planned enhancement after the Companion UX pass. The current
implementation continues to reuse one installed image independently per region.
This document does not claim multi-image support in an existing package.

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
