# Forever profile and Edit Mode live QA, 18 November 2026

## Result

**Confirmed:** a fresh Companion recovery bridge can replace one character's Offhand settings profile selection and HUD metadata with the last saved character's data. This is reproducible after a full client restart. Normal same-session profile sharing and `/reload` persistence passed the sampled checks.

**Not reproduced:** numeric labels in the native Edit Mode selector, or a missing native Account layout. The generated Offhand Main layouts observed here are native Character layouts, so their absence on another character is expected under the current implementation.

## Environment and evidence boundaries

- Forever executable 1.60.1.70959; installed Offhand 2.1.5 Beta 36.
- Store Companion package 2.1.801.0; executable 2.1.8.2; UI reports 2.1.8.
- Latest user-selected pair: Moonweaver Noggaholic and Noggaholic Naux.
- Installed Config, MainhandEditMode, HUDRecovery and SeamRedirect matched tag `v2.1.5-beta.36`. The dirty development checkout was not deployed.
- Live testing used the WoW test harness skill and Windows Computer Use. No movement, combat, progression, account changes or layout edits were performed.
- Private snapshots and screenshots are in `dist/forever-profile-qa-20261118/`. They contain personal game data and are excluded from this report's public content.
- Knowledge routing: shared project README/skill and status were consulted; exact-build 70959 recovery query returned no established finding. Observed client behavior and installed source provide this report's evidence.
- Other enabled addons included ArkInventory, BagSmith and OpenMap. This was an integration reproduction, not an isolated-addon or combat-safety certification.

## Live observations

| Check | Observed result |
|---|---|
| Naux initial native layouts | Active ID 6; Account `DaylightUI - DPS/Tank`; Character `Offhand Pad - Noggaholic` and `Offhand Main - Noggaholic` |
| Moonweaver initial native layouts | Active ID 5; Account `DaylightUI - DPS/Tank`; Character `Offhand Main - Moonweaver` |
| Moonweaver native selector | Displays the saved layout name and a `Moonweaver Specific` section; shared DaylightUI row visible; no numeric labels |
| Offhand settings before controlled test | Both characters implicitly selected `Default`; this cannot demonstrate distinct profile restoration by itself |
| Shared settings profile | Created `QA Moon 20261118` on Moonweaver; Naux's `GetProfiles()` included it after switching characters |
| Naux reload | Created `QA Naux 20261118`; after `/reload`, selected profile remained that name and native layout remained ID 6 |
| Full restart, Naux last saved, Moonweaver first login | Moonweaver selected **`QA Naux 20261118`**, despite previously saving `QA Moon 20261118`; diagnostics reported `source=companion-bridge`, `bridge=used` |
| HUD metadata on cold login | Setup guidance returned on Moonweaver; its saved native layout remained active ID 5. The bridge selected Naux's character data and identity validation discarded incompatible HUD records |

The restart test separates the profile defect from a layout-activation failure: the wrong Offhand profile was selected while the correct native Edit Mode layout remained active. Span/reload on Naux also showed the character HUD setup prompt without compatible reuse. Earlier Naux data included a changed character identity, so the controlled Moonweaver restart is the stronger reproduction.

## Repeatable reproduction

1. Give character A and B distinct Offhand settings profiles. Keep their existing named native Edit Mode layouts.
2. Log out A with profile A selected; log in B, select profile B, and exit WoW normally.
3. Leave the Store Companion running until it refreshes `Core/ForeverState.lua`.
4. Launch Forever through Battle.net and enter A first.
5. Inspect `OffhandCharDB.activeProfile`, `Offhand.foreverPersistenceDiagnostics` and `C_EditMode.GetLayouts()`.
6. Expected: A's profile and HUD metadata. Observed here: B's profile; Companion bridge used; native layout still A's; renewed HUD setup guidance.

Diagnostic commands used only local `/run` output, minimal temporary SavedVariables fields, `/editmode`, `Screenshot()`, `/reload`, `/logout` and `/quit`.

## Source explanation

