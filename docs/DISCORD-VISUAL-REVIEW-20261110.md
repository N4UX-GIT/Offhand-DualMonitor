# Discord visual evidence review, 10 November 2026

This supplements the [complete report review](DISCORD-REPORT-REVIEW-20261109.md).
Earlier investigations inspected selected attachments. This pass inventories and
visually checks every image attached or linked in the accessible forum snapshot,
including archived threads, and samples every video. It does not establish that
every reported defect is resolved.

## Coverage and evidence boundaries

The read-only snapshot contains 40 threads, 19 archived, collected on
9 November at 22:21 UTC. Twenty-four threads contain visual attachments: 95
distinct attachment IDs, comprising 88 images and seven videos. Five images are
byte-identical copies under different IDs. Three additional original support
images were checked: the HUD after-reload pair and the BetterBags/RestedXP
recurrence. Total coverage is 91 images and seven videos, 93 distinct file hashes.
The other forum threads contain no image/video in this snapshot; this does not
mean that the reporter never supplied one elsewhere.

All 95 forum attachments were retrieved. Six initially missing unsigned/copied
links were recovered using signed URLs already present in the collected original
messages. No new Discord API calls, messages, reactions, status changes or thread
changes were made. Attachment downloads used HTTPS GET against Discord media
hosts. Unrelated historical support-channel attachments are outside this audit.
User-supplied screenshots in this conversation were also reviewed, separately
from these counts.

All images were inspected in 34 labeled overview sheets, with original diagnostic
crops and selected full-size images used in the related investigations. Overview
coverage is not a claim that every small diagnostic line was transcribed. The
seven videos were inspected through 87 samples at approximately one frame per
second, across 19 sheets. Sampling cannot exclude a one-frame flash. The aura
clip has a separate, earlier review of all 274 decoded frames and selected full
frames in [UI flashing reports](UI-FLASHING-REPORTS-20261109.md).

The second controller clip advertises 13.42 seconds in its container, but a fresh
video-only decode produces 218 frames ending around 7.30 seconds. Its seven
samples cover that video stream, not 13 seconds of continuous visual evidence.
Audio and unavailable video intervals are not treated as reviewed visuals.

Private per-attachment hashes, contexts, local paths, review level and findings:
`dist/discord-image-audit-20261110/review-receipt.json`. The download receipt,
34 image sheets, 19 video sheets and HUD comparison remain alongside it, outside
the product manifests and packages. The snapshot SHA256 is
`b9feccbb7f294257f7bf684673026125abe43f6215f5ad8de80abeccc62675e3`.

## What the visuals establish

