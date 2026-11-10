# Companion 2.1.6 Store preparation

Date: 2026-11-10, Europe/Berlin. Owner approved the UI Preview 8 layout and requested remaining checks and Store submission preparation. This authorizes preparation/testing; no upload, certification submission, public release or website deployment has been performed.

## Planned identity and scope

Product 2.1.6; executable 2.1.6.1; assembly 2.1.6.0; Store MSIX 2.1.600.0, x64. The installed production baseline was independently read as N4UX.OffhandCompanion_2.1.500.0_x64__bwe0ea6astzt8. Store identity, publisher, application ID, minimum Windows version, capabilities and disabled-by-default Windows startup task are retained. Candidate output is separate from all frozen published artifacts.

The new UI includes Setup/Advanced navigation, balanced 32px tabs and 44px actions, updated branding/detected addon metadata, a replayable first-run tutorial and removal of persistent captions/instructions. Advanced holds custom layouts/profiles, standard-layout reset, Auto-span and troubleshooting. New two-monitor custom drafts cover the full Offhand monitor; saved areas remain unchanged. The final tutorial button also exposes Finish as its accessible name.

Companion protocol 1 and topology schemas remain unchanged. Current addon 2.1.5 Pre-Release Beta 28 is compatible: Core/Viewport.lua compares the writer semantically against X-Offhand-Companion-Min-Version (2.1.2-beta.19), rather than requiring equal addon/Companion patch versions. No addon files or release labels are changed; published add-on and website download references stay on their currently published 2.1.5 assets until the new Companion is actually released.

## Version and package references

Microsoft reserves the final MSIX version component for Store use and requires submission packages to end in zero; the applicable highest version is selected for delivery. See [Microsoft package version guidance](https://learn.microsoft.com/en-us/windows/apps/publish/publish-your-app/package-version-numbering). Account-side highest published/in-flight ordering must still be checked before a future upload; installed-package ordering is not an account-side query.

WACK is a local preflight, not Store certification. The configured Desktop Bridge required and optional tests are described in [Microsoft's Desktop Bridge test guidance](https://learn.microsoft.com/en-us/windows/uwp/debug-test-perf/windows-desktop-bridge-app-tests). Exact artifact hashes, complete report status and optional findings must be retained.

## Validation plan and preservation

Run the current Companion suites and Lua regression corpus, freeze the production EXE/portable ZIP, build the exact unsigned production MSIX, validate manifest/boundaries/payload parity, and run an exact-candidate Defender scan. The isolated package probe loads the hash-pinned payload under package identity with monitoring disabled and never calls Span/Restore or game commands. It tests existing custom/profile/Unicode settings, tutorial completion/relaunch/replay, Store routing, locked-save preservation and retry.

The elevated preflight installs and upgrades only N4UX.OffhandCompanion.UpgradeValidation216, from 2.1.500.0 to 2.1.600.0 with exact old/new EXE payloads, then removes that private identity. It does not replace the real Store app, import a certificate or change Developer Mode. WACK analyzes the exact production submission MSIX with -noinstallappx. Real app identity/EXE/preference hashes are checked before/after. A concurrent owner preference change is reported rather than overwritten.

Store certification, production-PFN delivery/upgrade, physical mixed-DPI/hotplug/three-monitor acceptance, Windows 10/Wine runtime acceptance and security reputation remain separate evidence boundaries. This native UI update does not expand prior game/renderer compatibility claims. Current-source native/synthetic tests are distinct from scoped previous game evidence. Shared KB status, Store-preflight findings, runbook and current live source were consulted.

## Results

Preparation is in progress. Exact source/artifact identities and final check results are recorded below once complete.
