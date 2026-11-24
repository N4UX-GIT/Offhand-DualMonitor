# Compatibility regression baseline

Compatibility is a set of tested behaviors, not a promise that every version of
an addon will work. Keep versions, client builds, topology, mode and remaining
gaps attached to each result. Unit tests protect modeled behavior; actual game
interactions and a final package test protect the parts those models cannot
exercise.

## Checks used for every addon change

From the repository root:

```powershell
python -m unittest discover -s tests -p test_compatibility_check.py -v
python scripts/check-compatibility.py --report dist/compatibility-check.json
```

The portable command follows all six manifests and nested XML loads, rejects
duplicate, missing or external paths, checks Lua 5.1 syntax and runs every Lua
suite in tests. CI runs the manifest/freshness checker and its tests, then runs
all Lua suites through the existing CI step.

These checks catch the duplicate-file TOC warning reported earlier, known
ownership regressions covered by the Lua tests, and stale live evidence. They
do not launch WoW or manufacture a live pass.

Before a live run:

```powershell
python scripts/check-compatibility.py --skip-lua-tests --installed 'C:/Games/World of Warcraft/_forever_/Interface/AddOns/Offhand'
```

Only the known Companion-generated ForeverState and CompanionTopology files
are excluded from the installed-source comparison. A mismatch exits with a
failure so a mixed local install cannot be silently described as this branch.
Reconcile the intended build before testing. Preserve deliberate changes from
other branches; do not overwrite the entire installed addon as a shortcut.

Before promoting the affected compatibility scope:

```powershell
python scripts/check-compatibility.py --require-fresh-live
```

Receipts in tests/compatibility record normalized UTF-8/LF source fingerprints
from the tested installation. Source changes make their live evidence stale.
Ordinary CI reports that separately from automated failures; the explicit
freshness check fails until the affected cases are rerun. Updating fingerprints
without a new matching live run does not renew evidence. Deferred cases remain
deferred even when the fingerprints match.

The November 23 release receipts (`tests/compatibility/forever-native-real-escape.json`
and `tests/compatibility/forever-workspace-restart.json`) record Beta 39 on
Forever `1.60.1.71037` with Store Companion `2.1.9-beta.2`. On the Beta 40
candidate (which adds Forever outdoor map zone following and Learned Addon
Windows), both receipts are currently stale on changed runtime files and
require a fresh live run before promotion (`--require-fresh-live`).
Outdoor zone map following (native Blizzard map + OpenMap 0.8.13) and
multi-page book turning have separate Nov 24 live runs on Forever `1.60.1.71037`
([MAP-ZONE-FOLLOW-QA.md](MAP-ZONE-FOLLOW-QA.md) and the book section below).

## Workspace restoration after a full restart

A player's open map, bags and other eligible workspace panels must return to
Offhand when the workspace becomes available. A one-screen login must preserve
that choice until the player spans WoW. A saved position alone must leave a
closed panel closed. Interaction windows such as NPC gossip require a new
interaction.

Beta 38 commit `2fdb2d4` used the UI reload flag to request a native map
open and recover separate bag IDs on Forever. A fresh login did not set that
flag. The delayed display-size handler performed ordinary layout without
the reopen request. Single-screen recovery could also interpret a hidden map
or bag as a player close. The current code keeps the request until the first
usable workspace and preserves the last spanned visibility through recovery.

`tests/forever-workspace-restart.lua` exercises the real logout, entry and
display handlers with fresh frames and fresh addon state. The saved tables
cross the simulated restart. The suite covers both span timings and mixed
open and closed windows. Existing provider suites cover separate bag IDs,
external map ownership and explicit closes.

