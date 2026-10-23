# Geometry-input locking candidate, source checkpoint 92b07a7

- Source: `codex/addon-ui-overhaul`, draft PR #35. A seam geometry lock now covers the rail, separate input and steppers in Settings and Calibration. It cancels pending drag work before focus release, rejects late field commits/direct steps, and restores controls when manual geometry is available. No topology calculation or workspace-window locking code was changed.
- Automated: all 48 Lua suites passed. Added coverage for all slider child states, interrupted drag cancellation without applying a stale value, rejected disabled field/step callbacks, manual re-enable, numeric disabled states, and exact-topology settings refresh. Six manifests passed paths, XML, load order and Lua 5.1 syntax validation. Companion preference and release-metadata checks passed; the frozen executable hash is unchanged.
- Package: all 72 unpacked files matched source SHA-256 and unpacked validation passed. Audit ZIP SHA-256: `5D8369665EECFD3B6C96BEF4A09FB196EA8114BCF3D30101C114A10291B42E4C`. Retained Beta 22 metadata is for local audit, not a release.
- Deployment: Retail and Forever Beta each match 70 copied files, preserving their two generated bridges unchanged. Current package and recoverable pre-update installs: `D:\Games\World of Warcraft\_offhand_deploy_backups\ui-overhaul-92b07a7`. Earlier candidates remain available.
- Live: pending. No live visual, taint, persistence or workspace-lock pass is inferred. The [combined checklist](../docs/REFACTOR-SMOKE-TEST.md) distinguishes geometry-input locking from workspace window locking.

# Calibration layout candidate, source checkpoint f766a58

- Source: `codex/addon-ui-overhaul`, draft PR #35. Calibration measures introduction/progress, topology recommendations, final HUD guidance/status, validation and footer spacing. Failure messages reflow the active page; longer footer labels reserve height. Topology checks, four/five-step policy, completion/skip confirmation, layout creation and reload actions remain unchanged.
- Automated: all 48 Lua suites passed. New coverage checks page/card/validation/footer separation, expanded final readiness text and non-accumulating relayout. Existing setup, topology mismatch and layout-creation failure regressions still pass. Six manifests passed paths, XML, load order and Lua 5.1 syntax validation. Companion preference and release-metadata checks passed; the frozen executable hash is unchanged.
- Package: all 72 unpacked files matched source SHA-256 and unpacked validation passed. Audit ZIP SHA-256: `E08F6727622BCE4A4A980B44F7933CF8EE42DC65EDF01FCE1F116032EECFFE68`. Retained Beta 22 metadata is for local audit, not a release.
- Deployment: Retail and Forever Beta each match 70 copied files; both generated bridges remain unchanged. Current package and recoverable pre-update installs: `D:\Games\World of Warcraft\_offhand_deploy_backups\ui-overhaul-f766a58`. Earlier candidates remain available.
- Live: pending. No in-game text rendering or protected-action pass is claimed. The [combined checklist](../docs/REFACTOR-SMOKE-TEST.md) includes read-only calibration inspection without completing or replacing a layout just to check appearance.

# Setup-guide spacing candidate, source checkpoint 70e2d4f

- Source: `codex/addon-ui-overhaul`, draft PR #35. Window Setup measures its title/body/status and action text, reserves non-overlapping body/action/status/footer regions, reflows status updates, and recenters a single action after the three-choice page. No setup actions, confirmations, saved-variable schema or release metadata were changed.
- Automated: all 48 Lua suites passed. Coverage includes guide-region arithmetic, all six page layouts, expanded status text, method download/reload/resume paths, and multilingual fallback calculations. All six manifests passed paths, load order, XML and Lua 5.1 syntax validation. Companion preference and release-metadata checks passed; the frozen executable hash is unchanged.
- Package: all 72 unpacked files matched source SHA-256 and unpacked validation passed. Audit ZIP SHA-256: `9923632DF6B8C7D053F2E31A603E0405D452740C8F7FAA14A0F094BAAE573ABA`. Retained Beta 22 metadata is not a new release.
- Deployment: Retail and Forever Beta each match 70 copied files, preserving their two generated bridges unchanged. Current package and recoverable pre-update installs: `D:\Games\World of Warcraft\_offhand_deploy_backups\ui-overhaul-70e2d4f`. Earlier candidates remain available.
- Live: pending. No in-game appearance, protected-action or lifecycle pass is inferred from these mocks. The [combined checklist](../docs/REFACTOR-SMOKE-TEST.md) includes guide-region inspection without resetting setup.

# Translated text layout candidate, source checkpoint 9db21e3

- Source: `codex/addon-ui-overhaul`, draft PR #35. Theme choices use bounded columns and measured row heights; wrapped Help headings reserve body space. Shared text measurement prefers client metrics and falls back conservatively when unavailable. No setting actions, storage, native frame ownership, Companion binary or release metadata changed.
- Automated: all 48 Lua suites passed. Presentation tests cover measured title/description expansion, row boundaries, repeat layout and fallback geometry using all eleven locale dictionaries. All six manifests passed paths, XML, load order and Lua 5.1 syntax validation. Companion preference and release-metadata checks passed; the frozen executable remains unchanged.
- Package: all 72 unpacked files matched source SHA-256 and the unpacked addon passed validation. Audit ZIP SHA-256: `53ADF94AC9ACCE3E16FB727E36A60797E89C35D026D3D3DDA5971DAE49D24E0B`. Existing Beta 22 metadata is retained only for local audit.
- Deployment: Retail and Forever Beta each match 70 copied package files, with both generated bridges unchanged. Current package and recoverable pre-update installs are under `D:\Games\World of Warcraft\_offhand_deploy_backups\ui-overhaul-9db21e3`. Earlier candidates remain available.
- Live: pending. Locale arithmetic tests are not visual rendering evidence. The [combined checklist](../docs/REFACTOR-SMOKE-TEST.md) now includes Themes and Help text boundaries.

# Profile and choice usability candidate, source checkpoint 025b6dc

- Source: `codex/addon-ui-overhaul`, draft PR #35. Shared profile-row styling, separate name/active labels, full-name tooltips, Enter/Escape name entry, automatic reveal of new profiles, stale-selection cleanup and scroll clamping. Radio labels are clickable; disabled radio/checkbox label clicks cannot bypass the parent state. Existing profile storage and destructive-action confirmations are unchanged.
- Automated: all 48 Lua suites passed, including expanded profile and choice-label regressions. Six manifests passed paths, load order, XML and Lua 5.1 syntax validation. The profile-only controls are block-scoped to respect Lua 5.1's local-variable limit. Companion preference and release-metadata checks passed; the frozen executable SHA-256 is unchanged.
- Package: all 72 unpacked files matched source SHA-256 and the unpacked addon passed validation. Audit ZIP SHA-256: `134D114D0987789EB473F7E55E300E1A67BF7740CDA6E24E7DF902F033A3221F`. Retained Beta 22 metadata is not a new release.
- Deployment: Retail and Forever Beta each match 70 copied files. Two generated bridge files per install remain unchanged. Current package and pre-update backups: `D:\Games\World of Warcraft\_offhand_deploy_backups\ui-overhaul-025b6dc`. Earlier candidates remain recoverable.
- Live: pending, with no new game session or assumed pass. The [combined checklist](../docs/REFACTOR-SMOKE-TEST.md) includes label clicks and an optional disposable-profile check.

# UI interaction hardening candidate, source checkpoint ad036fe

- Source: `codex/addon-ui-overhaul`, draft PR #35 stacked on structural PR #34. Adds interrupted-drag cleanup, final Wizard scale-release commit, semantic button/focus colors, a legacy selection-marker fallback, and event-driven visible-dialog fitting.
- Automated: all 48 Lua suites passed with expanded lifecycle and presentation coverage. Six manifests passed paths, XML, load order and Lua 5.1 syntax validation. Companion preference and release-metadata checks passed; the frozen executable SHA-256 is unchanged.
- Package: all 72 unpacked files match source SHA-256 and the unpacked addon passed validation. Current audit ZIP SHA-256: `E8769D8786C99FB977F376D88A00B9C2BFFCC2221E1BD8969E85B090A49F3D4D`. Retained Beta 22 metadata is for local audit only, not a release.
- Deployment: Retail and Forever Beta each match 70 copied files; their two generated bridge files are unchanged. Current package, verification copy and pre-update installs: `D:\Games\World of Warcraft\_offhand_deploy_backups\ui-overhaul-ad036fe`. Earlier structural-only and initial visual backups were retained.
- Live: still pending. No visual, lifecycle, taint, or combat result was inferred from mocks or the user's instruction to continue. Use the updated [combined checklist](../docs/REFACTOR-SMOKE-TEST.md).

# Initial visual overhaul candidate, source checkpoint e480af9

- Source: `codex/addon-ui-overhaul`, based on the completed structural branch at `b7508d5`. Visual implementation is a separate commit; structural PR #34 is unchanged.
- Automated: all 48 Lua suites passed. Six manifests passed paths, load order, XML, and Lua 5.1 syntax validation. Companion preference and release-metadata checks passed; the frozen executable is unchanged.
- Package: all 72 unpacked files matched source SHA-256 and the unpacked addon passed validation. Audit ZIP SHA-256: `9921173BF779715E07B26B1167ACBA9340A1FE831AF2E2EF81A080899C7D27F6`. Retained Beta 22 metadata does not make this a release.
- Deployment: Retail and Forever Beta each match 70 copied package files. Two generated bridge files per install were preserved unchanged. Pre-update installs and the package are recoverable under `D:\Games\World of Warcraft\_offhand_deploy_backups\ui-overhaul-e480af9`.
- Live: pending. No new game session, visual pass, protected-action pass, or persistence pass was performed. The user is away from the home computer.
- Handoff: [combined test checklist](../docs/REFACTOR-SMOKE-TEST.md) and [visual scope/evidence](../docs/UI-OVERHAUL-2026-10-23.md). Existing structural observations below remain historical.

# Final structural candidate, source checkpoint 8335480

- Source implementation: complete through increment 33 of the planned structural pass. PR #34 remains a draft into `addon/develop`.
- Automated: all 47 Lua suites passed. All six manifests passed load order, paths, XML, and Lua 5.1 syntax validation with 61 runtime files (60 Lua, one XML). Companion preference and release-metadata checks passed; the frozen executable hash is unchanged.
- Package: an isolated addon-only build passed. All 72 unpacked package files matched source by SHA-256, and the unpacked addon passed validation. The local audit archive has SHA-256 `9B6F6FD03F66857EF69F38AC932F12B17CACE81FCB05B8B59FB0808CA10F7A01`. Existing Beta 22 metadata was retained; this was not a release.
- Live: no new observed live result has been recorded for the final candidate. The user will test manually. Their instruction to assume success enabled continued source work only.
- Instructions: [final smoke checklist](../docs/REFACTOR-SMOKE-TEST.md). The earlier client observations below remain historical evidence for their original checkpoint.

# Historical addon architecture refactor smoke ledger, 2026-10-23

- Candidate: `codex/addon-architecture-refactor` at `10453d0941213916f1d7b060b64fc3eeb705bcc2`, draft PR #34 into `addon/develop`.
- Static and simulated result: PASS. All 42 Lua suites passed. All six manifests passed path, XML, and Lua 5.1 syntax validation with 43 runtime files. Companion preference and release-metadata tests passed without changing the frozen Companion.
- Deployment result: PASS. Retail and Forever installs match 52 packaged source files by SHA-256. Client-generated topology and Forever-state bridges were preserved. Recoverable pre-deployment copies are under `D:\Games\World of Warcraft\_offhand_deploy_backups\20261023-080833-*`.
- Forever 1.60.1 build 70532: PARTIAL. The candidate loaded, `/reload` completed without a client crash, settings rendered, and Map, bags, and Character opened. Character scale commands executed and the saved value was restored to `1.00`. The client ran in safe single-screen recovery because its window did not match the generated span, so workspace placement and visual scale change were not accepted as verified. The fresh BugGrabber record at 08:15:25 was a Blizzard `TextStatusBar.lua:110` secret-number error attributed to `*** ForceTaint_Strong ***`, not Offhand. Historical BugGrabber records were excluded from this run.
- Retail 12.1.5 build 70529: BLOCKED BEFORE ADDON LOAD. Battle.net reported `This folder doesn't contain the correct version of this game` and error `BLZBNTAGT00000AF0`. Direct `Wow.exe` launch remained unauthenticated. No credential or security input was attempted. Retail lock, close-reopen consistency, Character scaling, and lock-enabled `/reload` remain pending.
- Evidence: screenshots and Companion log moved outside the repository to `D:\Games\World of Warcraft\_offhand_deploy_backups\20261023-refactor-smoke-evidence`.
- Cleanup: both test clients closed. The frozen Companion started for the Retail attempt was stopped. Battle.net was left open. Source working tree was clean before this ledger update.
- Harness follow-up: the live runner now recognizes `Wow.exe`, `WowClassic.exe`, and Forever `WowB.exe`, and it no longer falls back to a WoW process outside the requested client root.

# Forever v2.1.2 release-candidate ledger -- 2026-09-23

This section is the authoritative current ledger. Earlier dated sections are
retained as engineering history; an older `pending`, failed smoke result, or
remaining-work list is superseded where this ledger records a later pass.

The Beta 21 release candidate adds topology-aware user controls for the Forever world-text split.
Equal-height spans retain native combat/XP text and native speech bubbles.
Affected mixed-height spans retain the confirmed combat-text correction and use
an addon-owned, classic-styled speech-bubble visual centred on Blizzard's
untouched world carrier. The native child is hidden only after the replacement
is ready and is restored whenever Offhand relinquishes ownership. EllesmereUI
customization takes precedence. Both paths have independent enable switches and
50–150% fine tuning; automated coverage passes, while the replacement requires
live visual and lifecycle retesting.

On 2026-10-20, a follow-up live report was traced to a stale Forever install:
the running `_classic_beta_` addon files were dated 2026-10-19 and did not
contain the current Professions migration, replacement-bag ownership guard,
alternate Social-root support, Social/Communities reflow repair, or Auction
House transaction guard. Thirty-two runtime files were backed up and deployed
with matching source hashes. Companion-generated `CompanionTopology.lua` and
`ForeverState.lua` were preserved. Source and installed-addon validation both
pass; the running client still requires `/reload` before this deployment can
produce live evidence.

## 2026-10-22: Forever Beta 21 false topology mismatch (OH-FOR-014)

