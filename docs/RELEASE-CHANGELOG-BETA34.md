# Offhand 2.1.5 Beta 34

## Mainhand and native dialogs

- Use `/offhand centerline` while spanned to show the Mainhand center and
  quarter marks. Run it again to hide them. The marks follow Mainhand when the
  viewport changes and mouse input passes through them.
- On Forever, newly generated native XP and reputation bars center across
  Mainhand when Action Bar 1 is attached to the Micro Menu. They remain attached
  above Action Bar 1 as the menu and action bar are fitted. A rebuild can also
  center a matching overlapping Beta 32 XP anchor and a matching reputation
  anchor. Custom status anchors keep their saved placement.
- On Forever, if Cooldown Manager's **New Layout** or **Import Layout** dialog
  would open off-screen or in a gap between monitors, Offhand recovers it onto
  Mainhand outside combat. This works from Cooldown Settings with Edit Mode
  closed. Reachable dialogs keep their positions.

## EllesmereUI setup

- Export a backup of the active EllesmereUI profile before spanning.
- Preview the Offhand HUD profile during setup. The import asks for a unique
  profile name through EllesmereUI, so the existing profile remains available.
  You can also finish with the current profile.
- If specialization assignments leave the new profile inactive, the wizard
  explains what happened. Follow the reload prompt when the imported profile is
  active and a reload is needed.

## Workspace C preview

- The paired portable **Companion 2.1.9-beta.1** adds Workspace C in the custom
  layout editor. A plan can use Mainhand plus three workspaces on up to four
  physical displays. Use **Identify Displays** and check the preview before
  saving. The Companion checks the addon's workspace capability before spanning
  a three-workspace plan.
- The addon reads the expanded layout formats and exposes Workspace C in its
  per-workspace options. Existing one- and two-workspace plans still load.
  Removing a workspace keeps its saved panel positions and sends its panels
  to the default workspace.
- The portable beta also carries forward Companion 2.1.8 changes. Workspace
  Profiles explains when the current layout cannot save a profile. Display
  diagnostics identify a display with a missing stable identity and retain the
  most recent span bounds failure with the requested bounds, observed bounds
  and rollback result.

## Installation and upgrades

- **Addon ZIP.** Install through your addon manager or place its `Offhand`
  folder in your WoW client's `Interface/AddOns` folder. Your existing
  compatible Companion and manual setup remain supported.
- **Complete Windows ZIP.** Includes the same addon and portable Companion
  2.1.9-beta.1 for Workspace C testing. Extract the ZIP and follow
  `README-FIRST.txt`. The standalone Companion ZIP contains the same executable.
- The current Microsoft Store release is **Companion 2.1.8**. The in-game
  `/offhand whatsnew` notice lists it separately from the paired portable beta.
  [Microsoft Store listing](https://apps.microsoft.com/detail/9PL4PW84Q90W)
- On Forever, leave combat and close Edit Mode before using **Offhand Settings
  → Recovery & Preview → Create Mainhand HUD Layout**. Reload when prompted.
  Offhand keeps the source layout available. Existing manually placed bars can
  be adjusted through Blizzard Edit Mode.

## Verification

The contributor build was exercised in live Forever with simulated workspace
rectangles and a separate two-monitor span and restore. Four physical
displays, mixed-DPI/HDR spans, and the assembled Beta 34 build on live Retail
and Forever remain to be verified. Native popup and Trade recovery during
combat is still under investigation.
