# Built-in EllesmereUI Bridge

Built-in Offhand bridge for the **EllesmereUI** suite. `Bridge.lua` supplies
facts only (ownership roles, guidance, diagnostics segments and the aura-bar
frame rule, the EllesmereUIBags bag facts and the locale key names of the HUD
layout transfer texts; its header lists them).
`Scale.lua` is the former `Core/EllesmereScaleCompatibility.lua` moved behind
the bridge contract, with unchanged behaviour. `Bags.lua` is the former
EllesmereUI bag Escape adapter and persistent-root branches of
`Core/BagPersistence.lua` and its close button finder of
`Core/WorkspaceChrome.lua`, moved the same way as the EllesmereUIBags bag
provider. `Windows.lua` is the former EllesmereUI window fitting of
`Core/PopupBounds.lua` and the chat bubble ownership probe of
`Core/ChatBubbles.lua` (and the onboarding profile backup advice), moved the
same way. `Layout.lua` and `Preview.lua` are the former
`Core/ForeverEllesmereLayout.lua` and `UI/EllesmereLayoutPreview.lua`, the HUD
layout transfer, moved the same way. `Layout.lua`, `Scale.lua` and `Windows.lua`
share one bridge object (registered as `EllesmereUI`) through the bridge
namespace.

## What Scale.lua does

- While Offhand is enabled and the game is spanned (and not in combat),
  EllesmereUI's pixel grid (`EllesmereUI.PP.mult`) follows the live UI root
  Offhand sets, not the scale saved in EllesmereUI's profile. The saved scale
  is never rewritten.
- It hooks `PP.UpdateMult` so every vendor refresh keeps that grid, and
  `PP.SetUIScale` so a scale the player picks in EllesmereUI is followed by one
  full Offhand layout on the next frame that keeps the chosen scale. Several
  slider changes in one frame give one layout; nothing runs in combat, while
  Offhand is disabled or while the game is not spanned.

## How core reaches it

- `RefreshScale()`: called on every full layout pass, right after Offhand
  applies its global UI scale and before the viewport updates, where core
  called the module.
- `Offhand.API.RequestFullLayout(true)`: the layout after the vendor's setter.

It registers on every client before EllesmereUI exists and looks
`EllesmereUI.PP` up on each call, so an EllesmereUI that loads after Offhand is
still hooked.

## What Bags.lua does

- On Forever, while `EUI_MainBagFrame` or `EUI_ReagentBagFrame` is open on the
  workspace, Offhand removes only that root's default registration from
  EllesmereUI's shared Escape proxy and closes the native bags it parks; on
  Mainhand the registration comes back once, and the proxy is shown again if
  the root is open.
- The workspace close button handling finds the backpack's header close
  button (the header child anchored `RIGHT` to `RIGHT`).
- The generic inventory toggles are kept open while `EUI_MainBagFrame` is on
  the workspace.
- Persistent root: `EUI_MainBagFrame` is the first root the bag persistence
  engine tries and is found by its stable name, never by a global-table walk.
  On Forever EllesmereUI restores it itself: its saved open state wins, the
  reagent bag's open state is saved with it (`reagentOpen`), no scripts are
  installed on it (it is observed outside its frame tree), and Escape (after
  its own proxy hid it), the Talents tab of Player Spells and reload reopen it
  through EllesmereUI's own show and refresh handlers. The reload reopen waits
  until EllesmereUI has installed its bag layout. A false
  `EllesmereUIDB.bagsVisible` is the player's own close and cancels any
  restore. On Forever it claims the shared bag toggle; when Baganator claims it
  too, the toggle is never called and the root opens through EllesmereUI's
  scale setup instead. The bag diagnostics end with `EUIOpen=<bagsVisible>`.

Core reaches it through `bagProvider.RefreshEscape(services)` at provider
order 70, after the bridges' own `RefreshBags` (where core called the adapter),
`GetCloseButtons(frame)` for the root it lists in `closeButtonRoots`, and
`GetToggleFrame()`. The bag persistence engine calls, each in `pcall`,
`IsRoot`, `Discover`, `hookScripts`, `GetManagedRoot`, `ClaimsSharedToggle`,
`ExplicitlyClosed`, `Show`, `CapturePosition`, `CanRestore`, `Restore`,
`Resume` and `GetRootDiagnostics` (docs/BRIDGES.md, section 4). It registers
on every client before EllesmereUI exists.

