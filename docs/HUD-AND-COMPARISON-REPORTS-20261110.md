# Native HUD placement and overlapping item comparison reports

Date: 2026-11-10. Investigation only; no additional runtime changes or release.

## Keep the two reports distinct

The cropped comparison image is from a reporter named Critalin. It shows item
text overlapping and a report that the social button disappeared, then returned
above chat. Tooltip owner, item IDs, exact client/build, addon version and the
missing-button state are not captured. Do not assign the fullscreen reporter's
versions or display geometry to this cropped report.

The fullscreen image is the previous placement reporter. Owner clarification:
default Blizzard action bars; an existing custom source layout is suspected,
not established. They switched to Modern, exited Edit Mode, accepted a recovery
dialog and reloaded into the illustrated state. They updated Beta 27 to Beta 28
during reproduction. Exact recovery-dialog wording and saved native layouts
have not been supplied.

The fullscreen diagnostic establishes:

- Companion writer 2.1.6, paired 2.1.5, protocol 1, MATCH.
- Enabled/spanned, Companion source, Mainhand LEFT, out of combat, setup complete.
- Mainhand (0,0 2560x1600); workspace (2560,8 1080x1920).
- Physical canvas 3640x1928, screen about 2496x1322, game area about 1755x1097.
- Topology READY/loaded/schema 1, expected and live canvas dimensions agree.
- Forever persistence bridge consumed. Preferred and active Offhand Main - Garrick
  both ID 5, matching, recovery none.
- GameTooltip and ItemRefTooltip are hidden in the printed presentation snapshot.

The precise client build is not visible. Forever is indicated by its diagnostics.
The desktop strip outside the shorter monitor and the black workspace alone do
not indicate failure. HUD elements using the full canvas are the separate issue.
A preferred/active layout match proves selection, not its systems' bounds.

## HUD source findings

Compared released v2.1.3-beta.27 (a2eee0c5dbee7b7f0c331e986f9c453c8f87235b)
with v2.1.5-beta.28 (dc5e9eb1526dd1ac0adad56d1021f7e9231cf5e1).
MainhandEditMode's relevant change is reload-button handling. Its coordinate
transform and HUDRecovery implementation are unchanged. These reports do not
establish a new Beta 28 coordinate regression.

HUDRecovery.ApplyForeverRecoveryChoice('restore') selects the stored layout ID;
it does not call CreateOrUpdateEditModeLayout or SaveLayouts. An isolated call
to the actual production handler reproduced Modern active ID 1 becoming the
existing Offhand ID 5, zero SaveLayouts calls and unchanged system anchors.
Thus, if the reported popup was Restore saved layout, accepting it is not a
test of newly generated Modern anchors. The exact popup remains a gap.

The generator translates anchors by their relative anchor point. That is not
general fitting of custom absolute coordinates into a smaller game rectangle.
The following synthetic replay uses the rounded reported UI widths, not an
export of the reporter's actual layout:

| Anchor case | Destination right edge | Mainhand right edge |
| --- | ---: | ---: |
| Default TOPRIGHT, offset -20 | 1735 | 1755 |
| Custom BOTTOMLEFT-relative absolute X 2450 | 2450 | 1755 |
| Custom stretched frame's second right anchor | 2496 | 1755 |

Both released Beta 28 and current pending source reproduce those outcomes.
Beta 28 translates the first anchor but a zero left-origin translation cannot
fit absolute custom X positions. It also omits anchorInfo2. Current pending
source transforms both anchors for default systems but preserves explicitly
customized entries, so those same custom positions remain. Do not incorrectly
attribute current pending custom-preservation policy to released Beta 28.

GetLayoutStatus.currentGeometry compares the saved geometry signature. It does
not check each live frame or generated anchor. A matching name/signature and a
nonzero moved-system count therefore cannot establish that the complete HUD fits.
Rebuilding also normally reuses recorded source provenance, so merely selecting
Modern before retrying creation does not guarantee a new Modern source.

These findings provide a plausible source explanation for the user's custom HUD
and recovery sequence. Their original/generated serialized layouts are required
to distinguish retained custom anchors from a save/application or mixed-install
failure. No arbitrary user positions should be overwritten automatically.

## Comparison tooltip source findings

