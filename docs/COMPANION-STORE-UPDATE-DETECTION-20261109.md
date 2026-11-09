# Quiet Store update detection, 9 November 2026

## Scope and source

Branch: `codex/companion-store-update`, based on the reviewed Companion dashboard/source records through `8c6e089`. Product 2.1.5, production file 2.1.5.1, proposed Store package 2.1.500.0. No add-on, public executable, GitHub release asset or Store submission is changed by this work. The website deployment remains independent.

The shared knowledge README/research skill, status and Store-update finding were consulted before implementation. Game snapshots are review-due, but this change makes no WoW API decisions. Current source and primary Microsoft documentation are the evidence used here.

## Behavior

Store package identity is required. The first query is scheduled 30 seconds after OnShown. Subsequent checks are limited to one per 24 hours using an atomically written package-local StoreUpdateCheck.ini and an exclusive claim lock, separately from layout preferences. Failure attempts also consume the allowance. Cached availability survives restart, expires after 24 hours, and does not carry over to a new build; the throttle survives a build change. Corrupt/implausible state can recover, while a denied cache write skips the query.

The WinForms timer calls StoreContext.GetAppAndOptionalStorePackageUpdatesAsync on its UI thread after binding the Companion HWND through IInitializeWithWindow. Only OS WinRT metadata and the strong-named .NET Framework async adapter are resolved on demand; portable/Wine startup has no mandatory WinRT SDK dependency. The documented COM IID is 3E68D4BD-7135-4D10-8018-9FB6D9F33FA1. No new DllImport declarations were introduced. No package download/install, forced restart, executable replacement, service or scheduled task is added.

A 15-second asynchronous budget, owner cancellation and late-result guards bound the operation. Repeated disposal is idempotent. Failures remain Unavailable rather than being reported as up-to-date. The passive footer button and tray menu agree about availability. The existing click still opens the official Store product URI. Quiet checks do not open a Store page, message box or notification balloon. Portable GitHub checks remain explicit. Preview/diagnostics builds are excluded.

## Verification

- Store update fixture: x64/x86, production/preview, 120/116 checks per architecture (472 total). Covers persisted success/failure/cooldown, upgrades, stale and malformed cache, claim locks, timeout, provider exceptions, cancellation, real timer scheduling/cached suppression, late completion and repeated disposal. Native footer and accessible action checks passed at 100%, 125%, 150%, 175% and 200% scaling without changing form/button bounds.
- Real local Windows metadata, generic async projection and desktop owner-window initialization passed in both architectures. The fixture deliberately makes no Store availability request. Windows Server CI may explicitly skip a missing/unregistered native Store runtime; unexpected binding failures remain failures.
- Existing preference/dashboard-scale, display identity, partial/flexible/multiple-region layouts, layout documents, third-monitor planning, native rollback, Remote Desktop, HDR/DPI diagnostics, workspace UX/profiles, taskbar and portable persistence checks passed. These include synthetic-window and C#-to-Lua bridge evidence, not new live WoW acceptance.
- Source interaction audit passed: 45 reviewed native declarations, restricted process-memory/input symbols absent. The new COM window-owner interface and reflection targets were separately reviewed against Microsoft documentation.
- Candidate-1 MSIX structural validation and exact embedded EXE parity passed. Candidate 1 was subsequently superseded by lifecycle cleanup and fixture refinements. Final candidate artifacts and scan receipts are recorded after the source commit under dist/companion-2.1.5-candidate-2.

The existing test's future minimum-version fixture moved to 2.1.6-beta.1 so it remains future-incompatible with 2.1.5. Historical 2.1.4 builder/receipts are preserved; the new builder is scripts/New-CompanionStoreUpdateCandidate.ps1.

## Remaining release acceptance

