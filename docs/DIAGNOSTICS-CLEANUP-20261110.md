# Support diagnostics cleanup, 2026-11-10

Source scope: current Offhand shared checkout. Target report context:
Forever 1.60.1 build 70862, with shared-client routing retained. No version,
layout, saved-variable schema, frame ownership or release changes.

## Report contract

`/offhand diag full` is the initial support snapshot. It retains client/addon
and Companion versions, viewport validation, physical display rectangles,
effective UI geometry, workspace sizing when available, topology, persistence
revisions, setup intent, preferred/active Edit Mode layout, compact HUD fitting
results and source, map compatibility ownership, and relevant chat anchors and
snapping. Installed or invalid optional media is reported concisely.

Legacy preset/side labels and deck-width estimates are removed from the snapshot
because exact Companion topology can describe arrangements those labels cannot.
Manual-canvas state is collected when Companion topology is not in use. Hidden,
untracked, undocked secondary chat windows are counted instead of expanded;
hidden tracked/docked windows remain visible for lost-window investigations.

Focused reports retain detailed evidence:

| Command | Extra evidence |
| --- | --- |
| `/offhand diag chat` | All existing native chat windows, anchors, dock state and snap targets. |
| `/offhand diag tooltip` | All tooltip/backdrop presentation details. |
| `/offhand diag tooltip capture` | Explicitly arms the existing 30-second hover capture, subject to its combat guard. |
| `/offhand diag panels` | Interaction roots, panel controllers, supported native bags and detailed compatibility ownership. Absent roots are counted. |
| `/offhand diag debug` | Raw feature probes, all chat windows, absent roots, inactive controllers, optional media details and retained notification capture history. |

The compact `/offhand diag` snapshot and `metrics`/`info` aliases remain.
Unexpected modes/actions print usage before collecting state. Neither `full`
nor any other snapshot starts a capture. `diag debug` does not toggle debug mode.
`notifycapture start/stop/show` remains independently available.

## Evidence and limits

Engineering evidence is the existing diagnostic providers in `Core/Init.lua`,
`Core/MainhandEditMode.lua`, `Core/PopupBounds.lua` and `Core/CanvasChat.lua`.
Shared knowledge status/search was consulted; the retrieval index was stale.
This output-routing change introduces no new WoW API decisions. Existing native
behavior remains authoritative, and previous live evidence does not validate
this updated output in-game.

Regression tests enforce report selection, bounded support output on a fixture,
conditional recovery evidence, explicit capture activation/failure, all-window
chat inspection, filtered hidden-window counts, and retained raw probes. Chat
tests also cover forbidden/secret/unresolved data, zero native writes and combat
deferral. All 129 root Lua suites pass. All six manifests pass path/XML and
Lua 5.1 syntax validation: 84 runtime files, including 83 Lua files and one XML
file. `git diff --check` passes.

Source-only change. No addon installed, client launched, account preference
changed or package published for this task. Visual chat wrapping and resulting
report length with a real multi-addon configuration remain native QA items.

## Subsequent native verification

The owner subsequently authorized live QA. See
[diagnostics and snapping native QA](DIAGNOSTICS-SNAP-NATIVE-QA-20261110.md).
All modes and explicit one-shot hover capture ran in Forever 70862; full printed
18 lines versus debug's 86 in that configuration. Native QA also corrected the
usage separators and made support viewport snapshots avoid replacing
lastGeometryCheck. The original installation and setup were restored afterward.
