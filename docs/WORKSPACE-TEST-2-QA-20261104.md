# Workspace Test 2 local QA

4 November 2026. Addon runtime staged from the working feature branch after
the library change. Companion reused the exact clean-source Beta 5 candidate
from 50317e6, SHA-256
574B54FA19ED341AC871E0F5840855F6316412C765828314228C22F264D3F186.
Program.cs and app.manifest remain unchanged since that native build.
The final package manifest identifies both source revisions and every file hash.

Retail 12.1.5.70783, previously authorized WoW1 EU and existing level-one
Noggetester in Coldridge Valley. No gameplay, account/realm changes, credential
input, or HUD-onboarding acceptance occurred. Both displays reported 100% scale.

| Check | Observed result |
| --- | --- |
| Before span | Bounds (0,215) 2560x961, style 14CF0000, clipping region 0 |
| Beta 5 manual custom span | Bounds (-1431,-6) 3991x1446, style 140B0000, clipping region 3 |
| Generated bridge and accepted metrics | Schema 2, spanned true, workspace-a 480x600, pixel origin (0,846), UI size 365.714x457.143 |
| Library discovery | AVAILABLE, two assets from code-free numbered metadata |
| First image | Warm 200x100 content in 256x128 texture, visibly contained in workspace |
| Second image | Cool 100x200 content in 128x256 texture, visibly contained with its separate aspect ratio |
| Reload | Cool image and named layout retained; confirmed from new capture and SavedVariables |
| Profile activation | Warm named layout restored qa-warm, visibly rendered again |
| Missing asset | qa-missing retained in region appearance; image hidden and theme restored |
| Error comparison | Sessions 352 to 355, 13 records before and after, complete records identical |
| Restore Window | Exact original bounds/style/clipping restored |
| Cleanup | WoW and Companion exited normally; media fixture removed from install; 18 states and 78 original addon files restored and hash verified. Battle.net left open |

Private native captures, original states and raw errors remain under ignored
dist/live-qa-workspace-features-retail-20261104-215459. They are not packaged.
Native screenshots include the full backing surface; the visible desktop is
clipped by the native window region. No claim is made from pixels outside it.

A deliberately invalid two-workspace plan using the same physical offhand
monitor was rejected before span. This confirms the distinct-display guard;
it does not constitute physical three-monitor acceptance. Simulated independent
canvases and three-display planner tests remain separate evidence.

Automated evidence: 90 Lua suites; six TOCs/path/XML and Lua 5.1 syntax;
background-studio.mjs; background-studio-library.mjs (including real producer
TOC passed to Lua); background-studio-regions.mjs (96 comparisons);
background-studio-workflow.mjs (offline CSP and DOM/canvas event simulation);
website-integrity.mjs. The native Beta 5 automated suite and isolated editor
acceptance at 100/125/150/200% are in COMPANION-UX-QUALITY-PASS-20261104.md.

Pending boundaries: browser visual interaction, fresh Anniversary library test,
library cold relaunch, simultaneous physical two-workspace images, mixed DPI,
hotplug, combat/protected actions, remaining large panels/replacement bags,
screen-reader and high-contrast acceptance. They are disclosed for the opt-in
test build and remain official-release gates.