- Source branch: `addon/forever/topology-canvas-match`; intended release: next addon beta after Beta 21. Discord candidate `Offhand-v2.1.2-beta.21-discord.topology-test1.zip` packaged on 2026-10-22; no public release. SHA-256 `D5B62B0F00B917E7474903ED6566F0200421641F11D36F86C6ABA0946D3878B1`. All 48 archive files verified against staging and all runtime assets against source; extracted six-manifest validation passed. Test identity is `2.1.2-beta.21-discord.topology-test1`. Existing Store Companion Beta 20 is retained; source and frozen Companion bytes are unchanged by packaging. Issue ID corrected to OH-FOR-014 because OH-FOR-013 already identifies OpenMap ownership.
- Reporter: Forever 1.60.1 build 70450, Interface 16001, Offhand 2.1.2-beta.21, Windows Store Companion (writer version not recorded).
- Later screenshots identify Companion Beta 20 and show portrait Display 2 (`1080x1816`) selected as Mainhand, with landscape primary Display 1 (`2560x1440`) as workspace. The physical report matches workspace, not Mainhand. Windows shows portrait-left/landscape-right alignment with a vertical offset; exact offset pixels are unknown. Regression covers these reversed roles with several representative offsets.
- Observed: Companion bounds `3640x1816`, physical API `2560x1440`, UI canvas `2287x1141`. The canvas aspect matches the span, but Forever was explicitly excluded from the existing one-monitor physical-report fallback, forcing recovery and blocking the wizard.
- Implemented: apply the existing two-signal check to Forever too. Both a selected display's dimensions and the complete span's canvas aspect must match. Retain rectangle validation and single-screen recovery on disagreement.
- Audit follow-up: exact physical bounds also require agreement with the UI canvas; stale selected-display reports cannot authorize arrangements whose full aspect is indistinguishable from that display. Wizard sizes and workspace percentages now use accepted Companion bounds, including stacked layouts.
- Reporter live acceptance, 2026-10-22: Discord topology-test1 resolves the span issue. Restore, cold-launch, exact post-fix diagnostics and detailed geometry remain separate pending checks. The reporter subsequently describes main-display pixelation and identifies ASUS GlideX as the tablet-display provider. No image of the rendered game or render-setting evidence accompanies this report. Establish physical-monitor versus tablet output, current Mainhand selection, 3D-only versus UI degradation, and the same stationary scene restored versus spanned before attributing it to streaming or the existing renderer-resize hypothesis. The addon-only candidate did not update Store Companion Beta 20.
- Pixelation follow-up: physical Mainhand is affected in both UI and 3D; tablet remains sharp; Restore Window restores Mainhand sharpness. Default diagnostics show viewport PASS and exact Mainhand `(1080,0 2560x1440)`, workspace `(0,8 1080x1816)`, span `3640x1824`, screen `2773x1389`, effective scale `0.553`, Companion writer Beta 20 and matching/current generated Edit Mode layout. This verifies the landscape is now Mainhand, superseding the earlier portrait selection. It does not verify native render-buffer dimensions. Compare Windows scaling percentages, a cold launch with both displays temporarily at the same scaling, and span before login versus span after login. Collect renderer CVars separately because neither default nor full support diagnostics currently outputs GetPerformanceDiagnostics. Frozen Beta 20 lacks the experimental resize handshake in current Companion source; no candidate Companion was built or deployed in response to this report.
- Automated validated: all 38 Lua suites passed, including the reported dimensions, preservation of raw diagnostic dimensions, stale reports from either display, pixel tolerance, stacked offsets, one-display splits, malformed data, ambiguous aspects, and rejection after single-monitor restore. Wizard regressions verify side-by-side and stacked workspace percentages. All six manifests passed paths, XML references and Lua 5.1 syntax validation; Companion preference/layout/topology checks passed.
- Live pending: with the affected display pair, span and reload; confirm topology `READY`, wizard progression and correct Mainhand/workspace bounds. Restore Window and confirm recovery; span again and repeat reload and cold launch. Recheck the saved Edit Mode layout after topology recovery. No live-client, protected-action or packaged-build acceptance is claimed.

- Subsequent Windows screenshots: both displays use 100% scale and recommended resolutions (`1080x1816` portrait flipped, `2560x1440` landscape). Mixed Windows scale percentages are not evidenced. A cold-launch/pre-login span versus a span after UI initialization remains a useful comparison for the unverified render-resize hypothesis; application/driver scaling remains possible. No new executable or addon candidate was generated for this evidence-only update.
- Pre-login test returned: login is sharp but entering the world makes Mainhand grainy. Connection is GlideX over Wi-Fi. This rejects pre-login spanning as a workaround, without establishing whether the trigger is the client's gameplay transition or Offhand's layout application. Next test keeps the window spanned and disables only Offhand via the addon list plus reload, comparing the same scene; re-enable/reload after recording. The unbounded world covering both displays is expected while the addon is disabled. Follow with a cold launch in the disabled condition if needed. No new runtime change or package was produced from this report alone.

- Further reporter isolation: USB has the same result as Wi-Fi; disabling/re-enabling Offhand does not affect sharpness; a full restart with Offhand disabled also returns no change. Latest Beta 20 Companion screenshot confirms landscape Display 1 as Mainhand, portrait Display 2 as workspace and `3640x1824` span. Auto-span and single-display split are off. Next compare a manually resized bordered window with Companion fully exited and the addon disabled against the Companion's borderless span; no candidate Companion or claimed renderer fix yet.

- Latest comparison: reporter says manual bordered spanning did not appear grainy. Companion border/style/region/resize handling is therefore the next investigation area; exact equivalence of the manual and Companion window bounds was not measured. The alternate landscape-tablet arrangement produced scrunching without fresh geometry evidence. FancyZones was not configured to a known test layout and the reporter abandoned the attempt; record no pass or fail. No further reporter data is available, so image quality remains open and any Companion experiment remains live-unverified. No additional runtime change or package was made for this status update.

- A separate Companion candidate is now prepared on `companion/graininess-test` from `companion/develop` `4ae9d386`: `Offhand-Companion-v2.1.2-beta.20-graininess.test1.zip`, SHA-256 `A22FE893456B87BE362334E5F941CFA6D0637219DC5E863E1247A1AC493701A4`. Four modes isolate the extra resize, clipping and border removal with equal measured client dimensions. Existing Companion regressions and synthetic hidden-window tests passed, and eight ZIP entries were byte-verified. Preferences are isolated and auto-span is disabled. The public binary and existing addon test package are untouched. Reporter should compare the same scene/configuration across modes, restoring and restarting between modes, then submit the mode logs. No mode is yet live accepted.

## Ordered execution plan

1. Preserve the accepted 4000x2560 Forever baseline and run the remaining
   combat/taint, post-combat, HUD-bar, transition, idle, relog and panel-reopen
   matrix one controlled live step at a time.
2. Exercise the complete Forever SavedVariables fallback live across `/reload`,
   relog and cold restart, then repeat on another character/account where
   practical.
3. Exercise Companion tray, display identification, pause, update, help and repeated hotplug
   recovery behavior.
4. Test addon coexistence and arbitrary movable windows, then test additional
   physical topologies as hardware permits.
5. Recheck version, changelog, release notes, website copy and package contents;
   prepare review and final artifacts without publishing or merging.
6. Only after Forever acceptance, reproduce Retail v2.0.0 reports and port the
   proven fixes across the supported client families.

## Release-candidate matrix

