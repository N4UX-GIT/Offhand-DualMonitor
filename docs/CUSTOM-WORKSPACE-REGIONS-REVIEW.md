# Custom workspace regions: local review handoff

Prepared 2 November 2026. The initial schema 1 implementation is working on the
recorded Retail and Anniversary setup. Prototype 5 remains an unpublished local
candidate, version `2.1.3-beta.1`, file version `2.1.3.1`, protocol 1.

## Scope ready for local review

- One monitor: choose occupied width, workspace width, occupied edge and game side.
  The visual overlay supports divider dragging, edge snapping and swapping sides.
- Two monitors: keep the full game monitor and move/resize one rectangular
  workspace on the other monitor, with numeric physical-pixel controls available.
- Save validates the current display identities and geometry before atomic
  preferences publication. Save changes the plan; manual Span applies it.
- Native apply and Restore use rollback-capable transactions. Excluded pixels
  and physical gaps are clipped from the two-monitor window.
- Custom layouts disable auto-span and automatic graphics-reset recovery.
  After applying a changed plan to an already loaded character, use `/reload`.

Only one contiguous workspace is supported. Multiple independent workspaces and
three or more selected monitors remain future schema 2 work. No addon runtime
changes were needed for this slice. The prepared Companion baseline and its
earlier fixes are retained on `codex/custom-workspace-regions`.

## Artifact identity

Exact prototype 5 executable, built from source
`0df1f29ce7240f6e791ace6bd9b652db61037818`:

- EXE SHA-256: `150F56776371E779083D4891D126E8BFF6DBC5BF6A2C48CC3C3EB32D1A8E8898`
- Portable ZIP SHA-256: `4B4252C732953CD8127C24DB3F26B8DA2065889B759E5B20DAA51E7E90D25A9E`
- Validation MSIX SHA-256: `9ED19EAF30603C2A5054A78B1D3AB7F2D993AB68EE5268A2583539FCB44C7C56`

The validation MSIX embeds the exact portable executable. It uses the separate
`N4UX.OffhandCompanion.Validation` identity and `1.0.0.0` package version, is
unsigned, and has not been installed or submitted. It is not a production update.
The original candidate metadata retains its build-time `liveVerification=pending`;
later acceptance is recorded in the documents accompanying this handoff.

The review bundle's manifest identifies the later source/test/documentation
snapshot separately from the original executable build commit. Production
Program.cs and application-manifest hashes must match the original candidate.
The runtime ZIP is retained byte-for-byte. Review materials and source remain
outside that runtime archive. No raw live-QA profiles, chat screenshots, logs,
account paths or knowledge caches belong in the review bundle.

## Validation reached

| Evidence | Accepted scope |
| --- | --- |
| Exact prototype 5 Retail | Two-monitor custom apply/reload; single-monitor replacement Save/apply/reload; matching viewport diagnostics; Character panel persistence; exact native Restore; no new captured errors |
| Exact prototype 5 Anniversary | Level-1 Paladin in Coldridge Valley; apply, reload, separately captured post-reload viewport match, Character panel persistence, exact native Restore; enabled BugGrabber recorded no new errors |
| Exact prototype 5 Retail HUD follow-up | Prepared legacy-row regeneration moved 47 systems and survived reload; Character/bags/spellbook placement and default-map AUTO fit; automatic Modern HUD return and full-client viewport after Restore; original Edit Mode rows restored. Fresh creation was safely refused at the five-layout cap |
| Earlier prototype 3 | Broader Retail cold-start and targeted Anniversary evidence, retained under its original executable hash |
| Preferences/topology | Atomic file publication, stale/missing/replaced displays, invalid geometry, gesture bounds, bridge consumption and metric/persistence fixtures |
| Native rollback | 160 custom span rollback cases and 60 custom Restore cases per architecture; normal/minimized/maximized hidden windows; 3,057 total assertions each on x64/x86 |
| Packaging | Portable contents and executable parity; unsigned MSIX structure, capabilities, opt-in startup, executable parity and rejection checks |

Live runs restored all backed-up file states and closed both test apps. Native
fixtures do not establish live WoW failure injection or protected-action safety.
Detailed provenance and evidence limits are in
[the prototype record](CUSTOM-WORKSPACE-REGIONS-PROTOTYPE.md).
The HUD follow-up uses the newer installed addon, not the worktree addon. Its
fixture, external OpenMap fit limitation, restoration and acceptance boundaries
are recorded in [Retail HUD QA](CUSTOM-WORKSPACE-REGIONS-RETAIL-HUD-QA.md).

## Remaining promotion gates

- Physical monitor loss/reconnect, mixed DPI, the motivating physical 5120-wide
  monitor and broader edge/side combinations.
- Broader exact-artifact client coverage; Forever live testing remains deferred
  until the user's November 4 milestone.
- Fresh HUD creation with a free slot, setup-button input, panel dragging,
  protected actions/taint, the wider panel matrix, live
  custom-span minimized/maximized behavior, actual WoW failure rollback and fresh
  warning-free ordinary-window reconciliation after Restore. The tested safe
  full-client fallback still displays the existing stale-layout notice.
- Wine and installed Store runtime/rollback; production Store delivery-version
  selection, signing and certification.
- Explicit release promotion and external publication under
  [the release runbook](COMPANION-RELEASE-RUNBOOK.md).

Public Beta 20 files are frozen and unchanged. Oversized in-game-options tooltips
remain a separate issue. No merge to main, push, tag, public release, Store upload
or submission is part of this local handoff.
