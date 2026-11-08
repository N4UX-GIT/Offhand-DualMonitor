# Companion UX quality pass

4 November 2026. Local candidate 2.1.3 Beta 5, file version 2.1.3.6,
protocol 1. This work continues on codex/custom-workspace-regions and does not
replace the frozen public Companion or Discord Test 1.

## Scope and decisions

Prioritise the Companion's existing layout workflow before expanding the media
format. Keep the dark Warcraft palette and branding, with shared field, button,
selection, hover, focus and disabled presentation. The dashboard remains compact;
its actions use a consistent Segoe UI font and its display pickers share the
editor presentation. Help and the workspace/profile tooltips cover the new flow.

All custom layout editors and the profile manager now share that presentation.
The multi-workspace editor groups display choice, Workspace A, optional Workspace
B and review. Display numbers match the dashboard. Inactive Workspace B fields
are hidden while their definitions are retained. A scaled diagram distinguishes
the game, workspaces and free desktop, including negative monitor coordinates.
This is a plan illustration, not a renderer preview or support guarantee.

Plan status remains above the footer when fields scroll. Invalid plans disable
Save and explain the correction. Disabling custom mode remains saveable after
monitor loss. The one- and two-display editors also validate before saving.
The existing native planners remain authoritative and still validate at commit.

The profile manager explains empty and pending states. Unavailable actions and
duplicate Save as new are disabled. Changes are still staged in a copy until
Save changes; Cancel preserves the caller's settings. No profile action resizes
WoW. Labels for dimension fields identify the workspace for accessibility.

The rectangular overlay puts its actions below the selection canvas and makes
movement/resizing available from the keyboard. Arrows move 10 pixels; Ctrl uses
one-pixel steps; Shift resizes; Ctrl+Shift resizes by one pixel. Enter accepts the
selection and Escape cancels it. The existing clamp and minimum-size rules apply.
The overlay returns pending dimensions to the editor; Save plan commits them.

## Evidence and limits

The new x64/x86 UX fixture covers dark controls, distinct accessible names,
100/125/150/200 percent layout scaling, valid/invalid plans, visible status,
missing-monitor disable, profile action states, staged copies, cancellation and
keyboard move/resize. It renders all editor types and the profile manager.
The existing dashboard, preference, workspace, clipping, identity, taskbar,
rollback and graphics-recovery fixtures remain part of validation.
Final checks pass: 67 UX assertions and 25 named-plan assertions on each
architecture; 352 multi-region checks and 40 third-monitor boundary checks on
each; 25 taskbar assertions and 3,057 rollback assertions on each. The dashboard
and partial-topology fixtures pass. Production and all three experimental
graphics-recovery scopes pass. Frozen public asset hashes remain unchanged.

A direct native UI check used the production editor classes in an isolated host
with the two connected displays and temporary in-memory geometry. The offhand
monitor overlay visibly moved its X offset from 20 to 21 with Ctrl+Right and
changed width from 640 to 650 with Shift+Right. Escape restored editor values
20/640; Cancel exited without committing. No saved Companion preferences, addon
files or WoW window were changed. Later accessibility/spacing refinements are
covered by the final source fixture and rendered forms.

Synthetic scaling checks do not establish physical mixed-DPI behavior. Third
physical monitor input/rendering, hotplug, screen-reader/high-contrast acceptance,
all client/panel combinations and protected-descendant/combat testing remain
release gates. This presentation pass does not inherit full live span acceptance
from an earlier binary. No stable, Store, GitHub or website publication occurs.

The shared KB status and UX query were consulted. Retrieval had no exact native
editor evidence; local source and the native fixtures above supply the bounded
evidence. No new WoW API or renderer access is introduced.

## Separate region images

The existing single-image region implementation stays compatible. The next
isolated feature is described in [the media-library plan](WORKSPACE-MEDIA-LIBRARY-PLAN.md).
It is intentionally not implemented by this UX candidate.
