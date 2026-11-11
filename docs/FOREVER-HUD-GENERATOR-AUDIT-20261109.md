# Forever HUD generator geometry audit

The 50/50 report exposed shared generator defects. Reproduction covers seven
Forever keyboard span arrangements at three bar scales, with and without
EllesmereUI. This is a source and simulation audit for Forever 1.60.1.70862
and installed EllesmereUI 9.8.2. It does not establish native visual or combat
acceptance for every layout.

## Saved-layout evidence

The local display bridge describes a 2560 by 1440 window split into equal
1280 by 1440 regions. Its saved HUD geometry is approximately 3142.86 by
1767.86 UIParent units, with Mainhand from x 1571.43 to 3142.86. That conversion
and the ordinary center-anchor shift are consistent.

The native character cache contains identical explicit RIGHT anchors for the
two right action bars. Their default-position flags are cleared. The previous
cache retains identical anchors with default flags set. Those flags matter
because Blizzard separates default right bars through its layout manager.
Cache inspection is read-only. No account data or layouts were reset.

## Reproduced defects and corrections

1. Generation translated the two right bars' placeholder anchors and cleared
   their default flags. Both then had the same explicit destination. The
   generator now gives default native right bars distinct columns using their
   effective dimensions and the Mainhand rectangle.
2. TransformLayout shifted explicit custom UIParent positions. It now preserves
   entries with isInDefaultPosition false, matching the existing setup contract.
3. TransformLayout updated anchorInfo but omitted anchorInfo2. Both UIParent
   anchors of a default stretched frame are now transformed.
4. EllesmereUI Copy projected unchanged source placeholders independently.
   Its read-only plan now uses the native generator's transformation and
   refinement helpers. It retains existing generated edits and adapts the
   projected right-bar columns to the replacement frames' actual sizes.
   The known MicroMenuContainer dependency resolves through its serialized
   anchor when available, avoiding dependence on a stale live screen position.

Actual externally owned native rows retain their ownership policy. The
replacement plan is a copy. It does not write the source, select a native
layout, import a profile or modify frames during preview.

## Scope of the reproduction

| Arrangement | Native right-bar overlap before | Custom position moved before | Second anchor wrong before |
| --- | --- | --- | --- |
| 50/50, Mainhand right | Yes | Yes | No |
| 50/50, Mainhand left | Yes | No shift in this example | Yes |
| Dual landscape, Mainhand right | Yes | Yes | No |
| Dual landscape, Mainhand left | Yes | No shift in this example | Yes |
| Portrait workspace on the left | Yes | Yes | No |
| Stacked, Mainhand on top | Yes | Yes | Yes |
| Stacked, Mainhand below | Yes | No shift in this example | No |

EllesmereUI Copy inherited overlapping right-bar positions in all seven
arrangements before correction. With EllesmereUI enabled, unchanged default
native anchors alone do not prove a native overlap because Blizzard retains
its default positioning policy. The explicit replacement proposals were the
separate reproduced failure.

The corrected matrix asserts native and replacement columns, replacement
bounds, custom-position preservation, both anchors, and source immutability.
It covers scales 0.65, 1 and 1.25, plus unequal replacement bar sizes and scales.
All 42 combinations pass. The full 115 Lua suites and six manifest checks pass.
Existing Gamepad tests pass. The seven-arrangement matrix targets keyboard
mode. The Forever right-bar refinement has not been extended to Retail or
Classic native placement.

Previously generated native layouts need an explicit Create Mainhand HUD Layout
refresh to receive corrected native anchors. This updates the existing
character slot. Then review and import the EllesmereUI profile and follow the
reload prompts. Live acceptance remains open for the reported span, native
bar visibility, larger HUD footprints, protected actions, Escape, and reload
persistence. Arbitrarily large frames may still require player adjustment.

## Sources

- [Pinned Forever preset constants](https://github.com/Gethe/wow-ui-source/blob/9dc84f0d3bbae1768ac3405b3716000bd93eda06/Interface/AddOns/Blizzard_EditMode/Camelot/EditModePresetLayoutConstants.lua).
- [Pinned native right-bar positioning](https://github.com/Gethe/wow-ui-source/blob/9dc84f0d3bbae1768ac3405b3716000bd93eda06/Interface/AddOns/Blizzard_EditMode/Shared/EditModeManager.lua).
- [Pinned native anchor application](https://github.com/Gethe/wow-ui-source/blob/9dc84f0d3bbae1768ac3405b3716000bd93eda06/Interface/AddOns/Blizzard_EditMode/Shared/EditModeSystemTemplates.lua).
- Core/MainhandEditMode.lua, Core/ForeverEllesmereLayout.lua and the corresponding
  production-entry regression suites. The ignored dist/hud-geometry-investigation-20261109
  directory retains the reproduction and reviewed upstream snapshots.

## XP bar stack follow-up

The next user screenshots show the native XP bar intersecting the main action
buttons after a Create Mainhand HUD Layout refresh. The legacy calculation used
the main frame's live attachment point and the legacy status manager dimensions.
A deliberately stale TOPLEFT live main-bar anchor reproduces the bad calculation
while the saved main-bar anchor is BOTTOMRIGHT relative to MicroMenuContainer.
The available native cache predates the new screenshots and is not treated as
fresh verification of their saved state.

The Forever keyboard path now resolves the saved main-bar origin through the
serialized Micro Menu anchor, reads the actual main and secondary status
containers, and places the default XP/Rep bars above the main-bar top. Offsets
are stored in UIParent units once. Secondary action rows reserve their combined
scaled heights. The path also handles EllesmereUI owning the action bars while
the player chooses Blizzard status bars. Explicit custom status positions are
preserved. Missing modern capabilities retain the legacy compatibility path.

The previous installed generator fails the new regression. The corrected
generator passes it for the reported equal split, mixed-height span and upper
stacked span, including different bar scales, misleading legacy dimensions,
stale live anchors, secondary-row clearance, custom reputation placement and
replacement ownership. All 116 root Lua suites, six manifests and installed
mainhand/transfer/wizard probes pass. The generator was backed up and installed.
Live placement and protected-action acceptance for this follow-up remain open.