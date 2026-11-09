# Beta 27 span recognized while addon remains disabled

## Reported evidence

User-supplied screenshot after entering the game, applying Companion's span and
reloading: Forever 1.60.1 build 70862, interface 16001, addon 2.1.3-beta.27,
Companion writer/paired 2.1.3, protocol 1, version status MATCH.

The diagnostic state is Enabled=0, Spanned=1, Source=Companion, Combat=0,
Setup=0. Mainhand is right at (1920,0 2560x1440), workspace is
(0,5 1920x1080), physical canvas 4480x1440, screen 3675x1181 and effective
scale 0.650. Viewport bounds check reports MISMATCH.

This establishes a recognized span with inactive addon layout. It does not
establish whether configuration was previously completed, lost, deliberately
disabled or interrupted. The Store hotfix channel is reported by the user;
the screenshot's writer version does not identify its package/build number.

## Released-source evidence

Inspected release tag v2.1.3-beta.27,
a2eee0c5dbee7b7f0c331e986f9c453c8f87235b, separately from the older dirty
checkout. No runtime source or installed files were changed.

- Core/Config.lua defaults enabled to false until placement/calibration is
  applied. Existing explicit values are preserved by defaults.
- Core/Viewport.lua, Viewport:Apply resets WorldFrame to the full canvas when
  disabled, even when Companion topology is READY. The bounds diagnostic still
  compares that full canvas with the intended Mainhand, explaining MISMATCH in
  this inactive state without proving a topology rejection.
- Core/Init.lua, EvaluateEntryNotices opens incomplete setup unless explicitly
  suppressed. Span recognition alone does not enable the addon or finish setup.
- UI/OptionsActions.lua, Options:AutoConfigure enables the addon. The wizard's
  recommendation action calls this method. Wizard completion records setup.
- `/offhand diag full` includes Forever persistence source, bridge/session state
  and revisions, which the supplied cropped diagnostic does not show.

Four targeted Lua 5.1 suites passed against an extracted copy of the release:
first-launch-onboarding, forever-cvar-persistence, companion-topology and
wizard-autoconfig. These are mocked regression checks, not reproduction on the
reporter's installation or native-client/persistence acceptance.

## Recovery and unresolved gap

For an installation that has only been spanned, open `/offhand wizard`, apply
the detected recommendation and complete calibration/HUD setup, including any
requested reload. For a previously configured installation that should already
be enabled, capture `/offhand diag full` before changing state to distinguish
profile selection, explicit disable and Forever persistence recovery.

Follow-up clarification: this was a first install. The guide reappeared after
reload and the user continued with Next. The actual wizard reproduces a source
defect: ordinary Next does not activate the disabled default, unlike the optional
recommendation. A correction and private addon-only package are now prepared in
the current 2.1.3 worktree. See
`C:/Users/NAUX/.codex/worktrees/workspace-addon-reconcile/Offhand/docs/SPAN-ACTIVATION-REPORT-20261108.md`
for the current investigation, failing-before regression, all 109 source and
packaged test passes, six-manifest validation, artifact hash and pending native
acceptance. Do not silently enable every recognized span, reset SavedVariables
or attribute this to the Store preference-write incident.

Shared knowledge README, research skill, status and Forever-scoped ask queries
were consulted. The persistence packet returned authored guidance only; upstream
Forever snapshots are review-due and do not verify build 70862 runtime behavior.
The conclusions above use the release source and supplied screenshot, with no
new client API assumptions.
