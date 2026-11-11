# CurseForge Beta 29 hotfix preparation, 10 November 2026

Status: addon-only beta artifact prepared locally. No upload, GitHub release,
tag, push, Discord message or Discord status change. The owner explicitly
requested inclusion of the loot-roll fixes without local real-roll testing,
with other beta testers providing that remaining acceptance.

## Frozen release scope

The release subject is `dist/curseforge-beta29-hotfix-20261110-r3/subject`,
derived from the accepted private QA14 archive SHA-256
`a6428faafef3b1b8ab1e2e02466d3b1233dc77d830f62190673db2258087868b`.
The preparation script checks every accepted archive entry and each corresponding
product file before changing the release subject. It does not package the
mutable working tree directly or change its pending implementation work.

The prepared version is `2.1.5-beta.29`, with stable paired Companion `2.1.5`,
protocol 1 and unchanged minimum `2.1.2-beta.19`. No native binary is changed or
included. All six TOCs use Beta 29 release markers. Player-facing notes are in
[the CurseForge changelog](CURSEFORGE-BETA29-NOTES.md).

The separate Retail friendly-name preference correction (OH-RET-002) is deferred.
The published Beta 28 preference function, event hook, logout block and matching
geometry assertions are retained in this release subject. The independent
pending preference test is kept outside its active tests. Unrelated geometry,
scale restoration and portrait/4K regressions remain included. This preserves
the existing Retail preference behavior; it does not claim that report fixed.

The scope delta from QA14 is retained as `scope-delta.diff`. Version/doc changes
and the narrow Retail deferral are the only new production changes relative to
that frozen native-tested candidate. ProcDoc and Daylight native acceptance
remain scoped to their previous controlled tests, with no new physical hardware
or combat acceptance claim.

## Static and artifact checks

- All 122 applicable Lua 5.1 suites pass against the frozen release subject.
  The 123rd private-candidate suite belongs to the explicitly deferred Retail
  change. Its published behavior still runs in the mixed geometry suite.
- All six manifests validate 82 runtime files (81 Lua, one XML), with working
  Lua 5.1 syntax checks.
- Archive has 93 files, one `Offhand/` root, portable paths, six manifests and
  BLP-only artwork. No executable, test helper, logs, credentials, tests or
  research cache is included. Topology and Forever recovery bridges are inert.
- Every ZIP entry is hashed after writing and matched to the release manifest.
  A separate fresh preparation reruns all 122 suites and produces the identical
  archive SHA-256.
- Installed QA product files match all 91 non-generated release files. The two
  live Companion-generated bridges are excluded from this installed comparison.
- Companion source/artifacts have no working-tree delta in this preparation.

Artifact: `dist/curseforge-beta29-hotfix-20261110-r3/Offhand-v2.1.5-beta.29.zip`
(950,822 bytes). SHA-256:
`004be4e1fe35dba3bc55f6579ba7d6aa5f5676328fe9c495305f18bbdba9694e`.

Reproduce into a fresh directory from the existing reviewed local inputs:

```powershell
python scripts/Prepare-Beta29Hotfix.py --output dist/beta29-fresh-review
```

The script requires the immutable local QA14 archive/test subject. The versioned
ZIP, its manifest and its frozen subject are the review target. The shared
checkout still contains the deferred Retail correction and Beta 28 metadata;
do not run the general packager against that working tree to recreate this ZIP.
Source promotion to the release branch is a separate step before a future tag
or automated publication workflow.

## Final native checks

Target: Forever 1.60.1.70862, interface 16001, selected existing level-2 Shaman,
enUS, installed Companion 2.1.6, single physical 2560x1440 display split equally
with Mainhand right. Spanning is explicitly applied through Companion. These
checks establish controlled split behavior, not a physical two-monitor matrix.

Cold login starts safely unspanned with MISMATCH until Span WoW Now is applied.
Spanned snapshots report READY. Options fit Mainhand. Repeated disable/re-enable
restores the observed UIParent scale from 0.4344242513 to 0.6399999857 and back.
Reload preserves READY and the owned spanned scale. Restore Window releases
scale and layout; explicit respan returns READY. PLAYER_LOGOUT observations
confirm `loggingOut=true`, restored root scale and cleared original/applied
ownership markers. Normal close succeeds without process termination.

Actual loaded state differs from the requested filesystem flags: EUI core,
Details and ProcDoc coexist; EUI Minimap, Daylight, OpenMap and Leatrix Maps are
not loaded in this final pass. This is not isolated replacement-minimap testing.
BugGrabber/BugSack were initially absent; explicit in-client enable/load and a
private QA bootstrap enable fresh error capture. Only the repeated instrumented
lifecycle checks establish captured-error evidence. Four historical records
retain message, stack, counter and time through the instrumented shutdown.
No current taint log is available; actual combat/protected-action safety is not
established by this run. Combat deferral/ownership fixtures pass separately.

Real simultaneous loot rolls, actual roll choices and combat lifecycle remain
unverified locally, as explicitly accepted for beta inclusion by the owner.
Exact tall set-item content, controller behavior, other client native matrices,
reporter profiles and physical portrait/4K layouts remain open. No gameplay,
combat, purchase, movement or loot automation is used.

Final acceptance reads 34 snapshots across five login/reload sessions and five
shutdown events, including two complete process launches. Eighteen active
snapshots and eleven released snapshots pass the scale/topology assertions;
two explicit disable samples clear ownership. The final clean relaunch loads
error capture, reapplies READY spanning and preserves the saved Mainhand and
workspace position tables. Four historical error records remain unchanged.
The bounded verifier is retained as `verify-final.lua` with its final-run output
in `native-verification.txt`. A cleanup retry overwrote the last raw trace copy;
the independently saved `native-after-shutdown.lua` retains the first full
process run, 28 snapshots across four login/reload sessions. It independently
passes the verifier. The second process launch/respan was observed in the GUI
and passed the 34-snapshot verification before cleanup. That last raw session
cannot be replayed from the retained trace. The cleanup helper now preserves
existing evidence on retries.

Cleanup restored 149 existing files by hash and 132 original absences, covering
all 281 backed-up paths. Installed files, addon flags, config and both generated
bridges are restored. The separately created active private-helper TOC is kept
in evidence and disabled. The QA client is closed and
the launcher/Companion remain open. The release ZIP is preserved independently
of that QA cleanup. `cleanup-receipt.json` records the restoration checks.

## Upload handoff

Use the prepared addon-only ZIP as a **Beta** file, display name
`Offhand 2.1.5 Beta 29 - Placement and Recovery Hotfix`, and Markdown text from
`curseforge-changelog.md`. Keep existing supported-client declarations; no new
client support is claimed. No Companion replacement or forced reset is needed.
Do not upload the whole evidence directory, frozen subject or private helpers.
