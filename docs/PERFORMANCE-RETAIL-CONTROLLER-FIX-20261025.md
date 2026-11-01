# Verified Retail controller-detection CPU fix

Integration follow-up, 25 October: PR #37 is merged into `addon/develop`.
The remaining PR #36 source was subsequently merged at `4a7b200`, retaining the
accepted early return and both regression sets. The separation described below
records the original narrow promotion; it no longer means those other sources
are missing from the integration branch. Their live evidence remains separate.

Source branch: `codex/retail-controller-cpu-fix`, targeting `addon/develop`.
This promotes only the missing-Gamepad-enum short circuit from draft performance
PR #36. The bag allocation/proxy optimizations, direct native-preset-table read,
diagnostic timing gate and standalone profiling tools remain separate.

## Problem and behavior

The two-second party-recovery pass checks whether Blizzard/controller UI owns
the HUD. Retail 12.1.5 build 70575 provides preset layouts but lacks
`Enum.InputDeviceInterfaceType.Gamepad`. Controller detection nevertheless copied
all preset/system trees before returning false because the enum was absent.

After the existing ConsolePort/native Gamepad checks, return that same false
result immediately when the enum is missing. When the enum exists, retain the
existing compatibility path. No native table reads, frame writes, caches, timer
changes, SavedVariables changes or Companion changes are introduced.

## Evidence

All 55 existing Lua suites and all six manifests passed on the investigation
branch. The isolated branch adds a focused regression for 450 missing-enum checks
without copies, a missing-member case, ConsolePort precedence and the existing
available-enum fallback. On this isolated branch, all 54 Lua suites pass (the
standalone diagnostic suite is excluded), along with all six manifests and Lua
5.1 syntax validation.

The live `enum-fixed` capture on Retail 12.1.5 build 70575 lasts 79.251 seconds:

| Party-recovery timing | Before | After |
| --- | ---: | ---: |
| Mean per call | 1.483729 ms | 0.022810 ms |
| Maximum per call | 2.818300 ms | 0.057000 ms |
| Calls exceeding 1 ms | 35 / 35 | 0 / 40 |

Measured phase mean fell 98.46%. The final capture has one new Offhand >1 ms tick
in total, replacing the repeated two-second pattern, and no new >5 ms ticks.
That single remaining tick was not attributed to the timed phases. No FPS gain
is claimed. Saved capture SHA256:
`711580A865D7B770A7654A69B10FD62534842CA28D56294954F5D33E79190DB3`.

The user subsequently confirmed normal spanned use, map/bag/chat/menu/HUD checks,
Edit Mode entry/exit and party positioning, reload and relaunch persistence. No
noticeable performance issue remained; the fluctuating AddOn List CPU value alone
is expected. The live candidate also contained a direct scalar read, but metadata
confirmed it was bypassed because this enum was absent. Thus the promoted early
return is the measured path. Client builds exposing the enum retain their old
path; no new runtime claim is made for them. Release Forever testing remains
deferred.

This is addon integration work, not a public release or Companion promotion.