## What Windows.lua does

- On Forever, while Offhand is enabled and spanned and outside combat, every
  0.2 s it fits EllesmereUI's settings window and popups (`EllesmereUIFrame`,
  `EUIFirstInstallPopup`, `EUIStyleChoicePopup`, `EUIConfirmPopup`,
  `EUIInfoPopup`, `EUIInputPopup`) inside Mainhand once per presentation when
  they reach space with no display, shrinking only when they are larger than
  Mainhand. A window that still holds the anchor Offhand gave it gets its own
  anchor and scale back when it hides or the span ends; a later EllesmereUI
  placement wins.
- The Unlock Mode toolbar is kept flush with the top of a display that reaches
  the real UIParent top (its hover handler uses that edge), refitted when the
  span geometry settles, and handed back when Unlock Mode closes.
- Chat bubbles: while EllesmereUI's profile enables its bubble styling, the
  Offhand bubble replacement yields (`replacementConflict=EllesmereUI`).

- Onboarding: on Forever, while EllesmereUI can export its profile, the span
  step advises a profile backup (`GetSetupNotes("before-span")`).

Core reaches it through `InitializePopupWindows()`, called once where
`PopupBounds` created the ticker (the ticker starts only on Forever when
EllesmereUI exists at that moment, as before), `OwnsFeature("chatBubbles")` and
`GetSetupNotes(context)`. It reads `Offhand.API.GetOptionsMetrics()`,
`IsForeverClient()` and `GetText(key)`.

## What Layout.lua and Preview.lua do

The one-time HUD layout handoff between Forever Edit Mode and EllesmereUI
profiles, on the Forever client only (whether or not EllesmereUI is loaded;
`IsAvailable()` checks EllesmereUI when it is asked):

- `Preview(direction)` plans each EllesmereUI mover: `fit` keeps the suite's
  HUD inside Mainhand (linked groups, cast bars, tracked buff bar groups and the
  Gamepad minimap obstacles included), `ellesmere` copies Offhand's native
  Mainhand layout into the profile, `blizzard` copies reachable positions back
  as a separate inactive native layout (`Offhand HUD - Blizzard`).
- `OpenImport(rows)` hands a partial profile (only the changed modules and spec
  buckets, overrides and layout excluded) to EllesmereUI's own interactive
  importer; a newly active profile asks for a reload.
- `Preview.lua` is the visual preview dialog (before and after diagrams, row
  selection, paging, blockers with help) and the import reload prompt.
- `/offhand ellesmere [preview|import|fallback]` opens the preview.

Core reaches it as `Offhand.HUDTransfer` (registered with
`Offhand.API.RegisterHUDTransfer`): the setup wizard's transfer step, the
Options preview button and help text, the onboarding note, the character
review prompt and the manual layout selection text use the provider's
`text` keys (`Bridge.lua` names them; the locale keys keep their names), its
`addon`, `reloadPopup` and `copyDirection`. The bridge reads the layout source
and saves the fallback through `GetHUDTransferSource` and
`SaveHUDTransferFallback`, and uses `GetControls`, `GetText`, `ShowPopup`,
`GetReloadFunction`, `IsNativeGamepadInterface`, `GetViewportMetrics`,
`GetGeometrySignature`, `GetLayoutFailureText`, `IsEnabled`, `IsInputReserved`
and `Print`. The command runs through `Bridges:RunSlashCommand` at the old
slash branch.

## Evidence

Automated tests pass (tests/ellesmere-scale-compatibility.lua,
tests/baganator-persistence.lua, tests/workspace-close-buttons.lua,
tests/popup-bounds.lua, tests/chat-bubble-scale.lua,
tests/forever-bubble-font-ownership.lua, tests/forever-ellesmere-layout.lua,
tests/forever-ellesmere-blockers.lua, tests/forever-ellesmere-expanded.lua,
tests/mainhand-placement.lua, tests/wizard-autoconfig.lua,
tests/character-setup.lua, tests/bridges-contract.lua). The moves themselves have not been run in a live
client.
