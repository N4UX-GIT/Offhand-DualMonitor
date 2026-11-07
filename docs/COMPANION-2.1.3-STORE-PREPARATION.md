# Offhand 2.1.3 Store update preparation

Prepared 2026-11-07. This supersedes the Beta 6/Beta 7 submission preparations.
No Store or Defender submission, certification or public release is claimed.

| Surface | Prepared identity |
| --- | --- |
| Companion UI/product version | 2.1.3 |
| Companion EXE/Win32 manifest | 2.1.3.9 |
| Add-on, all six manifests | 2.1.3, no beta release suffix |
| Microsoft Store MSIX | 2.1.300.0, x64 |
| Existing Store product ID | 9PL4PW84Q90W |
| Existing package name | N4UX.OffhandCompanion |
| Existing publisher | CN=E7BD7796-76DA-40C2-B114-9DD85609CD7F |
| Package family | N4UX.OffhandCompanion_bwe0ea6astzt8 |

The installed Store package was read locally as `2.1.20.0`, with this same name
and publisher. The new package version sorts higher and retains the family and
application ID for a direct update. The product version and MSIX version serve
different purposes. `2.1.3.0` would sort lower than the installed Store version.
The fourth MSIX component stays zero. Confirm Partner Center's highest published
or in-flight version before upload; it has not been inspected in this task.

Microsoft's [package requirements](https://learn.microsoft.com/en-us/windows/apps/publish/publish-your-app/msix/app-package-requirements)
describe Store package version ordering and the reserved fourth component.
The package is prepared unsigned for Store processing, with the existing
runFullTrust/internetClient capabilities and disabled-by-default Windows startup
task. Its structural validation is separate from certification or an actual
Store-delivered upgrade. Do not replace the user's installed Store package to
claim an update test on an unsigned preparation.

## Source add-on references

All six source TOCs identify the add-on and recommended Companion as `2.1.3`.
The release fields are empty, so Core/Init.lua computes `2.1.3` and `v2.1.3`
without appending a beta label. Protocol 1, schemas 1/2/3 and the existing minimum
ordinary-span Companion version remain unchanged.

The recommended URL remains the existing Store product:
https://apps.microsoft.com/detail/9PL4PW84Q90W

It is an in-place update to that product, not a new listing. Portable references
resolve to the intended versioned `v2.1.3/Offhand-Companion-v2.1.3.zip` release.
That portable URL becomes available only after a separate GitHub publication.
Publish the matching portable asset before distributing source/add-on guidance
that relies on that alternative download. The current Store listing does not
yet contain this prepared update. Use the included candidate until promotion.
The Store updates the Companion only. Distribute/install the matching WoW
add-on separately; it is not silently installed by the Store package.

## Prepared artifacts and install guidance

- `Offhand-Complete-v2.1.3.zip`: matched Companion and workspace add-on.
- `Offhand-Addon-v2.1.3.zip`: source-matching add-on only.
- `Offhand-Companion-v2.1.3.zip`: minimal EXE, README and license.
- `Offhand-Companion_2_1_300_0_x64.msix`: same exact EXE for Store upload.
- Defender handoff: separate exact samples, hashes, behavior disclosure and
  portal text, with submission IDs/verdicts unset.

Back up the add-on, SavedVariables and Companion preferences, close WoW and
Companion, and install both components from the matched ZIP for local testing.
Keep the included `Offhand` folder directly under `Interface/AddOns`.
In ordinary Windowed mode, review Mainhand/Workspace layout, save the plan,
click Span WoW Now and type `/reload` in WoW. First setup uses `/offhand guide`.
Restore Window undoes the span; Use standard display layout disables custom areas.

## Promotion gates

The [2026-11-07 final preflight](COMPANION-2.1.3-WACK-20261107.md) records
WACK overall PASS with all 13 required tests passed and one reviewed optional
finding, plus current regression and local Defender results. It supersedes the
earlier WACK hold. Partner Center navigation reached account selection only;
published/in-flight package versions remain unverified. Nothing was submitted.

The clean name is the intended release identity, not evidence of release
acceptance. Reuse the exact EXE across portable, paired, Defender and Store
artifacts. Any rebuild/signing/repack creates new samples. Record and supersede
the old hashes without rewriting historical tester downloads or approvals.

Run the existing package validator for exact identity, capability/startup policy
and executable parity. Record local AV scans separately. Actual Store
delivery/update, combined live WoW, physical mixed-DPI/hotplug/
three-monitor, Wine and complete protected-action acceptance remain outstanding
unless a later receipt explicitly demonstrates them. Do not promote the add-on
or website to a nonexistent portable download or claim Microsoft review early.
