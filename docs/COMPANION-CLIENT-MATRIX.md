# Companion client coverage and release gate

## 2 November: custom workspace prototype

The separate custom-region prototype 1 passed its initial Retail workflow and a
targeted Anniversary `2.5.6.70577` run with the unchanged installed
`2.1.2-beta.24-tbc-test.11` addon. Anniversary evidence covers custom native apply,
direct schema 1 viewport matching, Character-panel drag and reload persistence,
and exact native Restore. Fourteen original files were restored and hash-checked.
No native HUD regeneration, protected actions or fresh error-store audit was
performed. See [the prototype record](CUSTOM-WORKSPACE-REGIONS-PROTOTYPE.md) for
the exact artifact, geometry, cleanup and remaining limits. This does not promote
the ordinary release candidate or accept all supported clients.

## 2 November: revision 4 Retail follow-up

The changed restore path passed connected normal restore and two consecutive
VSync recoveries on Retail `12.1.5.70688`. A server disconnect was logged about
84 seconds before final Restore, ruling out that call as its trigger. The user
reports poor Starlink connectivity and asked to ignore these disconnects, so
they are excluded from acceptance blockers. The cause was not independently
proven. See [the revision 4 record](COMPANION-RC4-RETAIL-LIVE-20261102.md).
Broader release acceptance remains partial; original settings were restored.

A later revision 4 character-selection run passed successful Restore from native
minimized and maximized ordinary windows, retaining remembered original bounds,
client dimensions and style. Native readbacks and cleanup are recorded in the
same live record. This accepts that specific successful native path; in-world
show-state behavior, clipped-span minimization and actual failure rollback remain
open.

## 2 November: combined revision 3 Retail result

The same rc3 executable passed manual span, two consecutive VSync reset recoveries
and Restore priority on Retail `12.1.5.70688`. Original settings were restored and
both test processes closed. See [the Retail live record](COMPANION-RC3-RETAIL-LIVE-20261102.md)
for hashes, timing, evidence limits and remaining cases. This is targeted native
window acceptance, not full addon layout, persistence or taint acceptance.

A follow-up spanned `/reload` completed and saved a matching viewport diagnostic.
The existing FancyZones manual-canvas profile supplied geometry in that run.
A later temporary selection of Companion through Window Setup confirmed direct
schema 1 consumption and a matching viewport after cold relaunch. Direct-mode
reload was interrupted by an unexplained disconnect; full layout and lifecycle
acceptance remain open. The original profile was restored exactly.

## 1 November: combined revision 3 Anniversary result

The exact `2.1.3-beta.1` rc3 executable passed targeted native recovery and control
testing on Anniversary `2.5.6.70577`: initial manual span, two consecutive VSync
recoveries, Restore priority, Pause/Resume cancellation, manual re-arm and delayed
auto-span on a fresh process. Companion restart adoption was observed separately.
See [the live record](COMPANION-RC3-ANNIVERSARY-LIVE-20261101.md) for exact hashes,
installed addon version, event times, cleanup and untested gates. This does not
promote the artifact or imply cross-client, addon persistence or taint acceptance.
The table and older results below remain historical evidence for their named builds.

Updated 25 October 2026. Forever is the priority for the user's planned
4 November release. This date is a project milestone supplied by the user.

One public Companion should handle all supported clients, with explicit client
capabilities and recovery eligibility. Separate test executables isolate evidence;
they are not the intended distribution model. Executable names alone do not
identify client family. Addon manifests shipped together do not identify the
running client either.

