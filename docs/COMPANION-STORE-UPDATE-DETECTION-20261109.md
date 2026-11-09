# Quiet Store update detection, 9 November 2026

## Scope and source

Branch: `codex/companion-store-update`, based on the reviewed Companion dashboard/source records through `8c6e089`. Product 2.1.5, production file 2.1.5.1, Store package 2.1.500.0. No add-on, public executable or GitHub release asset is changed by this work. A separate owner-only Store flight was submitted after local validation; the public 2.1.4 submission remains unchanged. The website deployment remains independent.

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

A Store-delivered 2.1.5 flight must exercise available/no-update, offline/unavailable services, cached answers and propagation delays before public release. A local metadata/owner binding, fake provider or arbitrary sideloaded package does not prove correct Store catalog association or availability. The identity-bound diagnostic host described below is useful partial integration evidence; it does not replace acceptance of the Store-delivered flight. The installed 2.1.4 files were not replaced or modified. Windows 10/Wine runtime acceptance remains a separate gate. Fresh WACK and a local exact-build Defender scan passed as recorded below. No Defender or anti-cheat guarantee is claimed.

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

Before public release, Store-associated acceptance must also confirm quiet behavior with a signed-out/unavailable Store. The implementation-stage fixtures made no availability request; the subsequent real query and private flight are recorded below. The submitted 2.1.4 hashes were verified unchanged again after the final build and Store tests.

## Owner local test package

Prepared `dist/companion-2.1.5-local-test-1-final/Offhand-Companion-2.1.5-Local-Test-1.zip` with the unchanged 2.1.5.1 EXE, a separate local simulation host, license, README, manifest and checksums. No unsigned MSIX or installation script is included. The host verifies the exact production EXE hash, substitutes only the Store response delegate and uses isolated LocalTestData per scenario. It pauses background game monitoring and disables game/configuration actions in its own dashboard. The ordinary portable Offhand.exe remains available for separate normal testing with the usual user preferences.

The selector exposes available, no-update, unavailable and timeout responses, plus a test-cache reset checkbox. These are explicitly simulated responses, not actual Microsoft Store detection. Native visual QA observed the delayed Available state change without a new popup, correct disabled controls and successful Exit. The completed host/ZIP directory received a local Defender scan with exit 0 and no threats. ZIP entry/parity checks passed; local runtime test data is outside the archive. The original 2.1.4 submission hashes were verified unchanged.

Archive SHA-256: `67291DEE6FC3AECC7508BB604CBF4C3C238BE3DF4C94AF241F2243138656DC48`.
Receipt: `docs/evidence/companion-215-local-test-package.json`. This simulation package is local and unpublished. Subsequent real Store evidence follows; full flight acceptance remains pending.

## Real Store integration and private flight

On 9 November, Microsoft's supported `Invoke-CommandInDesktopPackage` command launched the separate `tests/CompanionStoreAssociatedProbe.cs` test host with the installed Store 2.1.400.0 identity. The host loads the exact unchanged 2.1.5.1 EXE, redirects configuration and update cache to a test directory, stops game monitoring, and disables game/configuration actions. Its observational wrapper calls the real production Store API; it does not substitute a Store response. Production scheduling, cache and button handling run normally.

- The first launch made one real request after the production 30-second delay. It returned `NoUpdate` in 1,395 ms without error, displaying `Store Updates` with the correct accessible description.
- A second launch used the persisted result and made zero API calls. The attempt timestamp remained unchanged.
- The separate Store-identity persistence suite passed 47 checks, including migration, repeated writes, locks, interruption and error-87 fallback.
- Installed package identity, installed EXE, three preference locations, submitted 2.1.4 EXE/MSIX and candidate 2.1.5 EXE/MSIX remained unchanged at the final preservation check, 02:32 UTC.

This is identity-bound diagnostic-process evidence, not a Store installation/upgrade of 2.1.5. The diagnostic token differs from normal app activation. `NoUpdate` was consistent with the installed public 2.1.4 package; an actual `Available` response has not yet been observed. Respect the documented 30-minute service cache and ten-per-day detection limit when testing flight propagation. Do not reset the user's daily cache or change their Store sign-in/network settings to manufacture a result.

