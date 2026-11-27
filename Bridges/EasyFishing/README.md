# Built-in EasyFishing Bridge

Built-in Offhand bridge (`Bridges/EasyFishing/Bridge.lua`) that keeps
**EasyFishing**'s skill-up popup and windows on the game monitor. EasyFishing
places them from UIParent's top-centre and centre, which with Offhand is the
seam between monitors. The bridge is inert (no frame, hook or timer) unless
EasyFishing is loaded on the Forever client. It replaces the standalone
`EasyFishingOffhand` addon.

## What it does

- **Skill-up popup:** the unnamed "+1 Fishing" popup (Tackle.lua
  `ShowSkillUp`, default `TOP` on UIParent `TOP 0,-170`, set once) is found
  among UIParent's children on each `CHAT_MSG_SKILL` and anchored to the top
  centre of the game rectangle; it follows the game rectangle afterwards and
  gets EasyFishing's own anchor back when Offhand is not spanned.
- **Session window, indicator and glow preview:** `EasyFishingSessionWindow`
  (`CENTER 330,20`), `EasyFishingIndicator` (`CENTER 0,-90`) and
  `EasyFishingGlow` (`CENTER 0,-60`, preview only) move to the same spot of the
  game rectangle.
- **Cast button and lure badge (secure):** `EasyFishingButton`
  (`CENTER 0,-140`) and `EasyFishingLureBadge` (`CENTER 60,-140`, only when
  there is no cast button) move out of combat only.
- **Settings and debug console:** `EasyFishingSettings` and
  `EasyFishingDebugConsole` (`CENTER 0,0`) move to the game rectangle's centre.
- **Seam scan:** declares the seven named frames above in `placedFrames`, so
  `/offhand scan` reports them as handled by this bridge (the popup is unnamed).

## What it leaves alone

- Any frame the player dragged somewhere else, and the lure badge while it
  hangs off the cast button.
- Messages EasyFishing prints through Blizzard's own error and raid-warning
  frames.

## Diagnostics

`/offhand diag` shows `EasyFishingAnchors=<moved>/<total>` and
`EasyFishingPopup=<times placed>` (`-` until the first skill-up shows the popup).

## Origin and evidence

- Contributed by Kintrok (@DCtheGeek).
- Read against EasyFishing 2.9.6.
- Automated tests pass (tests/bridge-easyfishing.lua). Live Forever QA is pending.
