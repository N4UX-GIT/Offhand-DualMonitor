# Panel placement, gathering and Escape policy

Candidate: `codex/professions-quest-ui`, 28 October 2026. Group Finder live acceptance remains pending. Both Escape-dispatch registration variants failed live. The current Retail candidate filters later panel cleanup. The developer confirms Offhand windows stay open on Escape without a fresh Lua error. Combat, cold-login and the full panel matrix remain pending.

| Panel family | Position owner | Gather Safe UI to Mainhand | Escape on Offhand | Reopen after reload |
| --- | --- | --- | --- | --- |
| Retail spellbook/talents | PlayerSpellsFrame | Visible workspace root | Preserved out of combat by cleanup filter | Eligible with persistence and saved open intent |
| Retail profession list | ProfessionsBookFrame | Visible workspace root | Preserved out of combat by cleanup filter | Eligible; loads Blizzard_ProfessionsBook |
| Retail crafting/orders | Native crafting root, such as ProfessionsFrame | Visible registered root only | Preserved out of combat by cleanup filter | No synthetic reopening; position restores on a native opening |
| Retail Group Finder | PVEFrame | Root once; content children are deduplicated | Preserved out of combat by cleanup filter | Eligible with persistence and saved open intent |
| GroupFinderFrame/LFDParentFrame inside PVEFrame | PVEFrame | Children are not moved independently | Root policy | No independent child restoration |
| Other movable standalone windows | Supported top-level root | Visible workspace window; registration/ownership guards apply | Existing independent-panel policy | Only supported persistent roots with saved open intent |
| Protected HUD/Edit Mode | Native system | Excluded from broad window gathering | Native | Native layout, not generic panel reopening |
| External or forbidden roots | External/native owner | Skipped | Native/external | Native/external |

Gather Safe UI searches registered panels, tracked workspace roots, supported bag
roots and movable direct children of UIParent. It moves only shown workspace or
tracked workspace candidates. It leaves already-Mainhand, hidden and parent-owned
content alone. Protected unregistered roots, HUD/Edit Mode, native maximized maps,
forbidden objects and external ownership can prevent placement. Such eligible
but unsupported candidates now increment the skipped count. Full diagnostics
include the actual outcome, rather than reporting zero unsupported windows merely
because a root failed an ownership guard before placement was attempted.

Recover Missing UI remains a separate action: any visible overlap with either
display leaves a frame in place. It does not force dormant interaction windows
or inactive abilities open. Its existing confirmation and exclusions still apply.

## Why the earlier Escape wrapper did not cover these panels

Retail's native panel manager registers a reference to CloseAllWindows in the
Game Menu Escape dispatcher before addons load. Replacing the global function
later does not replace that registered reference. Removing UISpecialFrames entries
or temporarily changing UIPanelWindows also does not reliably remove panels from
the native delegate's active slots. Reopening a crafting shell after its OnHide
has closed the interaction is not a valid workaround.

An attempted AddOn-priority handler modified the shared native dispatcher
registry. Live Escape then produced ADDON_ACTION_FORBIDDEN for SpellStopCasting
inside Blizzard's earlier casting handler, before the addon callback. This is
consistent with dispatcher taint and invalidates the simulated safety assumption.

The earlier withdrawal removed the registration, retry loader, custom target/menu
handling and all writes to that registry. It does not replace protected casting
or dispatcher functions. Registration-dependent spellbook, profession, crafting
and Group Finder roots retain native Escape behavior. Existing independent-panel
support remains for other supported roots. Close buttons and interaction endings
remain native. The settings description and diagnostics disclose this limit.
A reload is required after installing the rollback to discard the contaminated
Lua session; the native registry has no supported unregister path here.

Source evidence:
[native Escape dispatcher](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_GameMenuEsc/Blizzard_GameMenuEsc.lua),
[native panel manager](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_UIParentPanelManager/Shared/UIParentPanelManager.lua),
[Group Finder root and content](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_GroupFinder/Mainline/PVEFrame.lua).
These moving source mirrors support the investigation; feature detection and
target-client testing remain necessary.

## Evidence and remaining acceptance

Simulation covers one Group Finder position owner, root registration retention,
settlement after native panel reflow before the next frame, deduplicated gathering,
untracked movable windows and explicit protected/HUD skip reasons. The Escape
regression asserts no addon registration or loader and unchanged dispatcher,
securecallfunction and casting function identities. Native interaction closure is
expected. This write-boundary regression does not establish native taint safety.

After installing the rollback and reloading, verify Escape while the profession
panel is on Offhand, then during a legitimate in-game cast. Native stopping and
closing should work without a fresh ADDON_ACTION_FORBIDDEN. Inspect new errors
rather than cumulative BugGrabber entries from before the reload. Group Finder
and gather acceptance remain separate.

`/offhand diag full` includes recovery policy in the panel-controller diagnostics:
root versus content child, visibility area, native registration, reload class,
persistence setting, native Escape route and the most recent gather outcomes.

## 28 October follow-up: secure registration also failed live

The developer confirmed panels remained open, but the first Escape still produced
ADDON_ACTION_FORBIDDEN for Offhand calling SpellStopCasting in Blizzard's earlier
casting handler. Subsequent presses produced no additional visible report. That
absence is not evidence that execution became safe. Both direct and secure-call
registration candidates are rejected by live evidence.

The current Retail test candidate has no Escape registry registration or retry
loader. It filters the later dynamic CloseWindows lookup made by the captured
native CloseAllWindows callback. It preserves visible workspace roots during
ordinary cleanup, closes Mainhand roots, and returns whether anything actually
closed so Blizzard retains its own fallback. Explicit HideUIPanel/toggles and
non-nil close contexts remain native. No crafting Hide/Show cycle is introduced.
Combat, reserved input, controller layouts, disabled persistence and unspanned
layouts forward to the original cleanup function.

The temporary installed-only QA readout has been removed. The replacement is
installed in Retail only for focused acceptance. Anniversary retains the prior
withdrawal version. All 62 suites and six manifests pass. This verifies simulated
cleanup behavior and source boundaries, not native taint or combat safety. Native
Escape/casting, Mainhand closure, explicit X and combat acceptance remain pending.

### Developer acceptance of the cleanup filter

After reloading the replacement, the developer reports that Offhand windows now
remain open on Escape without a new Lua error. This is a live out-of-combat
acceptance report, not blanket combat/cold-login certification. Mainhand closure,
explicit X, active-cast cancellation and the complete per-panel matrix were not
individually confirmed in that reply.

The screenshot from the rejected registration build shows blocked=22, session
errors=2, last action Offhand: SpellStopTargeting(), with all four observed panel
roots hidden. It therefore demonstrates repeated protected-action events despite
limited visible error reports, including an affected targeting path. It is
historical evidence from the removed QA readout, not evidence against the later
cleanup filter.