# Security Policy

## Supported releases

Security fixes are applied to the current public Offhand addon and Companion
release. Older beta artifacts remain available for reproducibility and
historical verification but are not supported for new security fixes.

The Microsoft Store is the recommended Windows distribution channel. Portable
GitHub artifacts must be downloaded only from the official release page and
verified against the SHA-256 checksums published with that same release.

## Report a vulnerability privately

Please do not disclose a suspected vulnerability, compromised artifact,
credential exposure, or reproducible security weakness in a public issue,
CurseForge comment, or Discord channel before it has been investigated.

Use GitHub's private vulnerability reporting form:

https://github.com/N4UX-GIT/Offhand-DualMonitor/security/advisories/new

Include, when available:

- The affected Offhand and Companion versions.
- The exact download URL, filename, size, and SHA-256 hash.
- Whether the file came from Microsoft Store, GitHub Releases, or elsewhere.
- Reproduction steps and the observed result.
- Antivirus product, detection name, definition version, and screenshot.
- Relevant logs with credentials, session tokens, personal data, and unrelated
  account information removed.

If you believe an account has been compromised, revoke its sessions and
credentials from a known-clean device before collecting further evidence.
Never send passwords, passkeys, recovery codes, session tokens, or private
keys to the Offhand project.

## Response

The maintainer will acknowledge a complete report as soon as practical,
preserve the referenced artifacts, compare their hashes with canonical release
assets, and assess whether distribution should be paused. Confirmed issues will
be corrected before technical details are published. Reporter credit will be
offered unless the reporter requests anonymity.

## Verification guidance

Artifact hashes, behavior documentation, Microsoft review records, and local
verification commands are maintained in the repository's root
[`SECURITY.md`](../SECURITY.md). That document is evidence and user guidance;
this file defines the private reporting process.
