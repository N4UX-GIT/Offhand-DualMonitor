# Retail cutscene and contextual UI report, 31 October 2026

Status: developer reports the deployed candidate appears resolved on the local
new-character intro. Supplied screenshots verify Mainhand picture, subtitle and
skip-confirmation placement. Broader lifecycle/combat verification and the original
reporter's original vehicle reproduction remains pending.

## Premade Groups reporter follow-up

Additional screenshots supplied before test-build confirmation independently
identify the highlighted sign-up window through /fstack as
LFGListApplicationDialog and LFGListApplicationDialog.Border, with native source
Interface/AddOns/Blizzard_GroupFinder/Mainline/LFGList.xml:1945. The reporter says
this affects Premade Groups > Dungeons sign-up for Mythic groups, while regular
Dungeon Finder appears correct. This matches the candidate's targeted root.
These images predate the test package and must not be treated as a post-fix pass
or regression. Reporter confirmation remains pending.

The additional photos identify LFGListApplicationDialog (Choose Your Roles/Sign Up)
and LFGListInviteDialog (Accept/Decline). Full diag: Retail 12.1.5 build 70688,
Interface 120105, addon Beta 24, Companion Beta 20/MATCH, 3840x1080 canvas, equal
1920x1080 displays, Mainhand RIGHT, scale 0.700, combat=0. PVEFrame is hidden in
that snapshot, so the diag is not itself the open-photo state. Extra Action is
inactive and override roots are hidden; active vehicle controls remain unverified.

Pinned upstream LFGList.lua/.xml and StaticPopup.lua establish shared special-popup
placement: first dialog TOP-to-fullscreen-TOP, later dialogs TOP-to-previous-BOTTOM.
The local native collapse function removes hidden entries without necessarily
rebuilding surviving anchors. Application note entry uses a secured edit box.
Source revision 15881d522c44cd106d3d8660106ec9f9d2f44167 identifies build 70575,
distinct from reporter build 70688; paths and transfer limits are recorded in QA.

Candidate uses external secure post-hooks of StaticPopup_SetUpPosition,
StaticPopupSpecial_Show and StaticPopupSpecial_Hide to translate only known
UIParent TOP stack roots into Mainhand. Linked dialogs and hidden anchor dependencies
remain intact. Native visibility, notes, roles and buttons retain Blizzard ownership;
no scripts/fields are attached to these dialog trees. Protected/forbidden roots and
alternate parents yield. Still-owned points restore on end/disable/unspan. Both
roots are excluded from generic dragging and included in full diagnostics.

All 67 Lua suites and six-manifest validation pass. Four relevant modules were
deployed and hash verified in local Retail; installed Lua 5.1 validation passes.
Backup/inventory:
`D:/Games/World of Warcraft/_offhand_deploy_backups/retail-premade-dialogs-20261031-170648-665`.
Other pending source changes were not deployed; bridges, SavedVariables, Companion
and other clients were preserved. /reload then retest native sign-up/note entry,
accept/decline, simultaneous dialogs, close/reopen, restoration and combat/taint.

Local visual evidence, 31 October 2026: the two supplied 4000x2560 screenshots
`codex-clipboard-cd0ad957-0e42-4e11-b305-5abb06167d93.png` and
`codex-clipboard-01e788db-a94f-4955-a3d0-f9877a46680b.png` show the dwarf intro
picture confined to Mainhand, subtitle text/background fitting in both one and
two lines, and Blizzard's native Yes/No confirmation centered in Mainhand.
The developer reports "Appears to be resolved." This is a user-reported local
visual pass, not an agent-operated test. Button activation, standalone movies,
playback-end restoration and current taint evidence are not established by still
images. The earlier pending-live statements below describe the pre-retest stage;
the remaining matrix still applies beyond this demonstrated intro.

Deployment update: at the user's request, the current candidate was copied to
`D:/Games/World of Warcraft/_retail_/Interface/AddOns/Offhand`. Ten differing files
were updated; all 74 non-generated addon files match source by SHA256 and installed
six-manifest path/XML/Lua 5.1 validation passes. Both generated bridges were preserved
by hash. Backup and deployment inventory:
`D:/Games/World of Warcraft/_offhand_deploy_backups/retail-cinematic-20261031-162624-141`.
No other client, SavedVariables or Companion update. Live retesting remains pending.
Earlier statements about no installed update describe the pre-deployment stages.

## Mainhand playback candidate

The requested single-monitor presentation is implemented for Retail in
`Core/CinematicPresentation.lua`, loaded after `RetailFullscreen.lua` in all six
manifests (inactive on other clients). It constrains visible `CinematicFrame`,
`MovieFrame` and `SubtitlesFrame` roots to Mainhand without reparenting or changing
native input, visibility, playback, subtitle settings or text.

