# Companion 2.1.4 release preparation, 2026-11-09

Status: unpublished candidate preparation. No GitHub or Store publication is
authorized by this record. The owner requested remaining UI checks and next
release preparation after reviewing local UI Preview 2.

## Scope and identity

Product 2.1.4, assembly 2.1.4.0, exact production file build 2.1.4.1, proposed
Store package 2.1.400.0. Protocol 1 and supported topology schemas are unchanged.
The existing add-on remains compatible; its independent pending source changes
are not part of this Companion-only candidate. Frozen 2.1.3 and earlier
published artifacts remain untouched. Release copy is in
`Companion/RELEASE-NOTES-2.1.4.md`.

The dashboard changes are recorded in
`COMPANION-DASHBOARD-ACTIONS-20261109.md`. Added a native dark-scrollbar treatment
for the dashboard, log, Help and workspace dialogs. This retains Windows
scrolling, text selection, keyboard operation and accessibility. High contrast
resets the theme to the system default. Missing theme exports fall back without
blocking the interface.

The reviewed new import is exported `uxtheme.dll!SetWindowTheme`, called only
through private code taking managed Companion controls. There are no new game
inputs, process-memory operations, ordinal exports or hooks. Microsoft documents
[SetWindowTheme](https://learn.microsoft.com/en-us/windows/win32/api/uxtheme/nf-uxtheme-setwindowtheme).
The `DarkMode_Explorer` class is used by
[Microsoft PowerToys](https://github.com/microsoft/PowerToys/blob/main/src/modules/ZoomIt/ZoomIt/Utility.cpp),
but its availability across Windows/Wine versions is not a documented promise.
The local Windows 11 preview visibly showed dark dashboard and Activity Log
scrollbars, and wheel scrolling worked. Other OS versions and a physical
high-contrast transition have not been observed in this run.

## Reproduction and artifacts

Build production runtime and portable archive using
`scripts/New-CompanionUiCandidate.ps1 -OutputDirectory <fresh-directory>`.
This builds the ordinary runtime and records source hashes, source revision,
EXE/archive hashes and dirty-tree state. It refuses public artifact directories
and verifies canonical artifact hashes remain unchanged. The runtime archive
contains only Offhand.exe, README.txt and LICENSE.

Build the unsigned Store candidate from that exact EXE with
`Companion/Store/Build-StorePackage.ps1`, explicit package version 2.1.400.0,
CompanionPath and ExpectedCompanionSha256. Validate using
`tests/companion-store-package.ps1` with the same hash and version. Do not install
or replace the live Store app for structural validation.

The isolated review build is a separate `UI_PREVIEW` configuration, file
2.1.4.8001. It uses its own settings, auto-span/recovery disabled, and a separate
instance mutex. Do not ship this preview as the production candidate.

## Evidence and release gates

Current local logs are under ignored `dist/companion-ui-214-checks/`. Final
candidate hashes and the completed validation result must be recorded alongside
the staged artifacts. Historical 2.1.3 WACK, Defender and upgrade passes do not
automatically certify this new EXE. New Store submission/certification and public
publishing remain separate actions. No fresh live WoW acceptance is claimed for
this UI-only change.