`Companion/Source/Program.cs`, `ForeverStateBridge.TryRefresh`, chooses the newest account SavedVariables file, then the newest valid **single character** file under that account. It concatenates both tables into generated Lua without a target-character guard.

`Core/Config.lua`, `InitializeConfig`, accepts a fresh non-stale bridge, including its character table. `EnsureCharacterIdentity` detects an owner mismatch and clears HUD metadata, but does not restore the actual character's disk selection. The other character's `activeProfile` remains. The CVar snapshot path already checks a character key, but that check does not protect this generated bridge path.

This source path explains the controlled live mismatch. It does not establish that every reported profile or numeric-label issue has this cause.

## Implementation plan

### P1: Preserve character identity during recovery

1. Replace direct assignment of generated character state with a versioned recovery payload containing account data and explicitly identified character data. Prefer a per-character map for all validated characters in the selected account.
2. Apply the character payload only after resolving the current character identity. Match GUID where present; use a documented name/realm fallback only when GUID is unavailable. Never select a character by file modification time alone.
3. Select account and character recovery independently. A newer account revision must not authorize overwriting another character's selection or HUD metadata. Preserve the current character's captured disk state on a mismatch.
4. Keep legacy bridge handling safe: reject mismatched character records and retain valid local state. Report account recovery and character recovery separately in diagnostics.
5. Add meaningful regression coverage for A→B cold launch, reverse order, equal/stale/newer revisions, legacy untagged bridges, missing character data, recreated characters and account separation. Extend the Companion bridge fixture and Lua persistence suite together.
6. Repeat this exact live test with distinct profiles and named layouts on both characters, including span/reload and window restore. Acceptance: no profile substitution, no lost HUD records, and no unnecessary setup prompt for compatible saved geometry.

### P2: Make settings and layout scope understandable

1. Label Offhand settings profiles as shared account preferences, and show the character's current selection separately from its Blizzard HUD layout.
2. Show native layout name and scope together. Keep numeric IDs in diagnostics; give unresolved references a readable missing-layout state rather than presenting an ID as a name.
3. Offer an explicit, reviewed copy/reuse action for another character's compatible HUD arrangement. Preserve existing native character layout ownership and player-click activation requirements.
4. Add recovery guidance that distinguishes creating fresh preferences, selecting another shared profile, rebuilding the current character's HUD, and resetting all saved data. State the effect before any destructive action.

### P3: Complete the broader QA backlog

| Workstream | Planned work and validation |
|---|---|
| Map scaling | Development checkout already has direct map settings access, finer native steps and fit against both dimensions. Validate first-use calibration on portrait/short workspaces and OpenMap separately. |
| Themes and Studio opacity | Checkout has shared preset colors and opacity applied across Studio layers. Compare each label/preset and opacity endpoints in live custom-image and native canvas modes. |
| XP bar / spoken frame | Capture the exact frame owner and geometry before changing placement. Validate all visible action bars and native Talking Head versus addon-owned speech separately. |
| Map/bag keybind blocking | Define behavior per owner and input mode; inspect existing bindings, apply scoped reversible suppression, and test cleanup, Escape, combat transitions and competing addons on the exact client. |
| Expanded/compact map shortcut | Add explicit presentation preference and shortcut behavior only after verifying native/OpenMap dispatch and reopen semantics. |
| Professions bag anchoring | Reproduce the exact detached bag/root with combined bags open; choose anchor from the actual bag owner and workspace destination. Test BagSmith, ArkInventory and native bags independently. |
| Companion onboarding/display setup | Checkout has four tutorial steps and a prominent Display Settings entry. Validate the Store-built UI at supported DPI scales, with physical Windows monitor arrangement guidance during setup. |
| Website/centre line/reset guidance | Checkout includes Studio access, centre line control and fresh-profile guidance. Validate links and in-game discoverability. |
| Support/donations | Keep the Companion website support route. Review donation placement against the established addon-policy research before adding any in-game solicitation. |

