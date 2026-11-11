# Noncombat investigation and test11, 7 November 2026

Scope: remaining locally actionable reports, excluding combat and physical
controller input. Existing dirty source and private test10 were preserved.
Shared knowledge status and Forever-scoped queries were consulted; the cache is
review-due. Installed vendor source and native Forever 1.60.1.70862 behavior are
the authorities for this pass. No vendor source, public release or Discord state
was changed. The source and packaged checks comprise 96 Lua suites and six
Lua 5.1/path/XML manifests.

## Corrections reproduced before implementation

### Shared bubble-font ownership

Forever called RestoreForeverNativeBubbleFont on every bubble sweep, before its
Ellesmere ownership decision. A legitimate shared font of 21 or 24 points was
continually restored to the saved/default 13 points. The regression fails before
the correction. Recovery now runs once after a valid startup font is available,
only for the legacy undersized font case, and yields to explicit Ellesmere
ownership before writing. Later changes, including intentionally small fonts,
remain owned by their writer. Retail's separate instance-font handling retains
its existing capture/conditional restoration contract.

Native QA set the actual shared font to 24 through a temporary hardware-bound
QA button. Its own sample text and read-only records retain that size through
repeated updates, physical span and Restore, within native rounding. The original
13-point font was restored. Ellesmere's current bubble customization was off;
this is external-font fixture acceptance, not confirmation of the reporter's
exact bubble/overhead-text conflict. Enabled Ellesmere ownership and legacy
startup repair are separately covered by Lua fixtures. Engine damage/XP scale
and real bubble contents were not changed or triggered.

### ForeverPlus default row clearance

Installed ForeverPlus 1.0.6 computes its consumable default as the larger of a
proportional height and a general-row offset plus fixed icon halves, TimerRoom
and eight units of air. Scaling that entire offset to a shorter Mainhand loses
the fixed clearance. The new regression fails with 128-unit icons on a 720-unit
Mainhand. The adapter now retains fixed clearance for this recognized vendor
formula and leaves other/default formulas on the existing proportional path.
The original unmodified native anchor is still retained for restoration.

Native QA invokes the installed vendor's actual PlaceAsBar and DrawBar methods
on addon-owned, noninteractive preview roots and synthetic bar records, not its
saved profile. The 48-unit and 128-unit rows both fit Mainhand. Enlarged rows
retain approximately 30 UIParent units between their icon edges, covering the
current theme's timer and air. Rerouting off restores native anchors; on restores
Mainhand placement. Restore releases placement. This verifies vendor layout and
rendering transactions without gameplay. Real buff/consumable warning triggers,
large multi-icon wrapping, combat and controller focus remain separate.

### Ellesmere unlock-toolbar resize

The first native check found the toolbar's right edge slightly beyond the
portrait workspace after span geometry settled. The existing ownership fast
path retained an anchor calculated against earlier canvas dimensions. A mock
whose bounds follow its anchor/scale now reproduces a stale owned toolbar when
the canvas/display rectangle changes. It fails before correction.

The fast path now checks canvas dimensions, UI scale, physical display bounds
and intrinsic toolbar dimensions. On a changed geometry it restores its still
owned vendor anchor/scale and refits from that original size. Stable refreshes
remain no-ops; native entrance animation, later external placement, hover edge
and close restoration retain their existing contracts. The vendor's UI and its
read-only top-bar-anchor accessor supply the identity; no mover positions or
vendor scripts are changed.

A fresh native launch with the correction records the toolbar wholly inside the
portrait workspace after the same span, where the earlier sample fits neither
physical rectangle. The workspace is outside the primary-monitor capture, so
this is native bounds acceptance, not a claim that its portrait buttons were
visually clicked. Vendor Escape closes Unlock Mode without layout edits.

## Other completed checks

Native Chat Settings opens through General's context menu, remains visibly
inside Mainhand while spanning, and reopens through a hardware-bound native
ShowUIPanel transaction after spanned reload. The latter is a root-placement
fixture, not a claim to preserve General's selected filter context. Escape
closes it; reopening stays reachable. Restore retains its native panel, and
Combat Log tab navigation responds. No filter/default/reset control was changed.
No further placement correction was needed.

The three historical BugGrabber records retain their message counts. No new
messages or added historical occurrences were recorded across both sessions.
No combat or fresh taint-sensitive action was exercised. Original addon/native
state, Config.wtf, Companion configuration and generated bridges were restored
after both QA applications closed. The private fixture and its SavedVariables
were moved out of the installation. Private evidence is under
`dist/noncombat-live-20261107/`, excluded from distributions.

## Remaining evidence needed

- Zygor and Naowh are absent from the inspected Forever installation. Exact
  versions, frame identity/bounds and a failing owner/profile remain required.
- Whisper Messenger's simple keyboard opening already passes. Its random block
  still needs the first blocked function/stack and an Offhand-disabled comparison;
  no incoming test message was sent without authorization.
- French topology mismatch, 175% Store DPI and connected-disabled-TV identity
  need the affected configuration/hardware. Windows evidence cannot establish
  native Wayland behavior. Bot production activation remains unverified without
  an identified deployment/health target.
- Actual guild invitation, quest-item use, battleground, zoning and real warning
  or bubble triggers need an appropriate manual scenario. No queueing, movement,
  gameplay, outgoing chat or custom-script security bypass was performed.
- The owned recovery/setup popup can remain above a native dialog after keyboard
  Escape closes the latter. Its shared controller-safe popup priority deserves
  a separate input-lifecycle review; this pass did not change that routing.
- The existing combat, physical controller and exact reporter-layout acceptance
  requirements remain in their individual reports. No speculative compatibility
  exclusion or reporter-issue closure is inferred from these controlled fixtures.
