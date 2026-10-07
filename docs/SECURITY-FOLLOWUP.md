# Companion security follow-up

Last updated: 2026-10-06

## Final tested Beta 19 candidate — review passed

- `Offhand.exe`:
  `89C065D28D5EB37A3CCBF868DA006C64E7FD403A50417E8799806DF92E46BF52`
- `Offhand-Companion.zip`:
  `83EEDFE4DFE96EA4A34E6414E55797CAD4E02181604DAAA2F6E6B3EC57F1576B`

These artifacts include the topology-bridge repair validated during the final
Forever test cycle. The maintainer confirmed both exact submissions passed
Microsoft review on 2026-10-07. Their portal submission IDs still need to be
copied into this record.

## Previously reviewed Beta 19 candidate and current Store submission

Microsoft Security Intelligence completed review of the current Beta 19
executable and minimal Companion archive on 2026-10-06 without retaining a
malware detection. Cloud and client report no malware detected.

- `Offhand.exe`: `658B633783CA388C3E525B565D6061D8F75D9DEBB34E0489E04F046218AAF3E3`
  — submission `0f90acbe-658a-423b-9430-ea02125a9fc4`
- `Offhand-Companion.zip`:
  `5AFB9C4DED3BC7EB4C05B5758501E94DCD414E21B13A4A105CEE215ED166D87B`
  — submission `4e76f681-9e40-4287-b0d4-14c15de4804d`

The archive contains exactly `LICENSE`, `Offhand.exe`, and `README.txt`, and its
embedded executable is byte-identical to the separately reviewed executable.
Retain these as historical review records. The Store `2.1.19.0` package now in
certification embeds this earlier `658B633...` executable; allow that submission
to complete, then use a higher Store version for the final topology-repair build.

## Frozen Beta 18 candidate

- Version: `2.1.2-beta.18`
- Canonical executable: `Offhand.exe`
- Executable SHA-256:
  `A42A45CB149C66EF884308F15A79EE8905C58A94E9B4AE1A3B05B43BAF929F37`
- Canonical archive: `Offhand-Companion.zip`
- Archive SHA-256:
  `AD49BE14A9C8ADF5A888F873CE9B99F183C4AD2924909ECDF52801F303248A93`
- VirusTotal result observed for the executable on 2026-10-03: 6/70.
- Reported engines at that scan: CrowdStrike Falcon, Elastic, Malwarebytes,
  SecureAge, Trapmine, and VIPRE.

Every rebuild or regenerated archive has a different hash. Do not replace these
canonical files in place or describe a different hash as the reviewed Beta 18
artifact.

## Microsoft determinations

By 2026-10-04, Microsoft Security Intelligence had completed its reviews of the
submitted Beta 18 executable and archives without retaining a malware
detection. Authenticated submission records:

- <https://www.microsoft.com/en-us/wdsi/submission/5520a8b4-e4fa-44a1-aa61-09a9e8078998>
- <https://www.microsoft.com/en-us/wdsi/submission/c874681f-5e6e-4c5f-9984-354dc76f85c0>
- <https://www.microsoft.com/en-us/wdsi/submission/ef82d479-bd24-42ab-b4c0-beaee069f869>

Chrome no longer blocked the canonical executable or ZIP in the maintainer's
local test. Edge accepted the ZIPs but still described the direct unsigned EXE
as **"isn't commonly downloaded."** Microsoft documents that wording as an
application-reputation notice, not a malware determination. Continue testing
from independent browsers and networks; do not generalize one local result to
every user.

## Vendor follow-up

Submission or contact attempts have been made for the VirusTotal vendors named
above. Track each vendor independently because a Microsoft determination does
not update third-party verdicts.

- CrowdStrike Falcon: correction request sent; final response not yet recorded.
- Elastic: false-positive form submitted; final response not yet recorded.
- Malwarebytes: initial forum submission failed; a completed review is not yet
  recorded.
- SecureAge: the original email address rejected external mail. Use the official
  SecureAge false-positive form; a completed review is not yet recorded.
- Trapmine: correction request sent; final response not yet recorded.
- VIPRE: support request submitted; final response not yet recorded.

For every submission include the exact file, SHA-256, VirusTotal URL, immutable
source and release URLs, `SECURITY.md`, Microsoft's clean determinations, and a
short explanation of the Companion's allowlisted process detection, window
management, display identification, tray operation, and guarded Forever
recovery behavior.

## Warning classification for support

- **"Isn't commonly downloaded" / "Unknown publisher"**: unsigned-file or
  publisher reputation warning. It is not, by itself, a malware detection.
- **"Virus detected" / named malware detection**: stop and collect the exact
  URL, filename, SHA-256, browser, security product, and definition version.
- **Checksum mismatch**: do not run the file. Confirm the download source and
  investigate immediately.

Never instruct users to disable Windows Security. Prefer the official ZIP,
publish checksums, preserve immutable release assets, and keep the manual
no-executable setup available.

## Longer-term trust work

- Obtain Authenticode code signing tied to a verified publisher identity when
  a sustainable option becomes available.
- Keep GitHub build-provenance attestations and SHA-256 release checksums.
- Submit only frozen release candidates because every rebuild changes the hash.
- Recheck each final candidate before release and after vendor decisions.
