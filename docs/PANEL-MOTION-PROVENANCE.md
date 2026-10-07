# Panel Motion Provenance

Date: 2026-10-04

`Core/PanelMotion.lua` is an original Offhand implementation created for the
existing experimental Forever Professions workflow. Its requirements come from
Offhand's prior crash reports, mixed-monitor recovery behavior, existing saved
position model, and Blizzard's public `PanelDragBarTemplate` interface.

The implementation deliberately does not contain or depend on code, libraries,
frame registries, compatibility tables, APIs, identifiers, comments, or control
flow from third-party frame-movement addons. The external addon suggested during
research was used only to validate that this class of user need exists.

Design constraints:

- Blizzard Edit Mode retains exclusive ownership of protected HUD frames.
- The pilot applies only to the existing explicit Forever Professions opt-in.
- Blizzard's native template scripts perform the drag; Offhand observes start
  and completion only for its existing placement persistence.
- The grip is title-only and never enables mouse input over a panel body.
- Secure state visibility hides the grip in combat. If that guard cannot be
  established, attachment fails closed.
- No automatic Professions opening, Escape ownership, or reload-open behavior
  is introduced.
- Bags retain their separate native-title implementation.

Any broader rollout requires live taint-log evidence and a separate frame-policy
review. Source-level similarity to third-party implementations must be reviewed
before release.
