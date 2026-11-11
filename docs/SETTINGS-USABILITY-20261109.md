> Reload follow-up: the API fallback below was not sufficient for Forever.
> Reporter protected-action evidence and the Beta 28 manual handoff correction
> are recorded in docs/FOREVER-MANUAL-RELOAD-20261109.md.

# Settings and HUD reload usability, 2026-11-09

Private Guide & Wizard Test 11 is packaged and installed, not published.
The Test 10 history is retained below; the current header/lock follow-up follows it.

## Report and scope

The user reported that the owned post-HUD Reload UI button did not reload, and
requested header Website/Discord links, clearer tab names and useful section
priority. A subsequent request added a Crafted by: N4UX credit after the version.
Native reproduction of the failed reload was not performed in this follow-up.

## Reload behavior

Core/ClientRuntime.lua resolves C_UI.Reload when available, with the global
ReloadUI fallback for older supported clients. No global function is replaced.
The HUD reload callback resolves the capability at the click boundary and rechecks
combat and native controller ownership. Changed or unavailable state returns a
manual /reload notice. The guide, calibration recovery and Ellesmere handoff use
the same capability resolver; existing lifecycle and controller restrictions stay
in place. The generic manual HUD notice no longer asserts controller mode as the
only reason manual reload may be needed.

The cached Forever API declaration was build 70532 and review-due. Exact build
70862 primary documentation at Gethe/wow-ui-source revision
9dc84f0d3bbae1768ac3405b3716000bd93eda06 declares C_UI.Reload in
Interface/AddOns/Blizzard_APIDocumentationGenerated/UIManagerDocumentation.lua.
That revision's GameDialogDefs.lua also contains ReloadUI calls. These are source
declarations/callsites, not evidence that the legacy global was absent in this
user's session, or that either API bypasses controller or protected-action rules.
The change removes the legacy-only assumption; native success remains pending.

Primary documentation:
https://github.com/Gethe/wow-ui-source/blob/9dc84f0d3bbae1768ac3405b3716000bd93eda06/Interface/AddOns/Blizzard_APIDocumentationGenerated/UIManagerDocumentation.lua#L59

## Header and settings organization

The version row now sits below Offhand's name and reads, for example:
v2.1.3 (Companion v2.1.3) | Crafted by: N4UX.
Actual addon/paired Companion versions still come from metadata. The tagline stays
below this row, with Website and Discord buttons beside the contained close X.
The version tooltip remains attached to its text. Link buttons open the existing
owned address card, selecting the official URL for copying into a browser. No
browser launch or external Discord message is attempted.

Official destinations are reused from the repository website and TOC:
https://offhand-wow.onrender.com/ and https://discord.gg/J2P3SM6pAY.

Tabs are Display & HUD, Offhand Monitor, Appearance, Profiles, Help & Setup.
All 11 dictionaries include new text and the author credit. The language-neutral
Discord brand is explicitly allowed by the existing translation audit.

- Display: layout/orientation, Mainhand geometry, alignment/UI size, motion clarity,
  world text, group loot, remembered window, advanced bezel gap, OBS.
- Offhand Monitor: map scale/navigation, ordinary window behavior, window controls,
  recovery, automatic panel routing, then any advanced compatibility disclosure.
- Appearance: overall theme/trim/background/media before per-workspace overrides.
- Profiles: existing profile sections preserved.
- Help & Setup: shorter setup overview, Window Setup and calibration actions, plus
  a navigation shortcut to the existing recovery section. The duplicate placement
  button and immediate recovery action were removed from this overview.

Stable tab IDs and saved settings remain unchanged. Sidebar shortcuts follow the
actual stacked card positions. The recovery shortcut navigates without moving
windows or rebuilding a HUD.

## Verification and package boundary

104 root suites and 111 combined packaged suites pass under Lua 5.1. Regressions
cover modern-only reload, legacy fallback, missing APIs, combat/controller changes
between showing and clicking, header destinations/author credit, useful card
priority, recovery navigation, scrolling, and existing setup activation. FontString
mocks gained the native SetHeight surface. The combined partial Mainhand fixture
retains its accepted observer targets; root-only flight/mail investigations were
not imported into this scoped candidate. All six manifests pass path/XML/Lua 5.1
syntax checks. No native HUD was created or rebuilt for these tests.

