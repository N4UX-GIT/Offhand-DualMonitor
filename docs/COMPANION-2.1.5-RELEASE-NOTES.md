# Offhand Companion 2.1.5

Adds quiet update availability detection for Microsoft Store installations, with
a static Update available button and tray action. Checks start after the
dashboard loads and run at most once daily. Clicking the action opens Store;
the Companion does not download/install updates or restart itself. Portable
GitHub checks remain manual. Help/privacy explain the separate local cache.

Also includes the redesigned 2.1.4 dashboard: Span WoW Now and Restore Window at
the top, guidance beneath each button, a collapsed System Status indicator,
Configuration open by default, stable Show/Hide sizing and dark scrollbars.
Retains the 2.1.3 Store settings-save hotfix, custom workspaces/Flexible Layout,
monitor-identity/scaling safeguards and window recovery.

After spanning or changing Mainhand/layout, type `/reload` in WoW. Save plan
stores choices only; Span WoW Now applies them. Install the add-on separately.
The paired add-on is **2.1.5 Pre-Release Beta 28**. Existing protocol-1 add-ons
remain compatible.

- [Recommended signed Microsoft Store installation](https://apps.microsoft.com/detail/9PL4PW84Q90W).
- Portable: `Offhand-Companion-v2.1.5.zip`, containing Offhand.exe, README.txt and LICENSE.
- Exact EXE build 2.1.5.1, SHA-256 `95811DBB7020A20E2541AE123E69FE80721C83A0FD52D0EE5557DD6D54DCCC2A`.

Store Submission 6 is in certification, with automatic publication after approval;
public Store availability is not yet confirmed. Full flight acceptance was not
awaited at the owner's request. A real identity-bound NoUpdate query and cached
relaunch passed; Store-delivered 2.1.5 upgrade, real Available and real signed-out/
offline observations remain unverified. Manual Store access remains available.

WACK passed all 13 required checks, with one reviewed existing optional finding.
A local Defender scan found no threats. The portable EXE is unsigned and has no
Microsoft Defender file-review verdict; Store certification does not sign the
portable EXE or guarantee reputation. Check the attached SHA-256 checksums. Do
not disable antivirus or add exclusions to bypass a detection. Wine remains
experimental; physical display and complete client/combat coverage are not
established by automated checks.
