# Private Discord candidate: spanned minimap QA

Later keyboard Save/reload acceptance and an additional tooltip correction:
[Spanned follow-up QA](DISCORD-FOLLOWUP-QA-20261110.md). The initial pass below
retains its original scope and limitations.

Follow-up to [the unspanned smoke run](DISCORD-NATIVE-QA-20261110.md), at the
user's explicit request to apply spanning, including calibration if necessary.
The existing Companion configuration worked without a new calibration.
Discord remained read-only. No gameplay, native HUD Save/regeneration, vendor
source edit, publication, commit or push occurred.

## Candidate and actual viewport

Frozen private candidate `discord-qa-20261110-20261110-041329-310749`, previously
validated with 121 Lua suites, six manifests and verified package entries.
Forever 1.60.1 build 70862, Companion 2.1.5, idle level-2 Shaman in Valley of
Trials. Installed SexyMap v12.1.7 and EllesmereUI 9.8.2.

Companion's existing single-display 32:9 split, game side Right, was applied
with **Span WoW Now** before entering world. Companion reported that the WoW
window matched the selected layout. The 2560x1440 physical display contained
workspace `(0,0) 1280x1440` and game `(1280,0) 1280x1440`. Native screenshots
showed the black workspace and clipped world on the right. Observer snapshots
reported `topologyStatus=READY` and `isSpanned=true`; `/offhand diag` persisted
`viewportMatches=true` and WorldFrame approximately `(1280,0) 1280x1440` in
physical pixels. The viewport remained intact through the tested reloads.

This is actual single-display spanning, not physical dual-monitor or mixed-DPI
acceptance. The reporter's 4000x2752 portrait/landscape canvas was not reproduced.

## Isolated owner results

| Owner | Actions and observed result | Persistence evidence |
| --- | --- | --- |
| Native | Game Menu, Character and Spellbook open/close retained the visible map. Its native Edit Mode selection box covered the map in the workspace. | Two layouts, 118 systems, active layout 5 and serialized native anchors match before/after reload. Minimap geometry is identical; cluster floating-point delta is below 0.001 physical pixel. |
| SexyMap | EUI Minimap disabled. Game Menu and Character open/close retained the map. Native Edit Mode displayed an empty cluster box in the workspace while SexyMap's visible map stayed on the game side. SexyMap's own unlocked drag moved it across the seam; closing Game Menu retained that placement. | Reload retained the seam placement exactly in captured Minimap geometry. Native serialized anchors are unchanged. |
| EllesmereUI Minimap | SexyMap disabled; EUI Minimap and Options explicitly enabled. `/unlock` displayed the **Minimap** mover, unlike the earlier core-only configuration. Its **Center on Screen** context action moved the map horizontally across the seam. **Save & Exit**, Game Menu and Character open/close retained it. | Reload retained the seam placement with maximum physical geometry delta about 0.533 pixel. Native serialized anchors are unchanged. |

The EUI mover's appearance after module enablement supports module readiness as
the explanation for the missing control in this local setup. It does not prove
which modules were enabled in every reporter's session. Loading EUI Options also
showed Offhand's existing HUD review prompt; **Later** retained the current HUD.

Automated drags selected the native and EUI minimap boxes without moving them.
The same automation moved the native Edit Mode manager and SexyMap itself.
Neither native/EUI minimap drag nor native Save/reload acceptance is claimed.
Their behavior with a physical drag remains unresolved. EUI's owner-provided
context action, not a direct frame write, established its seam placement.

The visible SexyMap/native-box separation is confirmed. Automatically tying
the two save systems together is still not implemented. The ownership fix
preserves the selected minimap addon's placement; a future unified mover needs
an explicit authority and release contract. No spontaneous hiding or large
relocation was reproduced by this limited panel/reload pass.

## Capture and error boundaries

Private data and analysis are under ignored
`dist/discord-spanned-qa-20261110-1/`: scoped settings before/after, native/SexyMap/
EUI captures, `compare.lua`, `reload-comparison.txt`, hashes in `run-summary.json`
and `cleanup-receipt.json`. The analyzer executes only the explicitly selected
observer-generated files in an empty Lua environment with an instruction limit.
It excludes logout restoration snapshots when comparing post-reload state.
Logout deliberately restores native layout 1 and the full WorldFrame.

The native Edit Mode run reached the 120-event limit during layout updates.
Its early stop cannot attribute later attempted drag writes. The uncapped
EUI seam panel run recorded four Character-frame writes and identical start/end
minimap geometry and serialized anchors. SexyMap's seam run records start and
logout, so its panel closure result is visual; post-reload start geometry matches
its pre-reload start. Hooks can affect timing/taint attribution; missing events
do not establish absence of engine writes or protected-action safety.

BugGrabber and BugSack were temporarily enabled for the isolated vendor passes.
After normal exit, error messages, timestamps and counters are unchanged from
the pre-test backup (root session advanced from 48 to 52). The historical
invalid SetPoint, overflow and blocked reload records were not reproduced as
fresh failures. Native-only first pass had these collectors disabled. No combat
or taint acceptance is claimed.

An optional raw `/run` diagnostic encountered WoW's custom-script permission
prompt. The prompt was not answered by automation; the client was closed
normally and relaunched, and QA continued through existing addon commands.
No security permission was changed and that optional script supplied no evidence.

## Cleanup and remaining gates

Forever closed normally. Battle.net and Companion remain open. Before restoring,
the changed vendor profiles and character enable file were copied to private
`settings-after/`. The three original vendor SavedVariables files and the exact
character AddOns.txt were restored with matching SHA-256 checks. SexyMap, EUI
Minimap, EUI Options, BugGrabber and BugSack are back to their original disabled
states; EUI core and Offhand remain enabled. Both private helper TOCs are
`.toc.disabled`. Error logs and capture history are retained. The private Offhand
candidate remains installed; its 96 non-bridge product files still match the
installation receipt. Generated Companion bridges are retained.

These are partial native ownership/persistence checks. Still open: affected old
profiles, native/EUI physical drag, native HUD Save/reload, top-overhang placement,
Talents (unavailable on this character), buff changes, Restore/span cycles,
combat and fresh taint, physical multi-monitor geometry, the missing dungeon icon,
real loot-roll actions, oversized tooltips, ProcDoc and GPU comparisons.
Daylight live QA remains explicitly deferred. No Discord report was closed.

## Later user-authorized custom-script permission

After the tests above, the user explicitly identified **Allow custom scripts**
and instructed acceptance. Relaunched the same Forever 70862 character through
Battle.net, applied the same Companion split before entry, and submitted only
`/run print("Offhand QA script check")`. Clicked **Yes** on the native prompt,
then repeated the command and observed its local printed output. EUI Minimap
and Options remained disabled; this permission prompt did not require EUI.
No profile/geometry script, gameplay or chat transmission occurred. Closed WoW
normally afterward; original addon flags and disabled helper TOCs retained.
This later permission change does not alter the earlier capture evidence.
