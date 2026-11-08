# Addon Escape and Kerzo chrome follow-up, 7 November 2026

Test12 addresses Mort's test11 settings-window Escape and Kerzo top-right X
reports. Target: Forever 1.60.1.70862, keyboard input.

## Implementation plan and resulting changes

1. Preserve Forever's Blizzard panel-manager guard. The installed DungeonJournal
   is ForeverDungeonJournal 1.7.2, not Blizzard EncounterJournal.
2. Load CanvasAddonEscape before Canvas in all six TOCs. Use the existing
   persistence lifecycle and half-second ticker to filter only supported, shown
   UIParent roots on the workspace when persistentWorkspacePanels is enabled.
3. Recognize Leatrix's session-random names using UISpecialFrames, readable
   GetSourceLocation metadata and the reviewed configuration-panel structure.
   Check issecretvalue before inspecting metadata. Platynator also needs its
   settings prefix, Main.lua source, Tabs and CloseButton. Offhand uses its own
   settings getter; DungeonJournal uses its exact loaded-addon/root pair.
4. Keep weak side-table state. Return removed registrations on Mainhand, explicit
   closure, disable, unspan, controller ownership or preference opt-out. Respect
   reinsertion/replacement; defer mutations in combat. Never change vendor scripts,
   geometry, visibility, saved variables, UIPanelWindows or global close functions.
   Never force a window to reopen. No vendor hooks or new ticker are installed.
5. Discover KerzosQuestLog in WorkspaceChrome. Its inherited CloseButton now hides
   alpha/mouse input reversibly. The separate bottom Close button stays available.

Discovery is bounded to 256 registry entries and 64 roots. Missing, secret,
inaccessible or changed metadata fails closed. This does not support arbitrary
addon windows. Ordinary show/drag changes settle on the half-second ticker;
QA explicitly refreshed the adapter before the first Escape.

## Authoritative local source

| Addon | Version | Reviewed construction/registration |
| --- | --- | --- |
| Leatrix Maps | 1.60.28 | Leatrix_Maps.lua:5043 side; :6035 main |
| Leatrix Plus | 1.60.29 | Leatrix_Plus.lua:16572 side; :17161 main |
| Leatrix Sounds | 1.60.27 | Leatrix_Sounds.lua:342 browser/settings root |
| Platynator | 541 | CustomiseDialog/Main.lua:575; ImportDialog.lua:9 excluded |
| ForeverDungeonJournal | 1.7.2 | Core/Journal.lua:8997; :10527 Escape registration |
| Kerzo Classic Quest Log | 6.1.4 | nucleo/inicio.xml:3 ButtonFrameTemplate |
| Offhand | Beta26 candidate | UI/Options.lua floating root/getter |

Plus report/help/mute/info-card roots, Platynator import/confirmation dialogs,
Blizzard EncounterJournal and unrelated windows retain native handling. No vendor
code or assets are bundled. Source hashes remain in the private verification receipt.

Shared knowledge README, skill, status and UISpecialFrames/API queries were used.
The pinned corpus is review-due and lacks a Leatrix settings study. Exact-build
[GetSourceLocation declarations](https://github.com/Gethe/wow-ui-source/blob/9dc84f0d3bbae1768ac3405b3716000bd93eda06/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleScriptRegionAPIDocumentation.lua#L293)
allow secret ObjectDebug returns. Native samples confirmed readable Interface/AddOns
paths here. Factory wrappers can change the source and make discovery yield.

## Verification and limitations

Both regressions fail before their fixes. All 97 Lua suites and six manifests pass
with Lua 5.1. Simulations cover main/side settings, modal/native exclusions,
spoofed/missing/secret/erroring metadata, unsafe/child roots, bounded discovery,
late load/reinsertion, explicit close, Mainhand, preference/disable/unspan/transition/
client/controller/combat gates and duplicate prevention. Inactive clients/missing
config do not inspect viewport geometry. These are not combat/taint acceptance.

Live QA: idle level-one character; ordinary 2114x1353 canvas; temporary remembered
50/50 split, game right. No combat, controller, movement, progression or messages.
Existing OpenMap, ForeverPlus and EllesmereUI remained enabled. Platynator's
coexistence warning was dismissed for settings QA; nameplates were not tested.

- Maps, Plus, Sounds, Platynator, DungeonJournal and Offhand main roots stay open
  on the workspace while physical Escape opens the Game Menu.
- Maps returns to Escape closure on Mainhand after the existing Game Menu is
  dismissed. Plus's actual X closes its root and it stays closed.
- Platynator import dismisses with Escape while the workspace settings stay open.
  Existing Game Menu/input focus keeps its native dismissal priority.
- Kerzo's X changes from alpha 1/mouse enabled to alpha 0/mouse disabled on the
  workspace, restores on Mainhand, hides again on return and restores on opt-out.
  Its actual X then closes the quest log without reopening it.
- After reload, Maps/Plus get different random names, are rediscovered and again
  survive Escape. Final adapter bytes were loaded for this pass.

The first private harness attempted a disabled Maps slash handler, producing one
harness-only error with five occurrences. Maps was then enabled temporarily and
the harness corrected. BugGrabber has zero new product errors or extra historical
product-error occurrences. Side pages are source/simulation covered; native
acceptance above covers main roots. Combat, controller, alternate skins and the
exact reporter configuration remain untested.

Cleanup: client closed, Battle.net left open. Fifteen original state/config files,
character addon enablement and both generated bridges restored byte for byte.
Fourteen created state files and the QA addon moved to private evidence. Installed
vendor addons remain. No private logs, QA addons or research caches are packaged.
Test11 stays unchanged for rollback. Test12 is private; Complete retains frozen
Beta20 Companion. No publication or Discord issue closure.
