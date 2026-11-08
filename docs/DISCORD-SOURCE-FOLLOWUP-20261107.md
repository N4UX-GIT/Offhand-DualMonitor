# Discord source follow-up, 7 November 2026

## Implemented candidate: ForeverPlus warning placement

The warning report's screenshot identifies `ForeverPlus/Core/Warnings.lua:105`
and shows a warning at the monitor seam while native Gamepad UI is active.
The exact reporter vendor version and warning lifecycle are not supplied.
Installed vendor source is ForeverPlus 1.0.6, read without modification.

Its public `PlaceAsBar` method at lines 166-174 replays defaults against the full
UIParent center with a height-proportional offset. `RedrawBars` at lines 371-373
calls it before drawing each bar. Saved `bar.positioned` overrides that default.
Live warning roots are anonymous, noninteractive UIParent children created by
`DisplayFor` at line 308. The interactive mover is separately owned. These
contracts reproduce a source gap: default warning placement still targets the
entire span, while generic popup rescue is intentionally disabled for native
Gamepad navigation. A generic periodic writer would also compete with redraw.

`Core/ForeverPlusWarnings.lua` posthooks that public layout method once per
vendor namespace. It observes only unprotected, noninteractive direct UIParent
roots, then maps their unpositioned default center and proportional height into
Mainhand. An explicit saved position, user placement, alternate anchor or mover
preview retains vendor ownership. Native Gamepad focus is untouched. Combat
defers correction until the existing HUD cadence can run out of combat.

State stays in weak side tables. No vendor scripts, saved positions, visibility,
input handlers, secure attributes, icon children or textures are changed.
Feature-off, unspan and Offhand disable restore only still-owned anchors.
Generic rescue and panel movement yield observed vendor bars. The module loads
on all manifests but installs only for Forever with the supported vendor method.

The regression fails its Mainhand assertion with the correction intentionally
absent. Candidate coverage passes for native redraw, native Gamepad context,
stable no-op, explicit positions, mover exclusion, disable/Restore, intervening
external anchors, combat deferral and differing effective scales. All 92 Lua
suites and six path/XML/Lua 5.1 manifest checks pass. This is source/simulated
acceptance, not a claim that the screenshot's exact warning is fixed in-game.
Real warning visibility, repeated vendor redraw, physical controller focus,
combat and reporter acceptance remain pending.

Final scale review also covers unequal frame/UIParent scales: only Mainhand's
center crosses that scale boundary. The native warning offset is already in
frame coordinates and retains its proportional height without a second scale
conversion.

## Other source investigations

- Whisper Messenger v2.1.4 registers `WhisperMessengerWindow` in UISpecialFrames
  from `UI/MessengerWindow/ChromeBuilder.lua:115-124` and owns its own drag and
  Escape-order scripts. The supplied block dialog names WhisperMessenger, but
  supplies no blocked function or stack. Source includes a separate secure
  reply button; its existence does not attribute the report to that path or
  Offhand. No speculative focus/secure-handler patch was added.
- Current native chat source already yields positive Combat Log dock ownership
  and primary button-side layout. The native/Better Forever Chat report still
  needs its exact incoming-message and Edit Mode sequence. Installed Ellesmere
  chat ownership makes that a distinct compatibility context.
- Ellesmere's active profile accessor and `profile.chatBubbles.enabled` match
  Offhand's existing read-only ownership probe. That probe applies to bubble
  visuals. Engine damage/XP scale is independently controlled. No shared root
  or vendor frame was changed without a reproduced remaining conflict.
- Named Ellesmere player aura roots retain test5's external-owner exclusion.
  Naowh is not installed and the flashing root name remains unknown. A stronger
  claim needs the reporter's actual frame/profile, not an arbitrary larger name
  exclusion.
- Zygor source is unavailable locally. Its existing bounded read-only guide
  diagnostics remain the next step. No unofficial vendor mirror or guessed
  frame name was used to implement a fix.
- Linux native Wayland and the connected-disabled-TV identity case remain
  target-environment investigations. Windows source/smoke checks do not close
  those reports.

## Available client smoke: Forever 70862, installed test5

Battle.net supplied 1.60.1 build 70862. Its exact upstream revision is
`9dc84f0d3bbae1768ac3405b3716000bd93eda06`. Guild invite, StaticPopup,
FloatingChatFrame, UIParentPanelManager and BuffFrame XML match the researched
70790 revision byte-for-byte. Shared status/query returned guidance only for
the new vendor adapter; installed vendor source is the implementation evidence.

The existing level 1 Shaman QA character in Durotar loads. Active Companion
2.1.3 Beta 6 spans and restores the native window, and a spanned `/reload`
completes. Native Chat Settings opens from the General tab menu, survives the
span/restore sequence and responds to its Combat Log tab after restoration.
Placement while spanning was not conclusively captured because computer-use
screenshots expose only primary-monitor pixels. Its exact Mainhand anchor,
reopen while spanned and guild/controller acceptance remain open.

Whisper Messenger opens through its own `/wmsg` command and closes with Escape
without an observed error in the unspanned keyboard path. No test messages were
sent. Incoming-message and native controller behavior remain unverified.

A `/run` inspection attempt presented WoW's custom-script security prompt.
The prompt was declined; custom scripts were not enabled. Normal UI controls
were used instead, and no diagnostic script result is claimed.

BugGrabber messages and counters are unchanged from the pre-run backup; only
the session number changes. Public Companion preferences are byte-identical.
The window was restored and both QA applications closed; Battle.net remains
open. Existing HUD selection was retained at recovery prompts. The new warning
adapter was not present in this test5 runtime.

## Test6 package and next acceptance

The addon-only test6 archive contains the prior combined candidate and this
adapter. The Complete archive retains public Beta 20 Companion. Source TOCs
remain Beta 26; only staged TOCs carry the test6 identifier. Both are private
test candidates, not published releases. The package receipt records frozen
source and runtime hashes. Existing generated topology/recovery bridges must
be preserved during installation.

Built `dist/Offhand-v2.1.2-beta.26-forever-discord.test6.zip` and the matching
Complete ZIP from a 417-file frozen source snapshot. All 92 suites and six
manifest checks also pass against extracted runtime. The package contains 80
runtime entries. Installed 78 files into the local Forever addon, preserving
the two generated bridges and backing up test5 at
`dist/forever-discord-test6-20261107/installed-test5-backup`. The new adapter has
not been exercised in a live client. Receipt and install checklist are in
`dist/forever-discord-test6-20261107/`.

For ForeverPlus 1.0.6, compare a default warning with rerouting on/off, vendor
redraw, explicit bar movement, Restore and reload. Confirm saved positions are
unchanged. Use a manual tester for real buffs/consumables, combat and physical
controller input. A warning already positioned with ForeverPlus should stay
where its owner placed it.
