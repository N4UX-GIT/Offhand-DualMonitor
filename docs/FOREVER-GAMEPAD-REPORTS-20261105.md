# Forever Gamepad Discord reports, 2026-11-05

## Additional stock PlayerFrame report, 9037.jpg

Follow-up `9039.jpg` now identifies this session as Forever 1.60.1 build 70790,
Interface 16001, Offhand 2.1.2-beta.26 (without a candidate suffix). Companion
writer/paired version is beta.20, protocol 1, MATCH. Viewport bounds pass;
enabled/spanned/setup are all 1, combat is 0, Mainhand is LEFT. Physical displays
are two 2560x1440 rectangles, Mainhand (0,0), workspace (2560,0). The logical
canvas is 3900x1097, effective scale 0.700 and the split is 50 percent.
These are diagnostics, not a measured render-quality or native-action pass.

Preferred/active/generated layout is Offhand (2), active ID 5, matching and
geometry-current; recovery is none, LastFailure is none. These fields do not
mean the separate Lua error did not occur. Gamepad=no does not contradict its
stack: Mainhand.lua calls the Forever adapter at login/enter-world regardless
of interface mode, and its initial discovery scans hidden frames immediately.
The secret guard is still required in keyboard mode.

The version line identifies plain Beta 26 rather than the uniquely suffixed
guarded test candidates. With the earlier unpatched line-136 stack, this is
consistent with the known public-source defect, not a demonstrated candidate
regression. The diagnostic is not a package hash, and retained historical errors
remain distinguishable only by a fresh post-update test.

Compatibility reports WorldMapOwner=MoveAny, LeatrixMaps=loaded and OpenMap=loaded.
Thus this particular snapshot is not an all-other-addons-disabled baseline;
the reporter's isolated comparison may have been a different session. Their
presence does not establish a health-text cause or make these addons necessary
for the known secret-read failure. The compact diagnostic does not include
statusTextDisplay or per-bar text overrides, so the separate formatting claim
is still unresolved.

The reporter supplies 13 occurrences at `MainhandGamepad.lua:136`, with
`InspectText` called from line 196 in the globally enumerated-frame fallback.
The stack continues through radial discovery and adapter enable. The locals
identify Blizzard's `PlayerFrame.xml:209` HealthBarText, `ok=true` and a secret
string. This is the same OH-FOR-015 operation as the EUI/resource and other
unit-frame reports, not a different secret error or a proven map/loot failure.
It also establishes that an external unit-frame addon is not required.

The baseline at Beta 26 `9c7e83c` indexes `titles[value]` at line 136. The guarded
current source rejects secret/unreadable text before this lookup, including the
enumeration fallback. The combined Forever Discord test.2 addon archive
`Offhand-v2.1.2-beta.26-forever-discord.test2.zip`, SHA256
`46FFA54BFA0521D30AE85F7410C8F44BFCDEA1F7C5E9F10A4DF959B57042C696`, was opened
and its production module verified to contain that guard. The secret-text and
Mainhand placement suites pass. This new stack matches unpatched source; the
error screenshot alone did not identify the version. The subsequent diagnostic
identifies plain Beta 26; whether this is a retained historical BugSack record
still needs a fresh test. It is not a demonstrated failure of the candidate.

The screenshot separately claims Offhand adds HP/resource numbers and shows a
different numeric layout when disabled. In this stack, Offhand only calls
GetText on Blizzard's existing FontString. The inspected discovery path neither
creates a health label nor writes its text, so the exception does not establish
that claim. No direct `statusTextDisplay`, `showNumeric`, `showPercentage` or
native health-text override was found in the current addon runtime. The visual
comparison alone does not identify the exact frame/display state on each side.

