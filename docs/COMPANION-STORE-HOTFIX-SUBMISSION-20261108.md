# Companion 2.1.3 Store hotfix submission

Recorded2026-11-08 Europe/Berlin. The owner authorized remaining packaged
upgrade/preflight work so the Store hotfix could be submitted promptly, and
approved the Windows UAC prompt for the prepared isolated validation runner.

## Store result

Partner Center showed Submission3/package2.1.300.0 as the active published
baseline, matching the owner's latest-Store-version clarification. No product
update was in flight. Submission4, ID1152921505702345959, was created and the
exact2.1.301.0 MSIX uploaded and saved as its sole validated package. Removal of
the older package from the draft was automatic because the new version serves
the same customers; the currently published submission remains intact.

| Item | Value |
| --- | --- |
| Product | Offhand Companion, 9PL4PW84Q90W |
| Product version / exact build | 2.1.3 / 2.1.3.10 |
| MSIX package version | 2.1.301.0 x64 |
| Runtime source | a9a5d15e20a5506ab51382eb86c92fda26ad6c90 |
| Merged hotfix PR | [87](https://github.com/N4UX-GIT/Offhand-DualMonitor/pull/87) |
| Merge commit | 9399abe18c7f07519a0b21e4f0bcaf761ff4edb0 |
| MSIX SHA256 | BE5F13B064CF1B208BDF3BD31A21360A216C3AACBCF8A17344FDADDACD99DA8C |
| EXE SHA256 | 47FF105C62B32D5A77B369DDFB1FCC2E6D14E6926CCFDEE53AC3A1C6907FA30C |

English release notes describe the settings hotfix and retain the2.1.3 feature
summary. An obsolete optional-global-hotkey feature bullet was corrected to
optional launch monitoring with configurable delay. The certification guidance
was updated with migration, manual setup/reload steps, exact hashes and scoped
preflight results; its persisted value was verified after reload. Existing
runFullTrust justification, pricing, markets, ratings, screenshots, capability
set and gradual/mandatory update settings were retained.

The existing **Don't publish this submission until I select Publish now** hold
was preserved. No new credentials were supplied to certification notes.

The first Submit for certification action initially produced a transient UI
failure, correlation c217b009-3894-482e-90bf-5774e1a9d76a. A refreshed server view
then confirmed acceptance without a second Submit action:

- **Update in certification**.
- **Product update: In certification (Submission4)**.
- Submission complete; pre-processing underway at observation.
- **Your product will start publishing when you click on Publish now.**

The hotfix is submitted, not certified or publicly released. The production
Store installation remains2.1.300.0. Review the result in
[Partner Center](https://partner.microsoft.com/en-us/dashboard/products/9PL4PW84Q90W/overview)
before the later Publish now action.

## Upgrade and preflight evidence

See [the incident record](COMPANION-STORE-SETTINGS-INCIDENT-20261108.md) and
[sanitized WACK summary](evidence/companion-store-hotfix-build10-wack.json).

A distinct unsigned-OID MSIX identity was installed at2.1.300.0 and upgraded
in place to2.1.301.0 using byte-identical production/candidate EXE payloads.
Native product-form load/save, legacy migration, repeated saves, relaunch,
unknown/non-ASCII fields, locked-file preservation and retry passed. The real
Store identity and preference existence/hash snapshots remained unchanged;
the isolated package was removed. No certificate import, Developer Mode change,
game input, game-window manipulation or addon write occurred.

This was an isolated-identity package upgrade, not production-PFN upgrade or
reproduction on an affected user's machine. The original reported failure has
not reproduced locally. Independent persistence coverage passed25 portable and
47 installed-Store-identity checks. Broader native regression suites and the
final hotfix CI/CodeQL runs passed before merging PR87.

WACK overall PASS, PARTIAL_RUN=FALSE, all13 required tests passed. One optional
finding was reviewed and retained: existing URI Process.Start use and CsI bytes
in the unchanged icon PNG. Local Defender scans found no threats; this is not
a Microsoft AV file-review verdict. No fresh live WoW acceptance is claimed.

The matching addon remains2.1.3 Pre-Release Beta27. The public portable2.1.3
artifacts remain unchanged. A separately reported portable spanning/unrecognized
command symptom remains distinct; its exact rejected command is still unknown.

Local receipts/screenshots are under `dist/store-settings-hotfix/`, including
`acceptance.json`, `store-submission.json`, the upgrade/WACK evidence and
`partner-center-hotfix-submitted.jpg`. Frozen hotfix runtime/receipt are under
`Companion/Prepared/2.1.3-store-hotfix-build10/`.