Reviewed upstream Forever 1.60.1.70862 at
9dc84f0d3bbae1768ac3405b3716000bd93eda06. This is a reference build, not an
identified build for the cropped reporter. Its
[TooltipComparisonManager](https://github.com/Gethe/wow-ui-source/blob/9dc84f0d3bbae1768ac3405b3716000bd93eda06/Interface/AddOns/Blizzard_SharedXMLGame/Tooltip/TooltipComparisonManager.lua#L43-L132)
anchors shopping cards to the primary/root and each other. Its
[EditModeSystemTemplates](https://github.com/Gethe/wow-ui-source/blob/9dc84f0d3bbae1768ac3405b3716000bd93eda06/Interface/AddOns/Blizzard_EditMode/Shared/EditModeSystemTemplates.lua#L325-L351)
applies both saved anchors for native HUD systems.

PopupBounds.UpdateClassicTooltipClamp restricts each eligible tooltip separately.
For world-owned roots, ArrangeTooltipComparisons applies that same restriction to
the root and visible shopping cards. Their native anchor dependencies remain,
but individual clamp displacement can destroy their side-by-side presentation.

A model calling production PopupBounds, with independent native-style rectangle
clamping, starts with adjacent 200px root/comparison cards. A 400px group would
fit inside the 626px regional width. The independently clamped comparison moves
back over the root, producing 162px overlap. Released Beta 28 and current pending
source both reproduce this model. This is a source-backed geometry hazard, not
a measured reproduction of WoW's native engine or the reporter's actual owner.

Current tests assert inset values and anchor ownership but do not emulate all
native clamp displacement. Passing those tests does not exclude this overlap.
The fix direction is group-aware bounding after the completed native comparison
transaction, preserving ownership and dependency order. Per-card anchor reversal
or forced visibility would add unsupported behavior. No speculative runtime fix
was applied in this investigation.

The fullscreen tooltip lines show hidden roots and do not capture the cropped
reporter's overlap. To collect relevant evidence with the existing capture:
run /offhand diag full, close chat and hover the failing gear item within 30
seconds, holding the same comparison modifier used when it fails. Retain the
new 'Hovered tooltip presentation' lines, including shopping cards. Capture
the actual source/generated layouts separately for the fullscreen HUD report.

## Social button

The missing state is not shown and the reporter says the button returned.
Source audit finds native chat-strip handling in SeamRedirect.RepairChatButtons;
the current Forever path deliberately leaves Blizzard Edit Mode ownership alone.
The chat persistence regression verifies that no FCF_SetButtonSide replay occurs
there. This is not proof that other layout/parent/visibility effects are absent.
There is insufficient evidence to identify a social-button root or cause.
Next capture must identify its frame, parent, shown/visible state, effective
alpha and position while absent. No forced Show/Hide or anchor patch is justified.

## Reproduction artifacts and validation

Read-only scratch probe:
dist/hud-tooltip-investigation-20261110/investigate.lua, SHA256
80645E9A93B3C60DB56C04E05947EA4FDA26AD97BBC63DB7D1D9F62632682DEF.
The adjacent Beta 28 source snapshots were
read through Git, not copied into runtime or executed as upstream installation
scripts. The probe uses production addon functions with synthetic state only.

Seven existing targeted Lua 5.1 suites passed: mainhand-placement,
hud-compatibility, popup-bounds, classic-tooltip-clamp, modern-item-tooltip-fit,
chat-workspace-persistence and tooltip-presentation. The scratch probe passes
for both source versions and the actual restore handler. No native game/client,
reporter SavedVariables, protected actions or persistence acceptance was tested.
Existing unrelated pending code and frozen release artifacts are unchanged.

## Subsequent owner-authorized fixes

The owner requested both corrections while preserving layouts and safety checks.
The mutable source now fits a generated native HUD copy, honours an explicitly
chosen source, retains in-Mainhand generated edits and snapshots replaced data.
Comparison bounding now uses the native anchor chain and one root constraint,
with native fallback for oversized or unknown groups. No client installation or
public artifact change. All 125 Lua suites and six-manifest Lua 5.1 checks pass.
The investigation and scratch probe above describe the original failure paths;
the probe intentionally expected the old current-source failure. Use the new
regressions for the corrected implementation.
[Implementation, preservation contract and native QA](HUD-TOOLTIP-FIXES-20261110.md).
