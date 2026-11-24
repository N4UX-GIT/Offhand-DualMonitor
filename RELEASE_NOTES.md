<!-- offhand-companion-version: 2.1.9-beta.3 -->

# Offhand Beta 40 + Windows Companion 2.1.9-beta.3

This release pairs **Offhand v2.1.5-beta.40** with **Windows Companion 2.1.9-beta.3**.

### Built-in DaylightUI support, HUD alignment & persistence

- Added a built-in, single-folder **DaylightUI Bridge** inside Offhand (no separate addon folder or dependency). DaylightUI's movers, Edit Mode layout (with confirmation prompt and `/ohdaylight apply`), banners, AFK/welcome screens, fishing/crafting/campfire scenes, DataBar, loot rolls, vendor/trainer windows, world map, and bags stay aligned with Offhand's Mainhand monitor.
- Added lightweight **DaylightUI HUD Alignment** controls directly in **Offhand Monitor > Recovery & Preview** (visible only when DaylightUI is loaded): **Align DaylightUI HUD** (`/ohdaylight apply`) and **Reset DaylightUI positions** (`/ohdaylight reset`), plus live alignment status.
- Fixed DaylightUI 2.2.6 unlock mode and Cooldown Manager layout editor placement on mixed-height and L-shaped monitor layouts: the unlock bar pill, folded **Show** tab, and Cooldown Manager toolbar, tray, preview pieces, and snap guides stay inside Mainhand while preserving user-dragged spots on visible monitors.
- Confined DaylightUI's side-by-side window slides (`Win.Room`) to each window's own monitor so opening Spellbook, Professions, Talents, or Social over an open Offhand panel no longer shunts it across the seam into Mainhand.
- Added reload/restart and single-screen recovery persistence with DaylightUI enabled: `DaylightUIBag` reopens taint-free with Escape protection preserved, DaylightUI replacement windows (`Character`, `Social`, `Spellbook/Talents`, `Professions`, `Group Finder`, `Legacy`) persist and reopen together, and standard Blizzard panels moved via `DaylightUI_Skins` `WindowMove` (`Collections`, `Macros`, `Achievements`, `Encounter Journal`, `Communities`, etc.) sync cleanly with Offhand workspace persistence.

### Windows Companion 2.1.9-beta.3

- **Display Diagnostics preview:** Draws a to-scale preview of your Windows monitor arrangement showing Mainhand, workspace regions, and display numbers across side-by-side, stacked, and mixed-DPI setups.
- **Custom layout auto-span:** Custom workspace layouts now support automatic spanning on WoW launch after one verified manual span on the same monitors.
- **Post-DPI-change span retry:** Extended automatic post-DPI-change retry to every span path, including Windows display-scale decreases.

### Forever maps, bags, external addon compatibility & conflict notices

- Fixed a regression on Forever where dragging the separate Blizzard backpack (`ContainerFrame1`) left it cached in `layout-local.txt` at `FrameLevel: 1`, drawing a grey translucent overlay over backpack slots after reload/restart. Offhand now clears the stale layout-cache flag out of combat and heals any inverted `Bg` frame level automatically.
- On Forever, leave the Blizzard map open on Offhand as you travel outdoors and it updates to your new zone outside combat (while staying put if you browse another zone). With OpenMap, the outdoor map follows your character smoothly at your chosen zoom; pan away to browse, then middle-click to resume following.
- Fixed OpenMap `v0.8.13+` drag-sync and snap-back on Escape/`M` when paired with OneForAll, and fortified OpenMap, MapUtils, and MapWise adapters to validate API major versions and schemas instead of pinning exact patch strings.
- **Offhand Monitor > Window behavior** now shows active external frame owners (`Map`, `Bags`, `Minimap`, `Chat`), and genuine unmitigated conflicts (such as OneForAll moving the World Map ahead of Leatrix Maps, an unsupported OpenMap contract, or multiple active bag addons) display a once-per-session notice out of combat and appear in `/offhand diag`.

### Learned Addon Windows, Questdon & tooltips on Forever

- Select eligible third-party addon windows to keep on Offhand via **Panel layout > Addon windows > Select addon windows**, **Key Bindings > Offhand**, or `/offhand window` (`list`, `forget <name>`), with click-through outlines, top-edge `+ Add`/`Update` pills, toolbar `Forget`, and automatic return to Settings on `Done`.
- **Questdon**'s quest book stays open on Offhand when pressing Escape while DonCore dialogs, menus, and album view keep native Escape.
- World tooltips owned by `UIParent` no longer inherit leftover Offhand workspace clamp insets after hovering bag items with comparison tooltips.
- Multi-page book turning and close-before-reload persistence are verified live on Forever 1.60.1.71037.

### Known issues

- On Forever, reopening a separate Blizzard backpack with `B` during combat after it was restored can still show a yellow interface warning. The backpack opens at its saved spot. `B` reopens the backpack only.
- When spanning monitors of different sizes, the loading artwork can appear cropped. Your in-game view returns to its assigned display once loading finishes.

### Community thanks

Beta 40 and Windows Companion 2.1.9-beta.3 include contributions from these players and developers:

- **Kintrok (`@DCtheGeek`)** — contributed the `Core/Bridges.lua` bridge contract and DaylightUI layout bridge in [#136](https://github.com/N4UX-GIT/Offhand-DualMonitor/pull/136).
- **Abysmal Kabal** — contributed Windows Companion 2.1.9-beta.3's display preview, custom layout auto-span, and post-DPI-change span retry, plus the Forever world tooltip clamp fix and Questdon Escape integration.
- **@Iceskull7**, **@bitwize01 (Frosted)**, **@paramboy (Michele)**, **@victormolla14**, and **@N4UX-GIT** — ongoing Companion, controller, Retail, Wine, and Forever compatibility work.