| Area | Status | Evidence / remaining work |
| --- | --- | --- |
| Forever Auction House disappears after an Offhand move and close | FIXED IN CURRENT SOURCE (automated) / LIVE RETEST | Live SavedVariables retained a valid `AuctionHouseFrame` workspace position, ruling out corrupt geometry. The loss occurred when drag completion vacated Blizzard's active UIPanel slot through `HideUIPanel` followed by a direct frame `Show`. That re-entry is safe for independent menus but can sever an NPC-bound interaction transaction, leaving the next auctioneer click audible without a displayable panel. Every context-bound panel now remains in Blizzard's native slot; Offhand only saves and reapplies its anchor on later native opens. Regression proves an Auction House workspace drop performs no slot eviction and that a subsequent native reopen restores the saved Offhand position. Retest open, move, close with X, reopen at the same auctioneer, Escape close, reopen, then repeat after `/reload`. |
| Branch and checkpoint | PASS | `codex/forever-safe-recovery` is clean at `2d02266d842dbb148f05429d65f2fe7caa3ee7e1`; annotated tag `checkpoint/2026-09-22-forever-v2.1.2-stable` points at HEAD and the branch matches origin. |
| Automated addon baseline | PASS | All 21 Lua suites and all five addon manifest validations passed on 2026-09-23. |
| Companion preference regression | PASS | `tests/companion-preferences.ps1` passed on 2026-09-23, including compilation of the full Companion source. |
| Companion checkpoint binary | PASS | SHA-256 is `9FB8FA71CD76F71ABCB3BE73A69556630FCAE90153CBA10F95B5F7030BA2580A`. |
| Companion Beta 2 binary | PASS | Rebuilt v2.1.2.0 standalone SHA-256 is `CBA79B70788C904BBA13321CC16A1F00BCCDF6A265584C977DB5E255136A73B5`; this locally compiled beta has release checksums but no GitHub Actions provenance attestation. |
| Companion Beta 3 candidate | PASS | Rebuilt v2.1.2.0 standalone SHA-256 is `7CB2138A35CA34F2AF2440F5649451F211D5CBD0EC7CE0F0DCEC4D2DC01113F6`; source/compile regression passed. |
| Companion Beta 4 candidate | PASS (artifact) / GAP (live) | Rebuilt v2.1.2.0 standalone SHA-256 is `0F865AAF90F7EE83680AD2D46D454F9074D06C9F0D76A5A74A8966D5AAD0CD31`. Addon `F12B9EB9...875F`, Companion archive `76C82114...4926`, and complete bundle `A2ABED50...B84A` passed source/binary parity, version and development-content exclusion checks. This candidate contains the physical-monitor identity migration and has not been published or tested live. |
| Exact Forever topology | PASS | 1440x2560 portrait workspace plus 2560x1440 landscape Mainhand spans as 4000x2560; cold launch and respan retain the layout. |
| Independent FancyZones window restoration | PASS (live Forever) / IMPLEMENTED IN SOURCE (automated) | With Companion closed and both generated bridge files absent, a PowerToys FancyZones Canvas zone restored the same cross-monitor work-area frame after a cold launch. DWM measured `4000x2512`, the WoW client reported `3998x2480`, and Offhand produced a `1439x2480` workspace plus `2559x1439` Mainhand with viewport bounds passing. The addon now stores an explicitly confirmed account-wide canvas signature, accepts bounded `MATCH` and `CLOSE` variation, rejects ambiguous or malformed records, and treats the observed ordinary `2114x1353` one-monitor window as safe single-screen rather than falsely reporting a manual span. Native window origin remains unobservable and requires visual confirmation. |
| Beta 3 physical display identity / Mainhand reversal | FIXED IN SOURCE (automated) / CRITICAL LIVE RETEST | The user's standard 1440x2560 + 2560x1440 setup reproduced a concrete Companion failure: configuration stored `MainhandDevice=\\.\DISPLAY1`, Windows later assigned that label to the portrait display, and generated topology consequently declared the portrait `1440x2560` display as game/Mainhand. Companion now persists the physical monitor ID obtained from Windows, follows it across `DISPLAY#` renumbering, defaults an unupgraded configuration to the Windows primary display, and blocks automatic spanning until the user confirms the physical selection once. Regression swaps both `DISPLAY#` labels while retaining physical IDs and proves the landscape Mainhand remains selected. Existing Beta 3 binaries do not contain this fix. |
| Restored Options master-checkbox state | FIXED IN SOURCE (automated) / LIVE GAP | Disk SavedVariables and the generated Forever bridge both contained `enabled=true`; this was not evidence of another persistence loss. The settings frame could instead be restored by `Show()` without passing through `Options:Open()`, leaving its construction-time checkbox appearance stale. Every `OnShow` now resynchronizes the master toggle and all displayed settings from the active profile. Regression covers direct restoration with both enabled and disabled states. |
| Exact-topology settings and wizard classification | FIXED IN SOURCE (automated) / LIVE GAP | Companion topology intentionally owns display rectangles, so manual orientation and seam controls remain disabled while exact topology is active. The panel and wizard now state this explicitly. Exact side-by-side topology is classified from the independent game/workspace dimensions; a portrait workspace plus landscape Mainhand is no longer mislabeled or saved as `Dual Landscape 50/50`. |
| Missing-workspace recovery | PASS | Physical disconnect restores WoW to the surviving Mainhand; map, character, bags and chat remain reachable without replacing saved Offhand positions. |
| Native backpack mode switching and Mainhand transfer | FIXED IN SOURCE (automated) / LIVE RETEST | Individual and combined bags are two presentations of one backpack, but each previously retained an independent Offhand root. A stale inactive root could therefore pull the reopened combined bag offscreen, while protected individual bags were skipped by the generic drag system. Non-Forever clients retain the native-title observer; Forever uses the isolated `UIParent` sibling grip described in OH-FOR-006. Both paths keep only the active Offhand root and clear both roots when either presentation is moved to Mainhand. Regression covers proxy dragging, mode handoff, stale-root cleanup and Mainhand redocking. |
| Forever backpack Escape error, grey item-grid overlay and OH-FOR-006 item-use taint | PASS (automated and live Forever QA) | The reported unspanned `ContainerFrame_OnHide -> UpdateNewItemList` failure had `itemButton=nil` while `ContainerFrame1` carried Offhand recovery state. Directly showing a native bag shell bypassed Blizzard's pooled item-button initialization, while later title/close persistence hooks remained in the protected `UseContainerItem` ancestry. Forever native bags now use an isolated `UIParent` sibling grip: no native title, close, visibility, item-button, bag-function, `SetPoint`, or anchor-manager hook is installed, no Offhand field is stored on the bag, and reload restoration calls Blizzard's opener rather than `ContainerFrame:Show()`. Only the user-initiated root movement and an out-of-combat root anchor restore touch the native root. Forever's `ToggleGameMenu -> CloseAllBags` path is observed after it returns; if the bag consumed Escape, the next frame applies the requested menu visibility directly and reopens the tracked bag second. Deferred addon code never calls `ToggleGameMenu`, which would enter Forever's protected `SpellStopCasting` path. The same addon-owned observer reads Settings, AddOns and Edit Mode visibility to recover from their delayed bag cleanup without hooking those panel trees; explicit B/X closes still win. When Forever leaves a hidden root logically open and `OpenAllBags` declines, recovery normalizes the state only through Blizzard's toggle/open APIs. If a modal panel temporarily rejects every public bag API, Offhand retains the tracked intent for bounded later retries and never falls back to `ContainerFrame:Show()`. A bounded transition window plus secure Settings-opening observers covers Options' own `ToggleAllBags` cleanup before its frame is visible and AddOn List's post-hide cleanup. Forever routes that bypass the observable Settings APIs use the simultaneous Game Menu exit as the navigation signal; ordinary B/X outside navigation still cancels the window. Native workspace persistence remains inactive whenever `isSpanned` is false. Live QA passed Escape, AddOn List, Edit Mode and Options entry/exit; right-click Hearthstone use after every transition; and switching to Baganator and back to Blizzard bags. The removal of the final direct-show fallback requires a focused live retest of modal rejection recovery. |
| Forever Professions opens partly in mixed-height void | PASS (automated and live Forever) | Blizzard can anchor the manually opened Professions window at the full spanned UIParent's upper left, placing its title in the non-physical region above a shorter landscape Mainhand. The isolated movement adapter is now the hidden default. A one-time migration converts the former compatibility-card `false` value to enabled, so upgraded accounts cannot lose the drag surface after that card was removed; later internal API opt-outs remain sticky. Offhand waits one second for native cold-start initialization only on initial discovery, then centers an unsaved Professions root on Mainhand before exposing its isolated drag surface. Existing saved positions are restored immediately upon opening and protected against Blizzard UIPanel layout resets via synchronous SetPoint interception. If native Gamepad or another protected interface state refuses the first title-grip attachment, a narrow observer retries only while that Professions root is visible and unattached after keyboard UI becomes safe; existing movers and panel anchors are not refreshed. An Offhand-positioned panel re-vacates a UIPanel slot reclaimed by Blizzard, so keyboard and mouse Escape leaves it open, and the standalone Professions book retains its explicit Offhand open state across reload. The 2026-10-20 live pass confirmed that the visible Offhand Professions frame moves normally and restores its position across `/reload`. Native Gamepad Back and focus switching remain Blizzard-owned. |
| Optional workspace close-button hiding | FIXED IN CURRENT SOURCE (automated) / LIVE RETEST | A user-provided proof of concept hid map, character and bag close buttons globally. Offhand now offers a profile-scoped, default-off setting that hides only the X belonging to a visible frame physically inside the Offhand workspace. It supports ordinary Blizzard panels, native bags, Baganator theme roots and EllesmereUI's anonymous header button; original alpha and mouse state return on Mainhand, single-screen recovery or disablement. A one-second poll handles lazy frame and skin refresh without attaching scripts to native controls. Live-test the Forever shareable-map-pin path with taint logging enabled, every supported bag presentation, combat transitions and profile switching. |
| Reconnect recovery | PASS | Reconnection, selected-Mainhand restore and exact two-monitor respan passed. |
| Protected Edit Mode recovery | FIXED (automated) / LIVE RETEST | Player-click **Use Modern** and **Restore Offhand** prompts perform the protected layout changes Forever rejects from addon timers. **Bring to Mainhand** now remains available both on a mixed-height span and during explicit single-screen `MISMATCH` recovery, when stale spanned controls are most likely to be unreachable. Its read-only detector covers the manager and separate settings dialog; the click centers only shown, unprotected control surfaces and does not attach handlers, move protected HUD systems, or alter Edit Mode panel metadata. |
| Forever mixed-height Party Frames and unsaved World Map | FIXED IN CURRENT SOURCE (automated) / LIVE RETEST | A confirmed 1920x1080 bottom-aligned workspace beside a 3840x2160 Mainhand creates a real 1920x1080 UIParent region above the workspace with no physical display. Blizzard's default Party Frame and unsaved World Map anchors could land there even though exact Companion topology and viewport bounds passed. The external Forever `ToggleWorldMap` post-hook rescues only a shown, windowed, unsaved map through actual monitor rectangles and never hooks the native MapCanvas tree. Protected Party/Raid Frames remain Blizzard Edit Mode-owned. A Beta 21 follow-up showed that the generated layout could be current while Repair HUD repeatedly missed a system-relative Party entry. The player-clicked repair now passes the detected group candidate into layout generation, rebases that matching serialized entry into Mainhand, and fails explicitly if the payload lacks it. Ordinary customized reachable positions remain untouched. `/offhand diag` now prints group-frame bounds and protected-HUD recovery state. Regression covers targeted repair, no false success, exact reported geometry, no native map scripts, and read-only live-frame detection. Live retest must confirm the Party preview is visible after repair and `/reload`, joining a party displays usable frames, reopening Edit Mode does not prompt again, and current taint logs remain clean. |
| Raw mouse span handling | PASS | `OH RAW 1` was observed live and continuous right-button vertical camera movement passed; the prior CVar is restored outside the active span. |
| Core preference persistence | PASS | Master enable and minimap preference survived `/reload`. |
| Complete fallback logic | PASS (automated) / GAP (broad live) | Versioned, checksummed account and character snapshots are covered for geometry, themes, nested custom colors, profiles and Edit Mode recovery; equal-or-newer normal SavedVariables win. Broader live `/reload`, relog, cold-restart and multi-character coverage remains. |
| Combat, taint and HUD bars | GAP | Requires structured live combat/post-combat tests covering action, stance, pet, XP and reputation bars. |
| Runtime transitions and longevity | GAP | Long idle, zone/loading transitions, cinematics, relog/character changes and repeated map/bag/chat/tooltip/dropdown/panel reopen tests remain. |
| Companion controls and repeated hotplug | GAP | Tray, display identification, pause, update/help behavior and repeated recovery cycles remain. |
| Addon coexistence | GAP | Chattynator, bag addons, RIF, OneWorld, Focused, DeSync and representative movable addon windows remain. |
| Additional physical topologies | GAP | Dual landscape, stacked, mixed 1440p/1080p, 32:9 combinations, negative origins and primary-display changes require available hardware. Unavailable hardware is not a defect. |
| Release source consistency | PASS / GAP | TOCs, Companion assembly/manifest/UI, packager default, README, release notes and website source identify v2.1.2; the changelog now has a dated v2.1.2 section. The website's combat-safe claim remains subject to the live combat/taint matrix. |
| Beta 2 release artifacts | PASS | Rebuilt and inspected: addon `E1DD209F...B3B4`, Companion archive `A8D6DD6F...BC91`, standalone EXE `CBA79B70...73B5`, and complete bundle `C313EB2A...0281`. All archives exclude development-only content. |
| Beta 3 release artifacts | PASS | Published and inspected: addon `10364E5E...A323`, Companion archive `343DE945...6F98`, standalone EXE `7CB2138A...13F6`, and complete bundle `80356CA6...AC7E`. GitHub-reported digests match local files; the addon archive matches current source and excludes development-only content. |
| Confirmed open runtime defects | THREE BETA 1 REPORTS FIXED IN SOURCE / LIVE GAP | Beta 1 user reports confirmed two secret-number taint paths (`CompactUnitFrame`, `TextStatusBar`) and Cooldown Viewer aura-table taint. Current source removes the shared unsafe global/panel mutations and excludes Blizzard managed frames, with focused regression coverage. Exact live retests remain required before acceptance. |
| Cross-client disabled-state isolation | PASS (automated) / GAP (live) | Retail mocks now prove disabled and temporary single-screen profiles leave tooltip and bag ownership untouched. Live confirmation remains required on every supported client family. |
| Mixed-resolution geometry | PASS (automated) / GAP (additional hardware) | Companion and Lua geometry regressions retain independent display widths, heights and offsets; the accepted Forever 1440x2560 + 2560x1440 layout is live proof. Additional 1440p/1080p and DPI combinations remain validation gaps, not confirmed defects. |
| Engine-owned combat, damage, healing and XP text scale | PASS (automated + live Forever) | Forever live testing corrected the earlier false negative: `WorldTextScale_v2=0.4` visibly reduced damage and XP text immediately and remained effective across `/reload`; restoring `1` enlarged it again. Every attempt to resize or re-anchor Blizzard's native bubble root, visual child or NineSlice either displaced, deformed or hid it, so those native geometry paths remain removed. A four-state live comparison then confirmed EllesmereUI's independent visual stayed correctly sized and world-anchored while unspanned, spanned and restored. Offhand now independently applies the same ownership boundary only on affected mixed-height spans: Blizzard retains the outer world carrier; an addon-owned classic backdrop, tail and 13-point text mirror are centred on it; only the native visual child's alpha is borrowed, after the replacement is ready. Equal-height and unspanned users remain native, instances fail open, pre-hidden children are treated as externally owned, and EllesmereUI customization takes precedence. The user live-confirmed correct steady-state bubble size, text, anchor and slider response with EllesmereUI disabled. The initial 0.1-second first-bubble transition was removed with immediate and next-frame chat-event acquisition and subsequently live-confirmed. Percentage normalization and the gentler slider drag curve are also covered by regression. |
| Spanned render performance and motion fidelity | EXPERIMENTAL FIX IN BRANCH / LIVE RETEST | User comparisons now show static 3D-world and world-nameplate softness while spanned, not only temporal edge shimmer. Exact WorldFrame bounds and `RenderScale=1` prove final geometry and the saved render-scale CVar, but cannot prove that WoW recreated its internal D3D swap-chain buffers after the external borderless resize. The Companion now applies the exact span, performs a one-pixel `SetWindowPos` height nudge after the borderless style is active, waits 50 ms, and restores the exact bounds. This uses only ordinary window geometry: no injected messages, renderer hooks, process-memory access, or gameplay input. Automated coverage verifies negative-origin stacked bounds, one-dimensional fallbacks, exact final-topology preservation, and the prohibited interop boundary. Live retest must compare identical scenes after a cold launch and manual span; if softness persists, test a persistent one-pixel outer inset and opt-in resample sharpening separately rather than conflating them. Previous evidence remains relevant: affected systems passed exact viewport bounds with D3D12, `RenderScale=1`, dynamic scaling disabled, and branch-dependent `gxWindowedResolution` values that do not describe the live backbuffer. |
| Retail friendly player nameplate visibility | REVISED FIX IN CURRENT SOURCE (automated) / LIVE RETEST | Outdoor live testing confirmed the name CVar fix while spanned, but restoring/unspanning the window restored the previous `0` preference and blanked friendly bars again. Visibility is now an Offhand-enabled invariant rather than span compensation: canonical `1` is maintained on Retail while Offhand is enabled, including an unspanned window, and the exact original preference is restored only when Offhand is disabled or unloaded. Scale/native Size ownership remain span-only. Retest spanned and unspanned, selected and unselected, then disable Offhand and confirm the original preference returns. Instance visibility remains live-unverified. |
| Offhand bag item tooltips crossing the seam | PASS (automated + live Retail/Forever, portrait-left landscape-right) | Retail proved that reversing ShoppingTooltip dependencies after `TooltipComparisonManager:AnchorShoppingTooltips` poisoned the next item-data refresh: Blizzard attempted `ShoppingTooltip1 -> ShoppingTooltip2` while the retained Offhand graph still contained `ShoppingTooltip2 -> ShoppingTooltip1`, producing a circular-anchor Lua error. Offhand no longer calls `SetPoint` on any ShoppingTooltip. After the completed manager transaction it measures the intact native group and translates only the manually owned primary tooltip, leaving a 12-physical-pixel workspace/seam margin. This preserves Blizzard's acyclic comparison graph across repeated refreshes and keeps cursor-, world- and Mainhand-owned tooltips native. Retail's separate backpack snap-back was also explicit in the drag-stop path: a Mainhand drop cleared user placement and invoked `LayoutBags`. Hardware drops of the primary/combined backpack now retain a clamped Mainhand coordinate and no longer request native bottom-right redocking. Live testing confirms correct seam containment on Retail and Forever Beta with a portrait workspace on the left, landscape Mainhand on the right. Opposite-side and stacked topologies remain unverified. |
| Manual setup blocked at onboarding Step 4 | FIXED IN CURRENT SOURCE (automated) / LIVE RETEST | Step 4 previously required `companionTopology` even though manual spanning is supported by the viewport and calibration wizard. It now accepts a live manually detected span, explains that calibration will use manual monitor controls, and continues to block genuinely single-screen geometry or a stale generated Companion topology. Retest a clean profile with no Companion/topology file after manually resizing Windowed WoW across both displays. |
| Companion long status/log text | FIXED (automated) / GAP (visual) | The display-plan field now reserves two wrapped lines and the activity log uses a read-only word-wrapped surface. Source/compile regression passed; visually confirm the disconnected-display message and long log entries at normal and high DPI. |
| Single-display 32:9 split width | DOCUMENTED LIMITATION | The current explicit one-screen mode divides the display 50/50. Exact Companion topology disables the in-game seam slider, so arbitrary split width is not currently supported. |
| Forever Edit Mode layout identity | FIXED (automated) / GAP (live) | Layout-name matching was already case-insensitive; recovery now also re-resolves the saved name when its custom slot ID changes. Regression covers `OFFHAND` moving from global ID 6 to 5; repeat the disconnect/reconnect player-click flow live. |
| OH-FOR-003 Forever per-character Edit Mode recovery ownership | FIXED IN CURRENT SOURCE (automated) / LIVE RETEST | Forever no longer assumes a custom layout named `Offhand` or shares an in-progress recovery transaction through an Offhand settings profile. On upgrade, a healthy exact-span character adopts its active custom layout; ambiguous cases use **Use Current Edit Mode Layout** in the Recovery card. Built-in layouts are rejected, legacy profile records are scrubbed account-wide and staged only for the owning character, and stale name/ID transactions are discarded after API validation. Verify upgrade, `/reload`, relog, two characters sharing one settings profile, and disconnect/reconnect player-click fallback/restore. |
| OH-FOR-004 generated topology replaced by addon update | FIXED / LIVE REPAIR PASS / IN-GAME RELOAD RETEST | Companion now recognizes when an exactly spanned live window has lost or received a stale `CompanionTopology.lua`, atomically rewrites the selected plan without moving the window, and logs that one `/reload` is required. Automated regression passed. The rebuilt Beta 19 Companion was restarted against the live 4000x2560 Forever span; replacing its bridge with the packaged placeholder was repaired on the next polling pass without moving WoW. One in-game `/reload` remains to confirm the repaired file is consumed without another handoff notice. |
| OH-COMP-001 newer Companion false mismatch | FIXED IN CURRENT SOURCE (automated) / LIVE RETEST | The addon now compares the generated Companion release against `X-Offhand-Companion-Min-Version` instead of requiring string equality. Regression accepts Beta 19 and stable 2.1.2 for a Beta 18 minimum, rejects Beta 12, and treats unknown future formats as unverified rather than incompatible. |
| OH-UI-001 first-login cinematic Escape interception | PASS (automated + live Forever Beta) | Zero-runtime isolation ruled out addon Escape handling and established that Forever placed its native skip dialog outside the visible Mainhand cinematic in the mixed-height span. Current source observes only the native dialog's `OnShow` and recenters the already-open dialog in Mainhand; it neither handles the key nor invokes skip/confirm. Live testing on the exact 4000x2560 span confirmed that Escape displays Blizzard's confirmation dialog on Mainhand and the cinematic can be skipped while spanned. |
| OH-UI-002 detached Mainhand chat persistence | FIXED (automated + live Forever) | Offhand restored detached chat entries from `savedWorkspacePositions` during startup but omitted matching entries from `savedMainPositions`, exactly matching the report that Offhand-side windows persisted while Mainhand windows stacked at the span center. Registration, `OnShow`, and late native chat-save settlement reapply either committed monitor position for genuinely detached windows; live dock and tab-parent evidence takes precedence over Forever's stale `isDocked`/`isStaticDocked` fields. Reload-time `FCF_DockFrame` and save callbacks no longer erase a tracked snapshot; only an observed user tab re-dock relinquishes it. Custom secondary windows absent from the settled dock are persisted shown/detached before their saved Blizzard presentation is replayed. The built-in Combat Log is deliberately excluded from automatic visibility, docking and presentation recovery after that migration path proved unsafe; only an already-visible, explicitly detached Combat Log may receive its saved position. Color/opacity writes and Settings transitions retain their bounded replay for custom detached windows. The unsafe `FCF_UnDockFrame` replay remains removed. |
| OH-UI-003 Chattynator Combat Log scroll callback/input ownership | FIXED (automated + live Forever smoke test) | The nil callback stack is entirely inside Blizzard's scrolling-message refresh. Chattynator reparents native `ChatFrame2`, dual-anchors it in a custom holder and hides its native chrome; Offhand had still registered native chat hooks on that borrowed frame and its HUD pass could still select Chattynator's primary window and reposition the shared edit box. With Chattynator loaded, Offhand now clears stale `ChatFrameN` snapshots and abstains from all chat layout, hooks, clamping, sizing, anchoring, restoration, and edit-box positioning. Regression proves Chattynator's custom window, shared input anchor, borrowed Combat Log anchors, and dimensions remain untouched. Live smoke testing confirmed Chattynator behaved normally after the native-frame verification; the original missing callback was not independently attributable to Offhand. |
| OH-UI-004 Forever docked Combat Log overlay and chat-button drift | REVISED FIX IN CURRENT SOURCE (automated + reporter patch pass) / LIVE RETEST | The floating combat lines are the inactive Blizzard Combat Log (`ChatFrame2`) being shown over General, not messages injected into General. The initial settlement fix was insufficient: clean-character diagnostics proved the generic persistent-panel loop could still replay a stale 430x120 `ChatFrame2` record over Blizzard's healthy hidden 752x537 dock-relative frame before dock settlement. Generic restoration now excludes every Forever secondary Blizzard chat frame at both the collection and position-application boundaries. Only the settlement-gated tracked-chat path may restore a genuinely detached secondary frame. The unsafe one-time reopen path remains removed, positive membership or native tab-parent evidence hands native ownership back immediately, and a hidden Combat Log is never synthesized. Automated regression preserves native visibility, dimensions, anchor, and chat state under the exact stale-record reproduction, covers transiently absent `ChatFrame3`, and confirms non-Forever behavior remains unchanged. The reporter independently confirmed the proposed two-guard form live. Retest cold login and `/reload`, generate combat entries before and after repeated General/Combat Log switching, then test an intentionally detached Combat Log and a custom chat window. |
| OH-UI-007 Dialogue UI Mainhand confinement | SECOND REVISED FIX IN CURRENT SOURCE (automated) / LIVE FOREVER RETEST | Dialogue UI 1.0.6 sizes from `WorldFrame` but anchors its presentation roots and helpers to the full spanned `UIParent`. The first live retest proved anchor translation alone moved the oversized canvas-relative parchment into Mainhand and cropped its right and bottom edges. The second proved that physical-height scale compensation was correct, but inverse-compensating Dialogue UI's own quarter-screen offset pushed the now-correctly-sized parchment beyond Mainhand's right edge. Offhand now keeps that native offset in Dialogue UI's scaled coordinate space, confines the anchors, applies Mainhand height scaling to the quest, book, and settings roots, and follows animation resets without changing the other addon's size preference, camera, input, or saved settings. Test gossip, every quest stage, reward choice, the first-use banner, F1 settings, readable books, both orientations, and every Dialogue UI frame size. Then disable Offhand and verify native single-screen placement, scale, and offsets return. |
| Beta 1 Forever Edit Mode / `CompactUnitFrame` taint | FIXED IN CURRENT SOURCE (automated) / GAP (exact live regression) | The report reproduced after the earlier protected-frame exclusions, proving that fix was incomplete. Audit found Forever still replacing `CloseAllWindows`, modifying `UIPanelWindows`/panel attributes and anchoring Edit Mode/menu panels. Current source preserves Blizzard's close functions, Edit Mode manager, Game Menu, panel metadata and native anchors. Repeat Edit Mode open/close with party frames visible, including after combat. |
| Beta 1 Forever CharacterFrame / `TextStatusBar` taint | FIXED IN CURRENT SOURCE (automated) / GAP (exact live regression) | The report also reproduced after the earlier PlayerFrame exclusions. The remaining shared path was Offhand's global close-function replacement and CharacterFrame panel-manager mutation. Both are now disabled on Forever; native Escape/panel behavior takes precedence over persistent-open workspace panels. Repeat CharacterFrame open/close with player status text shown. |
| Beta 1 Forever Cooldown Viewer aura-table taint | FIXED IN CURRENT SOURCE (automated) / GAP (exact live regression) | Three user stacks named `EssentialCooldownViewer`/`UtilityCooldownViewer` after an orientation change. These are unprotected but Blizzard Edit Mode-managed frames, so the generic UIParent void scanner could reanchor them and taint later aura registration. Named and semantic managed-frame detection now excludes them from movement, scripts and recovery; the native `UpdateContainerFrameAnchors` function is also preserved on Forever. Repeat vertical-orientation setup with all Cooldown Viewer types enabled and exercise aura add/remove alerts. |
| Forever World Map shareable waypoint taint | PASS (automated + live Forever) | The first hardening pass stopped hooks on `WorldMapFrame` itself, but the generic draggable setup still hooked its native title container, title button/close lifecycle, and stored addon state on the Blizzard frame. That remained in the same protected widget tree used when Shift-clicking the yellow `Map Pin Sharing` user waypoint to insert a chat link. Forever now uses an independent `UIParent` drag surface, keeps all bookkeeping in an addon-owned weak table, and installs no handler on any native map control. Live verification confirmed shareable-waypoint and ordinary quest-pin refresh behavior without a new `SetPassThroughButtons()` blocked action; the saved workspace map still reopens after `/reload`, survives Escape, and remains draggable. |
| OH-FOR-007 Forever MapCanvas pin taint and native-bag open-state wedge | PASS (automated + live Forever) | BugGrabber attributed both combat quest-pin refresh and an out-of-combat user-waypoint acquisition to Offhand at protected `Button/Frame:SetPassThroughButtons()`. Generic restore markers now remain in addon-owned weak state, and Forever no longer runs map geometry work from `ToggleWorldMap` or `ToggleQuestLog`; an independent `UIParent` observer settles the saved Offhand anchor after Blizzard's protected toggle stack returns. The observer preserves a pre-reload open marker through the map's initial hidden construction frame and settles the first visible geometry immediately, while retaining placement, scaling, drag, reload persistence, and open-state ownership. Forever native backpacks persist a dedicated native-root open marker: Escape and system-panel cleanup reopen through Blizzard's public bag APIs, while B/X clear the marker and no recovery path directly shows a native bag shell. Forever can hide the root directly without calling `CloseAllBags`; Offhand observes `ToggleAllBags`, `ToggleBag`, and the default-B `ToggleBackpack` path (plus its container-namespace variant) as explicit hardware actions. The former three-second panel-transition grace timer has been removed entirely; Settings/AddOns/Edit Mode recovery now uses only visible panel state, visibility edges, and same-turn navigation markers. Historical EUI/Baganator child markers cannot resurrect the native backpack. Live Forever verification confirmed map-pin acquisition and refresh without a blocked action, map reload/placement persistence, bag reload-state persistence, Escape preservation, and immediate B/X response after dismissing the Game Menu. |
| Forever `taintLog` diagnostic safety | CLIENT BUG / DO NOT ENABLE | Forever 16.0.1 has a reported client defect where enabling `taintLog` breaks addon `hooksecurefunc` post-hooks. Do not use `/console taintLog 1` or `2` for Offhand live QA on Forever until Blizzard resolves it. Run `/console taintLog 0` followed by `/reload`, then use BugGrabber/BugSack blocked-action stacks for reproduction evidence. |
| v2.1.2 Forever locked/docked chat-tab drag | FIXED (automated) / GAP (live regression) | Confirmed from the reported `Core/Canvas.lua:1577` stack and locals: Offhand registered the tab for dragging, marked ChatFrame1 movable and called `StartMoving()` even though Forever reported `isLocked=true`, `isDocked=1` and a static dock. Offhand now observes Blizzard's native tab-drag lifecycle without overriding registration/movability or forcing movement. Regression makes those writes throw and verifies initialization plus drag observation remain safe. |
| v2.1.2 Forever Gamepad destination movement | FIXED (automated) / CRASH RETEST REQUIRED | Character, Map, Spellbook, Talents, Professions, Channels, Social, Communities, Collections and Legacy retain root-only centering. Per-panel Offhand-owned UIParent siblings provide mouse movement without adding a child, script, field, movability flag or drag call to Blizzard panel trees. The completed offset is saved per character. A profile option, enabled by default, hides or restores every addon-owned mover without changing panel placement. The adapter is strictly gated by Forever's native `InputDeviceInterfaceStyle` Gamepad setting. The 2026-10-20 live report produced a native `0x80000003` client breakpoint while toggling Gamepad mode, with no Lua stack. Current source now performs no protected radial or destination anchor work until the interface style has remained stable for one second, observes at 20 Hz instead of every rendered frame, and defers restoration of visible protected roots until they hide. Protected roots retain the narrow position-only allowlist and LootFrame remains excluded. Retest repeated keyboard/Gamepad transitions first, then native Back and focus swap. The same live pass confirmed World Map Escape, a limited Flight Master interaction, and non-Gamepad Loot Window behavior. |
| v2.1.2 Forever Gamepad Edit Mode transaction dialogs | FIXED (automated) / GAP (live regression) | The Gamepad-only opt-out was removed for the explicit EditModeLayoutDialog, import and unsaved-changes roots. A shown unprotected dialog outside both physical displays is centered on Mainhand outside combat. No Blizzard dialog scripts, controls or focus handlers are changed. |
| Horizontal and stacked Offhand workspace frame snapback | FIXED IN CURRENT SOURCE (automated) / GAP (exact hardware) | Two independent paths could recenter a valid drop. The popup/void scanner classified an upper workspace only by horizontal overlap with Mainhand, while the common drag-stop handler cleared Blizzard's `userPlaced` state before reading the final coordinates; live clients can synchronously restore the native center anchor at that call. The scanner now checks the complete workspace rectangle, drag-stop captures geometry first, and Forever retains user-placed state. Regressions cover full drag/save/reset/reload restoration for upper-stacked, horizontal-left and horizontal-right workspaces, including an emulated native center reset. Retest the reported frame types on exact Companion topology. |
| Classic/TBC Companion topology reports `MISMATCH` after span | FIXED IN CURRENT SOURCE (automated) / LIVE RETEST | TBC Anniversary reported `GetPhysicalScreenSize() = 2560x1440` after Companion successfully resized the window and wrote a `4000x2560` topology. Its live UI canvas nevertheless had the exact `4000:2560` aspect. Non-Forever clients now accept the topology only when the reported resolution matches one selected display and the UI canvas aspect matches the complete Companion bounds. Regression also proves Restore Window's `2560:1440` canvas rejects the stale topology; Forever keeps strict exact-dimension validation. |
| Forever intermittent pre-span dimensions / false mixed topology | FIXED IN CURRENT SOURCE (automated) / LIVE RETEST | A reported 3840x2160 Mainhand plus 1920x1080 workspace sometimes remained at the bordered pre-span client area `3818x2104` while the Companion expected `5760x2160`. The setup wizard then ignored the exact-topology `MISMATCH` state and mislabeled the one landscape window as mixed portrait + landscape through its broad fallback heuristic. The wizard now keeps this as a safe single-window mismatch rather than overwriting calibration with a guessed topology. `/offhand diag` now separately reports topology state, whether the generated handoff loaded, its schema and expected bounds, the live physical report and UI canvas dimensions. Forever's strict exact-size acceptance remains unchanged; capture the new line in both failing and recovered states to distinguish a missing generated file from renderer adoption delayed until `/reload`. |
| Retail/Anniversary per-character Edit Mode selection after login or `/reload` | FIXED IN CURRENT SOURCE (automated) / LIVE RETEST | Beta 17 hard-coded the layout name `Offhand`, overriding class-specific choices such as `druid offhand`. Offhand now adopts the character's active layout on upgrade, records later explicit selections in per-character state, and restores the remembered name only when Blizzard returns a different layout. It still uses `C_EditMode.SetActiveLayout` with the custom-layout array index because Anniversary's active global ID is a different namespace. Forever remains excluded from automatic selection and uses only its player-click missing-monitor recovery. |
| TBC Anniversary stock HUD remains arranged across the full span | FIXED IN CURRENT SOURCE (automated) / LINUX LIVE RETEST | The 4480x1440 report shows correct Offhand viewport/map routing after switching Proton-Wine from native Wayland to XWayland, but protected Blizzard HUD systems remained on their old full-window layout until Bartender4 moved them manually. Anniversary 2.5.6 ships `Blizzard_EditMode` with the required read/save/activate APIs; the gap was profiles already marked setup-complete before Offhand added its generated Mainhand layout step. Such Retail/Anniversary profiles now receive a once-per-session player-action repair prompt when the generated layout is missing or belongs to a different topology. `/offhand diag` reports API availability, active/generated layout and the attention reason. Forever remains on its separate protected-HUD recovery flow. Retest under XWayland without Bartender4 first, accept **Create Mainhand HUD Layout**, reload, then repeat Span, focus, relog and `/offhand diag`. Native Wayland focus-driven unspan remains outside the Wine/Win32 compatibility boundary. |
| Three-display `1440x2560 + 3440x1440 + 1440x2560` report | CONFIRMED ARCHITECTURAL LIMITATION / DEFERRED THREE-DISPLAY SCOPE | The follow-up identifies two rotated 1440p portraits around one 3440x1440 ultrawide, for an approximately 6320x2560 desktop. The legacy 50% seam lands at x=3160, halfway through the ultrawide: one portrait plus half the ultrawide is assigned to each side, matching the screenshots' cut-off/letterboxed world. Windows alignment can change void placement but cannot repair this partition. Current Companion can safely use the ultrawide as Mainhand plus exactly one portrait as workspace (4880x2560 exact topology), leaving the other portrait outside WoW. Using both portraits as independent workspaces requires future three-display/multi-workspace geometry. Moving camera-dependent shadow splotches resolve in a restored single-monitor window, but must be retested under the supported exact two-display plan before classifying a separate renderer defect. |
| Forever Restore Window with stale exact topology | FIXED (automated) / GAP (live regression) | The Companion restores the native WoW window to Mainhand and pauses auto-span. A generated topology that no longer matches remains a safe single-screen recovery state: percentage spanning is not applied, the viewport fills the current window, saved workspace visibility is preserved, ordinary panels receive temporary visible anchors, and protected Edit Mode HUD recovery offers the player-click Modern/Offhand handoff. An absent topology now retains manual spanning on every client, including Forever. Reproduce Restore Window with a stale generated topology live, then verify `/reload` and exact respan. |
| Mob tooltip appearing on the other screen | VALIDATION GAP / UNSUPPORTED REPOSITIONING | The Discord suggestion to drag it in Edit Mode is not established by current source. Offhand normalizes tooltip scale while spanned but deliberately excludes `GameTooltip` from generic movement/recovery and provides no tooltip-anchor control. First reproduce under exact Companion topology and record the tooltip owner/anchor behavior; a future fix must preserve cursor-owned tooltips and coexist with tooltip addons rather than globally forcing one anchor. |
| Deferred product scope | DEFERRED | Antivirus submissions, code signing, more than two selected displays, guaranteed management of every arbitrary third-party frame and low-priority Companion UI refactoring. |
| External publication | GITHUB BETA 3 PUBLISHED / CURSEFORGE USER-MANAGED | GitHub pre-release `2.1.2-beta.3` was published on 2026-09-23 with addon, Companion, standalone EXE, complete bundle and checksum assets. GitHub-reported asset digests matched the local files. The user manages any CurseForge upload. Do not merge, promote to stable, modify the live website or submit antivirus reports without further approval. |

