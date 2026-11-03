# Retail pet battle controls disappear

Status: user confirmed the reported Retail pet battle issue fixed on 2026-11-01
after the local addon update. This is acceptance of the reported failure;
the complete topology, compatibility, lifecycle and taint matrix is not recorded.

CurseForge report received 2026-11-01: professions work after the update,
but the pet battle top and bottom interface initially appears and then
disappears, preventing play until Offhand is disabled. The reporter's exact
client build, addon version, display geometry and other addons are unknown.

## Source finding

`Core/SeamRedirect.lua` runs generic popup rescue before dedicated transient
placement on the two-second maintenance ticker. On a mixed-height canvas,
an unprotected full-canvas `PetBattleFrame` can qualify as a window above
Mainhand. Generic rescue replaces its two bounds with a single `CENTER`
anchor. The dedicated battle mover then reports `custom-anchor` and yields.
The native root derives its dimensions from its bounds; it is not an ordinary
window with an explicit size. This is a source-confirmed ownership conflict,
and a candidate explanation for the report. A native bounds reset or late
adoption in the reporter's session has not been observed.

Blizzard source reviewed at revision
`15881d522c44cd106d3d8660106ec9f9d2f44167`, build `12.1.5.70575`:

- [Shared XML](https://github.com/Gethe/wow-ui-source/blob/15881d522c44cd106d3d8660106ec9f9d2f44167/Interface/AddOns/Blizzard_PetBattleUI/Shared/Blizzard_PetBattleUI.xml):
  `PetBattleFrame` is an ordinary `Frame`, `setAllPoints="true"`, hidden at
  creation. Top artwork and `BottomFrame` anchor to that root. Neither the root
  nor the action button templates declare a secure template.
- [Shared Lua](https://github.com/Gethe/wow-ui-source/blob/15881d522c44cd106d3d8660106ec9f9d2f44167/Interface/AddOns/Blizzard_PetBattleUI/Shared/Blizzard_PetBattleUI.lua):
  opening calls `PetBattleFrame_Display`; Blizzard owns battle visibility,
  action setup and removal. Source declarations do not prove runtime protection.

The installed Retail build is `12.1.5.70688` according to `.build.info`.
It was not launched or tested. The shared knowledge status was consulted;
`api C_PetBattles.IsInBattle --client retail` returned supporting callsite
evidence only. PetBattleUI implementation files were absent from the selected
cache, so the matching upstream revision above was inspected directly.
Full-text index regeneration failed because corpus metadata/content changed
during indexing. No retrieval absence was treated as API absence.

## Candidate changes and checks

- Exclude `PetBattleFrame` from both generic HUD popup discovery paths.
- Exclude it from Canvas workspace dragging and generic panel void rescue.
- Preserve already-correct two-point bounds without clearing them every tick.
- Keep native visibility, actions, custom-anchor yielding and combat deferral.

The regression uses an unprotected root with native full-canvas geometry on
the existing mixed-height fixture and invokes the real maintenance callback.
It failed before the scanner exclusion and passes afterward. Earlier coverage
always marked the root protected, masking this path. It also checks repeat
placement writes and rejection by generic panel handling. These mocks do not
establish native rendering, action safety or the reporter's exact trigger.

Validation: all 75 Lua suites passed. The addon validator checked all six
manifests, runtime paths, XML references and Lua syntax using Lua 5.1.

## Required live verification

The user has accepted the original fix. The following broader matrix remains
unrecorded and must not be inferred from that acceptance. The follow-up
[Retail transient audit](RETAIL-TRANSIENT-AUDIT-20261101.md) records additional
edge cases separately.

Record exact Retail/addon versions and topology. With the candidate installed,
start wild and trainer pet battles, wait at least six seconds, select abilities,
switch pets, and complete or forfeit. Repeat another battle and after `/reload`.
Check top artwork, unit frames and bottom controls throughout opening and rounds,
and normal UI restoration on close. Inspect fresh Lua errors and taint evidence.
Repeat with custom pet-battle placement to confirm Offhand yields. Do not mark
the CurseForge report resolved until these checks pass on the affected setup.
