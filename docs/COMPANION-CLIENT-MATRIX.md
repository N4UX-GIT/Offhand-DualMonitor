# Companion client coverage and release gate

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
