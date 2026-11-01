# Third-party compatibility boundary

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
  owned bag root and its explicit close state. Offhand does not create objects
  in the `EUI_` namespace.
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
