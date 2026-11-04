# Workspace profiles, panel routing and region themes

4 November 2026. Initial implementation on `codex/custom-workspace-regions`.
Companion candidate `2.1.3-beta.4`, file `2.1.3.5`, protocol 1. This is an
unpublished review build. The existing Discord Test 1 and frozen public
Companion assets remain unchanged.

## Using the features

In Companion, configure **Multiple workspaces**, then open **Workspace
profiles...**. Save the current monitor areas under a name, update a saved plan,
load it, rename it or delete it. Loading selects settings only. Click **Span WoW
Now** to apply, then `/reload` so the addon can read the selected plan identity.
Plans require the configured monitors and their saved resolutions. A missing,
ambiguous or resized display refuses loading; it does not silently substitute
another display. Loading keeps automatic span disabled.

In the addon's **Profiles** tab, the new workspace section saves panel positions,
routing and region appearance separately from the existing general addon
profiles. Save as new copies the current layout and selects it. Switching layouts
automatically retains the outgoing layout. Save current records the active
layout explicitly. Rename changes its label; delete is limited to inactive,
non-default layouts and requires confirmation. These layouts belong to the
current general addon profile, rather than a new cross-character HUD profile.
They do not switch display geometry, calibration or Blizzard Edit Mode layouts.

In **Workspace**, choose a destination for Map, Character, Spells, Collections,
Achievements or Journal. Existing behavior is the default. Routes are opt-in and
apply through the existing guarded panel restore/show path. A manual placement
always takes precedence. **Use routing again** confirms before clearing that
panel group's manual Mainhand and workspace positions. Bags, chat, professions,
interaction windows and third-party panels keep their established behavior.

In **Themes**, each active custom region can inherit the global appearance or
select Classic, Blizzard Slate, Obsidian, Pitch Black or Gnomish Tinker. Overrides
style the Offhand canvas and trim; they do not reskin native Blizzard panels.
Inactive regions cannot be edited. Current custom topology supports one full
game monitor plus up to two workspace regions on other monitors.

## Persistence and recovery contracts

Companion stores at most 20 named plans in versioned, bounded JSON encoded in
its existing preferences file. Snapshots contain an allowlist of monitor identity
and geometry settings. Launcher, updates, unrelated preferences and recovery
state do not travel with a plan. Profile CRUD operates on copies; the existing
atomic preference publication path commits changes. Loading revalidates against
the connected displays. A stable ID survives rename/update. Delete retains the
current geometry and addon layouts. Saving a plan alone does not resize WoW.

The optional schema 2 bridge fields `workspaceProfileID` and
`workspaceProfileName` associate an applied Companion plan with an addon layout.
The first encounter copies the current layout. Later plan selections restore
that plan's layout. Repeated layout passes and reloads preserve a subsequent
manual in-game layout selection. An unnamed, disconnected or schema 1 plan does
not switch layouts. The protocol remains 1; older consumers ignore the optional
fields. Limits, malformed data and unknown schema versions refuse edits without
discarding the original store. Deleting a Companion plan does not delete its
addon layout.

Addon workspace stores are version 1, limited to 24 layouts per general profile.
Only panel positions/open intent, panel loader hints, native backpack position,
map scales, spellbook tab, routing and region themes are copied. Existing
calibration, onboarding/HUD preferences and unrelated addon settings are outside
the snapshot. Loading copies records, rather than aliasing saved profiles.
Persistent panel state is a restore hint. Loading does not forcibly close native
panels absent from the incoming open-state record. Third-party bag addons retain
their own layout/snapshot lifecycle and are not a new routing category.

Automatically generated positions carry `autoRoute` and `routeTarget` markers.
A genuine drag produces the existing manual record shape, so edits to routing
cannot move a manually placed panel. Missing regions retain their original ID
while the existing recovery path uses the primary available region. Oversized
panels use guarded Mainhand recovery at native size and retain destination
intent. Schema 1 ignores generated routing records while preserving them for a
later custom span. Combat, protected/forbidden frames, external ownership and
existing special panel policies remain under the Canvas guards. Simulation
coverage is not a taint-safety claim.

No destructive migration is required. Unknown/future workspace stores remain
untouched. Reverting to the prior addon leaves the new fields inert; retaining a
SavedVariables backup also preserves independent layout snapshots. Restore
Window and the existing rollback path remain the native recovery controls.

## Validation

All 89 Lua suites pass, including new workspace profile, routing and region theme
suites. Production integration fixtures exercise the initial unsaved native
OnShow route, deferred anchoring, manual drag priority, missing/reconnected
regions, oversized recovery, combat/ownership guards and actual option callbacks.
Six matching TOCs pass path/XML checks and Lua 5.1 compilation (68 Lua files).
All eleven locale dictionaries include the new keys. Non-English strings are
explicit English fallbacks pending translation.

Native x64 and x86 fixtures pass 25 named-plan checks each, 324 multi-region
checks each, 40 third-monitor boundary checks each, 25 taskbar checks each and
3,057 rollback assertions each. Preference/partial topology and all four
production/experimental graphics-recovery scopes pass. The full dashboard,
including the new profile button, fits at 100%, 125%, 150% and 200% scale. A real
WinForms profile editor render caught and resolved a displayed type-name bug.
The review archive retains exact component hashes and inert generated bridges.

Live acceptance for these changed feature bytes is tracked separately from the
[baseline checkpoint](WORKSPACE-FEATURES-BASELINE-QA-20261104.md). Native-client
combat/protected descendants, physical three-monitor rendering/input, mixed DPI,
monitor disconnect/reconnect and replacement-bag integration remain acceptance
gates. No stable release or Store publication is implied by this implementation.

## Retail feature smoke test, 4 November

The initial feature bytes were exercised on Retail 12.1.5.70783 with the existing
level-one QA character. The real Options UI exposed overlapping new/old cards;
all three cards are now included in the existing page stacks, with a production
Options construction regression covering non-overlap and scroll bounds. The
corrected Profiles page was visually rechecked, with independent workspace and
general-profile sections.

The Companion created and displayed a named plan, committed it without resizing
WoW, applied the exact 480x600 region, and wrote its stable identity into the
schema 2 bridge. Reload selected the matching addon layout. Routing and Pitch
Black region settings persisted. Switching to Default isolated those settings;
reload and reapply retained that manual choice. Switching back restored them.
Actual metrics reported READY/schema 2 and the expected independent region.

Native Collections revealed a lifecycle failure before acceptance: its generated
route/region intent was correct and native scale remained 1, but its final
703x606 rectangle was left of Mainhand rather than recovered into it. A production
fixture reproduced removal of its native UIPanel registration. Collections now
uses the same native registration and late-anchor repair policy as the supported
standalone spellbook. The fixture fails before the change and passes afterward,
including protected-root restore, oversize recovery, destination retention and
late native SetPoint repair. No global protected-frame guard was relaxed.

A cold live retest deployed all 80 final review addon files and the unchanged
Beta 4 candidate. Network disconnection prevented completing the Collections
retest; it remains a specific live acceptance gate. Disconnects are excluded as
instructed, rather than attributed to addon errors. Both smoke sessions retained
all 13 historical BugGrabber records without new captured errors. No combat or
protected descendant action was attempted. No HUD setup prompt was accepted or
modified, and no Character drag was repeated.

Normal native Restore matched `(0,215) 2560x961`, style `14CF0000`, with no
clipping region. Original addon and file-state restoration is hash checked in
private cleanup receipts. These bounded checks do not accept three physical
monitors, mixed DPI, hotplug, replacement bags, all routed panel groups or all
clients. Full feature release approval remains separate from this initial
implementation.
