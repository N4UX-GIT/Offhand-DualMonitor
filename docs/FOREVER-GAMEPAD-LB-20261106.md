# Forever controller B versus LB, 2026-11-06

The physical B then LB retest on Forever 1.60.1.70790 with Discord test.2
did not reproduce the panel closure. B released Bags focus. Map and Bags
stayed visible at the same dimensions during both presses and through the
last snapshot before the save reload. The original closure remains open.

## Report and current conclusion

The owner reports in the already-open local Forever client that B removes focus
from the selected frame while leaving workspace panels shown; LB closes all
workspace panels. This is owner-observed physical-input evidence. It supersedes
the earlier lack of a physical B observation, but does not by itself identify
LB's effective native action or certify the earlier reporter's hardware/layout.

Offhand currently implements contextual B focus release, not a general native
Gamepad panel lock. `Core/WorkspaceBehavior.lua:RefreshGamepadWorkspaceBack`
only overrides `GAMEPAD_FACE_RIGHT` (PAD2), and only while an eligible workspace
panel has native focus. The override dispatches the hardware input directly to
`TOGGLEUIFOCUS`. It clears when focus leaves the eligible panel. It does not
override LB, Escape, targeting modifiers, or the native menu.
`Behavior:IsLockSupported()` deliberately excludes Forever. Consequently the
observed B success does not imply LB persistence is implemented or accepted.

## Evidence boundary

- Source root: `D:/Tools/Code/Offhand`, existing combined Discord test.2 work.
- The visible user-opened process is the release `_forever_/Wow.exe`, with the
  level 1 Shaman in native Gamepad UI. Store Companion is also already open.
  The previous smoke established 1.60.1.70790, but this follow-up has not yet
  independently read the running build or effective binding state.
- Shared knowledge README/skill/status and a Forever 1.60.1.70790 query were
  consulted. Retrieval returned authored protected-UI guidance, not an exact
  LB runtime contract. `GamePadEmulateEsc` lookup is unknown, not absent.
- Pinned upstream revision `ca8368f2f2380cbe696854f7f2646387c278a61b`
  represents the earlier 70532 source, supporting evidence rather than an exact
  70790 runtime reproduction. Selected files were read directly, not executed.
- [Native focus toggle](https://github.com/Gethe/wow-ui-source/blob/ca8368f2f2380cbe696854f7f2646387c278a61b/Interface/AddOns/Blizzard_Gamepad/Bindings.xml#L6)
  delegates to the native focus manager.
- [HideActiveFrames](https://github.com/Gethe/wow-ui-source/blob/ca8368f2f2380cbe696854f7f2646387c278a61b/Interface/AddOns/Blizzard_GamepadSharedUtility/FrameControlsManager.lua#L576)
  hides the tracked non-popup panels through HideUIPanel. Releasing focus does
  not remove panels from that manager's shown-frame list.
- [HUD mode OnShow](https://github.com/Gethe/wow-ui-source/blob/ca8368f2f2380cbe696854f7f2646387c278a61b/Interface/AddOns/Blizzard_Gamepad/UI/HUDMode/GamepadHudMode.lua#L84)
  calls that close-all routine. This is one concrete closure path, not evidence
  that this user's LB entered HUD mode. LB must not be assumed to equal Escape.
- The existing `tests/gamepad-workspace-back.lua` specifically enforces native
  Escape/menu ownership and PAD2-only contextual overriding. A successful
  keyboard Escape smoke does not establish LB behavior.

UI automation detected concurrent owner input before the first command could
be relied upon. No slash command or physical-button test was recorded from that
attempt. Game input was paused and an idle handoff requested. No new binding,
CVar, native handler, module or installed package was changed. The user-opened
game and Store Companion remain available for the requested comparison.
After the optional handoff interval, a fresh read-only capture showed another
foreground application covering the game. No diagnostic input was then issued;
effective LB binding inspection remains pending. That capture is not treated
as evidence about WoW panel state or input bindings.

## Next diagnostic and repair boundary

### Live baseline after idle handoff

The owner subsequently confirmed the game was idle and authorized continuation.
The existing `/offhand diag full` command ran successfully. A temporary local
observer was installed only in the live addon and six installed manifests;
original bytes are preserved under `dist/forever-gamepad-lb-20261106/live/`.
No canonical runtime source or archive was changed.

Observed baseline: build 70790, input mode 1, spanned true. Map and combined
bags were opened through their normal keyboard bindings. Native focus follows
WorldMapFrame then ContainerFrameCombinedBags; contextual Back reports `focus`.
The native core binding context (9) resolves PADLSHOULDER to
`GAMEPADLEFTTARGETMODIFIER`. With bags focused, the effective action is a native
InputFunctionBindingButton click and the private binding set is
CombinedBagsFrameNavigation. LB is therefore not established as Escape.
`GamePadEmulateEsc` returned no readable value, which remains an unavailable
query rather than proof of disabled emulation.

The first observer version mishandled an unavailable return value while
formatting its overlay, producing one new diagnostic-only BugGrabber record
at LiveLBQA.lua:54 (1069 occurrences before correction). This was agent-authored
temporary instrumentation, not a candidate addon regression. The observer was
corrected to normalize nil and stop after any unexpected error. Historical
product-error records remain distinguishable. The realm announced a scheduled
shutdown before the first physical comparison was captured.

The owner completed the requested input sequence after restarting the client.
The recovered SavedVariables end at the earlier setup, with Map and Bags open
and Bags focused. The observer had been removed from the installed manifests
before the restart, so the new session lacked capture. The recovered logs are
preserved under `dist/forever-gamepad-lb-20261106/live/`. The observer was then
installed through the capture reload, which saved the second physical run.

### Physical retest and cleanup

- The game was spanned in native Gamepad mode with workspace persistence enabled.
  After opening Map and Bags through the radial menu, the native focus manager
  reported Bags focused and Offhand reported `back:focus`.
- The B press at 1452107.051 released focus. The LB press at 1452113.941 kept
  focus released. Both panels stayed visible through button release and the
  final snapshot at 1452124.024. The map stayed about 1035 by 534 at scale 1.
- The core LB binding was the left targeting modifier. The snapshot after B
  showed the bag navigation click was no longer effective. The retest did not
  exercise LB while a panel had focus or establish the original closure path.
- The saved trace contains no new blocked action or product Lua error. The
  test client was closed normally. All six manifests match their original bytes.
  The temporary module, captured fields and observer error were removed from
  the installation and its backups. The three preexisting BugGrabber records
  compare equal, with only the session number advancing.

The saved trace is `dist/forever-gamepad-lb-20261106/live/char-physical-retry.lua`.

Do not globally remap LB, suppress a warning, reopen panels from an OnHide loop,
replace native focus handlers, or register an addon callback in the shared
Escape dispatcher to manufacture persistence. LB may own targeting or another
native mode that must continue to work. If closure is intentional native policy,
record the product limitation and design a bounded opt-in behavior only after
its actual action and protected-input boundaries are established.

Raw supporting source is retained under the ignored
`dist/forever-gamepad-lb-20261106/`, outside addon packages.