Direct review of pinned Forever 1.60.1.70532 source at
`ca8368f2f2380cbe696854f7f2646387c278a61b` confirms
[PlayerFrame.xml:209](https://github.com/Gethe/wow-ui-source/blob/ca8368f2f2380cbe696854f7f2646387c278a61b/Interface/AddOns/Blizzard_UnitFrame/Mainline/PlayerFrame.xml#L209)
defines HealthBarText plus native LeftText/RightText labels. Native
[TextStatusBar.lua:154-180](https://github.com/Gethe/wow-ui-source/blob/ca8368f2f2380cbe696854f7f2646387c278a61b/Interface/AddOns/Blizzard_TextStatusBar/TextStatusBar.lua#L154)
selects text formatting from statusTextDisplay and per-bar overrides. Numeric
versus combined percentage/value rendering is therefore a native formatting
path to inspect, not a proven CVar change caused by Offhand. The shared status
and exact FontString declaration query were consulted; full-text retrieval was
stale and was not treated as evidence of absence. Follow-up diagnostics identify
reporter build 70790. A targeted local declaration query for that exact build
returns unknown; the cached 70532 declarations are supporting evidence only.
The supplied runtime stack remains the direct evidence for secret text on 70790.

Next step: install the current guarded candidate, restart/reload and distinguish
fresh errors from retained records. Keep native HP/resource text enabled. If
the visual discrepancy persists, capture `/offhand diag full`, exact build,
the frame identity on each side and `/dump GetCVar("statusTextDisplay")` in both
states. Preserve settings; do not force a status-text CVar or replace native
FontStrings to suppress an unrelated discovery error. No runtime changes were
needed for this additional instance of OH-FOR-015.

## Combined test round

The combined Forever Discord test.1 candidate now supersedes the separate
Gamepad test.2 for distribution. It includes those controller changes together
with the first-launch and character HUD checks. All 88 combined Lua suites pass;
native acceptance remains pending. See
[Combined Forever Discord test candidate](FOREVER-DISCORD-TEST-20261105.md) for
artifacts, checksums, test scope and rollback. The following test.2 section is
retained as its isolated source checkpoint.

## Isolated controller checkpoint: Beta 26, test.2

The first test.1 archive used the stale `3826dfe` checkout and did not contain
all Beta 26 changes. It is superseded and must not be distributed as current.
On the user's version query, the branch was fast-forwarded to freshly fetched
`origin/addon/develop` at `9c7e83c9757901f262d568941db56a7bf7272b6f`, the Beta 26
integration commit. Candidate changes were preserved in Git stash
`43e72c2b70ce175f1da3fe7f1f14eb9236c64425` and reapplied. The one diagnostic
conflict retains both Beta 26 LastFailure and candidate GamepadLoot fields.

Compared with that Beta 26 baseline, only these production files differ:
`Core/Canvas.lua`, `Core/CanvasForeverMap.lua`, `Core/CanvasMapPresentation.lua`,
`Core/MainhandEditMode.lua`, and `Core/MainhandGamepad.lua`. All other production
source, UI, locales and canonical manifests match Beta 26. This is a source
comparison, not just a renamed Beta 24 archive. Companion remains frozen.

Replacement: `dist/Offhand-v2.1.2-beta.26-forever-gamepad-test.2.zip`, SHA256
`3A6A66871F75516257B4BA72112CCC4448339826D76A3790E4EEE8601C0C211B`.
All 84 Lua suites pass on the corrected source. All 76 extracted files match
the snapshot, with runtime source parity and only staged TOC test identifiers
changed. Six extracted manifests pass Lua 5.1/path/XML validation; four targeted
suites pass against extracted production files. Snapshot and receipt:
`dist/forever-gamepad-test2-beta26-20261105-084445/`. Current instructions:
`dist/FOREVER-GAMEPAD-test2-INSTRUCTIONS.txt`. Live verification remains pending.

## Initial authorized candidate, test.1 (superseded)

Source branch: `addon/forever/gamepad-reports-20261105`, based on `3826dfe`.
All three changes are now implemented as a live-test candidate:

1. Reject secret/unreadable radial-menu text before comparison or lookup.
2. Yield Canvas map configuration, fading, content refocus, saved-position
   restoration, deferred settlement and keyboard drag controls to native Gamepad
   ownership. The existing Gamepad destination adapter remains the root position
   writer. Queued keyboard callbacks recheck ownership when they execute; the
   independent keyboard observer stays alive and resumes after a mode switch.
3. Correct real stock loot overflow within Mainhand during the first 0.5 seconds
   following LOOT_OPENED. LOOT_CLOSED or a mode transition cancels observation.
   The existing observer is reused; no permanent loot poller or native script/focus
   hook is added. Already-contained loot is not moved.

Loot correction uses effective frame/UIParent scales and the smallest root-anchor
translation needed. It does not change size/scale, reopen loot, persist a
corpse-specific anchor or add LootFrame to general panel movement. It skips
combat, Edit Mode, forbidden/protected/hidden roots, replaced native Open or
FocusGamepad methods, user-placed/reparented roots, unreadable or secret geometry,
oversized windows, ConsolePort and inactive/nonspanned clients. Blizzard's
`editModeManuallyShown` flag also persists on custom layouts outside Edit Mode,
so the candidate checks actual editing state instead. This distinction is
source-reviewed and regression tested.

The map audit found a concrete missing ownership guard: generic panel handling
already yielded, but the separate map observer and presentation entry points
could still configure the native map. The candidate removes those competing
writers. It is not yet proven to resolve the reporter's warning, whose first
error/taint trace and exact build are still missing.

All **84 Lua suites** pass, including new loot geometry/lifecycle cases and
expanded map tests that count attempted writes from queued callbacks, direct
calls and grips during Gamepad mode. Six manifests pass Lua 5.1/path/XML checks.
Highest evidence: source-reviewed and simulated. No live-client or protected-action
pass is implied. Source release metadata and Companion bytes are unchanged;
the standalone test package identifies itself separately.

Package: `dist/Offhand-v2.1.2-beta.24-forever-gamepad-test.1.zip`, SHA256
`1201CAE6AEE2501CACBBD77439C08004446CF23960CD1F59776123A3557F6E06`.
All 76 extracted files match the frozen snapshot. Runtime files also match the
working source; only staged TOC candidate identifiers differ. Four targeted
suites pass against the extracted addon, and all six extracted manifests pass
Lua 5.1/path/XML validation. Receipt and snapshot:
`dist/forever-gamepad-test1-20261105-082605/`. Installation and rollback steps:
`dist/FOREVER-GAMEPAD-test1-INSTRUCTIONS.txt`. This is a local test artifact,
not a public beta.26 successor or a Companion update.

## Scope and evidence

- The developer confirms the client is **Forever**. The screenshot's reference
  to a beta client must not route this report to Retail's beta branch.
- Browsebird names addon `Offhand-v2.1.2-beta.26` in the screenshots. The separate
  error report says the latest CurseForge beta, without an exact addon version.
  Do not assume both reporters have identical packages or addon environments.
- Exact reporter `GetBuildInfo()` tuples, locale, combat state and package bytes
  are unavailable. The error timestamp is 2026-11-04 19:23:40, count 1.
- Source inspected: `codex/professions-quest-ui`, baseline `3826dfe`. This checkout
  advertises beta.24 and has the extracted `Core/MainhandGamepad.lua` module.
  The supplied error comes from the older combined `Core/Mainhand.lua` layout.
  The failing operation still exists in this checkout. This is not a byte-level
  comparison against the reporter's beta.26 archive or a latest-CurseForge check.
- Attachments: `Screenshot_20261105-063630.jpg`, `9008.jpg`, `9009.jpg`. FrameStack
  overlays identify highlighted areas. Follow-up `9011.jpg` and `9012.jpg`
  identify the loot window as `LootFrame`; `9013.jpg` identifies the map's
  `WorldMapFrame.BorderFrame` and quest-pane descendants. The warning itself
  still has no readable stack.
- `9014.png` is explicitly from a different user. It shows 15 occurrences at
  `MainhandGamepad.lua:136`, with `Mainhand.lua:126` calling the adapter. The
  locals show an owner from `Unitframes.lua:499`, a FontString from
  `Style.lua:2098`, `ok=true` and a secret string. The addon owning those two
  files is not established. This is independent evidence, not a patched-build
  retest or proof of a shared package/build.

## OH-FOR-015: Secret text used as a radial-menu lookup key

The supplied stack establishes a direct Offhand error. Menu discovery successfully
calls `GetText()` on a FontString created by `EUI_ResourceBars_Frames.lua`, receives
a secret string, then indexes `titles[value]`. Checking `type(value)` and wrapping
only the getter in `pcall` does not make that returned value usable as a key. The
same problem applies to `options[value]`. EUI is the encountered text owner;
this evidence does not establish an EUI defect or require EUI to be disabled.

The second user's `9014.png` matches the extracted baseline exactly:
`MainhandGamepad.lua:136` is `titles[value]`, and the stack reaches it during
`EnableForeverGamepadMainMenuAdapter`. This confirms the same flaw survives
the module extraction and can encounter text outside the original EUI resource
bar. The local guard also covers this path. No evidence says this screenshot
was taken with the candidate installed, so it is not a candidate failure.

The current module scans UIParent descendants and then globally enumerated
frames. Startup also requests hidden-frame discovery. Thus unrelated resource
text can be encountered before the radial is found. An exception there interrupts
that adapter call; it does not prove that the separate map focus failure has the
same cause.

The working candidate checks `issecretvalue` before comparing or indexing text.
Secret values and failed secret inspections are skipped. The same guard protects
localized label-set insertion. Clients without the detector retain the existing
ordinary-string behavior. No native frame fields, scripts or focus hooks are
added by this change.

`tests/forever-gamepad-menu-secrets.lua` covers child traversal, enumeration,
secret headings/options/localized globals, failed text getters, invalid values,
failed detection, valid discovery after unrelated secret text, and the legacy
absence of the detector. The new suite fails against the original module and
passes against the candidate. Its marked ordinary strings model the rejection
decision; Lua 5.1 cannot recreate native secret-string enforcement.

Initial guard-only validation: all **83 Lua suites** pass. All **six manifests**, runtime paths,
XML references and loaded Lua files pass the Lua 5.1 validator. Evidence level:
reported runtime failure plus source-reviewed/simulated correction, awaiting
live Forever verification. At that initial guard-only stage, no deployment,
archive, release or Companion change was made. The authorized candidate above
now supplies a separately identified local test archive.

## OH-FOR-016: Clicking outside the map leaves an undismissable warning

Reporter sequence: native controller UI enabled, open the map, click outside
its window, receive a warning that cannot be dismissed, reload required.
`9013.jpg` now identifies the map root and quest-pane hierarchy:
`WorldMapFrame.BorderFrame.NineSlice`, `QuestMapFrame.QuestFrame`,
`QuestScrollFrame`, and the map's ScrollContainer. The frame inspector selects
border art from `Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml:573`;
that source location is not an error stack or a new panel to move independently.
The blocked operation remains unclassified. The earlier loot placement image
is now tracked separately under OH-FOR-017.

The `Mainline` directory in the native source path does not change the confirmed
Forever client identity. `OffhandCanvasFrame` entries appear in the background
stratum; their presence in a frame stack alone does not attribute a focus error.

Upstream Forever `FrameControlsManager` routes a world click with no UI region
through `OnGlobalRegionMouseDown` to `SetUIFocusState(false)`, subject to focus
and cursor state. That method invokes native unfocus/end-focus handlers and
refreshes focus. A click on a different UI region follows a different focus
selection path. This is a source-backed reproduction target, not proof of which
branch ran for this reporter or of the first Offhand contamination.

Current source already blocks generic addon panel management, UISpecialFrames
changes and UIPanel slot eviction while native Gamepad UI is active. The map
adapter uses external controls rather than replacing native map scripts. Existing
map and Back-binding tests pass. These boundaries do not establish live taint
safety, nor prove that the reporter's package contains the same implementation.
The subsequent authorized candidate adds ownership guards described above,
without replacing the native focus-manager or popup handlers.

Needed evidence: the first fresh Lua/protected-action error and complete stack,
the exact Forever build and addon version, and a fresh taint trace if only a
blocked-action popup appears. Record whether the click hits the world or another
UI frame, how the map was opened (M, L or radial), and whether it had been moved.
Retest with Offhand plus its usual UI addons, then with Offhand disabled after
reload to isolate attribution without deleting saved settings.

## OH-FOR-017: Native loot window crosses the Mainhand seam

`9011.jpg` identifies `LootFrame` and its NineSlice, ScrollBox, item and shadow
descendants, with selected art from `SharedUIPanelTemplates.xml:484`.
`9012.jpg` shows the actual Items/4 Copper window crossing the physical seam.
This is the ordinary loot window, separate from group-loot roll prompts and
the earlier Loot Edit Mode focus exception (OH-FOR-011).

Read the pinned Forever
[LootFrame.lua Open path, lines 225-274](https://github.com/Gethe/wow-ui-source/blob/ca8368f2f2380cbe696854f7f2646387c278a61b/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/LootFrame.lua#L225)
directly because it is outside the selected local implementation corpus. When
either loot-under-mouse or native Gamepad UI is enabled, Blizzard gets cursor
position, converts by effective scale, subtracts 30 from x, applies a y floor,
and directly positions/shows the root. Only the other branch uses ShowUIPanel
and ApplySystemAnchor. Thus disabling loot-under-mouse or changing the Loot
Edit Mode anchor alone does not bypass this Gamepad placement branch in the
reviewed build.

This provides a concrete source mechanism consistent with a seam-crossing loot
window near Mainhand's left edge. The report does not include the original
cursor position, root geometry or exact build, so this remains a source-backed
explanation to verify, not a measured reproduction. The secret scan exception
does not itself explain this cursor-derived native anchor.

Offhand deliberately excludes LootFrame from its Gamepad destination mover;
the existing regression enforces this after the prior protected focus issues.
Do not add it to the ordinary panel list or overwrite its Open/FocusGamepad
handlers as an incidental fix. A candidate would need a narrowly owned geometry
path that accounts for cursor placement, preserves loot/focus lifecycle and
passes live loot selection, autoloot, Edit Mode, close, combat and taint checks.
The initial investigation introduced no loot mutation. The subsequently
authorized candidate uses the bounded stock-root correction described above;
the ordinary destination-panel exclusion and native focus handlers remain.

Next capture: exact build, active Gamepad setting and cursor/root coordinates
immediately after opening loot near each Mainhand edge and in its center.
Compare after reload with Offhand disabled. Keep OH-FOR-015/016/017 separate
until runtime evidence establishes any shared cause.

## Research provenance and remaining checks

The shared knowledge README/research skill, `status`, a Forever `ask`, and exact
`api issecretvalue --client forever` query were consulted. Full-text `search`
reported a stale index, so it was not treated as an absence result. The structured
query returned declarations for Forever **1.60.1.70532**, source revision
`ca8368f2f2380cbe696854f7f2646387c278a61b`, retrieved 2026-10-29:

- [FontString GetText, lines 352-365](https://github.com/Gethe/wow-ui-source/blob/ca8368f2f2380cbe696854f7f2646387c278a61b/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFontStringAPIDocumentation.lua#L352)
  declares secret text returns. Button GetText has the corresponding declaration.
- [issecretvalue, lines 286-302](https://github.com/Gethe/wow-ui-source/blob/ca8368f2f2380cbe696854f7f2646387c278a61b/Interface/AddOns/Blizzard_APIDocumentationGenerated/FrameScriptDocumentation.lua#L286)
  declares the detector. These declarations are not target-client execution tests.
- The selected local corpus lacks the focus-manager implementation. Read directly
  from the same immutable upstream revision:
  [FrameControlsManager, lines 602-694](https://github.com/Gethe/wow-ui-source/blob/ca8368f2f2380cbe696854f7f2646387c278a61b/Interface/AddOns/Blizzard_GamepadSharedUtility/FrameControlsManager.lua#L602).
- Native stock root and persistent custom-layout flag were checked directly in
  [LootFrame.xml](https://github.com/Gethe/wow-ui-source/blob/ca8368f2f2380cbe696854f7f2646387c278a61b/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/LootFrame.xml)
  and [EditModeLootFrameSystemMixin.ApplySystemAnchor, line 2337](https://github.com/Gethe/wow-ui-source/blob/ca8368f2f2380cbe696854f7f2646387c278a61b/Interface/AddOns/Blizzard_EditMode/Shared/EditModeSystemTemplates.lua#L2337).

Live acceptance for OH-FOR-015: clean reload on the reported Forever build with
EUI resource bars present; enable native Gamepad, open/navigate the radial, switch
keyboard/Gamepad modes, and repeat after combat. Verify discovery and Mainhand
placement, fresh errors and taint. Independently repeat the exact map click-away
sequence, close/refocus with mouse and controller, and inspect the first failure.
Passing discovery alone must not close OH-FOR-016.

For test.1, repeat map open via M, L and radial; click the world and other UI
frames; use B, Escape, close and refocus; switch keyboard/Gamepad without reload.
Verify Gamepad map placement and return of the keyboard grip. Inspect fresh taint
and the first error if a warning remains. For loot, open actual loot near every
Mainhand edge and center, including scaled/stacked layouts; select items,
exercise autoloot/full bags, close/reopen, enter/exit Edit Mode, and repeat around
combat. Diagnostics include `GamepadLoot=<status>` in the existing Mainhand report.
`protected`, `external-owner` and `oversized` mean the candidate yielded, not
that overflow was corrected. Keep existing saved settings.
