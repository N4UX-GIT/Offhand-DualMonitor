# Offhand 2.1.5 Pre-Release Beta 33

## Mainhand HUD

- On Retail, rebuilding a saved Beta 32 Mainhand HUD moves the default Action Bars 2 and 3 clear of Action Bar 1 and its status bars. Manually placed bars keep their anchors.
- On Forever, rebuilding fixes an overlapping native XP bar when it still uses the Beta 32 default anchor. Custom XP and reputation placements are preserved.
- Both repairs recognize the anchor offsets Blizzard rounds when it saves Edit Mode layouts. You can rebuild the existing Offhand layout from Settings and reload when prompted.

## Setup and compatibility

- See release highlights on your first login after an update. Use `/offhand whatsnew` to reopen them or copy the Microsoft Store link for the Companion.
- Setup explains when to reload after an EllesmereUI layout import. Eligible EllesmereUI bags stay open when you open Talents on Forever.
- Keep the World Map in its saved location when using MoveAny on Forever. Escape protection returns when OpenMap registers the map again. Setup guidance explains Blizzard's map fade while moving.
- Fit narrow backpacks to the workspace and preserve Titan Panel bar anchors and Blizzard's queue status button.
- Load each workspace scaling module once per client manifest.

Beta 33 works with your existing compatible Companion. The layout upgrade, manual anchor preservation and reload persistence were verified on Retail 12.1.5.70783 and Forever 1.60.1.70888.
