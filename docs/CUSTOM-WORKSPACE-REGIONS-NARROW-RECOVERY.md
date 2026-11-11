# Custom workspace panel fit recovery

3 November 2026. Follow-up to the immutable
[Prototype 8 live checkpoint](CUSTOM-WORKSPACE-REGIONS-PROTOTYPE8-LIVE-QA.md).
This changes addon runtime only; the native Companion remains P8. Earlier addon
ZIPs and their live results retain their original scope.

## Behavior

Schema 2 restores and explicit drops compare the actual panel size in UIParent
units with the destination workspace, including the existing 12-unit edge inset.
If it cannot fit, the panel returns to Mainhand through the existing guarded
placement service. A failed drop does not overwrite the previous saved position.
Automatic fallback retains workspace placement and replacement-bag open intent;
passive bag capture must not interpret it as a deliberate Mainhand move. A later
restore retries the saved destination, for example after enlarging the workspace
or switching to a smaller panel tab. Genuine subsequent movement supersedes
fallback intent. Explicit close still clears open intent while retaining position.

If the panel is taller than Mainhand itself, full containment is impossible.
Recovery keeps its title inside the game monitor so the player can close or move
it. Generic panels are not resized. Existing combat, native-tree and external
ownership restrictions still apply; failed eligibility does not authorize a write.

Custom workspaces retain native Retail PlayerSpells size instead of applying the
old unbounded shrinking calculation. There is no accepted readable scaling floor,
so this conservative policy uses Mainhand until a panel-specific scale policy is
live-reviewed. Existing schema 1 fitting remains unchanged. Existing map fitting
still runs before the containment decision. The rejection message is localized
across all eleven locale files and appears only after an explicit oversized drop.

## Evidence and limits

The production lifecycle fixture reproduced oversized restore failure before the
fix. New cases cover Mainhand containment, passive replacement-bag capture, fresh
fixture boot, successful later fit, rejected drops, real external movement, tall
titles and combat/external-owner guards. Narrow-fit fixtures cover native scale
retention, release of an old adapter-owned scale, exact available dimensions and
invalid/oversized dimensions. The combined follow-up now passes all 86 Lua suites
and six-TOC Lua 5.1/path/XML checks. These do not establish taint acceptance.

The exact `862d32b` addon and unchanged P8 Companion also passed a bounded live
integration probe on Anniversary 2.5.6.70577. The editor saved a 480x600 workspace
on the portrait display; manual span and reload produced a schema 2, 3991x1446
surface with the expected region. An addon-owned 1000x700 frame passed through
the production RestoreWorkspacePosition path into Mainhand. Resizing that probe
to 200x200 and retrying placed it inside the workspace. Both recorded rectangles
met the inset bounds; the saved `{x=12,y=2000,regionId="workspace-a"}` record was
unchanged. The probe used actual client frames and metrics, rather than injected
metrics. It did not exercise a native panel's descendants, input or passive bag
capture. The empty native quest log was opened without gameplay and was too small
to exercise the oversized case.

Larger native-panel behavior, native Retail PlayerSpells readability, explicit
oversized drops, replacement-bag capture and cold recovery remain live gates.
The user's prior manual character drag was not repeated. Native window Restore
matched the original bounds/style, and all test file states were restored and
hash-verified. See the [follow-up checkpoint](CUSTOM-WORKSPACE-REGIONS-FOLLOWUP-REVIEW.md).

No saved-variable migration, TOC capability, protocol, native executable or public
artifact change is required. The separate tooltip adapter and opt-in diagnostics
are described in the [tooltip investigation](OPTIONS-TOOLTIP-SCALE-INVESTIGATION.md).
