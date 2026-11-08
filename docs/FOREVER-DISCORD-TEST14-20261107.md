# Private Discord test14, 7 November 2026

## Included changes

Retains test13's immediate Escape/chrome updates, earlier Kerzo support,
EncounterBar candidate and EFIGS localization. Adds:

- [Pooled popup ownership correction](GROUP-INVITE-COMBAT-20261107.md): modern
  ordinary confirmations use one native stack translator. Legacy OnShow
  centering and broad void rescue yield StaticPopup1..4 on Retail/Forever.
- [Map-content isolation hardening](MAP-PIN-TAINT-FOLLOWUP-20261107.md): Forever
  avoids addon-driven zone refocusing and bootstrap provider rebuilds. Geometry,
  map persistence and native event-driven quest updates remain. Other clients
  retain refocusing; delayed bootstrap refreshes recheck combat and enablement.

The behavior tradeoff is deliberate: a persistent Forever map no longer follows
a zone change through Offhand's SetMapID/ResetZoom calls. Use native navigation
or reopen the map. This does not disable Blizzard's native pin updates.

## Evidence and limits

All 99 Lua suites and six manifests pass in source. Tests reproduce each
overlapping popup writer and each excluded map-content entry path against
frozen test13. Non-Forever refresh and legacy popup behavior are retained.

Native QA targets Forever 1.60.1.70862, an existing idle keyboard test character
and a remembered 50/50 ordinary canvas. External map owners are temporarily
disabled for native-map checks, with enablement and settings backed up first.
The launcher reached WOW51900308, requiring user-handled sign-in. The session
remained at that prompt, so no in-world acceptance was obtained. Closed both
launcher-created client windows normally, restored 15 original settings files,
character addon enablement and both generated bridges, and removed the temporary
QA addon. No new in-world QA state was created. Battle.net remains open.

Mort's one-off protected SetPassThroughButtons block is not reproduced and its
initial taint source is unknown. Arual's real group-invite failure is likewise
unconfirmed. Harmless QA dialogs, simulations and a clean smoke run cannot
validate actual AcceptGroup/DeclineGroup, active quest updates, level-up,
combat, controller input or taint safety. Exact reporter versions/profiles remain
requested. The reports stay open.

## Packaging contract

Private version 2.1.2-beta.26-forever-discord.test14; canonical source TOCs remain
public Beta26. The Complete bundle retains the frozen public Beta20 Companion.
Do not rebuild or replace that binary on this addon branch. Preserve installed
CompanionTopology.lua and ForeverState.lua. Prior test13 ZIPs remain rollback.
Only runtime files and public instructions go into ZIPs; tests/source evidence
stay in the separate source snapshot. No QA addon, logs, account state, reference
cache, credentials or SavedVariables belong in distributable archives.

The private candidate passes 99 suites and six manifests in source and extracted
runtime. Package verification covers the source snapshot, runtime hashes and
frozen Companion. Installed non-generated files match the package; generated
bridges are preserved and test13 archives remain unchanged for rollback.

Live map/popup testing remains pending login. Unchanged historical BugGrabber
records provide no candidate in-world evidence because addons never loaded.
This record does not mark unresolved reports fixed or authorize Discord posting.