| Client | Existing discovery | New graphics-reset recovery evidence | Rebuild gate |
| --- | --- | --- | --- |
| Forever | Installed `_forever_/Wow.exe`, file version 1.60.1.70532 | Test 5 prepared, live pending | Highest priority: baseline, graphics apply, cancellation and cold-start persistence on current build; repeat on final November 4 build |
| Retail | Installed `_retail_/Wow.exe`, file version 12.1.5.70575 | Test 4 recovery, re-arm and control checks user-confirmed on offset portrait setup | Recheck unified artifact and startup ownership |
| Classic Anniversary | Installed `_anniversary_/WowClassic.exe`, file version 2.5.6.70006 | Test 3 repeated recovery and control checks user-confirmed on offset portrait setup | Recheck unified artifact |
| Classic Era | Installed `_classic_era_/WowClassic.exe`, file version 1.15.9.70003 | Classic candidate scope covered by automated tests; live sequence pending | Run full recovery/control sequence, do not inherit Anniversary acceptance |
| Other current/progression Classic | Discovery recognizes `WowClassic`; `_classic_` is outside current recovery test scopes | Live pending; no installed `_classic_` executable found in this audit | Identify actual build and installation; verify existing span/restore and captured reset signature before opting in |
| PTR/beta/test clients | Known process names include WowT, WowB, WowClassicT and WowClassicB | Excluded from all current recovery test scopes | Explicit build-specific opt-in; no inherited production acceptance |
| Original Wrath 3.3.5a/custom legacy installs | Generic known process discovery may find Wow; addon manifest is experimental | Not covered | Preserve existing manual span/restore where available; no new automatic recovery claim |
| Unknown/renamed installations | Existing process/path resolution and addon protocol checks | Not classified by exact test folder scopes | Keep recovery ineligible until reliable identity evidence exists; report actionable status rather than silently guessing |

File versions above are local executable metadata, not live GetBuildInfo results.
Scope tests currently require exact installation-folder names. A unified public
resolver must also consider executable/build evidence for renamed or custom
installations; it must not infer Forever from a nearby `Offhand_Forever.toc`,
because every addon package contains that manifest.

## Shared mechanism versus client-specific responsibilities

- Native window geometry, DPI/display identities, borderless style, clipping,
  bounded reset recognition, cooldown and manual cancellation can share policy.
- Client identification, eligibility and any graphics reset signatures need
  explicit evidence. A different signature must not trigger a blind resize loop.
- Forever's protected Edit Mode and persistence recovery are separate from native
  span repair. No new input automation, renderer hooks or process-memory access.
- Forever bridge generation remains stopped-process only. Test normal persistence
  first on each new build; do not claim final-client bridge necessity from old
  builds. Preserve existing bridges and SavedVariables throughout testing.
- The public build must support existing manual span/restore on eligible addon
  installs even when automatic reset recovery is not yet eligible for that client.
  Client-specific test executables deliberately restrict spanning for isolation.
- Launch auto-span and inherited spans need their own arming design and tests.
  The test candidates disable launch auto-span and require manual span from a
  smaller window. Do not silently weaken ownership checks to cover startup.
- Multi-client ambiguity needs explicit selection or a clear single-client
  requirement. Never recover a different process because the earlier one exited.

## Required live matrix

For each production family, record actual client build, addon/candidate hash,
display geometry/scaling and fresh errors. Test Windowed baseline, manual span,
GUI VSync change once, stable automatic recovery where the signature matches,
second recovery without manual span, cooldown cancellation, Pause/Resume,
Restore Window remaining restored, Options/menu usability and normal shutdown.
Also check minimized/maximized state, display loss/reconnect, HWND/process
replacement, multiple clients, reload and cold launch. Rate-limit/failure guards
remain automated-only unless explicitly exercised safely.

Forever release gate adds protected HUD layout creation, Edit Mode interaction,
per-character recovery, login/character-selection behavior, and persistence with
and without the existing optional recovery bridge. Windows desktop evidence does
not establish Wine support; preserve Wine behavior and test its matching prefix
separately if included in the release.

The original tester's hang and excessive addon errors remain a separate defect.

### 2026-10-25: Companion work consolidated in planning; Forever testing deferred

User requests Forever live testing wait until the November 4 release and treats
this recovery work plus the experimental work in Investigate v21 Forever Beta
issue as one ongoing Companion build. Shared record: docs/COMPANION-ONGOING-BUILD.md
in D:/Tools/Code/Offhand. Separate worktrees and accepted artifacts are preserved;
no source merge or publication implied. Reconcile the graininess resize mitigation
with the recovery candidate's deliberate omission of that handshake before making
one final candidate. Other work may proceed meanwhile. No automation scheduled.