---

# Historical stabilization baseline -- 2026-09-16

## Build and deployment follow-up

- Rebuilt the native companion, addon ZIP and companion ZIP. Artifact checks
  verify source/TOC parity, matching executable copies and both checksum manifests.
- Packaging now always compiles current source, excludes unloaded legacy modules,
  retains existing build directories and uses unique temporary staging. Website
  checksums use the filenames actually served by the site. Release CI verifies
  artifacts before publication.
- Runtime addon version is read from TOC metadata (fallback 1.0.0), correcting the
  previous hardcoded 1.1.0 message. Companion assembly version remains 1.2.0.0.
- The Classic Era AddOns/Offhand folder is a junction to this repository. Source
  edits are therefore already available on next login/reload, without copying.
  Earlier wording that fixes were not installed was incorrect.
- WoW was not running during this follow-up. No live login, combat or UI acceptance
  was performed. No new public release tag was created.

Historical entries below do not establish acceptance of the present Canvas
implementation. Rollback: checkpoint/2026-09-16-before-stabilization (85f62ac).

- Corrected test harnesses: separate event handlers, CENTER-relative offsets,
  GetChildren varargs, child registration and delayed Edit Mode initialization.
- Active map coverage is in escape-and-bags.lua and loads Core/Canvas.lua.
  Historical module tests moved to tests/legacy, outside CI's active selection.
