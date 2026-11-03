# Consolidated custom-region review candidate

3 November 2026. This is an unpublished review build combining the preserved
addon changes with Prototype 6 Companion. It is not a public release or a claim
that the full supported-client release matrix has passed.

## Source and artifact identity

- Integrated addon source: `28982704bdd4599f0b2ecabb0e7db288f05f811d` on
  `codex/custom-workspace-regions`.
- Preserved addon fixes from `09c6f31`, `bba3088` and `3826dfe` are merged.
  All runtime Core/UI/Locales/TOC files match the primary branch at `3826dfe`
  ignoring whitespace. The primary checkout was left unchanged.
- Merge review removed a duplicated Retail CloseWindows/diagnostics block in
  CanvasPanelLifecycle. Website region guidance and the separate oversized
  options-tooltip issue were preserved.
- Addon package: 76 clean runtime files, TOC version `2.1.2-beta.24`.
  `Offhand-addon-review.zip` SHA-256:
  `8F8800ED606FAFA54C95396810F4859ECA27DB2220CC60DBF9B726ED084D0495`.
- Companion: exact Prototype 6, `2.1.3-beta.1`, file version `2.1.3.2`, protocol 1.
  Build source `4a27ed0e9b5418d7830e84334a812c16838b71f7`.
  EXE SHA-256:
  `634EFED06267E746EF968B0849F2ABF1F4EA518B5B01E64111B54F242ABEA274`.
  Its build-time candidate record remains immutable. Later acceptance is here.
- Source packages contain inert generated-state placeholders. Test preferences,
  installed generated bridges, account paths, SavedVariables and screenshots
  remain in ignored private evidence, outside the review package.
- A separate unsigned validation MSIX embeds the exact P6 executable, identity
  `N4UX.OffhandCompanion.Validation`, package version `1.0.0.0`. Structural checks
  passed for entry boundaries, identity, capabilities, startup policy and embedded
  EXE parity. SHA-256:
  `76D50B9D4044709CCC2EE82D7D1F778E4555430D85C90B7F06738025113C4DC8`.
  It was neither installed nor submitted and is not a production Store update.

## Automated evidence

All 83 Lua suites passed after reconciliation, including the final duplicate-code
review. Six TOCs, 65 runtime references, 64 Lua files and one XML file passed path
and Lua 5.1 syntax validation. Companion preferences/dashboard/policy checks and
the production C# to Lua partial-topology fixtures passed, including 64 topology
acceptance/rejection cases and 32 persistence round trips.

Companion runtime source and P6 executable bytes did not change. The previous
25 taskbar assertions and 3,057 span/Restore transaction assertions per x64/x86
architecture remain attached to those same bytes and their original evidence.
They were not relabeled as fresh live-client or combat tests.

Final preparation review found the candidate builder still checking file version
`2.1.3.1`. Its guard now accepts current `2.1.3.2`, its custom-region README
describes the fullscreen notification, and the preferences suite checks that
version agreement. A separate fresh build passed compilation, runtime ZIP parity
and frozen public-artifact preservation. The full preferences/dashboard suite
passed again. That build is tool validation only; it does not replace the exact
live-tested P6 bytes in this packet or inherit their live acceptance.

## Exact package live checks

Both clients temporarily received the clean 76-file addon, hash-verified against
the staged review manifest before launch. The complete original installed addon
folders and current user state were preserved first.

The physical setup was a 2560x1440 game display at `(0,0)` and a 1440x2560
portrait display at `(-1440,-1114)`, both at 100% Windows scaling. The saved
workspace was monitor-relative `(9,1108) 1418x1440`, desktop
`(-1431,-6) 1418x1440`. The existing 12-pixel bottom margin was retained.

