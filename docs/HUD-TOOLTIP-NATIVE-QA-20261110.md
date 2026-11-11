# HUD placement and comparison native QA

2026-11-10. Owner-authorized WoW test-harness run. Native out-of-combat checks
and the actual combat-click refusal passed on the local Forever installation.
The owner completed manual combat and authorized restoration. Cleanup is complete.
The owner separately confirmed readable combat comparisons without overlap or
visible errors. This is scoped native evidence, not unrestricted combat/taint
or release acceptance.

## Scope and subject

Forever 1.60.1 build 70862, authenticated through the existing Battle.net launcher,
preselected idle level-2 shaman. Companion 2.1.6, existing 2560x1440 single-display
split: right 1280x1440 Mainhand, left workspace. This is not the reporter's
2560x1600 plus portrait 1080x1920 physical arrangement.

The skill diagnostics collector was run before launch. Computer Use handled the
launcher, Companion, native Edit Mode and addon-owned private QA buttons. No
movement, casts, targeting, NPC interaction, public chat or combat automation.
The generic runner's UI automation was not mixed with Computer Use.

The installed addon was backed up with 192 scoped files, including prior
absences, flags, SavedVariables, native local layout caches, configuration,
generated bridges, helper source and taint log. Only MainhandEditMode.lua and
PopupBounds.lua were overlaid on the previously installed private baseline.
No Companion binary, public package or frozen release subject was changed.

Final tested module SHA-256:

- MainhandEditMode.lua: 12519022ca0f9d2a3889431948f10ce596e903f777cf0956f0dd5cbcc38ecaf1
- PopupBounds.lua: aa49752d253349812f4265f3c7d9962739df86036cf0bf69ea482598e3dce749

Loaded flags confirm EllesmereUI core/action bars/minimap, DaylightUI, Details,
TipTac and TinyTooltip were absent in the isolated tests; Offhand and error
capture loaded. The initial setup-only session had replacement addons enabled
and forced manual geometry. It is not acceptance evidence. Preparation was
corrected to handle enabled/disabled flags and use the public AUTO geometry and
Companion setup setters before the isolated run.

## Native findings and correction

Modern generation moved native action bars, player/chat frames and minimap into
Mainhand. Native Edit Mode showed the generated systems on the right. Generation
from the existing custom account source also moved its outlying HUD groups into
Mainhand, including its custom XP position. Both paths survived reload.

One native precision defect was found: saving an edit normalized the DamageMeter
anchor to 1571.4285888672 while Mainhand's computed left was 1571.4286024306.
The strict boundary comparison treated this 0.0000136 UI-unit difference as an
outlying custom position and projected it halfway across Mainhand on recreation.
The fitter now uses its existing 0.01 write threshold consistently for boundary,
size and skipped-group checks. No ownership, combat, protected, secret, ambiguous
anchor or oversized-group guard was removed.

The new rounding regression failed before this correction and passed afterward.
After restoring the recorded native edit and reloading the corrected module,
recreating the HUD retained the entire generated native row exactly. All 125
Lua suites passed again; native fitting now has 38 assertions. Six-manifest
Lua 5.1 path/syntax/XML validation passed. The shared working tree contains
other pending work; this is acceptance of the two installed module hashes,
not a whole-working-tree package claim.

## Preservation evidence

- The existing custom account source is identical in every captured native row
  comparison, with the native layout count unchanged.
- Action Bar 3 was nudged Right once in native Edit Mode and saved through the
  native Save button. The saved anchor survived Create and reload.
- After the precision correction, the complete saved generated row remained
  identical through Create, including settings and unrelated anchors.
- The first generated backup matches the actual native row captured immediately
  before the first replacement. Its difference from the initial login snapshot
  is native normalization of two small offsets when the preset was selected.
  The backup therefore preserves the actual pre-write row, not a fabricated
  source or another native slot.
- Explicitly selecting Modern and the existing custom source changes creation
  provenance accordingly. Original source rows remain selectable and unchanged.

Diagnostics remain NativeFit=partial where native systems cannot be measured or
resolved. Visible tested HUD placement is not a promise that every hidden,
replacement-owned or oversized system was fitted.

## Real item comparison evidence

The private owner buttons displayed actual cached Bent Staff and equipped Worn
Mace data through GameTooltip:SetHyperlink and GameTooltip_ShowCompareItem. Native
tooltip comparison management created the shopping card. No synthetic text,
comparison SetPoint, scale change or item action was used in these checks.

At the Mainhand seam and outer edge, native cards stayed adjacent with no overlap
and the entire measured group stayed inside Mainhand. Immediate and settled
samples pass the recorded rectangle checks (group width about 501.760 UI units).
Repeated after custom-source generation. Workspace-owner rendering was also
visually observed. Native screenshots and raw bounds are retained privately.

This is a real-item/native-manager check with addon-owned owners. It does not
accept the cropped reporter's exact bag, ring-pair, asynchronous item-data,
replacement-tooltip or short landscape-display scenario.

## Errors, combat and cleanup

The owner manually entered and left combat twice (approximately 5.2 and 14.4
seconds). During the second interval, the explicit Create HUD click was recorded
with InCombatLockdown=true and returned false/combat. That snapshot performed no
native layout or frame-geometry reads. Post-combat topology remained READY and
the selected layout remained active. No blocked/forbidden event was recorded.
The four historical BugGrabber message/time/counter/stack records are unchanged
after combat, restoration and client closure; no new captured Lua error.

Observer timing limitation: in both PLAYER_REGEN_DISABLED callbacks, the client
still reported InCombatLockdown=false. The entry-event probe therefore completed
ordinary out-of-lockdown generation. Those callbacks are not evidence of refusal
while locked. The subsequent explicit user click, about 1.77 seconds into the
second interval, is the actual lockdown evidence. Do not infer lockdown state
solely from event delivery, and do not repeat that transition probe in future
QA when a non-mutating observer will suffice.

The owner separately confirmed that combat comparison cards stayed separate and
readable, with no visible blocked-action or Lua error. This is owner-observed
visual evidence from the manual combat pass. It complements the recorded real
lockdown refusal, paired transitions and unchanged captured errors; the earlier
out-of-combat native bounds do not substitute for that observation.

The final captured taint log has startup traces involving Offhand's two
BINDING_NAME globals in Blizzard BindingUtil/Settings, plus Questie traces.
It has no blocked/forbidden action or MainhandEditMode/PopupBounds stack entry.
The pre-reload combat-session taint file was still empty on disk and the final
file covers the subsequent reload, so a complete combat-period taint-log claim
is unavailable. This is not a taint-free certification.

Restored the original native baseline through the same-character pre-run
snapshot outside combat, then closed the target client normally. Recorded native
layouts, settings, slots and active selection match the baseline exactly (zero
normalized anchor differences); the character layout record also matches.
All 63 original existing scoped files and 129 original absences were restored.
Final verification confirms 62 existing files still match their backup hashes;
the remaining file is the generated Forever recovery bridge, deliberately
refreshed from the hash-verified restored account/character data and verified
semantically equal to both restored tables. The QA helper source is restored
and its TOC disabled. The previously installed product modules, addon flags,
settings, caches and logging configuration are restored. Workspace source fixes
remain available; the private test overlay is no longer installed.

No WoW window/process remains. Battle.net and Companion remain open. No vendor
profile was intentionally edited and no gameplay input was automated. The
player's manual combat progress is server state, outside local setup restoration.

Private ignored evidence: dist/hud-tooltip-live-20261110. No release performed.
