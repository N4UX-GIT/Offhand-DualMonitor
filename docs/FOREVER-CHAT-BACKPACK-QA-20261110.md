# Forever chat and workspace backpack QA, 2026-11-10

Continued the remaining Discord reports with Daylight testing deferred. This
pass isolates stock chat: EllesmereUI core and all replacement chat/bag addons
are disabled. Offhand, the private observer, BugGrabber and BugSack are enabled.
No chat messages, rolls, item actions, NPC interactions or gameplay inputs were
sent. The private observer stores geometry and visibility, not chat contents.

## Baseline native result

Forever 1.60.1 build 70862, Companion 2.1.5, single 2560x1440 display with
1280x1440 Mainhand on the right and workspace on the left. Applied spanning
before entering the same idle test character; all snapshots report READY and
spanned. Stronger workspace locking is unsupported on Forever and remains off.

The baseline private archive is SHA-256
`e8dcfaf3b28ded4cc95e6315d708cab2d06986821e81c137f3deaad7b14b7b9d`.
Its 96 installed non-bridge product files were verified before launch.

General and Combat Log switch correctly, with exactly the selected message
frame visible. Both remain in the native dock. General's menu/channel buttons
follow its parent visibility; hidden voice buttons were not forced on. Chat
Settings, native Edit Mode entry/exit and reload did not reproduce the archived
inactive Combat Log overlay. A native chat drag attempt did not meaningfully
move the root; reverted its unsaved change through the native UI. No physical
drag or affected old-profile acceptance is claimed.

The first backpack check used default workspace placement without a saved
workspace record. Its closure does not exercise the persistence controller and
is not evidence that tracked-open restoration failed. Repeated the comparison
with an explicitly committed workspace record and tracked-open state, using a
private addon-owned button and the production persistence helpers. This is a
controlled saved-placement fixture, not acceptance of physical bag dragging.

The frozen pre-fix runtime then reproduced a tracked-backpack failure:

1. Open the backpack with B and commit its current workspace geometry using
   the private fixture; diagnostics confirm saved=1 and tracked=1.
2. Right-click General, select Settings. Chat Settings opens on Mainhand and
   the backpack disappears.
3. Dismiss Settings with Okay. The backpack remains closed.

Controlled baseline snapshots 15/16/17 show backpack visible=true and tracked=1,
then false and tracked=0 while ChatConfigFrame is visible, then false after it
closes. The workspace record remains saved=1. General remains visible and Combat
Log hidden. BugGrabber's four historical message/time/counter/stack records are
unchanged. This extends the analogous Retail report with a distinct Forever
native reproduction; it does not accept the Retail path or replacements.

## Correction and automated evidence

ChatConfigFrame was absent from CanvasForeverBags' preserving-panel list. Added
that exact root to the existing external controller's navigation classification.
This uses its existing native bag API recovery and explicit-close handling. No
new hook, ticker, visibility write, native script, panel metadata or lock policy
was introduced. The shared predicate also serves supported replacement adapters;
those vendor paths still need separate native acceptance.

The regression fails on the frozen baseline, then passes with the correction.
It covers the panel-triggered hide and a later explicit B close while Chat
Settings remains open, including dismissal without resurrecting a closed bag.
All 121 frozen Lua suites pass. Six manifests validate 81 runtime files (80 Lua,
one XML) with Lua 5.1. All 103 private ZIP entries verify by byte/hash.

Frozen follow-up archive SHA-256:
`698a6566c5d535475184713eb6875433c9073b59e05f773c815af42f41b5374b`.
Only Core/CanvasForeverBags.lua changed at runtime. Installed that verified file
after normal client exit and a full installed-addon backup. Generated topology
and recovery bridges remain byte-identical across installation.

The native comparison confirms the correction: snapshots 19/20/21 retain
tracked=1 and saved=1 through Settings, then restore the visible backpack at
exactly the same captured geometry after Okay. The bag remains hidden while
Chat Settings is open; continuous visibility is not claimed. B closure afterward
clears tracked-open state. A second Settings visit followed by B while the bag
is hidden leaves it closed after Okay (snapshots 23/24).

## Native X close correction

The native combined backpack's X click initially closes the root and then
Offhand reopens it. The bounded read-only trace records native CloseAllBags
from ContainerFrameCombinedBagsMixin.Close, with GetMouseFoci already empty.
Offhand's existing focus-only close classification consequently mistakes this
explicit close for navigation. The native callback is confirmed by the same
70862 source revision's Mainline ContainerFrame.lua around line 3026 and XML
onCloseCallback binding. Four historical error records remain unchanged.

Extended that classification with the native close button's read-only
IsMouseOver result, outside combat and guarded for forbidden, secret or failed
queries. No native frame state/script, new hook or retained focus sample is
added. The failing-before regression reproduces empty mouse focus after hide;
an unavailable hit test retains ordinary navigation recovery. All 121 frozen
suites and the six-manifest Lua 5.1 checks pass again; 103 ZIP entries verify.

Final private archive SHA-256:
`ddc00aaa1bf9116c768b9af8104f8065acc716c662939e46adc19e5ff4322cde`.
Runtime delta remains Core/CanvasForeverBags.lua only, relative to both earlier
archives. Installed module SHA-256:
`3738bde88f2c545c923650a094be51536950fd2a51bb29e14aed68b31654bc0b`.
Generated bridges remain preserved across this installation.

On that final build, the native X stays closed (snapshot 31). Reopening with B,
Settings, Okay and another X retains the same saved workspace geometry and
correct intent (32/33/34/35). The native trace confirms IsMouseOver=true while
GetMouseFoci is empty after the close, and the bag remains closed on the next
controller update. A normal /reload leaves it closed. This validates the local
out-of-combat combined backpack, not separate bags, replacement addons, Retail,
combat/protected item actions, physical dragging or the affected old profiles.

Reload snapshots 36/37 retain bag=false and tracked=0, with the saved workspace
record intact. Closed the target client normally. All four historical
BugGrabber message/time/counter/stack records remain identical; this does not
establish combat or taint safety.

Restored all twelve scoped original files with SHA-256 verification, including
addon flags, Offhand settings, observer source, chat cache and native local
caches/config. Disabled the issue observer TOC; the performance helper remains
disabled. Vendor profiles were not changed. Local cache restoration does not
claim rollback of server-side native layout state. Battle.net and installed
Companion remain open. The final verified private candidate stays installed
with a full addon backup. All 96 non-bridge product files match the prior
installation receipt with the single verified runtime-module delta. No public
package or Discord state changed.

## Source and private evidence

Knowledge lookup returned authored guidance and the known pinned-build gap.
The exact-build source study uses revision
`9dc84f0d3bbae1768ac3405b3716000bd93eda06`, already identified as Forever 70862.
[FloatingChatFrame.lua](https://github.com/Gethe/wow-ui-source/blob/9dc84f0d3bbae1768ac3405b3716000bd93eda06/Interface/AddOns/Blizzard_ChatFrameBase/Mainline/FloatingChatFrame.lua#L683)
opens ChatConfigFrame through native ShowUIPanel. That source entry point is
distinct from the observed closure and the simulated controller regression;
the baseline capture does not identify every internal native close caller.

Ignored `dist/discord-qa-20261110-4/` holds scoped backups, stock-chat and
controlled tracked-backpack snapshots, data-only upstream files/hash receipts, failing-before output,
frozen validation subject/archive and installation receipt. Account paths and
chat-cache files remain private. No Discord mutation or publication occurred.