A real Store-associated 2.1.5 build/flight must exercise available/no-update, offline/unavailable services, cached answers and propagation delays before release. A local metadata/owner binding, fake provider or arbitrary sideloaded package does not prove correct Store catalog association or availability. The currently submitted 2.1.4 package is not used as an injection target or replaced for this test. Windows 10/Wine runtime acceptance, fresh WACK and exact-build Defender release assessment remain separate gates. No Defender or anti-cheat guarantee is claimed.

If Store acceptance fails, the existing manual Store button remains functional, and failure of the automatic check does not affect window management. Rollback uses the preserved submitted 2.1.4 artifact and existing layout preferences; only the isolated update cache is new.

## Preserved submission

Rechecked the original candidate-2 files from the Companion dashboard checkout:

- Submitted 2.1.4.2 EXE SHA-256: 2D1FB0DE3A2BF6340D8EB4BF28D751C602C8DF66BD1947D0B43FB0A8DA709D5D.
- Submitted 2.1.400.0 MSIX SHA-256: EDE193AA3AF4ADC90264A950CB8B8BB282D24A1BD4E0C4F6A9CA452BE5AB14EA.

## Primary references

- [Store availability query and requirements](https://learn.microsoft.com/en-us/uwp/api/windows.services.store.storecontext.getappandoptionalstorepackageupdatesasync).
- [Desktop Bridge window-owner setup, earlier .NET](https://learn.microsoft.com/en-us/windows/uwp/monetize/in-app-purchases-and-trials#using-the-storecontext-class-with-the-desktop-bridge).
- [Framework async adapter](https://learn.microsoft.com/en-us/dotnet/api/system.windowsruntimesystemextensions.astask).
- [Store-managed package updates](https://learn.microsoft.com/en-us/windows/msix/store-developer-package-update).

## Final local candidate

Source commit `7bc07a6` built cleanly as candidate 2. Local package parity and identity checks passed for the fresh MSIX. A Defender custom scan of the complete candidate directory exited 0 and reported no threats. This is an exact local scan result, not a Microsoft Defender submission verdict or future detection guarantee. Source/hash and pending acceptance states are in `docs/evidence/companion-215-store-update-validation.json`.

- EXE SHA-256: 95811DBB7020A20E2541AE123E69FE80721C83A0FD52D0EE5557DD6D54DCCC2A.
- MSIX SHA-256: 9AD0A4F561C27A750885E8030B5E72DFC4FBD80DF8CD507FEB26FB1D335B71CA.

Before release, Store-associated acceptance must also confirm quiet behavior with a signed-out/unavailable Store and cached answers. No availability request, installation, catalog flight or publication was performed in this implementation task. The submitted 2.1.4 hashes were verified unchanged again after the final build.

## Owner local test package

Prepared `dist/companion-2.1.5-local-test-1-final/Offhand-Companion-2.1.5-Local-Test-1.zip` with the unchanged 2.1.5.1 EXE, a separate local simulation host, license, README, manifest and checksums. No unsigned MSIX or installation script is included. The host verifies the exact production EXE hash, substitutes only the Store response delegate and uses isolated LocalTestData per scenario. It pauses background game monitoring and disables game/configuration actions in its own dashboard. The ordinary portable Offhand.exe remains available for separate normal testing with the usual user preferences.

The selector exposes available, no-update, unavailable and timeout responses, plus a test-cache reset checkbox. These are explicitly simulated responses, not actual Microsoft Store detection. Native visual QA observed the delayed Available state change without a new popup, correct disabled controls and successful Exit. The completed host/ZIP directory received a local Defender scan with exit 0 and no threats. ZIP entry/parity checks passed; local runtime test data is outside the archive. The original 2.1.4 submission hashes were verified unchanged.

Archive SHA-256: `67291DEE6FC3AECC7508BB604CBF4C3C238BE3DF4C94AF241F2243138656DC48`.
Receipt: `docs/evidence/companion-215-local-test-package.json`. This package is local and unpublished. Real Store association, catalog response and release certification gates above remain pending.
