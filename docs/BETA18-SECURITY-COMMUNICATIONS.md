# Beta 18 security communication copy

Use this copy only for the canonical Beta 18 files recorded in `SECURITY.md`.
Do not reuse the Microsoft-review statement for a rebuilt executable or newly
generated archive with a different SHA-256 digest.

## Discord pinned post

### Offhand Companion Beta 18 download and security status

Microsoft Security Intelligence has reviewed the submitted Offhand Companion
Beta 18 executable and archives without retaining a malware detection. Chrome
is currently allowing the official executable and ZIP in our local testing;
independent browser testing is continuing.

**Recommended download:**
https://github.com/N4UX-GIT/Offhand-DualMonitor/releases/download/v2.1.2-beta.18/Offhand-Companion.zip

The Companion is still unsigned. Microsoft Edge may describe the standalone
EXE as **"isn't commonly downloaded."** Microsoft identifies that wording as a
SmartScreen application-reputation notice; it is not the same as Defender
reporting malware.

Please download only from the official GitHub release and verify the published
SHA-256 checksum. Do not disable Windows Security. If you see **"Virus
detected"**, a named malware alert, or a checksum mismatch, stop and send us:

- the exact download URL;
- filename and SHA-256;
- browser and Windows version;
- security product and definition version; and
- a screenshot of the complete warning.

The Companion is optional on supported clients; a no-executable manual setup is
available here:
https://offhand-wow.onrender.com/manual-spanning.html

Source, hashes, behavior disclosure, and Microsoft submission references:
https://github.com/N4UX-GIT/Offhand-DualMonitor/blob/main/SECURITY.md

## Short support reply

Thanks for reporting this. Please check the exact wording. Edge saying the EXE
**"isn't commonly downloaded"** is an unsigned-file reputation notice, not a
malware detection. Microsoft Security Intelligence reviewed the submitted Beta
18 files without retaining a malware verdict. Please use the official
`Offhand-Companion.zip`, verify its published SHA-256, and do not disable your
security software. If the message says **"Virus detected"** or names a threat,
send us the exact URL, file hash, browser, security product/definition version,
and a full screenshot so we can investigate the specific file.

## GitHub Beta 18 release-note addition

### Security and download status

Use `Offhand-Companion.zip` as the recommended portable download. Microsoft
Security Intelligence reviewed the submitted Beta 18 executable and archives
without retaining a malware detection. The exact reviewed hashes and submission
references are published in `SECURITY.md`.

The standalone `Offhand.exe` is unsigned and may still trigger Edge's **"isn't
commonly downloaded"** SmartScreen reputation notice. This is distinct from a
Defender malware detection. Verify `checksums-sha256.txt`; do not run files from
unofficial mirrors or files whose hashes do not match.

## CurseForge comment reply

Thanks for raising this. The reports in the earlier comments reflect warnings
that users genuinely received, and we have added a full account of the
investigation, Microsoft reviews, exact hashes, and safe-download guidance to
the new **Public Service Announcement: Companion download and antivirus
status** section of the project description. It also explains how to determine
whether a linked VirusTotal report covers the current Beta 18 file or an older
hash.

The recommended Windows Companion download is the official Beta 18 ZIP.
Microsoft Security Intelligence reviewed the submitted Beta 18 executable and
archives without retaining a malware detection. Edge may still describe the
unsigned standalone EXE as **"isn't commonly downloaded"**; that is an
application-reputation notice, not a malware verdict. Download only through the
official Companion page, verify the published SHA-256 checksum, and never
disable Windows Security. Report any **"Virus detected"** or named-malware alert
with the exact URL, file hash, browser, security product/definition version, and
a complete screenshot.
