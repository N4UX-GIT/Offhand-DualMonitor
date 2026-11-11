# Spanned follow-up: native Save and tooltip scale ownership

Continues [spanned minimap QA](DISCORD-SPANNED-QA-20261110.md). Forever
1.60.1.70862, Companion 2.1.5, idle level-2 character, single 2560x1440 display
split into left workspace and right 1280x1440 Mainhand. Applied **Span WoW Now**
before world entry on both launches; Companion confirmed the selected layout.
EllesmereUI core enabled, separate Minimap/Options and SexyMap disabled.
BugGrabber/BugSack and the private issue observer temporarily enabled.
The user's explicit custom-script authorization covered the reviewed local QA
commands. No gameplay, Discord mutation, commit, push or publication.

## Native minimap Save/reload

The exact-build cached native `EditModeSystemTemplates.lua` supports arrow-key
movement of the selected, unlocked system. Local source revision
`9dc84f0d3bbae1768ac3405b3716000bd93eda06`, SHA-256
`42ed9651df45ec43c2ec6f3a461ad30c366d1959571de77e9b277d87460a6736`.

Selected the native minimap in Edit Mode, pressed Right once and clicked Save.
The map and its selection box moved together. Closed the editor and stopped the
observer before `/reload`. The saved and post-reload serialized native anchors
match exactly across two layouts and 118 systems, active layout 5. Minimap
geometry matches exactly; cluster delta is below 0.0001 physical pixel.

Reopened the editor, selected the minimap, pressed Left once and saved. Original
visible placement is restored within 0.0003 physical pixel. Native movement
normalized that one system from TOP to equivalent TOPLEFT anchoring, with a
small floating-point Y difference. Other serialized anchors are unchanged.
The restored map remained stable for the observer's 180-second window and was
visibly retained on the next cold launch. This is native keyboard Save/reload
evidence, not physical mouse-drag acceptance or a reproduction of OH-UI-034's
affected dual-monitor profile.

## Loot mover preview

Opened the existing addon-owned mover with `SetGroupLootMoverShown(true)`.
Dragging from the default position toward the seam moved it and clamped the
entire preview to Mainhand's left edge. Recorded its rectangle, restored the
original `groupLootPosition` table and hid the mover. Account and character
position values match the pre-test backups. No actual roll, choice, sparse-row
completion, stack-direction or combat acceptance is claimed.

## Tooltip defect found and corrected

A synthetic 180-line native ItemRefTooltip remained oversized on the original
candidate. A bounded post-hook recorded Offhand's PopupBounds setting scale to
0.669733, followed by its own Init scale normalizer resetting it to 1.0.
The fit then correctly yielded to what appeared to be another scale owner.
This is an attributable internal callback conflict, not an EllesmereUI finding.

PopupBounds now exposes its scale ownership while a fit/restoration transaction
is in progress, after a completed fit, and while yielding to an external owner.
Init respects that ownership. The frame-specific transaction guard also covers
native size callbacks that occur before the final fit record is stored.

The regression now loads Init's actual login normalization callbacks together
with PopupBounds. It fails against the prior frozen runtime and passes with the
correction, including shorter content, hide, external scale ownership and combat
deferral cases. All 121 frozen suites pass. Six manifests validate 81 runtime
files, including 80 Lua files, with Lua 5.1; 103 ZIP entries verified by hash.

Backed up and installed a private follow-up built from the previously validated
subject, changing only Core/Init.lua and Core/PopupBounds.lua at runtime.
Archive SHA-256:
`e8dcfaf3b28ded4cc95e6315d708cab2d06986821e81c137f3deaad7b14b7b9d`.
Generated Companion bridges were preserved.

In the relaunched, spanned client the 180-line card retained local scale
0.669733. Its measured frame fits Mainhand, but extreme content is very small;
readability and every glyph's bounds are not accepted from that stress card.
A separately anchored 140-line card retained scale 0.857887, its final line was
visible, and its measured frame stayed inside Mainhand. Replacing the first
card with short text restored local scale 1; hiding the fitted card also
restored scale 1. These are synthetic native-renderer checks. Real long set
items, comparison transactions, short/stacked displays, Retail and combat
still require their existing acceptance matrix.

## Evidence and cleanup

Ignored private folder `dist/discord-qa-20261110-2/` contains scoped backups,
`followup-capture.lua`, `tooltip-fixed-capture.lua`, the bounded native layout
comparer, failing-before regression, frozen validation output, package and
installation receipts. The saved/reloaded and original/restored comparisons
exclude logout restoration. No capture reached the 120-event limit: Save had
63 events; reload/undo had 103. Later zero-event restored run ended at 180 seconds.

Closed Forever normally and waited for process exit. Copied final evidence,
restored the exact original character AddOns.txt with SHA-256 verification,
and disabled both private helper TOCs. BugGrabber's four historical error
message/time/counter records are unchanged; root session advanced 52 to 55.
No new error was captured, and no combat/taint safety is inferred.
All 96 non-bridge product files match the follow-up installation receipt.
Private candidate remains installed with backups; Battle.net/Companion retained.

Daylight live QA remains deferred. Affected old minimap/HUD profiles, native/EUI
mouse dragging, physical multi-monitor/top-overhang, missing dungeon icon,
real rolls/items, ProcDoc and GPU comparison remain open. No Discord report closed.
