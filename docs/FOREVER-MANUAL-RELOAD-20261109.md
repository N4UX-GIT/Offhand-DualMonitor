# Forever protected reload report, 2026-11-09

Historical fallback candidate, superseded by the native callback-order finding
in [reload-button research](RELOAD-BUTTON-RESEARCH-20261109.md). Keyboard/mouse
reload is restored with the callback executed before hiding its parent.
Controller UI retains the manual instructions below pending dedicated live QA.

Status: source correction, private candidate packaged and installed locally. Native
acceptance of the revised manual handoff remains pending. Nothing was published.

## Evidence and diagnosis

The user supplied WhoAmI's screenshots, including a readable BugGrabber trace:
ADDON_ACTION_BLOCKED, Offhand, protected function reload(). Its call stack reaches
Core/MainhandEditMode.lua:1593 from the owned popup's Finish/OnClick handlers in
Core/Init.lua:628/631. The adjacent prompt says Offhand created and selected the
Mainhand HUD layout. This identifies the reported failing step as the reload
request, not a failed layout creation.

The user subsequently confirmed the reporter is on Forever, Offhand Beta 28.
The exact client build and input style remain unconfirmed. The patch is based
on the current 2.1.5 Beta 28 source and installed release, HEAD dc5e9eb1526dd1ac0adad56d1021f7e9231cf5e1.
It does not reuse the older Beta 27 guide candidate.

The earlier API fallback was only compatibility support. Source declarations
for C_UI.Reload and successful mocks did not establish permission to call the
protected action. The reporter trace supplies the previously missing blocked-call
evidence. Its exact scope should not be generalized into a claim about every WoW
client or every reload context.

## Change

ClientRuntime.GetReloadUIFunction now deliberately returns no addon-callable
function for Forever, regardless of input style or whether both APIs exist. This
is a client policy, not a claim that the APIs are absent. Other clients retain the
current namespaced API and legacy fallback. No global or native API is replaced,
and the addon does not attempt another wrapper, secure-call workaround, automated
chat submission, timer reload or protected-action bypass.

- Mainhand HUD and Ellesmere import prompts use their existing manual instructions,
  offering no reload callback on Forever. The existing layout/profile is retained.
- After the guide's explicit window-position acknowledgement, its existing reload
  ticket and resume point are saved. The manual phase highlights /reload and hides
  the nonfunctional action button. The same-session issued ticket still prevents
  confirming placement before a new UI session.
- Calibration recovery saves the current wizard step, then opens an owned Mainhand
  instruction card. Its button is labeled Reload instructions; dismissing that
  card never requests reload.
- Three instruction strings are translated in all 11 dictionaries.

The instruction is to close the prompt and type /reload in native chat. Existing
HUD creation need not be repeated. Fresh tests of the next session and layout are
still needed; this change does not claim a native combat/taint acceptance pass.

## Validation

114 source Lua suites pass. 114 suites also pass with the packaged runtime. The
private harness supplies three development-only fixtures (two probe Lua sources
and package.ps1) needed by existing tests; tests and those fixtures are excluded
from the addon ZIP. New regression checks cover:

- no reload function offered for Forever when APIs are present;
- keyboard and controller HUD/import prompts without reload callbacks;
- an owned instruction card with dismissal only;
- saved guide/wizard resume tickets without API execution;
- confirmation locked in the same session and unlocked after a modeled UI restart;
- retained non-Forever namespaced/legacy paths and stale-click combat checks;
- all locale keys, placeholders and guide layout bounds.

All six manifests pass path/XML and Lua 5.1 syntax validation. No game interaction,
new HUD creation, native reload, combat/controller run or fresh taint-log capture
was performed for this candidate. The error screenshots are reporter evidence;
the new behavior has simulated and packaged evidence only.

## Artifact and install

Candidate: beta28-manual-reload-test1.
ZIP: dist/forever-manual-reload-20261109/Offhand-v2.1.5-beta.28-manual-reload-test1.zip
SHA256: 142e43f20bb03723bb8312abf288f06483972c7c0bd64f5fcc41c6fbb91e02bf

The ZIP contains 90 addon-only entries verified against staging. Versions and
Companion compatibility remain 2.1.5 / Beta 28; six private TOC titles/candidate
markers identify this test. No Companion binary, account state, QA addon, tests
or reference cache is shipped.

Installed at C:/Games/World of Warcraft/_forever_/Interface/AddOns/Offhand. The
released Beta 28 baseline was compared before installation (text line endings
normalized for the comparison); 22 scoped files were privately backed up and
replaced. Core/CompanionTopology.lua and Core/ForeverState.lua were preserved.
The temporary OffhandGuideQA addon remains absent. Changes take effect on the
next native /reload. This does not alter the already loaded old popup handler.


## One-click alternatives remain open

The manual policy is a fallback, not proof that all clickable reload methods are
unavailable. A follow-up source review identified the native secure macro-button
path as a candidate for isolated real-click testing. It remains unverified. See
docs/RELOAD-BUTTON-RESEARCH-20261109.md for primary source and evidence boundaries.
