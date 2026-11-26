# Built-in Questie Bridge

Built-in Offhand bridge (`Bridges/Questie/Bridge.lua`) that keeps **Questie**'s windows, dialogs and tracker
behaviour on the game monitor when UIParent spans several monitors. Questie places several windows on
UIParent's centre or top, which with Offhand is the seam between monitors, sends its map icons back to UIParent,
and sizes its tracker and item tooltips from the whole spanned width. The bridge is completely inert (no frame,
hook or registration) unless Questie is loaded on the Forever client.

## What it does

- **Windows:** `QuestieTutorialChooseObjectiveType` (`CENTER` 0,50) and `QuestieProfilerIndicator`
  (`TOP` 0,-4) are moved to the same spot of the game rectangle while they sit at Questie's default.
- **Dialogs:** Questie's dialogs stacked by LibPopupStack-1.0 (`TOP -> UIParent BOTTOMLEFT` at the top centre
  of the screen) are moved to the top centre of the game rectangle after each layout. The library's own
  `anchors` cache is never written.
- **QuestieTrace consent prompt:** `QuestieTraceConsentFrame` (same top-centre placement, remembered in
  `popupAnchorX/Y`) is moved the same way when QuestieTrace is installed.
- **Map icons:** `QuestieFrame<n>` icons are kept under the holder frame `OffhandQuestieIcons` instead of
  UIParent, so released world-map pins no longer pile up as UIParent children.
- **Tracker width:** Questie caps the tracker's automatic width at `GetScreenWidth() * trackerWidthRatio`.
  During `QuestieTracker:UpdateWidth` and `TrackerLayout.UpdateLineWidth` the ratio is scaled to the game
  rectangle's share of the screen, then restored, so the saved setting never changes.
- **Quest item button tooltips:** `Questie_ItemButton<n>` picks its tooltip side from half of the whole
  screen width; on the game monitor the side is corrected to the game rectangle's own middle.

## What it leaves alone

- Windows the player dragged, and dialogs placed beside a Blizzard popup.
- "Reset Tracker": Questie centres the tracker on the whole screen and saves that; Offhand leaves the
  tracker's position to Questie on purpose.
- The LibDBIcon minimap-button tooltip side, the optional sticky Durability/VoiceOver frames, and AceGUI's
  released widgets under UIParent.
- Questie's standalone settings window is fitted by `Options.lua` beside it, not by this bridge.

## Standalone settings window (`Options.lua`)

`Bridges/Questie/Options.lua` is the former Questie part of the addon options window fitting in
`Core/PopupBounds.lua`, moved behind the bridge contract with unchanged behaviour. It registers its own id,
`QuestieOptions`, on the Forever client whether or not Questie is loaded yet and whether or not the bridge above
is active.

- While Offhand is enabled and spanned, `QuestieStandaloneSettings` is sized to 70% of Mainhand's height
  (Questie sizes it from the whole canvas) and moved onto Mainhand when it overlaps the seam. A window being
  dragged is left alone.
- When the span ends or Offhand is disabled, the height it set goes back to 70% of UIParent and the anchor it
  owns goes back to Questie's own; a dragged window keeps its place. Nothing is changed in combat.
- Core reaches it through `InitializePopupWindows()` (hooks `QuestieOptionsEngine.ShowFrame` once the popup
  bounds handling initializes and again on Questie's `ADDON_LOADED`) and `RefreshAddonOptions(getMetrics)`
  (every popup layout pass and after combat). The fitting helpers stay in core
  (`Offhand.API.GetOptionsWindowHelpers()`). Tested by tests/addon-options-bounds.lua.

## Diagnostics

`/offhand diag` shows `QuestieAnchors=<moved>/<total> QuestieIcons=<icons adopted> QuestieWidth=<wrapped>/2`.

## Origin and evidence

Contributed by Kintrok (@DCtheGeek). Read against Questie 12.15.0 and QuestieTrace 1.14.0.
Automated tests pass (tests/bridge-questie.lua). Live Forever QA is pending.
