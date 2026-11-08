# Addon window timing follow-up, 7 November 2026

Mort reports that test12 protects settings only after a delay, leaves Leatrix and
Platynator X buttons visible, and briefly shows Kerzo's X on reopening. The earlier
test12 acceptance explicitly refreshed adapters before Escape; that did not test
the interval between opening and the next timer. The source confirms the gap.

## Changes for private test13

- Observe only the previously source-identified ordinary addon settings roots at
  OnShow, OnHide and OnDragStop. Run after vendor handlers, with weak side-table
  bookkeeping and per-script idempotence. Protected/forbidden roots are excluded.
- Observe named public addon slash openers, Offhand.Options.Open and Platynator's
  compartment callback. A narrow SetItemRef callback handles its own settings
  link. These cover first lazy creation before a root can be observed. Root
  lifecycle handlers cover later opens and vendor settings-page transitions.
- Synchronize WorkspaceChrome in the same transaction. Leatrix anonymous main X
  buttons are found through bounded direct-child inspection: verified vendor
  source, button type, exact top-right parent anchor and 30x30 size with a 0.01-unit
  float tolerance. Native dimensions read 30.000032424927 at the tested UI scale.
  Side settings
  use their known c field, Sounds cb, Platynator CloseButton, DungeonJournal
  closeButton and Offhand's explicitly exposed owned header button.
- Keep X hiding independent of persistentWorkspacePanels. Native dialogs and
  unrelated controls remain outside discovery. Restore on Mainhand, hide, option
  reversal and disable. Keep existing combat/controller gates.
- Reuse Kerzo's vendor escape/position posthooks to synchronize chrome. Also
  observe CalibrarCabeceraYCierre so a header redraw cannot reset the hidden X
  until the next one-second chrome tick.

The half-second/one-second tickers remain fallback reconciliation. There are no
new global CreateFrame, ShowUIPanel or Escape replacements, no button-script
hooks, and no vendor geometry/visibility changes. Specific ordinary addon root
observers are a deliberate change from test12's polling-only implementation.

## Evidence

Local installed versions/source paths are recorded in
[the test12 source review](ADDON-ESCAPE-FOLLOWUP-20261107.md). Additional source:
Leatrix Maps CreateCloseButton:5173, Plus CreateCloseButton:115; Platynator
Core/Initialize.lua:107 and API/Main.lua settings-link callback; Kerzo
interfaz/marco.lua CalibrarCabeceraYCierre and nucleo/controlador.lua open/close
transactions. No vendor source/assets are copied or modified.

Shared knowledge status and Leatrix/HookScript queries were consulted. The
review-due corpus declarations were checked against the exact
[Forever 70862 declaration](https://github.com/Gethe/wow-ui-source/blob/9dc84f0d3bbae1768ac3405b3716000bd93eda06/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleScriptRegionAPIDocumentation.lua#L347).
HookScript requires assignable scripts and forbids restricted bindings. A
successful unprotected callback does not establish combat/taint safety.

The new forever-addon-window-timing.lua regression fails against the frozen test12
source at the immediate Escape assertion and passes with the candidate. It never
creates or advances a timer. It covers early main/lazy opening, compartment,
anonymous/ordinary button separation, immediate drag/reopen/close, independent
options, modal priority, vendor header redraw, idempotence and protected/controller/
combat exclusions. All 98 suites and six source manifest checks pass.

## Native timing acceptance and cleanup

Forever 1.60.1.70862, English UI, keyboard, idle character, remembered 50/50
ordinary 2114x1353 canvas with game right. Same installed vendor versions as
test12. No gameplay, combat or controller actions; Companion was not launched.

A temporary QA addon called each vendor opener, placed the root in the workspace,
ran its drag-stop handler and Hide/Show, then called native CloseSpecialWindows
in the same Lua callback. There was no explicit Offhand adapter/chrome refresh
in that path. Samples before/after share the same GetTime value, so no ticker
could intervene. Maps, Plus, Sounds, Platynator, ForeverDungeonJournal and Kerzo
all remained shown, unregistered for Escape, with X alpha 0 and mouse disabled.
Physical Escape also opened Game Menu while each remained visible. Kerzo stayed
hidden on redraw/reopen; its bottom Close worked. Maps and Kerzo immediately
released on Mainhand, restored X alpha/mouse, and closed with native Escape.
Hide-X reversal restored Kerzo and Maps buttons; Maps's actual X closed it.
Maps/Plus were rediscovered through multiple reloads with new random names.

Initial native Leatrix chrome checks failed because exact size equality rejected
30.000032424927. The tolerance correction and native-value regression pass the
final run. The private harness also needed its lookup to include already tracked
roots, because synchronous discovery removes their UISpecialFrames entry before
the opener returns. Neither adjustment is hidden in the final acceptance.

Offhand's own settings refit into Mainhand on Show through Controls.FitDialog,
so that forced Hide/Show sample correctly closed with Escape and kept X visible.
It is excluded from the six-root workspace timing pass. Its adapter is simulation
covered; the earlier test12 artificial workspace placement is historical evidence,
not acceptance of its normal open/fit flow on the workspace.

No new BugGrabber messages or counter increments. Closed the target client,
restored 15 original settings files, character addon enablement and both generated
bridges. Moved 14 created state files and the temporary QA addon into private
diagnostics outside installation. Vendor addons retained. Private logs, account
data and QA code are excluded from distributable archives.

Test13 retains the frozen public Beta20 Companion. All 98 suites and six manifests
pass in source and extracted runtime; installed non-generated files are checked
against the package. Test12 archives remain unchanged for rollback. Combat,
controller, native Leatrix side pages, alternate skins, exact reporter profile
and private Platynator entry routes remain separate acceptance items.
