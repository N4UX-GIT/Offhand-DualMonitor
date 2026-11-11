# EllesmereUI scale and portrait/4K HUD investigation, 2026-11-10

## Scope and native baseline

OH-UI-038 and OH-UI-039 are separate reports. The larger-text reporter names
Forever and suspects EllesmereUI but provides no exact build/profile/image.
The portrait/4K reporter supplies HUD screenshots and a three-line diagnostic.
All three images were reviewed in the preceding read-only collection. No
Discord messages, statuses, tags or thread state were changed.

Local native baseline: Forever 1.60.1.70862, English, Windows, Companion 2.1.5,
EllesmereUI core 9.8.4. Companion spanning explicitly applied before entry,
2560x1440 single display split into 1280x1440 Mainhand right/workspace left.
This is not the reporter's physical portrait/4K arrangement. No movement, NPC
transactions, item actions, combat or guide advancement. The user-authorized
test character remains beside the merchant. Private helper uses addon-owned
buttons and bounded, read-only frame/font/scale samples; no native hooks,
unit/chat reads or shutdown callbacks.

Native samples 1-5 show root scale 0.4344242513, saved EUI scale 0.6399999857
and PP.mult 0.8333333520. The actual pixel grid requires about 1.2276785463.
Calling EUI's existing PP.SetUIScale(0.8) from an addon-owned test button grows
the native Character sheet text and leaves the workspace mask/HUD stale (6/7).
An explicit Offhand layout restores its normal root and placement, but PP.mult
still describes 0.8 (8/9). EUI 0.8 followed by disabling Offhand resets the
root to the older 0.64 (10-13), overwriting the later selection. Re-enabling
restores the spanned baseline (14/15). All samples report spanning/READY,
including the disabled comparisons' still-spanned physical window.

CharacterLevelText remains approximately 14 font units throughout. Its
effective scale changes with the root, demonstrating inherited size rather
than a changed font-size setting in this controlled case. Four historical
BugGrabber records retain identical message/time/counter/stack values.
The first run unexpectedly loaded Details through an enabled child despite
its disabled root flag; no wizard action was taken. Subsequent flags isolate
EUI core and the QA/error helpers by disabling other custom entries, although
a Details meter remains visible in the corrected session. Do not claim a
pure core-only runtime from the flags alone.

## Candidate correction

EllesmereScaleCompatibility follows the actual root for PP.mult while spanning,
without changing EllesmereUIDB or font settings. Two idempotent post-hooks on
EUI's public UpdateMult/SetUIScale methods maintain the grid and coalesce a
deferred geometry refresh after a player scale change. That refresh runs the
normal layout pipeline while preserving the newly selected root scale. It
does not hook UIParent or native frame ancestry. Disabled/unspanned/combat
states yield; a pending callback rechecks them before applying geometry.

Viewport release now restores only a root it still owns. If a normal explicit
Offhand layout later reclaims an externally changed root, it remembers the
newer baseline for release. Existing legacy-CVar migration remains separate.
Ordinary Offhand layout/reload still applies its configured HUD scale; this
change does not replace that policy or merge the two addons' scale preferences.

The disable ownership regression fails before correction and passes after.
Pixel-grid, setter coalescing, disabled/combat/missing capability and layout
pipeline tests pass. All 122 frozen Lua suites and six manifest Lua 5.1 checks
pass (81 runtime Lua files and one XML). All 104 private ZIP entries verify.
Candidate SHA-256:
dba0e873a99ec65ccc93391eb8803a646e723e2c8c0428a339095ad8b55a4773.
Runtime changes are the new adapter, Init, Viewport and six TOC entries.
Installed source is backed up in full; generated bridges are preserved.

## Corrected native verification

The first corrected launch disconnects before character selection with
WOW51900319. One normal authenticated launcher retry succeeds; spanning is
explicitly applied again before entry. Corrected samples 16-20 report PP.mult
1.2276785463 at root 0.4344242513, matching the actual grid while leaving EUI's
saved 0.8 unchanged. EUI 0.8 now retains its selected root and restores the
workspace seam to x=1280 without an extra manual layout (21/22), observed
visually. The raw WorldFrame rectangle was already correct in the baseline;
do not describe the old mask problem as a measured camera-rectangle failure.

Disabling retains 0.8 (23/24). A distinct comparison sets EUI 0.9 while disabled
(25), enables Offhand (26/27), then selects EUI 0.8 again (28/29). Disabling
leaves that later 0.8 intact, rather than restoring the older 0.9 (30/31).
Re-enable returns the configured spanned baseline with a correct grid (32/33).
Normal /reload retains that baseline and saved EUI preference (34-37), and
Character text is reopened for comparison (38). All 38 samples report
spanning/READY. Selected font sizes and UI/text CVars remain unchanged across
the samples; bounded native assertions pass. This does not accept every native
HUD anchor at enlarged scale: large existing custom footprints can still clip.
No EUI Blizzard Skins or populated-guide acceptance is claimed.

