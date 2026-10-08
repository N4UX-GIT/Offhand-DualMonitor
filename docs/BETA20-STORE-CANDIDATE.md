# Offhand 2.1.2 Beta 20 / Companion Store 2.1.20.0

Prepared on 2026-10-07 as the first update after Microsoft Store publication.
This is a staged candidate, not a published release.

## Purpose

- Keep Microsoft Store installations on the Microsoft Store update channel.
- Keep portable installations on the existing explicit GitHub release check.
- Carry the Beta 19 topology-bridge, DPI-layout, display-identification, and
  delayed auto-span fixes into the next Store package.
- Release the accumulated addon fixes as Beta 20 while keeping the compatibility
  contract at protocol 1 / minimum Companion `2.1.2-beta.19`.
- Publish the exact Beta 20 Companion candidate on GitHub and retain those bytes
  as the frozen baseline for later addon-only releases.

## Candidate artifacts

### GitHub release

- Addon: `dist/Offhand-v2.1.2-beta.20.zip`
  - SHA-256: `91F6DB209E679DEA32AFDB03648CB9E94447E92065E678228CB7D76AAE9043BF`
- Complete bundle: `dist/Offhand-Complete-v2.1.2-beta.20.zip`
  - SHA-256: `654E1C6206208393C5EC32A45BEEBD4211AFDC8B21D2A8ED51164FAF3A0B0D61`
- Portable Companion: `dist/Offhand-Companion.zip`
  - SHA-256: `C726444612DD740BE3F923B83704D155E21BC017F7C5FE245379B19DBECC76E3`
  - Canonical reviewed archive retained at `Companion/Offhand-Companion.zip` so
    GitHub Actions publishes the exact bytes instead of recompressing the same
    entries under a different PowerShell/.NET runtime.
- Standalone Companion: `dist/Offhand.exe`
  - SHA-256: `81EECE9430885CEAC178A44A42429854524279072305F9F94EE62E7CCD620CCB`
- Checksums: `dist/checksums-sha256.txt`
- Release notes: `dist/release-notes-v2.1.2-beta.20.md`

The final portable archive supersedes the earlier staged
`Offhand-Companion-Beta20.zip`. Its executable bytes are identical; its
`README.txt` adds the complete span, wizard, Mainhand HUD layout and reload
steps used by the current release documentation.

### Microsoft Store

- Executable: `dist/store-beta20-candidate/Offhand.exe`
  - File version: `2.1.2.20`
  - Product version: `2.1.2-beta.20`
  - SHA-256: `81EECE9430885CEAC178A44A42429854524279072305F9F94EE62E7CCD620CCB`
- Store package: `dist/store-beta20-candidate/Offhand-Companion_2_1_20_0_x64.msix`
  - Package identity: `N4UX.OffhandCompanion`
  - Package version: `2.1.20.0`
  - SHA-256: `CCF5E3E85528B33056A3AB43FC1A4C3B188CBC3ADD07395A87EF7289BE977C7C`
  - Embedded executable SHA-256: `81EECE9430885CEAC178A44A42429854524279072305F9F94EE62E7CCD620CCB`
The MSIX is intentionally unsigned. Microsoft signs it after successful Store
certification. A local Microsoft Defender custom scan reported no threats for
the executable, portable ZIP, and MSIX; this does not replace hash-specific
Defender submission and Store certification.

## Update behavior

- Packaged process detected: the dashboard says **Store Updates**, the tray says
  **Check Microsoft Store for Updates**, and the action opens product ID
  `9PL4PW84Q90W`. No GitHub API request is made by the Companion.
- No package identity detected: the dashboard and tray retain **Check for
  Updates**, and the existing one-time GitHub Releases query runs only after the
  user clicks it.
- Neither channel performs an automatic update check during startup.

## Required release checks

1. Submit the exact executable hash above to Microsoft Security Intelligence.
2. Submit the exact portable ZIP hash above without rebuilding the executable
   between submissions. Retain the MSIX unchanged for Store submission.
3. Confirm a clean result for every distributed file hash.
4. Upload the exact MSIX above as Store package `2.1.20.0` and complete Store
   certification.
5. After Store installation, confirm the button and tray action open the
   Offhand Companion Store page and do not contact the GitHub Releases API.
6. On the portable build, confirm **Check for Updates** still detects marked
   beta releases and opens the matching GitHub release page only with consent.

## Validation completed

- Companion preference, update-policy, topology, and safety tests passed.
- DPI layout tests passed at 125%, 150%, and 200%.
- MSIX unpack verification confirmed package version `2.1.20.0` and byte-for-byte
  equality of the embedded executable.
- Local Microsoft Defender custom scans completed with exit code 0 and no
  recent threat detections for the addon ZIP, complete bundle, portable ZIP,
  standalone executable, and MSIX.
