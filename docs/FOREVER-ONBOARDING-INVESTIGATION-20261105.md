# Forever launch onboarding investigation

Beta 26 has a reproducible first-launch setup defect. A new profile starts with
`enabled = false`, but automatic entry guidance requires `enabled = true`.
Consequently, installation can succeed without opening the welcome guide. The
same condition suppresses a saved placement-step resume before calibration has
enabled Offhand. This is a product defect that plausibly explains the reporter's
failure to discover setup. The screenshots do not establish that it was the only
failure on their machine.

Investigation date: 2026-11-05. Scope: the five supplied screenshots, beta 26
source and archived package, setup/entry tests and public installation guidance.
The initial investigation left runtime code unchanged. A subsequent source
candidate is described below; the pending Gamepad changes remain separate.

## First launch source candidate

For distribution now, use the
[combined Forever Discord candidate](FOREVER-DISCORD-TEST-20261105.md). It includes
both onboarding and the pending controller fixes.

The later character-aware test.2 candidate supersedes test.1 for onboarding
testing. See [Character HUD setup candidate](CHARACTER-SETUP-20261105.md) for its
behavior, package checksum and current validation. The following test.1 evidence
is retained as the first-launch checkpoint.

The follow-up preserves the inactive viewport default and removes its gate from
automatic preparation. Explicit disable now records a separate per-profile
`automaticSetupSuppressed` boolean. Reopening the guide or calibration clears
that opt-out without enabling the viewport. Ordinary SavedVariables and
Forever's versioned display-flag fallback retain the choice. The new reader
accepts both V1 and V2 fallback records; V1 has no explicit setup-intent field.
An older incomplete disabled profile without that field may receive setup
guidance, since the old format cannot distinguish user intent from defaults.
Completed accounts remain quiet.

Both minimap menu implementations now route incomplete setups through
preparation. The calibration handoff and completion message explain moving the
first World Map panel onto the workspace. This additional instruction is
translated into French; the pre-existing English fallback described below is
not a completed French translation of the entire guide.

Validation at the test.1 checkpoint: all 86 Lua 5.1 suites pass, including two new entry-path
suites. All six manifests pass path, XML and Lua 5.1 syntax validation. These
checks cover fresh defaults, an inactive viewport, placement resume, explicit
disable/re-entry, standard and Forever session persistence, cinematic deferral
and both minimap menu APIs. Live visual, native display and cold-launch
acceptance on the actual Forever release client remain pending.

The isolated candidate is
`dist/Offhand-v2.1.2-beta.26-onboarding.test1.zip`, SHA256
`CE69BDB15014B992417A4BC12A5D474B0F4A306848950C3993E2001A368491F6`.
It overlays only onboarding runtime/locale changes, changelog and candidate TOC
metadata onto the archived beta 26 package. The unrelated pending Gamepad changes
and native Companion are excluded. All 84 baseline-plus-onboarding suites pass
in a validation tree with runtime bytes matching the package; five targeted
suites also pass against the extracted ZIP. Its 76 entries match staged bytes.

## Evidence and limits

- Source: release preparation commit `293f56666255028d1aef4646bb776100ed74b51c`,
  integrated at `9c7e83c`. The affected Init, Config, Onboarding, Options and Wizard
  files are unchanged between those commits and the working tree inspected here.
- Archive: `dist/beta26-preparation-20261101/Offhand-v2.1.2-beta.26.zip`.
  SHA256: `599CFC87906C043636119387CC250B25C2457C1CE26B1A364286D2A9CEFE0833`.
  All 76 files match its archived verification manifest. The affected files also
  match current source. This is the local release-preparation artifact, not a
  newly downloaded copy from the reporter's installation.
