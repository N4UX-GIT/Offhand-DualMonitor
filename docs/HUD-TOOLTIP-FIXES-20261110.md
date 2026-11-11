# Native HUD fitting and comparison group correction

Date: 2026-11-10. Source implementation complete. Native out-of-combat follow-up
is recorded in [the live QA report](HUD-TOOLTIP-NATIVE-QA-20261110.md), including
an actual combat-click refusal, owner-confirmed readable combat comparisons
without overlap or visible errors, and completed setup restoration. Broader
taint acceptance retains the limits recorded there.
Owner authorization: fix HUD placement and comparison overlap while preserving
existing layouts and safety checks. The social-button report remains separate.

## Native HUD creation

Create Mainhand HUD Layout fits the generated copy, not the original user
layout or Blizzard preset. The fitter reads registered native system dimensions
and resolves their serialized anchors, including the second anchor of stretched
systems and snapped dependencies. It never calls SetPoint, SetParent, SetSize or
SetScale on these native frames.

- Custom positions already inside Mainhand are unchanged.
- Outlying custom groups are projected proportionally into Mainhand, then fitted
  to its bounds. This avoids simply piling multiple bars onto the same edge.
- Snapped children keep their anchors and follow their root as a group.
- A standalone stretched system, such as XP, can fit through its two anchors.
  Ordinary oversized groups retain their sizes and require manual adjustment.
- External owners, forbidden/unmeasurable systems, cyclic/ambiguous dependencies,
  groups with an unresolved or externally owned child, and Forever's ambiguous
  ClassBar are not moved through guessed geometry. Native Gamepad generation
  retains its existing dedicated path.
- The registered-frame lookup is capability-detected for Retail/Forever. Older
  clients without it retain their existing generation path.

An explicit Create while Modern or another ordinary user layout is selected now
uses that source. Previously recorded provenance no longer overrides the newly
chosen source. Create while the current generated layout is active on the same
geometry retains its in-Mainhand edits and does not translate defaults twice.
Targeted protected-system repairs retain their existing selective scope.

Before replacing an existing generated payload, its layout and provenance are
saved in OffhandCharDB.mainhandLayoutBackups. The first snapshot is retained;
different GUID ownership gets a separate key. This happens before the native
write so the old data is retained even if the save errors or readback is delayed.
It does not consume an additional native Edit Mode slot. Original user source
rows and presets remain unchanged. No layout deletion or settings reset is used.

Existing combat, Edit Mode, API, owner, capacity, activation and reload guards
remain. Creation additionally refuses a pending display geometry transition.
Failed-save tests retain the prior native payload/provenance and the backup.
Restore saved layout still selects saved data; it does not silently regenerate
or migrate a user's HUD.

Diagnostics append NativeFit=status/fitted/skipped and source name. A complete
fit describes the eligible resolved native groups, not replacement-owned HUDs
or a native-client visual/taint pass. Partial or unavailable fitting needs review.
The creation tooltip describes source selection and preservation in all 11 locales.

## Comparison tooltips

Modern shopping cards no longer receive separate regional clamp restrictions.
The completed comparison transaction reserves the full group envelope through
its root tooltip's native clamp insets. This preserves Blizzard's ownership,
card-to-card dependencies, text and normal primary anchor.

The envelope resolves the saved native comparison anchor chain, rather than
trusting card positions already distorted by independent native screen clamping.
TOP and side anchors constrain their respective axes. Coordinates and offsets
are converted through the individual effective scales, including mixed tooltip
scales. Horizontal and vertical reservation both operate in UIParent units.

Only chains depending on the root and its own shopping cards are fitted. Unknown,
external or cyclic anchor dependencies yield to the native group policy.
Groups too large for the target region also retain native positioning rather
than compressing independent cards into an overlapping stack. This can allow an
oversized group to extend beyond one display; it does not promise to fit content
that cannot fit without changing its size or layout.

Combat, protected/forbidden/embedded frames, secret or unresolved coordinates,
and known tooltip replacements retain their boundaries. Root ownership state is
kept in weak side tables. Hide/owner changes and layout disable/unspan release
owned constraints; restoration defers combat and does not overwrite another
writer's clamp values. The module layout callback refreshes only the known native
tooltip roots. No new ticker, frame-tree scan or deferred comparison correction
was added. Repeated unchanged completed groups do not churn clamp writes.

The existing limited manual-root fallback remains for clients lacking native
clamp capabilities. Native comparison dependencies are never reversed.

## Evidence and tests

First-line shared research was consulted and its stale index rebuilt. Relevant
prior evidence is in HUD-AND-COMPARISON-REPORTS-20261110.md. Native API/UI contracts
were inspected in Forever 1.60.1.70862 at Gethe/wow-ui-source
9dc84f0d3bbae1768ac3405b3716000bd93eda06:

- Blizzard_EditMode/Shared/EditModeManager.lua, GetRegisteredSystemFrame.
- Blizzard_EditMode/Shared/EditModeSystemTemplates.lua, ApplySystemAnchor.
- Blizzard_SharedXMLGame/Tooltip/TooltipComparisonManager.lua,
  AnchorShoppingTooltips.

These are source contracts, not proof of protected-action safety. The cropped
reporter's exact client/build remains unknown.

Final validation:

- All 125 root Lua suites pass under Lua 5.1.
- tests/native-hud-fit.lua: originally 32 assertions for custom absolute positions,
  stretched anchors, snapped groups, left/right/stacked Mainhand geometry,
  source/settings preservation, proportional placement, idempotence, unknown and
  external children, oversized groups, ClassBar, cycles and secret data.
  The native follow-up adds six boundary-rounding assertions (38 total) and
  consistently applies the existing 0.01 write threshold at region/size edges.
- tests/mainhand-placement.lua: production create/rebuild tests preserve the
  source row, settings and in-Mainhand generated edits, honour explicit Modern
  selection, retain pre-write snapshots without another slot, and block failed
  saves/unsettled geometry. Existing Classic, Gamepad, typed-slot, ownership,
  recovery and eight-topology generator coverage remains passing.
- tests/tooltip-comparison-group.lua: 992 assertions cover Retail/Forever,
  multiple comparison cards, both directions, world/item owners, region bounds,
  UI and mixed tooltip scales, vertical native-clamp displacement, oversized
  fallback, idempotence, combat/protected guards, unknown anchor chains, external
  clamp writers, hidden comparisons and disable cleanup. This models clamping;
  it is not the native engine.
- All six TOCs pass Lua 5.1 syntax, runtime path and XML-reference validation.
- Locale key/format and wizard bounds checks pass. Targeted diff checks pass.

Full-suite log:
C:/Users/NAUX/AppData/Local/Temp/Offhand-hud-tooltip-final-3d9c38880a0d49268475e6c75c9ee197.log.

## Delivery and remaining native checks

Only mutable source/tests/documentation were changed. Existing pending work was
preserved. No installed addon, Companion executable, frozen Beta 29 release
subject or public archive was replaced, and no release/publication was performed.

After installing a candidate, use Create Mainhand HUD Layout once and follow the
reload prompt to receive corrected HUD data. To change source, select the desired
source in Edit Mode, close Edit Mode and then Create. Using Restore alone keeps
the old payload. Existing sources remain selectable in Blizzard's layout menu.

Pending native QA: actual reporter custom/generated data, portrait-left/right
and offset display arrangements, custom stretched XP and snapped groups, original
source and generated-edit retention across reload/cold login, replacement owners,
native Gamepad non-regression, real item comparisons (including two rings and
asynchronous item data), cursor/world/item anchors, oversized groups, combat
transitions and fresh taint/error evidence. No social-button fix is claimed.
