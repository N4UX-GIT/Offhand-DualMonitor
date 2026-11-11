# Tiny fonts after removing Offhand

## Report and status

CurseForge screenshot supplied on 9 November 2026: a player reports tiny fonts
when opening chat and when a resurrection popup appears after uninstalling
Offhand. Client family/build, addon version, other UI addons, topology and exact
removal/restart sequence are unknown. The comment is symptom evidence only.
It does not establish permanent font changes or their cause.

**Resolved in the candidate, pending post-release verification.** The installed
2.1.5 beta.30 candidate passed a cold restart with Offhand disabled on Forever
1.60.1.70888. The cause of the original report remains unconfirmed.

## Source findings

- Current `Core/Viewport.lua` applies temporary `UIParent:SetScale` while spanned.
  It deliberately does not write `uiScale` or `useUiScale` during normal layout.
- `Core/Init.lua`'s logout handler resets WorldFrame and restores saved CVars,
  but previously did not restore the current session's `Viewport.originalScale`.
  A production-handler regression demonstrates that the temporary root scale
  remained applied at logout. This is a cleanup defect, not proof that native
  clients persist the root scale or that this causes the reported font symptoms.
- Historical commit `9b9babc0061f6c8dfd53e01eaa17583ff676a003` wrote UI-scale
  CVars. `a379aed7234ad99c04841eadba361b706813dd57` removed those normal-layout
  writes. The reporter's version is unknown; historical behavior is only a lead.
- Current Offhand does not resize global GameFont font objects or write
  `userFontScale`. Its explicit font changes concern chat bubbles, map coordinate
  rendering, addon-owned text and docked secondary chat message windows.
  `FCF_SetChatWindowFontSize` can save chat-message size, but that alone does not
  explain both chat input and resurrection-dialog text.
- The shared knowledge query returned gaps for this lifecycle/font interaction.
  The pinned corpus is review-due and does not contain the needed UI definitions.
  Upstream was inspected separately at Forever 1.60.1.70862, revision
  `9dc84f0d3bbae1768ac3405b3716000bd93eda06`. This client is an evidence scope,
  not an assumption about the reporter's client.

Upstream source references:

