# Forever native bag Escape, November 18, 2026

Candidate: codex/offhand-replacement-bag-escape, reviewed in Offhand PR #129.
Client: Forever 1.60.1 build 70959, Interface 16001.
Companion: 2.1.8.
Layout: 2560x1440 Mainhand and a 1440x2560 Offhand with unequal vertical bounds.
Vendor: Forever Bag Mover 0.8.0, with vendor positions saved on Offhand.

## Behavior

When visible native bags are on Offhand, Escape first dismisses another
ordinary panel or special window, preserving both the bag and selected target.
The next Escape clears the target through Blizzard's secure target action.
With no selected target, another ordinary window can still close while the bag
stays visible. Explicit bag bindings continue to close and reopen bags.

The native adapter uses a separate UIParent-owned window-dismissal button and
calls CloseWindows, preserving native panel cleanup without CloseAllWindows'
preceding CloseAllBags call. It keeps Blizzard's global functions and shared
Escape handler list intact and adds no scripts to native bag ancestry.
The existing target button remains a secure action. Both temporary binding
owners use the existing secure combat binding-clear pattern.

Existing guards still yield for combat, reserved input, text focus, popups,
casting, targeting cursors, menus, replacement bags, custom Escape bindings,
and any visible native bag outside Offhand. A native bag separately registered
in UISpecialFrames also causes the adapter to yield.

## Live results

B and Shift-B were each temporarily assigned to OPENALLBAGS to compare the
same action under both keys. Default B=TOGGLEBACKPACK and Shift-B=OPENALLBAGS
were captured, and the original bindings were restored without saving the
temporary assignments.

| Bags | Bag key | Other window | OneForAll 6.2.11 | Result |
| --- | --- | --- | --- | --- |
| Separate backpack | B | UISpecialFrames test window | Disabled | Window closed, then target cleared; bag remained visible; key closed and reopened it |
| Separate backpack | Shift-B | Native left-panel test window | Disabled | Same result |
| Combined backpack | B | UISpecialFrames test window | Enabled | Same result |
| Combined backpack | Shift-B | Native left-panel test window | Disabled | Same result |

The native-only regression also passed with Forever Bag Mover and OneForAll
disabled. A native panel closed without a selected target while the combined
bag remained visible. Verified Escape sequences had zero bag OnHide events
and preserved bag coordinates within 0.01 UI units. The trace recorded no
ADDON_ACTION_BLOCKED or ADDON_ACTION_FORBIDDEN events.

The first native-panel fixture was created already shown, so ShowUIPanel did
not register it. That attempt was excluded and the fixture corrected before
the verified native-panel cases. Trace markers were checked after reload,
and missing keyboard-toggle markers were repeated.

The ignored evidence is dist/forever-bag-mover-escape-qa/latest.json and
verified-results.json. The verifier checks five Escape sequences, four explicit
bag-key toggle comparisons, and no-target native dismissal.

## Validation and limits

All 135 Lua suites and all six manifest/path/XML/Lua 5.1 checks passed.
The regression model covers panel priority, preservation, secure target
handoff, stale clicks, popups, text focus, combat yielding and custom Escape.

The character had no equipped bag slots 1-4. The tests used actual native
panel-manager and special-window fixtures, without NPC or remote-player
interaction. Flight paths, combat and those interaction-specific callbacks
remain untested. Exact 70959 FrameXML is absent from the shared corpus;
70938 source guided the implementation and the results above are live 70959
evidence.

Cleanup restored the original combined-bag setting, keyboard bindings and
three AddOns.txt snapshots. New vendor settings, the temporary vendor install
and the QA addon were archived out of the game installation. Installed Offhand
source matches the candidate. WoW was closed normally and Battle.net retained.

## Actual NPC and player inspection follow-up

On the same Forever 70959 mixed-height layout, with OneForAll 6.2.11 enabled,
the native separate backpack remained visible on Offhand while an actual NPC
gossip conversation was opened by right-clicking the NPC. GOSSIP_SHOW and
GOSSIP_CLOSED were captured. First Escape closed GossipFrame and retained the
NPC target; second Escape cleared the target. The bag remained at the same
Offhand bounds.

A nearby real player was selected and inspected through the native target
portrait menu. The equipment/model inspection UI and INSPECT_READY events
establish that this was an actual inspection rather than an empty frame.
First Escape closed InspectFrame while retaining the player target, and the
second cleared the target. The bag stayed visible at the same Offhand bounds.
No player names or GUIDs are included in the evidence summary.

The follow-up trace is dist/real-bag-escape-qa/latest.json and its checked
summary is verified-results.json in the same ignored directory. If an explicit
typed marker is absent, the verifier requires a matching automatic state-change
sample and corresponding server interaction event. No blocked or forbidden
action event was captured in this follow-up.

The older fixture observer's automatic sampling and error-event recording
expired after 42 seconds, which limits its earlier no-error claim to that
active interval. This follow-up extended automatic sampling to ten minutes
and made blocked/forbidden event collection independent of its timer. The
corrected real NPC and inspection sequences were captured again.

Forever Bag Mover was not enabled during these actual interactions; its
earlier modifier-specific fixture and B/Shift-B results remain separate.
No merchant purchase, training, quest action, message, flight, combat or travel
was automated. Other bag-addon combinations are not certified by this run.

The installed addon contains other candidate changes: eight Core files differ
by bytes from this bag branch after excluding generated files and the observer.
Seven differ after normalizing line endings.
Three of those differences are among the dependencies recorded in
tests/compatibility/forever-native-real-escape.json. The new freshness check
therefore requires a matching integration run before that branch or a final
merged package is described as verified. Receipt hashes record the tested
installation and were not rewritten to hide those differences.

Cleanup removed the temporary observer and its saved trace from three saved
copies, restored three addon-selection snapshots and the original bag setting,
and closed WoW normally. Battle.net was retained. The runtime fixes and
compatibility safeguards are reviewed in Offhand PR #129; these results
describe the tested local installation.
