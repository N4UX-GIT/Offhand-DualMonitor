# Discord refresh after bag Escape QA, 2026-11-10

## Collection and visual review

Read-only collector snapshot at 14:50:25 UTC: 42 threads, 19 archived, 2,292
history messages, ten linked originals, zero reported gaps. Against 08:47 UTC,
six support messages were added, with no new threads or missing message IDs.
Three apparent edits only refresh image URLs or Discord content-scan metadata.
The four collector tests pass. No gateway session or Discord writes occurred.

Downloaded all three new image attachments and reviewed them visually. The
Mainhand image shows scattered HUD and overlapping populated RestedXP/tracker
content. The portrait workspace is mostly empty, with chat at its bottom and
text clipped at the right edge. Its chat records automatic HUD layout creation
and a recovery action, which alone do not prove correct final placement. The
third image supplies only three diagnostic lines. These screenshots are report
evidence, not a native reproduction in the local test profile.

## New evidence and disposition

| Report | Finding and remaining check |
| --- | --- |
| [Larger character/quest text after updating](https://discord.com/channels/1491522138371391691/1551335554787057694/1569650173208956948) | OH-UI-038. Reporter identifies Forever and suspects EllesmereUI, but supplies no build, scale values, before/after image or enabled-addon inventory. Keep this separate from tiny text after removing Offhand. Existing source audit finds no global GameFont or userFontScale writer in current Offhand; that does not rule out inherited scale effects. Capture the affected profile before changing settings, then compare font and root/frame scale owners. The bot's cause and release-timing claims are unverified. |
| [Portrait/4K HUD placement](https://discord.com/channels/1491522138371391691/1551335554787057694/1569676680040284262), [diagnostic](https://discord.com/channels/1491522138371391691/1551335554787057694/1569677131733139458) | OH-UI-039. Diagnostic reports Mainhand=(1440,400 3840x2160), workspace=(0,0 1440x2560), Phys=5280x2560, Screen=2681x1300, effective scale=0.591, GameArea=1950x1097. Mixed heights and a nonzero display offset are supported inputs. The offset alone is not a proven defect or a reason to require Windows display realignment. HUD ownership, generated layout and populated guide placement need a matched capture. No speculative topology change. |

The rounded diagnostic values are internally consistent with the current
coordinate conversion: 2560/768 * 0.591 is about 1.97 physical pixels per
UIParent unit. GameArea converts to about 3841.5x2161.1 pixels and Screen to
5281.6x2561.0, matching the reported physical rectangles within displayed
rounding. A later source check corrected the offset interpretation:
ClientRuntime reports gamePixelBottom, so 400 is already bottom-origin, not
Windows display Y. Mainhand spans y=400..2560 and its top-origin offset is zero.
This arithmetic does
not verify native viewport rendering or HUD placement, and the cropped
diagnostic omits build, topology acceptance and layout ownership state.

The populated RestedXP image adds context to earlier welcome-frame tests. It
does not establish a failing reposition call or invalidate the limited welcome
geometry result. No guide was loaded or advanced during local QA. Keep native
populated-guide acceptance open.

## Completed local correction and remaining gates

[Bag Escape QA](FOREVER-BAG-ESCAPE-QA-20261110.md) reproduces OH-UI-035's target
dismissal loop in the spanned Forever client and verifies the private correction,
reload, saved placement and unchanged error records. Health/mana preferences
and profession bags remain separate. NPC quest release still needs an actual
NPC quest interaction after disable/Restore Window; opening a map quest log or
forcing QuestFrame shown would not establish that behavior.

Exact affected HUD/minimap profiles, populated guides, real multi-roll and tall
item cases, combat/controller, mixed physical displays and GPU comparison retain
their existing gates. Daylight live testing stays deferred. Scoped QA settings
were restored and the target client closed before this read-only refresh. No
messages, statuses, tags, thread state, public packages, commits or releases were
changed. Private snapshot, image hashes and delta remain under ignored dist and
the bot's logs/read-only-reports directory.
