# Private Discord QA capture

This opt-in observer is outside the product TOCs. It does not move windows,
change CVars/profiles, call native layout saves, capture chat, or send messages.
It records Lua-visible frame writes with bounded caller stacks, plus explicit
out-of-combat geometry and serialized HUD snapshots. Hooks themselves can affect
timing or taint attribution, so repeat a failure with the observer disabled after
a clean reload. Missing hook events are not proof that no engine write occurred.

Build a private addon-only candidate from the current reviewed checkout:

```powershell
python tools/issue-capture/build-candidate.py
```

The builder freezes the runtime and test subjects, runs all root Lua suites and
Lua 5.1 syntax checks, rejects source drift, verifies every ZIP entry and writes
hashes under `dist/`. It changes no installed client files. No Companion executable,
generated topology, account data, credentials or Discord export is packaged.
The packaged bridge files are inert; the installer preserves existing installed
topology/recovery bridges. Source and simulated validation do not establish live
acceptance. ProcDoc is optional and is not bundled.

Use the generated `Install-QACandidate.ps1 -WowPath <explicit client directory>`
only after closing WoW normally. It backs up the existing addon/probe folders,
verifies source and installed hashes, preserves the two generated bridge files
and leaves account SavedVariables untouched. It refuses to install while a WoW
process for the selected client is running. There are no recursive deletes, launcher or window changes.
The candidate includes OffhandIssueProbe and OffhandPerformanceProbe separately;
disable/remove those helpers after QA and reload normally. Keep the backup and
installation receipt for rollback. Restore only the prior addon folders from the
backup while the client is closed, retaining the generated bridges.

## Movement and HUD persistence

1. Retain the player's profiles and window-mover addons. Record exact versions.
2. `/ohissue start combat-shift` while out of combat. This installs the observer
   hooks for this UI session. Do not use this observer during a GPU measurement.
3. Open the reported Character/profession/Skills panel and reproduce manually.
   The player performs any combat or gameplay. Capture does not automate it.
4. `/ohissue mark after-shift` out of combat, then `/ohissue stop`.
5. For HUD saves, start another labeled run. Enter native Edit Mode, move only
   the affected system, use native Save, mark `after-save`, stop, then reload.
   Start/mark/stop a second run after reload without re-generating the layout.
6. Exit normally or reload to flush `OffhandIssueProbeDB` to the helper's own
   SavedVariables file. Compare saved anchor data, native call stacks, actual
   geometry and active layout identity. Layout names/character names are omitted.

Capture limits: three runs, 120 write events, eight snapshots per run, 12 layouts
and 80 systems per layout, at most 180 seconds. Caps and inaccessible hooks are
recorded. Secret arguments are redacted before arithmetic/string conversion.
Combat snapshots defer protected geometry and layout reads; write arguments are
still observed. Reload uninstalls native hooks; `/ohissue stop` makes installed
hooks inert until the next explicit start. No automatic capture on login.

## Viewport and GPU comparison

Use snapshots to compare UIParent/WorldFrame geometry and the exact topology.
Resolve the report's Forever/3.3.5 contradiction from GetBuildInfo before selecting
an adapter. A saved resolution CVar is not a live backbuffer measurement.

For GPU reports, leave issue capture stopped. In an unchanged scene/camera with
the same graphics/FPS settings, use `/ohperf start LABEL` and `/ohperf stop` for
restored, spanned and same-size-UI-disabled comparisons. Record GPU utilization
and GPU frame times from the player's chosen hardware monitor. The performance
helper measures client frame intervals and available addon CPU metrics, not GPU
load. It does not change scriptProfile, graphics or FPS settings. Restart cleanly
with the issue helper disabled when measuring if its hooks were used earlier.

The candidate also needs native loot-row/tooltip and ProcDoc acceptance from
`docs/DISCORD-FIXES-20261110.md`. Daylight testing remains deferred. No report is
closed and no Discord status is changed by this tooling.
