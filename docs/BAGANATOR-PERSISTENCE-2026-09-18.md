# Baganator reload persistence

The former reload/logout post-hooks set the shutdown flag before attempting the
snapshot, so the snapshot returned without saving. The resulting `bagsWereOpen`
value was not consumed by restoration either. Broad scans for BGR objects also
mistook locally shown item buttons for an open backpack.

`Core/BagPersistence.lua` tracks Baganator's SingleView/CategoryView backpack root
windows, using the names verified in the installed Baganator
`ViewManagement/Initialize.lua`. It does not modify Baganator's files, scale, or
profile. A visible backpack on the workspace is sampled while playing. Hides are
sampled on the next timer turn so UI teardown cannot overwrite the snapshot.
Leaving the world pauses tracking; entering restores before tracking resumes.

Restoration waits for lazy initialization for up to five seconds and defers in
combat. It invokes Baganator's `ToggleAllBags` implementation only once and only
when no backpack root is visible, then restores the saved workspace coordinates
through Offhand's existing clamping. Generic bag restoration yields to this path
when Baganator is loaded. Manual closes and moves to the game monitor clear the
snapshot. The persistent-panels and restore-on-reload settings both gate it.

The tracker stores `baganatorWorkspacePanels` in the active Offhand profile.
Old ambiguous bag markers are not migrated into this new snapshot. After loading
the update, open the bag on the workspace before testing another reload.

Validation: 16 Lua suites and all three TOC manifests pass. New coverage includes
teardown hides, manual closes, workspace/game monitor routing, an already-visible
bag, locally shown item buttons, delayed roots, disabled persistence, and combat.
Locale stub UTF-8 BOMs were removed, TOC locale lines corrected, and existing test
mocks now provide Blizzard's StaticPopupDialogs table.

Live verification remains required: reload to load the update, open Baganator on
the Offhand monitor, wait a moment, reload again, and check visibility/position.
Repeat after closing the bag, moving it to Mainhand, and disabling persistence.
