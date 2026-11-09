# Portable Companion and unrecognized command report, 2026-11-08

## Report and current conclusion

Zeitaneitor reports that an earlier error stopped, but spanning does not work
properly and an in-game command is not recognized. The user confirmed the
portable Companion and Forever client. The exact command, affected geometry,
Companion file build, installed add-on release, and Forever build are unknown.

No defect explaining that report was reproduced in the checks below. Keep this
report open for affected-machine evidence. Do not attribute it to monitor IDs,
declare a command-registration regression, or claim the Store settings hotfix
resolves it. No production code or release artifact was changed by this audit.

## Pinned subjects

- Released portable EXE: `Companion/Prepared/2.1.3/Offhand.exe`, file build
  `2.1.3.9`, SHA-256
  `88916B6FBAA4FF2E81EC574F8FA248C553ED531AD7A3DC828FF4948568797443`.
- Its runtime source: `d2934ef802cf0c8deb62d29fd0c932658e64afa3`.
- Released add-on: `Offhand-v2.1.3-beta.27.zip`, SHA-256
  `BC9C11361C3658A249C1C593108985498E85FAB51662DBF1431C03D548D864EF`.
- Audit baseline: `cdadbf6aedeb45ef813523d07be3813ac5e24139`.
- Local evidence: ignored `dist/portable-forever-investigation-20261108/`.

These are locally available published artifacts, not artifacts obtained from
the reporter. Their installation and versions have not been established.

## Source findings

`Core/Init.lua` registers `/offhand`, `/oh`, and `/Offhand` during file load.
`guide` and `setup` open onboarding; `wizard`, `calibrate`, and `span` open the
setup wizard. Registration does not wait for successful calibration. Startup
code executes before registration, so a prior runtime error remains a possible
cause, not an observed failure. `/reload` is a game command, not registered by
Offhand. Establish which command was rejected before interpreting the symptom.

`AddonInstallation.Inspect` in `Companion/Source/Program.cs` verifies the client
installation's on-disk manifest metadata and Companion compatibility. Its
successful result says to confirm the add-on is enabled in WoW. It does not
establish that the add-on is enabled for the character, that its Lua loaded
without error, or that the generated topology was consumed in the current UI
session. A successful on-disk check must not be reported as live add-on health.

The span path writes topology before changing the native window. Successful
spanning logs an instruction to return to WoW and type `/reload`, also shown in
the tray notification. Mainhand/layout guidance tells users to span and reload.
If WoW has not loaded Offhand or the newly written topology, native window
placement alone does not prove the in-game Mainhand/workspace layout is ready.
This is a diagnostic possibility, not the established reporter root cause.

The Store build10 diff changes persistence, versioning, and diagnostics. It does
not introduce a fix for this separate span/command report. Submission 4 and its
frozen artifacts were left unchanged.

## Checks and evidence boundaries

- Exact released add-on archive: 86 files, six TOCs, all 444 manifest file
  references present, and all 74 Lua files accepted by Lua 5.1 `luac -p`.
- Seven existing Lua suites executed with the extracted release as their
  working source: `diagnostic-output`, `wizard-autoconfig`, `lifecycle`,
  `first-launch-onboarding`, `companion-topology`, `disabled-client-isolation`,
  and `geometry`. All passed. These use mocked APIs, not the Forever runtime.
- The source-tree `manifests.lua` suite passed. Running that entire suite inside
  the distributed archive reaches its final repository-packager assertion and
  stops because `package.ps1` is intentionally not shipped. This is a harness
  boundary, not a missing add-on payload. The independent archive checks above
  verify the shipped manifests and files without adding build scripts to it.
- The exact released EXE was loaded for a read-only reflection call to
  `AddonInstallation.Inspect`, against an isolated `_forever_` directory holding
  the extracted Beta 27 add-on. It accepted the matching installation and
  reported `Verified beta.27`. No Companion UI or game was launched for this.
- Released native runtime source passed the existing display-selection suite
  (177 checks each on x64 and x86), and the partial topology writer/consumer
  suite (64 acceptance/rejection cases plus 32 metric/persistence round trips
  and secondary-workspace offset/stale-canvas checks).
- Released native runtime source passed 3,057 rollback assertions on each of
  x64 and x86 using the current corrected `CompanionSpanRollback.cs` fixture.
  The original historical fixture first failed because its synthetic 3,200px
  window was clamped to 2,580px by this host's tracking limit. The already
  committed fixture correction explicitly permits synthetic large windows and
  avoids wholly off-desktop restore targets. No runtime code was patched to
  obtain the pass. Both raw and corrected-run logs are retained.
- Current-main display-selection, partial topology, and native rollback suites
  also passed. Compiled source tests and synthetic windows do not establish
  real WoW rendering, taint safety, or the affected user's monitor behavior.

Read-only inspection found this machine's installed Forever add-on was an older
`2.1.2-beta.26-forever-discord.test19` fixture, with source differing from the
released Beta 27 package. This is the owner's machine, not the reporter's, and
does not establish reporter version skew. It was not overwritten. No game
input, reload, span, settings reset, or live-client acceptance was performed.

## Next affected-machine check

Wait for the exact rejected text/command and a description or screenshot of
the wrong span. Obtain the Companion's copied diagnostics/activity log from
that operation, the add-on version shown in Forever's AddOns list, and the
Forever build. Confirm Offhand is enabled for that character in that client.
Do not delete preferences or SavedVariables as a diagnostic shortcut.

When the reporter is ready, distinguish these branches:

1. If `/offhand` and `/oh` both receive WoW's unknown-command response after
   a reload, investigate add-on discovery/enabling or a startup Lua error. Ask
   for the first current-session error, rather than changing monitor settings.
2. If the base command works but a subcommand does not, capture the exact
   spelling and response, then compare its handler with that installed release.
3. If the outer window is correct but gameplay is on the wrong monitor, retain
   the selected Mainhand and generated topology evidence. After the normal
   Span WoW Now and `/reload` handoff, capture `/offhand diag` if it works.
4. If the outer window itself is wrong, retain Windows display arrangement,
   scaling, selected displays, native bounds, and fresh Companion diagnostics.
   Investigate geometry separately from add-on slash handling.

No additional public package is justified by these results alone. A confirmed
defect should get a focused regression and candidate without modifying the
Store package currently in certification.