- Regressions cover a single scanner, clamped-CVar independence, native map
  dimensions and Ctrl-wheel combat protection, plus game-monitor drag bounds.
- Verification: all 14 active Lua suites and both TOCs pass; simulated companion
  window-operation tests and compiled C# preference regressions pass.
- No game-folder deployment or live runtime acceptance in this pass.

---

# Lifecycle validation â€” 2026-09-12

## Global UI baseline and independent resizable map

Replaced per-frame scale corrections with one guarded UIParent:SetScale baseline,
calculated from physical game/canvas dimensions and the saved size preference.
No uiScale CVar writes: avoids the earlier CVAR_UPDATE/layout feedback path.
Repeated identical calculations do not write scale; recursion/combat are guarded,
and disabling restores the pre-Offhand root scale. Native addon relative scales remain.
Removed addon-specific placement names; generic top-level movable-window/tooltip
discovery handles placement separately from scaling. Standard panel names remain
for Blizzard docking and opening behavior, not for scale exceptions.

Docked WorldMapFrame alone is detached via UIPanelLayout area metadata after
releasing its existing panel-stack slot. Its mini-map display mode remains windowed.
Other panels retain normal Blizzard stack behavior. A bottom-right grip resizes the
window/scroll canvas and saves dimensions; disabling docking restores original map
metadata/display preference and hides the grip. No combat resize is attempted.

Global baseline, inherited custom relative scale, no-op/reentrant updates, disable
restore, persistence and map coexistence/resize/restore mocks pass. Lua/TOC validation
passes. Nine files installed with matching hashes and backups. Real map rendering,
click/zoom behavior after resize, coexistence and global UI appearance still need
live acceptance testing after reload. No live client input was sent for this revision.

## RIF, tooltip scaling and panel persistence follow-up

Added named RIF roots (RiF_StatusWidget/MainWindow/options/onboarding/copy), tooltip
and dropdown roots, LFG frames and OneWorld context menu. Top-level GameTooltips and
named movable AceGUI windows are discovered with a one-second supported-frame scan.
This is not an override of all addon frames. OnSizeChanged also rechecks fit.
Dragged panel positions are saved by frame name and monitor-relative coordinates;
saved positions override Blizzard reopen anchors. Prior positions cannot be recovered.
Added padding inside visible monitor bounds to accommodate frame border artwork.

Bag handling now anchors individual backpack/bag-slot buttons, raises their frame
levels above the main artwork, and anchors MicroMenu left of the final bag slot.
No bag visibility or action state is forcibly changed. Existing immediate repair
hooks cover the bag buttons. Panel persistence, simulated reload/reopen, RIF/tooltip
scale, and geometry/lifecycle regression tests pass; TOC syntax validation passes.
Four updated files installed with matching hashes and temporary backups. This
revision still needs live visual confirmation of bags, menus, tooltips and reopening.

## Missing/oversized panels and micro-menu overlap

User confirmed action-bar flicker resolved. Screenshot shows widgets in the physical
desktop gap above the game monitor. CharacterDock had removed UIPanelWindows.area
for Spellbook/Friends/etc. without replacement placement. Removed that mutation;
reload restores original Blizzard panel definitions. Standard named panels now use
HUD-relative scale, fit within the game or deck rectangle and recover from invisible
gap positions. Valid user-placed panels can remain on either visible rectangle.
Dragging defers placement until drop; combat defers until exit. Named OneWorld and
DeSync widgets are included; unknown third-party panels are not globally overridden.
MapDock delegates placement to the same geometry; character/map/bag docking options
select the deck. MicroMenu and BagsBar now have separate adjacent artwork anchors,
including MicroMenuContainer scale handling and immediate repair hooks.

tests/panels.lua passes for panel metadata preservation, HUD scale, game/deck bounds,
gap rescue, dragging, combat and left-primary geometry. Geometry suite includes
micro-menu/bag anchor separation. Lifecycle and Lua/TOC validation pass. Six changed
runtime/documentation files installed with matching hashes and temporary backups.
No live reload or visual acceptance test performed for this revision yet.

## Idle Action Bar 2/3 and shapeshift flicker follow-up

User confirmed recurring flicker while idle out of combat. Previous XP-only fix
left action bars on a 50 ms timer and omitted modern StanceBar/PetActionBar hooks.
Action-frame scale and anchors now replay the last committed layout synchronously
after external SetScale/SetPoint calls, with recursion guards. Manager completion
also repairs the action frames. No visibility calls or method replacements added.
Modern and legacy stance/pet names are included. Combat repair remains deferred.

Geometry regression now simulates 100 scale/anchor resets on each bottom action
bar, StanceBar, legacy shapeshift frame and PetActionBar. Each returns to its desired
geometry before the setter returns, without timers. Combat/disabled checks pass;
existing geometry/lifecycle and TOC checks pass. Installed SeamRedirect.lua hash
matches the project. This revision still needs live idle/form-change verification.

## Companion unification and vertical alignment controls

- GUI, one-shot spanner and watcher now use Companion/Offhand-Window.ps1.
  Batch launchers use process-local execution-policy settings; no machine policy changes.
- Shared path restores minimized/maximized windows, uses physical DPI coordinates,
  verifies window ownership and immediate final bounds, and rolls back borders/bounds
  if spanning fails. More than one game client is treated as ambiguous.
- Installation is checked against the running client's directory, including the
  Vanilla TOC. Live enabled status is explicitly unknown; unrelated AddOns.txt files
  are no longer inspected. Unreadable installation paths do not pass the gate.
- Added the shared Game bottom offset field, Apply, and one-pixel nudges to settings
  and wizard. SavedVariables were not edited. Opening the field preserves calibration.
- tests/companion.ps1 passed under Windows PowerShell 5.1 with simulated native
  operations: install/unknown state, negative origins, restore, failure rollback,
  DPI-context cleanup, process ownership and multi-client refusal.
- Real shared native declarations compiled under Windows PowerShell 5.1. Read-only
  desktop measurement returned X=-1440, Y=-1114, width=4000, height=2560.
- tests/bottom-control.lua passed: opening, nudges, clamp, invalid text and refresh.
  Existing geometry/lifecycle suites and Lua/TOC validation passed. PowerShell files parse.
- Nine updated runtime/documentation files copied to the installed addon with hash
  verification and backups under the temporary Offhand-before-companion-update folder.
- No live window mutation, GUI launch, or game reload was performed in this follow-up.
  Actual spanning and new control rendering still require live acceptance testing.
  Restart the companion and reload the addon to load the updated versions.

## Calibration reference cleanup

Updated wizard/settings labels, heuristic detection wording, guide, README,
default comments and command help. Removed the unused uiScale initialization.
The 55% button is explicitly a custom split; 36% names its 1440/4000 geometry.
HUD presets are relative sizes, not resolution presets. Settings percentage
formatting now multiplies stored fractions by 100. Settings seam range matches
the wizard (15â€“80%, 0.5% steps); HUD range is 25â€“125%, with matching command clamps.
Added /Offhand settings and /Offhand options; clarified Fill and height behavior.
SavedVariables were not edited. Five updated files were backed up and copied to
the installed addon, with matching hashes. Existing geometry/lifecycle tests and
both TOC validations pass; revised graphical labels have not been checked live.

## Recurring XP/action-bar flicker follow-up

User reported continuous resizing, which invalidates acceptance of the earlier
transient recovery as sufficient. Classic's StatusTrackingManager UpdateBarVisuals
calls SetScale(ClassicScale) on each update. Offhand previously repaired that 50 ms
later and routed all HUD hooks through ApplyFullLayout.

- XP scale now corrects synchronously through a guarded post-hook; combat defers.
- Other HUD notifications coalesce into a HUD-only pass, without touching the
  viewport, canvas, or dock modules.
- Identical anchors are no longer cleared and rewritten.
- Regression passes: 100 XP resets recover before return without timers; 100
  manager notifications schedule one HUD pass; unchanged anchors remain untouched;
  100 combat resets defer to one post-combat repair. Geometry/lifecycle suites and
  both TOC validations pass. Installed Core/SeamRedirect.lua matches the workspace.
- This follow-up has not yet been verified in the live client. Continuous idle,
  XP/reputation updates, and combat transitions remain the runtime acceptance tests.

Source: https://github.com/Gethe/wow-ui-source/blob/classic_era/Interface/AddOns/Blizzard_ActionBar/Classic/StatusTrackingManagerOverrides.lua

## Geometry fix â€” final live result

The geometry work below supersedes the initial failing smoke test in this file.

- Measured physical client: 4000 x 2560. Left display: 1440 x 2560;
  right display: 2560 x 1440, bottom six pixels above the client bottom.
- Root cause: WorldFrame anchors received UIParent coordinates without converting
  effective scales. HUD offsets had the same mismatch. Geometry now rounds in
  physical pixels and converts offsets for each target frame.
- Installed updated Core files and Wizard into the existing Classic Era addon.
  Backup: `C:\Users\NAUX\AppData\Local\Temp\Offhand-geometry-20260912-001124`.
- Final saved settings: seam 0.36, HUD multiplier 0.70, bottom inset 6 pixels.
- `/Offhand diag` passed after reload. Saved WorldFrame physical rectangle:
  x=1439.9999, y=6, width=2560, height=1439.9999. Deck width=1439.9999.
- MainMenuBar, MainActionBar, ActionButton1, PlayerFrame, and MinimapCluster
  share effective scale 0.39375. ActionButton1 measures 47.25 x 47.25 pixels.
- Full 4000 x 2560 screenshot inspected: left workspace contains no world render;
  primary game area and managed HUD align. Evidence remains local at
  `C:\Games\World of Warcraft\_classic_era_\Screenshots\WoWScrnShot_091226_002328.jpg`.
- Chattynator primary window and chat entry now follow the game HUD size.
- A transient Blizzard bar reposition was observed and recovered on the deferred
  layout pass. This is not a guarantee of zero visible movement during updates.
- Closed WoW normally with `/quit`; saved settings and diagnostics verified.
  Latest BugGrabber session 371 contained two errors, neither referencing Offhand.
- Lua 5.1 geometry and lifecycle suites pass; both TOCs pass syntax/file validation.
  Geometry tests cover multiple global scales, nested frames, left-primary layouts,
  manual seam changes, bottom inset, fill bounds, and invalid values.
- Not verified: live combat/taint stress, cinematics, zone transitions, or arbitrary
  third-party addon positioning. OWL and other independent widgets still use their
  own anchors outside the managed HUD.

Scope: configuration preservation, master layout combat deferral, draggable panel
setup deferral, and reporting of caught layout errors.

## Automated checks

- Lua 5.1 syntax and referenced file validation passed for both TOCs using the
  addon development skill's `validate-addons.ps1`.
- `lua tests/lifecycle.lua` passed: existing seam/HUD settings survive migration;
  malformed root settings recover; install/reset geometry defaults agree; twenty
  combat layout requests execute once after combat; caught errors are reported;
  layout reentrancy guards recover after a failure.

## Live smoke test

- Client: existing Classic Era client under `C:\Games\World of Warcraft\_classic_era_`.
- Character: Shapeshifted, idle in Stormwind. Realm not independently verified.
- Backed up the four installed Core files to
  `C:\Users\NAUX\AppData\Local\Temp\Offhand-before-qa-20260912-000301`,
  then installed the four changed source files.
- Entered `/reload` after visually verifying chat focus and the exact command.
- Returned to the world; Offhand startup and viewport messages appeared without a
  visible Lua error dialog. This does not establish absence of taint or hidden errors.
- Existing visible HUD misalignment persisted. Geometry is not accepted as passing.
- Saved settings observed after reload: seam 0.36, HUD scale 0.56, game height 1.0,
  enabled true. No saved calibration was intentionally changed.
- Viewport message reported 960 x 540; these values come from the addon's current
  GetScreenWidth/GetScreenHeight calculation, not verified physical pixels.
- Issued normal window close for the target client after evidence capture.

## Remaining work

- Measure physical client bounds, monitor rectangles, UIParent dimensions/effective
  scale and WorldFrame bounds together. A 1440/4000 layout implies a 36% seam only
  when those physical bounds match the actual spanned client.
- Correct scaled HUD anchor offsets and left-primary handling with live measurements.
- Exercise actual combat/post-combat, cinematics, zone changes, and load-on-demand
  panels. Mock combat tests cannot establish protected-frame safety in the client.
- Review disabling/restoring managed frames, obsolete Deck bay references, and
  companion behavior before expanding workspace features or preparing a release.

## 2026-09-12: inaccessible child and RIF reset errors
- CharacterDock probes forbidden/inaccessible children and isolates discovery per frame. Failed hook installs stay inactive; discovery avoids combat. Added bad-self and forbidden-child regression; later valid frames and ticker initialization continue.
- RedIsFriend UI_Settings reset now declares its function-local locale table. Isolated reset test verifies localized and fallback values without touching player data.
- All five Offhand Lua test files, RIF settings-reset test, and both project validators passed. Both changed runtime files backed up, deployed to Classic Era and hash verified. Live reload remains to be tested.


## Deferred native layout corrections
- Panel OnShow/OnSizeChanged/SetPoint hooks now coalesce to next tick, allowing native multi-anchor transactions to finish. Explicit dimensions retained before replacing anchors. Tooltip placement preserves native location and clamps only when outside visible monitors; no tooltip position persistence.
- Map OnShow/display synchronization now defers configuration to avoid reentrant minimize/resize during native layout.
- Bag reopen and tooltip position/dimension regressions, map deferred-show regression, existing Lua suites and validator pass. Two runtime files deployed with backups and matching hashes. User screenshots exposed behavior not covered by former mocks; live verification remains required.

## 2026-09-21: Forever v2.1.0 exact-topology acceptance

- Hardware topology: 1440x2560 portrait workspace beside a 2560x1440 landscape Mainhand, spanned as a 4000x2560 virtual desktop.
- Companion v2.1.0 displayed the new display selection and explicit Mainhand controls.
- Selecting both displays and the landscape gaming display as Mainhand succeeded.
- `Span WoW Now` generated the exact topology and spanned the client correctly.
- Forever loaded the workspace panels, protected HUD, and persistent Edit Mode options frame in their expected rectangles.
- A normal WoW exit followed by a cold relaunch with Companion running preserved the complete layout.
- User accepted all seven primary release-candidate steps. The disconnected-workspace-display fail-safe remains the final live safety check.
- Physical workspace-display disconnect confirmed Companion refused `Span WoW Now` and did not collapse the 4000x2560 span onto the 2560x1440 Mainhand. The stale topology was rejected and the game remained viewable.
- The first disconnected-display run exposed a protected-HUD gap: Forever retained the spanned `Offhand` Blizzard Edit Mode layout, so protected frames were readable but malformed. The initial v2.1.1 automatic API handoff was later proven ineffective because Forever ignores this protected change outside a hardware event; v2.1.2 replaces it with player-click recovery prompts.

## 2026-09-22: Forever v2.1.2 recovery findings

- The primary seven-step exact-topology and cold-launch sequence passed on the
  1440x2560 portrait workspace plus 2560x1440 landscape Mainhand.
