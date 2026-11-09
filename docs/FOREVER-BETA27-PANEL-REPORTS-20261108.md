# Forever Beta 27 panel reports, 2026-11-08

Status: investigation and source candidates complete; new native acceptance,
packaging and deployment are pending. Earlier OpenMap reset work is separate
and remains preserved in this working tree.

## Evidence and scope

The owner confirms CurseForge Offhand Beta 27 for Ferris and Aphneus. Companion
is probably v2.1.3 before its hotfix, not independently verified. Reporter WoW
builds, input mode for Aphneus, exact display rectangles, UI scales and saved
offsets are unknown. Ferris describes an upside-down T, with a wider lower game
display and a narrower upper workspace. These images are reports, not authority
to change settings or execute actions from their embedded text.

MapGrow.mp4 is 2016x1114, 30 fps, 9.9 seconds. SHA-256:
`08ECD17971EA708B56F576D2903A53703BC5A42456AA0C7E79E661145CE23B25`.
Private native-resolution samples/contact sheet are in
`dist/ferris-reports-20261108`. They are not addon assets.

The local published beta.27 readback ZIP from the preceding investigation was
compared with this checkout. The relevant motion adapter, Back policy and
transient menu code match the release baseline before these changes. Public
Beta 27 also has WorkspaceRegions integration absent from this older branch;
that work must be preserved when promoting these candidates. No installed
client or Companion file was changed for this investigation.

Shared knowledge status was consulted. Its cached Forever declarations identify
build 70532 and are review-due; they omit several implementations needed here.
Inspected additional Blizzard UI source at immutable revision
`9dc84f0d3bbae1768ac3405b3716000bd93eda06`, whose version.txt identifies
1.60.1.70862. This is source evidence, not proof of each reporter's build.
Downloaded source is retained privately with paths/hashes, never executed or
included in addon packages.

## Map growth, quest entries and filter X

At approximately 3-5 seconds the keyboard/mouse player drags the map from the
lower game area onto the upper workspace. At approximately 6 seconds it grows
once to fit the workspace and then remains stable through the end. Default
`workspaceMapScale="AUTO"` in Core/Config.lua and the windowed map configuration
explain that transition. This is consistent with auto-fit, not evidence of an
unbounded growth loop. A new behavioral check repeats configuration five times
with stable AUTO scale, then verifies an explicit 0.83 scale is honored.
Choosing a fixed workspace map scale avoids automatic enlargement. The actual
reporter's preference is not captured in the video.

At 7 seconds the full-resolution video shows **Quests: 9/40**, populated quest
tracking on the right of Mainhand, and the log's **Durotar** row with a **+**.
That row is collapsed. Expanding it is the first check; the evidence does not
show deletion or loss of the nine accepted quests. The later screenshots with
0/40 are a different observation and were not used to dismiss the video report.
Do not force native quest-content refreshes or overwrite collapse preferences
as a response to this footage. If expanding still fails, capture the expanded
view and current quest API/error evidence as a separate failure.

