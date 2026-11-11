# Prototype 7 persistence follow-up

3 November 2026. This unpublished addon follow-up keeps the exact Prototype 7
Companion. Source `7146cc485d8ad4f61b8dc3b3e2dd400fabac535a` follows the original
[P7 package and Retail report](CUSTOM-WORKSPACE-REGIONS-SCHEMA2-PROTOTYPE.md).
The original P7 and P6 packets remain immutable. No publishing, main promotion,
physical display changes or unattended gameplay is part of this work.

## Missing workspace ownership

The lifecycle review found a reproducible gap in P7: after restoring a
replacement bag from an unavailable workspace into the primary area, passive
bag capture could replace its original region ID and relative position. The
pure position resolver preserved the record, but the later observer did not.
Capture could also retire workspace state during full-client safe fallback.

The new production lifecycle fixture failed on the original source with
`Passive capture replaced missing-region ownership`, before this fix:

- Successful restore of an unavailable destination records its fallback anchor
  in an addon-owned weak-key table, outside the bag's frame ancestry.
- Passive capture retains that original region record while the root remains
  at its restored anchor. Minor physical-pixel rounding and resizing without
  moving the top-left do not revoke the unavailable destination.
- Movement away from the anchor permits normal capture to adopt the new region;
  a deliberate Mainhand move still retires workspace ownership.
- Closing the fallback bag clears open intent while preserving its placement.
- Full-client fallback does not infer a workspace move from an ordinary visible
  bag. Original region and open-state snapshots remain available for recovery.
- Failed anchors do not publish a migration. Existing combat and external-owner
  guards remain in place. No new native fields, hooks, handlers or frame writes
  were added for the passive bookkeeping.

`tests/workspace-region-lifecycle.lua` exercises actual production restore and
bag tracking with synthetic frames and topology. It covers fresh fixture loads,
primary changes, a missing destination, repeated observer capture, reconnection,
subpixel/resize cases, close intent, deliberate workspace/Mainhand moves,
full-client fallback, blocked restore and copy-preserving legacy migration.
Fresh fixture state is not a real client cold launch or physical hotplug test.

All **85 Lua suites** pass. Six TOCs, 66 runtime references, 65 Lua files and one
XML file pass path/XML/Lua 5.1 validation. Companion source and executable did
not change; their prior native and x64/x86 evidence remains attached to those
exact bytes, not relabeled as new hardware or protected-action evidence.

## Package identity

- Addon: 77 staged files, still experimental TOC `2.1.2-beta.24`, source `7146cc4`.
  ZIP SHA-256: `538D9E9BF9494A35CB95A8D63656B44230BC1F22EB948CB743D6F5B53150BCDB`.
- Companion remains `2.1.3-beta.2`, file/application `2.1.3.3`, protocol 1, built
  from `2e68d73`. EXE SHA-256:
  `3D7701F0AB46CC6D2357173D9872D7716D35F43C7534970D1C0CDE9EAB1242F7`.
- Original portable ZIP:
  `8B36FD2EDD18EE1621B9B0F4ADEC30EC25FCD7B1F6B7776C5818033DB7DEDD27`.
- Original unsigned structural validation MSIX:
  `E6DE7319BE2204F54CA723F3B54552953A44E7F631618EBFEC5CE6E7B4A4CC5D`.
  Same exact executable, separate validation identity/version. Not installed or
  submitted. There is no new Companion build or inherited MSIX runtime claim.

The new follow-up packet identifies the revised addon separately from the P7
native build and includes the original P7 addon as a rollback reference. Raw QA
state, generated installed files, account paths, screenshots and logs stay private.

## Bounded Anniversary check

Anniversary `2.5.6 / 70577 / Oct 22 2026 / 20506`, Windows x64/enUS, existing idle
level-1 QA character. Approximately 10:43-11:09 CET. All 77 deployed addon files
matched the revised package before launch. Existing addons/profile were retained;
One World Layer was visibly loaded. No account or realm selection, movement,
combat, protected descendant action or gameplay was automated.

Preflight found Offhand disabled for this character. A first reload while it was
disabled was not counted as addon evidence. After consulting the matching-build
declaration for `C_AddOns.EnableAddOn`, Offhand was enabled only for the current
character with the local API and reloaded. Its original enabled state was backed
up and restored after the run. No HUD creation/selection prompt was actioned.

This was one actual workspace on two physical displays, both 100% Windows scale,
using the same geometry as P7 Retail. It does not exercise a missing physical
monitor or the two-independent-workspace hardware case.

1. Manual Span wrote schema 2, `workspace-a`, backing `(-1431,-6) 3991x1446`,
   style `140B0000` and a complex native clip.
2. Once enabled and reloaded, the addon showed the primary canvas. Captured
   diagnostics reported READY/schema 2, one workspace and matching viewport:
   WorldFrame bottom-origin `(1431,0) 2560x1440`; workspace `(0,6) 1418x1440`.
   A further diagnostic reload retained valid geometry.
3. Both physical taskbar samples, `(-722,1416)` and `(1280,1415)`, hit the WoW root
   while WoW was foreground. Point samples are not universal shell acceptance.
4. Restore exactly returned native baseline `(215,0) 2130x1392`, style `14CF0000`,
   no clip. Captured addon diagnostics reported MISMATCH and a matching full-client
   safe viewport. This opt-in schema 2 AUTO behavior declines a stale bridge;
   it does not erase the previous manual calibration or change explicit MANUAL.

No visible new Lua error appeared. BugGrabber and BugSack were disabled for this
character. The historical 100-record and 2-record files remained unchanged, but
they are not fresh error-capture evidence. Combat/taint, protected actions,
replacement-bag integration, real missing-monitor recovery, cross-workspace input,
cold persistence, mixed DPI and Store/Wine runtime remain pending.

Both target apps exited normally. All **20 original file states and 87 original
addon files** were restored with every hash verified, including original absent
character SavedVariables and the disabled Offhand state. Battle.net remains open.
Public Beta 20 assets and the primary checkout are unchanged. Nothing was pushed,
published, tagged or promoted.

Knowledge routing: shared README, research skill, status, CompanionWorkspaceRegions
record and matching Anniversary 70577 EnableAddOn declaration at `68e0a2ec559d`
were consulted. Declarations, synthetic fixtures and live observations stay distinct.
