# Character HUD setup candidate

New characters on an account with completed monitor setup receive a short HUD
check on supported Edit Mode clients. The check reuses account installation and
the current profile's calibration. It does not repeat the Companion guide or
apply a new monitor split.

Status: source and package simulation verified, live acceptance pending.
For the current combined test round, use the
[Forever Discord candidate](FOREVER-DISCORD-TEST-20261105.md), which includes the
Gamepad fixes too. The isolated artifact below remains a historical checkpoint.
Candidate: `Offhand-v2.1.2-beta.26-onboarding.test2.zip`.
SHA256: `C9C87CDB2ED3C750A1A9850FF5CBAEF96756623A8F3B45B8BBA4E9600C8D341C`.

## Character choices

| Choice | Behavior | Saved result |
| --- | --- | --- |
| Use existing setup | Selects a verified compatible saved HUD layout. It does not create, rewrite, translate or promote a layout. If none is available, the card explains that and retains Customize HUD and Later. | Character association plus a completed existing-layout choice. A changed active layout uses the existing reload prompt. |
| Customize HUD | Opens the existing wizard directly at its HUD step. Monitor setup and calibration remain intact. | A pending character choice, completed after a compatible character layout is observed. |
| Later | Closes the check and allows play to continue. | A per-character acknowledgement that remains quiet for the same display geometry and input mode. |

On Forever, Customize HUD creates or updates a native character-specific
Edit Mode layout for the current input mode. Use existing setup still offers
compatible shared layouts. If the character already uses a compatible legacy
Offhand account layout, creating the character layout can carry its placements
over while preserving the shared entry.

The card is addon-owned on keyboard/mouse and native Gamepad interfaces. It uses
the existing Mainhand positioning, popup text measurement and three-button
presentation. New copy has French translation; other non-English dictionaries
use labelled English fallback pending translation.

## State and lifecycle

- Account onboarding remains in `OffhandDB.onboarding`.
- Monitor calibration, enabled state and profile setup suppression remain in the
  selected `OffhandDB.profiles[name]` record.
- The character decision is `OffhandCharDB.characterSetup`, version 1, containing
  choice, completion and the display/input context. Character HUD ownership and
  active-profile selection retain their existing per-character records.
- A new profile still clones the current profile; it does not clone or reset
  character acknowledgement. Another character gets an independent check.
- A matching returning character with a ready layout stays quiet. A completed
  full account setup need not immediately show a redundant character card when
  that setup already established the character's HUD.
- A changed GUID clears the prior character choice together with old HUD state,
  while retaining account setup, profiles and recovery provenance.
- Later remains quiet across reload and cold launch when state loads correctly.
  A changed display geometry or input mode permits another check. A previously
  accepted layout that becomes unavailable or incompatible can also require
  guidance. The check is bounded per context in the current UI session.
- Existing characters with working HUD records do not receive a forced migration
  prompt. Older explicit Don't remind me choices remain respected.
- Incomplete account setup takes priority. Disabled profiles remain quiet.
  Clients without supported Edit Mode retain the existing account setup path.
- Combat and cinematic input defer the check. An already-visible card hides when
  a cinematic begins. A settled span can trigger the deferred character check
  after Companion placement has become valid.
- Normal SavedVariables and the existing character-scoped Forever full snapshot
  retain the choice. No new Companion version or CVar protocol is required for
  this character record.

## Reuse boundaries

`Core/CharacterSetup.lua` owns the card and character choice.
`Core/MainhandEditMode.lua` adds a separate discovery/selection path. It accepts
only a present compatible character layout or a shared row whose recorded
client, geometry, input mode and external UI ownership match. Discovery does not
activate a layout. Explicit selection verifies the resulting active ID before
recording success, preserving saved anchors and rollback provenance.

Missing, stale, foreign-character, controller-owner or UI-owner mismatches do not
fall through to layout creation. Combat, open Edit Mode and failed/unverified
activation cannot complete reuse. This is source and mock evidence, not proof of
native protected-action or taint safety.

## Validation and packaging

- All 88 current Lua 5.1 suites pass. Tests include real Config initialization,
  GUID identity, reuse discovery/selection and entry-event dispatch with mocked
  native storage and presentation.
- All 86 isolated Beta 26 plus onboarding suites pass. The candidate combines
  the earlier first-launch changes with the character check and excludes pending
  Gamepad work. Mainhand's baseline body is preserved; only the new reuse helpers
  are appended to it.
- Character setup, layout reuse, lifecycle, fresh-launch entry, shared identity
  and the wizard suites pass against the extracted ZIP.
- All six manifests pass file, XML and Lua 5.1 syntax validation. All 77 archive
  entries match staged bytes and have a single portable `Offhand/` root. Tests,
  development tools, caches and the native Companion are outside the addon ZIP.
- Full source and artifact details are in the ignored
  `dist/first-launch-test2-20261105/verification-manifest.json`.

The targeted client identity in the character tests is synthetic Forever
`1.60.1.70790`, not an observed runtime build. Shared knowledge guidance on
separating account/character/profile state was consulted before implementation.
The exact reporting users' release builds remain unknown. Live client source
and observations remain authoritative.

## Live acceptance

Use an account whose monitor setup is already complete and a character that has
not used Offhand. Preserve real SavedVariables, generated bridge state and the
installed addon for rollback; deleting them would obscure this test.

1. Record the actual client/build, selected profile, input mode, topology/DPI and
   current addon/Companion versions. With Offhand enabled and the intended span
   established, verify that the short character card appears instead of the
   installation guide.
2. Select Use existing setup with a compatible shared HUD. Check native active
   selection and the reload prompt, exact saved panel/HUD positions and that
   another character's shared layout has not been rewritten.
3. On another character choose Later. Reload and cold launch in the same context;
   the check should stay quiet. Create a profile and verify that the character
   choice remains independent. Change input mode or display geometry and check
   the next appropriate entry/settled-display evaluation.
4. With no compatible layout, verify that reuse explains the problem without
   creating a native layout. Choose Customize HUD and confirm that it opens only
   HUD setup. Complete creation and its reload, then verify a quiet return.
5. Test combat entry and a cinematic starting while the card is visible. Check
   Mainhand placement, French/narrow-display wrapping and both input interfaces.
   Exercise native actions and inspect current errors/taint, not only the card.

No client was launched, installed addon replaced, public release published or
native Companion rebuilt during this implementation.
