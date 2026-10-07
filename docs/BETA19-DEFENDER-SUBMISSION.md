# Offhand Companion 2.1.2 Beta 19 — Defender Submission

Prepared: 2026-10-04

## Final tested candidate — review passed

The completed Forever validation cycle produced the final executable containing
the topology-bridge repair. The maintainer confirmed on 2026-10-07 that both
exact files passed Microsoft Defender review:

| Artifact | Size | SHA-256 |
| --- | ---: | --- |
| `Offhand.exe` | 289,280 bytes | `89C065D28D5EB37A3CCBF868DA006C64E7FD403A50417E8799806DF92E46BF52` |
| `Offhand-Companion.zip` | 233,519 bytes | `83EEDFE4DFE96EA4A34E6414E55797CAD4E02181604DAAA2F6E6B3EC57F1576B` |

The ZIP contains exactly `LICENSE`, `Offhand.exe`, and `README.txt`; its
embedded executable is byte-identical to the standalone candidate. Record the
portal submission IDs here when available.

## Previously reviewed replacement candidate submissions

Submitted to Microsoft Security Intelligence on 2026-10-06. These were the
post-DPI-layout and update-check candidate bytes. Microsoft completed both
reviews without retaining a malware detection, but the later topology repair
superseded them.

| Artifact | Size | SHA-256 | Submission ID | Final result |
| --- | ---: | --- | --- | --- |
| `Offhand.exe` | 288,256 bytes | `658B633783CA388C3E525B565D6061D8F75D9DEBB34E0489E04F046218AAF3E3` | `0f90acbe-658a-423b-9430-ea02125a9fc4` | No positive detection; cloud and client report no malware detected |
| `Offhand-Companion.zip` | 234,097 bytes | `5AFB9C4DED3BC7EB4C05B5758501E94DCD414E21B13A4A105CEE215ED166D87B` | `4e76f681-9e40-4287-b0d4-14c15de4804d` | No positive detection; cloud and client report no malware detected |

The archive contains exactly `LICENSE`, `Offhand.exe`, and `README.txt`. Its
embedded executable is byte-identical to the separately submitted executable.
Windows file metadata reports file version `2.1.2.19` and product version
`2.1.2-beta.19`.

## Submitted cases

Submitted to Microsoft Security Intelligence on 2026-10-05:

| Artifact | Submission ID | Initial portal result |
| --- | --- | --- |
| Superseded source-bearing `Offhand-Companion.zip` | `4e2a81f6-2b66-4fc8-8193-fe199373a37f` | Cloud: `Trojan:Script/Wacatac.C!ml`; client: pending. Do not publish this archive. |
| Superseded layout-v1 `Offhand.exe` | `9c3d9594-824f-46c4-8978-8656928258f2` | Cloud and client: no malware detected; analyst found no positive detection or telemetry indicators. Superseded by the scaled-layout correction. |
| Superseded layout-v1 minimal `Offhand-Companion.zip` | `04c7ade1-df0a-4f39-a855-3806026abd6d` | Cloud and client: no malware detected; analyst found no positive detection or telemetry indicators. Superseded by the scaled-layout correction. |

Related unchanged Beta 18 regression submission:
`699faa87-8977-48f4-ba00-9de03cab9a3d`.

## Reviewed but superseded artifacts

These hashes passed Microsoft review but must not be published as the final Beta
19 Companion because tester evidence showed malformed native selectors at 150%
Windows scaling. The replacement requires a new review.

| Artifact | Size | SHA-256 |
| --- | ---: | --- |
| `Offhand.exe` | 285,184 bytes | `F58E0F7CFACE8087B10F6607286765E8F6666E0B1EE39D851C9C02203EB92032` |
| Minimal `Offhand-Companion.zip` | 232,498 bytes | `3A34546CE069FB9CC164F247527AC0F617A74DE6C4C561204F7A977A717D4E2D` |

The executable embedded in `Offhand-Companion.zip` has the same SHA-256 as the
standalone `Offhand.exe`. Windows file metadata reports file version `2.1.2.19`
and product version `2.1.2-beta.19`.

## Replacement scaled-layout test candidate

