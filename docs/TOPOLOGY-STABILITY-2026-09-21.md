# Display Topology Stability

This document maps the September 2026 user reports to the topology work that
replaced combined-resolution guessing.

## Resolved reports

| Report | Root cause | Resolution |
| --- | --- | --- |
| One 49-inch 32:9 display | A 5120x1440 window was indistinguishable from two 2560x1440 displays. | Companion has an explicit one-display 32:9/32:10 split with selectable game side. |
| 32:9 game display plus another monitor | The addon capped the game model at 21:9 and inferred widths from the total window. | Explicit Mainhand role passes the entire native 32:9 rectangle to the viewport. |
| Dual Landscape opened as Portrait Right | Presets and aspect heuristics could overwrite the user's intended physical roles. | Companion owns stable Mainhand/workspace roles; exact rectangles are authoritative and manual guess controls are disabled when present. |
| Stacked screens adjusted left/right | Canvas, panel clamps, bags, chat, and the seam guide assumed a horizontal split. | All workspace consumers use `left`, `bottom`, `right`, and `top`; the guide changes orientation automatically. |
| Workspace occupied part of Mainhand | One deck-width ratio could not represent offset or unequal monitors. | Workspace is the exact second-screen rectangle rather than a percentage of the union. |
| 1440p + 1080p scaling wrong | The union height was mistaken for both displays' usable height. | Game and workspace retain independent native widths, heights, and vertical offsets. |
| Disconnected second screen produced tiny UI | Invalid saved indices were silently discarded, allowing a one-monitor span with dual-monitor addon settings. | Saved Windows display identities are all required; missing screens abort span and stale addon topology resets to a full-window viewport. |
| Ultrawide Mainhand was squashed or letterboxed | Only 16:9/21:9 guessed viewport sizes were available. | Exact Mainhand rectangle is rendered natively, including 32:9. |
| Black bars required a game-height control | Bottom anchoring and a guessed aspect ratio placed a smaller game rectangle inside the union. | Mainhand position and height come directly from Windows display geometry. Legacy manual controls remain only when no Companion topology exists. |

## Supported topology contract

- Normal mode: exactly two selected physical displays and one explicit
  Mainhand. The other display is the workspace.
- Super-ultrawide mode: exactly one selected display, explicit split enabled,
  and a selected game side. The split is currently equal halves.
- More than two selected displays are rejected rather than guessed.
- A saved display that is unavailable is rejected rather than filtered out.
- Display identities use `Screen.DeviceName`; Windows list indices are retained
  only for one-time backward-compatible migration when every old index exists.
- The Companion writes `Core/CompanionTopology.lua`. The addon accepts it only
  when its dimensions and rectangles match the current physical WoW canvas.

## Automated matrix

The C# preference tests cover stable identities after list reordering, missing
display rejection, more-than-two rejection, negative coordinates, unequal
side-by-side sizes, stacked sizes, and one-screen split. Lua geometry tests
cover exact mixed-height side-by-side geometry, exact stacked geometry, and
stale-topology fail-safe behavior. The full addon test suite and TOC validator
must pass before packaging.

## Live QA still required

Automated tests cannot prove how a specific Windows driver, DPI configuration,
or WoW client build reports its final render surface. Before release, perform:

1. Forever cold launch with the tested portrait + landscape pair.
2. Side-by-side 1440p + 1080p in both Mainhand orders.
3. Stacked displays with Mainhand above, then below.
4. A 32:9 single-display split, both game sides.
5. A 32:9 Mainhand plus separate workspace display.
6. Disconnect the saved workspace display, launch WoW, and confirm no span and
   a normal readable full-window UI.
7. Reconnect it, span, `/reload` if already logged in, and verify workspace
   positions normalize into the new rectangle.
8. Forever Blizzard Edit Mode: save/select `Offhand`, close/reopen Edit Mode,
   then cold launch and confirm its options frame stays in Mainhand.
