# Classic graphics recovery test 3

Isolated portable candidate for Classic Era and Anniversary. Retail and Forever
are excluded. Window title must say CLASSIC TEST 3. Exit the Store Companion or
previous candidate before running it. This does not install a Store update.

## Behavior

- A manual Span WoW Now establishes the window and display ownership. The window,
  client area, borderless style and clipping must remain correct across observations
  at least two seconds apart before recovery is armed.
- The captured graphics-reset signature permits a recovery only with the same HWND,
  confirmed display plan, saved pre-span dimensions, stale region and frame styles.
  Ordinary manual window changes are not a recovery trigger.
- After successful immediate native verification, recovery waits for at least four
  seconds of continuously observed healthy geometry and a ten-second cooldown.
  It then re-arms automatically without another manual Span click.
- If healthy post-recovery verification cannot finish within twenty seconds,
  recovery stops instead of repeatedly forcing the window. Native recovery failure
  also stops automatic attempts immediately.
- At most three attempts are allowed in a rolling five-minute window. A fourth
  eligible reset pauses recovery with an activity-log and tray notice. It stays
  paused until a deliberate manual Span WoW Now establishes a new baseline.
- Restore Window and Pause Monitor cancel recovery, including during cooldown.
  Resume Monitor never revives a cancelled arm. New manual spanning is required.
- Changed displays/roles, recreated windows or unreadable/unrecognized settled
  geometry cancel ownership. Hung/minimized/maximized windows are not resized.
- The experimental one-pixel resize handshake stays disabled for this candidate.
- Recovery is default monitoring behavior, with no separate checkbox. Launch
  auto-span is disabled in this test build. Public monitor selections are read
  initially; test changes go only to ClassicTestConfig.ini beside the candidate.
- Activity is written to classic-recovery.log beside the executable. Public INI
  and Store binary remain unchanged. Successful spans use the standard Beta 20
  topology bridge with the same confirmed displays.

## Repeated-reset test on Anniversary

1. Exit WoW normally and Exit the previous Companion through its tray menu.
2. Run Test 3. Launch Anniversary in ordinary Windowed mode with VSync Enabled.
3. Start the native observer, click Span WoW Now and wait for Classic span verified
   stable. Check both screens before continuing. Do not test VSync if initial span
   is wrong or the stable message is absent.
4. Enter /ohcapture start. In Graphics Options, disable VSync. Wait for automatic
   restoration, then wait for the explicit Classic recovery re-armed log message.
5. Without clicking Span WoW Now, change VSync through Graphics Options again.
   If the window resets, expect a second recovery and another re-armed message.
   A stable toggle without a window reset is not proof of a second recovery.
6. Stop the probe and native capture, take the result screenshot, then exit WoW
   normally to flush the addon log. Retain both captures and classic-recovery.log.
   The probe/native observer stop after three minutes; begin a fresh capture if
   setup consumed that period. Keep each test within the attempt budget.

## User-control acceptance

- Restore Window and wait ten seconds: WoW must stay restored.
- Re-span and wait for stable arming, then Pause Monitor. Make a GUI graphics
  change that resets the span. Wait ten seconds: no recovery. Resume Monitor and
  wait ten seconds: still no unsolicited recovery. Manual Span restores/re-arms.
- Restore Window and Pause Monitor must also cancel during the ten-second
  post-recovery cooldown. Do not deliberately trigger repeated hangs or disconnect
  displays for this first test. Existing disconnect recovery remains separate.
- If recovery fails or oscillates, Pause Monitor, Restore Window, and retain logs.
  Do not reset addon settings or recalibrate to hide the failure.

## Rollback

Exit Test 3 through its tray menu and reopen the unchanged Store Companion, or the
previous Test 2 for comparison. Test files remain in their own folder. No automatic
startup registration, process-memory access, renderer hooks or gameplay input is
added. Ordinary Windows geometry operations perform recovery.

## Evidence status

Test 2 previously passed one automatic Anniversary recovery, Restore Window,
pause/resume cancellation and manual re-arm on build 70006 and the offset portrait
setup. Test 3's repeated-recovery and cooldown behavior has automated regression
coverage but remains live pending. Era, Retail, other topologies and the original
Midnight hang are not verified by this test. This is an unpublished candidate.


## Recorded Test 3 live acceptance, 24 October 2026

On the tested Anniversary build 70006 and offset portrait arrangement, Companion
logs confirm two automatic recoveries without a manual span between them, followed
by two stability/cooldown re-arm cycles. The user confirmed intact game/workspace
presentation and the subsequent Restore Window, cooldown Pause Monitor, resume
without unsolicited recovery, and manual re-span controls.

Those targeted checks are live accepted for this configuration. Rate-limit
exhaustion and failure/deadline cases remain automated-only. The latest external Windows capture initially showed zero file-list length while
open. Direct reading later confirmed valid records independently corroborating
both Test 3 recoveries; the earlier empty-file conclusion was incorrect. Retail, Era and the original
Midnight hang remain separate untested/unresolved items. Candidate is unpublished.
