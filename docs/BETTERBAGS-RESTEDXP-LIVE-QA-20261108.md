# BetterBags and RestedXP native placement QA, 8 November 2026

Result: PASS for the tested out-of-combat placement matrix on private test19.
No production code change was needed after the source correction. Two temporary
test-harness issues were identified and corrected separately below.

## Environment and package

- Forever 1.60.1.70862, keyboard interface, level-2 test character.
- Offhand `2.1.2-beta.26-forever-discord.test19`, BetterBags v0.9.2 and
  RXPGuides v4.11.34. Existing ForeverPlus and other installed addons retained;
  competing bag replacements temporarily disabled with backups.
- Temporary remembered 50/50 workspace-left/Mainhand-right layout in the normal
  client window. This tests the native split placement paths, not the reporter's
  unknown physical monitor layout or a mixed-height gap.
- All 99 Lua suites pass in source and extracted packaged runtime; six extracted
  manifests validate. Installed 80 runtime files match the candidate. Frozen
  public Beta20 Companion and both immutable test18 archives are unchanged.
- [Source investigation and package hashes](BETTERBAGS-RESTEDXP-PLACEMENT-20261108.md).

Battle.net initially reached WOW51900308. The user handled authentication and
entered the safe character. The user also moved to a real vendor and opened it;
subsequent checks reopened that same adjacent vendor without character movement.
No buy/sell clicks or commands were issued. The existing ForeverPlus auto-sell
feature ran on the user's initial vendor opening.

## Observed behavior

| Placement / mode | Native checks | Result |
| --- | --- | --- |
| Classic bags, workspace | Map open/close, settled popup scan, reload, B reopen | Saved bag and RestedXP V1 positions retained |
| Classic bags, Mainhand | Map open/close, settled scan, reload, B reopen, real vendor opening and B close/reopen | Positions retained |
| Classic bags, workspace after normal title drag | Real vendor close/reopen | Bag retained the dragged position; guide stayed placed |
| Classic anchor mode | Native `/bbanchor`, drag backpack anchor onto workspace, B close/reopen, map transition, reload and B reopen | Bag remained attached to its vendor anchor; both shown anchors escaped automatic centering |
| Next small bags, workspace | Map open/close, real Next vendor panel opening, settled snapshot, reload and B reopen | Bag and guide positions retained |
| Next small bags, Mainhand | Map open/close, vendor close/reopen, reload and B reopen | Bag and guide positions retained |

The initial classic fixtures used LibWindow and RestedXP's SaveFramePositions.
The Next fixtures used the vendor's SetNextSmallPlace/GlideTo methods. These are
controlled native placement/persistence checks, not manual-drag acceptance for
Next. The automated Next title drag did not relocate it, so that gesture is not
accepted. Actual classic title and anchor drags did move their windows and were
observed separately.

The recorder contains 124 samples, seven world-entry/logout pairs (initial login,
six reloads, final exit), and five actual merchant-opening transactions with
settled observations. For example, Next retains rendered left/bottom coordinates
99.608/1245.844 on the workspace and 1671.037/1245.844 on Mainhand through the
relevant settled transitions and reload reopening. Opening-slide samples differ
temporarily by design and are not used as final positions. Classic anchor reload
has normal sub-unit LibWindow rounding, with the bag still attached to its anchor.

RestedXP used its welcome V1 guide shell without loading or advancing a guide.
This accepts frame placement, not quest or guide-content behavior. BetterBags
owns bag visibility at login; automatic reopening after reload is not promised.

## Harness findings and errors

1. Moving the classic bag through the first fixture changed its LibWindow save
   but left an earlier Offhand Mainhand snapshot. On the next vendor opening it
   returned to that earlier position. A normal title drag correctly updated the
   ownership and the repeat passed. The fixture now clears its previous test
   snapshots before changing destinations. This was a fixture failure, not an
   additional product correction. The original failed samples are retained.
2. The optional Character-panel fixture invoked ToggleCharacter from an insecure
   addon button. BugGrabber recorded four TextStatusBar.lua:110 secret-number
   comparisons explicitly attributed to OffhandPlacementQA. The retained stack
   ends in that test callback through CharacterFrame.lua. Removed that helper;
   future Character tests must use the client's real binding. Character-panel
   protected-action safety is not accepted from this run.

No product-attributed BugGrabber message/counter increase was recorded. The final
retained taint log contains no blocked-action headings, forbidden-action matches
or SetPoint matches. That log covers the final retained reload interval; it does
not establish complete whole-session taint freedom. The QA-attributed errors are
preserved, not removed from the user's error history.

## Cleanup and limits

Closed the specific test client normally. Restored all 33 original settings,
enablement/cache files and two generated bridges byte-for-byte. Moved eight
newly created test-state files to the private evidence folder and removed the
temporary QA addon from the game. Existing Battle.net and Companion stay open.
Test19 remains installed; previous runtime backup and archive hashes retained.

Private evidence is under `dist/betterbags-rxp-20261108/`, including the used QA
source in removed-test-addon, redacted geometry samples, error deltas, retained
taint log, cleanup receipt and acceptance summary. No QA or account state is
included in either package. Bundled test19 notes predate live acceptance; this
report and the external verification manifest record the later result.

Native RestedXP V2, bank interaction, Next full/docked/chain variants, Next mouse
dragging, mixed-height/stacked void recovery, combat, controller and the exact
reporter profile remain separate acceptance items. Next's successful existing
TOPLEFT vendor anchors in this split do not prove all possible anchors are
excluded from generic recovery. No unrelated Discord report is closed by this QA.