- [TextSizeManager](https://github.com/Gethe/wow-ui-source/blob/9dc84f0d3bbae1768ac3405b3716000bd93eda06/Interface/AddOns/Blizzard_AccessibilityTemplates/TextSizeManager.lua):
  separate `userFontScale`/`userFontScaleGlue` controls and user-scalable fonts.
- [Graphics settings](https://github.com/Gethe/wow-ui-source/blob/9dc84f0d3bbae1768ac3405b3716000bd93eda06/Interface/AddOns/Blizzard_SettingsDefinitions_Shared/Graphics.lua):
  the UI Scale controls access `useUiScale` and `uiscale`.
- [Dialog templates](https://github.com/Gethe/wow-ui-source/blob/9dc84f0d3bbae1768ac3405b3716000bd93eda06/Interface/AddOns/Blizzard_StaticPopup_Game/GameDialog.xml):
  popup text uses user-scaled font templates.
- [Chat font setter](https://github.com/Gethe/wow-ui-source/blob/9dc84f0d3bbae1768ac3405b3716000bd93eda06/Interface/AddOns/Blizzard_ChatFrameBase/Mainline/FloatingChatFrame.lua):
  `FCF_SetChatWindowFontSize` updates message fonts and calls `SetChatWindowSize`.

These are UI-source observations. Native persistence, font raster caching and
taint/combat behavior remain unverified.

## Candidate change and verification

`Viewport:PrepareForLogout` now prevents global scale reapplication during
teardown and restores the session's original root scale outside combat, only
while the current root still matches Offhand's last applied scale. It leaves
another owner's changed scale alone. Saved enablement and UI/font CVars are
unchanged. The existing legacy-CVar and viewport cleanup continues to run.
Combat logout skips the protected root write; a native reload builds a fresh UI.

`tests/logout-ui-scale.lua` runs the real Init logout handler and Viewport scaler.
It failed before the change with the root left at 0.35 instead of 0.8. It now
passes restoration, repeated cleanup, late callback, external-owner and combat
guards. All 117 Lua suites pass. Six TOCs, 79 runtime Lua files and XML/path
validation pass using Lua 5.1's compiler. These are source-tree checks only.

## Live test on 11 November 2026

Used the WoW test harness diagnostics and Computer Use on the existing Forever
1.60.1.70888 installation, Offhand 2.1.5 beta.30, and Companion 2.1.6. The same
level 2 Shaman in Durotar used the existing gamepad UI and addon set, including
EllesmereUIChat. The 2114×1353 window was spanned to a 4000×2560 canvas with a
2560×1440 Mainhand and a 1440×2560 workspace. The installed Viewport SHA-256 was
`D407F34989AF280DEC714CF7D80576015C1D63817CAA3683F425499C97E559B0`.

| Stage | Offhand loaded | UIParent effective scale | Chat input font height | StaticPopup1 text font height |
| --- | --- | ---: | ---: | ---: |
| Normal window before span | Yes | 0.64 | 18 | 12 |
| Mixed-height span | Yes | 0.39375 | 18.00038 | 12.00025 |
| New process at normal window size | No | 0.64 | 18 | 12 |

The local readout used `UIParent:GetEffectiveScale()`, `GetCVar`,
`C_AddOns.IsAddOnLoaded`, `ChatFrame1EditBox:GetFont()` and
`StaticPopup1.Text:GetFont()`. `uiScale=1`, `useUiScale=0`, and
`userFontScale=1` matched across all three readings. The spanned run exited
normally through `/quit` with Offhand still loaded. The in-game attempt to
disable it did not persist, so with the first process closed the test changed
only Offhand's entry in the test character's `AddOns.txt`. Battle.net started a
new process and WoW confirmed `IsAddOnLoaded("Offhand")` returned `false`.
The chat input and native exit confirmation looked normal after restart.

The synthetic popup sample triggered a controller UI warning. BugGrabber
recorded a `SetPreferredGamepadInteractTarget()` restriction during the first
session and no new entry during the disabled restart. The native exit dialog
was used for the visual comparison. A real resurrection, combat, and the exact
root scale during `PLAYER_LOGOUT` remain unmeasured. The restart establishes
the visible outcome on this build and setup.

Both WoW processes exited normally. The test character's addon list was
restored byte-for-byte, with Offhand enabled again. Battle.net and Companion
remain open. Private WoW captures are in `dist/font-restart-qa-20261111/`.

## Recovery and information to request

1. Exit WoW completely, return its window to the intended normal single-monitor
   size, and relaunch with Offhand disabled. If Companion is automatically
   spanning WoW, turn that option off for this check. Merely deleting the addon
   folder while WoW is running does not unload the active Lua session.
2. Search the game's settings for **UI Scale**. Review the player's intended
   value and Apply it. Where offered, also review **Text Scale**. Record values
   before changing them. Whole-interface scale and text scale are separate.
3. If only the chat message history is small, use the chat tab's **Font Size**
   menu. That is a different control from chat input and popup text.
4. Request client/build, last Offhand version, whether a full exit helped,
   whether the input or message history is affected, a screenshot, and the UI
   addons in use. If needed, collect these read-only chat commands with Offhand
   still disabled:

   ```text
   /dump GetBuildInfo()
   /run for _,n in ipairs({"uiScale","useUiScale","userFontScale"}) do print(n,GetCVar(n)) end
   ```

   `userFontScale` may be unavailable on older clients. No CVar is changed.

Do not ask the player to delete WTF, SavedVariables, chat settings or Edit Mode
layouts. A blanket CVar reset would discard unrelated preferences. An addon
cannot perform recovery after it has already been removed from the running UI.

## Suggested CurseForge reply

> Thanks for reporting this. Could you tell me which WoW version you're using
> and whether you mean the text you type into chat or the messages already in
> the chat window? Please first exit WoW completely and reopen it with Offhand
> disabled and the game window back at its normal size. If the text is still
> small, search Settings for UI Scale and, if available, Text Scale, then check
> those values. A screenshot and your last Offhand version would help me track
> this down. I've found a scale-cleanup gap and prepared a candidate change,
> but I haven't yet confirmed that it explains your report.

## Post-release verification

Ask the reporter to repeat the full restart with Offhand disabled after using a
release containing the fix. If the text is still small, reopen the report with
their WoW build, Offhand version, UI addons and a screenshot. Compare UI and
text scale settings before spanning and after restart, and check the actual
resurrection dialog if that is where the symptom occurs.
