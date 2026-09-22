# Client support audit — 2026-09-22

This is a source and automated-test audit, not a claim of live acceptance. The
current branch loads the same runtime modules for every client family; manifest
selection and feature detection choose the client-specific paths.

## Current support state

| Client family | Current manifest targets | Static state | Live state | Main risk before release |
| --- | --- | --- | --- | --- |
| Forever | 1.60.1 (`16001`) | 19 suites and manifest validation pass | Exact 4000x2560 topology, cold launch, disconnect/reconnect recovery, player-click Edit Mode recovery and raw mouse passed | Complete combat/taint, transitions, idle and broad SavedVariables matrix |
| Retail / Mainline | 12.1.5 and retained 12.x targets | Manifest and shared regression suite pass | No current v2.1.2 acceptance | Blizzard Edit Mode layout selection, protected HUD behavior, panel attributes, combined bags and tooltip ownership |
| Classic Era / Hardcore | 1.15.9 and 1.15.8 | Manifest and legacy-layout regressions pass | No current v2.1.2 acceptance | Direct action/stance/pet/XP/reputation anchoring, combat deferral, bags, map and character-specific persistence |
| TBC Anniversary | 2.5.6 | Manifest and legacy-layout regressions pass | No current v2.1.2 acceptance | Same legacy protected-frame path as Era, with branch-specific frame names and status bars |
| Progression Classic / MoP | 5.5.4 plus retained 3.x/4.x/5.x targets | Manifest and shared regressions pass | No current v2.1.2 acceptance | Mixed modern/legacy APIs, Edit Mode presence, bags, maps and panel manager differences |
| Generic fallback | All interfaces above | Load order and file references pass | Not independently accepted | Must not be treated as evidence for an unknown client flavor |

## Public v2.0.0 exposure

The current CurseForge release is v2.0.0 for Retail, MoP Classic, Classic Era
and TBC Anniversary. Forever still receives v1.0.1 there. Source inspection
confirms several high-impact v2.0.0 behaviors that have since changed:

- Fresh v2.0.0 profiles started enabled and could alter the UI before setup;
  current profiles start inert until the Wizard enables them.
- v2.0.0 inferred physical screens from one combined resolution. Current source
  consumes exact Companion rectangles and rejects stale topology.
- v2.0.0 advertised three/four-display selection without stable multi-workspace
  semantics. Current Companion deliberately supports exactly two displays or an
  explicit one-display 32:9 split.
- Current Companion uses stable display identities, refreshes selectors after
  hotplug, restores the selected surviving Mainhand, refuses missing-display
  spans, and disables automatic spanning by default.
- Current shared addon code adds safer display-transition debouncing, combat
  deferral, off-screen recovery, panel reopening, combined-bag persistence,
  exact workspace rectangles and less destructive startup behavior.
- The 2026-09-22 audit additionally fixed disabled/single-screen profiles
  mutating tooltip scale and disabled profiles rewriting bag anchors at logout.

The current source is therefore materially safer than public v2.0.0, but the
shared improvements are not a substitute for client-specific live acceptance.

## Porting classification

Already shared across all clients:

- Exact Companion topology and stale-topology rejection.
- Companion display identity, hotplug refresh, selected-Mainhand restore and
  safe spanning defaults.
- Geometry, display-event debounce, workspace rectangles, panel reachability,
  map/bag/chat persistence, combat queues, onboarding and localization sizing.
- Raw mouse management while an Offhand span is active.
- Disabled and single-screen tooltip/bag ownership guards.

Forever-only by design:

- Complete SavedVariables CVar snapshot/fallback and generated recovery bridge.
- Sustained missing-topology prompts and player-click **Use Modern** / **Restore
  Offhand** protected-layout recovery.
- Forever Edit Mode manager placement and protected-frame exclusion rules.

Requires client-specific validation or adaptation:

- Retail Edit Mode layout creation/selection and protected frame ownership.
- Classic action, stance, pet, possess, XP and reputation bar names/anchors.
- Panel manager attributes and load-on-demand frames on each branch.
- Native and replacement bag APIs, combined bags, world map variants, tooltips
  and arbitrary third-party movable frames.

## Approved beta release path

The user approved preparing one all-client v2.1.2 Beta package so players can
exercise the shared fixes while the live matrix continues. The beta must be
uploaded with CurseForge's **Beta** release type and must not be described as a
stable acceptance of every client or topology.

1. Package every current manifest in `Offhand-v2.1.2-beta.1.zip`.
2. Attach all current supported game versions, including Forever, to the
   CurseForge beta file.
3. Use `docs/CURSEFORGE-v2.1.2-BETA.md` as the file changelog/testing request.
4. Publish Companion v2.1.2 separately on GitHub when authorization is
   available; do not imply that updating only the Companion replaces the addon
   fixes in this beta.
5. Continue the client ladder: Retail, Classic Era/Hardcore, TBC Anniversary,
   then MoP, recording each result independently.
6. Fix only reproduced branch-specific failures, with a regression for each,
   before promoting a later artifact to Release status.

## Minimum manual client ladder

Run each item on a safe character with Lua errors visible. Stop at the first
failure and record the client build, enabled addons, command/action and error.

1. Cold login with an existing v2.0.0 profile; confirm migration preserves the
   profile and does not enable a previously disabled profile.
2. Span with Companion v2.1.2, run `/offhand diag`, then `/reload`.
3. Open, close and reopen map, character, spellbook/talents, bags, chat,
   tooltips, dropdowns, settings and the Offhand panel.
4. Enter combat manually; exercise action, stance/form, pet/possess, XP and
   reputation bars; open bags where allowed; leave combat and verify one clean
   deferred recovery without flicker or blocked-action errors.
5. Change zone through a loading screen, relog, change character, and cold
   restart while checking geometry and SavedVariables after each boundary.
6. Repeat with representative bag/action-bar/map addons before expanding the
   compatibility claim.
