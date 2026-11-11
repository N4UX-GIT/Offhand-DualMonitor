# Kerzo Classic Quest Log Escape support, 7 November 2026

The supplied report shows Kerzo's separate quest log closing on Escape on
Forever while other supported workspace windows remain open. Installed local
source is Kerzo Classic Quest Log 6.1.4. Its frame is `KerzosQuestLog`, rather
than Blizzard's `QuestLogFrame` or the World Map quest sidebar.

## Source-backed cause and candidate

`nucleo/inicio.xml` defines the standalone root under UIParent. In
`nucleo/controlador.lua:790-820`, `ActualizarEstadoEscapeModal` removes and then
conditionally registers its root in UISpecialFrames. Settings and other modal
windows suppress the main root so Escape closes the appropriate dialog first.
Opening/closing the root or a dialog recomputes that registration. Simply
removing the root once is insufficient. Its `MemorizarPosicion` method records
vendor-owned geometry and is called after native dragging.

Offhand's ordinary persistence path intentionally returns early on Forever to
avoid mutating Blizzard's protected panel manager. That broad native boundary
does not provide specific Escape support for Kerzo's separate addon-owned root.
The stronger lock-open feature remains unavailable on Forever and is not enabled
by this change. This adapter uses the existing Escape-persistence
(`persistentWorkspacePanels`) preference, labeled **Keep Panels in Offhand
Monitor on ESC (Independent Panels)** in English.

`Core/CanvasKerzoQuestLog.lua` posthooks only those two Kerzo methods. While the
root is shown on the actual workspace in a span, it removes only that root's
Escape registration. It leaves all modal and unrelated UISpecialFrames entries
alone. Placement follows the existing Canvas workspace geometry check, not stale
Offhand coordinates. Kerzo retains its own anchors, settings and close/toggle
behavior. Test8 only filters Escape. Test9 adds a bounded startup opener for
explicit workspace reload intent, described in
[reload restoration](KERZO-RELOAD-20261107.md). Neither version writes scripts
or protected attributes.

Moving to Mainhand, restoring/unspanning, disabling Offhand or disabling panel
persistence releases the policy. Release asks Kerzo to recompute its own current
modal/visibility registration rather than blindly adding an Escape entry.
Native Gamepad/ConsolePort ownership is excluded. Combat defers acquisition and
release. Protected/forbidden roots are excluded. Existing Canvas initialization,
addon-load and layout updates plus the existing Forever position ticker cover
late loading and external movement without a new timer or global frame scan.

## Evidence and limits

Shared knowledge status and an exact-target query for Forever 1.60.1.70862
returned no Kerzo-specific packet. Installed vendor source is the interoperability
evidence; no vendor files or implementation text are modified or bundled.

SHA256 of inspected installed files:

- `nucleo/controlador.lua`: `9DF6AFB5E08D8CFBFB2156B7B790058D5E3475F8AA19307526DAC0594758341E`
- `nucleo/inicio.xml`: `02148539D7577FEBE3CC002574B440F5D771B803D9024EF42EC33FAAD764CDA9`
- `Kerzo Classic Quest Log.toc`: `CC61649D87F82D69A0CFB931D236609778047C3F5BFAAE831217288CC1D2D130`

The standalone regression models native Escape closing the registered root
before the adapter. Candidate tests keep the workspace root open, close its
settings modal first, restore native Mainhand behavior, respect explicit close
and reopen, and cover vendor re-registration, late load, feature release,
combat deferral, native Gamepad exclusion and idempotent hooks. All 94 Lua suites
and six path/XML/Lua 5.1 manifest checks pass in source.

The [test8 live keyboard QA](KERZO-LIVE-QA-20261107.md) passes workspace Escape,
modal dismissal, explicit close/toggle, Mainhand, preference changes, reload and
Restore on Forever 70862 in a visible single-display split. No runtime correction
was needed. Physical multi-monitor, quest-item, combat and controller acceptance
remain open; a posthook, mock or ordinary Escape pass does not prove taint safety.

## Test8 candidate and manual acceptance

The private addon and Complete test8 packages include test7 and this adapter.
The Complete package retains public Beta 20 Companion. Test7 remains available
for rollback; no Discord message, report tag or public release was changed.

With keyboard UI, span the game and move the Kerzo window onto the workspace
using its own drag behavior. Enable the Escape-persistence preference. Press Escape
with the quest log open: it should remain open while normal native menu behavior
continues. Open Kerzo settings and another modal, then use Escape to close each;
the quest log should remain open. Confirm its X button and toggle close it and
that manual reopening does not require a reload. Move it onto Mainhand and
confirm native Escape closes it again. Repeat panel persistence off/on,
Restore/Span and reload. Test8 does not reopen the window on reload; test9 adds
that support through Kerzo's own opener when both persistence preferences allow it.
Use a manual tester for quest-item and combat actions, preserve the first fresh
error, and repeat native Gamepad exclusion separately.