These development changes were previously checked with 130 Lua suites, six manifest checks and a focused Companion DPI fixture. That validation is separate from this Beta 36 live run and does not mean the fixes are installed or released.

## Limits and cleanup

No new native layout was saved or deleted. Numeric labels remain an open reproduction gap. No claim is made about addon-driven protected activation, taint or combat safety. Error snapshots were retained, but a clean baseline error-count comparison was not established; this report is not a zero-Lua-errors certification.

The temporary profiles and `_qa`/`_qaMoon` fields were removed through addon APIs before normal client exit. Cleanup restores the two character SavedVariables snapshots from before the controlled temporary-profile test, preserving Naux's current recreated identity. Final cleanup verification is recorded in the private run receipt.

## Implementation follow-up

The development checkout now implements the P1 character boundary. Config rejects
mismatched legacy bridges, preserves the captured current-character disk table,
and selects only a matching GUID from schema 1 character recovery payloads. The
Companion includes all valid character records within the selected account's
normal realm/character SavedVariables paths. It no longer chooses one character
by modification time. Unused character records are released after selection.

Account bridge use and character bridge use are diagnosed independently through
`source`/`bridge` and `bridgeCharacter`. New generated files retain a matching-GUID
assignment for older addons when identity is already available during loading.
The addon guard should be shipped first, because it also protects users of the
current Store Companion.

Validation: 131 Lua suites pass, along with all six manifest/path checks and Lua
5.1 syntax checks. The focused `tests/companion-forever-recovery.ps1` compiles the
actual Companion source and executes its generated Lua with Config.lua for both
characters, late/missing identity, an unknown character, a consumed bridge and a
non-Forever client. The Lua suite also covers legacy bridges, newer disk state,
unknown payload schemas and recreated identities. Native Companion artifacts
were not replaced. At this stage, fixed-candidate live verification, Store
packaging and release were pending. The sections below record subsequent
candidate validation separately from the original Beta 36 reproduction.

## Fixed-candidate live verification

A recovery-only patch was applied temporarily to the installed Beta 36
Config.lua on Forever 1.60.1.70959. The rest of the development checkout was
not deployed. The new Companion `ForeverStateBridge.TryRefresh` implementation
was compiled into a private console test host and invoked only while WoW was
closed. This validates the generator in the live persistence flow; it is not
verification of a new Store package or the Companion monitoring UI.

Temporary profiles `QA Recovery Moon 20261118` and `QA Recovery Naux 20261118`
were cloned from the existing Default preferences. Their character selections
were seeded in private recovery fixtures. Moonweaver's selected fixture was
also placed temporarily in its normal character SavedVariables before the
first cross-character restart. Its timestamp remained older than Naux's save,
so the original newest-character algorithm would have chosen Naux.

| Candidate check | Live result |
|---|---|
| Naux initial candidate cold login | Naux profile; `source=companion-bridge`, `bridgeCharacter=used`; native layout 6 |
| Naux `/reload` | Naux profile retained; `source=savedvariables`, `bridgeCharacter=not-used`; layout 6 |
| Naux exits, generator refreshes, Moonweaver enters first after full restart | Moon profile; `source=companion-bridge`, `bridgeCharacter=used`; layout 5 |
| Moonweaver HUD ownership | `Offhand Main - Moonweaver`, owner Moonweaver; setup reminder nil; reminder declined true |
| Moonweaver exits, generator refreshes, Naux enters first after full restart | Naux profile; `source=companion-bridge`, `bridgeCharacter=used`; layout 6 |
| BugGrabber comparison | 19 historical records before and after; no new messages or increased counters |

Both full restart directions passed. The erroneous character-HUD setup guidance
seen in the original reproduction did not return on Moonweaver. The normal
inactive-span layout-choice notice remained available. No native layout was
created, edited or deleted.

WoW was closed normally. All 23 tracked installation, SavedVariables, native
layout-cache, configuration and error-log files were restored from the pre-run
backup and verified by SHA-256. This removes the temporary profiles and restores
the installed Beta 36 code. Battle.net remained open; the Store Companion binary
was untouched. Private screenshots, generated bridges, candidate diff and receipt
are retained in `dist/forever-profile-candidate-20261118/`.