| Check | Retail 12.1.5.70688 | Anniversary 2.5.6.70577 |
| --- | --- | --- |
| Context | Idle level-one character, existing OpenMap and other addons retained | Idle level-one character; Offhand, BugGrabber and BugSack temporarily enabled only for that character |
| Native custom span | `(-1431,-6) 3991x1446`, style `140B0000`, complex clipping type 3 | Same exact native geometry/style/clipping |
| Fresh runtime after reload | `READY`, viewport matches; WorldFrame approximately `(1431,0) 2560x1440`, workspace `(0,6) 1418x1440` | Same matching physical viewport and workspace |
| Taskbar samples | `(-722,1416)` and `(1280,1415)` hit actual WoW with WoW foreground and Companion foreground | Both hit actual WoW with WoW foreground and Companion foreground |
| Native Restore | Exact original `(0,215) 2560x961`, style `14CF0000`, no clipping | Exact original `(215,0) 2130x1392`, style `14CF0000`, no clipping |
| Taskbars after Restore | Both points returned to Shell taskbar windows | Both points returned to Shell taskbar windows |
| Fresh ordinary-window addon state | `isSpanned=false`, `MISMATCH`, full client WorldFrame approximately `2544x922`, viewport matches | Stale exact bridge rejected as `MISMATCH`; existing confirmed `2114x1353` manual canvas matched under AUTO, so its manual split remained active |
| Error records | BugGrabber sessions 352 to 357; all 13 historical records deeply unchanged | Sessions 550 to 554; all 100 historical records deeply unchanged |

The Anniversary fallback is the existing AUTO preference contract, not acceptance
of stale Companion topology. Its matching ordinary-size manual calibration was
already present before this run. Native Restore does not erase remembered manual
canvases. A full-screen ordinary addon fallback is therefore not claimed for that
configuration. The briefly stale layout immediately after the resize and before
reload is not accepted as correct live geometry.

Retail's normal setup method returned success for `Offhand (2)`, 47 systems,
active. A subsequent independently captured layout snapshot showed active combined
ID 6. All four pre-existing native rows compared deeply unchanged before/after.
This accepts reuse of an existing compatible owned layout and its visible game
HUD fit. It does **not** establish fresh row creation or native layout migration.
The earlier interpretation that a fifth row had been created was disproved by
the saved-state comparison; no layout row needed removal.

Character, OpenMap and combined bags reopened in the Retail workspace. The user
reported the previously requested Character-panel drag test passed manually and
asked that it be skipped. Record this as user-reported acceptance on their setup;
no agent repeat or new exact-package drag evidence is claimed.

## Cleanup and remaining gates

Both WoW clients and both Companion sessions exited normally. The Retail run
restored 18 state files and all 78 original addon files. Anniversary restored
20 file states, including two originally absent character files, and all 87
original addon files. All original hashes and addon file counts were verified.
New test files were retained privately. Battle.net remained open. No layout row
was deleted, no global taskbar preference changed, and nothing was published.

Still pending: hands-on combat and protected descendant actions; physical DPI
changes/disconnect/reconnect; fresh native HUD-row creation; exact P6 Classic Era
and Forever acceptance; physical 5120-wide and three-monitor hardware; applied
span minimize/maximize, Explorer restart and auto-hide variants; wider panel and
Store/Wine matrices. Forever remains scheduled by the user's previously chosen
availability milestone, not inferred from launcher advertising. The separate
oversized game-options tooltip issue remains open.

Shared knowledge README/skill/status and appropriate queries were consulted.
The broad region/native query returned authored protected-UI guidance, not exact
implementation evidence. Retail Edit Mode declarations are pinned to 70575 at
`15881d522c44cd106d3d8660106ec9f9d2f44167`; live Retail was 70688. The Anniversary
EnableAddOn declaration matches 70577 at
`68e0a2ec559d9761dfc4e7f864c3944f9d758a49`. Declarations, mocked checks, native
fixtures and the bounded observations above remain distinct. No combat/taint
safety follows from unchanged captured errors.

Private evidence: `dist/live-qa-consolidated-retail-20261103-080113`,
`dist/live-qa-consolidated-anniversary-*`, source-reconciliation inventories,
fresh diagnostic snapshots, native point/bounds readbacks and cleanup manifests.
