# Third-party compatibility boundary

OpenMap retains map window position and scale, including its private saved
anchor. Its own title handle passed manual placement, reopening and reload
checks on Forever 70862, including with Leatrix's competing geometry options off.
Original OpenMap v0.7.5-beta **Reset size and place** failed to recover a hidden
title even with Offhand disabled. The earlier vendor patch passed native
reopen/reload/span checks. A subsequent Offhand candidate provides **Recover
OpenMap title** and `/offhand recovermap` without editing OpenMap files. This
explicit action coordinates one saved anchor with OpenMap's existing owner,
preserving size/scale. It is gated to Forever, OpenMap v0.7.5-beta and API 1/4,
refuses combat and other movers, and has automated acceptance only so far.
The built-in path and reporter's exact vertical stack need live confirmation; see
[investigation, repair tool and evidence limits](OPENMAP-SNAPBACK-20261108.md).

The automatic popup scanner now yields to BetterBags' Backpack/Bank windows and
their anchor roots, RestedXP's named guide/item roots and its anonymous V2 guide
identified through the public AceGUI widget. Explicit user placement also wins.
Vendor source, position databases and explicit workspace movement are unchanged.
Native Forever 70862 keyboard checks accept classic/Next small bags and RestedXP
V1 map/vendor/reload placement in the tested 50/50 split, plus classic native
title/anchor gestures. V2, mixed-height gaps and other Next variants remain
separate acceptance. See the [placement investigation](BETTERBAGS-RESTEDXP-PLACEMENT-20261108.md)
and [native matrix](BETTERBAGS-RESTEDXP-LIVE-QA-20261108.md).

Test12 adds specific Forever Escape adapters for Leatrix Maps/Plus settings,
Leatrix Sounds, Platynator settings, ForeverDungeonJournal and Offhand settings.
Readable source metadata identifies random Leatrix roots. Vendor geometry,
visibility, scripts, explicit close and dialogs remain owned by those addons.
Kerzo's inherited X now participates in reversible workspace chrome. See
[source scope and native evidence](ADDON-ESCAPE-FOLLOWUP-20261107.md).

Kerzo Classic Quest Log 6.1.4 receives a Forever-only Escape adapter for its
`KerzosQuestLog` root. Offhand observes its `ActualizarEstadoEscapeModal` and
`MemorizarPosicion` transactions and filters only the main root's Escape entry
while on the workspace. Vendor dialogs, anchors, saved variables, visibility
and close/toggle behavior remain vendor-owned. Feature release delegates current
Escape registration back to Kerzo. No vendor source or assets are bundled.
See [candidate evidence and limits](KERZO-QUEST-LOG-20261107.md).

Offhand does not bundle, copy, modify, or reproduce EllesmereUI source code or
assets. Its replacement speech bubble is independently implemented and uses
Blizzard's public frame APIs and Blizzard-owned chat-bubble artwork.

EllesmereUI is distributed under a custom all-rights-reserved license. Its
source may be inspected for interoperability, but no implementation text,
media, or other expressive material is incorporated into Offhand.

The source contains a small number of compatibility references to identifiers
exposed at runtime by other installed addons:

- `EllesmereUI.GetActiveProfileData()` is called through a guarded ownership
  probe. Offhand reads only `profile.chatBubbles.enabled` so it can yield when
  that addon owns chat-bubble appearance. It does not call the chat-bubble
  module's database, layout, refresh, or mutation paths; a missing or changed
  interface fails open.
- `EUI_MainBagFrame` and `EllesmereUIDB.bagsVisible` identify an externally
  owned bag root and its explicit close state. On Forever standard layout,
  Offhand observes native Escape and can reopen the workspace root while
  EllesmereUI retains its position. When Baganator also provides a bag toggle,
  Offhand uses EllesmereUI's bag-scale setup capability and its specific bag
  root for reload restoration. Native Gamepad layout uses Blizzard's bags
  when EllesmereUI is the only replacement installed.
- Known EllesmereUI settings and dialog roots can receive temporary placement
  within the physical span. `GetUnlockModeTopBarAnchor` identifies the Unlock
  Mode toolbar through its hover zone. The toolbar stays flush with the top
  of the spanned window so EllesmereUI's hover behavior can still reach it.
- `EllesmereUIRaidFrames` is used only as an addon-presence identifier so
  Offhand can direct users to the correct frame owner instead of moving those
  frames itself.
- `DUIQuestFrame`, `DUIBookFrame`, and `DUIDialogSettings` identify Dialogue
  UI's public named roots. While a span is active, Offhand translates only
  UIParent-relative anchors on those roots and Dialogue UI-owned direct helper
  frames to its addon-owned Mainhand region. The three presentation roots
  receive the physical-height correction needed to render against Mainhand
  instead of the complete span. After a quest frame-size rebuild, Offhand may
  complete the root height at Dialogue UI's own `frameHeight` target if its
  Unfold animation left the intermediate half-height active. Dialogue UI
  retains ownership of frame size preferences, animation, camera behavior,
  input, and saved settings. The anonymous custom reward tooltip is identified
  only by its distinctive public frame methods and passed to Offhand's existing
  transient-frame bounds clamp after Dialogue UI completes its own layout.
  Offhand does not read or alter the tooltip's item data, comparison state,
  appearance, or owner. Protected or forbidden frames are never adopted.

These names remain the property of their respective owners and are referenced
solely for interoperability. Compatibility is best-effort because third-party
runtime interfaces can change without notice.

### OpenMap scale settings candidate (2026-11-08)

The Offhand map scale control supports the reviewed v0.7.5-beta WindowOptions
contract (API 1/4), active owner and matching module DB. A DB-only setter invokes
its existing scale Apply action, with no mod:Refresh or vendor source edits.
OpenMap retains its 50–160% range and saved anchor/size. Auto Fit stores a fitted
numeric scale in OpenMap rather than a persistent AUTO mode. Other versions and
owners keep their own settings. Synthetic source/ownership tests pass; native
rendering, reload and taint acceptance are pending. See MAP-SCALE-20261108.md.
