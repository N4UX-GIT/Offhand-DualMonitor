# Companion post-update notice

The reporter confirmed that rerunning in-game window setup/calibration resolved the blurry-image problem. They attributed it to a lower-resolution image being stretched across a native 2560x1440 screen. That attribution remains reporter evidence; no before/after render-buffer measurements or diagnostics were supplied. Recalibration resolving this report does not establish a new native rendering-code regression in Companion 2.1.6. No renderer, scale CVar or addon code was changed in response.

The owner requested a post-update explanation and a reminder to recalibrate if issues occur. Implemented in next-version 2.1.7, file build 2.1.7.2, as an owned dark Companion dialog using the existing formatted Help controls, logo and scaled footer. It explains six-hour Store checks, last-check timestamps, unchanged Store installation/manual portable checking and preservation of saved setup. Recovery guidance is conditional: review displays/Mainhand/layout, Span WoW Now, /reload, then /offhand guide > Companion and the placement/calibration/HUD prompts if the game looks wrong. Working layouts need no reset. No action in this notice recalibrates, changes graphics settings, loads a plan, spans WoW or types game commands.

## Version and introduction policy

CompanionLastSeenVersion stores the acknowledged clean product version, separately from the tutorial-seen flag and Store query cache. Existing users with an older marker see the notice once per new version. Legacy 2.1.6 users have a tutorial flag but no marker; they see this migration notice once. Same-version restarts do not repeat it. A newer marker survives rollback and prevents downgrade notices. Invalid markers can recover. The notice records acknowledgement only after dismissal; a failure to show it does not silently mark it seen.

Fresh installs, and older users seeing the tutorial for the first time, receive only that introduction. Their current-version baseline is recorded when the tutorial is started. They can still read update notes from Help > What's new. Help also retains Start Companion tutorial. Got it, Escape or normal close dismiss the update notice; Setup help opens the existing guidance after acknowledgement. Modal ownership and the existing polling suspension keep it part of the Companion interface.

## Evidence and scope

New x64/x86 native fixtures exercise actual shown upgrade/dismissal/relaunch, legacy migration and first-run/tutorial routing with isolated preferences, as well as semantic version/rollback/malformed-marker policy. Both passed 63 assertions. The existing 100%-200% and enlarged-control Help/layout/tutorial matrix passes with update-note content, pinned controls, footer fit and Help replay checks. Existing Store-update production/preview x64/x86 fixtures passed 776 assertions; the native interaction boundary retained 45 declarations and rejected eight prohibited mutations.

The native offscreen RichTextBox bitmap is not used as visual evidence because that control does not paint its body through the existing bitmap fixture. Full live visual acceptance remains for the owner reviewing the local build. No external keyboard/mouse automation is required for the review launcher, which supports --available and starts with a legacy-user fixture so the notice opens automatically. The launcher records whether the notice is open in its own diagnostic receipt.

Shared KB README/skill/status and existing tutorial, update-cache and blur findings were consulted. The search index was stale while other shared-project changes were occurring; it was rebuilt, and current source plus the authored findings were read directly. Current addon guide command/Companion placement prompts were checked in Core/Init.lua and UI/Onboarding.lua. No new WoW API or live game/calibration run is claimed. Exact build/package/preservation results are recorded after preparation below. Existing 2.1.6 and published artifacts remain frozen; no Store/GitHub/addon/website publication is authorized by this local UI change.

## Local Test 3

Built from clean source `2d31d18e4a09b8fccb4bbc106f9f7f36063706a1` into `dist/companion-2.1.7-candidate-2`, then prepared `dist/Offhand-Companion-2.1.7-Local-Test-3.zip`. ZIP SHA-256: `066D4D9914DF8D8645BCCA8FF89BC45C42A911AC04C06A88D4220B88B0F4E3A0`. It supersedes the earlier local test ZIPs, contains the exact runtime and review host, and excludes seeded preferences/cache/results.

The launcher is open with the What's new dialog for owner review. Its self-diagnostic confirms UpdateNoticeOpen=True and the simulated Available result. Read-only Computer Use observed the complete owned dialog, including formatted headings/body, optional recovery steps, logo and pinned Setup help/Got it footer. The complete second screenshot region, rather than the cropped parent capture, was used for visual inspection. No keyboard or mouse input was injected. Real Store availability was not queried by the simulation.

Fresh directory/ZIP Defender scans found no threats. Store-identity persistence passed 47 checks. Real preference/update-cache hashes and exact 2.1.6 artifacts remain unchanged. [Machine-readable receipt](evidence/companion-217-update-notice-20261110.json) records the exact payload and verification. Store-associated update/upgrade acceptance, WACK and publication of 2.1.7 remain later work.

## Layout reminder and 2.1.7.3 preflight, 11 November 2026

Forever 1.60.1.70888 with addon 2.1.5 Beta 28 retained the centered Flexible layout after Standard was saved and spanned at the same 2560 × 1440 window size. The Companion showed the save and reload reminders. With one Companion running, `/reload` replaced the two Flexible workspaces with a single left workspace and the game on the right.

A concurrently running 2.1.6 QA instance had rewritten the topology file on the first attempt. The 2.1.7.3 release candidate and UI Preview 4 hold the release and legacy preview Windows mutexes before opening the dashboard. This excludes both older startup paths in the same Windows session. An exact UI Preview 4 launch against the running 2.1.6 QA executable displayed the duplicate-instance prompt, exited, and left the topology file byte-identical. The preference fixture also verifies both legacy lock paths, release after a blocked launch, and acquisition after the prior holder releases its lock.

- Production EXE SHA-256 `8CA3EFDBE428B8C729A7E35A3455BD01AB97C6F76220CB9FDD0B9F8FAD0D80B0`.
- Store MSIX 2.1.700.0 SHA-256 `DC0331B32A031249FDBF851A7F2FBA22856DDE901B1E09F00C9A4579A1974ED3`. The embedded EXE matches the portable candidate.
- WACK passed all 13 required checks on Windows 11. The optional blocked-executables finding matches the 2.1.6 report. The no-install report is under `dist/companion-2.1.7-store-preflight/retry/wack-report.xml`.
- The private 2.1.6 to 2.1.7 MSIX upgrade passed baseline, first launch and relaunch probes with 41, 44 and 44 checks. It preserved the settings, displayed What's new once and removed the private package afterward. The preflight verified the installed Store app and existing preference hashes.
- The exact candidate queried the real Store API under the installed 2.1.6 package identity. The service returned NoUpdate and the footer showed the local last-check time. Relaunch within six hours made zero requests and preserved the cache. The Store-delivered available-update path still requires a newer build offered by the Store.
- Defender report-only scans found no threats in the portable candidate directory or exact production MSIX. Companion layout at 100–200% scaling, display identity, topology, span/restore rollback, interaction boundaries, Store scheduling, notices and preference fixtures passed.
