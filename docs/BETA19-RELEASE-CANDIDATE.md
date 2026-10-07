# Offhand 2.1.2 Beta 19 release candidate

Prepared: 2026-10-05

## Current tested candidate — review required before publication

The final source-tested Beta 19 candidate includes the later topology-bridge
repair used during the Forever validation cycle. Its exact release artifacts
were generated without rebuilding the tested executable on 2026-10-07:

| Artifact | SHA-256 |
| --- | --- |
| `Offhand.exe` | `89C065D28D5EB37A3CCBF868DA006C64E7FD403A50417E8799806DF92E46BF52` |
| `Offhand-Companion.zip` | `83EEDFE4DFE96EA4A34E6414E55797CAD4E02181604DAAA2F6E6B3EC57F1576B` |
| `Offhand-v2.1.2-beta.19.zip` | `21E2451651E9F8C978D7F64D589745307489855599EF23E30BBC1ED4B8CADF38` |
| `Offhand-Complete-v2.1.2-beta.19.zip` | `A0C7B3E15726481BC59E55369E186368961C15943A6D1581984A1F1EC96A22D4` |

All repository regression suites, manifest validation, Companion source
compilation, packaging checks, and the reported Forever live-test cycle pass.
The executable and minimal ZIP are newer than the Microsoft-reviewed hashes
below. Submit these exact two files for hash-specific review before updating the
release workflow or pushing `v2.1.2-beta.19`.

## Previously reviewed replacement candidate

This candidate added the corrected measured high-DPI layout and the repaired
user-initiated GitHub release check. Microsoft Security Intelligence received
these exact bytes on 2026-10-06:

| Artifact | SHA-256 | Submission ID |
| --- | --- | --- |
| `Offhand.exe` | `658B633783CA388C3E525B565D6061D8F75D9DEBB34E0489E04F046218AAF3E3` | `0f90acbe-658a-423b-9430-ea02125a9fc4` |
| `Offhand-Companion.zip` | `5AFB9C4DED3BC7EB4C05B5758501E94DCD414E21B13A4A105CEE215ED166D87B` | `4e76f681-9e40-4287-b0d4-14c15de4804d` |

Microsoft completed both reviews without retaining a malware detection. Cloud
and client reported no malware detected. These determinations do not transfer
to the newer final tested candidate.

## Previous review decision

That replacement Beta 19 executable and minimal ZIP passed Microsoft review.
They are not the final release candidate because the later tested topology-
bridge repair changed the executable. Public promotion remains blocked until
the current `89C065...` executable and `83EEDF...` archive receive their own
determination.

## Reviewed but superseded artifacts

These files passed Microsoft review but are not release candidates anymore:

| Artifact | Size | SHA-256 |
| --- | ---: | --- |
| `Offhand.exe` | 285,184 bytes | `F58E0F7CFACE8087B10F6607286765E8F6666E0B1EE39D851C9C02203EB92032` |
| `Offhand-Companion.zip` | 232,498 bytes | `3A34546CE069FB9CC164F247527AC0F617A74DE6C4C561204F7A977A717D4E2D` |
| `Offhand-v2.1.2-beta.19.zip` | 419,368 bytes | `C2D3069065F733355150F7A685DD5D32ED54430411CFC470611B8DF4F5ECA2FB` |
| `Offhand-Complete-v2.1.2-beta.19.zip` | 662,216 bytes | `F2683ED7C6503C9EDE2545B23722505C2EE80CEF769D730D3926397C5AF486EC` |

The minimal Companion ZIP contains exactly `Offhand.exe`, `README.txt`, and
`LICENSE`. Its embedded executable is byte-identical to the standalone file.

## Current scaled-layout test candidate

| Artifact | SHA-256 |
| --- | --- |
| `Offhand-beta19-dpi-layout-test.exe` | `3944FAD2BBE03E75FAC0198C73083BF34D68C6B3DEA6998F670D663AC682FC0F` |
| `Offhand-Companion-beta19-dpi-layout-test.zip` | `FFD7BD50C242398543B97C2311F7AA8E4A46E9589C85D4111FDC5184A61625D0` |

This test package passed local Defender scans and an executable layout regression
at 125%, 150%, and 200% scaling. It is deliberately not named as the canonical
release asset. The affected tester must confirm it before release artifacts are
rebuilt and resubmitted.

## Review records

- Standalone executable: Microsoft submission
  `9c3d9594-824f-46c4-8978-8656928258f2`.
- Minimal Companion ZIP: Microsoft submission
  `04c7ade1-df0a-4f39-a855-3806026abd6d`; submitted 2026-10-05, currently
  pending for cloud and client determinations.
- Superseded source-bearing ZIP: submission
  `4e2a81f6-2b66-4fc8-8193-fe199373a37f`. Do not publish this archive.

## Promotion checklist

- [ ] Affected 4K/150%-scale tester confirms the measured configuration layout.
- [ ] Rebuild and freeze the final canonical executable and minimal ZIP once.
- [x] Microsoft final determination is clean for the replacement executable hash.
- [x] Microsoft final determination is clean for the replacement minimal ZIP hash.
- [ ] Browser download testing passes for the ZIP on clean tester systems.
- [ ] Two-, three-, and four-monitor selector layout is confirmed where available.
- [ ] Recompute hashes and confirm they match this document exactly.
- [ ] Change the website download and source links from Beta 18 to Beta 19.
- [ ] Update `package.ps1`, `.github/workflows/release.yml`, and the Companion
      runbook so Beta 19 becomes the frozen baseline.
- [ ] Publish `v2.1.2-beta.19` as a GitHub prerelease using the prepared notes
      and all four artifacts plus `checksums-sha256.txt`.
- [ ] Validate the permanent `releases/latest/download/Offhand-Companion.zip`
      URL only after Beta 19 is deliberately marked latest.
- [ ] Upload the addon-only ZIP to CurseForge only if the Beta 19 addon changes
      are intended for that channel.

## Website state before approval

The checked-in website describes Beta 19 as prepared and under review but keeps
the actual download button on Beta 18. This is intentional. Promotion is a
small, auditable link-and-status change after approval rather than an early
public switch.