- Companion refused a new span after the workspace was physically disconnected,
  and Offhand rejected stale topology. Temporary single-screen recovery now gives
  map, character, bag, and chat windows clean reachable positions while retaining
  their saved Offhand coordinates for reconnection.
- Forever layout IDs are global: Modern 1, Classic 2, and the tested custom
  Offhand layout 6. A timer/addon call to `C_EditMode.SetActiveLayout(6)` was
  ignored, while the same call issued directly by the player succeeded. Recovery
  therefore uses player-click **Use Modern** and **Restore Offhand** prompts.
- A stale generated Forever bridge was found overwriting newly saved state during
  `/reload`. The bridge is now consumed once, and current SavedVariables win on
  subsequent reloads.
- Disconnecting the workspace from an already-spanned session exposed desktop
  content where the missing monitor had been. Companion v2.1.2 now detects this
  state and restores a bordered WoW window that fills the surviving Mainhand work
  area. Later v2.1.2 acceptance confirmed the native-window disconnect recovery,
  reconnection and exact respan; the original pending status is superseded.
- During the first v2.1.2 retest, the workspace was reconnected after Companion
  launched. Its status calculation saw both displays, but the selectors retained
  the one-display startup inventory, and manual Restore Window returned WoW to its
  stale portrait-workspace position. The selectors now refresh on Windows topology
  changes without rewriting saved device identities, and manual restore fills the
  selected or surviving Mainhand. The selected-Mainhand restore and subsequent
  exact two-monitor respan passed later in this same acceptance cycle.
- The selected Mainhand restore and subsequent exact two-monitor respan passed.
  Repeated full-range vertical camera sweeps while holding right mouse eventually
  exhausted cursor travel; releasing the button reset it. Setting
  `rawMouseEnable=1` eliminated the block in the same live session. Offhand now
  enables raw input only while its span is active and restores the prior setting
  on single-screen recovery, disable, or logout. Automated lifecycle coverage was
  added. Later live acceptance observed `OH RAW 1` and confirmed continuous RMB
  vertical camera movement; the original pending status is superseded.
- A clean cold-launch control with both displays continuously connected reproduced
  the vertical camera block with `rawMouseEnable=0`, establishing that it is a
  normal mixed-height span requirement rather than a disconnect-test artifact.
  The same control also exposed a false missing-workspace prompt during the brief
  pre-span startup interval. Recovery now waits eight seconds for a sustained
  mismatch, cancels if exact topology arrives, and hides obsolete prompts.
- Enabling the master dual-monitor mode was then proven to revert to disabled on
  `/reload`. Forever had reloaded the profile default while its normal
  SavedVariables update was unavailable. The session fallback now mirrors the
  master enabled and raw-mouse preference flags together, and updates them from
  the options UI, auto-configure, slash toggle, profile changes, and reset.
- The same client defect can affect every account or character field, not only the
  master switch. Forever now records a bounded, checksummed, data-only snapshot
  of the complete Offhand account and character state at the reload boundary. The ordinary account
  table carries the same monotonically increasing revision: an equal or newer
  standard load wins automatically, while only a stale revision activates the
  fallback. Tests cover geometry, themes, nested custom colors, Mainhand frame
  positions, active profile selection, and protected Edit Mode recovery state.

## 2026-09-23: Beta 4 display identity and live panel recovery follow-up

- Companion's stable physical display identity migration selected the landscape
  2560x1440 primary as Mainhand and generated the expected 4000x2560 topology
  beside the 1440x2560 portrait workspace. Restore Window and explicit spanning
  both passed after the one-time physical-display confirmation.
- The ordinary SavedVariables table and complete Forever fallback were both at
  revision 4 with empty `savedWorkspacePositions`, `savedMainPositions`, and
  `openWorkspacePanels`. The per-frame fallback index was also empty. Previously
  remembered panel coordinates had therefore already been cleared and were not
  recoverable; this was not a Beta 4 failure to restore an existing coordinate.
- A fresh World Map drag to the workspace wrote matching active and `W4` Forever
  fallback coordinates. First Escape opened the Game Menu without closing the
  map; second Escape closed only the Game Menu. Critical map Escape persistence
  therefore passed with a valid saved workspace record.
- The Game Menu initially appeared against the full virtual canvas and visibly
  jumped to Mainhand through void recovery. This is a confirmed presentation
  defect; the menu remained accessible and functional.
- Forever opened `EditModeManagerFrame` at approximately x=1268.8, y=1586.9,
  size 510x247.6 while Mainhand ended near y=1446. The protected HUD entered Edit
  Mode correctly, but its control window was inaccessible in the mixed-height
  void. Blizzard reports the manager as movable, unprotected and mouse-enabled,
  with its own drag handler, but its small physical intersection was not usable.
- A diagnostic player-issued anchor change moving only the manager to
  `WorldFrame` center made the controls visible. Exiting Edit Mode then completed
  cleanly: the workspace map stayed open, protected HUD placement remained stable,
  and no Offhand taint error occurred. Blizzard reset the manager to the void on
  the next Edit Mode opening.
- Source candidate detects the shown manager outside both physical display
  rectangles without mutating it. A player-click recovery prompt performs only
  the tested manager anchor change and leaves Edit Mode systems, scripts, panel
  metadata and layout attributes untouched.
- Initial live acceptance exposed two related lifecycle defects: the Accept
  callback explicitly hid a popup that Blizzard was already closing, and a map
  reopened through Blizzard could reoccupy the active `left` UI-panel slot even
  though it remained absent from `UISpecialFrames`. The callback now lets
  Blizzard complete its native close, while a saved workspace map is detached
  from the active panel slot after every native reopen.
- Final live `/reload` acceptance passed. The map reopened at its saved workspace
  position, occupied no left/center/right/doublewide UI-panel slot, survived the
  first Escape while the Game Menu opened, and survived the second Escape while
  only the Game Menu closed. Edit Mode then opened with the map intact; **Bring
  to Mainhand** exposed its control window without closing the map or producing
  a Lua error; normal Edit Mode exit and a subsequent Escape repeated the same
  correct map and Game Menu behavior.
- All 20 Lua test files, manifests, locale dictionaries, Forever taint-boundary
  checks and Companion preference tests pass after the final map-panel fix.

## 2026-09-23: Post-Beta 4 backpack, panel and chat-size candidate

- Live follow-up found that hiding the Combined Backpack invoked Offhand's drag
  completion path, which immediately showed an independent workspace panel
  again. This trapped B and the close button, while also preventing Escape from
  reaching the Game Menu. Hide no longer runs drag completion. Explicit B and
  close-button actions retain native closure. Live tracing established that
  Forever's Escape path directly calls `CloseAllBags` and then `ToggleGameMenu`,
  bypassing both `CloseAllWindows` variants. Secure post-hooks pair only those
  two calls within one event turn and defer the native B-key toggle to restore
  the workspace backpack. Because reopening the native backpack itself dismisses
  the Game Menu—and Forever's `ToggleGameMenu` post-hook runs before the menu
  reaches its final state—Offhand derives the intended result from the stable
  pre-Escape menu state and reapplies it through the verified non-toggling
  `GameMenuFrame:Show()`/`Hide()` route after the bag. Both hooks have independent
  late-load guards; no Blizzard global or protected panel-manager function is
  replaced.
- Forever can hide Character and Backpack before its first reload/logout event is
  delivered. Teardown now preserves the continuously tracked explicit open state
  rather than rebuilding it from an already-hidden UI, allowing those panels to
  reopen after `/reload` when they were open beforehand.
- The complete Forever fallback profile was previously written before that
  open-panel capture. On the next reload its stale embedded visibility table won
  over the newer field-specific CVar. The full snapshot now writes last, after
  the final open-panel table has been captured and mirrored.
- Forever also calls `CloseAllBags` during startup cleanup. Treating every such
  call as an explicit player close erased the correctly restored request before
  the delayed reopen. Generic `CloseAllBags` state syncing was removed: B remains
  tracked by `ToggleAllBags`, X by its button hook, and Escape by the paired
  `CloseAllBags`/`ToggleGameMenu` observer.
- During early reload startup, Combined Backpack mode may not create
  `ContainerFrame1`; the general compatibility heuristic then falsely reports a
  custom bag addon and skips native restoration. A saved
  `ContainerFrameCombinedBags` root is now authoritative and restores according
  to its rendered visibility rather than stale logical `IsBagOpen` state.
- Restoring any independent workspace panel now evicts it from Blizzard's active
  UI-panel slots. Map show/hide and Edit Mode exit reapply only currently shown
  workspace panels. The obsolete Character tab-toggle cycle was removed so map
  transitions cannot reclaim or briefly re-toggle the Character frame.
- Explicit Blizzard chat dimension saves now update the Forever workspace
  snapshot. Periodic Edit Mode sampling no longer overwrites that snapshot with
  a stale runtime width, and startup/Edit Mode exit reapply the saved dimensions.
- All 20 Lua test files, Companion preference tests, manifests, locale checks and
  the addon validator pass. This remains an unpublished local test candidate.
- Final live acceptance passed after the persistence and direct-Escape fixes:
  Backpack, Map and Character all reopened after `/reload`; first Escape kept all
  three open while opening the Game Menu; second Escape kept them open while
  closing only the Game Menu; and both B and the Backpack X remained functional
  explicit close controls. No Lua error was reported during this sequence.

## 2026-09-24: Retail primary-chat Edit Mode candidate

- A Retail report showed the default primary chat frame accepting an Edit Mode
  drag, then snapping upward/offscreen after save-and-exit; the channel button
  was separately stranded near screen center. Secondary chat windows retained
  their placement and the behavior persisted with ElvUI disabled.
- Source review confirmed that Retail `ChatFrame1` inherits Blizzard's
  `EditModeChatFrameSystemTemplate`. Offhand was replaying its own primary-chat
  anchor after Edit Mode and had stored the frame's top coordinate while later
  interpreting it as a bottom coordinate.
- The candidate yields position and dimensions to Blizzard whenever the Retail
  primary chat remains on Mainhand. It clears legacy Offhand Mainhand chat
  coordinates after Edit Mode exits, while still capturing an explicit
  workspace placement. Workspace moves call Blizzard's `FCF_SetButtonSide` to
  bring the native channel/menu button strip with the frame.
- Automated coverage verifies Mainhand ownership, unchanged Retail size and
  coordinates after Edit Mode exit, deliberate workspace persistence, the
  top-edge coordinate schema, and button-strip repair. All Lua tests, Companion
  preference tests, manifests, locales, and static addon validation pass.
- Reporter confirmation on a live Retail client remains pending; this build is
  suitable for beta testing and can be adjusted if the observed result differs.

## Beta 21 Leatrix Maps live-span coordinate-font candidate

- Enable Leatrix Maps coordinates and open the world map before spanning.
- Apply the span without reloading. Verify both `Player:` and `Cursor:`
  coordinates retain their normal font size immediately after the display
  settles; map size, position, border, pins, zoom and Leatrix settings must not
  change.
- Run `/offhand diag` and verify compatibility diagnostics report
  `LeatrixMaps=loaded | CoordinateFontRefresh=3`. A different count should be
  captured with the affected Leatrix version and locale before broadening the
  selector.
- Restore the window and span again, then `/reload`; verify the labels remain
  the same size in all three states and no blocked-action or Lua error appears.
- Repeat once with Leatrix Maps disabled. Offhand must not enumerate or rewrite
  any world-map font string, and diagnostics must omit the Leatrix refresh.

## Unreleased Bagnon, Leatrix ownership and equal-height world text

- The first live Forever test found two failures: non-Gamepad Escape still hid
  Bagnon's `UISpecialFrames` root, and Gamepad Settings exit produced an
  `ADDON_ACTION_FORBIDDEN` attribution to Bagnon at
  `SetPreferredGamepadInteractTarget`. The candidate no longer installs root
  `OnShow`/`OnHide` hooks or Bagnon-manager callbacks. An addon-owned observer
  discovers the lazy root, and the secure `ToggleGameMenu` post-transaction now
  pairs a directly hidden saved root without requiring a third-party-frame
  callback. Gamepad mode retains saved intent but performs no root inspection,
  reopen, reanchor or chrome write. Simulated regression passes direct Escape,
  reload opening, explicit B/X closure and strict Gamepad yielding. Live retest
  must reproduce Settings open/close and two Escape presses with fresh
  BugGrabber and `taintLog 2` evidence.
- Simulated regression proves Leatrix-owned World Map anchors and scale remain
  untouched while Offhand records workspace open intent, removes the map from
  Escape closure, evicts its active panel slot and reopens it after restoration.
  Live Forever verification must cover M/L, two Escape presses, Professions,
  Leatrix dragging, maximize/minimize, `/reload`, map pins and shift-click links.
- Simulated geometry verifies an equal-height 5120x1440 span now applies the
  world-text fine-tune multiplier. At 50%, diagnostics and
  `WorldTextScale_v2` should report `0.50`. Live combat and XP text comparison
  remains required before declaring the visual result resolved.

# Manual and single-ultrawide onboarding

- With no generated Companion topology, continue from onboarding Step 4 and
  verify that **Confirm manual Offhand layout** appears before progression.
- Cancel the confirmation and verify the guide remains on Step 4.
- Accept it after manually spanning two displays and verify that the calibration
  wizard retains orientation, Mainhand side, seam and aspect controls.
- On one 3440x1440 display, prepare a manual layout and run Auto-Configure.
  Verify that Mainhand is 2560x1440 and the remaining 880-pixel side is Offhand.
- On one 32:9/32:10 display, use Companion's explicit single-display split and
  verify Step 4 accepts the exact topology without showing manual confirmation.
# Workspace lock, Character scaling and gamepad compatibility: 2026-10-14

Automated coverage now verifies a bounded non-Forever lock-open policy for the
World Map, native/supported bags and Character window; the policy preserves
open intent through Canvas rather than rewriting user bindings. Enabling it
also enables Escape and reload persistence. Forever deliberately reports the
stronger lock as unavailable and retains native close/panel-manager ownership.

CharacterFrame uses a reversible 75–150% workspace-only scale multiplier over
the native frame scale. Moving it to Mainhand, disabling ownership, or loading
ClassicUI Forever restores/yields the native scale. Combat performs no scale
mutation. True frame resizing/reflow remains unsupported.

Controller-style Blizzard presets and ConsolePort are detected separately.
ConsolePort remains an external protected-HUD owner and is never cloned. On
Forever, native Gamepad UI exposes a player-triggered action that translates
only the active preset's UIParent-relative anchors into Mainhand. Forever makes
custom layouts unselectable while Gamepad is active, so Offhand patches the
runtime `Gamepad (Preset)` copy and rebuilds it from Blizzard's original data
after `/reload`. `Bindings.xml` also exposes a normal Blizzard binding for
toggling Offhand settings.

Forever's live native interface style is now authoritative even when Edit Mode
preset data is stale or unavailable. While native gamepad navigation is active,
Offhand does not create title-grip children inside Blizzard UIPanels, run the
broad `UIParent` popup/void re-anchor scan, or auto-select an Edit Mode layout.
Static regression coverage verifies that a gamepad-managed panel remains
non-movable and structurally unchanged and that a centered navigation overlay
retains its native anchor.

