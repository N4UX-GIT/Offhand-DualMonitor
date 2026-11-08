# BetterBags and RestedXP placement investigation, 8 November 2026

Status: private test19 is packaged, installed and accepted for the tested native
map/vendor/reload placement matrix. Original settings restored; temporary QA
removed. See the [native report](BETTERBAGS-RESTEDXP-LIVE-QA-20261108.md) for scope
and the two corrected harness issues.

The reporter uses Offhand Beta 26 on Forever. Opening the map, a vendor or
another panel reportedly moves BetterBags and RestedXP to Mainhand's centre.
The reporter's exact addon versions, client build and saved layout are unknown.
Local source inspection uses BetterBags v0.9.2 and RXPGuides v4.11.34, both with
Forever 16001 manifests. Subsequent native QA uses Forever 1.60.1.70862.

## Findings

`Core/SeamRedirect.lua` runs a general popup rescue pass every two seconds. It
can centre visible UIParent children when they retain a zero-offset full-parent
CENTER anchor or extend above Mainhand into the apparent monitor gap. Before
this correction, the child scan did not honour user placement or these addons'
position ownership. A separate ShowUIPanel centering hook also lacked that
check. The generic UISpecialFrames OnShow callback already respected user
placement, but its hook installation did not consistently yield to these owners.

BetterBags owns its positions through LibWindow. Its two window roots are
`BetterBagsBagBackpack` and `BetterBagsBagBank`, created by
`frames/bag.lua:830` and `window/window.lua:219`. It also creates corresponding
UIParent anchor roots, named with an `Anchor` suffix in `frames/anchor.lua:147`.
Moving an anchor can move the attached bag even if the bag root was untouched.

RestedXP owns `RXPFrame` and `RXPItemFrame` and saves enabled-frame positions in
`SettingsPanel.lua:4322`. Its newer guide uses an anonymous frame exposed through
the public AceGUI widget `RXPV2GuideWindow.frame` in `UI/V2/Core.lua:1472`.
The widget table itself is not the frame. Named-frame exclusions alone miss it.

These sources establish an ownership conflict capable of producing the reported
centring. They do not establish that every map or vendor opening triggers it in
the reporter's layout. Forever already bypasses the legacy UIPanel offset path;
no change to that path or Blizzard/vendor source was needed.

## Implemented correction

1. Add a shared automatic-popup position policy in `Core/HUDCompatibility.lua`.
   Yield to the six verified named roots, the currently exposed anonymous V2
   guide frame and explicit user placement. Unreadable or secret placement/name
   results conservatively prevent automatic writes.
2. Apply that policy before generic hook installation, on showing a popup,
   during the UIParent child sweep and in immediate/deferred ShowUIPanel
   centering. Recheck current ownership when callbacks run.
3. Retain ordinary misplaced-popup recovery. Explicit workspace movement,
   vendor position saving, native bag combat adapters and saved-variable schemas
   keep their existing behavior.

## Validation

- The new integration regression fails against the immutable private test18
  runtime at `BetterBagsBagBackpack`, reproducing the ownership override.
- All 99 current Lua suites pass with the correction. Coverage includes all four
  BetterBags roots, both named RestedXP roots, its anonymous V2 root, explicit
  user placement, repeated panel transitions, center-area ShowUIPanel calls,
  late/replaced V2 ownership and unreadable/secret property results.
- The ordinary addon-popup rescue regression continues to pass.
- All six manifests pass path/XML checks and Lua 5.1 syntax validation.
- Local evidence and source/vendor hashes are in ignored
  `dist/betterbags-rxp-20261108/`. No third-party implementation was copied.

The source investigation initially left test18 installed. The subsequent
user-requested package/install step replaces it with test19. Native placement
and reload evidence is scoped separately below; no combat/controller acceptance.

## Private test19 installation

Both private test19 archives contain the correction. All 99 suites pass against
source and extracted packaged runtime; all six extracted manifests validate.
The runtime delta from test18 is HUDCompatibility, SeamRedirect, CHANGELOG and
the six private-version manifests. Frozen public Beta20 Companion is unchanged.

Installed 80 runtime files with the game closed, verified their hashes and
preserved both generated bridges. The previous installed runtime is backed up
under `dist/forever-discord-test19-20261108/installed-before-test19-backup/`.
Both immutable test18 archives remain unchanged.

- Addon ZIP SHA256:
  `69886017C903AC71E138F32F0A0ECAE00A42DFFAF4315A77F8BE5BFA046FFA6C`
- Complete ZIP SHA256:
  `E795E21A88FED12A95CF13854186977B3E57FDB168A275A8F8FE9444D469EF7D`

## Native acceptance and cleanup

The user resolved the initial WOW51900308 login prompt and visited a real vendor.
Classic BetterBags and its native anchor mode pass placement checks; Next small
bags and RestedXP V1 also retain map/vendor/reload positions on both sides of a
temporary 50/50 split. Six reloads and five merchant openings are represented in
124 recorder samples. No further production correction was needed.

The controlled placement fixture initially left an older Offhand position record;
normal title dragging corrected ownership and the repeat passed. Fixed the
fixture's snapshot replacement. Four Character status-bar errors are explicitly
attributed to the optional temporary QA button calling ToggleCharacter; that
helper was removed. No product BugGrabber deltas. The final retained taint interval
contains no blocked actions; full-session taint freedom is not claimed.

Closed the client normally, restored all 33 original state/enablement/cache files
and two generated bridges byte-for-byte, removed the temporary QA addon and moved
eight created state files into private evidence. Test19 runtime and both archives
reverified unchanged. Battle.net and the existing Companion remain open. No
publication or external message occurred. Bundled notes predate acceptance; the
external verification manifest and [native report](BETTERBAGS-RESTEDXP-LIVE-QA-20261108.md)
record it.

RestedXP V2, bank interactions, Next full/docked/chain variants and mouse dragging,
mixed-height gaps, combat/controller behavior and the reporter's exact profile
remain outside this native acceptance.