The native cinematic aspect-ratio updater still uses the full physical canvas
for parts of its calculation. An external secure post-hook corrects WorldFrame
to Mainhand-local legacy letterbox, 16:9 or 2.4:1 bounds. The regular viewport apply
path reapplies that correction so display/layout recovery does not erase it.
Legacy bars retain their native minimum height. Subtitle text/background widths
are bounded for narrow displays, using the native text-fit method after a width
change. Font selection and subtitle CVars are preserved.

Frame anchors and changed dimensions are restored on end/disable/unspan only when
they still match Offhand's applied state. Native refreshes establish a new baseline;
later external placements are preserved on release. Protected/forbidden roots are
excluded. Combat writes defer through the existing queue and evaluate current
state afterward; live combat-time presentation is not claimed. Bounded event retries
cancel older generations, with no new ticker or frame-tree scan.

Additional upstream inspection at pinned revision
`15881d522c44cd106d3d8660106ec9f9d2f44167` resolved the earlier subtitle selection
gap: `Interface/AddOns/Blizzard_Subtitles/Blizzard_Subtitles.lua` and `.xml` define
the independently anchored SubtitlesFrame, its native AddSubtitle transaction,
Subtitles array and background. These were fetched as source text from the pinned
upstream after locating their paths in its Git tree, without executing upstream
code or including it in the addon. `Blizzard_SharedXML/SecureUtil.lua` documents
the native ScaleTextToFit implementation. They establish source behavior only.

Validation: all 65 Lua 5.1 suites pass; six manifests pass path/XML/Lua syntax
validation. `tests/cinematic-presentation.lua` covers physical Mainhand bounds,
scale conversion, portrait and wide layouts, native camera ratios, subtitle width
and refitting, native refresh, restoration, external ownership, combat coalescing,
stale retries and non-Retail isolation.

Live retest remains required on the local 4000x2560 setup: create a character and
check image, bars, subtitle background and text, Escape/Yes/No; then exercise a
standalone movie and long subtitles. Include resize/unspan, disable, end/return to
normal gameplay, a narrow/portrait Mainhand, combat deferral and current taint logs.
No installed addon or native Companion binary was changed.

## Local reproduction and source candidate update

The developer confirms the failure when creating a new character on their local
machine. The attached 4000x2560 screenshot shows the dwarf intro in the lower-right
gameplay region, with subtitles extending to the left outside that region. It does
not show a skip confirmation or establish whether Escape reached Blizzard. Exact
client build, installed package bytes, key sequence and taint evidence are still
unrecorded. This is a user-reported local reproduction, not an agent-observed pass.

The candidate in `Core/Init.lua` enables the existing native dialog recentering for
Retail as well as Forever, adds PLAY_MOVIE attachment with the same bounded retries,
and preserves enabled/span/visibility/scale and forbidden/protected checks. It
does not replace input handlers or invoke confirmation/cancellation. Full diagnostics
now include the last skip-dialog recovery status; compact diagnostics stay compact.
Subtitle layout was unchanged at this stage; the subsequent Mainhand playback
candidate above adds that handling. No installed addon was updated.

All 64 Lua 5.1 suites pass, including the new `retail-cinematic-dialog.lua` simulation
for late movie creation, native ownership, mixed-height geometry/scale and excluded
states. Six manifests pass paths, XML references and Lua 5.1 syntax validation.
These do not establish a live fix or combat/taint safety. Retest Escape, native Yes
and No, a standalone movie, disabled/unspanned state and combat where applicable.

The initial source findings below describe the pre-candidate behavior.

The Discord report describes cutscenes that cannot be skipped, dungeon acceptance
prompts near the monitor seam, and vehicle-specific controls in unsuitable places.
Retail is suspected; exact client/build, installed Offhand release, display topology,
active Edit Mode layout and replacement addons have not yet been supplied.

## Source scope and evidence

- Local checkout: `codex/professions-quest-ui`, HEAD `2e5c008`, tagged
  `v2.1.2-beta.23`, with substantial pre-existing uncommitted work. Working manifests
  identify the addon candidate as Beta 24. Findings about this checkout do not
  identify the reporter's installed package.
- Shared knowledge status: `blizzard-live` revision
  `15881d522c44cd106d3d8660106ec9f9d2f44167`, within its review window.
  Its `version.txt` identifies Retail `12.1.5.70575`. This is the reference snapshot,
  not a confirmed reporter build. The search index was stale at investigation time;
  a rebuild completed (48,839 passages), but a follow-up search still reported a
  stale index after this finding was added to shared knowledge. The question router returned unknown, with no exact
  declaration symbol. Conclusions below come from direct source inspection.
- Blizzard implementation evidence: `Interface/AddOns/Blizzard_FrameXML/Shared/`
  `CinematicFrame.lua` and `.xml`, plus `Blizzard_FrameXML/MovieFrame.lua` and `.xml`
  at that pinned revision. Mirror:
  <https://github.com/Gethe/wow-ui-source/tree/15881d522c44cd106d3d8660106ec9f9d2f44167>.
