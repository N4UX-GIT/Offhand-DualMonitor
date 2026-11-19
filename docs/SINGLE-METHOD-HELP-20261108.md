# Simplified in-game and Companion setup guidance

8 November 2026. Source-only help update from main 1df5e4b, following the website
single-method flow. The follow-up below also changes custom-editor entry. No native-window,
persistence, geometry, protected-frame or API behavior changes.

## User-facing changes

- Welcome and method selection explicitly say choose ONE placement method.
  Companion remains recommended for Windows; FancyZones and manual placement
  are alternatives, not additional numbered requirements.
- The method-selection title is now "Choose one setup method".
- The setup handbook uses one choice, only that method's placement instructions,
  and calibration in the same guide. It no longer presents independent placement
  as a numbered step after completing Companion placement.
- The calibration introduction says placement is already complete. Keep the
  chosen method rather than trying alternatives or restarting setup.
- Handbook references, custom workspaces, themes and backgrounds are optional.
- Companion Help uses the same three-stage flow, retains the explicit
  Span WoW Now / Reload UI / Confirm placement handoff and HUD requirements,
  and separates standard display choice from optional custom editors/plans.
- Companion README contains a short matching entry point.

Eight existing locale keys change. enUS, deDE, frFR, itIT, esES and esMX have
authored updated wording. koKR, ptBR, ruRU, zhCN and zhTW use explicit English
fallbacks for these changed paragraphs pending translation. Existing keys,
format arguments, color escapes and locale load order are preserved; duplicate
assignments for the changed keys are collapsed to a single effective definition.

## Evidence and limits

Shared knowledge README/research routing and status consulted; Offhand retrieval
contains supporting historical observations, not acceptance for new help copy.
The current UI/Onboarding.lua, UI/Wizard.lua, locale dictionaries, Companion
FillSetupHelp and website are the direct evidence for labels and flow. No new
WoW API or client/build-specific behavior decision is introduced.

All 109 existing Lua suites pass, including locale completeness, EFIGS translation
policy and matching format arguments. Generic addon validation passes six
manifests, 74 runtime Lua files and one XML file with Lua 5.1 compilation.
Companion preference and scaled-layout/help fixtures pass at 100%, 125%, 150%,
175% and 200% scale. These validate compilation, structure and dialog scrolling;
they do not prove live WoW text wrapping or native gameplay behavior.

Before shipping, inspect welcome, method choice, calibration intro and handbook
at supported in-game UI scales, including the longer German/French text. Confirm
the user can follow one method through placement and calibration without
switching or repeating a completed stage. No live game was launched for this task.

## Delivery boundary

The edits are a next-build source candidate. No tracked EXE, prepared binary,
release receipt, Store package, TOC version or installed WoW files are changed.
Existing frozen artifacts remain historical evidence for their original bytes.
Do not claim their hashes or acceptance cover the edited native help source.
The next Companion candidate needs its normal versioning, build, package and
delivery validation before publication. This change does not update an already
installed Microsoft Store app or publish an addon package.

## Standard-layout entry follow-up

Fresh preferences already select standard layout. The old chooser presented only
custom editors and focused its one-monitor editor; its "Two monitors" name could
be mistaken for normal full-monitor setup. The candidate now puts Keep standard
layout first and makes it the fresh-setup Enter action. Custom editors require a
separate optional opt-in, and the second-monitor action explicitly describes a
custom area. Existing saved custom layouts keep their mode and focus. Choosing
an editor does not write settings; keeping standard when already standard is a
no-op. Named profiles and geometry defaults are unchanged.

Dashboard status shows whether standard or custom layout is selected. Tooltips,
Help and README explain full-monitor setup, reasons to use custom areas and the
return-to-standard path. Reinstalling is not presented as a settings reset.

Regression fixtures cover missing preferences, the standard default, guarded
custom entry, deliberate custom selection and preference immutability. Rendered
chooser previews and scaled-layout fixtures check reachability and wrapping.
The next native build still requires the release and live-acceptance steps above.