The character recovery fix now has live evidence for the sampled windowed
restart/reload flow. Store packaging, Companion UI/monitor lifecycle and a
spanned geometry regression remain separate release checks. Numeric-label
reproduction and the P2/P3 workstreams remain open.

## Recovery-only addon QA archive

An isolated private QA archive is now prepared from the Beta 36 tag, commit
`a158bd52f9f82262a6416b8f144a1d4b2b72eb0a`. It contains 97 files. Only
`Core/Config.lua` and the six TOC candidate labels differ from that baseline.
The packaged Config.lua is byte-identical to the recovery patch tested live.
The generated-state placeholders come from Git, with no account snapshots,
Companion executable, test fixtures or unrelated development changes included.

Artifact: `dist/forever-recovery-addon-package-20261118/Offhand-v2.1.5-beta.36-recovery-qa.zip`.
SHA-256: `de0502553b3a5c8d3d448a021975de344e82ad8e0d3a7676a29073f2c151b97c`.

Validation ran against files extracted from this archive:

- All six manifests, referenced paths, XML and Lua 5.1 syntax passed.
- The extended Forever persistence suite passed, including mismatched legacy
  bridges, missing disk state, consumed/stale bridges and recreated characters.
- The actual Companion generator fixture passed with the extracted Config.lua,
  including both characters, late/missing identity, account separation and
  atomic updates. The fixture now accepts `-ConfigPath` for artifact validation.

This archive is a QA candidate, not an installed or published release. Its code
matches the sampled live test, but installing this complete archive and running
the Store monitoring/span/restore matrix remain pending. The native Companion
binary and installed addon remain unchanged.

### Remaining release sequence

1. Validate this addon guard with the existing Store Companion through a full
   span, reload, restore and cross-character cold restart. Preserve backups and
   compare profile, HUD ownership, geometry and fresh error records throughout.
2. Promote the addon guard through the addon release workflow after review.
   Keep the existing Companion version compatible during rollout.
3. Build the all-character bridge through the separate Companion candidate
   workflow. Verify its actual monitoring lifecycle, Store package identity and
   rollback before promotion.
4. Track numeric-label reproduction and settings/layout scope UX separately;
   the character-recovery result does not close those reports.

## Store Companion live follow-up: 19 November 2026

The complete recovery-only QA archive above was temporarily installed on
Forever 1.60.1.70959 with the existing Store package 2.1.801.0, Companion UI
2.1.8. This run used the actual Store monitoring process and its legacy
single-character bridge, not the compiled test generator.

Before launch, 120 installation/configuration/SavedVariables/cache/error files
and the Store Companion preferences were backed up. The current configuration
selected a 2560 x 1440 landscape display and a 1440 x 2560 portrait display.
The single-display 32:9 checkbox was enabled, but the generated topology used
`DUAL_DISPLAY`, with a 4000 x 2560 combined surface. No display preferences
were changed during the test.

| Check | Observed result |
|---|---|
| Moonweaver cold login | Default selection (`activeProfile=nil`), `source=companion-bridge`, `bridgeCharacter=used`, native layout 5 |
| Store Span action | Window resized; Companion displayed the expected `/reload` guidance |
| Restore before reload | Original bordered window returned |
| Repeat span and `/reload` | Reload completed; gameplay/HUD visible on the landscape display; native full-render screenshot retained privately |
| Restore after spanned reload | Original bordered window returned; default selection retained, `source=savedvariables`, `bridgeCharacter=not-used`, native layout 5 and HUD owner Moonweaver retained |
| Store shutdown monitoring | Created `QA Store Moon 20261119` through the addon API, closed WoW normally, then verified that the Store-generated bridge contained that character's selected profile |
| Cold launch directly into Naux | `activeProfile=nil`, `bridgeCharacter=unmatched`, native layout 6; the Moonweaver test profile was not selected |
| Naux saved HUD comparison | `mainhandLayout=nil`, reminder true and declined nil both before and after; this run did not remove an existing Naux HUD record |

