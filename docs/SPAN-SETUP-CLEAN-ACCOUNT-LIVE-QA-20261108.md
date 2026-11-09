# Clean account setup, Next, HUD and cold restart: native PASS

On 8 November 2026 the owner explicitly authorised resetting the local account's
addon settings. The immutable private span-setup-test1 addon passed first-time
setup using ordinary Next, creation of its first native HUD, the requested HUD
reload, and a cold restart of both WoW and Store Companion. This closes the
clean local settings gap identified in the earlier Next test.

Repeated on the owner's request later the same day. The unchanged candidate
passed a second independent account/cache/Companion preference reset, ordinary
Next, first HUD creation, HUD reload and cold WoW/Companion restart. This repeat
recorded zero Lua errors throughout, including the helper. The restart check
entered the world before manually spanning and reloading; see the repeat record
below.

The result applies to Forever 1.60.1 build 70862 and Store Companion product
2.1.3/package 2.1.301.0. The host has one physical 2560x1440 display. The test
explicitly selected Companion's single-display split, Mainhand right1280x1440
and workspace left1280x1440. The reporter's physical two-display4480x1440
geometry, other clients and protected/combat actions remain outside acceptance.
This was an existing character with cleared local state, not a newly created
Blizzard account or an OS/Store reinstallation.

## Reset and verified starting conditions

Closed WoW and Companion normally. Moved the entire selected account directory
(207 files), client Cache (26 files), old installed addon (83 files), Store
Companion preferences and legacy Companion import preferences to a rollback
snapshot. Retained client graphics Config.wtf and unrelated accounts. Installed
all86 entries from the private candidate. Temporarily enabled only Offhand,
BugGrabber and the observer/reset helper for the selected idle test character.

Companion opened with default preferences: auto-span off,15second delay and
single-display split off. Explicitly selected split and used Span WoW Now during
the real first-time guide. Welcome started enabled=false/setup=false, and the
post-span Reload UI resumed placement as expected.

WoW restored six previous Offhand-named custom HUDs despite removing local Edit
Mode caches. The helper backed up the full native payload and removed these six
rows. The first helper guard incorrectly expected every name to contain a space
after Offhand, so it rejected the legacy bare name without changing any row.
Its repeated guard produced two helper-only BugGrabber messages/five occurrences.
These were corrected before calibration. SaveLayouts alone emptied the current
list but the server later restored it; completing the transaction with native
OnLayoutDeleted calls removed the synced rows as well. One disconnect occurred
during this preparation, recovered through the authenticated Reconnect button.

Before the actual Next/HUD sequence, a completed reload recorded:
enabled=false, setup=false, customLayoutCount=0, offhandLayoutCount=0 and native
activeID=1 (Modern). The complete sample history is retained, including rejected
reset attempts and transient zero counts; only the verified final baseline is
used for acceptance.

## Actual UI acceptance

Clicked Confirm placement, Start Calibration and ordinary Next on step1.
The workspace and Mainhand viewport activated immediately. Continued Next
through orientation, seam and UI size, then clicked Create Mainhand HUD Layout.
No Auto-Configure action or direct enabled/setup override was used.

Exactly one HUD creation call produced exactly one custom native row,
Offhand Main - Noggaholic, ID4. It cloned preset Modern and moved54 systems.
The real creation popup offered Reload UI; clicked it. After that reload the
guide stayed closed, enabled/setup/viewportMatches were true, the generated HUD
was configured, its geometry matched and native activeMatches was true.
Persistence source was savedvariables, bridge absent, standard fallback.

Closed WoW normally, exited and restarted Store Companion, then launched a new
WoW process through Battle.net. Companion retained the newly chosen split.
Auto-span remained off, so manually reapplied Span WoW Now at character select
before entering the same test character. Cold login restored enabled/setup,
matching viewport and the same sole native HUD without creating another row or
rerunning the wizard. This time Companion's newly generated recovery bridge was
used, revision12. This verifies cold recovery with the selected span applied;
it does not claim automatic window spanning with auto-span disabled.

Both acceptance samples have AutoConfigure calls=0, HUD calls=1 and the same
two helper-only errors/five occurrences. All BugGrabber messages were checked:
zero product errors and zero error increase during Next, HUD, reload or cold
login. This is no claim of combat or taint safety.

