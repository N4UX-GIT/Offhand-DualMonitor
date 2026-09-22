# Offhand Companion v2.1.2

This is a Companion-only safety update. The public CurseForge addon remains
v2.0.0 for Retail and Classic clients while the v2.1.2 addon candidate completes
client-by-client validation.

## Improvements

- Uses stable Windows display identities and exact Mainhand/workspace rectangles.
- Refuses to collapse a saved two-display span when a selected display is missing.
- Restores WoW to the selected or surviving Mainhand after a disconnect.
- Refreshes display selectors during hotplug without discarding saved choices.
- Supports an explicit equal-half split for one 32:9/32:10 display.
- Disables automatic spanning by default for new installations.
- Makes update checks user-initiated and includes complete build source.
- Adds Forever cold-start SavedVariables recovery and safe generated-file updates.

The Companion improves window and topology safety for existing addon users, but
it cannot replace addon-side fixes. Retail and Classic v2.0.0 users should still
install the next addon update when it becomes available.

## Downloads

- `Offhand.exe` — standalone Companion.
- `Offhand-Companion.zip` — executable, exact source, build script, license and
  security documentation.
- `checksums-sha256.txt` — SHA-256 values for both downloads.

Verified standalone SHA-256:

`9FB8FA71CD76F71ABCB3BE73A69556630FCAE90153CBA10F95B5F7030BA2580A`

The Companion is unsigned. Download it only from this official repository and
verify the checksum before running it.