- Existing Forever live evidence is recorded under OH-UI-001. It does not establish
  Retail behavior or protected-action safety.

## Cutscene findings

1. Blizzard's cinematic key handler resolves the Game Menu binding and shows
   `CinematicFrame.closeDialog` only for a cancellable cinematic/scene/vehicle.
   The confirmation button retains Blizzard's stop/scene-cancel/vehicle-exit action.
   Some scenes are intentionally not cancellable.
2. Movie playback is a separate path: `MovieFrameMixin:OnKeyUp` opens
   `MovieFrame.CloseDialog`; `PLAY_MOVIE` and `STOP_MOVIE` drive playback.
3. Both XML dialogs default to the center of their full-screen parent. On a spanned
   window, that center need not be the center of the physical gameplay display.
   A dialog at the seam or in a physical void is a plausible explanation for
   apparent failure to skip. Receipt of the key and actual dialog visibility on
   the reporter's machine remain unverified.
4. `Core/Init.lua` already resolves both dialog variants, but
   `CenterCinematicSkipDialog` and `AttachCinematicSkipDialogRecovery` return early
   unless `isForever` is true. The same gates exist in committed `main`.
5. Attachment is called at `CINEMATIC_START`, with bounded delayed retries.
   `Core/Init.lua` does not register `PLAY_MOVIE` or `STOP_MOVIE`. Merely widening
   the client gates would leave standalone movie lifecycle coverage unresolved.
6. `_cinematicSkipDialogStatus` is assigned internally but is not emitted by the
   current diagnostic dispatcher. Ordinary diag output cannot establish whether
   Blizzard received Escape or opened a skip dialog.

Candidate direction after reproduction: retain Blizzard's keyboard, visibility and
confirmation ownership; adapt the existing dialog presentation recovery to Retail
and both playback lifecycles. Check shown/enabled/spanned state, forbidden/protected
status, combat policy, scale conversion and client ownership before any writes.
Do not replace Escape handlers, auto-confirm, or force-enable scene cancellation.

## Contextual UI findings

- `Core/HUDTransientPolicy.lua` already lists `LFGDungeonReadyPopup`, ready checks,
  role polls, alerts, toasts and other temporary UI. `HUDTransientFrames.lua`
  reanchors eligible roots to Mainhand when enabled, spanned and `seamRedirect`
  is active. It retries native OnShow/selected OnEvent updates.
- This is not a blanket guarantee: protected roots require explicit secure policy,
  and ordinary repositioning defers in combat. Exact prompt identity, load timing,
  protection status, settings and other frame owners can distinguish a coverage
  gap from existing handling that did not run. The pinned corpus selection does
  not include the relevant dungeon prompt or vehicle implementation modules;
  those native roots need a focused upstream/client study once identified.
- "Accepted into a dungeon" could describe a queued dungeon ready prompt or a
  group-finder invitation. No claim that these share one frame is established.
- `OverrideActionBar` is explicitly excluded from generic panel dragging and
  persistence. Extra Abilities and the vehicle leave button have separate Edit
  Mode handling in `MainhandEditMode.lua`; they are not interchangeable with a
  full vehicle/override bar. Confirm the actual control before choosing an adapter.
- A universal movable-notification option should not bypass protected ownership.
  First establish coverage for the affected roots; customization is separate work.

## Reporter evidence and reproduction

1. Obtain `/offhand diag`, exact Offhand release and Retail build, monitor arrangement,
   resolutions and scaling, active Edit Mode layout and relevant UI/bar addons.
2. Obtain one named cinematic or quest and whether Escape does nothing, releases
   the cursor, shows a displaced confirmation, or shows a button that fails.
   A screenshot spanning both displays is useful. Compare a known cancellable
   replay outside a timed key, with Offhand disabled, then Offhand alone enabled.
3. Obtain the exact acceptance prompt and named vehicle/quest. Capture the affected
   UI while present. In the current candidate, `/offhand diag full` outside combat
   adds read-only interaction visibility/ownership details for override and extra
   ability controls. It does not currently include the dungeon or skip dialogs,
   and support for this output must be checked against the installed release.
4. Reproduce on both equal-height and reporter-matching display geometry. Test a
   cinematic and a standalone movie separately; verify native confirm and resume.
   Test dungeon acceptance and the actual vehicle ability clicks, including combat
   where relevant, with fresh Lua/taint evidence. Include disable and unspan recovery.

## Validation performed

Lua 5.1: `tests/lifecycle.lua`, `tests/mainhand-placement.lua`,
`tests/retail-workspace-escape.lua` and `tests/interaction-visibility.lua` pass on the
existing working tree. These verify existing simulated behavior, not this reported
Retail failure. No runtime code, settings, installed addon or release was changed.
