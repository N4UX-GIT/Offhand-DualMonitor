# Initial custom workspace region prototype

2 November 2026. Explicitly authorized initial runtime implementation on
`codex/custom-workspace-regions`, based on prepared Companion source `a4684a1`.
This overrides the previous deferral for stage 0 only. Unpublished; schema 2,
multiple workspaces and general discontiguous regions remain outside this slice.

## Implemented workflow

Open **Custom region...** in Companion. Choose one display, enable the
experimental custom region, set occupied WoW width and workspace width in
physical pixels, select the occupied monitor edge and game side, and review
the game/free widths. **Save plan** atomically saves settings without resizing
WoW. **Span WoW Now** applies the plan. Select **Use Companion** in the addon's
Window Setup; reload a character UI that was already loaded when geometry changed.
**Restore Window** returns to the remembered ordinary window.

The example `5120 = WoW 4080 + free 1040`, with workspace 640 and game 3440,
is supported by the production planner. The native window bounds contain only
the occupied width. Its clipping region uses the actual game/workspace
rectangles, excluding reserved pixels. Existing transactional rollback and
schema 1 `SPLIT_ULTRAWIDE` handoff are reused.

Settings retain stable monitor identity and resolution, widths, edge and side.
Display renumbering and negative origins are supported. A changed resolution,
different/missing monitor, multi-display selection or invalid dimensions blocks
application until reviewed. Disable custom region in its editor to return to
the existing display workflow; select two displays or enable equal-half split
as appropriate. Existing equal-half dimensions and two-display behavior remain.

Custom mode disables auto-span and does not arm graphics-reset recovery. Apply
manually again after a graphics reset. Existing modes retain their recovery.
No tooltip behavior, saved-frame schema or addon protocol changed.

## Guardrails and limits

Initial physical-pixel guardrails are workspace at least 480, game at least 960,
height at least 600, and dimensions at most 32768 within the selected monitor.
These are input guardrails, not universal readable panel minimums. Narrow panels
may not fit; use Mainhand for such panels. In particular, the existing talents
adapter may shrink substantially. Generic panels are not automatically scaled.

## Automated evidence

- Production planner: both occupied edges, both game sides, negative origins,
  stable identity through renumbering, malformed/unsafe preferences and
  equal-half fallback.
- Native clipping: actual production region builder includes both occupied
  corners and excludes every tested outside boundary.
- Generated C# topology to actual Lua reader: 64 acceptance/rejection cases;
  32 metric/position round trips.
- All 64 Lua suites pass. Preferences/dashboard/editor layouts pass at
  100%, 125%, 150% and 200%. Native restore rollback passes 381 assertions on
  each of x64/x86; production recovery passes 121. Ordinary color/DPI passes
  228 assertions per architecture.

Live evidence and exact prototype artifacts are recorded below after testing.