This candidate replaces fixed child coordinates in the Configuration card with
measured flow-layout columns. It has passed the runtime layout regression at
125%, 150%, and 200% scaling and local Defender scans on definitions
`1.459.557.0`, but it has not completed tester or Microsoft review.

| Artifact | SHA-256 |
| --- | --- |
| `Offhand-beta19-dpi-layout-test.exe` | `3944FAD2BBE03E75FAC0198C73083BF34D68C6B3DEA6998F670D663AC682FC0F` |
| `Offhand-Companion-beta19-dpi-layout-test.zip` | `FFD7BD50C242398543B97C2311F7AA8E4A46E9589C85D4111FDC5184A61625D0` |

Do not rename or promote these test filenames until the affected 4K/150%-scale
tester confirms the layout. After confirmation, rebuild the canonical release
artifacts once, freeze their hashes, and submit those exact files to Microsoft.

## Defender form values

- Submission type: **Software developer**
- User opinion: **Incorrect detection**
- Product: **Offhand Companion**
- Version: **2.1.2 Beta 19**
- Source repository: <https://github.com/N4UX-GIT/Offhand-DualMonitor>

### Additional information for the EXE

```text
Official pre-release candidate for Offhand Companion 2.1.2 Beta 19, an open-source
Windows companion for the Offhand World of Warcraft addon.

File: Offhand.exe
SHA-256: 658B633783CA388C3E525B565D6061D8F75D9DEBB34E0489E04F046218AAF3E3
File version: 2.1.2.19
Product version: 2.1.2-beta.19
Source: https://github.com/N4UX-GIT/Offhand-DualMonitor

The program detects only allowlisted World of Warcraft processes and, when the
user requests it, adjusts the WoW window across selected displays. It stores
local preferences, provides a tray UI, and writes display-topology data for the
addon. It does not register global hotkeys, install startup persistence, inspect
security tokens, download or execute code, or perform a background update check.

Relative to the previously reviewed Beta 18 executable, Beta 19 changes the
display-selection layout so a fixed-height scrolling list cannot overlap the
Mainhand selector on systems with three or more monitors, plus corresponding
version metadata. Please analyze this exact hash and correct any false-positive
detection.

Microsoft previously reviewed the Beta 18 artifacts without retaining a malware
detection under submissions 5520a8b4-e4fa-44a1-aa61-09a9e8078998,
c874681f-5e6e-4c5f-9984-354dc76f85c0, and
ef82d479-bd24-42ab-b4c0-beaee069f869.
```

### Additional information for the ZIP

```text
Official portable archive for Offhand Companion 2.1.2 Beta 19.

File: Offhand-Companion.zip
Archive SHA-256: 5AFB9C4DED3BC7EB4C05B5758501E94DCD414E21B13A4A105CEE215ED166D87B
Contained Offhand.exe SHA-256: 658B633783CA388C3E525B565D6061D8F75D9DEBB34E0489E04F046218AAF3E3
Source: https://github.com/N4UX-GIT/Offhand-DualMonitor

The archive contains only the exact executable submitted separately, a plain
text quick-start/security README, and the license. Source, build scripts,
manifests, and development assets remain publicly available in the repository
and GitHub source archives but are intentionally excluded from the end-user
runtime package. It is not password protected. This replaces the superseded
source-bearing archive submitted as 4e2a81f6-2b66-4fc8-8193-fe199373a37f,
which received the provisional cloud label Trojan:Script/Wacatac.C!ml. Please
analyze this replacement archive and its contained executable as an
incorrect-detection submission.
```

## Local verification completed

- Companion regression tests passed.
- Release metadata tests passed.
- All client manifest and Lua regression tests passed.
- Microsoft Defender custom scans of both exact artifacts completed with no
  threats using the locally installed current definitions.
- The archive's embedded executable hash was independently verified against the
  standalone executable.

## Publication boundary

The final hashes at the top of this document completed Microsoft review and are
the GitHub Beta 19 release baseline. Recheck the staged hashes before changing
public links or publishing the release. The Store `2.1.19.0` submission embeds
the earlier reviewed `658B633...` executable and remains untouched while its
current certification completes.
