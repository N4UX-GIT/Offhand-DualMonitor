# In-game release notes

The addon checks for an unseen release on its first world entry after login.
Dismissal records the full addon version in account SavedVariables, so reloads
and character swaps do not repeat the notice. Downgrades preserve a newer
acknowledgement. A saved setup handoff takes priority on that login; the notice
remains unread. The player can always reopen it with `/offhand whatsnew`.

Before packaging an addon release:

1. Add the exact manifest version, including any beta suffix, to the release
   table in [UI/WhatsNew.lua](../UI/WhatsNew.lua). Add two or three highlights to
   each locale. Link to the full notes on the matching GitHub release.
2. Set the entry's `companion` field only if this addon release is paired with a
   new Companion release. Leave it empty for addon-only updates.
3. Update `storeVersion` only after verifying public Microsoft Store
   availability. A paired release, portable ZIP, Store submission, or private
   flight is not evidence of public availability. If the Store is behind, keep
   its last confirmed version. For Beta 32 the public US and DE catalog records
   for product `9PL4PW84Q90W` listed the `2.1.700.0` package (Companion 2.1.7).
4. Run `lua tests/whats-new.lua` and the manifest and locale checks. The login
   regression requires highlights for the active TOC version. On a test
   installation, check a login with an older or missing Companion handoff,
   dismiss and reload, then open the notice again with the slash command. Check
   the copy field and placement on a narrow Mainhand, including Forever's
   Gamepad UI, and check an upgrade with an up-to-date handoff.

The dialog compares the published Store version with the Companion that last
wrote the display handoff. It labels that version as historical. With an older
or missing handoff it asks Store users to check for an update. Store availability
is packaged release information; WoW does not query the Store or inspect the
installed desktop app. The Store and release notes buttons provide copyable
addresses.
