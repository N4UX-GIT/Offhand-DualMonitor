# Offhand 2.1.3 Pre-Release Beta 27 and Companion 2.1.3 preparation

Corrected on 2026-11-08: the add-on remains Pre-Release Beta 27 (`2.1.3-beta.27`), continuing Beta 26. Companion stays clean `2.1.3`. Earlier unsuffixed add-on preparations are superseded and must not be published.

Prepared locally on 2026-11-08. The owner requested reconciliation of local
changes, matching add-on/portable publication preparation and commits. This work
does not publish a GitHub release, upload to CurseForge, push a tag, click Store
Publish now or submit a Defender sample.

## Reconciled source

The publication branch is `codex/workspace-current-addon-test`. Released source
on main is not promoted by this preparation. The current website mainline was
merged to keep its newer presentation while preserving custom-workspace
Background Studio library/region support.

| Local work | Disposition |
| --- | --- |
| Main add-on checkout, previously dirty on `addon/forever/gamepad-reports-20261105` | Committed as `4506eac`, then merged with the workspace implementation in `a01090e`. All tracked/untracked runtime modules, tests, locale updates, diagnostics tools and QA notes were accounted for. |
| Website mainline through `6be1da7` | Merged in `f2f8105`; retained region/media Studio behavior and combined the stylesheet cache versions. |
| Pending display reporter evidence and expanded child-scaling fixture | Committed as `7fb4798`, merged in `51c403f`; no Companion runtime changes. |
| Detached Beta 20 display-selection investigation | Preserved on `codex/display-selection-preserved-20261108` as `ca3c0d9`. Marked reconciled with an explicit superseded-history merge: its old implementation was already replaced by active-path identity resolution and broader migration tests in the frozen 2.1.3 runtime. It was not replayed over that newer source. |
| Other clean historical worktrees/branches | Existing committed investigations remain intact. They are not uncommitted pending fixes or instructions to revive superseded experiments. |

Conflict review retained both workspace additions and the latest add-on fixes,
including native bag combat permission guards, selected-region placement,
comparison-tooltip routing, map lifecycle ownership, popup ownership, EncounterBar
repair and both sets of regression cases. The merged package contains 86 add-on
files, including 75 manifest-referenced runtime files (74 Lua and one XML).

The newer complete EFIGS policy also applies to the 44 custom-workspace strings
in deDE, frFR, itIT, esES and esMX. Mainhand and the naturally identical French
Collections label are valid invariant labels. Other dictionaries retain their
existing fallback policy. The Companion test now checks localized download copy
through its locale key, rather than requiring English prose in UI/Options.lua.

## Frozen native identity

| Artifact | SHA-256 |
| --- | --- |
| Offhand.exe, 2.1.3 / file 2.1.3.9 | `88916B6FBAA4FF2E81EC574F8FA248C553ED531AD7A3DC828FF4948568797443` |
| Offhand-Companion-v2.1.3.zip | `C277105FEFA08B8A7EC7B089151D418960FF0378B449375BBBF56B2686AB816A` |
| Submitted Store MSIX, 2.1.300.0 | `5F77AA758BD12FB45520381CAEE9FFE1644D868B00D600710E622972708A6F68` |

The first two exact assets are tracked under `Companion/Prepared/2.1.3/` so a
fresh checkout can prepare publication without a machine-local dist folder or
recompilation. `release.json` preserves the original native source revision,
source/resource fingerprints and Store identity. Text-source fingerprints ignore
CRLF/LF checkout differences; the native EXE, ZIP and artwork hashes are exact.

The canonical Beta 20 files under `Companion/` and every previous tester/download
archive remain unchanged. None of the current add-on merges changes the frozen
Companion runtime, WACK sample or Defender sample. The newly packaged add-on has
its own current source revision and hashes; the old 83-file add-on receipt does
not describe the new 86-file package.

## Prepared publication workflow

From a clean committed checkout, use a fresh directory:

```powershell
./tests/publication-213.ps1
./scripts/Prepare-213Publication.ps1 -OutputDirectory dist/publication-2.1.3
./scripts/New-ReleaseMetadata.ps1 -Tag v2.1.3-beta.27 -CompanionReleaseTag v2.1.3 -OutputPath dist/publication-2.1.3/release-notes.md
```

The preparation script validates exact frozen hashes, embedded version, all
runtime source/resource fingerprints, six matching TOCs, inert bridge files and
the reviewed add-on inventory. It refuses a dirty checkout, changed native bits,
source drift or an existing output directory. It never compiles the Companion,
installs files into WoW, alters preferences or replaces historical outputs.