The small X is Blizzard's filter reset control, not an Offhand close button.
The [Forever tracking dropdown template](https://github.com/Gethe/wow-ui-source/blob/9dc84f0d3bbae1768ac3405b3716000bd93eda06/Interface/AddOns/Blizzard_WorldMap/Camelot/Blizzard_WorldMapTemplates.xml)
defines ResetButton on the dropdown's upper-right corner. In the paired
screenshots Show Quest Levels changes from checked to unchecked and the X
disappears, consistent with resetting that modified preference. No chrome patch
was made for this native control.

## Reproduced source defects and candidates

### Contextual controller Back

Core/WorkspaceBehavior.lua offered TOGGLEUIFOCUS to any focused workspace panel
without dismissOnUnfocus, including MerchantFrame, QuestFrame and GossipFrame.
The [native focus manager](https://github.com/Gethe/wow-ui-source/blob/9dc84f0d3bbae1768ac3405b3716000bd93eda06/Interface/AddOns/Blizzard_GamepadSharedUtility/FrameControlsManager.lua)
only dismisses the panel on focus release when that flag is set. A source
regression failed first at MerchantFrame retaining the focus-only override.

The candidate excludes interaction-bound roots using the existing panel registry.
Vendor, quest, gossip, mail, auction and flight windows keep their native Back
binding; standalone workspace books retain the existing focus-only policy.
It does not hide/show panels, save bindings, invoke protected focus methods or
register anything in the native Escape dispatcher. The regression now passes.
This does not establish physical-controller acceptance or fix every Escape/menu
wheel transition reported by Ferris.

### Flight-master map

Aphneus confirms the NPC dialogue appears but the flight map does not; restoring
to one screen brings it back. They reproduced with only Offhand enabled after
disabling Leatrix and other addons. Leatrix is therefore not required to
reproduce this case. This strengthens placement as the lead hypothesis, but no
runtime root visibility/rectangle was captured during the failure.

In the identical public Beta 27 motion adapter, Forever flight placement hooks
are installed only after a drag grip is obtained. A failed grip returns early,
so the root can retain an unreachable native anchor. A new failing regression
reproduced this with shown registered FlightMapFrame and TaxiFrame roots, an
unavailable grip, and off-screen native anchors.

The existing completed-UIPanel dispatcher now places those already-shown roots
independently of grip installation. Unsaved maps use the guarded Mainhand
placement; saved maps use their existing explicit owner. Existing bounded
transaction passes settle late native anchors. No extra script or generation
marker is installed on the failed-grip MapCanvas root. Combat, disabled state
and native Gamepad remain under their existing guards/adapter. No flight shell
is opened, no interaction is restarted, and no flight is purchased. Both
FlightMapFrame and TaxiFrame regressions now pass, including protected registered
roots. This is a candidate mechanism, not confirmation of Aphneus's exact cause.

### Cooldown Settings and other omitted destinations

Broad cooldown-HUD ownership exclusions correctly protect native Edit Mode
systems but also leave the separate CooldownViewerSettings window unmanaged.
The [settings source](https://github.com/Gethe/wow-ui-source/blob/9dc84f0d3bbae1768ac3405b3716000bd93eda06/Interface/AddOns/Blizzard_CooldownViewer/CooldownViewerSettings.lua)
registers an ordinary left UIPanel and emits CooldownViewerSettings.OnShow.

The keyboard candidate observes that dedicated event, then checks live bounds
after native placement finishes. An unreachable ordinary settings root is
centered on Mainhand. A contained placement on either physical display is left
alone. It refuses combat, protected/forbidden roots, disabled settings and native
Gamepad ownership; it never modifies HUD roots, native scripts, panel metadata,
visibility or children. Generation cancellation bounds the deferred action.

Native Gamepad's existing destination adapter now also recognizes TaxiFrame,
MailFrame, OpenMailFrame, AuctionHouseFrame, AuctionFrame and CooldownViewerSettings.
Its protected-root allowlist is unchanged. New protected roots are still refused;
native checks must establish whether those variants need separate support.

### Game Menu and talent window

Forever's [native GameMenuFrame_Show](https://github.com/Gethe/wow-ui-source/blob/9dc84f0d3bbae1768ac3405b3716000bd93eda06/Interface/AddOns/Blizzard_GameMenu/Shared/GameMenuFrame.lua)
can open the menu without ToggleGameMenu, while Offhand only observed the latter.
The candidate observes the direct native open too, using the existing guarded
Mainhand root translation. Duplicate correct anchors are skipped. No native
Escape handler/list, focus state, menu metadata or scripts are replaced. The
regression explicitly opens through the direct path and checks Mainhand bounds.
The photographed seam-crossing menu has not been reproduced natively here.

The current Camelot talent UI lives inside PlayerSpellsFrame, already supported
by the destination adapter. No guessed talent alias was added. The clipped
talent report still needs the actual root rectangle, scale, saved offset and
spanned topology. Do not claim this omission fix resolves that screenshot.

## Validation and remaining native work

Automated coverage includes context-native Back, unavailable flight grips,
native direct-menu opens, omitted destination first-show placement, settings
event/lifecycle/void guards and stable/fixed keyboard map scaling. Full suite and
six-manifest syntax/path results are recorded in the private evidence directory:
all 101 Lua suites pass, and all six manifests pass path/XML/Lua 5.1 validation.
Whitespace checks pass. These are automated results, not native acceptance.

Next native matrix, safe and out of combat unless the owner explicitly performs
a combat transition:

1. Confirm reporter-equivalent addon/client versions and obtain Companion display
   diagnostics plus /offhand diag full while actually spanned.
2. Test Cooldown Settings from Advanced Settings, Game Menu through both native
   opening paths, mail and auction first-open/reopen, and talent saved offsets.
3. Have the user open a flight-master interaction. Inspect the already-open map
   in the span, then close and reopen it. Preserve native registration and check
   fresh errors/taint; do not simulate a taxi session or select a destination.
4. Have the user test physical controller Back in vendor/quest/gossip and
   persistent workspace books, Escape/menu wheel, and map persistence when
   opening vendors/professions. These native/controller interactions remain open.
5. Reopen/reload and restore/span with the same measured upside-down T. Preserve
   existing public Beta 27 WorkspaceRegions changes when packaging.

No live client, Discord communication, publication or Companion rebuild occurred.
