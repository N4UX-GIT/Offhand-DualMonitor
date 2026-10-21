# Offhand website demonstration

Open `demonstration.html` through the website's local server. The page uses the
shared `style.css` navigation, typography, content deck, buttons, and footer,
with player-specific styles in `demonstration.css`. It is linked from the
homepage's “Watch Offhand in action” button and page menu. It remains an
illustrated explanation rather than recorded gameplay or installation footage.

The approved visual reference is `assets/offhand-demonstration-concept.png`.
The animation itself uses SVG and JavaScript, without generated game imagery,
external animation libraries or video dependencies. Shared website typography
loads the same web fonts as the other pages. The desk is an
illustrated representation rather than a photorealistic 3D scene.

## Review controls

- Select an arrangement to inspect it. Selecting pauses the tour.
- Play Tour keeps the full demonstration, with no shortened cut. It opens with
  a directed sequence: about 16.4 seconds on the close-up single
  screen, 11.8 seconds on conventional spanning, and 11.3 seconds on the Offhand
  reveal. The remaining layouts use about 4.1 seconds each.
- Replay Intro restarts the opening from the close-up, including UI activity.
- A global 1.1 playback rate makes the whole tour 10% faster, including UI actions,
  captions, transitions, ending, and equipped pulse. The intro retains its slower
  relative pacing (a .5 base rate, now effectively .55). The camera pulls back
  over about 3.5 seconds to show the conventional span. The Offhand reveal takes
  about 7.6 seconds: separate the game and map first, then grow the workspace
  into a portrait display. Most other transitions take 1 second.
- Expand Demo hides the page and centres the scene. Move to the bottom
  centre or focus the controls to reveal them. Escape or Exit Expanded View
  restores the website layout.
- `demonstration.html?present=1` opens directly in expanded view.
- Reduced-motion preference disables arrangement tweening. Playback starts only
  when requested. Background tabs pause animation work.
- Equip your Offhand. previews the closing sequence directly. The ending takes
  about 9.3 seconds and holds on the finished card instead of looping. Replay Tour starts
  from the intro again. The Get Started link opens `in-game-setup.html`.

## Current sequence

1. Before Offhand: close on one screen. A simulated cursor opens the map, closes
   it to see the world, opens Character and Bags, and returns to the map. Short
   captions explain the interruption. Pause freezes the simulated UI activity.
2. Before Offhand: a conventional span with one game canvas sampled across two
   physical screens. Pull back to reveal the hardware. Highlight the centre of
   play on the bezel, then open a map across the seam. The player frame and
   minimap sit at opposite outer edges.
3. With Offhand: separate the existing game canvas into workspace and Mainhand,
   then grow the workspace into the approved portrait-left arrangement.
   The game viewport and HUD contract onto Mainhand, the original centred map
   travels onto Offhand, and the remaining workspace panels appear in place.
   Selecting Conventional Span again reverses the same animation. Reduced-motion
   users get the settled layout immediately.
4. Two landscape displays with separate workspace and Mainhand roles.
5. Landscape Mainhand left, portrait workspace right.
6. Mainhand above the workspace.
7. Mainhand below the workspace.
8. A 32:9 ultrawide with a logical workspace/game split.
9. Three monitors: a portrait workspace and landscape Mainhand, with the third
   screen outside the WoW span for desktop apps.
10. Four monitors: a landscape workspace and Mainhand, with two additional screens
   outside the WoW span.
11. Earlier arrangements use a simple Character silhouette with blank equipment
   blocks and a basic Bags grid. On entering the ending, reveal the detailed
   artwork in those same panel bounds. Return to the finished portrait-left setup.
   The camera follows a straight dolly toward
   the Character panel already on that monitor. The same vector character frame
   is used in the workspace and close-up, with a bevelled border, paper-doll
   silhouette, equipment columns, stats bars, tabs, and three bottom slots:
   Mainhand, Offhand in the centre, and Ranged. Show the Offhand icon in a bag
   slot among illustrated generic items with matching bevels and muted metal tones.
   Each equipment column has eight generic items informed by the character-frame
   reference: head, neck, shoulder, back, chest, shirt, tabard, and wrist on the
   left; hands, waist, legs, feet, two rings, and two trinkets on the right.
   The established three bottom slots remain. The bag settles, then the
   cursor approaches and briefly hovers. It clicks at about 5.6 seconds; the
   bag slot empties and the icon immediately appears in the centre equipment
   slot, followed by a short highlight. The equipped icon, drawn slot trim, and
   soft background glow pulse gently on a shared roughly 2.55-second cycle. Reduced-motion
   preference keeps the equipped artwork and glow steady.
   The bag, equipped item, page logo, and closing wordmark use the same supplied
   transparent artwork (`assets/offhand-logo-borderless.png`). Bag and equipment
   slots draw matching bevels around it instead of switching to a framed bitmap.
   The original bag panel transfers to the close-up layer at its exact projected
   position, leaving no duplicate behind. Its original coordinate system is
   retained, so the panel, slots, labels, and spacing zoom together with Character
   without compacting or reflowing. The surroundings fade fully to the closing backdrop.
   There is no dragged icon or travel path.
   Fade the bag into the wordmark, tagline, and setup link, then hold.
   `OffhandSheet1.png` informs the arrangement only; its pixels are not rendered.
   The close-up tracks the camera's projected frame position before fading its
   surroundings, rather than introducing a separate image.

