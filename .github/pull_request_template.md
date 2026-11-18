## Summary

Describe the player-visible result, the implementation boundary, and any known
limitations.

## Component

- [ ] Addon
- [ ] Companion
- [ ] Packaging, website, or documentation only

## Client scope

- [ ] Shared across supported clients
- [ ] Retail or Mainline
- [ ] Forever
- [ ] Classic or Anniversary
- [ ] Vanilla
- [ ] Wrath 3.3.5a
- [ ] Not client-specific

## Evidence

- [ ] Relevant automated tests pass
- [ ] TOC paths, XML references, and Lua 5.1 syntax pass
- [ ] Required live client testing is complete
- [ ] Combat, taint, persistence, and lifecycle checks are complete when relevant
- [ ] Packaged candidate contents or hashes were checked when relevant
- [ ] Remaining validation gaps are listed below

Highest evidence level reached:

Target addon release:

Affected issue IDs:

## Runtime regression checks

For a private addon test ZIP, run
`./package.ps1 -AddonOnly -Version <base-version> -CandidateId <test-id>`.
Use a new ID for changed contents. The candidate ID appears in the AddOn List
and `/offhand diag`.

For a UI or compatibility fix, record the test ZIP name and SHA-256, the loaded
candidate ID for a tester build, and the client/build, Companion version,
topology, and affected addon versions. To reproduce an upgrade, replace the
addon folder using the exact ZIP and keep the existing SavedVariables.

Record one result per relevant scenario, with the exact actions, expected and
observed behavior, and a link to the capture or reporter reply. When placement
behavior differs by display, record Mainhand and Offhand separately. Cover the
reported native interaction and any affected close, reopen, and reload paths.
For a vendor and bag interaction, test a bag the player opened and a bag the
vendor opened. Exercise the relevant dismissal methods during the interaction.

| Scenario and starting placement | Actions and expected result | Observed result | Evidence |
| --- | --- | --- | --- |
| | | Pass / Fail / Pending | |

Use the matched client run or reporter result to mark a scenario verified. List
any untested or still-failing path under Remaining validation. Keep automated
checks, local live results, and reporter results identifiable in the record.

## Ownership and compatibility

Run `python scripts/check-compatibility.py` for the portable addon checks.
For ownership or input changes, include the affected compatibility rows from
`docs/COMPATIBILITY.md` and the live evidence freshness result. Record any
deliberate differences between the installed test addon and this branch.
Before release, repeat affected live cases on the combined packaged candidate.

- [ ] Capability detection is used where client APIs differ
- [ ] Blizzard and third-party ownership boundaries remain intact
- [ ] Saved-variable and localization compatibility was considered
- [ ] Companion source and the frozen executable are unchanged, or this is an
      intentional Companion pull request
- [ ] Presented text contains no em dashes

## Remaining validation

List every client, configuration, or runtime path that still requires testing.
