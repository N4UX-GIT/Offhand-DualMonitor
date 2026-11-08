# Zygor visibility and external map persistence reports

The supplied `9028.png` contains two separate reports. The map report exposes
reproducible defects in Offhand's Forever observer. The Zygor disappearance has
not been reproduced and has no confirmed cause. Combined Discord test.2 includes
the map correction and read-only guide diagnostics, not a claimed Zygor fix.

## Scope and evidence

- Reporter client/build, input mode, addon versions and whether either user ran
  public Beta 26 or a Discord candidate remain unknown. Forever/public Beta 26
  is provisional context, not a fact established by the screenshot.
- Current source is the dirty combined candidate on
  `addon/forever/gamepad-reports-20261105`, based on Beta 26 `9c7e83c`.
- Shared knowledge status and queries were run first; the stale index was
  rebuilt. Client-scoped Zygor and Leatrix searches yielded no evidence. This
  records a coverage gap, not absence of support or APIs.
- Installed Leatrix source was inspected read-only at
  `D:/Games/World of Warcraft/_classic_beta_/Interface/AddOns/Leatrix_Maps`.
  Its TOC declares Interface 16001 and version 1.60.25. Lua file SHA256:
  `226F18F945CDE64C50CB9FD17FC3F6684ABD407A89E64824EE149F1645DBB365`.
  The directory name does not establish a runtime build, and this version is
  not confirmed as the reporter's version. No vendor source was modified or
  copied into the package.
- No Zygor-named directory was found in the inspected local Retail/classic-beta
  AddOns roots, so current vendor source was unavailable for this investigation.
  No unofficial Zygor mirror was used as an implementation
  authority. The vendor's
  [Guide Controls manual](https://www.zygorguides.com/support/manual/controls)
  documents a Reset Window control for viewer/arrow positioning; it does not
  diagnose this conflict.
- No native client, protected-action, taint or cold-launch acceptance was run.

## Confirmed Offhand map observer defects

`Core/CanvasForeverMap.lua` allows an independent observer for Leatrix Maps and
OpenMap because their geometry stays externally owned. Its UpdateHandle branch
then hid that observer when it saw external ownership. Hidden frames receive no
OnUpdate, so closing the map before the next opening could permanently stop
the edge detection that establishes workspace open intent and Escape policy.

The prior OpenMap simulation manually invoked OnUpdate even while the handle
was hidden. That concealed the actual scheduler condition. The updated test
honors visibility and reproduces the failure before the source change.

A second failure remains even if the observer is kept alive: moving the same
open external map between Mainhand and Offhand generates no show edge. Neither
that drag nor a persistence-option change refreshed the Escape policy. The
updated test reproduced the stale close registry after a drag to Mainhand.

The candidate now parks the addon-owned observer off-screen at 1 by 1 with mouse
input disabled, leaving it active. It observes workspace membership and the
persistence option on its existing throttled cadence, and refreshes policy only
when those values change. Membership updates defer during combat. It does not
install native map scripts, take over dragging/scale/anchors, add a new ticker or
force the map open after a user's ordinary close.

Tests cover Leatrix and OpenMap with the map initially closed, subsequent opening,
both seam-crossing directions, persistence toggles while open, no repeated fader
writes in a stable state, combat deferral, Escape, restoration and unchanged
external geometry/scripts. These are simulated regressions, not the reporter's
live acceptance.

The persistence option applies to a map on the Offhand workspace. A map on
Mainhand retains native Escape closure. Native Gamepad map lifecycle remains
Blizzard-owned; this correction is not a promise to override Gamepad Back.

## Zygor investigation

Offhand has no named Zygor compatibility adapter. Its generic popup/void rescue
in `Core/SeamRedirect.lua` can reposition eligible direct children of UIParent,
so geometry/redirection is one possible investigation path. The report does not
establish that this path touched a Zygor frame. Other possibilities include
initialization errors, hidden or transparent frames and saved placement; none
is established as the cause.

The candidate adds `CanvasCompatibility.GetGuideAddonDiagnostics`, called only
by `/offhand diag full`. It checks known addon ID probes/namespace presence and
observed named Zygor children of UIParent/WorldFrame. It reports visibility,
alpha/effective alpha, layer/level, scale and bounds. Discovery is bounded to
256 direct children per parent and eight reported roots, with truncation shown.
Secrets, unavailable getters and nonfinite values remain unavailable.

The diagnostics do not show, move, hook, reparent, rescale or read guide content
from vendor frames. No observed direct root does not prove that Zygor is absent
or uninitialized; its UI may be deeper, anonymously named or outside the bound.

Needed from the reporter:

1. Exact client/build and Zygor/addon version, plus guide viewer versus arrow or
   all UI disappearing.
2. The first fresh Lua/error stack and `/offhand diag full` in the failing state.
3. A reversible A/B test: keep Offhand enabled and the same span, disable
   "Reroute popups & dialogs away from center bezel", reload and compare. Restore
   it afterward. This separates the broad rescue path from viewport behavior; a
   changed symptom narrows the cause rather than proving a compatibility fix.
4. If reachable, Zygor's own Reset Window can test saved positioning after the
   diagnostics are captured. Do not delete either addon's SavedVariables.

## Local release-client verification, 2026-11-05

Test.2 was installed on Forever 1.60.1 build 70790 and tested on a level 1 Orc
Shaman. Leatrix-only workspace Escape passed both initial and later map opens.
After restoring OpenMap, the map reopened after reload and survived Escape with
OpenMap ownership. Native visibility was observed through a temporary read-only
overlay/log because the capture showed only primary-monitor pixels. The observer
was removed and original addon toggles/manifests restored. BugGrabber records
match baseline and historical taint.log is unchanged. Pins, external dragging,
live option changes, Gamepad/loot/combat and Zygor remain unverified.
See [the live report](FOREVER-LIVE-QA-20261105.md) for the exact evidence boundaries.

## Candidate and validation

- Complete bundle:
  `dist/Offhand-Complete-v2.1.2-beta.26-forever-discord.test2.zip`.
  SHA256: `A32DCEC9AAC4F729BD11BB65875EDBE8B064A68D3ABAC59D494AD5D23C64B230`.
- Addon only: `dist/Offhand-v2.1.2-beta.26-forever-discord.test2.zip`.
  SHA256: `46FFA54BFA0521D30AE85F7410C8F44BFCDEA1F7C5E9F10A4DF959B57042C696`.
- Keeps all prior combined test.1 changes and the unchanged Beta 20 Companion.
  This candidate supersedes test.1 for distribution, without changing its archive.
- All 89 Lua 5.1 suites pass in source and the frozen combined validation tree.
  Thirteen targeted suites pass against extracted ZIP runtime files.
- Six manifests validate. All 77 addon entries match both archives and the
  validation tree; the complete archive has 87 portable entries and 86 verified
  internal content checksums. Native Companion SHA256 remains
  `81EECE9430885CEAC178A44A42429854524279072305F9F94EE62E7CCD620CCB`.
- Source hashes, extracted copies, tests and receipt:
  `dist/forever-discord-test2-20261105/`.
- Install/checklist/rollback and a copy-ready Discord draft are included outside
  the addon folder. No client was launched, vendor/installed addon modified,
  message posted or public release published.