The opening scenes illustrate common space and spanning problems, rather than
claiming that every single-screen layout is crowded or every spanning method
fails. The busy layout is a schematic example, not a claim about which native
panels can be opened simultaneously in every client.

The extra screens use blue-grey desktop diagrams rather than gold workspace
panels. Companion's topology planner in `Companion/Source/Program.cs` explicitly
rejects more than two selected displays. These examples demonstrate a supported
pair within a larger desktop, not a span across three or more displays.

Display transitions illustrate the arrangements; they do not imply that Offhand
can rotate physical hardware or configure the desktop automatically. Scene
coordinates are unrelated to actual WoW canvas geometry. Growing and reshaping
the illustrated workspace is a presentation effect, not automatic physical
monitor configuration.

## Next production work

Layout navigation starts collapsed behind the native “Explore layouts”
disclosure. Its open/closed preference is saved in browser local storage
when available. The scene title and description remain visible. The
homepage demo link uses a restrained gold border and play-icon accent,
leaving the filled Get Started button as the primary action.

The illustrated tour initially displays a static vector snapshot of the
finished portrait-left/Mainhand-right arrangement with a “Play the tour”
button. The snapshot reuses the existing scene with prefixed SVG IDs and
adds no promotional headline. Starting via the cover, playback control,
or Replay intro fades the cover away and begins the crowded-screen intro.
Selecting a layout dismisses the cover without forcing the intro.
Reduced-motion preference removes the cover fade. The initial description
is factual; scene-specific descriptions resume after dismissal.

### Local in-game footage example

The demonstration page includes a separate, click-to-play 30-second silent
example below the illustrated tour. Source: `2026-10-21 23-15-58.mkv`,
00:01 through 00:31 (1 to 31 seconds from the beginning).
Mainhand stays fixed in size throughout. It starts alone,
showing Character, Bags, then Map opening over the game. The entire Offhand
region, its drawn border, and Chat label fade in together from edit time
5.6 to 6.4 seconds, before the first panel crosses the seam. Both regions
then stay visible through the remaining real-time interactions.
The empty left area initially reads “One screen. Shared space.” and
“Your map, bags, and Character panel compete with the game for room.”
This copy fades away by 5.5 seconds, before Offhand appears.
At edit time 21 to 22.2 seconds, Mainhand moves down by 110 output pixels
with smoothstep easing. Its border moves with the footage. Text then
fades into the space above: “Your game on Mainhand.” and
“Your UI within reach on Offhand.” No footage is sped up or paused.
This replaces the earlier encoding-lag-affected recording. The new source
was captured at 2000 by 1280 at 60 fps, reducing encoder load while retaining
the complete two-screen canvas.
The original recording is unchanged and is not shipped with the website.
The exported H.264 MP4 is 1920 by 1080 at 60 fps, preserving the source cadence, with fast-start metadata
and no audio. Native video controls and `preload="none"` avoid autoplay
and unnecessary video downloads. A still from 24 seconds into the edit
serves as the poster.
The poster includes a separate HTML “Watch · 30 seconds” button, hidden
without JavaScript so native controls remain the fallback. It disappears
when playback starts, transfers keyboard focus to the video, and returns
as “Replay · 30 seconds” after the clip ends. Pausing uses native controls.

The portrait region is cropped from x=0, y=0, width=720, height=1280;
the Mainhand region from x=720, y=560, width=1280, height=720.
The full empty chat frame is retained, with a muted gold “Chat” label
overlaid in its interior. No part of the portrait region is masked.
Both regions retain their timing and are reframed side by side with thin
drawn monitor borders. The caption discloses the adjusted presentation
and added chat label; this is not an illustration of physical alignment.
Assets: `assets/offhand-in-game-demo.mp4` and
`assets/offhand-in-game-demo-poster.jpg`.

The homepage links to the integrated demonstration page. A final video
can use the same vector screen diagrams inside a rendered desk environment.
This prototype does not yet export a video or demonstrate installation steps.
