# Questie and Social placement review, 2026-11-10

Candidate: `codex/questie-social-placement`, based on `a604625`.
Target: Windows Forever 1.60.1.70862, Interface 16001, Questie 12.6.5.
Spanning was applied with Mainhand on the right and workspace on the left.
This work is separate from the prepared Beta 29 release.

## Change

Automatic popup recovery now preserves `Questie_BaseFrame`, `ChatAlertFrame`,
`TextToSpeechButtonFrame` and `QuickJoinToastButton`. These roots retain their
existing positioning owners even when `IsUserPlaced()` is false. Ordinary
popups still use the existing recovery path. No vendor files, native scripts,
visibility, saved-variable schemas or parent relationships are modified.

Social and Quick Join are two presentations of `QuickJoinToastButton`, rather
than two independent buttons. On the observed build its anchor chain is:

`ChatFrame1ButtonFrame -> ChatAlertFrame -> TextToSpeechButtonFrame -> QuickJoinToastButton`

The broad popup scan could detach a root in this chain when its top entered
the area above Mainhand. The fix prevents that write; it does not introduce a
second mover or override another chat addon's layout.

## Evidence

- The reporter's screenshots and frame stack were reviewed. They identify
  QuickJoinToastButton and its FriendsButton/QueueButton children.
- Installed Questie source owns `TrackerLocation`, a lock option and Ctrl-drag
  handling. Its reset placement uses UIParent center coordinates and can have
  a false user-placed flag. The tracker belongs to Questie, not Blizzard Edit
  Mode. To move it, hold Ctrl while dragging, or uncheck Questie's Lock Tracker.
  Questie also provides `/questie tracker reset` for a lost tracker.
- Regression fixtures failed against the old preservation policy for Questie
  and chat roots. The updated fixtures cover linked anchors above Mainhand,
  UIParent scanning, native panel callbacks and deferred scans. Unrelated
  popup recovery remains covered.
- A private live fixture deliberately moved TextToSpeechButtonFrame above
  Mainhand. With baseline Beta 29, Offhand changed its point to CENTER relative
  to UIParent, moving QuickJoinToastButton with it. With the candidate, the
  injected point remained intact through repeated scans and 30 seconds.
  Reload restored the native chat anchor chain. This is a controlled recovery
  reproduction, not proof of the reporter's original trigger.
- Questie Objectives was selected by the user. For testing only, Show Header
  for Empty Tracker was enabled and Lock Tracker disabled. Questie's reset
  recovered its empty header at the seam, and its saved location survived
  reloads. Drag attempts on this empty tracker did not establish successful
  movement, so active-objective dragging is still a manual verification gap.
- EllesmereUIChat and Questie were loaded. Prat, ForeverPlus, OpenMap and
  DaylightUI were not loaded. BugGrabber's historical count stayed at four;
  no new entries were observed. No combat, protected social action, real
  Quick Join invitation, character swap or multi-monitor hardware test ran.

## Validation and sources

All 123 Lua suites passed. All six manifests, 81 runtime Lua files and the
runtime XML references passed path and Lua 5.1 syntax validation.
Candidate HUDCompatibility.lua SHA256:
`26f588dd293e3f331e7c357baabef664cb3e56f3939de9dc95e792a3086fc4a3`.
Private captures and backup maps remain in ignored
`dist/questie-social-20261110/`, outside addon packaging.

Shared knowledge was consulted first. Status and ask/search queries exposed
a stale full-text index and an older pinned Forever snapshot, build 70532 at
`ca8368f2f2380cbe696854f7f2646387c278a61b`. This is a retrieval gap, not
evidence of API absence. The pinned QuickJoinToast.lua and ChatAlertFrameMixin
source corroborate linked native ownership. Build 70862 runtime evidence
adds TextToSpeechButtonFrame to the observed chain.

Installed Questie revision: `0214175640abba697f535b2be73787a4c2f2b32b`.
TrackerBaseFrame.lua SHA256:
`caf80984375709569d6f5f2122e191e5742a42ed8582bfe476d492e95fad21c2`.
QuestieSlash.lua SHA256:
`9794e4b579b042ad6f577d6a859a1ebb3400454bea4aec883ce6aa71bf87c50e`.
These are installed-source findings, distinct from native test results.

Prepared Beta 29 ZIP remains SHA256
`004be4e1fe35dba3bc55f6579ba7d6aa5f5676328fe9c495305f18bbdba9694e`.
No release assets, Companion binaries or Discord messages/statuses changed.

## Cleanup

Desktop input paused after another application appeared over WoW. Final
normal shutdown and backup restoration are pending exclusive desktop access.
The restore baseline preserves the user's Questie Objectives and QuestieTrace
choices, while reverting subsequent tracker QA settings and the private helper.
