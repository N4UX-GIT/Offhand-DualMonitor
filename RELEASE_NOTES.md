<!-- offhand-companion-version: 2.1.9-beta.3 -->

# Offhand Beta 41 (DaylightUI Action Bar Hotfix)

This is an **addon-only hotfix** (`Offhand v2.1.5-beta.41`). Windows Companion remains **2.1.9-beta.3**.

### Bug Fixes

- **DaylightUI 2.2.6+ action bar placement & dragging**: Fixed a Beta 40 regression where DaylightUI action bars registered at file load time (`DaylightUIBar1..8`, stance, pet, possess, and totem bars) were intercepted by Offhand's frame sweep and shifted onto `OffhandDaylightUIArea` instead of staying in DaylightUI's coordinate space. On stacked and asymmetrical monitor setups, this pushed bars upward, bounced dragged bars back, and caused manual X/Y adjustments to climb toward the top of the screen.
  - Offhand now recognizes all pre-registered and runtime DaylightUI movers (including proxy movers), preserving manual drag and numeric X/Y placement across `/reload` while still aligning default positions to Mainhand.
  - *Note*: If you dragged or adjusted X/Y values while on Beta 40, DaylightUI already saved those shifted coordinates in its own profile. After updating to Beta 41, drag your bars back into place once (they will now stay put) or reset them via **Offhand Monitor > Recovery & Preview > Reset DaylightUI positions** (`/dui reset`).
- **DaylightUI stacked-monitor hardening**:
  - Edit Mode staleness detection (`layoutStale`) now accounts for vertical Mainhand offsets on both top-Mainhand and bottom-Mainhand stacked monitor layouts instead of checking horizontal `offsetX` only.
  - DaylightUI fishing, crafting, and campfire scenes now detect vertically stacked spans and refit their height and waterline to Mainhand.

### Previous highlights (Beta 40 + Windows Companion 2.1.9-beta.3)

See [CHANGELOG.md](CHANGELOG.md) for the full Beta 40 release notes, known issues, and contributor credits (**Kintrok / `@DCtheGeek`** and **Abysmal Kabal**).