Test 10 is based on Test 9, preserving the accepted newer workspace and ordinary
Next span activation behavior. Only 24 scoped runtime/locale/TOC files changed;
all live baseline files were compared before replacement and privately backed up.
Generated CompanionTopology.lua and ForeverState.lua were preserved. The ZIP has
88 addon-only entries, byte-verified against staging. No test, QA helper, account
state, shared knowledge cache or Companion binary is included.

ZIP: dist/guide-wizard-live-20261109/Offhand-v2.1.3-beta.27-guide-wizard-test10.zip
SHA256: 9bad4d9144ad72d3a94738e80edd745bc8d3edc8c1f9fd903e3ed9e1e7a17380

Native status: reload required to load Test 10. Visual header/translation fitting,
HUD Reload UI click, and the existing placement flow need in-game acceptance.
No desktop interaction, combat/controller run or new taint-safety claim occurred
in this follow-up. OffhandGuideQA remains absent from live AddOns.


## Test 11: header alignment and unavailable lock controls

The user's screenshots showed the slogan on a third header line and an unavailable
Forever window-lock section taking most of a card. The header now reads
Offhand | Dual-wield your monitors. on its first row. Versions and localized N4UX
credit share one larger, brighter second row. Website, Discord and the contained
close X retain their positions. The version tooltip still covers its text.

Policy review: Core/WorkspaceBehavior.lua IsLockSupported explicitly returns false
for Forever. tests/workspace-behavior.lua asserts that Forever cannot enable the
stronger lock or advertise a native frame as locked. The 2026-10-14 QA ledger
records automated non-Forever coverage and the deliberate Forever exclusion; no
later dedicated Forever acceptance was found. This does not establish native
combat/taint safety. The stronger lock is distinct from the existing independent
panels, Escape persistence, reload persistence, and placement locking.

The settings card now follows the existing capability policy. When unsupported,
it creates only a compact 100-unit Character window scaling section, with no
lock master checkbox, disabled categories or testing-status paragraph. Supported
clients retain the original full lock controls. Refresh handles absent widgets
and respects an explicit false capability rather than overriding it with a
non-Forever fallback. No underlying lock policy, native frame, saved preference
or persistence behavior was changed. The Character window title is localized in
all 11 dictionaries. Old locale keys remain for compatibility.

104 root and 111 combined packaged Lua 5.1 suites pass. New assertions cover the
inline title/slogan anchor, readable version height, absence of the unsupported
Forever checkbox, compact card height, and retained supported-client lock UI.
The existing real lock/scaling policy suite remains passing. Six manifests pass
paths/XML/Lua 5.1 compilation. The large settings refresh stays within Lua 5.1's
upvalue limit.

Test 11 changes UI/Options.lua, 11 locale dictionaries, and six private manifest
markers from Test 10. The six X-Offhand-Candidate fields now accurately identify
Test 11, correcting the older inherited Test 8 marker. All 88 ZIP entries match
staging. Live files matched Test 10 before replacement and were privately backed
up. Generated bridge files and the accepted newer workspace/span runtime remain
unchanged. The temporary QA addon remains absent.

ZIP: dist/guide-wizard-live-20261109/Offhand-v2.1.3-beta.27-guide-wizard-test11.zip
SHA256: cc9f2cbed01cffe8c97e1be1d5af019bb5c07adcdb2e64b188d91cd149946be6

Native status: installed, requires /reload and visual review. The user screenshots
are Test 10 evidence. No desktop interaction or new native lock, combat/controller,
HUD creation or taint test was performed for Test 11.


### OH-UI-025 follow-up: native reload click verified, 2026-11-09

Supersedes the blanket manual-only fallback above. Forever 1.60.1.70862 keyboard/
mouse reproduces the blocked call when the owned popup hides first; callback-first
and the actual production HUD completion prompt both perform real UI reloads.
Reload dialogs opt into callback-before-hide, with generation protection for
replacement cards. Other callbacks retain their lifecycle. Controller UI remains
manual; combat activation and other builds are unverified. 114 source suites pass.
Private helper removed and final clean reload completed; client closed normally.
Current BugGrabber contains only the one intentional comparison failure from this
run, with no later error. Taint log is stale. See docs/RELOAD-BUTTON-RESEARCH-20261109.md.
