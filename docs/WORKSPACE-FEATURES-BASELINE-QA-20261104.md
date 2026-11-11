# Baseline QA before workspace profile development

4 November 2026. Exact published Custom Workspace Regions Test 1 was tested
before starting the new feature implementation. Its 77 addon files matched the
published package; Companion `2.1.3-beta.3`, file `2.1.3.4`, SHA-256
`AB022A01DEE6D5CC627A5387DFC032D1B3D02BEA22DD0D5ED7CEC22157F388A3`
was reused unchanged. This evidence does not accept later feature bytes.

| Check | Evidence and result |
| --- | --- |
| Anniversary 2.5.6.70577 ordinary options tooltip | Long SettingsTooltip visibly contained. Local/effective scale and UIParent scale were 0.394, font height 14. On hide, the temporary local scale returned to 1. |
| Anniversary custom area | Saved 480x600 region, manual schema 2 span and reload produced the expected visible workspace and a 3991x1446 backing window. |
| Anniversary Restore Window | Original `(215,0) 2130x1392`, style `14CF0000`, no clipping region restored exactly. |
| Anniversary error comparison | Both captured BugGrabber stores matched their historical baseline records. The network disconnect was excluded as instructed. |
| Retail 12.1.5.70688 native Spellbook | Opened PlayerSpells, applied the same custom area, reloaded and reopened. The oversized native frame recovered to Mainhand at scale 1. Recorded rectangle was about `(1661.024,990.071,809,883)` in UIParent units. |
| Retail saved ownership | PlayerSpells and Collections retained their `(12,900,workspace-a)` destination records after the test. |
| Retail Collections | Root loaded and native scale 1 was observed. A complete final rectangle and clean cold lifecycle were not captured, so acceptance remains open. |
| Retail Restore Window | Original `(0,215) 2560x961`, style `14CF0000`, no clipping region restored exactly. |
| Retail errors | 13 historical records became 15. The two fresh errors came from local QA `/run` diagnostics: reading a not-yet-loaded root and enumerating a forbidden UIParent child. They were not addon runtime call stacks. They prevent a blanket zero-fresh-error claim. |
| Cleanup | Both test apps exited normally. Anniversary restored 20 original file states and 87 addon files; Retail restored 18 original file states and 78 addon files. Every original hash was verified. |

The existing level-one QA characters were used without gameplay. The user's
manual Character drag verification was not repeated. No account, realm,
credential or HUD-onboarding change was made.

Spanned tooltip hover and correction disable/re-enable transitions still need a
clean check. The GUI capture/input geometry was unreliable after spanning, so
those attempts were not counted as passes. The taskbar sample point was outside
the small top-of-monitor workspace and correctly hit Explorer. This does not
establish taskbar coverage inside a region intersecting the taskbar; the earlier
P8 taskbar evidence remains separately scoped.

No supported replacement-bag addon was installed, so a live bag integration test
was unavailable. Physical third-monitor input/rendering, mixed DPI and actual
monitor disconnect/reconnect require hardware evidence. Combat and protected
native descendants were not exercised. Collections lifecycle, cold fit recovery
and those boundaries remain release gates.

The custom span/reload, exact native Restore, native-size Spellbook recovery and
preserved region intent supported proceeding with an opt-in initial
[workspace profile implementation](CUSTOM-WORKSPACE-PROFILES.md). The remaining
checks were retained as explicit acceptance gaps, rather than promoted to passes.
Private profiles, account paths, screenshots, chat and raw error captures remain
in ignored local evidence directories and are excluded from packages.
