# Test15 native bag live QA, 7 November 2026

## Result

Partial acceptance on Forever 1.60.1.70862, keyboard UI, private test15.
Out-of-combat placement, reversible close-button hiding, reload persistence and
post-combat recovery passed for the tested backpack. Reopening during combat
still permits native bottom-right anchoring and remains an open limitation.
No production code changed in this QA pass. Test15 archives remain unchanged.

## Setup and evidence

Verified all 80 installed non-generated files against test15, preserving generated
bridges. Used a temporary addon-owned diagnostic panel and read-only combat
recorder, without hooks or handlers on native bag roots or controls. Test layout
was a remembered 50/50 canvas with Offhand left and Mainhand right. Existing
third-party addons remained enabled; this was not an Offhand-only isolation run.

Initial launch encountered BLZ51900060. The user handled authentication/session
selection and entered an idle test character. All movement, combat and manual
inventory testing were performed by the user. Automated actions were limited to
addon setup, bag UI, local commands, reload and closing the target client.

| Check | Observed result |
| --- | --- |
| Combined backpack on Offhand | Visible, X alpha 0 and mouse disabled with hiding enabled |
| Disable Hide close buttons | X alpha 1 and mouse enabled restored |
| Switch to separate bags | Backpack and keyring participate independently; both X buttons hidden on Offhand |
| Manual title drag to Mainhand | User confirmed movement; both native X controls restored on Mainhand |
| B and all-bags closing/reopening | Explicit close works; backpack reopens at saved Mainhand position |
| Mainhand placement after reload | Saved position retained when reopened; X remains visible |
| Offhand placement after reload | Workspace backpack reopens at saved position with X hidden |
| Reopen near combat end, Mainhand | User observed native bottom-right snap; saved position restored by the 0.2-second sample |
| Reopen near combat end, Offhand | Same snap, followed by workspace restoration and hidden X by 0.2 seconds |
| Already-open bag during combat | User confirmed it stayed open throughout the repeat; both Mainhand and Offhand positions remained stable |

The character had no equipped additional bags, and the user limited testing to
this character. ContainerFrame2 was the keyring, not an equipped bag. This checks
the new additional-frame discovery path but does not accept a full multi-bag
stack or the reporter's exact layout. Automated title dragging did not move the
bag; a real manual drag succeeded, identifying an input-tool limitation.

## Combat distinction

Initial event samples recorded InCombatLockdown false while player combat was
true, followed by both true. This is native evidence for retaining the dual
combat predicate in test15.

First combat checks observed the native default location at combat exit:
ContainerFrame1 left 2954.86 frame units. At 0.2 seconds it returned to saved
Mainhand left 2184.98, or saved Offhand left 1168.08 respectively. No saved
ownership was lost. Later repeat samples recorded unchanged open-bag anchors
through combat. The user clarified that those bags remained open throughout,
so that repeat does not accept closing/reopening during combat.

Native source corroborates the reopening path: ContainerFrame_GenerateFrame
calls UpdateContainerFrameAnchors, whose first bag anchor is the parent's bottom
right. On this right-Mainhand layout, the full-span right edge is also Mainhand's
right edge. Source:
[Forever 70862 ContainerFrame.lua](https://github.com/Gethe/wow-ui-source/blob/9dc84f0d3bbae1768ac3405b3716000bd93eda06/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/ContainerFrame.lua).
This source path and observation support the explanation, without instrumenting
or replacing the native anchor manager to attribute every write.

The repeat reported IsProtected false for the bag root itself. This is not proof
that combat writes to its geometry or descendant item-action ancestry are safe.
No combat guard was removed. A correction for combat reopening needs separate
engineering and protected-action acceptance; this run does not resolve it.

## Errors and limits

The user reported no Lua error. Fresh BugGrabber counters did not change in the
captured runs. Mort's intermittent new Lua failure and previous quest-pin block
were not reproduced and remain unattributed.

Taint logging was enabled manually, with native reload records retained privately.
Those records include routine tainted reads from several addons and no matching
blocked-action record. Reload rotates/resets the available log, so retained log
coverage does not establish a complete trace of the earlier combat-reopening
checks. Do not describe the whole run as taint-free or general combat-safe.
Actual protected item use, combined-mode combat reopening, equipped extra bags,
controller input and the reporter's exact profile remain unverified.

No new executable, release, Discord message or issue closure was made. Detailed
private observations remain outside distributable archives and shared knowledge.

## Cleanup

Closed the target WoW client normally and left Battle.net open. Restored 21
original settings/enablement files and both generated bridges byte for byte.
Moved two newly created QA state files and the temporary addon into private
evidence storage. Final BugGrabber message/counter comparison has zero changes.
Installed test15 runtime remains unchanged; original diagnostic logging settings
were restored with Config.wtf. No character progression or inventory data was
rewritten by cleanup.