Forever live evidence on 2026-10-15 showed two remaining controller ownership
violations. `LootFrame` carried Offhand's `native_gamepad` status marker when
Blizzard's `FrameControlsManager` entered `FocusGamepad`, and the protected HUD
scanner inspected Compact Party Frame previews during Edit Mode before offering
a Repair HUD action that could only fail with `gamepad`. Native gamepad mode now
short-circuits panel discovery, drag setup, saved-position restoration and
protected-HUD recovery before any Blizzard frame is annotated or inspected.
Unprotected Edit Mode controls retain their existing read-only detection and
player-click recovery. Panel-motion diagnostics use an addon-owned weak table
instead of a field on the native frame. Automated coverage confirms that the
background controller path leaves the panel unmarked, clears stale repair state,
and never writes or activates an Offhand Edit Mode layout. Live `/reload`, Edit
Mode entry and exit, and controller focus traversal remain required.

Forever live follow-up on 2026-10-16 confirmed that disabling every control
surface recovery was too broad: `EditModeManagerFrame` and `SettingsPanel` both
opened in the mixed-height void while the protected controller HUD itself was
healthy. Gamepad mode now retains the player-click Edit Mode controls recovery.
Settings uses external opening observers plus deferred root-only centering, with
no scripts, fields, drag ownership, or persistence attached to the Blizzard
frame. Automated regression covers the controller Edit Mode prompt and action,
Mainhand Settings placement, and the absence of native-frame annotation. Live
taint and focus traversal retesting remains required.

A subsequent live test showed that clicking **Bring to Mainhand** closed the
Blizzard `StaticPopup`, after which `StaticPopupGamepad` asked
`FrameControlsManager` to restore focus to `LootFrame` and failed inside
`FocusGamepad`. Native Gamepad UI now presents that recovery action in an
addon-owned Mainhand card instead of a Blizzard `StaticPopup`. The button still
provides the required player hardware action, but showing, accepting, dismissing
and hiding the card never enter Blizzard's popup focus stack. Keyboard and mouse
mode retains the original popup. Automated coverage rejects any Gamepad recovery
path that calls `StaticPopup_Show` or `StaticPopup_Hide`; live confirmation of
the button and subsequent controller focus traversal remains required.

The next 2026-10-16 live pass showed the same native ownership boundary when
Step 2 of the setup guide opened the FancyZones link. Blizzard's
`StaticPopupGamepad` activated its binding stack during `StaticPopup_OnShow`,
which reached protected `SetPreferredGamepadInteractTarget()` under Offhand's
execution context. All Offhand dialogs now route through a shared addon-owned
card while native Gamepad UI is active. This includes setup links, manual-layout
confirmation, Companion notices, profile confirmations, optional compatibility
choices, HUD layout prompts and reload prompts. Keyboard and mouse mode retains
Blizzard `StaticPopup` presentation. Simulated coverage verifies formatted text,
copyable link text, accept/cancel callbacks, hide callbacks and callback data
without calling `StaticPopup_Show` or `StaticPopup_Hide`. Live traversal through
both Step 2 setup choices and Step 4 confirmation remains required.

Visual follow-up showed the addon-owned notification card aligned to the top of
Mainhand while ordinary setup UI was centered, and Blizzard's Gamepad HUD still
centered on the complete spanned canvas. Gamepad-safe dialogs now use Mainhand's
exact center. A later screenshot proved Forever disables every custom layout
while the native Gamepad interface is active, leaving only `Gamepad (Preset)`
selectable. An experimental runtime-preset translation then failed with
`preset-apply`; entering Edit Mode and logging out subsequently produced
Offhand-tainted secret-number and secret-boolean errors in `CompactUnitFrame`.
The preset-manager strategy is therefore rejected. Native Gamepad mode now
performs no preset table mutation and no Edit Mode manager refresh, and the HUD
creation action is disabled. Simulated taint-boundary coverage enforces that
restriction. A fresh `/reload`, Edit Mode entry, and logout remain required to
confirm the live session is clean.

The 2026-10-17 retest occurred after Blizzard's October 15 client update, whose
notes state that applying Edit Mode layouts while Gamepad UI is enabled and the
invisible Gamepad bar after selecting a custom layout were fixed. The temporary
disabled action was therefore too restrictive for the current build. Offhand
now leaves the preset-manager prohibition intact but restores the player-clicked
custom-layout workflow: copy the live Gamepad preset, transform only the copy,
save and activate it through `C_EditMode`, then require a manual `/reload`.
Regression coverage must prove the preset table is byte-for-byte unchanged,
the stale Classic-source record is ignored, the custom row is reused rather
than duplicated, and no manager refresh method appears in the implementation.
Live acceptance requires creation, visible Mainhand placement after `/reload`,
Edit Mode entry and exit, logout, and fresh BugGrabber evidence.

A further live screenshot confirmed that the Start-button radial Main Menu is
not an Edit Mode system and remained centered on the full 4000x2560 canvas.
Offhand now locates that native surface from Blizzard's localized `Main Menu`
and radial-option labels, accepts only a bounded and unprotected common visual
container, and centers only its root on Mainhand from an addon-owned observer.
No scripts, hooks, fields, or input handlers are installed on the native menu
tree. Simulated coverage verifies protected-frame rejection, Mainhand centering,
native-anchor restoration, diagnostics, and isolated controller ownership.
Live Start-menu placement, controller navigation, combat, close/reopen, and
taint validation remain required.

The 2026-10-17 follow-up visually confirmed that the Main Menu and Ping radial
surfaces are centered on Mainhand, while Character, Map and Quest Log,
Spellbook, Professions, and Chat Channels still use Blizzard's fixed full-canvas
panel anchors, usually placing them on the Offhand display. Native Gamepad mode
correctly blocks Offhand's generic title-grip injection, so mouse dragging those
windows is intentionally unavailable. A new external adapter now checks only a
fixed list of radial destination roots every 0.2 seconds and centers a shown,
unprotected root on Mainhand. It adds no fields, scripts, hooks, children,
visibility changes, Escape behavior, or persistence to those Blizzard trees.
It skips combat and protected roots, excludes `LootFrame`, and restores the
captured native anchor only if the frame still has Offhand's exact applied
anchor. Simulated coverage verifies centering, protected-frame rejection,
LootFrame exclusion, native-tree structural isolation, diagnostics, and
reversible ownership. Live retesting remains required for every radial entry,
close and reopen, combat transitions, `/reload`, and current taint logs.

Dragging the Loot Window preview in Forever Edit Mode produced a native
`LootFrame:FocusGamepad` nil-call error. The stack contains only Blizzard's
`LootFrame`, `FrameControlsManager`, and callback registry, and the current
Offhand Gamepad paths neither annotate nor move `LootFrame`. The new destination
adapter also excludes it explicitly. This is therefore recorded as a likely
Forever client defect rather than patched by replacing or hooking the protected
focus method. Retest the same drag with Offhand disabled to confirm the client
baseline, then include that result in any Blizzard report.

The 2026-10-18 live follow-up confirmed Spellbook, Professions, the generated
Gamepad HUD, and the Start-button radial Main Menu on Mainhand. Newly reachable
radial destinations exposed the remaining fixed roots. `LegacySystemFrame`,
`FriendsFrame`, `CommunitiesFrame`, and `CollectionsJournal` are now in the
explicit adapter registry. Each may use the narrow protected position-only
exception outside combat. Every explicit root receives the independent
persistent `Drag to move` handle, including protected roots, because the handle
remains a `UIParent` sibling and commits only the already permitted root-anchor
operation after a hardware drag. The
radial locator also primes a hidden menu at startup and after Gamepad
load-on-demand completion to avoid its first-show native-anchor flash. Finally,
default generated HUD layouts inset the Minimap 64 units below Mainhand's top;
Blizzard's system-relative BuffFrame anchor follows it down without a separate
rewrite. Live acceptance requires opening all four destinations, checking which
ones expose handles, confirming saved offsets across `/reload`, verifying the
lower Minimap/Buff row after refreshing the Mainhand HUD layout, and checking a
fresh taint log.

Automated status: all 32 Lua test files and the shared multi-TOC addon validator
pass. Live acceptance remains required for:

- Retail/Classic M, C and B toggles, Escape, native X buttons, combat and reload
  with each lock category enabled separately and together.
- Character tabs, equipment model, currencies and late-loaded panes at 75%,
  100%, 125% and 150%, including a cross-seam move back to Mainhand.
- Forever Character scaling with status text visible, followed by map-pin,
  CompactUnitFrame, TextStatusBar and Cooldown Viewer taint regression checks.
- Forever native gamepad and ConsolePort flows with Xbox- and PlayStation-style
  controllers: wizard completion, settings binding, cursor traversal across the
  span, combat, disconnect/reconnect, `/reload` and cold launch.

## Retail 12.1.5 live follow-up: 2026-10-14

- Pet-battle Mainhand confinement passed the reported live retest.
- Character workspace scaling passed when changed through the step controls.
  Dragging the slider could leave the frame at the previous sampled value until
  a step button was clicked. The slider now commits its final displayed value
  on mouse release; automated regression passes and live confirmation remains.
- Workspace locks reopened closed Map, Character and bag windows, but timing
  varied from immediate to roughly three seconds and `/reload` crashed the
  client. Active lock enforcement was repeatedly entering the full startup
  restoration path while its delayed panel and bag callbacks were still
  settling, creating overlapping callbacks and a credible crash path. It now
  remains suspended through login or reload, begins after the
  normal startup restoration window, uses short active-lock delays, and
  deduplicates the bag callback. Automated reload-boundary and settlement-mode
  regressions pass; Retail and Classic live confirmation remains required.

## Companion-independent Forever persistence audit: 2026-10-14

- The generated recovery bridge is not yet proven unnecessary. The original
  defect was reproduced live on Forever 1.60.1: the client wrote `Offhand.lua`
  but loaded stale/default state during a later transition. The current local
  client is 1.60.1.70374, so the workaround now requires fresh validation rather
  than an assumption that all 1.60.1 builds behave alike.
- The installed addon currently contains the packaged `ForeverState.lua`
  placeholder, not a generated Companion snapshot. The newest account
  `Offhand.lua` contains persistence revision 2463. This proves recent normal
  SavedVariables writing, but does not prove that a subsequent cold client
  launch loads that revision.
- `/offhand diag` now reports the startup persistence source, bridge state,
  session-fallback result, disk revision, and active revision. Simulated coverage
  distinguishes normal SavedVariables, a fresh Companion bridge, a stale normal
  load repaired from the in-client fallback, and an equal-revision normal load.
- User guidance now treats manual spanning as a first-class path and explicitly
  says the Companion may be exited after applying a span. The bridge is described
  as a compatibility fallback while current Forever builds are revalidated.
- Retirement remains blocked on repeated `/reload`, relog, cold-launch,
  character, and preferably account coverage with the Companion fully exited.
  The exact matrix and removal boundary are recorded in
  `docs/COMPANION-INDEPENDENCE.md`.

## Window Setup onboarding QA: 2026-10-15

1. Run `/offhand guide` and confirm Step 2 offers **Use FancyZones**, **Use
   Companion**, and **Configure Manually** in that order.
2. Select FancyZones. Confirm the popup exposes the official Microsoft
   PowerToys Store link and returns to Step 2 when closed.
3. Snap WoW into the saved cross-monitor zone, continue to Step 4, and confirm
   **Remember Window** stores the current canvas before advancing.
4. Fully exit and relaunch WoW. Reapply the zone if Windows does not do so, then
   confirm `/offhand diag` reports `Source=FancyZones` and a remembered-canvas
   `MATCH` or `CLOSE` state without a Companion handoff warning.
5. Launch WoW at a materially different ordinary-window size. Confirm Offhand
   rejects the remembered canvas, uses safe single-screen geometry, and keeps
   the remembered record intact.
6. Reopen Window Setup while exact Companion topology is active. Confirm the
   neutral setup action remains available and switching methods is explicit.

### Existing-user upgrade recovery

- Live `/reload` from an already configured manual/FancyZones span exposed the
  safe fallback before any remembered canvas existed. The saved profile was
  retained, but the full combined window temporarily became the game viewport
  and appeared zoomed.
- Configured users with no exact topology and no remembered canvas now receive
  a one-time session prompt. **Remember Current Window** records the current
  preview canvas and immediately reapplies the existing profile. **Not Now**
  keeps safe single-screen geometry.
- Regression coverage also verifies that popup, settings, and slash-command
  remember actions preserve all Lua return values and reapply successfully.

## Dialogue UI reward tooltip and frame-size QA: 2026-10-19

- Automated status: the targeted regression covers narrow discovery and
  physical-game bounds handling for Dialogue UI's anonymous custom reward
  tooltip. It also verifies that frame-size changes retain the physical-height
  correction and complete the quest root at Dialogue UI's own `frameHeight`
  instead of an intermediate Unfold animation height.
- Live test: With **Use Blizzard Tooltips** disabled, hover each quest reward,
  hold and release Shift, and confirm the custom comparison tooltip remains
  fully inside the game view. Change Frame Size from Large to Medium and back
  to Large while the quest is open; confirm the original parchment dimensions
  return without `/reload`.

## Forever controller-only UI unfocus QA: 2026-10-19

- Forever's Gamepad addon already owns `TOGGLEUIFOCUS`; the native action calls
  `GamepadMode.FrameControlsManager:ToggleUIFocus()` and is also used by the
  World Map. Offhand now exposes a visible player binding that delegates only
  to that action during the assigned hardware event.
- Assign **Offhand: Toggle gameplay and window focus** to an
  unused controller button or chord. Move a supported panel to Offhand, interact
  with it, then press the binding. Confirm gameplay control resumes and the
  panel remains visible. Repeat after interacting with the panel again.
- Repeat with Map, Character, Social, Collections, Communities, bags and another
  supported ordinary panel. Record any panel that closes, because Blizzard
  panels marked `dismissOnUnfocus` intentionally close in the native transition
  and cannot be described as pinned.
- Exercise the assigned action before combat, during combat and after combat.
  Inspect fresh BugGrabber and taint-log evidence after protected HUD, party
  frame, Character status-bar and Loot Window actions. Static tests establish
  delegation only, not protected-action safety in the live client.

### 2026-10-20 follow-up

- The first settings shortcut incorrectly opened keyboard Keybindings. It now
  opens **Gamepad (Alpha)**. Enter Controller Configuration there and assign
  Offhand's **Toggle gameplay and window focus** action.
- The supplied Forever binding screen rendered `HEADER_OFFHAND` literally.
  Source now initializes both header globals used across supported clients.
- Gamepad Back and keyboard Escape remain native dismissal actions. Offhand
  intentionally does not intercept them or reopen protected windows afterward.
  Validate the assigned focus action as the no-mouse unfocus path instead.
- Bagnon and Baganator must not show an Offhand mover on the borrowed native
  bag root. Social must show one mover for the actual visible Friends root,
  including the alternate Forever root names covered by the adapter.
- Dragging the Loot Window preview again failed in Blizzard
  `LootFrame:FocusGamepad()` while `LootFrame.isInEditMode` was true. The stack
  contains no Offhand function, and LootFrame remains excluded from Offhand's
  destination registry and mover creation. Reproduce the same Edit Mode drag
  once with Offhand disabled before filing it as a Forever client defect.

### Professions, Social and Options follow-up

- Live SavedVariables identified the movable Professions root as
  `ProfessionsFrame`, not the previously whitelisted `ProfessionsBookFrame`.
  Automated coverage now uses the current root and verifies load-on-demand
  reopening at its saved Offhand position. The preload path preserves its open
  marker while hidden, installs anchor repair before the first visible pass,
  and performs no native hide/show eviction or half-second polling.
