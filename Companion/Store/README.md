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
  -PackageVersion 2.1.19.0 `
  -CompanionPath .\dist\defender-beta19-current\Offhand.exe `
  -ExpectedCompanionSha256 658B633783CA388C3E525B565D6061D8F75D9DEBB34E0489E04F046218AAF3E3
```

Store package versions must contain four numeric components and end in `.0`.
Increase the version for every submission. `CompanionPath` packages frozen,
already-reviewed bytes, while `ExpectedCompanionSha256` makes the build fail if
the selected executable is not the approved artifact. Without `CompanionPath`,
the package builder compiles the current Companion into temporary staging. It
never replaces the canonical portable executable, produces exact-size Store
artwork, validates the manifest, and writes the resulting MSIX beneath
`dist/store`.

The output is intentionally not signed with a development certificate. The
Microsoft Store signs accepted submissions with a trusted certificate. Use a
self-signed development certificate only for local installation testing; never
publish a self-signed package as a production download.

## Startup behavior

The package declares a Windows-managed startup task named
`OffhandCompanionStartup`. It is disabled by default and can be enabled by the
user through **Settings > Apps > Startup**. This replaces registry or shortcut
persistence with the packaged-app mechanism reviewed by the Store.

## Release safety

Do not replace an existing GitHub release asset with an MSIX or change the
portable release workflow until the Store submission passes certification.
The GitHub ZIP and Store package are separate distribution channels and have
different hashes.