| Report | Visual evidence and consequence |
| --- | --- |
| [Mismatched heights](https://discord.com/channels/1491522138371391691/1555707584915439646) | The left physical workspace occupies only the lower part of the span. The empty area above it must not be treated as a reachable display. Preserve the existing physical-region recovery boundaries. |
| [Retail login layout](https://discord.com/channels/1491522138371391691/1556723456282861741) | The small crop shows an automatic Edit Mode layout message. It supplies no full-window geometry or new persistence proof. |
| [Level-up taint](https://discord.com/channels/1491522138371391691/1556770591531475004) and [beta19 combat](https://discord.com/channels/1491522138371391691/1557467476663468123) | Both error images name SetPassThroughButtons through quest-provider pin acquisition. They identify the failing path, not the first contaminating write. Retain the map ownership/taint investigation. |
| [Detached chat](https://discord.com/channels/1491522138371391691/1557094374200840274) | Separate workspace chat positions change while world/map/character remain placed. This supports the existing chat persistence scope rather than a general viewport reset. |
| [Quest item combine](https://discord.com/channels/1491522138371391691/1557139720675262555) | The image identifies the quest item and combine operation. It does not contain a blocked-function stack. Preserve the separately recorded native bag-action acceptance. |
| [Older Companion scaling](https://discord.com/channels/1491522138371391691/1557457561039409253) | The app's controls are visible in this image. It is not the later missing-Mainhand-dropdown reproduction. |
| [Large text](https://discord.com/channels/1491522138371391691/1557468806195060921) | Speech bubbles, map labels and damage text are different surfaces in the submitted images. Do not classify them all as one font setting or infer friendly-nameplate behavior from them. |
| [Map keys](https://discord.com/channels/1491522138371391691/1557777525760073828) | The map is absent from the workspace in the shown state. A still does not identify the key handler or map owner that suppressed it. |
| [Linux focus](https://discord.com/channels/1491522138371391691/1557837307820904600) | The clip alternates restored/spanned geometry with desktop/Companion visible; one still includes a noisy horizontal strip. Native Linux compositor/focus attribution remains separate from UI placement and the later reporter configuration workaround. |
| [Better Forever Chat](https://discord.com/channels/1491522138371391691/1558483840542974094) | Overlapping inactive Combat Log and General content supports the stale ChatFrame2 migration investigation. It does not prove all reported button-strip behavior. |
| [French setup](https://discord.com/channels/1491522138371391691/1560316087269335082) | English setup copy and a topology mismatch appear together. Localization coverage and display calibration are separate defects. |
| [Retail cutscene/panels composite](https://discord.com/channels/1491522138371391691/1566101794562515045) | The attachments show distinct signup, application, vehicle and completion surfaces. Two small Mythic completion pictures are reference illustrations, not placement acceptance screenshots. Later reporter acceptance and diagnostic traces retain their narrower scope. The MoveAny clips show Group Finder moving/reappearing at different positions, but do not expose the first writer. |
| [Guild/chat windows](https://discord.com/channels/1491522138371391691/1567906926648631316) | Full-window images show dialogs crossing the seam. Frame-stack context helps identify roots, but does not itself prove a source callback caused the move. |
| [ForeverPlus warning](https://discord.com/channels/1491522138371391691/1567909191803347006) | Warning-window context is visible. No new protected-function stack appears. Keep its existing acceptance scope. |
| [WhisperMessenger](https://discord.com/channels/1491522138371391691/1567914589495234641) | The generic blocked-action dialog names WhisperMessenger but omits the protected function and first contamination. It cannot by itself attribute a new Offhand protected-action defect. |
| [Controller/stacked composite](https://discord.com/channels/1491522138371391691/1567984437009055764) | The initial clip shows map enlargement after Spellbook opens. A later keyboard/mouse clip shows a small map dragged into the upper workspace and then enlarged. Later originals explicitly accept the controller correction while reporting the friend's keyboard/mouse growth persists. Cooldown Settings, Talents, mailbox/AH reachability and contextual Back are separate symptoms. The phone photo shows Game Menu spanning the physical horizontal bezel. |
| [Combined backpack](https://discord.com/channels/1491522138371391691/1568072216019468329) | The two images are identical. Edit Mode selects Action Bar 2 and shows the bag cue. They do not establish an open bag's visibility lifecycle. |
| [Missing Mainhand dropdown](https://discord.com/channels/1491522138371391691/1568241793823154206) | The first app image omits/clips the dropdown; a later one exposes it. The Windows 100% setting shown is for a different portrait display, so it does not disprove the reporter's primary-display 175% setting. |
| [Aura/Daylight flashing](https://discord.com/channels/1491522138371391691/1568299430090903602) | The checkbox image records the rerouting workaround. The detailed aura-video review supports transient movement, not a caller identity. Daylight's world-map conflict comes from a separate reporter/source study; its native test remains deferred. |
| [Retail friendly names](https://discord.com/channels/1491522138371391691/1568729606352273418) | Diagnostics identify Retail 12.1.5 build 70783 and manual stacked geometry, rather than the working Forever installation. Keep the friendly-name CVar correction distinct from friendly-nameplate behavior. |
| [SexyMap/profile visibility](https://discord.com/channels/1491522138371391691/1569183781720686775) | These six images are diagnostics, not before/after pictures of the minimap. They show profile/revision changes, but lack the minimap's visibility state and Hide writer. Fresh-profile recovery does not establish which setting caused the old-profile problem. |
| [EUI minimap relocation](https://discord.com/channels/1491522138371391691/1569423787605237938) | The game images place the minimap first at the top-right boundary and later behind bottom-center action bars. This establishes relocation, not a visibility toggle. It does not identify the writer. |
| [HUD after reload](https://discord.com/channels/1491522138371391691/1569461564438745109) | The original support message labels one pair "before reload" and the next "this after". The first pair is two halves of the same span, not before/after by itself. After reload, minimap/chat and additional action bars are visible on Mainhand while map/character remain on the workspace. The bot summary reverses the reported direction. Native Save serialization still needs comparison. |
| [BetterBags/RestedXP recurrence](https://discord.com/channels/1491522138371391691/1551335554787057694/1569474526318698588) | The additional original image shows both vendor surfaces on Mainhand in the auction-house scene. It contains no installed-build/module-version evidence; compare the exact candidate, roots and profiles before calling it a regression of private test19. |

## Implementation and acceptance consequences

This pass adds evidence and narrows attribution; it makes no new runtime change
or report-closure claim. The current keyboard map path already caps the map by
both destination width and height and yields to supported external map owners.
That source property does not close the old keyboard/mouse video report without
a candidate retest at the failing geometry. Its friend's exact build/profile and
map owner are still missing. Existing source tests cover region fitting and owner
boundaries; the controller's acceptance cannot substitute for this retest.

OH-UI-034 needs the affected native layout's serialized anchors before Save,
after Save and after reload. The existing bounded issue observer supports those
snapshots. The successful local minimap keyboard Save/reload test is narrower
than the reporter's multi-system failure. No profile reset, blanket Show loop or
automatic layout regeneration is justified by these screenshots.

OH-UI-030 combat shifts, OH-UI-031 real roll disappearance, OH-UI-032 ProcDoc,
OH-UI-033 contradictory client/offset and OH-PERF-002 GPU load do not gain new
visual evidence from this inventory. Their capture/acceptance gates remain in
the [report review](DISCORD-REPORT-REVIEW-20261109.md) and
[implementation record](DISCORD-FIXES-20261110.md). Daylight native testing remains
deferred. Existing validated candidate and live QA results are unchanged.

Knowledge routing: refreshed the stale local search index and ran the
Forever-scoped map-scale query. Local source, the original message chronology
and attachment bytes are the authority for this review. Retrieved older
knowledge notes have their own dates/scopes and do not supersede the later
Daylight implementation or native QA records.
