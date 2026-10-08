# Microsoft Store packaging

The Microsoft Store is the recommended Windows distribution path for the
Offhand Companion. Store submission gives users a trusted install and update
path without requiring this free project to purchase and operate a public code
signing certificate.

For the complete versioning, validation, GitHub, Store, CurseForge,
communication, and rollback workflow, use
[`docs/COMPANION-RELEASE-RUNBOOK.md`](../../docs/COMPANION-RELEASE-RUNBOOK.md).

## Publisher setup

1. Create a free individual developer account from
   <https://storedeveloper.microsoft.com/>.
2. Reserve **Offhand Companion** in Partner Center.
3. Open the product identity page and confirm the following assigned values:

   - **Package/Identity/Name:** `N4UX.OffhandCompanion`
   - **Package/Identity/Publisher:** `CN=E7BD7796-76DA-40C2-B114-9DD85609CD7F`
   - **PublisherDisplayName:** `N4UX`

4. Build the package. These assigned values are the script defaults:

```powershell
.\Companion\Store\Build-StorePackage.ps1 `
  -PackageVersion 2.1.20.0 `
  -CompanionPath .\dist\store-beta20-candidate\Offhand.exe `
  -ExpectedCompanionSha256 81EECE9430885CEAC178A44A42429854524279072305F9F94EE62E7CCD620CCB
```

Store package versions must contain four numeric components and end in `.0`.
Increase the version for every submission. `CompanionPath` packages frozen,
already-reviewed bytes, while `ExpectedCompanionSha256` makes the build fail if
the selected executable is not the approved artifact. Without `CompanionPath`,
the package builder compiles the current Companion into temporary staging. It
never replaces the canonical portable executable, produces exact-size Store
artwork, validates the manifest, and writes the resulting MSIX beneath
`dist/store`.

The currently published Microsoft Store package is `2.1.19.0`. The command
above builds the staged `2.1.20.0` update from the exact Beta 20 candidate bytes.
That update includes the topology bridge repair and distribution-aware update
button: Store installations open the official Microsoft Store product page,
while portable installations retain the explicit GitHub release check. Do not
submit a rebuilt executable in place of the hash recorded above; if source or
binary bytes change, increment the package version and repeat security review.

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
manual update checks. Portable builds remain independent and continue using the
official GitHub Releases API only after the user clicks **Check for Updates**.

## Release safety

Do not replace an existing GitHub release asset with an MSIX. The GitHub ZIP
and Store package are separate distribution channels and have different hashes.
