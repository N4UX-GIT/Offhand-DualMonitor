# Offhand Companion 2.1.8 Store submission handoff

Prepared locally for the existing Offhand Companion product `9PL4PW84Q90W`.

| Field | Value |
| --- | --- |
| Package | `Offhand-Companion_2_1_800_0_x64.msix` |
| Package version | `2.1.800.0` |
| Executable | `Offhand.exe`, file version `2.1.8.1` |
| Identity | `N4UX.OffhandCompanion` |
| Publisher | `CN=E7BD7796-76DA-40C2-B114-9DD85609CD7F` |
| Application ID | `OffhandCompanion` |
| MSIX SHA-256 | `313AAB3A7DDCC1A82EAA8AB6099E3601E42E7DF395673F96877080F0F6E0E501` |
| Embedded EXE SHA-256 | `90B80AAB395BC0A1BB22A45441A4D8CAD8BF22CC43A3C6E38756337281E303E2` |

The unsigned x64 MSIX is in `dist/companion-2.1.8-release/store`. The Store
signs the accepted package. The portable GitHub ZIP contains the same executable.

Before upload, confirm the current published, pending and flight package versions
in Partner Center. The installed Store-signed package was `2.1.700.0`. The
previously loaded dashboard showed Submission 8 in certification and required a
fresh sign-in on refresh. Start the next draft after the current submission
status and package ordering are confirmed. Retain the current price,
availability, privacy listing, age ratings and existing full-trust justification.

## What's new

Workspace Profiles now explains how to save a profile when you're using the
Standard layout. If Windows can't identify a selected monitor, Companion names
the affected display and points you to Copy Display Diagnostics. If WoW fails to
keep its requested window size or position, those diagnostics include the most
recent failed span and its rollback result.

Your saved preferences and profiles carry forward. This update works with
Offhand Beta 32 and Beta 33.

## Notes for certification

This updates the existing free, full-trust Windows desktop app. The identity,
publisher, capabilities, minimum Windows version and opt-in startup task are
retained. The app opens without World of Warcraft and requires no sign-in.

To check the profile guidance, open Advanced and Workspace Profiles with the
Standard layout saved. The app explains that a Multiple workspaces or Flexible
plan must be saved before creating a profile. To exercise spanning, start a
separately installed World of Warcraft client in standard Windowed mode.
Select the displays and Mainhand, then click Span WoW Now. Copy Display
Diagnostics reports monitor identity and captures the most recent bounds failure
if one occurred in that session. Restore Window returns WoW to its saved window.

Local checks covered package identity and payload, update and profile behavior,
display identity and synthetic native span rollback. The exact payload passed a
Microsoft Defender custom scan. Local Windows App Certification Kit testing
requires elevation and did not complete. Store certification and a
Store-delivered upgrade remain pending.