For release QA, quit with the map, backpack and Character open on Offhand
and a fourth saved panel closed. Relaunch from Battle.net, log in on one
screen, then apply the span. Check all four panels before touching a key or
reloading, and inspect BugSack for the session. Record the actual bag and map
providers and Companion build. Repeat for changes to Companion window spanning
as well as relevant addon changes. The restart receipt fingerprints the tested
addon sources. CI checks its freshness on pull requests to main. The live run
used OpenMap and combined bags. [November 23 restart results](FOREVER-BETA38-BAG-MAP-QA-20261121.md#full-client-restart-with-the-span-applied-after-login-on-november-23).

## Forever bag scope recorded through November 18, 2026

The rows below describe the local candidates reviewed in Offhand PR #129.
They do not claim that published Beta 36 includes those fixes. Earlier
provider traces and source studies are retained in the shared knowledge
project, knowledge/offhand-forever-bag-compatibility-20261117.md.

| Provider and tested version | Verified behavior | Remaining scope |
| --- | --- | --- |
| Native, Forever 70959 | Separate/combined target-clearing Escape; B and Shift-B toggles; window-first Escape; real NPC gossip and player inspection with the separate backpack on Offhand | Other equipped bags, combat, flight paths, other clients |
| Native, Forever 71037, `43b419e` | Separate backpack with real NPC gossip, native and early-opening Inspect. B closed the open backpack during player-operated combat. | In-combat Escape, other equipped bags and flight paths |
| Forever Bag Mover 0.8.0 | Vendor-saved Offhand placement; B/Shift-B using the same action; separate/combined Escape with special-window and native-panel fixtures | Actual NPC/inspection with that modifier enabled; conflicting vendor/Offhand positions |
| FlareUI 6.11, Bags active | Target-clearing Escape, explicit B close/reopen; OneForAll on/off | Full suite combinations and real interaction callbacks |
| Baganator 862 | First Escape target clearing, explicit close/reopen; earlier verified Options and restart persistence | Flight paths, combat, every layout/profile combination |
| Bagnon 12.1.11 | Offhand placement/reachability, target-clearing Escape and explicit B | Every optional module/profile combination |
| ArkInventory 3.12.17 | Target-clearing Escape and explicit B | Every rules/profile/module combination |
| BetterBags 0.9.5 | Classic and Next small Escape and explicit B | Next full Escape and other modes |
| BagSmith 1.9.0 | Offhand placement, target-clearing Escape and explicit B | Other replacement settings/profiles |
| ElvUI 16.01 | Target-clearing Escape, explicit B, Options, Mainhand dismissal control | Other full UI module combinations |
| DaylightUI Bags 1.9.3 | Target-clearing Escape and explicit B | Other full UI module combinations |
| DaylightUI replacement Spellbook, Talents and Trainer (Forever) — **placement resolved** | Moonweaver, build 71037, DaylightUI 2.2.3, Companion 2.1.9-beta.2, local development add-on, November 23. Naeluna Swiftmend's training list stayed visible with 184 services through Span and Restore. Spellbook and Talents remained reachable in both layouts, with zero BugSack errors in those checks. The parked native frames had 0.001 relative scale. The visible replacements retained normal scale. | Spanning with the trainer list open triggered a DaylightUI NPC repaint error at `Npc/Window.lua:380` (missing `choices`). Reproduced with the Offhand add-on disabled. The owner closed the placement report after live verification on Moonweaver. Moonweaver had zero talent points. Spending points and purchasing training were outside this placement check. [Report](https://discord.com/channels/1491522138371391691/1573894857351503973) |
| EllesmereUI Bags 9.8.9 | Target-clearing Escape and explicit B; another vendor-registered window retains priority | Detached reagent window and other full UI modules |
| AdiBags | No Forever live pass recorded | Identify a compatible Forever build or fork before claiming support |

Flight paths remain deferred. The 71037 combat result covers the native
backpack toggle. OneForAll
independence is directly verified for native separate/combined, FlareUI and
representative Baganator controls. Do not infer that every provider combination
was rerun with OneForAll disabled.

Actual NPC and inspection results:
[November 18 QA](FOREVER-BAG-ESCAPE-QA-20261118.md).

The November 21 retest reproduced early target clearing when Inspect was
visible outside both window registries. The corrected package passed that
case, ordinary portrait-menu inspection and real NPC gossip.
[November 21 native backpack retest](FOREVER-BAG-ESCAPE-QA-20261121.md).

For Moonweaver's Beta 39 tests with the native map and separate bags, see the
[November 23 release checks](FOREVER-BETA39-RELEASE-QA.md).

For out-of-combat Escape with an empty target, separate satchel placement,
Baganator and OpenMap reload behavior on the public Beta 38, Discord
`178bf64` and the local candidate, see the
[Beta 38 comparison](FOREVER-BETA38-BAG-MAP-QA-20261121.md).

For the crafting Escape handler, expanded Spellbook, and isolated Bagnon,
BetterBags, Bagnaros and Baganator checks on build 71037, see the
[November 21 Forever QA](FOREVER-CRAFTING-BAG-ESCAPE-QA-20261121.md).

### Inventory tooltip crossing the display boundary — resolved

Nin reported that an item tooltip crossed onto Mainhand while hovering a bag on Offhand. In live Forever testing with Baganator 854, the entire Hearthstone tooltip stayed on Offhand with the slot center about 37 physical pixels from the split. Beta 38 includes the tooltip placement fix. The owner closed the report on November 23 based on local verification. Nin's exact setup was unconfirmed at closure. [Discord report](https://discord.com/channels/1491522138371391691/1571130196268945538)

## Preserve the baseline when changing compatibility

- Add a regression case for the reported failure and a control for the behavior
  that must remain intact, such as explicit B/X close, Mainhand dismissal,
  another window's Escape priority, or feature disable.
- Keep provider adapters narrow. Verify frame identity, parent and capabilities,
  yield when they do not match, and avoid native item ancestry or shared secure
  dispatcher mutation. Unknown provider versions need a fresh check.
- Retest affected providers and one neighboring provider after shared-controller
  changes. Include OneForAll on/off when its interaction is relevant.
- Keep bag opening by the player separate from automatic vendor opening.
  Test the actual interaction reported by the user. A fixture alone cannot
  establish NPC, merchant, inspection, combat or flight behavior.
- Capture observer activation, timestamps, before/after state, position,
  effective visibility and current blocked/forbidden errors. Reject missing
  samples and expired traces. Keep names, GUIDs and private chat out of receipts.
- Combine the reviewed fixes on an integration candidate and test that exact
  ZIP with existing SavedVariables before release. Record the candidate ID and
  ZIP hash. Keep a known working package available for rollback.
- Promote narrow results into additional component receipts for maps, panels,
  tooltips, chat/HUD and topology as those scopes are verified. This initial
  bag receipt does not certify those other areas.

Required CI checks and a staged beta rollout are useful additional release
controls. Repository hosting settings and publication behavior were not changed
by this work.

## Forever error and quest-progress text

On November 21, 2026, a clean `71d6ae4` simulation of the reported
5118 × 1347 manual span placed `UIErrorsFrame` 60 UI units below the top
of Mainhand. Blizzard's native top inset was 122. The fix preserves the
frame's own top offset when switching its reference from UIParent to Mainhand.

Live QA used Forever 1.60.1.71037 and Companion 2.1.9-beta.1. With Offhand
disabled, the native inset measured 122. The packaged fix measured 122 with
Mainhand on the right using Companion geometry, on the left using a manual
half-width layout, and after returning to one window. Horizontal center
error rounded to zero in each case. Red error and yellow information previews
used Blizzard's event handler with the same two messages on each layout.
Toggling seam redirection, reloading the UI and scaling the message frame to
80% preserved the inset. An explicit anchor to the minimap survived realignment.
BugSack recorded zero new errors. The reporter used build 70959. Actual quest
progress and raid encounters remain outside this measurement.

### Books and readable items on Offhand

The [Discord book report](https://discord.com/channels/1491522138371391691/1573966761651470457) did not specify the WoW flavor or build. Before the correction, the Lua panel fixture reproduced both the lost native reading interaction after a workspace drag and an empty reader reopening from a stale saved flag. The archived Blizzard 9.2.7 ItemTextFrame XML calls CloseItemText on hide. The corrected fixture keeps the native panel slot and saved position, clears the old open flag and waits for the next book interaction. The lifecycle fixture also checks logout while the reader is visible.

**Passed on Forever 1.60.1.71037 on 24 November 2026.** Moonweaver opened *Bloody Note* in Shen'dar Highlands with the Companion span active. Page one and the Next button were visible on Mainhand. The player dragged the title onto Offhand, confirmed that turning the page changed the text, then closed and reopened the note at its saved spot. BugSack had zero entries in session 1014.

The player reloaded with the note open. At 04:20:04 the observer found the reader hidden, its open flag clear and its saved position intact at (705.52, 980.38) in workspace coordinates. After the player interacted with the note again, the 04:20:13 sample showed page one visible on Offhand with the same saved position. BugSack recorded zero entries in session 1015. The installed addon matched the checkout with runtime commit `8f7cef2`. The note was left open.

An earlier Forever check with Store Companion 2.1.9-beta.2 also exercised migration of a stale open flag. A local observer supplied the flag and a workspace position to the reload routine. The routine cleared the flag, kept the reader hidden and retained the position, with zero current-session BugSack errors.
