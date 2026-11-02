# Companion 2.1.3 Beta 1 acceptance

Local release candidate. No public promotion or client acceptance is implied.
Candidate branch: `codex/companion-next-candidate`.

Current candidate is revision 4. Its restore failure path now retains exact
prior native clipping and placement; synthetic coverage is now 381 assertions per
architecture. See [revision 4 evidence](COMPANION-RC4-RESTORE-EVIDENCE.md).
Revision 3 live results below do not accept the changed executable. A separate
[revision 4 Retail run](COMPANION-RC4-RETAIL-LIVE-20261102.md) passed normal
span/restore and repeated recovery. A server disconnect preceded final restore.
Broader controls/lifecycle, failure rollback, show-state and cross-client cases
remain explicit gates.

The expanded local suite includes actual minimized/maximized synthetic states,
all restore failure stages, exact normal/minimum/maximum placement readbacks and
both absent/complex clipping. This does not accept visible WoW show-state timing
or successful restore from those states. Revision 4 executable bytes are unchanged.

Subsequent [Retail character-selection testing](COMPANION-RC4-RETAIL-LIVE-20261102.md)
passes successful Restore from minimized and maximized ordinary windows using
the remembered original geometry. Exact native outer/client/style and normal
show-state readbacks match the original. This advances the visible native path
only; in-world behavior, still-clipped span minimization and WoW failure rollback
remain unaccepted.

User disposition, 2 November: ignore the observed network disconnects given
their poor Starlink connection. They are excluded from acceptance blockers;
historical logs remain evidence without an independently established cause.

Update, 1 November: [revision 3 passed a targeted Anniversary live sequence](COMPANION-RC3-ANNIVERSARY-LIVE-20261101.md).
That record supersedes the generic pending status only for its listed cases and
exact artifact/client/addon pairing. Remaining procedure items below still need
acceptance before release.

Update, 2 November: [Retail revision 3 evidence](COMPANION-RC3-RETAIL-LIVE-20261102.md)
adds two VSync recoveries, Restore priority and a spanned reload smoke pass.
The saved geometry check matched under an existing FancyZones manual-canvas
profile (`companionTopology=false`). A subsequent supported-UI selection confirmed
direct Companion topology and viewport matching after cold relaunch. One
direct-mode reload attempt disconnected without an established cause. Full layout
and lifecycle acceptance remain pending; require both matching dimensions and
the intended geometry source.

## Runtime contract

The ordinary runtime now includes bounded graphics-reset recovery, enabled only
for `_retail_` and `_anniversary_` installations. This is eligibility for candidate
testing based on prior targeted evidence, not approval of the combined artifact.
Era, Forever, PTR, other Classic branches and unknown paths retain Span/Restore
but cannot arm automatic graphics recovery. The explicit experimental builds
retain their own scopes and isolated preferences. Forever testing remains
deferred until November 4 and requires its actual client build.

A successful manual or delayed automatic Companion span can establish ownership.
The original HWND, pre-span client size and complete display plan must be known.
At least two seconds of healthy matching observations are required before arming.
Restarting Companion may resume existing display-loss protection, but cannot
infer graphics-recovery ownership from an already-spanned window.

Only the captured reset signature triggers recovery: original client/outer size,
stale span clipping and restored resize-frame style, stable for two seconds.
An ordinary resize, unknown geometry, changed HWND or changed display plan does
not qualify. Successful recovery must verify bounds/style/clipping, remain
healthy for four seconds and complete a ten-second cooldown before re-arming.
Three attempts per five minutes are allowed; a fourth request latches off.
Failure or twenty-second verification timeout stops automatic retries.

Restore, Pause and display edits cancel ownership. Resume alone cannot revive
it. A new explicit span may establish a fresh arm; an automatic recovery cannot
replace its own history or reset its attempt limit. Closing Companion ends all
recovery monitoring. Startup auto-span remains optional and off for new users.

