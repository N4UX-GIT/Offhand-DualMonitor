# First-install Next route leaves Offhand disabled

## Report and reproduction

Forever 1.60.1 build 70862, interface 16001. The screenshot identifies addon
2.1.3-beta.27, Companion writer/paired 2.1.3 and compatible protocol/version.
It reports Enabled=0, Spanned=1, Source=Companion and Setup=0 after span/reload.
Canvas is 4480x1440; Mainhand is right at (1920,0 2560x1440), workspace left
at (0,5 1920x1080). The user confirms this was a first install following the
guide, that the guide reappeared after reload and that they continued with Next.

Release tag v2.1.3-beta.27 is a2eee0c5dbee7b7f0c331e986f9c453c8f87235b.
Its UI/Wizard.lua matches the investigation baseline before this correction.
Config defaults to disabled; only the optional recommendation action called
Options:AutoConfigure, which enables the addon. Ordinary Next advanced all
calibration steps without enabling. The HUD creation transaction requires an
enabled addon. Skipping HUD creation could also mark setup complete while
leaving the viewport disabled. This is an addon setup defect; the available
evidence does not connect it to the Store preference-write hotfix.

The new mocked regression starts disabled, opens the actual wizard, advances
Next on the reported accepted geometry, and fails before the correction with
"fresh-install Next must activate confirmed calibration without requiring
Auto-Configure". Existing tests initialized the wizard with enabled=true.

## Correction

UI/Wizard.lua activates a disabled profile only after an explicit calibration
continuation passes placement and Companion-version validation. It uses
SetEnabled to retain the existing persistence contract and applies the layout
without replacing manual seam, scale or other calibration settings. It also
checks activation before confirmed setup completion. Opening the wizard stays
inert; ordinary login/span recognition does not override disabled preferences.

Regression covers Next, resumed steps, activation before HUD creation, complete
setup, preservation of calibration values, no repeated activation, and refusal
on stale geometry or incompatible Companion version. Existing first-launch and
Forever persistence suites still pass. No new client API assumption is made.

## Validation and artifact

All 109 Lua 5.1 suites pass in current source and against the extracted candidate
runtime with release-source development fixtures outside the deliverable ZIP.
All six source and extracted TOCs pass path, XML and Lua 5.1 syntax validation.
git diff --check passes. No live client, combat, taint or cold-start acceptance
is claimed. No installed addon, SavedVariables, native layouts, Companion
binary, public release or Store submission was changed.

Private candidate: dist/span-setup-test1/Offhand-v2.1.3-beta.27-span-setup-test1.zip.
SHA-256: C6B6FE2DBCA41AC60E8A4A4B3D867C53BBB640BDF6A39F36FBF37C236B2D37C1.
Base is the public-readback Beta 27 ZIP, SHA-256
BC9C11361C3658A249C1C593108985498E85FAB51662DBF1431C03D548D864EF.
All 86 entries were read/hash-verified. Only UI/Wizard.lua changes at runtime;
six TOC titles/candidate markers distinguish the private build. Every other
entry is byte-identical to the published archive. Generated bridges remain
packaged inert. The receipt and development test logs are outside the ZIP.

Native acceptance update: Forever 70862 first-install guide, span/reload,
Confirm placement, Start Calibration, ordinary Next, actual HUD creation and two
completed reloads pass on the tested 2560x1440 single-display split. The viewport,
completed setup and newly generated 54-system HUD persist with matching active
layout and geometry. All original settings/installation restored after testing.
The subsequent owner-authorised clean-account/default-Companion run also passes
first HUD creation with zero prior native rows, reload and cold WoW/Companion
restart. Fresh settings and the candidate remain installed after that later run.
See [clean-account evidence](SPAN-SETUP-CLEAN-ACCOUNT-LIVE-QA-20261108.md).
Exact reporter topology and protected actions remain separate gaps.
See [native evidence](SPAN-SETUP-NEXT-LIVE-QA-20261108.md) for recorder failures,
error attribution and precise cleanup. The released recommendation action
remains the workaround until a corrected addon is installed.

Knowledge README/skill/status and Forever-scoped queries were consulted. The
corpus did not establish the setup mechanism; release source, actual wizard
callback simulation and the user's workflow clarification are the evidence.

## Earlier report investigation (superseded by the correction above)

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
