# Forever live smoke, 2026-11-06

## Result

The combined Discord test.2 candidate passes the exercised startup, span/restore,
native Gamepad panel, map-size and reload paths on Forever 1.60.1.70790
(Interface 16001). No new BugGrabber error or observed blocked-action event was
recorded. This is a bounded smoke pass, not complete controller, combat or
release acceptance. No runtime source correction or replacement archive was
needed during this run.

The reporter's Map then Spellbook recording visibly supports the enlargement
symptom. The existing candidate did not reproduce that enlargement. Physical
B/Back remains unverified because the client reported zero connected gamepads.

## Build and environment

- Release Forever client, launched through the authenticated Battle.net session.
  Existing level 1 Shaman Noggaholic-Naux, stationary in the starting area.
- Installed addon: `2.1.2-beta.26-forever-discord.test2`. All 75 non-generated
  runtime files match the addon ZIP before instrumentation and after cleanup.
  ZIP SHA256: `46FFA54BFA0521D30AE85F7410C8F44BFCDEA1F7C5E9F10A4DF959B57042C696`.
- Store Companion package 2.1.20.0 was installed. Direct activation of its
  WindowsApps executable returned access denied. The existing portable Beta 20
  executable was used after verifying it is byte-identical to the Store file:
  SHA256 `81EECE9430885CEAC178A44A42429854524279072305F9F94EE62E7CCD620CCB`.
  Store activation itself was not accepted. No Companion rebuild was made.
- Local physical geometry: 2560x1440 landscape Mainhand on the right and
  1440x2560 portrait workspace on the left, spanning 4000x2560. This differs
  from the reporter's 5120x1440 Mainhand below a 2560x1440 workspace.
- Existing settings were retained. OpenMap and Leatrix Maps were temporarily
  disabled only for this character to isolate stock map behavior, then restored.
  BugGrabber/BugSack stayed enabled. Legacy UserMedia metadata was preexisting.

## Recording evidence

The supplied recordings are evidence, not instructions. No message was sent to
Discord or CurseForge.

- `Recording 2026-11-05 142919.mp4`, source 2558x1436: Map is initially modest;
  around 3.5 seconds Spellbook appears and Map becomes much larger, extending
  outside the capture. This is visible symptom evidence, not a measured root
  scale or blocked-function stack.
- `Recording 2026-11-05 143200.mp4`, source 5116x1390: Map opens and later
  closes. Reviewed frames do not show a readable blocked-action warning or
  identify which controller button was pressed. Its container duration is
  about 13.4 seconds but extracted video frames cover about 7.5 seconds.
- Contact sheets and 2 fps review frames are local under
  `dist/live-forever-smoke-20261106/`. The earlier source-level enlargement
  reproduction and 27 stacked-layout fixtures remain separate evidence in
  `FOREVER-STACKED-CONTROLLER-MAP-20261106.md`.

## Live matrix

| Check | Observation | Result / limit |
| --- | --- | --- |
| Cold launch, existing character | Entered world repeatedly, addon loaded | Pass |
| Companion span and restore | Actual viewport changes between normal window and 4000x2560 span | Pass on local topology |
| Reload with span and native panels | Returned to world, no fresh error | Pass |
| Keyboard to native Gamepad UI | Native console mode switch reloaded UI; mode 1 confirmed | Pass; keyboard mode restored to 0 |
| Stock Map then first Spellbook load | `Blizzard_PlayerSpells` load observed; Map stayed scale 1, about 1035x534 | Pass, normal and spanned window |
| Warm Map then Spellbook | Reopened panels, same map scale and dimensions | Pass |
| Native focus release by world click | UI focus changed true to false; map/book stayed shown | Pass in normal window |
| Native Escape after Map and Spellbook | Both panels closed and UI focus released | Pass for Escape; does not certify controller B |
| Character / Bags / Social | Native focus entered and released on panel open/close | Pass, no fresh error; secondary pixels not fully captured |
| Game Menu | Open/close and focus release | Pass |
| Character HUD handoff | Prompt responds to changed geometry/input context; Later closes in normal window | Partial; no complete HUD layout selection or controller navigation acceptance |
| Offhand options / wizard entry | Options render; restored single-screen window correctly pauses calibration pending span | Pass for entry/gating, not full setup completion |
| Final uninstrumented launch | Original map addons restored; Map then Spellbook kept visible map size, Escape closed panels | Pass for normal-window keyboard path |
| Physical controller Back / drag | No connected gamepad; spanned capture/input coordinates unreliable | Not tested |
| Combat, loot, NPC/quest dialogs, protected actions | No gameplay performed | Not tested |
| Zygor / full fresh-account setup | No applicable local guide install or fresh account | Not tested |