The candidate identifies as `2.1.3-beta.1`, file version `2.1.3.1`, protocol 1.
No addon minimum or canonical Beta 20 artifact changes. The one-pixel rendering
comparison remains exclusive to graininess builds. No custom regions are enabled.

## Local checks

```powershell
./tests/companion-preferences.ps1
./tests/companion-span-rollback.ps1
./tests/companion-graphics-recovery.ps1 -Production
./tests/companion-graphics-recovery.ps1
./tests/companion-graphics-recovery.ps1 -Retail
./tests/companion-graphics-recovery.ps1 -Forever
./tests/companion-color.ps1
./tests/companion-color.ps1 -DiagnosticsTest
./tests/release-metadata.ps1
# Use a fresh output directory; do not overwrite an accepted candidate.
./scripts/New-CompanionReleaseCandidate.ps1 -OutputDirectory ./dist/companion-2.1.3-beta.1-review
```

The production configuration passes 121 policy assertions; each scoped
experiment passes 112. Ordinary x64/x86 dashboard/color/DPI checks pass 228
assertions each, including enabled startup controls and ordinary title/settings.
Diagnostics configurations retain 232 assertions each. Preferences, topology,
new-version/future-minimum rejection, layout and release metadata checks pass.
The graininess comparison still compiles, passes its synthetic native-window
checks and verifies all eight ZIP entries. These tests do not operate WoW.

The next candidate iteration adds span rollback coverage: 113 assertions per
x64/x86 synthetic-window build. The span operation captures prior topology bytes,
style, bounds, placement and clipping before writing or moving anything. Failed
operations restore those snapshots; failure to restore is reported separately.
A detected external topology edit is preserved, and rollback does not target a
window now belonging to a different process. Hidden tests verify no prior region
and exact complex-region restoration, file absence, raw bytes, commit, repeated
rollback and locked-file failures. Real client timing and show-state acceptance
remain live gates.

## Live procedure, pending

Use the same exact candidate ZIP for Retail and Anniversary. Record executable
SHA-256, full client/build, monitor identities/arrangement, scaling, selected
roles, initial window size, addon version and relevant UI addons. Preserve the
public installation and configuration before using ordinary shared preferences.
Exit other Companion instances through the tray. Launch as an ordinary user.

1. With auto-span off, span manually. Verify game/workspace appearance and
   sharpness. Use `/reload` once if needed. Wait for stable-arm confirmation.
2. Change only VSync in Graphics Options and Apply. Retain the activity log and
   native observations. Verify exactly one recovery, correct HUD/workspace and
   subsequent re-arm after stability/cooldown.
3. Repeat after cooldown to verify bounded repeated recovery. Do not provoke
   repeated rendering failures merely to exercise the rate-limit latch.
4. Restore Window, wait at least ten seconds, and verify it stays restored.
5. Span again, pause, reproduce the reset, and verify no recovery. Resume and
   verify the cancelled arm stays cancelled. Manually span to re-arm.
6. Change display selection or game side, including changing back before the
   next polling tick. Verify old recovery ownership stays cancelled.
7. Test delayed auto-span on a fresh process. Confirm configured delay, stable
   arming, reset recovery and explicit-restore priority. Restore the user's
   original auto-span preference after the test.
8. Restart Companion while WoW remains spanned. Verify no inferred graphics arm;
   use Restore then Span to establish fresh ownership. Verify display-loss
   protection still works and reconnect does not silently re-arm graphics recovery.
9. Complete cold launch, shutdown, reload, disconnect/reconnect, mixed DPI and
   portable/Store parity checks. Unknown or unaccepted clients must still span
   normally and never report automatic graphics recovery as armed.

Run the Forever-specific acceptance after the November 4 milestone using its
scoped build; do not add Forever to production eligibility based on date alone.
Known hang, sharpness and protected-UI reports remain separate acceptance gates.
No Store version is assigned before checking the actual delivery history.
