# Remaining Discord reports: spanned Forever QA, 2026-11-10

Continued the approved native QA using the private follow-up from
[the preceding run](DISCORD-FOLLOWUP-QA-20261110.md). No additional product
defect was reproduced or runtime fix added in this pass. Daylight live testing
remains deferred. No Discord communication or report status changes occurred.

## Environment and evidence boundaries

Forever 1.60.1 build 70862; installed Companion 2.1.5; single 2560x1440 display
split into a right Mainhand and left workspace, each 1280x1440. Applied **Span
WoW Now** before entering the same preselected, idle level-2 character in each
session. Captures report spanned=true and topology=READY. No movement, casts,
targets, rolls, NPC interactions or combat automation occurred.

The installed private archive remains SHA-256
`e8dcfaf3b28ded4cc95e6315d708cab2d06986821e81c137f3deaad7b14b7b9d`.
All 96 non-bridge product files still match its installation receipt. Generated
Companion bridges were preserved. This is a frozen candidate, not a claim that
subsequent edits elsewhere in the shared working tree received native QA.

EllesmereUI core was enabled; its separate Minimap module, SexyMap, OpenMap and
Leatrix were disabled. Vendor minimap checks remain in the preceding spanned
report. Temporary, combat-refusing addon-owned buttons opened native UI,
captured bounds/layouts and generated explicitly synthetic tooltip content.
They did not call native SaveLayouts or perform item actions. Native Edit Mode
Save was clicked through the UI.

## Observed results

| Report area | Native result | Remaining limit |
| --- | --- | --- |
| Keyboard world-map sizing | Map remained within the workspace after the drag-stop path, Spellbook opening and reload; repeated configuration retained the same fitted scale. | Automated title dragging did not meaningfully relocate the root. Physical drag and the reporter's upside-down-T display arrangement remain unaccepted. |
| Item tooltip bounds | Cached equipped Worn Mace rendered inside Mainhand at local scale 1. A synthetic 140-line ItemRefTooltip fitted at 0.857886672, with its final line visible. Short content and hide restored scale 1. | The attempted real set item stayed unresolved and provides no acceptance. Actual tall set items, comparisons, rolls, short displays and combat remain open. |
| HUD Save/reload | Chat, Buffs and Action Bar 3 were nudged Right once in native Edit Mode and saved. Serialized layout anchors matched exactly after reload. The corresponding Left nudges were saved afterward. | This is the local native profile, not the affected reporter's EUI/HUD profile or physical mouse dragging. |
| Cooldown Settings | Native ShowUIPanel first-open and reopen remained fully inside the workspace at scale 1. A deliberately seam-centered root was recovered fully onto Mainhand at scale 1. | The forced placement explicitly called production recovery. It does not reproduce the natural offscreen first-show failure or independently prove event timing in that failing topology. Advanced Settings entry and native controller input remain open. |
| Game Menu | Direct GameMenuFrame_Show and ordinary Escape opening both produced the same fully contained Mainhand rectangle. | No physical controller Back, menu wheel or combat acceptance. |
| Spellbook/minimap | PlayerSpellsFrame's Spellbook opened fully inside Mainhand. Minimap and cluster stayed shown with identical geometry through the settings/menu/book sequence. | This level-2 character did not exercise the reported talent pane or an affected saved minimap profile. |

The map observer recorded 58 events over 117.914 seconds, stopping on logout
rather than its event cap. Its drag-stop path wrote fitted scale 1.49509997;
subsequent configuration retained that value. AUTO sizing is enabled in the
saved profile. This does not demonstrate fixed-scale drag acceptance.

HUD snapshot 6 (saved) and snapshot 7 (reloaded) retain identical serialized
layouts. After reversal, ChatFrame1 and BuffFrame differ from their initial
measured rectangles by at most 0.000149 and 0.000199 physical pixels; PlayerFrame,
Minimap and WorldMapFrame match exactly. Native Edit Mode normalized three
equivalent anchor representations, so original/restored serialization is not
bit-identical. Action Bar 3 used symmetric native key nudges but was not included
in that frame-rectangle capture; no measured pixel-restoration claim is made
for it. Local cache restoration below is distinct from server-side persistence.

## New loot diagnostic

The newly supplied screenshot identifies Forever 70862 / Offhand beta.28,
combat=1, a LEFT 1920x1080 Mainhand beside a 1080x1920 portrait workspace, and
Companion writer 2.1.3 / paired 2.1.5 with status MATCH. It narrows OH-UI-031's
client/topology gap but does not identify the failing roll/item, input mode,
tooltip replacement or frame writer. OpenMap owns the world map; that alone
does not identify a tooltip owner. The local out-of-combat 1440-high test cannot
accept this shorter, combat-active configuration. Exact evidence is recorded in
[the report review](DISCORD-REPORT-REVIEW-20261109.md).

## Cleanup and follow-up

Closed each target client normally. Before restoration, copied final scoped
SavedVariables/config/cache files and compared BugGrabber: all four historical
message/time/counter/stack records remain unchanged, with no new captured error.
This does not establish combat or taint safety.

Restored all ten backed-up local files, including addon enable flags, Offhand
settings and native local caches, with SHA-256 verification. Restored the
original private observer source and disabled its TOC; the performance helper
also remains disabled. No vendor profiles were changed. Battle.net and
Companion remain open. The private candidate remains installed with backups.

Ignored evidence folder `dist/discord-qa-20261110-3/` contains the before/after
files, keyboard-map capture, HUD captures, panels-final.lua (18 snapshots),
bounded data readers, cleanup receipt and 96-file product verification. These
private files include account paths and are excluded from packages.

Still needed: actual multi-roll lifecycle, tall real item/comparison and combat
on the reporter's short Mainhand; installed ProcDoc; affected HUD/minimap
profiles; physical native/EUI dragging and controller input; physical
multi-monitor/T topology; user-opened mail/auction/flight sessions; and the GPU
comparison. No speculative runtime change was made for those unobserved paths.