- Social displacement was broader than the Communities toggle. Any Blizzard
  panel using the shared left slot could push an open, unsaved Mainhand Social
  frame into Offhand. The initial `ShowUIPanel` observer and its bounded timers
  did not change the live behavior because Blizzard could recalculate the whole
  panel stack after those observations. Current source repairs known Social and
  Communities roots at the authoritative `UpdateUIPanelPositions` completion
  point. A root `SetPoint` observer queues one next-frame fallback for later
  native layout continuations. The next live `/fstack` capture established that
  the visible Forever root is `SocialUIFrame`, not the previously inferred
  `FriendsListFrame`. Current source includes that confirmed root in ordinary
  drag discovery, position-only safety, Social repair, and Gamepad alias
  resolution. Its valid Mainhand position is remembered for the session and
  restored after a close-time Collections layout displacement. Automated
  coverage now drives the confirmed root through both the native layout
  completion hook and the later direct-anchor fallback. A live follow-up
  confirmed the correct root and stopped the cross-monitor displacement, but
  exposed visible corrective movement and a World Map regression. Current
  source preserves the first stable Mainhand coordinate, repairs direct root
  anchor changes synchronously, skips unchanged anchors, and restores saved
  workspace peers from both open and close layout completion. The 2026-10-20
  live pass confirmed that Social remains isolated from these panel movements.
- Bagnon restoration is deferred while Settings remains visible. Its saved
  Offhand snapshot is retained without reopening or playing the bag cue, then
  restored once after the native Settings close transaction.
- Auction House lifecycle and replacement-bag mover exclusion passed live and
  remain closed. Live acceptance is still required for the three changes above
  in both keyboard/mouse and native Gamepad modes.
- The first common panel-open repair covered only Social and Communities. Live
  testing showed the same shared-slot reflow pulling an already-visible Offhand
  World Map down to the top-left anchor whenever another panel opened. The
  observer now restores all saved visible peers, excludes the panel currently
  opening, and skips replacement-bag capture inside that temporary transaction.
  Automated coverage displaces both Social and World Map before opening an
  unrelated left-slot panel and verifies both saved positions are restored.
- A later live pass confirmed Social isolation but showed that Forever can
  queue a second-generation World Map layout after the immediate and 0.10
  second repairs have completed. Panel open and close transactions now start
  the map's existing addon-owned settlement controller in forced transaction
  mode. Four chained, generation-scoped passes span the nested timer work and
  stop after 0.60 seconds. Each pass compares physical placement first, so an
  unchanged map receives no redundant anchor write. Automated coverage now
  reproduces the nested timer sequence. The 2026-10-20 live pass confirmed the
  World Map remains at its saved Offhand position while other panels open and
  close.

## Forever Gamepad status bars and focus assignment: 2026-10-22

- Candidate on `addon/develop`, Beta 21 working source. Live acceptance pending.
- The reported generated Gamepad layout placed XP and the second status bar
  off-center or partly below Mainhand. Gamepad status entries now use explicit
  Mainhand bottom-center anchors, with a 12-unit bottom inset and a separate
  secondary row. Keyboard status alignment remains unchanged. Only default
  source entries are refined; custom source placements are retained. Existing
  generated layouts change only when the player refreshes the generated HUD.
- The Gamepad settings page has no reported Controller Configuration entry.
  The Offhand focus control now displays Blizzard's native `TOGGLEUIFOCUS`
  binding using its `GamepadModeInGameCore` context and offers an addon-owned
  assignment dialog. Conflicts require a second matching press or Accept;
  Escape cancels capture and combat entry releases it. The selected binding is
  saved to the player's current account/character binding set. It executes
  Blizzard's action directly rather than the old Offhand `RunBinding` delegate.
- Reference source inspected: `Blizzard_Gamepad/Bindings.xml`,
  `Blizzard_Settings_Shared/Blizzard_Keybindings.lua`, and
  `Blizzard_GamepadSharedUtility/FrameControlsManager.lua` on the
  `forever` branch of <https://github.com/Gethe/wow-ui-source>.
- This is a usable focus-assignment candidate, not a fix for native B/Escape
  dismissal. Those routes still close native panels. The native focus toggle
  can also dismiss a frame marked `dismissOnUnfocus`. No focus-manager state,
  native close handler, or panel visibility was patched to mask that behavior.
- Live QA: Reload, refresh the generated Gamepad Mainhand HUD using its creation
  action, then confirm both status bars are centered and fully visible. Confirm
  the displayed native focus binding, assign an unused button, verify conflict
  cancellation and confirmation, then reload and check persistence. With Map,
  Character, Social and bags on Offhand, use that focus binding to return to
  gameplay and record which panels remain visible. Compare B and Escape
  separately. Capture fresh taint/error evidence for OH-FOR-009; a mock pass
  does not prove protected-action safety or window retention.

### Gamepad Merchant placement follow-up: 2026-10-22

- Live report: The merchant opened at the spanned UIParent top-left inside
  Offhand. The existing Gamepad destination list covered Quest and Gossip but
  omitted `MerchantFrame`. It now includes the shown Merchant root through the
  same external geometry observer. Native interaction, visibility, focus,
  purchase/buyback handlers and scripts remain under Blizzard ownership.
- No protected-frame exception was added. A protected or forbidden Merchant
  root still fails closed. A hidden Merchant is never opened from saved offsets.
- Simulated coverage verifies Mainhand centering, no repeated anchor write,
  combat deferral, unchanged native scripts, mover hiding on close, saved-offset
  restoration after a native reopening, keyboard-mode anchor restoration, and
  refusal to move a protected Merchant root.
- Source review: Both Mainline and Vanilla `MerchantFrame.xml` on the `forever`
  branch of <https://github.com/Gethe/wow-ui-source> declare a standard
  `ButtonFrameTemplate` Merchant root. This is supporting source evidence,
  not a live protection or taint-safety result.
- Next live check: After reload, reopen a vendor in Gamepad mode and confirm
  Mainhand placement. Close and reopen it, move it deliberately if desired,
  then check the position and fresh Lua/taint evidence. Normal merchant item
  actions also need live safety verification. No client interaction or purchase
  was automated for this change.
- Other interaction roots absent from the destination list include Bank, Mail,
  Trade and Class Trainer. They remain audit candidates, not confirmed defects;
  no blanket protected allowlist or global panel scan was added.

### Loot Edit Mode focus failure, detailed locals: 2026-10-22

Tracked as OH-FOR-011. The fresh report identifies SmartNavigation's last button
as `LootFrame.Selection`, an Edit Mode overlay. Native `FocusGamepad()` assumes
its parent is a loot row and calls `GetSlotIndex()`; that parent is actually
`LootFrame`, which has no such method. The native source line 376 matches the
report. Offhand remains excluded from Loot destination placement. No runtime
patch or client action was performed. Repeat the same preview move after a
reload with Offhand disabled to isolate whether Offhand is required.

### Contextual B/Escape retention and Gamepad reticle: 2026-10-22

- Revised Beta 21 working candidate on `addon/develop`. LootFrame investigation
  is deferred at the player's request; its runtime code remains unchanged.
- The white dot is native `GamepadReticle`. Its `Recenter` uses UIParent's
  horizontal center and `GetCursorCenterPosition` for full-canvas height. The
  existing external Gamepad observer now positions its unprotected root at
  physical Mainhand center with effective-scale conversion. It receives no
  mover, script, visibility or targeting API changes. Combat defers geometry;
  keyboard mode/disable restores only an anchor still owned by this adapter.
- OH-FOR-010 now has a contextual B override and a native Escape-handler
  candidate. B dispatches straight to `TOGGLEUIFOCUS` when a visible Offhand
  destination has focus. Escape opens native Game Menu while bypassing generic
  window cleanup and the menu's own center-slot close-all transaction. Only the
  hidden menu's panel-layout attributes are prepared through a restricted
  handler; native ShowUIPanel and focus registration still execute. The native
  menu metadata is restored after ownership ends and the menu closes. No panel
  is hidden/reopened, and native focus state is read without mutation.
- Simulation: All 36 active Lua suites and six-manifest Lua 5.1 validation pass.
  New coverage models both global cleanup and center-slot closure, verifies
  retained visible peers, singleton registration, contextual B release, native
  menu navigation yielding, combat-state override clearing, cinematic yielding,
  visible-menu deferral and external menu ownership. Reticle regression checks
  Mainhand center, effective scale, unchanged anchors, restoration, combat and
  protected-root refusal. These checks do not prove native taint safety.
- Source inspected on the `forever` branch of
  <https://github.com/Gethe/wow-ui-source>: GamepadReticle.lua,
  Blizzard_GameMenuEsc.lua, UIParentPanelManager.lua, GameMenuFrame.lua,
  FrameControlsManager.lua and SmartNavigation.lua.
- Live QA after reload: Wait for the interface to settle. Put Map, Character,
  Social and a bag on Offhand. Focus an Offhand panel and press B: peers should
  remain visible and gameplay control should return. Press Escape from both
  panel focus and gameplay: Game Menu should open without closing peers, and
  native menu navigation/closing should work. Repeat explicit panel closes,
  Mainhand-focused Back and gameplay B. Check the dot at Mainhand center, then
  repeat mode transition and reload. Capture fresh `/offhand diag`, BugGrabber
  and taint evidence immediately on failure, especially OH-FOR-009. Combat uses
  native dismissal and is not covered by the preservation claim.
- Diagnostics now include `GamepadReticle` and `GamepadBack` policy state.

### Reporter acceptance and native Gamepad XP generation: 2026-10-22

- The reporter accepted the B/Escape and reticle candidate as a solid fix.
  Preserve those paths. No complete per-panel matrix or fresh taint trace was
  supplied with that acceptance, so it does not close OH-FOR-009 or establish
  combat safety. The remaining reported defect is XP placement when creating
  the Gamepad HUD layout.
- Exact generation gap: The native Gamepad preset uses the separate
  `GamepadMainActionBar` system. It has no keyboard `ActionBar/MainBar` entry.
  The common refinement routine returned before processing the status bars,
  whose native anchors are relative to `StatusTrackingBarManager`, so generic
  UIParent translation also skipped them. The previous test fixture retained a
  keyboard main-bar entry and did not characterize this native preset shape.
- Gamepad status refinement now runs before keyboard-bar prerequisites. It
  updates XP and the secondary status row in the generated layout payload,
  independently of the keyboard action bar. Native presets and customized
  source entries remain unchanged; no runtime status-frame hooks were added.
- A regression using the native separate action system and manager-relative
  status anchors failed before this change and passes afterward. Live check:
  reload, close Edit Mode, click Create Mainhand HUD Layout, then confirm XP
  is centered on Mainhand and fully above the bottom edge without manual drag.

### Protected casting regression and Escape rollback: 2026-10-22

The later Game Menu report supersedes the Escape safety claim in the earlier
acceptance. Both Gamepad radial entry and standard UI reached protected
`SpellStopCasting` under Offhand attribution before the addon-priority callback.
The callback registration inserted and sorted the native shared handler table
even while Gamepad mode was inactive. That source hazard is removed entirely;
the independent-menu layout adapter and unused callback are also removed.
Contextual B, the reticle and XP generation remain. Escape reverts to native
window-closing behavior. New regression guards reject registration, native menu
invocation and menu metadata writes in both modes while preserving B coverage.
Reload is required to discard the previous session's handler-list taint. Retest
fresh radial-menu and keyboard-Escape Game Menu entry for OH-FOR-012. A safe
Escape-retention replacement remains pending; do not re-register a callback as
a workaround or infer native taint safety from the earlier simulated pass.

### Automatic Edit Mode control rescue: 2026-10-22

- The reporter requested smoother recovery of the Edit Mode control window
  that opens in the mixed-height void. The settled recovery candidate now uses
  the existing centering helper automatically for a shown, unreachable,
  unprotected manager or element-settings dialog. Its existing 0.15-second
  settlement and generation invalidation are retained. No native-frame hooks,
  Escape callbacks, panel metadata or protected HUD anchors are added/changed.
- `autoRecoverEditModeControls` defaults to true and merges through existing
  profile defaults. Recovery & Preview exposes Automatically recover off-screen
  Edit Mode controls. Turning it off retains the existing manual prompt.
  Reachable placements on either physical display remain untouched.
- Coverage exercises the Gamepad manager and separate settings dialog, delayed
  application, no repeated anchor write/prompt, protected-root refusal, combat
  deferral and opt-out. The historical manual-recovery matrix remains covered.
- Live gate: Reload and open Edit Mode in the exact span; the control window
  should move into Mainhand after native positioning settles, without a recovery
  popup. Select a HUD element and verify its settings dialog too. Manually move
  controls within a physical display and confirm they stay placed. Disable the
  preference and verify Bring to Mainhand is offered for unreachable controls.
  Check native dragging, save/cancel, controller focus and fresh Lua/taint
  evidence. Simulated geometry success does not establish native focus safety.
- Reporter follow-up: Automatic Edit Mode control rescue was accepted live
  on 2026-10-22. This confirms the reported recovery workflow; the broader
  focus, combat and topology matrix remains separate.

## OpenMap geometry ownership candidate (2026-10-22)

- Inspect OH-FOR-013 for the supplied versions and confirmed competing writers.
- Automated: OpenMap alone and with Leatrix must report WorldMapOwner=OpenMap.
  Configure, drag-stop and restore must preserve external anchor/scale and
  dormant Offhand coordinates. Forever must retire its map handle while keeping
  workspace open intent and reopening without applying dormant coordinates.
  New Forever regression fails against committed Discord baseline a484baf.
- Live setup: OpenMap 0.7.2-beta, with Leatrix 1.60.25 Unlock map frame and
  Scale the map disabled, Use simple map frame disabled, then reload. Also test
  OpenMap alone. Do not delete SavedVariables or reset existing map settings.
- In the actual span, use OpenMap's title handle to move the windowed map to
  Offhand. Verify native map toggle, another UIPanel opening, maximize/minimize,
  reload and normal logout/cold login preserve the placement. Test span after
  login and restore to a single screen separately, including equal-height
  displays and Offhand on either side. Capture diagnostics at any position jump.
- Repeat map-pin hover, shift-click links and combat transitions with fresh
  BugGrabber/taint evidence. Automated tests do not establish runtime taint safety.
- Candidate source only: no installed addon files changed and no new ZIP built.

## Support diagnostic cleanup (2026-10-22)

- `/offhand diag` (also metrics/info) keeps version/pairing, operating state,
  display geometry, Forever persistence and Edit Mode, plus map ownership even
  without another loaded-addon marker. A healthy READY topology omits the
  repeated dimensions; mismatched topology and active manual canvases retain
  their recovery evidence. Installed/invalid user media gets a short status.
- `/offhand diag full` retains feature-level world-text, speech-bubble, loot,
  pet-battle, group/protected HUD, panel-controller, Gamepad and Dialogue UI
  evidence. These getters are not called by the default command. World-text
  collection uses a focused getter rather than enumerating nameplates and
  reading unrelated renderer CVars through the performance collector.
- Automated coverage: real slash dispatch, aliases, full opt-in, skipped
  collectors, OpenMap-only output, healthy/mismatched topology, manual geometry
  and invalid installed media. Focused world-text fields match the previous
  collector without sampling framerate or nameplates. All 37 Lua suites and
  six-manifest Lua/XML validation pass.
- Deployment: updated Init, Canvas, Mainhand, Viewport and package documentation
  in the Forever Beta Offhand directory, with a backup and per-file hashes.
  Existing generated bridge files and SavedVariables remain unchanged. Live
  chat readability and copy/paste checks remain pending after `/reload`.
