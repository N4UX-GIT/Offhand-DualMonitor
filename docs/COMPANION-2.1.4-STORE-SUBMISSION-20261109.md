# Companion 2.1.4 Store submission, 9 November 2026

## Submitted artifact

- Partner Center product: `9PL4PW84Q90W`.
- Submission 5: `1152921505702348478`.
- Product version 2.1.4, production file build 2.1.4.2, Store package 2.1.400.0.
- Runtime source commit: `eeea3413f5739c8d7cddb5a003af05d818f876de`.
- Uploaded the existing candidate-2 MSIX without rebuilding it.
- MSIX SHA-256: `EDE193AA3AF4ADC90264A950CB8B8BB282D24A1BD4E0C4F6A9CA452BE5AB14EA`.
- EXE SHA-256: `2D1FB0DE3A2BF6340D8EB4BF28D751C602C8DF66BD1947D0B43FB0A8DA709D5D`.

## Partner Center evidence

The package was validated and the English release notes updated for the dashboard changes. Existing publisher identity, capabilities, availability and pricing were retained. The existing certification notes were replaced with version-specific test steps, exact hashes, WACK evidence and explicit test limitations. Notes were saved and verified after reload.

After Submit for certification, Partner Center showed **Product update: In certification (Submission 5)**, Submission complete and Pre-processing in progress. It explicitly states **Your product will start publishing as soon as it passes certification**. This is submission acceptance, not certification completion or public availability. The previously published Submission 4 remains available during review.

Local proof: `dist/companion-214-submission/store-submitted.png`. Candidate paths and validation are documented in `COMPANION-2.1.4-PREPARATION-20261109.md` and `docs/evidence/companion-214-ui-build2-*.json`.

## Website changes

Website work is isolated on `codex/website-companion-214`, based on current `origin/main` rather than the older Companion branch. It updates the homepage and Companion guide, including a capture of the actual production UI with isolated example preferences. The capture host disabled monitoring before its message loop and did not span or interact with WoW. It was closed after capture. The image is a layout illustration, not Store installation or game acceptance evidence.

The guide explains top-level Span/Restore, the collapsed System Status indicator and Show control, saved/default panel choices, the tray Pause/Resume background monitoring menu, and /reload after geometry changes. Existing sequential setup guidance and portable/add-on download links are preserved. It labels the 2.1.4 interface as a preview while certification is pending.

Validation: website integrity passed (7 pages / 341 references); all four Background Studio suites passed, including 96 website-to-Lua region comparisons. Desktop guide and homepage visual review passed. At a 390px viewport, both pages reported 375px document width (no horizontal overflow), and the new image loaded at its expected natural size of 550 x 704. Responsive screenshot capture was unreliable, so this is a DOM layout check rather than a mobile visual acceptance claim.

Website source commit: `36138d4bed1957522e017944cc298dcc74d0c6a6`. PR: https://github.com/N4UX-GIT/Offhand-DualMonitor/pull/98 . Deployment outcome is recorded below after verification.

## Scope retained

No GitHub release/tag/assets or add-on package was published. Pending add-on source and QA work in the Companion checkout was not staged, reverted or included in the Store binary. The existing Pre-Release Beta 27 add-on remains protocol-compatible; the Store package contains only Companion. No new production-PFN upgrade, live game, physical mixed-DPI, Windows 10 or Wine acceptance is claimed by this submission task.

## Website deployment verified

All GitHub PR checks passed: test, Analyze Companion (C#), and CodeQL. PR 98 was squash-merged as `f8baa76febfb1d7ea1a6d353b6ef6ee68176917e`. Render deployment `7644691884` reported success at 2026-11-09 01:15:43 UTC for environment `main - offhand-wow`.

The live `https://offhand-wow.onrender.com/companion.html` was reloaded and verified to contain the new controls guidance and the `offhand-companion-dashboard-20261109.jpg` image, loaded at 550 x 704. The live homepage references the same new image. Proof: `dist/companion-214-submission/website-live.png`. GitHub release assets and tags were not changed. Store Submission 5 was still in certification at the final observed check, with automatic publication after approval.
