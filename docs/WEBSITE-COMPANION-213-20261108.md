# Companion 2.1.3 website guidance

8 November 2026. Website-only update from main 6be1da7. Runtime, packages,
Store metadata and addon Help text are outside this change.

## Evidence and release boundary

The owner confirmed Store publication. Read-only installed package inspection
found N4UX.OffhandCompanion 2.1.300.0, product 2.1.3, file 2.1.3.9 and EXE SHA-256
88916B6FBAA4FF2E81EC574F8FA248C553ED531AD7A3DC828FF4948568797443.
This matches Companion/Prepared/2.1.3/release.json on
codex/workspace-current-addon-test, source checkpoint 56b247a, frozen native
source revision d2934ef802cf0c8deb62d29fd0c932658e64afa3.

Read the matching release notes, FillSetupHelp in Program.cs, WorkspaceEditorLayout,
FlexibleWorkspaceEditor.cs and CUSTOM-WORKSPACE-PROFILES.md. Older candidate
documents are historical; their unpublished labels do not override the owner's
Store publication confirmation or installed exact-byte identity.

GitHub REST inspection found both new Companion/addon releases still drafts.
The paired addon is 2.1.3 Pre-Release Beta 27, not a stable addon. Public copy
explicitly distinguishes Store availability, addon requirement and the older
portable Beta 20 download. No draft/private download URL is placed on the site.
Recheck and replace the availability callouts when the packages are published.
Do not publish the packages as part of a website-only task.

Shared knowledge README/research routing, status and workspace search consulted.
The corpus includes prior source/native prototype evidence and is review-due for
Blizzard sources. No new WoW API, native rendering, combat or client-support claim
is inferred from this documentation change. No game was launched or controlled.

## Content ownership

- companion.html: Store/update channel, standard setup, everyday controls,
  display diagnostics and links to the custom guide.
- custom-workspaces.html: mode selection, one shared save/apply/reload sequence,
  named plans, profile comparison, panel routing/appearance and custom recovery.
- in-game-setup.html: retain calibration/HUD and targeted recovery instructions;
  link to custom guidance without repeating editor instructions.
- background-studio.html: explain region dimensions and link back to appearance.
  No unpublished media-library implementation is copied from another branch.
- index.html: recommend Store Companion and link to the workspace guide.
  Remove obsolete Beta 20 dashboard imagery from the new Companion presentation.

No new primary navigation entry, duplicate wizard gallery or fabricated UI image.
Existing older addon reference captures remain explicitly version-qualified.
Flexible layout retains its actual prototype label. Custom layouts remain manual
Span WoW Now workflows; saving/loading a plan alone does not move WoW.

## Screenshots requested from the owner

Use the Store 2.1.3 UI and matching addon Beta 27. Send original PNGs at normal
readable UI scale. Keep control labels, preview and footer visible. Include the
WoW client/build and UI scale with in-game captures. Avoid private chat/account
data and crop unused desktop voids; do not crop useful game/workspace regions.

Priority set:

1. Dashboard: version, System Status, Span displays/Mainhand, Workspace layout,
   Workspace profiles, Span WoW Now and Restore Window. If it scrolls, two
   overlapping captures are better than shrinking text.
2. Workspace layout chooser with all modes and the standard-layout return choice
   visible where available.
3. One monitor editor with a valid unequal split, labelled areas and Save plan.
4. Two monitors editor with a partial secondary region; include its preview.
   Also capture the visual area selector with its resize edges visible.
5. Multiple workspaces editor with A/B and primary workspace selection, using
   actual connected hardware. Do not imply physical three-monitor acceptance
   from a two-monitor or simulated example.
6. Flexible layout editor with a valid preset and all rectangle labels/preview.
7. Workspace profiles dialog with two named plans and load/save controls visible.
8. In-game Profiles with separate general/workspace sections, Workspace routing
   destinations, and Themes region overrides. These can be three images.
9. One completed real custom layout with Mainhand/workspace designation visible.
   Capture only occupied WoW regions, excluding desktop voids.
10. Display Diagnostics expanded and Display Troubleshooting dialog, two captures
    if needed. Redact private paths from any support text.

Optional: saved-display confirmation, standard-layout return review, and missing
display message encountered naturally. No need to disconnect hardware or disturb
a working layout solely to obtain an error screenshot. Existing setup/HUD images
can stay where the wording still matches. Place new images beside their owning
instructions, in optional full-size-linked galleries, rather than repeating them.

## Verification

Run node tests/website-integrity.mjs and git diff --check. Review standard setup,
custom mode cards and the profile comparison at desktop and 390px viewport.
Confirm no page-wide horizontal overflow and keyboard-accessible details/table
scrolling. Verify deployed HTML/CSS bytes after the website PR merges to main.
Screenshot completion remains pending owner-supplied captures; the text guide
works independently and uses no empty image placeholders.