- The [public CurseForge file](https://www.curseforge.com/wow/addons/offhand/files/9396675)
  identifies beta 26 and lists Forever 1.60.1 support. The remote ZIP bytes were
  not independently compared: the direct download page presented a browser
  challenge. Public listing metadata does not prove archive-byte identity.
- User client: Forever, exact build unknown. The visible addon tooltip gives
  `2.1.2`, which does not identify its beta suffix. Beta 26 is supplied by the
  owner, not independently established from that screenshot.
- Shared knowledge was consulted first. Its Forever snapshot is
  `ca8368f2f2380cbe696854f7f2646387c278a61b`, version `1.60.1.70532`. Searches for
  settings category registration and cinematic detection returned no local
  evidence. That does not establish API absence. The
  [upstream version at eac30af](https://github.com/Gethe/wow-ui-source/blob/eac30af597e5aaa43a60f6675ef5fdcea100375f/version.txt)
  is `1.60.1.70790`. Neither build is confirmed as the reporter's build.
- Evidence level: source review and Lua 5.1 simulation against extracted package
  code. No live client, native display, combat/taint or cold-launch acceptance is
  claimed. The supplied images are observations of user reports, not a complete
  diagnostic session.

## What the reports establish

| Report | Established | Still uncertain |
| --- | --- | --- |
| First reporter initially sees no Offhand in Add-ons settings | Offhand has no native settings category. A later installed-addon screenshot shows it enabled and recognized. | Successful initialization, automatic guide visibility, selected client folder, mode and span, Companion use, Lua errors and setup state. |
| First reporter asks whether a wizard exists | Setup was not discovered or understood during that session. | Whether the confirmed entry defect, a load error or another factor caused their exact experience. |
| Another user reports an entirely black Offhand monitor after the wizard | A separate unresolved symptom, reported without diagnostics or a screenshot of the black display. | Empty working canvas versus incorrect geometry, disabled setup, panel placement, renderer failure or a native Gamepad limitation. |
| A third user reports success, then asks about using part of the second monitor | At least one participant reached a usable setup. | Their client/build, topology and whether the requested partial-monitor arrangement works. |
| CurseForge complaints | The repeated account/text is not an independent installation failure each time. | Wider failure rate or number of independently affected users. The other short comment is too ambiguous to classify confidently. |

The evidence does not justify treating this as user error, nor does it establish
a general Forever addon-loading failure. A listed and enabled addon can still
encounter Lua errors while loading.

## Confirmed defect in automatic guidance

The relevant path is:

1. `Core/Config.lua:10` keeps a new profile inert with `enabled = false`.
2. `InitializeConfig` creates account onboarding with neither welcome dismissal
   nor setup completion set. It copies that disabled default into the profile.
3. `Core/Init.lua:1252` requires `Offhand.db.enabled` before considering an
   incomplete welcome, incomplete setup or saved resume step.
4. The enabled/completed notice branch is also skipped. The ordinary login chat
   message still advertises `/offhand`, but no automatic guide or welcome popup
   appears.
5. Opening `/offhand guide` manually works without enabling the viewport.
6. `UI/Onboarding.lua:741` saves resume step 4 before its Reload UI action.
   During initial preparation the profile can still be disabled, so the next
   entry check skips that explicit resume too.
7. `UI/OptionsActions.lua:133` enables the profile when applying the calibration
   recommendation. Preparation before that point cannot rely on enabled state.

This is shared logic, not a Forever-specific API assumption. Other clients using
the same fresh-profile and entry paths are exposed too. Existing users whose
profiles are enabled can have a very different experience from new users.

History: the enabled gate appears in commit `8e0954c` on 2026-10-25, while the
disabled first-launch default predates it (`dd5dc6d`, 2026-09-21). The defect is
not evidence of a new launch-day API change.

### Package simulation

The investigation harness loads the extracted package's actual Init, runtime
and Config modules. It uses real configuration initialization, saved onboarding
accessors and the real `PLAYER_ENTERING_WORLD` handler, with mocked UI/timers.
Its build identity is synthetic. It measures calls to the guide entry point,
not pixels or native-client behavior.

| Starting state | Automatic guide calls |
| --- | ---: |
| Fresh install, disabled default, no acknowledgement or completion | 0 |
| Incomplete disabled setup with Companion method and saved resume step 4 | 0 |
| Enabled incomplete setup | 1 |
| Enabled completed setup | 0 |
| Completed setup subsequently disabled | 0 |

Manual `/offhand guide` produces one guide call with `enabled` still false.

Local reproduction material is under ignored
`dist/onboarding-investigation-20261105/`: `reproduce.lua`, extracted `package/`
and tests recovered from release commit `293f566` under `baseline-tests/`.
Run the reproduction from the extracted addon root:

```powershell
Set-Location D:/Tools/Code/Offhand/dist/onboarding-investigation-20261105/package/Offhand
lua D:/Tools/Code/Offhand/dist/onboarding-investigation-20261105/reproduce.lua
```

The three release-baseline suites `lifecycle.lua`, `wizard-autoconfig.lua` and
`forever-cvar-persistence.lua` all pass against that extracted package. The same
three current suites also pass against package code. The lifecycle test calls an
incomplete disabled profile deliberately disabled, but starts its welcome state
as already dismissed. It never exercises actual fresh defaults plus entry.
Passing wizard tests therefore did not cover first-launch enrollment.

## Additional discovery and guidance gaps

### The expected settings location has no entry

`UI/Options.lua:2613` has an empty `InitializeOptions`; `Options:Open` creates
Offhand's own floating settings window. No native Add-ons category is registered.
The first screenshot is consistent with that design, rather than proof that
CurseForge failed to install Offhand. `/offhand`, `/oh` and the minimap icon open
the custom window.

Add a discoverable native settings entry that opens the existing window, subject
to the target client's supported settings registration API. Keep slash commands
and the icon as recovery paths. A settings API implementation has not been
validated in this investigation.

The minimap's Run Setup Wizard action directly opens calibration
(`UI/Minimap.lua`), whereas the settings wizard button routes incomplete setups
through onboarding. That inconsistent entry path can bypass the preparation
guide, even though calibration has its own geometry checks.

### French client receives English setup instructions

The screenshots show French game UI. Beta 26's `Locales/frFR.lua` provides English
text for the current introduction, placement, calibration, readiness and many
help strings. The login message and some older strings are translated. This is
an intentional fallback recorded in the changelog, but it materially reduces
the accessibility of a multi-stage setup. It does not prove the reporter cannot
read English or that a translation alone would have resolved the incident.

### Calibration does not populate the workspace

`Core/Canvas.lua:109` creates an empty secondary canvas with a dark background.
Existing saved panel positions can restore, but a new installation has none.
The wizard completes calibration and HUD setup; it does not automatically open
and populate a dashboard of panels.

`ONBOARD_CALIBRATE_TASK_CLASSIC` explicitly says to move supported panels onto
Offhand. `ONBOARD_CALIBRATE_TASK_EDITMODE`, used on Forever, ends at HUD creation.
`UI/Wizard.lua:940` closes the wizard and prints saved/readiness/cold-start
messages, without a concrete first-panel placement task. The website's
[setup instructions](https://www.curseforge.com/wow/addons/offhand) include a
separate arrange-panels stage, but a player can finish the in-game flow without
that visible handoff.

An empty dark workspace is a plausible explanation for the second report, not a
diagnosis. A physically black monitor that is outside the WoW window, or a panel
that cannot be moved there, needs separate geometry/runtime investigation.

### Minimap and World Map are different requests

The first reporter specifically asks for a minimap. On Forever,
`Core/CanvasCompatibility.lua` treats `MinimapCluster` as Edit Mode owned, and
Canvas excludes it from ordinary panel dragging when Edit Mode is available.
The generated HUD layout handles it as part of Mainhand. The older minimap
docking locale strings are not an exposed docking feature in current Options.

For the actual minimap, explain the native Edit Mode workflow and test placement
on the release client before promising it. For the large World Map, explain
opening and dragging the supported map onto the prepared workspace. Clarify
which one the user wants. The screenshot does not establish a minimap-movement
bug.

## Recommended order of work

1. Correct entry guidance eligibility independently of viewport activation.
   Preserve `enabled = false` before calibration. Distinguish a never-configured
   installation and an explicit setup-resume request from a deliberate user
   opt-out. Do not globally enable fresh profiles or indiscriminately reopen
   setup for every disabled profile. Durable opt-out/resume precedence needs an
   explicit contract because the existing enabled flag records no intent.
2. Add integration coverage using actual fresh Config state plus the entry event,
   including guide Reload UI handoff, cinematic deferral, setup dismissal,
   completed accounts, explicit disable and Forever persistence recovery.
3. Make Settings, minimap and slash-command entry points consistently lead new
   users through preparation before calibration.
4. Add a final visible first-use task: open World Map, move it onto Offhand,
   verify it remains visible, and explain the separate minimap/Edit Mode path.
   Offer targeted recovery and diagnostics if that cannot be completed.
5. Translate the revised French setup flow and verify wrapping on a narrow
   Mainhand display. Keep current button labels consistent in all support text.

For live acceptance, use a fresh installation on the actual Forever release
build. Record the complete build tuple, addon/Companion versions, input UI mode,
monitor bounds/DPI and current errors. Check first entry, the placement reload,
calibration/HUD reload, first panel placement, a normal cold restart and an
explicitly disabled completed setup. The existing Gamepad test candidate is a
separate scope and does not establish acceptance of these onboarding paths.

## Immediate support triage

First use `/offhand guide`; no reinstall or saved-variable deletion is indicated
by the current evidence. Keep WoW in ordinary Windowed mode, confirm the selected
placement method, then follow placement, calibration and HUD/reload instructions.
After calibration, distinguish an empty workspace from a window that never
reached the second monitor by trying one supported ordinary panel.

If setup still fails, request `/offhand diag`, the exact step/button where it
stops and the first Lua error. For the black-screen report, also request a full
view of both displays and whether WoW visibly spans them, plus the input UI mode.
Do not prescribe repeated reinstalls, resets or a particular hardware cause
without that evidence. The screenshots and duplicate complaints cannot establish
the overall incidence of the problem.