The cross-character check demonstrates the addon guard rejecting the actual
Store Companion's foreign-character snapshot in the Moonweaver-to-Naux
direction. It does not demonstrate that the legacy Companion can recover a
missing current-character record. The new all-character generator remains the
follow-up for that capability. Both restart directions for the new generator
were tested in the earlier candidate run.

BugGrabber increased from 19 to 20 records. The sole new error was from the
QA `/run` diagnostic dereferencing Naux's absent `mainhandLayout`, not an addon
callback. A shorter diagnostic completed successfully. No other new messages
or increased counters were found. This is not a zero-error or combat/taint
certification.

The desktop capture was clipped to one monitor while spanned. A native WoW
screenshot captured the complete render, but exact physical alignment, panel
placement across both monitors and alternate DPI configurations were not
fully assessed. Span/restore lifecycle evidence should not be generalized to
a complete geometry acceptance pass.

WoW and the Store Companion were closed normally. All 120 tracked files and
the Store preferences were restored and SHA-256 verified, removing the test
profile and restoring the original installed Beta 36 files. Battle.net remained
open. Private evidence is retained in `dist/forever-store-span-20261119/`.
Nothing was published, and no candidate remains installed.

## Isolated Companion candidate: 19 November 2026

Prepared an unpublished native candidate from the local 2.1.8.2 DPI hotfix
source revision `1be38f87ff8745fb7201c53ec0b80c1a663585a8`. Its version metadata
matches the installed Store baseline; this does not claim a reproducible match
to the Store-signed binary. Only the `ForeverStateBridge` implementation and QA
assembly identity were changed. This avoids combining the recovery fix with
the unrelated older Companion changes in the active addon checkout.

The candidate is `2.1.8-recovery.qa.1`, file version `2.1.8.2001`. Its source,
diff, build recipe and receipts are in
`dist/companion-forever-recovery-20261119/`. These are local QA identifiers,
not a reserved public version or Store submission version.

| Artifact | SHA-256 |
|---|---|
| `Offhand.exe` | `41082ad78676eaa72a135e093e2b7e97cad40723441954499dbd30bac1ff9a66` |
| `Offhand-Companion-recovery-qa.zip` | `d009bcfc3f0cb0a15d368e748e2ec143fc70254d310b67fe018b62af95e684bd` |
| `msix/Offhand-Companion_1_0_0_0_x64.msix` | `33f592e19d9674a99d14b9a39412671508a27b0c30ffe86faca77a2096d9a3e7` |

The native-interaction audit from the pinned baseline passed for all four
compiled source files, with 46 reviewed native declarations. The active
checkout's older audit initially rejected `GetDpiForWindow`; that API and its
audit allowance are already present in the pinned DPI hotfix. No audit rule was
weakened to accept a new native call.

The recovery fixture compiled this candidate's source and passed against the
Config.lua extracted from the addon QA archive. Coverage includes both
characters, late/missing identity, consumed bridges, account boundaries and
atomic updates. The fixture accepts `-SourceDirectory` as well as `-ConfigPath`
so candidate source and packaged addon bytes can be tested together.

Independent archive verification confirmed identical executable bytes in the
standalone file, portable ZIP and MSIX. The portable archive contains only
the executable, README and license. The unsigned MSIX uses the separate
`N4UX.OffhandCompanion.Validation` identity, version `1.0.0.0`, with the baseline
`internetClient` and `runFullTrust` capabilities and disabled startup task.
It is a structural validation package, not a production Store update.

The candidate executable was compiled and packaged but not launched. Native
monitor lifecycle, UI, signed Store installation/update acceptance and release
checks remain pending for these exact bytes. Earlier live tests exercised the
generator in a test host and the existing Store binary; they do not certify
this new full executable. Frozen checked-in artifacts and the installed Store
application were not changed. No release was published.
