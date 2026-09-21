# Companion security follow-up

Last updated: 2026-09-21

## Deferred antivirus false-positive submissions

Submit the stable Companion release candidate to the vendors below after its
version and binary are frozen. A submission applies to the exact file hash, so
do not submit an intermediate build that will immediately be replaced.

Current reviewed candidate:

- Version: 2.0.3
- File: `Offhand.exe`
- SHA-256: `3840FF7DE6395277D756292358C8493C5D023881C00909BE84120710CD0D6A94`
- VirusTotal result observed 2026-09-21: 5/71
- Generic detections: CrowdStrike Falcon, Elastic, Malwarebytes, SecureAge,
  and Trapmine
- Microsoft Defender local custom scan: no threats found

Submission channels:

- CrowdStrike VirusTotal ML false positives: `VTscanner@crowdstrike.com`
- Malwarebytes: Support or the Malwarebytes False Positives forum
- Elastic: community False Positive Submission Form
- SecureAge: SecureAPlus false-positive submission form
- Trapmine VirusTotal ML false positives: `fp@trapmine.com`

Include the exact executable, SHA-256, VirusTotal report URL, official repository
and release URLs, `SECURITY.md`, the clean-build and Defender results, and a short
explanation of the window-management, global-hotkey, tray, and guarded Forever
recovery behavior. Record submission references and final vendor decisions here.

## Longer-term trust work

- Obtain Authenticode code signing tied to a verified publisher identity.
- Keep GitHub build-provenance attestations and SHA-256 release checksums.
- Submit only frozen release candidates because every rebuild changes the hash.
- Recheck the stable signed candidate before release and after vendor decisions.
