# Built-in Platynator Bridge

Built-in Offhand bridge (`Bridges/Platynator/Bridge.lua`) for **Platynator**.
It holds the Platynator parts of `Core/CanvasAddonEscape.lua`, moved behind the
bridge contract with unchanged behaviour. Platynator keeps its own geometry and
visibility.

## What it does

- Escape leaves Platynator's customise dialog (`PlatynatorCustomiseDialog...`,
  created by `CustomiseDialog/Main.lua`, with tabs and a close button) open
  while it is on the workspace. Its import and confirmation dialogs keep their
  own Escape rules.
- A first open through its slash command, the addon compartment or the
  `addon:platynatorsettings` settings link is followed at once, so a lazily
  created dialog is protected before it is shown.
- Its close button is the dialog's `CloseButton`. The addon window picker may
  remember the dialog's placement.

## How core reaches it

- `data.windows`: the dialog name pattern, owner `Platynator`, the opener
  `Platynator_AddonCompartmentCallback` and the settings link (observed while
  Platynator is loaded).
- `IdentifyWindow(frame, name, source)`, `GetWindowCloseButtons(frame)`.
- `data.catalogs`: the `Platynator` catalog entry (`learnPlacementFile`
  `customisedialog/main.lua`, slash opener `Platynator`).

It registers on every client and reads Platynator when asked.

## Evidence

Automated tests pass (tests/forever-addon-settings-escape.lua,
tests/forever-addon-window-timing.lua, tests/learned-addon-windows.lua,
tests/bridges-contract.lua). The move itself has not been run in a live client.