Outputs:

- `Offhand-v2.1.3-beta.27.zip`: add-on only, for CurseForge/GitHub.
- `Offhand-Companion-v2.1.3.zip`: exact frozen minimal portable ZIP.
- `Offhand-Complete-v2.1.3-beta.27.zip`: matching add-on, frozen EXE and install guidance.
- `Offhand.exe`, `checksums-sha256.txt`, `publication.json`, `release-notes.md`.

All ZIP entries are read back and hashed. The minimal ZIP still contains exactly
LICENSE, Offhand.exe and README.txt. The paired receipt names both source
revisions. User preferences, SavedVariables, reference caches, tests, tools and
private QA files are excluded from runtime packages.

The tag workflow handles both component tags with separate draft releases.
`v2.1.3-beta.27` creates **Offhand v2.1.3 Pre-Release Beta 27** with
`prerelease: true`. `v2.1.3` creates **Offhand Companion v2.1.3** with
portable assets only. It never publishes the add-on as stable. The
`companion-release/` directory has its own exact-file checksums and provenance.
Neither lane rebuilds the EXE. Historical tag behavior retains its Beta 20 lane.
This avoids accidentally packaging Beta 20 for the 2.1.3 tag. GitHub attestations
are generated by that tagged workflow, not claimed for locally prepared assets.
Their provenance covers the publication operation; the native build revision
remains the one recorded in the receipt.

## Validation and limits

The merged source passes 109 Lua suites and all six manifests with Lua 5.1
syntax validation. Five website/Studio suites and 21 Companion/publication
checks passed, including graphics variants, x64/x86 rollback and enlarged-child
scaling coverage. The publication checks
exercise rejection of changed EXE/ZIP bytes, false identity/build hashes and
source drift. Full Companion/regression and final archive results are retained
in `dist/2.1.3-publication-preparation-20261108/`; the final packaging receipt
identifies the exact committed revision.

Initial failures were retained in the QA logs and investigated. Python-launched
Windows PowerShell inherited PowerShell 7 module paths and could not load
Get-FileHash; the same checks passed under the normal shell. The synthetic
rollback fixture also assumed a larger and negative-origin desktop existed on
the host. Its custom-span window now permits the synthetic width explicitly,
and the Restore fixture uses an actual desktop location when the test topology
is wholly offscreen. All exact bounds/style/clipping and placement assertions
remain; the negative-origin topology/clipping cases and native span rollback
cases remain covered. Both architectures pass 3057 assertions, 160 custom
rollback cases and 60 custom Restore cases. No production runtime change was
needed.

Microsoft documents the relevant
[WinForms maximum-size boundary](https://learn.microsoft.com/en-us/dotnet/api/system.windows.forms.form.maximumsize?view=netframework-4.8.1)
and automatic relocation of completely offscreen windows by
[SetWindowPlacement](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-setwindowplacement).

WACK and Defender scan evidence remains as recorded in the
[preflight receipt](COMPANION-2.1.3-WACK-20261107.md). The exact binary is
unchanged, so neither is represented as a new run. Existing live bag/controller,
map/vendor/reload and popup evidence remains scoped to its exact client/build,
installed candidate and action. The combined new package has not received new
live WoW acceptance. Physical mixed-DPI/hotplug/three-monitor, Wine and full
protected-action coverage remain separate.

## Promotion after certification

1. Check the actual status of Store Submission 3. It was last observed in
   pre-processing with manual publishing held; preparation is not certification.
2. Review the current prepared package hashes, matched add-on source and any
   remaining acceptance gaps. Update the README preparation notice when actually
   promoting the release. Retain the install, security and rollback guidance.
3. With publication authorized, promote the reviewed source through the release
   PR, push the intentional v2.1.3 Companion and v2.1.3-beta.27 add-on tags and review both drafts/provenance. Publish
   the exact portable assets before relying on the add-on's v2.1.3 download URL.
4. Publish the matching add-on ZIP to CurseForge separately as a Beta file, not a Release file. The Store updates
   Companion only. Coordinate GitHub, CurseForge, website links and Store
   Publish now so users can obtain the matching components.
5. Verify a real Store-delivered 2.1.20.0 to 2.1.300.0 upgrade, profiles and the
   paired add-on installation. Do not infer this from unsigned-package tests.

No Defender submission was made because the inspected form did not offer a
classification matching the clean samples. Preserve the prepared sample/context
for a real detection or an applicable review route. Store certification does not
sign the portable EXE or guarantee SmartScreen reputation.
