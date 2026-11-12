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
  layout, activates it, and offers to reload. On Forever, Modern and Gamepad
  keep their preset minimap, aura, damage meter, and unit-frame offsets relative
  to Mainhand. Gamepad keeps Blizzard's radial bar and its unit-frame spacing.
  The keyboard layout keeps Blizzard's right-bar spacing and puts its secondary
  bars side by side when Mainhand has room. Status bars and other bottom controls
  use the projected action-bar area. In the generated
  copy, supported native groups outside Mainhand are fitted using their serialized
  anchors and registered dimensions. Custom positions already inside Mainhand
  remain unchanged. Snapped children follow their root. Standalone stretched
  systems can fit through both anchors; oversized, unknown or externally managed
  groups retain their source placement for manual review. Forever leaves the ambiguous
  MultiCast/ClassBar entry at its source position to avoid the client's empty
  spell-tooltip error.

Layout writes require a player click, no combat, and a closed Edit Mode window.
An explicit Create after selecting Modern or another user layout uses that
selected source. Creating again while the current generated layout is active
retains its in-Mainhand edits and does not apply a second default translation.
Before an existing generated payload is replaced, its prior data and provenance
are retained in `OffhandCharDB.mainhandLayoutBackups` without using another native
layout slot. Original user layouts and presets remain unchanged. Restore saved
layout selects existing data; it does not regenerate or reset the HUD.

Forever saves the generated HUD under the character's Edit Mode layouts.
Standard and Gamepad each have their own slot. Rebuilding for a different
span or a change in HUD ownership updates that slot. Existing account-wide
Offhand layouts remain available through the native layout menu.

### EllesmereUI on Forever

Before spanning, type `/eui` and open **Profiles & Presets**. Under
**Export Profile**, select the modules you want to preserve and include
**Unlock Mode Layout**. Save the export string outside WoW. To make manual
changes in a separate profile, choose **Create New (Copy)** and follow
EllesmereUI's reload prompt. Switch back through **Active Profile**.

With Offhand spanned and EllesmereUI loaded, finish native HUD setup in Step 5.
If a matching layout is active, select **Next**. If you create or select a
layout, follow the reload prompt and the wizard resumes at Step 6. Choose the
highlighted **EllesmereUI HUD Preview** or **Finish with current profile**.
If you enable EllesmereUI after creating a character HUD and that layout is still
active on the same span and input mode, **Review EllesmereUI HUD** opens Step 6
directly and starts the preview on **Copy Offhand to EllesmereUI**.
The same preview is available under **Offhand Monitor & Map → Recovery &
Preview** and through `/offhand ellesmere preview`. **Help & recovery**
explains the three transfer choices.
The preview shows the current and proposed placements on both displays for
Action Bars 1–8, minimap, player, target, and focus when their registered
elements are available. Choose the moves to include.

- **Fit HUD to Mainhand** proposes moving supported gameplay frames onto
  Mainhand, including ones currently in the workspace. Fit is available
  before the native HUD is created.
- **Copy Offhand to EllesmereUI** uses native Offhand positions for the
  selected elements. Use the Mainhand HUD layout for this span and input mode.
  If you need to create or select one, follow the native reload prompt first.
  `/offhand ellesmere import` opens this view directly.
- **Copy to a Blizzard fallback** requires a current generated native layout
  for this span and input mode. It copies the selected positions as native
  anchors into an inactive layout. `/offhand ellesmere fallback` opens this
  view directly. Select the copy in Blizzard Edit Mode when using the native HUD.

Native Gamepad keeps Blizzard's radial bar. Its EllesmereUI minimap placement
accounts for visible keyboard bars and native aura frames. A wider replacement
focus frame stays beside target when it fits and can move above target on a
narrower Mainhand. Frames with attached children
move as a group, preserving their EllesmereUI links. A frame anchored to
another parent requires moving its parent. Groups without usable bounds
and profiles using overrides are excluded. Fit and Copy
open an EllesmereUI import review for a new profile. Enter an unused name
such as **Offhand HUD**. The module list contains only modules with selected
positions. Confirm **Import Selected Addons**.
When the wizard returns, choose **Finish & Reload** to see the reload prompt.
If you opened the preview from settings, the prompt appears when EllesmereUI
closes. In Forever Gamepad mode the prompt instructs you to type `/reload`.
If a specialization assignment keeps your old profile
active, check **Active Profile** and the assignment. Use EllesmereUI Unlock
Mode for other elements.

EllesmereUI 9.7.8 can capture Blizzard frame positions during its initial
setup. The profile named **Default** can therefore contain saved positions
that carry over to a single monitor. To repair a single-monitor layout, make
a copy in **Profiles & Presets → Create New (Copy)** and place the affected
frames with EllesmereUI Unlock Mode. The visual transfer requires an active
Offhand span and offers Mainhand placement for its supported gameplay frames.

See [Forever HUD mapping](FOREVER-ELLESMERE-HUD-MAPPING.md) for the current
ownership rules, candidate mappings in both directions, and the proposed
setup flow when an EllesmereUI profile already exists.

For publication, use this workflow as the source for a website guide with a
preview screenshot and both setup orders. Summarize supported transfers and
link to that guide from CurseForge once Standard and Gamepad placement,
Escape, and reload persistence have been verified.

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
