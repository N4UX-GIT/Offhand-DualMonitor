# Offhand 2.1.3 Microsoft submission

Recorded 2026-11-08 Europe/Berlin. The owner explicitly authorized checking
Partner Center and submitting the prepared update to Microsoft Store and
Defender where applicable.

## Microsoft Store

The authenticated Partner Center account contains the existing Offhand Companion
product `9PL4PW84Q90W`. Before creating the update, Current packages showed only
published Submission 2, `2.1.20.0` x64. The product overview offered Start update,
with no in-flight update, and Package Flighting explicitly reported no flights.
The frozen `2.1.300.0` package is newer than the published package.

Submission 3, ID `1152921505702343609`, was created and the exact frozen MSIX
uploaded. Partner Center validated it, including identity/version compatibility,
and saved it as the sole package in this draft. The lower-version package was
removed from the new submission automatically because the new package supports
the same customers; the existing published submission remains available.

| Item | Value |
| --- | --- |
| Product version | 2.1.3 |
| EXE file version | 2.1.3.9 |
| MSIX package version | 2.1.300.0, x64 |
| Frozen runtime source | d2934ef802cf0c8deb62d29fd0c932658e64afa3 |
| MSIX SHA-256 | `5F77AA758BD12FB45520381CAEE9FFE1644D868B00D600710E622972708A6F68` |
| Embedded EXE SHA-256 | `88916B6FBAA4FF2E81EC574F8FA248C553ED531AD7A3DC828FF4948568797443` |

The existing `runFullTrust` explanation was retained. Updated Additional Testing
Information includes setup, manual `/reload`, ordinary Windowed mode, separate
add-on installation, exact hashes and the reviewed optional WACK finding.
The saved notes were verified after reloading the page. No credentials were
added. Pricing, markets, age ratings, supported device families and mandatory/
gradual-update settings were not changed.

The English Store description, short description and release notes were updated
for 2.1.3: custom and Flexible Layout workspaces, visual selection, previews,
profiles, active monitor identities, scaling/diagnostics, recovery, taskbar
presentation, UI/help and reload guidance. The listing explicitly requires the
separately installed matching 2.1.3 add-on for the new workspace integration.

The publishing option was changed to **Don't publish this submission until I
select Publish now**, so release can be coordinated with the matching add-on
and portable publication. This is a certification submission, not public rollout.

After Submit for certification, Partner Center visibly reported:

- **Update in certification**.
- **Product update: In certification (Submission 3)**.
- Submission: complete; Pre-processing: in progress.
- Certification and Publishing stages: not started at that observation.
- **Your product will start publishing when you click on Publish now.**

The status was observed shortly before `2026-11-07T23:22:03Z`, which is
2026-11-08 in Europe/Berlin. Partner Center itself displayed Last modified
11/07/2026; that portal date is preserved as observed rather than treated as
the user's local date. Certification acceptance and Store-delivered upgrade
are not yet established. The current public package remains 2.1.20.0.

[Partner Center product overview](https://partner.microsoft.com/en-us/dashboard/products/9PL4PW84Q90W/overview)
is the place to review certification and, when ready, perform manual publication.
Do not cancel certification or click Publish now incidentally.

## Microsoft Defender

The Microsoft Security Intelligence portal was inspected while signed in with
the Software developer persona and Microsoft Defender Antivirus (Windows 11)
selected. It offered only malware/malicious, PUA, incorrectly detected malware
and incorrectly detected PUA classifications, and exposed a required detection
name. There is no current reproduced detection for these exact samples.

No sample was selected/uploaded and no Defender submission was filed. Choosing
an incorrect classification or inventing a detection would misstate the local
evidence. The existing exact EXE/minimal ZIP and English context remain prepared
for an actual detection or a suitable review route. No blanket exemption,
SmartScreen reputation clearance or Microsoft AV determination is claimed.

The [submission portal](https://www.microsoft.com/en-us/wdsi/filesubmission)
and [Microsoft developer FAQ](https://learn.microsoft.com/en-us/defender-xdr/developer-faq)
remain the primary references. Defender Antivirus and SmartScreen reputation
are separate. The four previously recorded local scans were clean with
definitions 1.463.180.0; no new scan or Microsoft review is inferred from opening
the portal.

## Evidence and remaining work

The [final WACK receipt](COMPANION-2.1.3-WACK-20261107.md) remains the exact-file
preflight evidence. All frozen sample hashes were checked before upload and the
runtime files were not rebuilt for this submission. Canonical Beta 20 and
unofficial Revision 4 public artifacts were not replaced. No GitHub or
CurseForge publication occurred in this task.

Local submission receipt:
`dist/2.1.3-microsoft-submission-20261108/submission-status.json`.
Earlier preparation archives remain historical and unmodified; their
not-submitted statements describe their creation time and are superseded for
the Store by this dated record.

Next external steps are Microsoft's certification result, coordinated matching
add-on/portable distribution, manual Publish now when ready, and verification
of the resulting Store-delivered update. The broader physical-display and exact
candidate live-WoW acceptance gaps in the preflight receipt remain separate.
