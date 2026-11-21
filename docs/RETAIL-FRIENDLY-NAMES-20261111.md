# Retail friendly-name preference correction

The owner requested inclusion of the previously deferred correction in the
pending Beta 30 package. Only its visibility-preference changes were imported
from the original development checkout; unrelated workspace sizing and support
diagnostics changes were excluded. The existing loot-roll correction is unchanged.

The report identifies Retail 12.1.5 build 70783, Interface 120105. Offhand's
previous ApplyGlobalScale forced UnitNameFriendlyPlayerName on whenever enabled,
including an unspanned window, then reapplied it after CVAR_UPDATE. This correction
removes that forced value, its callback and stale logout restoration.

Legacy cleanup restores a saved off preference once if the current value is
still the old forced-on value. Missing getters and failed writes retain the
marker for retry; malformed backups are discarded. An already-off value is
preserved, and later scaling and logout leave the player's preference alone.
A deliberate on choice before cleanup cannot be distinguished from the old
forced value; the one-time restore can turn it off, after which player changes
are no longer overridden. Nameplate sizing and nameplate visibility controls
remain separate from this name-text preference.

The production geometry regression covers spanned/unspanned state, changed
preferences, legacy cleanup and disable. The imported production migration/logout
fixture covers unavailable APIs, failed setters, malformed backups and newer
player choices. Its local source SHA256 is
`a92ea27cdd97600b5b0f8ef6aab3406ab0db4d40bf3df6d3f9a1a8bf9b07ac29`.

Shared knowledge status/search were consulted first. The full-text index is
stale; no absence or safety inference was drawn. The earlier local report review
and current production source are the implementation evidence. The prior upstream
study of Blizzard SettingsDefinitions Nameplates.lua at revision
`297d7aaaa736f346b3e036f38ee088eaf7f8c07f` distinguishes the friendly-name checkbox
from nameplate visibility. It is not exact-build native evidence.

Native Retail 70783 acceptance remains unrecorded. Inclusion is explicitly
authorized by the owner; automated evidence does not establish native combat,
taint or the reporter's exact checkbox behavior. No live client was changed
during this inclusion pass.
