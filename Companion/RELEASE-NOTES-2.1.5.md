# Companion 2.1.5, unpublished candidate

- Store installations quietly check for Companion updates 30 seconds after startup, at most once daily, including while running in the tray.
- The Store Updates button and tray action show Update available when Microsoft reports an update. Click to open Microsoft Store and install when convenient.
- Checks have a timeout, cancel during shutdown and keep their own small local cache. Offline or unavailable Store services do not block Span/Restore or show a popup.
- Portable installations retain the manual GitHub check. UI previews and diagnostic builds skip automatic Store checks.
- Updated Help and privacy guidance describes the Store query and locally cached build, time and result.

The Companion does not download/install updates or restart itself. Existing Microsoft Store automatic-update settings continue to apply. The protocol-1 add-on remains compatible; this change does not require an add-on update.

This is prepared source, not a released update. Real Store-associated availability acceptance, WACK and release scans remain release gates. The submitted 2.1.4 package is unchanged.
