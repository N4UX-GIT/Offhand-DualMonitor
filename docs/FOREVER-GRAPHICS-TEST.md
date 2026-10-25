# Forever graphics-reset candidate, Test 5

Private test candidate, not a public update. Use only with the `_forever_` client.
Window title must say FOREVER TEST 5. It shares the bounded recovery mechanism
tested on Retail and Anniversary, but Forever behavior is not yet live verified.

Existing Store/public Companion files and settings are not replaced. This build
writes ForeverTestConfig.ini and forever-recovery.log beside its own Offhand.exe.
It can initially read the public display preferences. Launch auto-span is disabled
for this isolated test. The existing Forever stopped-client state bridge remains
part of the candidate; preserve generated bridge files and SavedVariables.

1. Close other WoW clients normally and exit the other Companion instance.
   Preserve the existing installed Forever addon and bridge state with backups.
2. Start Test 5, verify selected displays and Mainhand, and launch Forever in
   ordinary Windowed mode. Enter the world. Record the exact live build and addon
   version; local executable metadata at preparation was 1.60.1.70532.
3. Set GUI VSync Enabled before spanning. Click Span WoW Now and wait for
   Forever span verified stable. Confirm both screens and the protected HUD.
4. Start a client-matched read-only native watcher and addon probe if installed.
   Change VSync to Disabled once through Graphics Options. Wait for automatic
   recovery and re-arm without manual span or reload. Preserve logs if the reset
   signature differs; do not repeat a hang or assume a missing recovery is safe.
5. If successful, repeat once without manual span. Test Pause Monitor during
   cooldown, a GUI change while paused, Resume without a forced re-span, and
   Restore Window remaining restored. Re-span explicitly for normal use.
6. Check open Options centering, chat, workspace panels, protected HUD and fresh
   Lua/protected-action errors. Verify reload, normal shutdown and cold launch.
   Check normal SavedVariables persistence separately from the bridge workaround.

The existing Retail-only watcher starter does not target Forever. Use an explicit
Forever PID with the generic watcher, and close other clients first. Diagnostic
capture tools are separate and are not bundled with this candidate.

Stop if WoW becomes unresponsive; retain native and Companion logs. Exit normally
when possible to flush addon probe data. Restore Window and Pause Monitor cancel
recovery; a manual span is required to establish ownership again. At most three
automatic recovery attempts are allowed per five minutes, with stability checks
and a ten-second cooldown. Unrecognized geometry or failed verification stops
retries. It does not repair unknown renderer faults or protected addon errors.

See COMPANION-CLIENT-MATRIX.md in the source checkout for the full release matrix.
The final November 4 client build must be retested even if this candidate passes
on the current installed client.

Current user direction (25 October): live testing is deferred until the Forever release. Resume under the shared COMPANION-ONGOING-BUILD.md plan.

