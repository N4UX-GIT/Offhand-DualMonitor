# Guidance alignment and remaining captures

Source review: 1 November 2026. This checklist does not establish live acceptance.

## Implemented addon copy

The seven handbook topics and overview now use the same Companion-first window
placement sequence as the website. Expanded placement help uses Confirm placement,
not Next. Independent confirmation distinguishes Remember Window in the guide
from Remember Current Window in settings. Recovery starts with Recover Missing UI
and explains the larger effects of Gather Safe UI to Mainhand and HUD rebuild.
Edit Mode text accounts for supported clients and external HUD ownership.

All locale overrides for these revised keys use explicitly labelled English
fallback copy until translated. Existing unrelated translations remain intact.
Source checks: all 73 Lua suites and six-manifest Lua 5.1/XML/path checks pass.
Help-card wrapping/scrolling, translated text expansion and player comprehension
require live review. No installed client or SavedVariables was changed.

## Capture queue

Keep screenshots focused on the relevant dialog. Do not include desktop voids,
private chat, account data or unrelated windows. Reuse earlier captures only if
their wording matches the current candidate. Do not recreate every normal page.

| Priority | Capture | Required visible context |
| --- | --- | --- |
| 1 | Updated Help & recovery | Overview, placement and recovery cards, each at a readable size. Check every card for clipping before capturing. |
| 1 | Missing/mismatched Companion geometry | Paused calibration instructions and available actions. Capture the applicable state without changing saved display settings just for a screenshot. |
| 1 | Full Edit Mode layout list | Guided recovery card and native layout dropdown with the relevant export/delete controls. Use disposable test layouts, never delete a valued layout for a photo. |
| 1 | Recover Missing UI | Confirmation plus resulting feedback during a real recovery; visible UI should stay in place. |
| 1 | Broader recovery warnings | Gather Safe UI to Mainhand and HUD rebuild confirmations. Cancel when only capturing the warning. |
| 2 | Background Studio ready state | A valid installed media package, enabled controls and the resulting workspace background. Capture after the required full client restart. |
| 2 | Multiple profiles | A non-default active profile with the load/copy controls available. Preserve the normal profile. |
| 2 | PowerToys itself | Relevant FancyZones spanning options and one combined Canvas zone. Offhand's guide screenshots already exist. |

Record client/build, candidate source/package hash and UI scale with each set.
Protected HUD and recovery behavior need their existing live/taint checks; a photo
alone does not verify native actions, persistence or combat safety.

## Website

The Companion page must link to the refreshed in-game guide instead of retaining
its older six-step screenshot walkthrough. Keep one authoritative screenshot set.
Companion remains the recommended Windows route; alternatives remain accessible.

## Next Companion build, source follow-up only

Review Companion/Source/Program.cs GetHelpText and the distributed README together:

- Initial manual span should explicitly follow entering the game world and then
  Reload UI, Confirm placement and Start Calibration. Resolve client-specific
  Forever startup requirements against release-client evidence before rewriting
  automatic launch behavior. Do not change window behavior as a copy-only fix.
- Describe the current generated Offhand / Offhand - Gamepad layout names without
  implying that an older character-named layout must be deleted.
- Separate Restore Window, Pause Monitor, Exit and ongoing recovery ownership.
- Keep Store and portable update instructions distinct. Label experimental HDR,
  DPI and graphics-reset behavior according to the actual selected build.
- Link to the illustrated website rather than duplicating a second long guide.
- Capture the final dashboard, help, Identify Displays and recovery states after
  candidate UI acceptance. Do not market an experimental dashboard as Beta 20.

No Companion executable or native source was rebuilt or changed by this copy pass.
The public Companion remains Beta 20.
