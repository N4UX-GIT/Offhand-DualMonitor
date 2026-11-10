# Offhand Companion 2.1.6 Store submission

Prepared 2026-11-10. Not uploaded, submitted or published.

## Package

Use `dist/companion-2.1.6-store-submission/Offhand-Companion_2_1_600_0_x64.msix`.

- Product: Offhand Companion, `9PL4PW84Q90W`.
- Identity: `N4UX.OffhandCompanion`.
- Publisher: `CN=E7BD7796-76DA-40C2-B114-9DD85609CD7F`.
- Application ID: `OffhandCompanion`.
- Display version: 2.1.6. Executable: 2.1.6.1. Package: 2.1.600.0, x64.
- SHA-256: `87866739AFBA3BD6C9C73FA39F37C4E11CCE80D25A58A3E45C6B21F4234F2691`.
- Embedded EXE SHA-256: `166C6BD750282C4EFDDE12BBE4A64DAFB1E88B2A29C826A86365FEFF741D4879`.

Upload this exact unsigned production package for Microsoft Store signing. Do not upload the internal portable candidate, private upgrade packages or test host. Do not rebuild the tested executable. Before upload, verify the existing Partner Center product and highest published/in-flight package version; the installed baseline is 2.1.500.0 but is not an account-side query. Retain existing availability, pricing, capabilities and startup policy unless the owner requests a change.

The read-only package-list check encountered an expired Partner Center session. Sign in manually before the final account-side version check and upload. No update draft was created during preparation.

## What's new

Offhand Companion 2.1.6 brings a cleaner interface with Setup and Advanced tabs. Everyday monitor selection and Span/Restore controls stay easy to find, while custom workspaces, profiles, Auto-span and troubleshooting live in Advanced.

A new optional first-run tutorial introduces the controls. You can replay it from Help whenever needed. Updated branding, detected addon version information and balanced controls complete the refresh.

New two-monitor custom plans start with the full Offhand monitor, helping avoid accidental partial workspaces. Existing saved layouts and profiles are preserved. The current Pre-Release Beta 28 addon remains compatible.

## Notes for certification

This is an update to the existing free, full-trust Windows desktop Companion. It runs as the invoking user. Package identity, publisher, application ID, capabilities, minimum Windows version and disabled-by-default Windows startup task are retained.

The app opens without World of Warcraft installed or running. To exercise spanning, a separately installed WoW client must be running in standard Windowed mode. The owner chooses displays and Mainhand, then clicks Span WoW Now. The player performs `/reload` and initial addon setup inside WoW. Restore Window returns the game to its remembered window. No account sign-in is required by the Companion.

The Setup/Advanced interface and skippable introduction are the main changes. Help > Start Companion tutorial replays the introduction. The tutorial explains controls and temporarily navigates the Companion UI; it does not apply a layout, change monitor selections or send game input. Previously saved layouts/profiles remain intact. Existing custom layouts are identified in Advanced; users can choose Use standard display layout there.

Store updates remain managed by Microsoft Store. The existing quiet availability check does not download or install updates or automatically restart the app. User-triggered website, Discord, CurseForge and Store links open their normal destinations.

Local WACK on this exact MSIX completed with overall PASS, a full run and all 13 required tests passing. Its optional Blocked executables test reports existing Process.Start link/settings references and a CsI string inside an unchanged PNG icon resource. The resource was compared byte-for-byte with the published 2.1.5 build. A fresh local Defender scan found no threats. Full report and review are included with the local handoff; local preflight does not replace Store certification.

The published 2.1.5 Pre-Release Beta 28 addon remains compatible through the unchanged Companion protocol. This interface update does not require an addon release.

## Evidence

See [the preparation record](../docs/COMPANION-2.1.6-STORE-PREPARATION-20261110.md) and [machine-readable receipt](../docs/evidence/companion-216-preflight.json). Physical mixed-DPI/hotplug/three-monitor, Windows 10/Wine, actual Store-delivered upgrade and real update-available responses are outside this preparation's fresh acceptance evidence. No new game runtime compatibility claim is made.
