# Private Discord candidate: Forever smoke QA

Subsequent actual spanning and isolated minimap tests are recorded in
[Spanned minimap QA](DISCORD-SPANNED-QA-20261110.md). The unspanned results below
remain the historical first pass.

This is limited native smoke evidence, not acceptance of the remaining reports.
The user explicitly authorized normal close, backed-up installation, Battle.net
relaunch, addon options/reload checks and layout capture. Discord stayed read-only.

## Candidate and installation

Frozen candidate: `discord-qa-20261110-20261110-041329-310749` under `dist/`.
All 121 root Lua suites passed against its frozen runtime; six manifests and
Lua 5.1 compilation passed. All 103 ZIP entries were verified.

ZIP SHA-256:
`fe2f9ed55c5c51f421bd332fe3f98c7c0cc8c949f2017eab9ec066c9283a8418`.

The isolated installer fixture preserved generated sentinel bridges. The real
installation target was `C:/Games/World of Warcraft/_forever_`, after normal exit.
Actual addon backup and installed hashes:
`dist/discord-qa-20261110-20261110-041329-310749/installed-backup-20261110-041920-266/`.
The installer left SavedVariables untouched and preserved both generated bridges.
The running Companion later refreshed `ForeverState.lua` after client exit,
consistent with its stopped-client writer in `Companion/Source/Program.cs`.
Topology still matches its backup. Retain the newer recovery bridge during any
rollback; do not replace it with the candidate's inert stub.

## Native test

Forever 1.60.1 build 70862, selected level-2 Shaman idle in Valley of Trials,
keyboard UI, existing profiles and layout retained. A stale session initially
showed emergency maintenance and reconnect error WOW51900308. A fresh Battle.net
launch reached character selection and entered world successfully.

The 2405x1353 client area mismatched the saved Companion topology. Spanning
remained paused. Both missing-monitor prompts were answered Keep Current Layout.
No layout regeneration, native Save, player movement, combat or gameplay action.

Commands: `/ohissue start native-load`, `/offhand`, `/ohissue stop`, `/reload`,
then `/ohissue start after-reload`. The second run stopped on normal client exit.
Character was opened and closed once with its normal keybind.

Observed:

- Offhand and the opt-in observer loaded. Options opened successfully.
- The ProcDoc checkbox displayed unchecked, with compatibility text below it.
  Vendor ProcDoc behavior and translated UI layouts were not tested.
- The minimap stayed visible after Character opened/closed in this unspanned run.
- Normal reload returned without a visible Lua error. This is not a full fresh
  error-log audit or a combat/taint-safety claim.
- Before/after reload captures contain identical native serialized anchor data:
  two layouts, 118 systems, active layout 5. Minimap, MinimapCluster, PlayerFrame,
  MainActionBar and BuffFrame geometry also matches. The later logout snapshot
  restores active layout 1; it is separate from the post-reload snapshot.
- Observer recorded four then six Lua-visible writes, zero reported hook-install
  gaps, manual/logout stops and successful SavedVariables persistence. Missing
  events do not prove absence of engine writes.

Private raw data and bounded offline comparison are under this candidate's
`native-evidence/` directory. Capture SHA-256:
`e985ef531094ff132dae9571104577b169e050e6d3c8db3b8d78f0d91ba49804`.

## Cleanup and remaining acceptance

Forever closed normally. Battle.net and Companion remain open. Both newly
installed QA helpers were disabled while stopped by renaming each helper's
`.toc` to `.toc.disabled`; sources and captures remain available. To reuse a
helper, restore that filename while WoW is closed. The private Offhand candidate
remains installed. No publication, commit, Discord message or status change.

The new capture workflow is in `tools/issue-capture/README.md`. Hooks install
only after explicit start, are bounded and stop on request/time/event limits.
They can affect timing and taint attribution; repeat failures after a clean
reload with the observer disabled. Do not use the issue observer for GPU timing.

Spanned minimap ownership, old failing profiles, competing-mover combat shifts,
native Save/reload persistence, oversized item cards, actual multi-roll actions,
ProcDoc release/restoration and GPU comparisons remain open. This run does not
reproduce the reporter's window/topology/profile combination. The native matrix
in `docs/DISCORD-FIXES-20261110.md` still applies. Daylight QA stays deferred.