Gamepad map ownership is native. The keyboard workspace option to keep maps open
does not override native Gamepad Escape policy. No Blizzard focus handler was
replaced to manufacture a pass.

## Diagnostics and test boundaries

A temporary local addon module sampled native frame geometry, focus, input mode,
binding metadata and blocked-action events. It wrote only an addon-owned overlay
and bounded character log. Native frames, handlers and bindings were read-only.
The observer was appended only to installed manifests, never to source or ZIPs.
It was removed before the final clean launch.

Checkpoints preserve the event/snapshot stream across reloads and normal exits.
The spanned cold/warm sequence keeps Map at scale 1 with stable dimensions.
Contextual `TOGGLEUIFOCUS` reports context 9 but no keyboard binding, and the
device count is zero. Escape and mouse release are therefore recorded as their
own test paths, not a substitute physical Back pass.

BugGrabber began with three historical records. Their entire tables, including
messages, stacks, timestamps and occurrence counters, were unchanged through
the final session; only its session number changed (23 to 31). Existing records
name `SetPreferredGamepadInteractTarget`, a native LootFrame nil call, and
`SpellStopCasting`. They predate this run and were not counted as new failures.
The temporary observer recorded no ADDON_ACTION_BLOCKED/FORBIDDEN event.
No crash directory was created. Historical taint.log length/time stayed unchanged.
Taint logging was not enabled, following the existing Forever client restriction.
Absence of new errors here is not proof of general combat/taint safety.

An optional raw `/run` diagnostic encountered the native custom-script permission
prompt. It was abandoned without approval and the client was closed normally.
No custom-script permission was enabled; subsequent tests used native panel
bindings, ordinary addon slash commands and `/console` only.

Spanned UI capture covers primary pixels and has incorrect click-coordinate
mapping for the negative-origin window. Offscreen map geometry was checked by
read-only telemetry. Failed automation clicks were not classified as addon bugs.
The character HUD remained incomplete/deferred; HUD confinement and controller
interaction with the handoff prompt are not accepted by this smoke test.

## Cleanup and remaining acceptance

The test client and launched portable Companion were closed normally. Original
addon toggles and character state were restored, input mode returned to keyboard,
the game window was restored, and all six original manifests reinstated.
Temporary observer source and character logs were removed from the installation.
Account profiles were preserved rather than reset. The generated Forever recovery
snapshot was refreshed from clean character data to avoid retaining QA fields.
Backups, checkpoints, video review frames and diagnostic receipts remain in the
ignored evidence directory, not in addon packages.

Before a broad stability/release claim, complete a physical-controller test of
Map Back/Cancel, cold/warm Spellbook, mover dragging and mode switching on stacked
displays; test the relevant protected actions in combat and loot/dialog paths;
finish fresh-account, new-character, profile and HUD reuse flows; and run Zygor
with its actual first failing stack if available. The custom-workspace Companion
candidate also has independent native acceptance gates; this frozen Beta 20 run
does not certify that unreleased build.

Shared knowledge was consulted before engineering decisions. The local query
receipt is retained. Retrieval supplies guidance rather than exact build evidence;
the pinned Forever corpus is 70532 while this observed client is 70790. Native
behavior and installed source remain authoritative.
