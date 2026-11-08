# Kerzo Escape live QA, 7 November 2026

**Result: test8 passes the exercised keyboard Escape workflow. No runtime fix
was needed.** This does not establish combat, quest-item or controller safety.

## Runtime and package

- Forever 1.60.1.70862, selected in Battle.net; Windows, English UI.
  The full GetBuildInfo tuple/project ID was not collected by a script.
- Installed Offhand `2.1.2-beta.26-forever-discord.test8`: all 79 non-generated
  installed package files hash-match the test8 receipt before and after the run.
- Addon ZIP SHA256: `EA56E10D8DCB10FC74A3907D9B2EDAA3EFDF2DBF846358EA48257B43C263DD30`.
- Kerzo Classic Quest Log 6.1.4. EllesmereUI and ForeverPlus 1.0.6 coexist.
- Companion 2.1.3 Beta 6, existing candidate. Auto-span remains off.
- Existing level 1 Shaman in Durotar, idle. No movement, quests, combat,
  messages, item actions or custom `/run` scripts were performed.
- Run: 13:43-13:57 CET. Private before/after snapshots are ignored artifacts in
  `dist/kerzo-live-20261107/`; account and chat data are not included here.

The original display configuration is a 2560x1440 Mainhand and a 1440x2560
portrait workspace. Window capture only exposes primary-monitor pixels when
spanning both. For directly visible Escape tests, the Companion temporarily used
its single-display split on the primary: 1280x1440 workspace left, 1280x1440
Mainhand right, in a native 2560x1440 window. The generated topology confirmed
`SPLIT_ULTRAWIDE` and the addon rendered the two regions after `/reload`.
Physical two-display workspace Escape placement is not claimed from that run.

## Observed checks

| Action | Observed result |
| --- | --- |
| Cold load test8 and `/kql` outside a span, then Escape | Kerzo opens and native Escape closes it. |
| In the visible split, drag Kerzo by its own title fully onto the workspace | Kerzo moves normally and retains its own placement. |
| Press Escape twice with the workspace quest log open | Game Menu opens, then closes. Kerzo stays open both times. |
| `/kql config`, then Escape | Settings dismisses; the quest log stays open. |
| Settings, About, then Escape | Both vendor dialogs dismiss; the workspace quest log stays open. This records observed vendor behavior, not a claim that each dialog consumes a separate press. |
| Use Kerzo's X button, reopen with `/kql`, then use `/kql` again | Explicit close, manual reopen and explicit toggle close all work. No automatic resurrection occurs. |
| Drag Kerzo onto Mainhand, then Escape | Native Escape closes it. |
| Disable Offhand's panel Escape-persistence checkbox, open Kerzo on workspace, then Escape | Native Escape closes it. |
| Re-enable the original preference, reopen Kerzo, then Escape | Kerzo stays open and Game Menu opens. |
| `/reload`, manually reopen Kerzo and press Escape | Vendor-saved workspace placement remains; Escape protection remains. Kerzo does not automatically reopen on this reload, consistent with vendor ownership. |
| Companion Restore while Kerzo is open, retain the current HUD, then Escape | The native window restores and Escape closes Kerzo. |

No user HUD layout was rebuilt. Setup/recovery prompts used Later or Keep
Current Layout. The original two-display configuration was reapplied and the
window restored before closing the QA game and Companion. Battle.net and
unrelated applications remain open.

## Logs, cleanup and remaining coverage

BugGrabber has the same three existing messages and unchanged occurrence
counters before and after the run. No new error or blocked-action dialog was
observed. The existing `taint.log` was last written on 22 October and did not
provide fresh evidence for this run; these checks do not prove taint safety.

Eight Offhand/Kerzo SavedVariables and backup files were captured after testing,
then restored byte-for-byte to the pre-run versions. Both generated bridge files
were restored from the verified pre-test8 installation backup. Companion settings
returned byte-for-byte to their initial contents through the UI. Private fresh
error records were retained. Runtime source and both test8 ZIPs are unchanged.

Remaining manual coverage: quest-item/protected descendant actions, combat-time
modal transitions and deferred updates, physical-controller/native Gamepad
behavior, another character, and the reporter's physical multi-monitor layout.
The earlier 94-suite and six-manifest automated acceptance applies to the same
runtime bytes; no source change or replacement package was required here.
