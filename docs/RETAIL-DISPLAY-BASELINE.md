# Retail graphics-reset and hang baseline

Retail has not been tested. Anniversary recovery acceptance does not establish
the original Midnight reporter's hang/error cause or Retail recovery behavior.

## Prepared baseline

- Source: addon release tag v2.1.2-beta.22, commit
  62de7a3f0e850601c02e1cb7d1db713186680988. This is a release-tag source baseline,
  not a claim that the downloaded CurseForge ZIP was byte-compared.
- Staging: D:/Tools/Code/Offhand/dist/retail-baseline-beta22/source. Forty-seven
  runtime/support files staged with SHA-256 manifest; six manifests, 35 Lua files
  and XML paths validated. Installer backs up all existing Retail addon files and
  preserves generated CompanionTopology/ForeverState files and SavedVariables.
- Installer updates released runtime files/TOCs. Unreferenced development-only
  files remain on disk but are absent from the released TOCs/XML.
- Retail currently contains development addon files. Do not label that installation
  as the release-tag baseline until installed.json records successful deployment.
- Retail executable metadata reports 12.1.5.70575; capture GetBuildInfo in-game
  before assigning the live build. Original reporter's exact build is unknown.
- OffhandDisplayProbe is installed and source hashes match the tested helper.
  BugGrabber/BugSack are installed; confirm they are enabled for the tested character.
- Use the public Store Companion Beta 20. Exit CLASSIC TEST 3 first. The Classic
  candidate intentionally rejects Retail and must not be used for this baseline.

## Install and test sequence

1. Close Classic normally, retaining its SavedVariables, and Exit its test Companion.
2. Install the staged release-tag Retail baseline with
   D:/Tools/Code/Offhand/dist/retail-baseline-beta22/Install-RetailBaseline.ps1.
   Deployment is blocked while any WoW client is running. Preserve its backup.
3. Open the Store Companion and Retail. Enable Offhand, Offhand Display Probe,
   BugGrabber and BugSack. Keep the addon list consistent within each comparison.
   Record other enabled addons before later isolation; do not reset the profile.
4. In ordinary Windowed mode set VSync Enabled, enter the world, then Span WoW Now.
   Reload once if needed to load the matching bridge. Verify chat and layout.
   If a Lua error already appears here, stop and retain the FIRST error.
5. Run D:/Tools/Code/Offhand/tools/display-capture/Start-Retail-Capture.cmd. Confirm
   it prints Capture file opened and Recording WoW window. Enter /ohcapture start.
6. Change VSync Enabled to Disabled through Graphics Options once. Do not expect
   automatic recovery from public Beta 20. Take a screenshot before manual recovery.
7. If responsive, /ohcapture stop, stop the watcher, then Span WoW Now to recover.
   Exit normally to flush the probe log. Retain first error and Companion activity.
8. If WoW hangs, stop repeating the action. The external log flushes independently;
   do not assume probe SavedVariables saved. Record the exact action and time.

## Capture safeguards

The Retail-specific watcher rejects a running Classic process. Startup now writes
and flushes a start record before monitor enumeration and records exceptions.
This improves diagnostic visibility; the cause of the previous empty capture is
not established. One-second Classic-filter preflight and Retail-rejection check
passed. No Retail process/window has been launched or observed during preparation.

## Interpretation

Native size/style/clipping reset, addon errors/taint and full application hang
are distinct results. Reproduce and diagnose each independently. Do not extend
Classic recovery to Retail merely because the screenshots look similar. Do not
replace the public Companion or alter graphics state with recovery code during
this baseline. Restore newer addon source only after preserving the comparison.
