# Chat displacement after Edit Mode with snapping

2026-11-10. Investigation of the supplied WhoAmI reports. The reported workaround
is credible, but the exact offending saved anchor and frame writer are not yet
captured. No native reproduction or complete chat-placement fix is claimed.

## Report evidence

- Forever 1.60.1 build 70862, interface 16001, Offhand 2.1.5-beta.28.
- Reporter explicitly says there is no chat addon.
- Topology is READY with viewport bounds PASS, schema 1, expected/live physical
  canvas 3440x2640. Mainhand is 3440x1440 at (0,0); workspace is 1920x1200 at
  (744,1440). The exact bridge describes a stacked arrangement despite the legacy
  preset/RIGHT label. Do not interpret that label as proof of side-by-side screens.
- Reported effective scale is 0.355. Active/preferred generated layout ID 6
  matches; recovery=none.
- In Edit Mode, chat is visible at the intended lower-left position. After exit
  and reopening, only a sliver near the top-left remains. The reporter explicitly
  says disabling snapping helped.
- An earlier message says extra chat windows disappear. That may involve
  detached/docked window visibility or another anchor; it is not automatically
  the same defect as primary chat displacement.

The supplied diagnostics do not include ChatFrame anchors, snap targets, native
chat docking state or a before/after saved layout payload. Tooltip bounds and a
PASS viewport do not prove the chat anchor is valid. Neither a corrupted monitor
identity nor a confirmed Blizzard-only defect follows from these screenshots.

## Source evidence

First-line shared knowledge README/skill/status consulted; stale search index
rebuilt and Forever queries run. Its pinned selection lacks the required native
Edit Mode implementation, so exact-build upstream source was inspected directly.
Pinned Forever 70862 revision: 9dc84f0d3bbae1768ac3405b3716000bd93eda06.

- [Native systems](https://github.com/Gethe/wow-ui-source/blob/9dc84f0d3bbae1768ac3405b3716000bd93eda06/Interface/AddOns/Blizzard_EditMode/Shared/EditModeSystemTemplates.lua):
  OnDragStop applies magnetism when snapping is enabled; SnapToFrame establishes
  an actual relative-frame anchor. SetPointOverride tracks that target, and
  native visibility/size/position changes can affect dependent systems. Native
  movement keys clear the snap and commit a standalone position.
- [Native manager](https://github.com/Gethe/wow-ui-source/blob/9dc84f0d3bbae1768ac3405b3716000bd93eda06/Interface/AddOns/Blizzard_EditMode/Shared/EditModeManager.lua):
  SetEnableSnap changes runtime snapping and preview visibility. The user-input
  path persists EnableSnap through the account setting API. It does not iterate
  existing links or detach already snapped systems.
- [Native chat](https://github.com/Gethe/wow-ui-source/blob/9dc84f0d3bbae1768ac3405b3716000bd93eda06/Interface/AddOns/Blizzard_ChatFrameBase/Mainline/FloatingChatFrame.lua):
  primary/default chat restoration belongs to Edit Mode; detached chat has its
  own legacy saved position/dimensions path. Those are distinct state owners.

This supports a snapped-anchor dependency as a leading hypothesis, especially
given the workaround. It does not identify the reporter's target, prove a scale
conversion defect, or eliminate a second addon/native writer. Current Offhand
source largely yields primary Forever chat to Edit Mode and preserves native
links in generated copies. Do not break all links or regenerate a custom layout
as an automatic response to this report.

## Changes made

Added read-only chat placement diagnostics. /offhand diag full reports relevant
windows and /offhand diag chat includes every existing ChatFrame1 through
ChatFrame10. They report runtime Edit Mode/snap state and, for each window:
shown/docked/editing flags, native snap target, parent, rectangle with explicit
coordinate labels, effective scale, saved Offhand region and up to two live
anchors. Hidden tracked or docked windows remain in the full report; other
hidden extras are counted and available through /offhand diag chat. No chat contents/titles, network
messages, layout writes, frame hooks or preference changes are introduced.
Forbidden/unresolved/secret values yield safely; combat defers the capture.

Added the workaround to the existing HUD setup help in all 11 locales: if chat
jumps after Edit Mode, turn off Snap to Elements, reposition chat and save.
Existing help sizing uses measured wrapped text. This preserves layout/settings
ownership and gives a visible remedy without silently changing an account-wide
preference.

Automatic setup-only snap suppression is not implemented. It would miss later
ordinary Edit Mode adjustments, and switching the flag off does not repair an
existing link. A future temporary mode needs explicit scope, original-value
restoration, user-change ownership, reload/abort handling and native safety QA.
Do not hook or rewrite protected native manager state merely to force the box off.

## Validation and next capture

All 129 Lua suites pass, including the new chat-snap-diagnostics regression for
hidden extras, offscreen/dependent anchors, secret/forbidden/unresolved data,
zero frame writes and combat deferral. Locale parity and wizard layout tests
pass. Six-manifest Lua 5.1 syntax/path/XML validation passes. This is source and
simulated evidence; the new diagnostic/help changes have not been installed or
verified natively. No client was launched, user profile changed or release made.

For a candidate containing the diagnostics, capture /offhand diag full once for
the setup context. Capture /offhand diag chat before
editing, after moving chat while Edit Mode remains open, and after Save/exit and
reopening. Repeat with snapping disabled and a small actual reposition before
saving; merely clearing the checkbox is insufficient to remove a prior link.
Compare the ChatFrame1 snap target/live relative anchor, the named target's
layout, and any saved Offhand record. Repeat separately for the disappearing
extra window and identify its ChatFrame number and dock membership. Preserve
the original source and generated-layout backups throughout.

Private ignored upstream/evidence folder: dist/chat-snap-investigation-20261110.

## Subsequent controlled native test

See [diagnostics and snapping native QA](DIAGNOSTICS-SNAP-NATIVE-QA-20261110.md).
On Forever 70862, a temporary copied layout and native SnapToFrame control
confirmed that a chat-to-action-bar anchor survives disabling the native snap
checkbox. A native one-step reposition detached it, and the independent anchor
survived Save/exit/reload. The controlled link did not jump offscreen. Mouse
dragging was not reliable through the harness, and the reporter's stacked
topology remains untested. Original layouts and the snapping preference were
restored. This confirms the mechanism behind the repositioning workaround,
without establishing the original report's root cause.
