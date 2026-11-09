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
