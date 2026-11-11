# Companion 2.1.5 public Store submission, 9 November 2026

## Submitted artifact and authorization

The publisher explicitly requested public submission/publication without waiting for the private internal QA flight. This supersedes the earlier instruction to leave the public submission unchanged. Outstanding flight acceptance was accepted as a release limitation, not marked as passed. No additional runtime changes or rebuild were made.

- Partner Center product: `9PL4PW84Q90W`.
- Public Submission 6: `1152921505702348834`.
- Product version 2.1.5, file build 2.1.5.1, MSIX 2.1.500.0, x64, Windows.Desktop minimum 10.0.17763.0.
- Runtime source: `7bc07a60113c7c990067d5fd86215ace310399cc`.
- Exact candidate: `dist/companion-2.1.5-candidate-2/store/Offhand-Companion_2_1_500_0_x64.msix`.
- MSIX SHA-256: `9AD0A4F561C27A750885E8030B5E72DFC4FBD80DF8CD507FEB26FB1D335B71CA`.
- EXE SHA-256: `95811DBB7020A20E2541AE123E69FE80721C83A0FD52D0EE5557DD6D54DCCC2A`.

## Partner Center result

Uploaded the exact validated package and saved it as the new public package. The portal replaced the superseded 2.1.400.0 package in this draft because the new package supports the same customers. Previously published Submission 5 and local 2.1.4 artifacts remain preserved.

English release notes now describe the quiet daily Store query, static update indicator, manual Store fallback and separate cache. The description discloses the availability query and local cache. Both saved fields were verified through a fresh listing view. Supplemental certification guidance includes version/hash details, reviewer steps, actual evidence and outstanding limitations. Pricing, availability, age ratings, device-family policy, capabilities, screenshots and the existing runFullTrust justification were retained. No gradual rollout or mandatory-update setting was selected.

The existing **Publish this submission as soon as it passes certification** option was verified selected. After submission, Partner Center showed **Product update: In certification (Submission 6)**, Submission complete, Pre-processing in progress, and **Your product will start publishing as soon as it passes certification**. This proves submission acceptance with automatic publication enabled; it does not prove certification completion or public availability.

Proof: `dist/companion-215-public-submission/store-submitted.png`. Product dashboard: https://partner.microsoft.com/en-us/dashboard/products/9PL4PW84Q90W/overview . Microsoft Store: https://apps.microsoft.com/detail/9PL4PW84Q90W .

## Evidence and remaining limitations

- WACK: full run, overall PASS, 13 required passes, zero required failures. Existing optional blocked-executables finding reviewed in `docs/evidence/companion-215-wack.json`.
- Fresh exact-candidate local Defender custom scan: exit 0, no threats. No Microsoft false-positive submission verdict or future detection guarantee is implied.
- 472 production/preview x64/x86 fixture assertions passed, including scheduling, cache, timeout, cancellation and static UI at 100-200% scale.
- Actual production Store query under installed 2.1.400.0 identity returned NoUpdate in 1,395 ms. Relaunch reused the persisted result with zero API calls. Separate Store-identity persistence regression passed 47 checks.
- That diagnostic host is not normal Store-delivered 2.1.5 activation. Actual 2.1.5 Store delivery/upgrade, real Available and real signed-out/offline behavior remain unobserved. Windows 10/Wine runtime acceptance also remains unobserved. The publisher chose not to wait for flight completion.
- API failure leaves manual Store access and window management available. The Companion uses availability queries only, with no self-install/download/restart flow.

The existing one-account private QA flight remains separate and was not cancelled or widened. No add-on, portable GitHub release, website deployment or account/security/network settings were changed in this submission task. Existing Offhand Pre-Release Beta 27/protocol 1 remains compatible.
