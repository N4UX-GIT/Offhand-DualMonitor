# Prototype 5 Retail lifecycle QA

Recorded 2 November 2026, following the [HUD and panel run](CUSTOM-WORKSPACE-REGIONS-RETAIL-HUD-QA.md).
The unchanged Prototype 5 now has exact-artifact Retail cold-start evidence,
right-edge/left-game coverage, and apply/Restore coverage when entering from
maximized or minimized ordinary windows. This is bounded local acceptance,
not public release or complete client certification.

## Exact scope and preparation

- Companion `2.1.3-beta.1`, file version `2.1.3.1`, protocol 1, built from
  `0df1f29ce7240f6e791ace6bd9b652db61037818`. EXE SHA-256
  `150F56776371E779083D4891D126E8BFF6DBC5BF6A2C48CC3C3EB32D1A8E8898`.
- Retail `12.1.5.70688`, installed Offhand `2.1.2-beta.24`, existing level-1
  Hunter in Coldridge Valley. No gameplay, movement, combat, targeting, spell
  casting or item use was automated.
- Installed `Core/MainhandEditMode.lua` SHA-256
  `47B4DD323026D817D09F11BF0109F149BB9A0359B83D843085E3A1C8F072A5E0`,
  differing from worktree SHA-256
  `0D87D85A3EF2519564917D9350F5F8CEA2FFE792215E1651DABA502E024BD826`.
  No addon source was deployed. Acceptance applies to this installed pairing.
- Primary display `(0,0) 2560x1440`; portrait display
  `(-1440,-1114) 1440x2560`; both at 100% Windows scaling. Only the primary
  was selected for this custom plan.
- Eighteen original files were backed up. The temporary account profile used
  direct/AUTO Companion geometry. Existing Edit Mode layouts were preserved.
  The user restored WoW1 availability by restarting Battle.net, then authorized
  resumption. No account changes were made by the test.

Private evidence: `dist/live-qa-prototype5-retail-lifecycle-20261102-210355`.
Profiles, account paths, error records and screenshots remain ignored and are
excluded from review packages.

## Native lifecycle and opposite side selection

| Check | Observed result |
| --- | --- |
| Ordinary baseline | Outer `(208,0) 2144x1392`, style `14CF0000`, no clipping |
| Apply from maximized ordinary window | Before apply: maximized, outer `(-8,-8) 2576x1408`. Apply: normal borderless `(320,0) 2240x1440`, style `140B0000`, rectangular clipping region type 2 |
| Restore after maximized entry | Normal bordered original `(208,0) 2144x1392`, original ordinary style, no clipping |
| Apply from minimized ordinary window | Before apply: iconic, native minimized position. Apply: visible normal custom `(320,0) 2240x1440`, style `140B0000`, region type 2 |
| Restore after minimized entry | Normal bordered original `(208,0) 2144x1392`, original ordinary style, no clipping |
| Save right-edge, left-game plan | UI Save persisted `PartialEdge=RIGHT`, `PartialGameSide=LEFT`, occupied width 2240 and workspace width 640. The ordinary WoW window did not resize until manual Span |
| Apply saved plan | Native `(320,0) 2240x1440`; schema 1 game `(0,0) 1600x1440`, workspace `(1600,0) 640x1440`; 320 physical pixels remain outside WoW on the left |
| Fresh in-world diagnostic | `READY`, version `MATCH`, `viewportMatches=true`, WorldFrame approximately `(0,0) 1600x1440` |

Manual Restore deliberately requests normal placement. `InvokeSpanWindow`
normalizes the window before taking its ordinary snapshot, and
`WindowRestore.Apply` explicitly clears minimized/maximized style bits. These
live results do not promise restoration to the previous maximized or minimized
show state. Failure rollback retains its separate exact-placement contract.

An attempted minimize-from-maximized gesture was normalized by the UI tool and
did not produce an iconic client. It is excluded from acceptance. Minimizing or
maximizing an already applied custom span, and live failure injection, remain
unverified.

## Actual HUD button, reload and cold restart

The visible **Create Mainhand HUD Layout** button was clicked. With five custom
layouts already present, it safely refused fresh creation and showed the
layout-limit explanation. All five rows and active preset 1 compared deeply
equal before and after the button, reloads and final Restore. No layout row was
deleted, renamed, regenerated or selected by this run. Existing full-display HUD
anchors remained stale; viewport matching alone does not accept their fit.

The Character panel reopened inside the workspace after reload. Two actual title
drag attempts produced no visible movement. A read-only runtime sample confirmed
that Offhand had a movable Character root and used the native TitleContainer as
its drag handle. The cause of the unresponsive gestures remains unresolved;
this is not a drag pass or proof of an Offhand regression. Historical successful
dragging belongs to earlier prototype evidence.

Both apps exited normally and the exact Prototype 5 was relaunched. Companion
read the saved plan with byte-identical INI contents. Auto-span remained disabled;
the new Retail process stayed ordinary until manual Span. Its new baseline was
`(219,0) 2121x1392`, style `14CF0000`, no clipping.

Manual Span on character selection produced `(320,0) 2240x1440`, style
`140B0000`, region type 2. The same level-1 character entered safely. Character
reopened in the workspace with the same saved position and exactly equal
UI-unit rectangle as before restart. A newly executed diagnostic, flushed by
reload, again confirmed `READY`, version `MATCH`, the 1600x1440 WorldFrame and
640x1440 workspace. Native geometry and clipping persisted through world entry
and reload. This accepts cold restart plus manual apply, not automatic startup
spanning.

Final Restore returned exactly to this new process's own ordinary bounds and
style, with no clipping. A fresh diagnostic confirmed `isSpanned=false`,
`viewportMatches=true`, and full-client WorldFrame approximately
`(0,0) 2105x1353`. The stale custom bridge reported `MISMATCH` and the existing
warning remained visible. Warning-free ordinary-window UX is still open.

## Errors, cleanup and evidence limits

BugGrabber advanced from session 349 to 355. All 13 historical error records were
deeply unchanged, with no new captured errors. This does not establish combat,
protected descendant actions or taint safety.

WoW and Companion exited normally. All 18 originals, including preferences,
bridges, account/character profiles and backups, Edit Mode caches, error stores
and character AddOns.txt, were restored and hash-verified with both test apps
closed. Battle.net was left open. Prototype 5 and frozen public Beta 20 bytes
remain unchanged; no production source change or publication occurred.

Shared knowledge status and relevant queries were consulted. Broad Windows DPI
and exact-build Character-drag routing returned unresolved gaps. The production
Companion source, installed addon source and explicit native/runtime samples
above provide this bounded evidence. Missing retrieval does not establish API
absence or safety. Edit Mode declarations remain pinned to `12.1.5.70575`,
revision `15881d522c44cd106d3d8660106ec9f9d2f44167`, rather than the tested
`70688` client.

The user deferred hands-on display changes. Mixed DPI, physical disconnect and
reconnect, physical 5120-wide hardware, free-slot HUD creation, Character drag
acceptance, protected actions, wider panels, other exact-artifact clients and
Store/Wine runtime remain open. Oversized game-options tooltips remain separate.
