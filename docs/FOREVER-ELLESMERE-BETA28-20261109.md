# Forever EllesmereUI follow-up for Beta 28

The user screenshots show the Step 6 progress label wrapping past its cell,
gameplay frames in the workspace after native HUD creation, and preview rows
skipping player, target and focus because they have linked cast bars.
The installed EllesmereUI is 9.8.2. The current local Forever QA build is
1.60.1.70862. The active display bridge describes a 2560 by 1440 canvas split
into two 1280 by 1440 regions.

The saved EllesmereUI links attach playerCastbar to player, targetCastbar to
target, and focusCastbar to focus. The earlier transfer rejected any anchor
target, including these roots. Its Fit mode also preserved gameplay frames
anywhere on either display. Only the first action bar was mapped.

The progress tab now uses the product name and measures text with its prior
height cleared. Fit HUD to Mainhand proposes supported gameplay placements
inside Mainhand. Linked parent groups retain their relationships, and their
combined bounds must fit. Enabled descendants without usable geometry still
block that group. Disabled cast bars without geometry do not block the parent.
Mapped children follow the root in the diagram and receive no independent
position write. Native numbered bar identities map to EllesmereUI Bar2 through
Bar8. Registered hidden bars are omitted. Native Gamepad skips keyboard bars.
The Blizzard fallback remains a separate native layout and displays anchor
points. Native HUD creation dismisses the old display-recovery prompt after
successful activation.

Creating the native layout prepares Blizzard's side of setup. EllesmereUI
positions are applied through its reviewed profile import and final reload.
The wizard guidance now makes those phases explicit.

Regression coverage includes root/cast-bar groups, oversized groups, disabled
children, mapped followers, scale conversion, workspace-to-Mainhand placement,
native numbered-bar aliases, Gamepad exclusion, and wrapped progress labels.
All 114 root Lua suites and six TOC syntax/path/XML checks pass. The new UI
and imported placements require in-client checks in both input modes. Previous
live reload-button verification belongs to the earlier reload fix.

Player-facing guidance is translated in German, French, Italian and Spanish.
The other non-English dictionaries use English fallback for these new strings.
The EllesmereUI brand stays unchanged in every progress tab.

Retest by reloading the updated addon, opening the wizard, and proceeding to
Step 6 with the current character layout. Compare Fit and Copy. Confirm the
selected positions through EllesmereUI's Import Selected Addons, then finish
and follow the reload prompt. Check attached cast bars and enabled secondary
bars on Mainhand. Recheck Escape and workspace persistence after reload.