## Cleanup and evidence

WoW is closed normally; Companion and Battle.net remain open. Removed the
temporary QA addon and its SavedVariables, and archived the helper-only error
files. Restored only the character's prior addon enabled/disabled selection;
all reset addon settings remain fresh. The tested candidate and newly completed
Offhand setup remain installed. Other UI addons were disabled during acceptance;
their next launch with reset defaults is outside this test.

Private evidence: dist/span-setup-test1/clean-account-20261108, including
reset-manifest.json, before/, after/, screenshots01-12, after-reload/,
verify-clean.lua and acceptance.json. The verifier asserts the zero-row baseline,
single creation, both successful in-world samples, persistence sources and
exclusive helper error attribution. Full backups contain private account data
and remain outside the package and tracked documentation.

Candidate ZIP SHA256 remains
C6B6FE2DBCA41AC60E8A4A4B3D867C53BBB640BDF6A39F36FBF37C236B2D37C1.
All installed package bytes match except the two expected Companion-generated
Core/CompanionTopology.lua and Core/ForeverState.lua files. No product source
changes were needed during this run; prior109suite/sixmanifest validation still
applies to the unchanged artifact. Nothing was published or submitted to Store.

Knowledge status and Forever API queries were consulted. The cached declaration
revision ca8368f2f238 targets70532 and was review-due; observed70862 behavior is
the native evidence. The missing deletion usage was checked against the pinned
[Blizzard Edit Mode implementation](https://github.com/Gethe/wow-ui-source/blob/ca8368f2f2380cbe696854f7f2646387c278a61b/Interface/AddOns/Blizzard_EditMode/Shared/EditModeManager.lua#L1451),
which saves removal and notifies OnLayoutDeleted. The local knowledge note
records this source and the live reset/persistence result separately.

## Independent repeat requested by owner

The repeat snapshot retained the preceding fresh setup, then moved all47 active
account files,17 cache files,87 installed addon files and the one active Store
Companion preference file out of the test installation. Installed and verified
the same86 archive entries. No product source or archive bytes changed.

Companion again opened with auto-span off,15second delay and split off. The
first-world Welcome guide again started enabled=false/setup=false. Removed the
single prior Offhand HUD using the already verified reset transaction; the
post-span reload recorded zero custom layouts and no errors before calibration.
Followed the complete Companion/Windowed/Place WoW/Span/Reload/Confirm placement/
Start Calibration path and clicked ordinary Next through all calibration steps.
The actual HUD button created one Modern-derived ID4 row and moved54 systems.
AutoConfigure stayed0 and HUD creation count stayed1 for the entire run.

The requested HUD reload recorded enabled/setup/viewportMatches/configured/
currentGeometry/activeMatches all true, one custom row and no errors. Closed
both processes normally and restarted Store Companion and WoW through Battle.net.
Companion retained the new split while keeping auto-span off.

This time entered the world while still windowed. The setup remained complete;
the existing HUD was available, with its geometry appropriately marked different.
The missing-monitor protected-layout recovery prompt appeared. Used Companion's
real Span WoW Now without accepting a fallback layout. The recovery prompt
cleared and the saved Mainhand HUD returned. A temporary QA button recorded the
state and performed ReloadUI; it did not change product settings. After this
reload, enabled/setup/viewportMatches/configured/currentGeometry/activeMatches
were again true with the same single row and no new HUD creation. Cold login
used the new Companion bridge; the final reload used SavedVariables revision7.

The verifier checks the zero-row pre-Next baseline, one creation, all three
post-creation world-entry samples, the expected windowed geometry difference,
the matching final geometry and zero BugGrabber errors across every sample.
There were no helper errors, product errors, disconnects or recorder repairs in
this repeat. Computer Use required refreshing one expired screenshot reference;
this did not change product state or the acceptance sequence.

Closed WoW normally and removed the temporary helper/SavedVariables. Archived
the runtime evidence and restored only the previous addon enabled selection.
Fresh settings and the tested candidate remain installed; Companion/Battle.net
remain open. Other UI addons were disabled during acceptance. Private evidence
is separate from the first run under
dist/span-setup-test1/clean-account-repeat-20261108, with before/, after/,
screenshots01-13, reset-manifest.json, verify-clean.lua and acceptance.json.
The physical single-display split limitation is unchanged.
