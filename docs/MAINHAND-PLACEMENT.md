# Mainhand Placement

Status: **implementation branch; core Forever workflow live-tested, refined HUD stacking pending live approval.**

Offhand exposes the Mainhand game rectangle without taking ownership of arbitrary
addon frames. The implementation has separate paths for unprotected windows and
Blizzard Edit Mode systems.

## Player workflow

The Recovery card contains three related actions:

- **Gather Off-Screen UI** retains the existing emergency recovery behavior.
- **Gather Safe UI to Mainhand** moves visible, movable, unprotected windows that
  do not already fit inside Mainhand. It skips protected, forbidden, tooltip, and
  Edit Mode-owned frames.
- **Create Mainhand HUD Layout** clones the recorded source or active Blizzard
  Edit Mode layout, translates its UIParent-relative anchors from the complete
  WoW canvas to the Mainhand rectangle, saves a character-associated generated
  layout, activates it, and offers to reload. Source entries still using
  Blizzard's default positions receive a compact standard stack: the XP/status
  bar aligns with the complete main/bag bar, stance and pet controls sit above
  its left edge, the vehicle-exit control sits above stance, and extra abilities
  sit above the action/XP stack. Explicitly customized source entries remain
  unchanged.

Layout writes require a player click, no combat, and a closed Edit Mode window.
Regeneration always starts from the recorded source layout. It never applies a
second translation to the generated layout.

## Addon integration API

The API is optional and has no dependency on another UI addon:

```lua
local mainhandFrame = Offhand.API.GetMainhandFrame()
local rect = Offhand.API.GetMainhandRect()

Offhand.API.RegisterGeometryCallback("MyAddon", function(newRect, reason, revision)
    -- Reapply MyAddon's own layout if needed.
end)

local ok, why = Offhand.API.AnchorToMainhand(myUnprotectedFrame,
    "CENTER", "CENTER", 0, 0)
```

`GetMainhandRect()` returns `left`, `bottom`, `right`, `top`, `width`, `height`,
`screenWidth`, `screenHeight`, and `isSpanned`. When Offhand is disabled or not
spanned, the region becomes the full UIParent rectangle.

`AnchorToMainhand` refuses forbidden, protected, and combat-time writes.
Third-party addons should normally use the geometry callback and reapply their
own saved layout rather than asking Offhand to persist their frames.

Returning `false` from a geometry callback unregisters it. A callback that raises
an error is also removed so repeated display events cannot flood the client.

## Ownership boundaries

- `OffhandMainhandFrame` is an unprotected geometry anchor; Offhand does not
  parent discovered frames to it.
- Blizzard protected HUD systems are changed only through a cloned Edit Mode
  layout initiated by a player click.
- The gather action is one-shot. An addon that subsequently reapplies its own
  position remains authoritative.
- Offhand does not globally hook `CreateFrame`, `SetPoint`, or third-party mover
  implementations.

## Client behavior

- **Forever:** generated Edit Mode layouts use the client-specific custom-layout
  identifier offset and are designated per character for Companion recovery.
- **Retail:** the same capability-detected Edit Mode transformation and default
  XP/stance refinement applies, without Forever's recovery bridge.
- **Classic Era, Hardcore, and Classic branches without Edit Mode:** no generated
  layout is written. Offhand uses its established direct compatibility anchors;
  XP/reputation stays above the main bar and stance/form buttons align over its
  left edge. Custom action-bar addons remain authoritative.
- **Legacy Wrath 3.3.5a:** the direct path is syntax/simulation compatible but
  remains experimental until the documented genuine-client matrix passes.

## Required live validation

- Forever and Retail: Modern, Classic, and existing custom source layouts.
- Layout limit reached, controller mode, Edit Mode open, and combat lockdown.
- Left, right, top, and bottom Mainhand positions; mixed resolutions and offsets.
- Repeated regeneration after geometry changes without anchor drift.
- Party/raid transitions, action paging, pet/stance/vehicle bars, cooldown
  viewers, and taint logging before and after reload.
- Missing-monitor fallback and restoration of the generated Forever layout.
- Safe gathering with Blizzard windows and several movable addon windows.
