# Addon window compatibility catalog

The [runtime catalog](../Core/AddonWindowCatalog.lua) starts with 16 providers
on Forever. Each entry describes a specific window role under the addon's
folder ID. Offhand's [settings and journal adapter](../Core/CanvasAddonEscape.lua)
uses the catalog to select the existing opener observers and to check close
policy after it identifies a live root. The bag, map, and quest log entries
describe existing dedicated behavior.

| Addon | Window | Placement and saved location | Close and reopen behavior |
| --- | --- | --- | --- |
| Leatrix Maps | Settings | Leatrix owns placement | Workspace close policy for the recognized settings windows |
| Leatrix Maps | World Map | Leatrix owns map geometry | Dedicated map policy when its windowed map qualifies |
| Leatrix Plus | Settings | Leatrix owns placement | Workspace close policy for recognized settings windows |
| Leatrix Sounds | Browser and settings | Leatrix owns placement | Workspace close policy for the recognized root |
| Leveldon | Settings | Leveldon owns placement | Workspace close policy for the recognized DonCoreOptions window |
| Questdon | Quest book | Questdon owns placement | Workspace close policy for `QuestdonQuestBook`. DonCore dialogs, menus, and album view keep native Escape. |
| Platynator | Settings | Picker can remember placement for the reviewed settings root | Workspace close policy for settings. Import and confirmation dialogs follow their own rules. |
| ForeverDungeonJournal | Journal | Picker can remember placement for the reviewed journal root | Workspace close policy for the recognized journal root |
| Kerzo Classic Quest Log | Quest log | Kerzo saves the position | Dedicated Escape handling and optional reopen after reload. Explicit close clears the saved open intent. |
| Baganator | Backpack | Dedicated bag position and reload handling | Dedicated close policy for eligible workspace backpack roots |
| Bagnon | Inventory | Dedicated inventory position and reload handling | Dedicated bag policy with Bagnon's inventory manager |
| EllesmereUI Bags | Backpack | Dedicated bag handling with EllesmereUI's own geometry | Dedicated close and reload behavior subject to provider capability and input mode |
| BetterBags | Backpack and bank | Automatic popup recovery yields to the provider's position | Provider handles visibility and closure |
| RestedXP Guides | Guide window | Automatic popup recovery yields to the provider's position | Provider handles visibility and closure |
| OpenMap | World Map | OpenMap owns map geometry | Dedicated map policy when its windowed map qualifies |
| MoveAny | World Map | MoveAny owns map geometry | Dedicated map policy with current client and panel guards |
| ClassicUI Forever | World Map and Character | ClassicUI Forever owns geometry | Existing native and provider lifecycle |

The workspace close policy preserves an eligible window during the game's
shared special-window close pass while the window is on Offhand and panel
persistence is enabled. The provider's explicit close remains in charge.
The existing adapter checks span, input mode, combat, root identity, and
visibility. It restores the registration when it releases the window.

The evidence is specific to the tested windows. Earlier keyboard tests on
Forever 1.60.1.70862 covered the settings timing, the journal, and Kerzo's
reload behavior. BetterBags Next and the RestedXP V2 welcome window have
position evidence on that build. Replacement bag and map policies differ by
provider, mode, and build. [Settings and journal](ADDON-WINDOW-TIMING-20261107.md) ·
[Kerzo](KERZO-RELOAD-20261107.md) · [BetterBags and RestedXP](BETTERBAGS-NEXT-RXP-V2-QA-20261110.md) ·
[Bag persistence](BAGANATOR-PERSISTENCE-2026-09-18.md) ·
[Third-party ownership notes](THIRD-PARTY-COMPATIBILITY.md)

## Remember a window

On Forever with a spanned workspace, open **Offhand → Panel layout → Addon
windows → Select addon windows**. Eligible addon windows get an outline.
Click each window you want to add, then click **Done**. You can open more
addon windows during the session. The **Select addon windows** keybinding
and `/offhand window` command also toggle the mode.

**Next** cycles through eligible windows and **Add** saves the focused
one. The toolbar names the focused window and shows its position in the
list. You can bind **Focus next addon window** and **Add focused addon
window** in WoW or use `/offhand window next`, `/offhand window add`,
and `/offhand window done` with the keyboard.

Offhand keeps a selected window's current position if the whole window is
already in a workspace. Otherwise it centers it in the destination workspace
if it fits.

Offhand stores the placement in the active profile and restores it the next
time the provider opens that window. To change the saved location, move the
window and select it again. Use `/offhand window list` to see remembered
windows and `/offhand window forget <window name>` to remove one.

The first version checks the global frame name, addon folder, and source
file before restoring. Pick the window again if those change. The saved
workspace needs to be present and the window needs to fit at its native
size. Learned windows keep the owning addon's close and reopen behavior.
Open windows can continue to move through the addon's own controls.

The picker works with ordinary frames that have a single UIParent anchor.
Cataloged addons can opt individual windows into placement. Platynator
settings and ForeverDungeonJournal are the initial examples. Source paths
and protected frame state can make some windows unavailable. The selection,
keyboard focus, compatibility rules, and restore logic have Lua fixture
coverage. Live mouse targeting, frame order, and protected actions still
need confirmation in the Forever client.
