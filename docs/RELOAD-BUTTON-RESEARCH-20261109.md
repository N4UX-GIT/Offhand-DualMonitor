# One-click reload alternatives, 2026-11-09

## Native reload-button follow-up, 2026-11-09

Supersedes the earlier all-Forever manual-only policy. On Forever 1.60.1 build
70862 (interface 16001), keyboard/mouse UI, a real click on the existing owned
popup reproduced ADDON_ACTION_BLOCKED when Finish hid the parent first. Moving
that callback before Hide produced a real loading screen and return to world.
The final production Mainhand:PromptReload dialog also reloaded successfully.
No HUD layout was created or replaced for this focused prompt test.

The production change opts reload confirmations into callback-before-hide.
Ordinary confirmations retain their existing lifecycle. A generation check keeps
replacement/reopened cards visible when a callback changes input mode or enters
a fallback. No secure button or protected ancestry is added to the shared card.
The native secure macro probe also worked, but is unnecessary for this fix.

Forever keyboard/mouse uses C_UI.Reload with the existing ReloadUI fallback.
Controller UI keeps manual instructions pending a dedicated native activation
test. Combat and stale-click checks remain. The guide's span/reload/placement
checkpoint is unchanged: a request alone cannot unlock confirmation.

Validation: 114 source Lua suites pass, including callback visibility, ordinary
hide-first lifecycle, replacement-card preservation, cancel behavior, missing API,
controller/combat fallback and modeled new-session placement guards. Native tests
were out of combat only, on Noggaholic in Valley of Trials, without movement or
NPC interaction. The test window was unspanned; no new span/topology acceptance
is claimed. Controller activation, combat transition clicks and other builds
remain separate verification gaps.

Error evidence after normal client exit: !BugGrabber retained the earlier
02:56:36 report and exactly one new private hide-first comparison error at
20:55:52, session 25, count 1, nativeReload(). There were no later captured errors
through 21:00:18, including callback-first and production HUD reload. The taint log
was unchanged from 2026-11-08 17:45:54, so it is stale, not a fresh taint pass.
The private slash/probe was removed before the final HUD button reload; its clean
source loaded on return to world. The target client was closed normally afterward;
Battle.net and unrelated windows were left open. No account/configuration reset,
Companion rebuild, public upload or publication occurred.

## Earlier source-only investigation

Scope: source investigation requested after the Forever Beta 28 blocked reload
report. No runtime code, installed candidate or package was changed in this turn.
The reporter trace establishes that the existing owned-popup Lua callback was
blocked. It does not establish that all player-clicked reload paths are impossible.
The installed manual handoff remains a fallback while alternatives are unverified.

## Primary source

Reviewed Gethe/wow-ui-source revision 9dc84f0d3bbae1768ac3405b3716000bd93eda06,
previously identified as Forever 1.60.1.70862. This is a pinned source identity,
not a fresh read of the available client's current build. Local hashes/URLs are
recorded in dist/reload-button-research-20261109/sources.json. Downloaded upstream
source was inspected only, never executed or added to an addon package.

1. Blizzard_FrameXML/SecureTemplates.xml:4-8 defines SecureActionButtonTemplate
   with Blizzard's own SecureActionButton_OnClick. Its comment says addons do not
   receive the extra isKeyPress/isSecureAction flags. Inheriting the template does
   not authorize an arbitrary Lua callback or grant those flags.
2. SecureTemplates.lua:422-434 supports the precompiled macro action, reading macro
   or macrotext attributes and invoking the native macro runner. A fixed /reload
   macro on an actual user-clicked secure button is a credible candidate to test.
   Keep the inherited OnClick handler, create/configure outside combat and avoid
   dynamic secure snippets or a scripted Button:Click as the test input.
3. Blizzard_ChatFrameBase/Shared/SlashCommands.lua:1338-1340 registers /reload
   through the general slash-command utility and calls ReloadUI. This does not
   prove that executing that command from an addon-owned secure macro retains the
   permission of a manually entered chat command. Native verification is required.
4. Blizzard_AddOnList/AddonList.lua:574-580 uses Blizzard's own OnOkay function,
   hides its window, then calls ReloadUI when shouldReload is set. This shows a
   native UI click path, not permission to call it from addon code or to modify
   its protected ancestry. It also means hiding before reload alone cannot be
   declared the cause of Offhand's failure from source inspection.

The exact-build source includes C_UI.Reload, but API existence is already known
and cannot resolve the missing runtime permission evidence. A historical primary
bug report, Stanzilla/WoWUIBugs#62 (9.0.5.37503), describes OnClick hardware-input
recognition failing while other mouse handlers worked, then being fixed. This is
historical evidence only and does not establish the same defect on Forever.
Secondary guides surfaced in search were not used to establish client behavior.

## Native comparison still needed

- Control: manually enter /reload and record the exact current build/input style.
- A minimal owned button calling the native API directly from a real click, with
  no popup hide/reuse/other callbacks first, isolates the current Finish path.
- A precompiled SecureActionButtonTemplate with type=macro and fixed macrotext
  /reload isolates the supported macro action. No arbitrary secure-code wrapper.
- If necessary, compare an ordinary mouse-up handler as a separate hypothesis.
  Historical input-handler bugs are not evidence that this route works now.

Use one physical activation per attempt, outside combat, with fresh BugGrabber
and protected-action evidence. A successful reload must actually restart the UI;
calling a mock, hiding a panel or receiving no Lua return error does not count.
Controller activation and combat behavior remain separate follow-up dimensions.
Do not change the default button until a candidate passes this native comparison.

No new live run occurred. The conclusion is that one-click reload remains an open
engineering possibility, with a concrete native-template path to investigate.

## Private candidate

beta28-reload-click-test1 is packaged and installed locally. Both source and
packaged-runtime runs pass all 114 Lua suites. All six manifests, nested XML
references and 78 runtime Lua files validate with Lua 5.1. The ZIP has 90 entries
and matches staging byte for byte; no private probe, tests or knowledge cache is
included. Runtime installation matches the candidate; generated Companion bridges
are preserved. Companion artifacts are unchanged. Nothing has been published.

Artifact: dist/reload-button-live-20261109/Offhand-v2.1.5-beta.28-reload-click-test1.zip

SHA-256: 970a8e014c4568e5867427f593bba1f8f64d8d7def6b7d903a2b2a8a15881cbe

Structured evidence: dist/reload-button-live-20261109/native-evidence.json.
