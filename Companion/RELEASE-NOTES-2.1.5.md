# Companion 2.1.5, submitted to Microsoft Store

- Store installations quietly check for Companion updates 30 seconds after startup, at most once daily, including while running in the tray.
- The Store Updates button and tray action show Update available when Microsoft reports an update. Click to open Microsoft Store and install when convenient.
- Checks have a timeout, cancel during shutdown and keep their own small local cache. Offline or unavailable Store services do not block Span/Restore or show a popup.
- Portable installations retain the manual GitHub check. UI previews and diagnostic builds skip automatic Store checks.
- Updated Help and privacy guidance describes the Store query and locally cached build, time and result.

The Companion does not download/install updates or restart itself. Existing Microsoft Store automatic-update settings continue to apply. The protocol-1 add-on remains compatible; this change does not require an add-on update.

Public Store Submission 6 was accepted for certification on 9 November 2026 and is configured to publish automatically after approval. Public availability is not yet confirmed. Fresh WACK passed all 13 required checks and a local exact-candidate Defender scan found no threats. A real identity-bound Store query returned NoUpdate and cached relaunch made no request. Full Store-delivered 2.1.5 upgrade, real Available and real signed-out/offline observations remain unverified; the publisher explicitly chose to proceed without waiting for the private flight. Existing fixture failure/timeout coverage remains separate evidence. The original 2.1.4 artifacts are preserved.
