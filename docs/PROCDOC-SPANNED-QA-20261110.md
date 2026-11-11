# ProcDoc Mainhand centering QA, 10 November 2026

User installed ProcDoc and requested continued spanned QA. Daylight testing is
now available for review as needed; this run isolates ProcDoc first. No Discord
messages/statuses, gameplay, item actions, vendor-source edits or public release.

## Installed source and baseline

ProcDoc v4.14.0, interface 16001. Its public one-unit ProcDocAlertFrame uses
ApplyCenter to read ProcDocDB.globalVars.centerX/centerY. Local runtime source
SHA256 abac52aa6e228f87590022b4c65d321468a359ebf5c93674677f0fb4a37c9ed5.
This is newer than the originally studied 4.13.0 source. Knowledge README,
research skill, status and targeted ProcDoc/ApplyCenter searches were consulted
first. Forever cache remains review-due and predates native build 70862. The
installed source and observed behavior are authoritative for this run.

Forever 1.60.1.70862 with explicit Companion spanning: physical 2560x1440,
right Mainhand 1280x1440 and left workspace. Companion changed externally from
2.1.5 to 2.1.6 before this test; its visible split configuration is retained and
the generated topology reports 2.1.6. No Companion binary is changed here.
ProcDoc/Offhand and error tools requested enabled; captured loaded-addon flags
also show Details and EllesmereUI core, so pure two-addon isolation is not
claimed. The character stays idle beside the vendor. A later Daylight setup
exposed that the staging script did not handle Forever's word-form addon flags;
that setup script is corrected, without retroactively claiming isolation here.

Fresh backups cover native caches/settings, addon flags, vendor state and the
private helper. ProcDoc has no prior SavedVariables. A temporary QA profile
disables its automatic CDM setup and preview sound; it is removed on cleanup.
The observer captures numeric anchors/scales/metrics and selected vendor fields,
with bounded addon-owned controls and a labeled anchor marker. The marker is
an observation aid, not a real proc. The vendor's own test preview shows actual
alert frames without casting or combat.

Baseline private archive SHA256:
8cb11cac0150cf09021b38db23916aa4f52b1127be0951ddd19c010207368d94.
All 97 installed product files match it, excluding generated bridges.

## Reproduced ownership conflict

All 15 baseline snapshots are spanned/READY. With the optional center setting
off and vendor offsets (0,0), the root is already CENTER/CENTER (785.71448,0)
instead of the vendor's (0,0). Enabling the adapter produces (1571.42908,0),
doubling the Mainhand translation and pushing the anchor toward the far edge.
Applying vendor offsets (120,-60) returns the active adapter to (905.71448,-60).
Turning the option off still leaves that translated point, rather than restoring
the vendor's (120,-60). The visible preview follows this incorrect anchor.

The automatic popup ownership list omits ProcDocAlertFrame, allowing generic
recovery to compete with both vendor centering and the opt-in adapter. A new
production scanner fixture uses the actual one-unit, non-panel CENTER root.
It fails before correction: automatic popup rescue changes that anchor.
Four historical BugGrabber records remain unchanged in message/time/counter/stack.

## First candidate and native precision finding

Add only the verified public ProcDocAlertFrame root to the existing automatic
popup preservation policy. The generic pass now yields irrespective of the
centering option; the dedicated adapter remains the only optional translator.
No vendor files/settings, frame scripts, native handlers or polling are added.
An existing session's previously displaced root is not blindly overwritten;
the owner's ApplyCenter or a reload supplies its saved baseline again.

The scanner regression passes after correction. All 123 frozen Lua suites,
six manifest Lua 5.1 validations (81 Lua/one XML) and 104 ZIP entry hashes pass.
Only runtime delta versus baseline: Core/HUDCompatibility.lua.
Private candidate SHA256:
95e87f88f889190b11f7c00b1880ff91af2569b64415a8d0b918113c9f366465.
Original installation backed up; all 97 installed product files match and the
generated bridges are preserved. Native default-off and opt-in placement now
work, but release still fails. Captures show the adapter requested
785.714436848958 and native GetPoint returns 785.714477539063, a difference of
0.000040690104 UI units. Its 0.00001 comparison wrongly loses ownership.

## Accepted controlled correction

Keep the popup preservation change and allow 0.001 UI units in the dedicated
adapter's anchor comparison. This handles the observed native round trip and
avoids unchanged writes. A regression models coordinate quantization, repeated
refresh and release; a separate 0.01-unit external adjustment still causes the
adapter to yield. The regression fails before the comparison change and passes
afterward. No vendor state, native handlers or new scheduling is introduced.

All 123 frozen Lua suites, six manifest Lua 5.1 validations and 104 ZIP entry
hashes pass. Runtime deltas from baseline are HUDCompatibility.lua and
ProcDocCompatibility.lua. Accepted private archive SHA256:
6c0b83411cce50c10fd98e9eeb6eb24459c3713db61bbf64d05278fb6b4f7d64.
All 97 installed non-bridge product files match after cleanup.

Native checks: default off retains vendor (0,0); opt-in applies the Mainhand
translation once; public ApplyCenter updates vendor offsets to (120,-60) and
centers relative to Mainhand; option off restores (120,-60); option on and the
vendor's own preview render actual alerts at the expected anchor. Disabling
Offhand restores vendor offsets, re-enabling reapplies one translation, and
normal /reload retains the opted-in placement and vendor values.

Of 34 captured samples, 32 match their settled ownership state. Two observations
at the same timestamp during Restore Window precede the adapter's layout
refresh; the subsequent release occurs 0.752 seconds later and retains native
offsets within 0.000008 UI units. This is deferred layout settlement,
not an immediate same-frame unspan claim. All 29 observations before unspan
report spanned/READY, including the explicit disable interval.

Four historical BugGrabber records are unchanged across baseline and both
candidates. No new captured error or visible error dialog; this does not prove
combat/taint safety. Closed every QA client normally and confirmed no WoW
window remains. Restored 53 existing scoped files by SHA256 and 130 prior
absences, including ProcDoc's temporary new profile. Both private helper TOCs
are disabled. Battle.net and Companion remain open. Earlier baseline launch
retries briefly created three launcher clients; two were closed at their
logged-elsewhere notices before entering world. Corrected acceptance used a
single authenticated client.

Private ignored evidence: dist/discord-qa-20261110-13, including scoped backups,
vendor hashes, baseline snapshots, failing/passing regression logs and frozen
candidate/install receipts. Combat, real proc triggers and exact reporter
profiles remain outside this out-of-combat preview test.
