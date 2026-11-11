# Kerzo quest-log reload restoration, 7 November 2026

Test8 preserved Escape behavior and vendor-saved position, but did not reopen
Kerzo after reload. Test9 adds explicit per-character workspace open intent.

`OffhandCharDB.kerzoQuestLogOpen` is set only for a shown quest log on the actual
workspace with panel persistence and reload restoration enabled. Explicit hide
or toggle, moving to Mainhand and disabling those preferences clear it. Identity
reset also clears it. Changes use Forever's existing character-scoped profile
snapshot in addition to SavedVariables, so stale ordinary loads do not silently
discard the new marker.

The first PLAYER_ENTERING_WORLD of a UI session arms a startup restore request.
The existing Canvas cadence waits for Kerzo initialization, a valid span and
workspace placement, then calls Kerzo's `CambiarVisibilidad` opener. It does not
show an uninitialized frame shell, move the root or change Kerzo settings.
Game Menu, reserved input, combat, native Gamepad and protected/forbidden roots
gate opening. Requests expire after 15 seconds and never rearm during ordinary
play or zoning. The transition handler pauses observation before teardown can
erase the last open intent. Existing Escape protection remains active afterward.

Installed Kerzo 6.1.4 source is authoritative for its `cfg` readiness and normal
opener. Shared status and retrieval returned the prior source/live records,
including test8's observed lack of automatic reopening. Target is Forever
1.60.1.70862. No vendor source or saved settings are modified by this adapter.

`tests/kerzo-quest-log-reload.lua` models separate UI sessions, open/closed
restoration, vendor initialization, stable snapshots, teardown, repeated refresh,
zone resume, expiration, missing vendor, Mainhand, preference and input/combat
gates. All 95 Lua suites and six path/XML/Lua 5.1 manifest checks pass in source.
The same 95 suites and six manifest checks pass against the extracted package.

## Live acceptance

Test9 was exercised on Forever 1.60.1.70862 with Kerzo 6.1.4 on 7 November,
14:09 to 14:20 CET, using keyboard UI and a visible single-display split with
1280x1440 workspace and Mainhand regions. Opening Kerzo on the workspace and
issuing `/reload` automatically reopened the populated vendor frame at the same
saved position without `/kql`. Escape then opened the native Game Menu while
the quest log stayed open. After dismissing the menu and explicitly clicking
Kerzo's X, a second `/reload` left it closed beyond the startup retry window.
No runtime correction was needed after those checks.

BugGrabber retained the same three historical messages and counters. This is
not combat/taint acceptance. Protected quest-item, combat, controller, physical
multi-monitor and disabled-preference reload behavior remain separate coverage;
the latter preference gate is modeled by the regression suite.

Both test apps were closed. The original two-display selection, single-display
setting and Companion configuration were restored byte for byte. Twelve backed-up
Offhand/Kerzo SavedVariables files and both generated bridges were restored;
fresh error logs were retained. All 79 installed non-generated files matched
the candidate. Private baseline, after-state and result receipts remain under
`dist/kerzo-reload-live-20261107/`, outside distributable source.

The candidate requires both existing Escape-persistence and reload-restoration
preferences. Open the log on the workspace once to establish intent. Closing it
explicitly clears that intent; ordinary play never continuously reopens it.
