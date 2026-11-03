# Anniversary options tooltip scale

3 November 2026. Separate from custom-region geometry and native Companion work.
Target: Anniversary 2.5.6.70577, existing level-one QA character. Native Companion
was not running during the initial measurements; the window remained ordinary
`(215,0) 2130x1392`. The revised addon included read-only tooltip diagnostics.

## Observed evidence

| Sample | Offhand feature | UIParent effective scale | SettingsTooltip local/effective scale | First font-region height |
| --- | --- | --- | --- | --- |
| Ordinary window, legacy calibrated canvas active | Enabled | 0.394 | 1.000 / 1.000 | 14 |
| Ordinary window after feature-off reload | Disabled | 0.700 | 1.000 / 1.000 | 14 |

SettingsTooltip reported no usable parent effective scale and did not ignore
parent scale. Ordinary GameTooltip inherited UIParent at local scale 1.000.
Large Auto Clear AFK and Interact On Left Click tooltips were visibly reproduced.
The feature-off control kept the addon loaded for read-only diagnostics; it is
not a clean addon-disabled control. This identifies a root-tooltip versus UIParent
scale mismatch, amplified by the active calibrated canvas. It does not establish
every underlying cause of Blizzard's default tooltip presentation.

The active source's broad tooltip normalizer in Init.lua runs only on Retail and
Forever. Anniversary's live flags were both false. That explains why the existing
normalizer did not compensate this root on the observed client. The pinned shared
knowledge selection has matching API declarations but omits the Settings tooltip
implementation. Retrieval returned a gap, not proof of absence. A later direct
GitHub tree lookup and raw-file fetch succeeded at the exact pinned revision
`68e0a2ec559d9761dfc4e7f864c3944f9d758a49`. The Settings panel XML creates the
root without a parent; Classic's TopLevelParentScaleFrameTemplate is a stub.
DefaultTooltipMixin calls SetOwner, constructs text, then Show. These source
observations support the measured client behavior without establishing every
native tooltip-layout detail. See the immutable upstream
[Settings caller](https://github.com/Gethe/wow-ui-source/blob/68e0a2ec559d9761dfc4e7f864c3944f9d758a49/Interface/AddOns/Blizzard_Settings_Shared/Blizzard_SettingControls.lua),
[root declaration](https://github.com/Gethe/wow-ui-source/blob/68e0a2ec559d9761dfc4e7f864c3944f9d758a49/Interface/AddOns/Blizzard_Settings_Shared/Blizzard_SettingsPanel.xml), and
[Classic template](https://github.com/Gethe/wow-ui-source/blob/68e0a2ec559d9761dfc4e7f864c3944f9d758a49/Interface/AddOns/Blizzard_SharedXML/Classic/SharedUIPanelTemplates.xml).

Fresh BugGrabber capture was loaded. Its active session advanced 550 to 554 with
all 100 historical records identical during the measurement run. The client exited
normally; all 20 original file states and 87 installed addon files were restored
and hash-verified. No game option, character action or HUD setup action was used.
Private profiles and screenshots remain excluded from packages/shared knowledge.

## Scoped correction

Only the known SettingsTooltip root on the Anniversary interface family is
normalized during an active Offhand layout. The target effective scale follows
UIParent. A SetOwner post-hook prepares scale before the Settings caller builds
text. Changing scale on show, including a deferred next-turn change, produced
visible wrapping and border-height errors in live QA; those variants were not
accepted. The final implementation does not rescale completed text from show or
size callbacks. It preserves the existing parent and ignore-parent-scale flag and
changes only root local scale. Native size is restored on hide or the next
eligible feature-off update, provided scale remains addon-owned. A later external
scale change causes the adapter to yield for that presentation. Existing known
tooltip replacement addons, custom parentage, protected/forbidden roots and
combat prevent acquisition. Bookkeeping stays in addon-owned weak-key tables.
Item, comparison, world and Offhand-owned tooltip scale policies are unchanged.

The new fixture covers parentless/inherited/ignore-parent behavior, UI-scale
changes, idempotence/reentrancy, release, feature-off/ordinary fallback,
external ownership, other clients and combat/protection guards. All 86 Lua suites
and six-TOC Lua 5.1/path/XML checks pass. These do not establish taint safety.

## Final packaged check

Runtime source `862d32bc76bab325743c47e34bb17ca24c072f94`, 77-file addon ZIP
SHA-256 `E4C514B13E4843C6979DC8B30DA0E9DAD7A74100CF13B6049D7943C1CCCAEC8A`.
The exact packaged source, without the temporary diagnostic hook used to test
the ordering hypothesis, displayed Auto Clear AFK and the longer Sticky Targeting
tooltip with contained text. SettingsTooltip local/effective scale was 0.394,
matching UIParent; the first font-region height remained 14. Hiding Settings
restored local scale to 1.000. Measurements were saved by reload.

This is bounded Anniversary ordinary-window acceptance with an enabled legacy
calibrated canvas. Later schema 2 spanning exercised the same addon, but did not
repeat options hover there. Other clients, replacement tooltip addons, feature-off
correction transitions, repeated hover after reload and protected/combat behavior
remain separate gates. During the final combined run fresh BugGrabber capture was
loaded, session advanced 550 to 554, and all 100 historical records were identical.
Native Restore returned `(215,0) 2130x1392`, style `14CF0000`, with no window region.
Both test apps exited normally. All 20 original file states and 87 addon files
were restored and hash-verified. See the [follow-up checkpoint](CUSTOM-WORKSPACE-REGIONS-FOLLOWUP-REVIEW.md).
