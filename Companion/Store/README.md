# Microsoft Store packaging

The Microsoft Store is the recommended Windows distribution path for the
Offhand Companion. Store submission gives users a trusted install and update
path without requiring this free project to purchase and operate a public code
signing certificate.

For the complete versioning, validation, GitHub, Store, CurseForge,
communication, and rollback workflow, use
[`docs/COMPANION-RELEASE-RUNBOOK.md`](../../docs/COMPANION-RELEASE-RUNBOOK.md).

## Publisher setup

The next Store candidate is **2.1.8**, EXE **2.1.8.1**, package **2.1.800.0**.
See the [2.1.8 submission handoff](STORE-SUBMISSION-2.1.8.md) for the exact
package, listing copy, certification notes and account checks.

The historical **2.1.6** update has EXE **2.1.6.1** and Store package
**2.1.600.0**. Use `scripts/New-Companion216Candidate.ps1` and the exact frozen
candidate path/hash with the package builder. See
[the 2.1.6 preparation record](../../docs/COMPANION-2.1.6-STORE-PREPARATION-20261110.md).
It was submitted on 2026-11-10 as public Submission 7, ID
`1152921505702364011`, and is in certification with automatic publication after
approval. See [the submission receipt](../../docs/evidence/companion-216-public-submission.json).
The historical commands below are retained as examples; do not rebuild the tested
2.1.6 payload or replace the published 2.1.5 assets.

1. Create a free individual developer account from
   <https://storedeveloper.microsoft.com/>.
2. Reserve **Offhand Companion** in Partner Center.
3. Open the product identity page and confirm the following assigned values:

   - **Package/Identity/Name:** `N4UX.OffhandCompanion`
   - **Package/Identity/Publisher:** `CN=E7BD7796-76DA-40C2-B114-9DD85609CD7F`
   - **PublisherDisplayName:** `N4UX`

4. Build the prepared 2.1.3 update with the frozen candidate. These assigned
   identity values remain the script defaults:

```powershell
$candidate = Get-Content .\dist\companion-2.1.3-native\candidate.json -Raw | ConvertFrom-Json
.\Companion\Store\Build-StorePackage.ps1 `
  -PackageVersion 2.1.300.0 `
  -CompanionPath .\dist\companion-2.1.3-native\Offhand.exe `
  -ExpectedCompanionSha256 $candidate.binarySha256 `
  -OutputDirectory .\dist\companion-2.1.3-store
```

Store package versions must contain four numeric components and end in `.0`.
Increase the version for every submission. `CompanionPath` packages frozen,
already-reviewed bytes, while `ExpectedCompanionSha256` makes the build fail if
the selected executable is not the approved artifact. Without `CompanionPath`,
the package builder compiles the current Companion into temporary staging. It
never replaces the canonical portable executable, produces exact-size Store
artwork, validates the manifest, and writes the resulting MSIX beneath
`dist/store`.

On 2026-11-07 the local installed Store package was observed as `2.1.20.0`,
with the identity/publisher above. The prepared product is **Offhand 2.1.3**;
its MSIX version is **2.1.300.0**, which sorts above that installed version.
`2.1.3.0` would sort below `2.1.20.0` and cannot serve as its update. Keep the
package identity, publisher and application ID unchanged. Confirm the highest
published/in-flight Partner Center version before upload; this local observation
does not inspect the developer account or establish Store certification.

See [the current update guide](../../docs/COMPANION-2.1.3-STORE-PREPARATION.md)
for matched add-on references and remaining acceptance. The Store package reuses
the same exact EXE as the prepared portable/Defender samples. A rebuild or signing
pass creates a new sample; record its hash and repeat the relevant review.

The output is intentionally not signed with a development certificate. The
Microsoft Store signs accepted submissions with a trusted certificate. Use a
self-signed development certificate only for local installation testing; never
publish a self-signed package as a production download.

## Startup behavior

The package declares a Windows-managed startup task named
`OffhandCompanionStartup`. It is disabled by default and can be enabled by the
user through **Settings > Apps > Startup**. This replaces registry or shortcut
persistence with the packaged-app mechanism reviewed by the Store.

Microsoft Store owns update delivery for the packaged installation. The
Companion does not query GitHub when it detects package identity. Its **Store
Updates** button and tray action open the product page for Store status and
manual update checks. The 2.1.5 source adds a quiet availability-only StoreContext
query after startup, limited to once daily with package-local cached state.
The button changes to Update available when the Store reports an update. It
never invokes package download/install APIs or an automatic app restart. Store
association/availability acceptance remains pending for this source change.
Portable builds remain independent and continue using the
official GitHub Releases API only after the user clicks **Check for Updates**.

## Release safety

Do not replace an existing GitHub release asset with an MSIX. The GitHub ZIP
and Store package are separate distribution channels and have different hashes.
