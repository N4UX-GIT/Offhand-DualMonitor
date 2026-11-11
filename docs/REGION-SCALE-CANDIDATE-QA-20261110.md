# Region scaling Companion candidate and native QA handoff

The initial candidate used stale Companion 2.1.5 source from the addon checkout. This was a source-base error, not just a version-label error. It is superseded by a rebuilt candidate using the verified Companion 2.1.6 base with all pending local Companion changes applied. Native acceptance remains pending on the corrected candidate.

The user selected the existing Noggaholic session on Forever. After the previous harness released the client, the matching addon snapshot and a private QA helper were installed with backups. The old candidate wrote a topology bridge containing the new metadata. Physical Escape then stopped Computer Use at character selection, before any feature acceptance. No UI interaction was resumed during the version correction. Installed test files, configuration changes and restoration remain pending; backups and the interrupted-run evidence are retained in the superseded candidate's `native-run/` directory.

## Built artifacts

- Corrected candidate directory: `dist/region-scale-companion-216-20261110-230444/`.
- Companion: `Offhand.exe`, product version 2.1.6, file version 2.1.6.1, SHA-256 `5BC115E2B16E1FD384836E96BC0E9E7C0F377D9A0DC825533169C427DA376919`.
- Runtime archive: `Offhand-Companion-v2.1.6-region-scale-candidate.zip`, SHA-256 `EA43A676C9C2A3C98DCCE0EF30E67486297FB97250009440202519591B5C37D9`. Its embedded executable bytes are verified by the existing package builder.
- Base source: verified clean 2.1.6 revision `a43e4fea4e7ddd4f8da8470c2275732c75ac458d` from the separate Companion checkout. All five base input hashes match its candidate receipt before applying the preserved local patch. The local patch includes display-selection diagnostics and region-scale metadata. The candidate retains `base-2.1.6-receipt.json`, `source-provenance.json`, `local-companion.patch` and the exact compiled source snapshot. Subsequent 2.1.7 development changes were not imported.
- Matching addon archive: `Offhand-region-scaling-addon-QA.zip`, SHA-256 `92f627066c6ab4560a3555e3d48a5eabd828b8cb647984f6fd1798ceb24869d9`.
- Native source snapshot, source hashes, public-artifact hashes, native interaction audit, archive hash and dirty-checkout provenance are recorded in `candidate.json`. Nothing is published or Store-submitted. The compiled version is checked against the expected 2.1.6 base; the path and hash identify this private build.
- `matched-qa-plan.json` links the exact addon verification/installer to the Companion source receipt. The frozen addon subject is `dist/discord-qa-20261110-20261110-224020-896564/validated-subject/`.
- The superseded candidate's `private-qa/OffhandRegionScaleQA/` contains the installed private helper with snapshots and addon QA buttons. It does not automate gameplay or enter combat. It observes the addon-owned scale writer, without installing hooks on native frames. It preserves a character-scoped baseline across reload and can restore the scoped test preferences. It has syntax validation only; loading it in-world has not been observed.

The candidate was built using `scripts/New-RegionScaleCandidate.ps1`, which freezes explicit C# inputs, checks source drift and canonical artifact hashes, validates the expected version and optional rebased-source provenance, runs the native interaction audit, builds with C# 5, and packages through `New-CompanionTestPackage.ps1`. It does not launch or install anything. The earlier 2.1.5 artifact is marked superseded. An intermediate build that failed the new version guard is marked rejected.

## Completed checks

- All 129 root Lua suites pass against the exact frozen addon snapshot; all 106 addon archive entries are verified.
- New region-scale C# fixtures pass on x86 and x64, including exact generated schema 2 and 3 metadata acceptance by Lua.
- On the corrected 2.1.6 source, display selection, flexible layouts, workspace regions, partial topology, layout documents and workspace profiles also pass. Exact results are recorded in `verification.json` beside the corrected candidate.
- Six manifests pass path/XML/Lua 5.1 syntax validation: 83 loaded Lua files and one XML file.
- Native interaction audit passes: four source files and 45 reviewed native declarations, with restricted process/input symbols absent.
- Canonical Companion executable and archive hashes remain unchanged.

The WoW harness diagnostics collector ran read-only against `C:/Games/World of Warcraft/_forever_`; its output is private in the superseded candidate directory. The installed executable reports 1.60.1.70862. Earlier observations of Noggaholic in-world belonged to the preceding harness. Our subsequent interrupted run reached character selection. The ordinary Store Companion was exited before launching the superseded candidate; the separate simulated Store-update test build was preserved. These observations are context, not region-scaling acceptance. Re-enumerate current processes and windows before resuming.

## Native sequence when testing resumes

1. Confirm the test session and coordinate use of the active diagnostics session. Close only the selected WoW client normally before installing, as required by the verified candidate installer. Preserve unrelated sessions and existing QA helpers. Back up the target addon folders, generated bridges, scoped preferences and Companion configuration.
2. Exit the ordinary Companion normally before starting the candidate, because the ordinary runtime uses the same instance mutex and can otherwise rewrite topology. Preserve its previous preferences. Do not interact with the unrelated simulated Store-update build.
3. Use the frozen installer for the target client, preserving existing topology/recovery bridges and account data. Install the optional private helper separately and record hashes/enabled addon state. Keep account/realm/character selection and authentication under user control.
4. Start the candidate and verify its process path/hash. First apply the same display plan as before the update. Reload the confirmed character so it reads the candidate's actual metadata. Capture exact runtime build, accepted topology, per-region metadata and native root scales.
5. Before applying a size, open calibration step 4 and Workspace settings. Capture default resolved values, region table contents and root scales. Preview manual and Auto values, switch regions and discard. Verify that these actions do not commit sizing or native scale writes.
6. Apply a temporary Flexible Layout with two workspace regions on the available display, preserving the original plan. Check each region independently with different manual percentages, dragging supported windows between them, reopening bags, map fitting and reset to native size. Reload and compare scoped persisted settings. On one physical display Auto should resolve to the same-monitor ratio; do not claim physical mixed-DPI acceptance.
7. Ask the player to enter a safe real combat state manually. Keep the addon test frames already visible. Apply a pending region size through the production UI, record deferred flags and any scale writes, then ask the player to leave combat. Verify zero Offhand scale writes while combat-restricted and one correct post-combat application. Simulated combat flags do not substitute for this check. Inspect current errors/taint and actual item/chat/map interactions where applicable.
8. Restore the original sizing and window preferences, disable the private helper, restore the original Companion plan/configuration and close only the tested WoW client normally. Record persistence, generated metadata and current error evidence after shutdown. Preserve the preexisting launcher and unrelated test build.

Native calibration, settings, default-size preservation, real combat, taint and cleanup all remain pending. Do not describe the candidate as live verified until the sequence and exact evidence are recorded.
