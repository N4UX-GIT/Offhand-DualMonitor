# Built-in DonCore Bridge

Built-in Offhand bridge (`Bridges/DonCore/Bridge.lua`) for the Don addons
**Questdon**, **Leveldon** and **DonMap** and the DonCore library they share
(verified against Questdon 1.7.0, Leveldon 0.3.4-beta and DonMap 1.3.6,
`Libs/DonCore/Kit.lua`). It holds the Don parts of
`Core/CanvasAddonEscape.lua`, moved behind the bridge contract with unchanged
behaviour. The addons keep their own geometry and visibility.

## What it does

- DonCore adds every `Kit.Window` it makes to `UISpecialFrames`. Two of them
  are workspace windows that Escape leaves open while they are on the
  workspace: Questdon's quest book `QuestdonQuestBook` (a `Kit.Window` from any
  addon's copy of DonCore, with a header and a close button, while Questdon is
  loaded) and DonCore's shared options window `DonCoreOptions` (the frame the
  `DonCore-1.0` options module returns, while Leveldon is loaded). Dialogs,
  menus, the album view and the way box keep closing with Escape.
- Their close button is the window's `close`; a drag of the window's header is
  followed like a drag of the window.
- The Leveldon guide `LeveldonPanel` and the DonMap arrow `DonMapArrow` are
  vendor gameplay frames on the Forever client: Offhand never saves, gathers or
  rescues their placement. Placement and open records that older Offhand
  passes saved for them are retired.

## How core reaches it

- `data.windows`: `DonCoreOptions` (identified before any source location is
  read) and `QuestdonQuestBook`, owners `Leveldon` and `Questdon`, header drags,
  and the openers: the `DONCORE` slash command and the options module's `Open`.
- `IdentifyWindow(frame, name, source)`, `GetWindowCloseButtons(frame)`.
- `RetireStalePlacements(services)`: with every addon window Escape refresh.
- `data.catalogs`: the `Leveldon` and `Questdon` catalog entries.
- `data.frameRules`: `vendorGameplay` and `preservePopup` for the guide and the
  arrow (by name, their own shape, the Forever client only).

It registers on every client and reads the addons when asked, so a Don addon
that loads after Offhand is still handled.

## Evidence

Automated tests pass (tests/forever-don-addon-escape.lua,
tests/forever-addon-window-timing.lua, tests/party-editmode-and-void-rescue.lua,
tests/bridges-contract.lua). The move itself has not been run in a live client.
