# Controller bag combat reopening fix, 8 November 2026

## Report and cause

After the keyboard separate/combined test17 passes, the user reports that
controller opening/closing snaps the bag to native bottom-right Mainhand from
either saved side, with placement restored after combat. Do not extend the
keyboard acceptance to controller mode. Target client remains Forever
1.60.1.70862; the report does not separately supply its exact build/version.

Source confirms two distinct owners. CanvasForeverBags yields to native Gamepad
UI. MainhandGamepad owns controller destination positions and its independent
drag handles, using per-character offsets. Its placement observer previously
skipped every active destination during combat, so the keyboard root correction
could never fix this path.

## Test18 correction

Share the existing native-bag capability guard between both adapters. For only
the two native backpack roots, the controller observer may restore the last
successfully applied out-of-combat CENTER anchor. Require initialized state,
ordinary explicit native permissions, known native ancestry, readable anchor
data, and unchanged valid root/UIParent scale. UIParent or Blizzard's separate-
bag container ancestry are accepted under the existing checks.

Do not run ordinary centering, clamping, native opening/closing, item controls,
chrome, drag or persistence writes in combat. Keep the independent grip hidden.
Unknown/secret/restricted data, cold roots and replacement ownership yield.
Thrown or silently rejected anchor writes suspend further attempts until combat
ends. Other Gamepad destinations retain their existing combat deferral.

No native parent, script, handler, function replacement or metadata write added.
Existing controller offsets and keyboard saved positions remain separate.

## Evidence

Shared knowledge README/research skill, freshness and Gamepad bag combat/API
queries consulted. Collected Forever 70532 declarations are review-due. This
reuses the permission boundary verified against exact 70862 declarations in
[the keyboard investigation](BAG-COMBAT-REOPEN-FIX-20261107.md); declarations and
keyboard native passes do not establish controller protected-action safety.

The controller regression fails on test17 and passes the correction. Covers
actual hide/reopen through the controller observer, workspace/Mainhand offsets,
combined/separate ancestry, player-combat-only and lockdown states, missing or
secret security/anchor reads, rejected/silent writes, retry suppression and
out-of-combat recovery, replacement ownership, cold roots, hidden grip, unchanged
position store and no combat clamping. All 99 Lua suites and six manifests pass
in both source and the extracted test18 runtime. Installed-runtime verification
and native controller acceptance will be recorded separately.

## Native test18 acceptance

PASS for the native combined backpack on Forever 1.60.1.70862, native controller
interface and temporary 50/50 workspace-left/Mainhand-right layout. Initially
the client reported keyboard mode after relaunch; the user activated controller
mode and opened the bag. The recorder then confirmed Gamepad=true, combined
mode 1 and the controller-owned CENTER anchor before the combat test. A physical
Escape interruption was honored; testing resumed only after the user's request.

The user performed controller close/pause/reopen during combat on both sides
and reported stable placement and no error after using a bag item with the
controller after combat. The 0.05-second observer independently captured two
complete hidden-to-shown reopen cycles on workspace and one on Mainhand during
actual lockdown. A separate Mainhand combat kept an open bag stable. Every shown
combat sample retained that side's CENTER anchor and geometry within 0.01 UI
units, with native UIParent ancestry and ordinary permissive root capabilities.
The controller adapter reports combat-bag-positioned for corrected shown roots.

No new BugGrabber messages or counter changes. Preserved the pre-exit and final
taint logs without reloading after the combat checks. Ten secret-arithmetic
blocks explicitly name ForeverPlus Core/Util.lua:624; none matches this Offhand
bag path. This is not a clean whole-session taint claim. Item use after combat
passes by user report; in-combat item actions remain untested.

Closed the target client normally. Restored all 29 original state/enablement and
character-cache files and both generated bridges byte-for-byte, and removed the
temporary recorder plus two created SavedVariables files. Battle.net and the
user's existing Companion remain open. Installed test18 runtime and both ZIP
hashes were reverified after cleanup. No new production change was needed after
native acceptance.

Separate-mode controller reopening, equipped extra bags, roots first encountered
in combat and the reporter's exact physical display profile are not accepted by
this run. Existing restrictive/unknown-capability deferral remains intentional.
Test17 keyboard acceptance remains historical evidence; keyboard native behavior
was not rerun on test18 in this controller run.

## Packaging

Private test18 retains frozen public Beta20 Companion and test17 rollback.
Source manifests remain public Beta26. Preserve installed generated bridges.
No public publication or Discord message is part of this change.
Immutable test18 ZIPs were built before native acceptance; their bundled testing
notes record that earlier pending state. This report and the external verification
manifest contain the subsequent live result.
