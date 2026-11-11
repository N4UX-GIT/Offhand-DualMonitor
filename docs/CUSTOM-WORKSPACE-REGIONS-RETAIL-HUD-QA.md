# Prototype 5 Retail HUD and panel QA

Recorded 2 November 2026. This is targeted acceptance of the unchanged Prototype
5 Companion with the installed Retail addon, not a release or a complete HUD
acceptance pass.

## Exact scope

- Companion `2.1.3-beta.1`, file version `2.1.3.1`, protocol 1. EXE SHA-256
  `150F56776371E779083D4891D126E8BFF6DBC5BF6A2C48CC3C3EB32D1A8E8898`.
- Retail `12.1.5.70688`, installed Offhand `2.1.2-beta.24`, existing level-1
  Hunter in Coldridge Valley. The character remained idle; no combat, movement,
  spell casting, item use or progression actions were automated.
- Installed `Core/MainhandEditMode.lua` SHA-256
  `47B4DD323026D817D09F11BF0109F149BB9A0359B83D843085E3A1C8F072A5E0`.
  This differs from the worktree file, SHA-256
  `0D87D85A3EF2519564917D9350F5F8CEA2FFE792215E1651DABA502E024BD826`.
  No addon source was deployed or changed. Do not transfer this installed-addon
  acceptance to a different packaged addon without checking its source.
- Full game display `2560x1440`, one `782x1290` workspace on the portrait display,
  local top-origin offset `(500,914)`. Both displays used 100% Windows scaling.
  Native backing rectangle `(-940,-200) 3500x1640`, complex clip region type 3.

Private evidence is under ignored
`dist/live-qa-prototype5-retail-hud-20261102-180532`. Raw profiles, account paths,
screenshots and error records are not distribution artifacts.

## HUD generation boundary and controlled regeneration

The account already contained five custom Edit Mode layouts. A private call to
the installed addon's normal `CreateOrUpdateEditModeLayout` method returned
`false, "maximum"`. Snapshots confirmed all five rows and active preset 1 were
unchanged. Fresh creation of an additional row remains unverified.

To exercise regeneration without removing a user layout, the existing backed-up
Offhand row was temporarily renamed to the current character's recognized legacy
layout name, and the temporary character record was pointed at it. The generator
then rebuilt that owned row from Modern for the new region. This is a deliberately
prepared legacy-state fixture, not acceptance of the initial setup button or a
new-row transaction. It returned success, 47 moved systems, and active layout 7.
The other four custom rows remained deeply equal to the original snapshot.

After `/reload`, a separate `GetLayouts` sample confirmed active layout 7 and
unchanged generated rows. The visible action bar, XP bar, player frame and minimap
were inside Mainhand. A fresh viewport diagnostic reported `READY`, version
`MATCH`, `viewportMatches=true`, and WorldFrame approximately
`(940,0) 2560x1440` in backing pixels. Native bounds and clipping survived reload.

## Panels and external ownership

Character, combined bags and spellbook were visible inside the workspace. Bags
and Character persisted through reload; the spellbook reopened through normal
keyboard input. This checks placement and visibility, not item or spell actions.

The first map test used the user's enabled OpenMap addon. Runtime diagnostics
identified `OpenMap` as the map geometry owner. Its existing large map extended
beyond the narrow custom area, and changing Offhand's map scale to `AUTO` did
not change it, consistent with Offhand yielding geometry to the external owner.
This is an observed compatibility limit, not a default-map fit pass.

OpenMap was temporarily disabled for this character and the UI reloaded. With
Offhand owning the default Blizzard map and `workspaceMapScale="AUTO"`, the map
fit inside the custom workspace. OpenMap's original enabled state was restored
after the run. External map and chat layout adjustments remain the owner's
responsibility; their previous full-display layouts do not establish custom-area
fit.

The automation capture surface cropped the spanned window and reported an
inconsistent origin. Full backing screenshots were obtained through WoW's normal
Print key for inspection. No unverified spanned-window coordinate clicks or
drags were used. Custom-area panel dragging and actual HUD setup-button input
remain open.

## Restore and cleanup

Companion Restore returned exactly to native outer `(208,0) 2144x1392`, style
`14CF0000`, no clipping region. Without manually selecting a HUD, Edit Mode
returned to Modern, active preset 1, and retained it after `/reload`.

A fresh ordinary-window diagnostic confirmed `isSpanned=false`, zero workspace,
`viewportMatches=true`, and full-client WorldFrame approximately
`(0,0) 2128x1353`. The old custom bridge was rejected as `MISMATCH` and the existing
layout-mismatch notice remained visible. This accepts safe viewport fallback and
HUD selection; it does not accept a silent or warning-free Restore experience.

The full original Edit Mode snapshot was restored through `SaveLayouts`, keeping
the same five rows, then sampled again after a separate reload. All row contents
and original active preset compared equal. No layout row was deleted.

WoW and Companion exited normally. Eighteen original files, including Companion
preferences, generated bridges, account/character profiles, Edit Mode caches,
error stores and character AddOns.txt, were restored and hash-verified. OpenMap
was enabled again. BugGrabber session advanced from 349 to 358; all 13 captured
historical error records were deeply unchanged. No fresh captured errors were
found. This does not establish protected-action or combat/taint safety.

## Evidence routing and remaining gates

Shared knowledge status and `C_EditMode.GetLayouts`, `SaveLayouts` and
`SetActiveLayout` declarations were consulted first. The locked `blizzard-live`
source is revision `15881d522c44cd106d3d8660106ec9f9d2f44167`, version
`12.1.5.70575`; its declarations are supporting source evidence, not exact-build
`70688` behavior or taint acceptance. The installed source and observations above
are authoritative for this run.

Fresh creation with a free layout slot, real setup-button input, panel dragging,
protected descendant actions, combat/taint, other clients, physical hotplug,
mixed DPI, the physical 5120-wide monitor, and Store/Wine runtime remain open.
The oversized game-options tooltips remain a separate issue. Production source,
Prototype 5 bytes and frozen public Beta 20 artifacts are unchanged.