Four historical BugGrabber records remain identical through normal exit.
Closed the target client; Battle.net/Companion remain open. All 97 installed
non-bridge files match the frozen candidate, with both private helpers disabled.
The corrected private build remains installed; no commit or public release.

Cleanup provenance: seventeen original files were captured before the first
launch. The extra EUI backup pass initially used SavedVariables global names
instead of addon filenames, missing the actual core file. Before another save,
the engine's .bak retained its pre-run .lua (timestamp preceding the run and
saved scale 0.6399999857); this was preserved and restored in full, hash
189ac2cf1d882ebf37daccb0d75276b74875f1253c419faebd4b3d401f94c108.
The recovered profile is also retained as a valid .bak. The original older
backup generation was not captured and is not claimed restored. Thirty-four
additional vendor files were checkpointed later. Final restoration verifies
53 checkpoint files and 126 absences, with four new scoped files retained
privately. Those counts are not a claim of 53 pristine pre-run backups.

## Portrait/4K evidence

The cropped diagnostic reports physical 5280x2560, Mainhand=(1440,400
3840x2160), workspace=(0,0 1440x2560), effective scale 0.591. Source tracing
through Init/GetOperatingDiagnostics establishes that 400 is gamePixelBottom.
It is already bottom-origin, not Windows Y: the Mainhand top is 2560 and its
bottom is 400. The earlier review's top-origin interpretation was corrected.
No Windows display realignment is required by this evidence.

An exact rectangle replay preserves physical (1440,400 3840x2160) through
Viewport.Apply. Native generation and EUI projection now include this eighth
arrangement at three bar scales, with bounds, separate right-bar columns,
custom-anchor preservation and source immutability. All 48 combinations pass.
These are simulations, not physical multi-display acceptance. No topology
calculation defect was reproduced, and the user's populated guide/owner/profile
remains untested. Never infer a full HUD fix from the cropped arithmetic.

## Provenance and remaining gates

Knowledge README/research skill/status and scale/font/ownership searches were
consulted first. Pinned Forever cache is review-due and older than 70862; it
does not contain this EUI 9.8.4 interaction. Authoritative evidence is the
installed Startup/PixelPerfect source (hash receipts retained privately),
current Offhand source and the native baseline above. No vendor implementation
was copied or modified. Existing exact-build font-source audit remains separate.

Ignored dist/discord-qa-20261110-8 retains fresh scoped backups, source hashes,
native samples, bounded readers, validated subject, candidate and installation
receipt. Exact reporter cold-start triggers, EUI Blizzard Skins/font options,
physical portrait/4K display, custom HUD profiles, populated guides and
combat/protected actions remain open. Daylight live testing stays deferred.

## Blizzard Skins native follow-up

Further spanned Forever 1.60.1.70862 testing uses installed EllesmereUI 9.8.4
and EllesmereUIBlizzardSkin. The actual loaded flags confirm both, with EUI
ActionBars and UnitFrames absent. Details is also loaded despite its initial
disabled flag, so this is not a pure two-addon isolation run. Its setup wizard
appears on cold entry and is not clicked. It is absent after normal /reload.

The native Character sheet visibly has the EUI skin on cold entry, after a
normal Offhand layout refresh and after reopening following /reload. Thirteen
bounded samples all retain spanning/READY, root 0.4344242513 and PP.mult
1.2276785463. Selected font point sizes, faces and UI/text CVars stay unchanged:
CharacterLevelText is about 14, GameFontNormal 12, GameFontNormalLarge 16 and
selected quest text about 13. All recorded faces remain FRIZQT__.TTF. This
does not test an alternate EUI typeface preference or actual NPC quest dialog.
No new font/startup defect is reproduced, so no additional runtime fix is made.

Installed WindowEngine WSkin.Font/FontFamily and Forever Character sheet source
preserve existing point sizes when selecting a typeface. The reviewed quest
skin path does not establish a generic font-size increase. Local source hashes
and private observer evidence are in ignored dist/discord-qa-20261110-9.
The shared Forever corpus remains older than 70862; the additional targeted
skin/font query has no matching local evidence. That is a coverage gap.

Normal client exit leaves four historical BugGrabber records unchanged by
message/time/counter/stack. Fresh pre-launch backups include the actual EUI
core and skin addon filenames and their .bak files. All 53 existing scoped
files restore by SHA-256; 126 original absences restore, with newly created
files retained privately. Both private observer TOCs are disabled. The 97
installed non-bridge product files match the previously validated candidate;
generated Companion topology and Forever state bridges remain preserved.

GET-only Discord refresh at 15:36:03 UTC retains 42 threads (19 archived),
2,292 messages, ten referenced originals and zero gaps. No new or edited
message content, threads or referenced originals: all differences disappear
when attachment URL query strings are removed. No new image content to review.
No Discord messages or statuses changed. Physical portrait/4K hardware,
populated guides, exact reporter profiles/triggers and combat remain open.
Daylight testing stays deferred.