Fresh WACK on the exact candidate MSIX completed with exit 0, overall PASS, no partial run, 13 required passes and zero required failures. Optional checks had ten passes and one existing blocked-executables finding. Review traced `CsI` to the unchanged embedded logo PNG (9,408 bytes, SHA-256 `5A07E4979187D0DEEC6F098EB8EBE1A0E47ABFA622C753F6CAE3882BEB3DEAC8`), shared with submitted 2.1.4 and the source icon. Existing `Process.Start` calls open the official Store, manual GitHub page, documented external links or Windows display settings. No new native imports were added. WACK ran with `-noinstallappx`; the installed Store package and preferences were preserved. A fresh Defender custom scan exited 0 and found no threats; this is not a Microsoft submission verdict.

Partner Center accepted **Companion 2.1.5 internal QA**, submission `1152921505702349123`, for certification. It contains the exact validated 2.1.500.0 MSIX and is limited to the one-account **Companion internal QA** group. The account address is intentionally excluded from source and evidence. The flight publishes only to that group after certification. Additional Testing Information now includes private-flight instructions while retaining the existing 2.1.4 reviewer notes. Public Submission 5 remains live, with no new standard submission created. Private certification and Store propagation are pending; no public 2.1.5 release is claimed.

Receipts: `docs/evidence/companion-215-store-associated.json` and `docs/evidence/companion-215-wack.json`. Full local outputs are under `dist/companion-215-store-associated` and `dist/companion-215-wack`. The remaining flight acceptance covers Store delivery/upgrade, a real available response if observable before the upgrade, and quiet real-service failure behavior. Existing fixture coverage for failure/timeout is separate from those observations.

### Reproducing the identity-bound probe

Use the same signed-in Windows user that owns the installed Store package. This probe is deliberately pinned to the recorded candidate hash. Copy that EXE beside the compiled test host; do not replace the installed Store EXE. Build with the Framework64 C# compiler, references `System.dll`, `System.Core.dll`, `System.Drawing.dll`, `System.Windows.Forms.dll` and `System.Web.Extensions.dll`, and `/target:winexe /platform:x64`. Pass the absolute source path to the compiler. Start it with:

```powershell
Invoke-CommandInDesktopPackage -PackageFamilyName N4UX.OffhandCompanion_bwe0ea6astzt8 `
  -AppId OffhandCompanion -Command $absoluteProbeExe `
  -Args ('"' + $absoluteIsolatedOutputDirectory + '" online')
```

The host records `result.json` and closes after 50 seconds. Its output directory must be test-only; it contains the isolated cache and configuration. Preserve the first receipt before relaunching with the same output directory and mode `cached`; the second receipt must record zero queries and the unchanged cache timestamp. Do not repeatedly use fresh directories to bypass service limits. A newly certified flight may automatically update the owner's installed app, so refresh installed identity/version evidence before interpreting subsequent results.

Additional primary references:

- [Package-context diagnostic command](https://learn.microsoft.com/en-us/powershell/module/appx/invoke-commandindesktoppackage?view=windowsserver2025-ps).
- [Custom test harness under package identity](https://learn.microsoft.com/en-us/windows/msix/desktop/desktop-to-uwp-debug).
- [Private package flights and certification](https://learn.microsoft.com/en-us/windows/apps/publish/package-flights).

## Public submission authorized without waiting for flight

The publisher subsequently requested public Store submission/publication without waiting for the internal flight. Public Submission 6 (`1152921505702348834`) was accepted for certification with automatic publication after approval, using the unchanged exact candidate MSIX. This supersedes the earlier private-only release scope. It does not turn outstanding real-flight acceptance into a pass. See `docs/COMPANION-2.1.5-STORE-SUBMISSION-20261109.md` for the submitted artifact, listing/reviewer changes and accepted limitations. Public 2.1.5 availability has not yet been observed.
