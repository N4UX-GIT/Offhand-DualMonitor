# Forever crafting, Spellbook and inventory QA

The November 19 Discord report identified two ways an anchored inventory could interfere with other windows. Local QA used Moonweaver Noggaholic on Forever 1.60.1.71037 with keyboard input, the 2.1.9-beta.1 test Companion, and one inventory provider enabled at a time. Both Offhand persistence options were enabled. The setup had a left-hand portrait Offhand and a landscape Mainhand. The reporter used two 1920 × 1080 displays and Companion 2.1.8. [Discord report](https://discord.com/channels/1491522138371391691/1572833433858740244)

## Reproduction and implementation plan

1. Start from the earlier Discord Beta 36 settings-trim package. Open a learned profession and its recipe list. Record actual crafting-frame hides, inventory visibility and Game Menu state on consecutive physical Escape presses. Repeat after moving crafting to Mainhand and check the close button.
2. Open each inventory before Spellbook, reverse the opening order, and try expanding Spellbook on Mainhand. Record each hide and show in addition to the settled visibility. A bag that immediately reopens can otherwise appear to pass.
3. Preserve the native crafting session at the dedicated Escape handler. Let that handler receive Escape when the native backpack is open. Scope inventory handling to the verified vendor backpack and native panel transaction. Exercise the ordinary close controls after each change.

## Live findings

| Scenario | Local observation |
| --- | --- |
| Bagnon 12.1.11 and Cooking on Offhand | On the Discord build, two Escape presses hid and restored the crafting frame and never showed the menu. With the fix, the first press opened the menu, the second closed it, and the crafting frame recorded zero hides. The recipe API returned 132 recipe IDs before and after. Bagnon stayed visible throughout. |
| Cooking on Mainhand with Bagnon | Two input traces recorded Escape closing Cooking and the next press opening the menu. One earlier sample ended with the menu closed after the second press. That result did not recur in either traced replay. Clicking the native close button on Offhand also closed Cooking. |
| Blizzard combined backpack and Cooking | The backpack's window-close binding closed the crafting session. With both windows anchored on Offhand, the packaged fix opened and closed the menu on successive Escape presses, with zero crafting hides. On Mainhand, the first press closed Cooking and the next opened the menu. The backpack stayed visible in both cases. |
| BetterBags 0.9.5, Next backpack | Compact Spellbook preserved the bag. Expanding Spellbook on Mainhand called the native panel manager's close-special-windows path and BetterBags queued an animated close. With independent windows enabled, the bag remained open. Turning that setting off restored its ordinary close. Explicit bag close still worked. |
| Bagnaros 1.2.1 | The expanded Spellbook and Escape produced a hide immediately followed by a vendor reopen, even after saving the bag position through Bagnaros. After excluding the vendor's Offhand inventory from the special-frame list, both transitions recorded zero hides. Explicit close and reopen still worked. [Vendor release](https://www.curseforge.com/wow/addons/bagnaros/files/9079337) |
| Baganator 865 | Its inventory survived compact and expanded Spellbook, including the expanded check in category view. With an active search box in either view, the first Escape released text focus and the second opened the menu. The inventory stayed on Offhand. [Vendor release](https://www.curseforge.com/wow/addons/baganator/files/9689225) |

## Acceptance still needed

BugSack error counters were compared across reloads and vendor changes. The compatibility checker passed 140 Lua suites in the packaged baseline and 141 in the working checkout. All 10 checker tests passed. The older full native-bag release receipt still requests a fresh run for its broader scope.

Moonweaver is level 7 and pressing N did not open Talents. Repeat on a character with unlocked Talents and record the inventory provider, view, which monitor owns PlayerSpells, and whether the bag disappears, flashes or remains visible. Reporter acceptance on the original two-monitor configuration is also pending. These checks cover out-of-combat keyboard input.

The addon-only QA ZIP was built from the committed development baseline `cc24a00` with the scoped fixes. Its SHA-256 is `BF6035A5D5F05391E04B8EECF770189C3A306D9938480FAE26CA22E4EB2D15C7`. The installed runtime matched the candidate checkout. The package retains Beta 36 metadata, so use the filename and hash to identify it. Private run evidence was saved under `dist/professions-bags-1795216061427`.
