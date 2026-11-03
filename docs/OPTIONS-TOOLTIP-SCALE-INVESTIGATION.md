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
implementation. Retrieval returned a gap, not proof of absence; a direct pinned
upstream fetch was unavailable. The target-client observations and local addon
source are the evidence for this change.

Fresh BugGrabber capture was loaded. Its active session advanced 550 to 554 with
all 100 historical records identical during the measurement run. The client exited
normally; all 20 original file states and 87 installed addon files were restored
and hash-verified. No game option, character action or HUD setup action was used.
Private profiles and screenshots remain excluded from packages/shared knowledge.

## Scoped correction

Only the known SettingsTooltip root on the Anniversary interface family is
normalized during an active Offhand layout. The target effective scale follows
UIParent. It preserves the existing parent and ignore-parent-scale flag and
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
The corrected addon still requires visible target-client verification, repeated
hover/hide and later ordinary/spanned acceptance; no prior P8 pass is inherited.
