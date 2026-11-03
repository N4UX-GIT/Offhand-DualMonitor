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
invalid/oversized dimensions. All 85 Lua suites and six-TOC Lua 5.1/path/XML checks
pass. These are source/simulation checks, not live panel interaction or taint
acceptance. Live verification of this revised addon remains pending.

No saved-variable migration, TOC capability, protocol, native executable or public
artifact change is required. The opt-in tooltip investigation is separate.
