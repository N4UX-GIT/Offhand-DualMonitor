# Mixed HDR/SDR brightness investigation

Date: 2026-10-27. Source reviewed: `2e5c008` on
`codex/professions-quest-ui`, including the current working tree.
Status: source and vendor-documentation investigation only. No HDR reproduction
or packaged-build validation has been performed. No runtime changes proposed yet.

## Report

CurseForge report supplied by the maintainer:

> Any plans to make this add-on work with HDR ? currently if your second monitor is not a HDR monitor you have a super bright image.

Unknown: affected display/content, WoW client/build, Windows build, GPU/driver,
monitor models, addon/Companion versions, spanning method, and HDR mechanism.
Do not assume that Windows HDR being enabled means WoW has native HDR output.

## Source findings

- `Companion/Source/Program.cs`, `InvokeSpan` around lines 2830-2975, modifies
  WoW's window style, clipping region, and position/size. Both displays remain
  parts of the same WoW window. It does not capture and redisplay the workspace.
- The source's resize handshake explicitly leaves renderer resources to WoW.
  Current source and the released Beta 20 executable differ here, as already
  recorded in `docs/ISSUES.md`. Do not attribute this report to that experiment
  or rebuild the frozen Companion on the addon branch.
- `Core/Viewport.lua`, `Viewport:Apply` around line 884, anchors `WorldFrame`
  inside the game rectangle. This is a viewport/layout operation, not a separate
  display output or color pipeline.
- A search of `Core`, `UI`, and `Companion/Source` found no HDR, tone-mapping,
  color-space, gamma-ramp, or brightness control implementation. Companion's
  `MonitorSelection.Display` and `ReadDisplays` describe identity and geometry,
  with no active HDR state.

## Working hypothesis

A color/presentation mismatch when a single window straddles HDR and SDR outputs
is plausible. It is not yet the established cause of this user's symptoms.

Microsoft documents clipping of Advanced Color content on SDR output, including
windows straddling displays with different capabilities. Its display-capability
APIs report the display containing the window center, which need not match
Offhand's chosen Mainhand. Brightness or highlight clipping could therefore
depend on the actual rendering/conversion path and window geometry. This does
not prove which path the reporter uses.
[Microsoft Advanced Color documentation](https://learn.microsoft.com/en-us/windows/win32/direct3darticles/high-dynamic-range).

Windows Auto HDR and NVIDIA RTX HDR must be distinguished. NVIDIA supports mixed
HDR/SDR extended desktops subject to launch-display conditions; its FAQ does not
establish correct rendering for one game window spanning both types of display.
[NVIDIA App FAQ](https://nvidia.custhelp.com/app/answers/detail/a_id/5521).

## Controlled reproduction

Record the unknowns above, Windows primary display, physical layout/resolutions,
which display is Mainhand, and whether only WoW or also unrelated desktop apps
are too bright. Record whether whites clip or the entire image simply brightens.
Retain `/offhand diag`; it measures geometry, not HDR correctness.

Keep scene, UI panels, monitor brightness, graphics API, and window bounds
consistent. Change one variable at a time and restart WoW for HDR-path changes.
Restore each setting after its comparison.

1. Compare restored single-monitor WoW with the ordinary Offhand span using the
   reporter's current HDR settings. Note separately how each display looks.
2. Preserve the span, disable Offhand through the addon list, and reload. Verify
   native bounds stayed the same. Persistence would show Lua layout is not
   required for the symptom; disappearance would justify inspecting its UI path.
3. Keep Windows HDR enabled on the HDR monitor and disable the active game HDR
   conversion mechanism. Test Auto HDR and RTX HDR separately if applicable,
   without enabling both together. If this resolves the symptom, investigate
   that conversion path before proposing an addon correction.
4. Compare the same span with Windows HDR disabled, making both outputs SDR.
   A pass only here strengthens a mixed-output hypothesis, but is not a fix.
5. If needed, compare a manual span with equivalent bounds, styles, and clipping
   to isolate Companion setup. Optionally compare which output contains the
   window center, keeping that geometry change explicitly recorded.

Microsoft provides a per-game **Don't use Auto HDR** option under Windows 11
Display > Graphics > the game's Options, followed by a game restart. Labels
can vary by Windows build.
[Microsoft instructions](https://support.microsoft.com/en-us/windows/hardware/display-graphics/optimizations-for-windowed-games-in-windows-11).

Use a photograph of both screens as supporting evidence if possible. An ordinary
SDR screenshot can lose or transform HDR luminance information and cannot alone
establish what the physical displays showed.

## Engineering decision

There is no identified one-line Lua HDR correction. A dark overlay or theme
brightness slider would not implement proper per-output tone mapping and could
dim content without recovering clipped detail. Do not advertise that as HDR
support.

If reproduced, a suitable Companion follow-up is read-only detection/logging of
each selected output's active HDR state and a specific mixed-output diagnostic.
Keep detection capability-based and preserve portable, Store, and Wine fallback
behavior. Detection would aid support, not correct WoW's pixels. Full independent
color handling needs renderer/conversion-path support or a separately evaluated
presentation architecture.

No game launch, display-setting changes, binary rebuild, or posting to
CurseForge was performed during this investigation. Existing unrelated edits
were preserved. Documentation-only change; runtime tests were not run.

## Suggested reporter reply

Thanks for reporting this. Offhand spans one WoW window across both monitors,
and mixed HDR/SDR output may be causing the brightness mismatch. We are
investigating, but do not have a confirmed fix yet. Which WoW version, Windows
version, GPU, and monitor models are you using? Is Auto HDR or NVIDIA RTX HDR
enabled, and is only the second screen too bright? Please compare with that
game HDR feature disabled while leaving Windows HDR on, restart WoW, and let
us know whether the brightness returns to normal.
