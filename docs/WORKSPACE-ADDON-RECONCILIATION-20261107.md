# Workspace Test 3 addon reconciliation

The revised tester addon combines the released Beta 26 baseline, the local
addon candidates, and the workspace branch used in Test 3.

The workspace parent is 35b8396f82d3296348937816e47a4d85a8b9b10b.
The local source snapshot is 0c29e1285f8ac94ed9e89e8b1a9293d50ed8c1f8,
based on Beta 26 commit 9c7e83c. The snapshot contains 59 changed runtime,
manifest, changelog and Lua test files captured through an isolated Git index.
The original local checkout retains its edits and staging.

A follow-up snapshot, 6c19735bd1ad0c05fdd127e2cb4b6ac0e319db83, captures
local changes that arrived during packaging. It adds Forever native-dialog
fixtures, aura-bar ownership guards, related popup-hook restrictions and
French text corrections. The combined generic rescue path preserves both
external aura ownership and workspace-canvas exclusions.

## Combined behavior

- The six addon manifests retain Beta 26 release metadata and declare topology
  schemas 1, 2 and 3.
- Custom regions, Flexible Layout, workspace profiles, panel routing, region
  themes and installed background libraries remain available.
- Current first-launch and per-character setup, shared and character HUD reuse,
  Forever controller and bag behavior, Ellesmere preview and compatibility
  diagnostics come from the local source snapshot.
- The local Retail secret-value guards remain in popup geometry reads.
  Tooltip ownership and comparison bounds use the selected workspace region.
- Existing translations and current setup guidance are retained. The 44 new
  workspace keys in each locale keep their workspace-branch fallback text.

The Companion source and frozen public native assets match Test 3. Packaging
reuses the exact Test 3 executable and records its hash.

## Verification

All 101 top-level Lua suites passed after the follow-up reconciliation. A targeted addition
to the popup suite verifies that comparison tooltips follow their owner's
workspace. All six manifests, 72 runtime paths, XML references and Lua 5.1
syntax passed validation.

These are source and simulated checks. Existing live evidence for the earlier
workspace and local Forever candidates remains scoped to those candidates.
Live acceptance of the combined addon, protected actions and combat, mixed DPI,
physical third-monitor behavior and monitor reconnects remains pending.

The revised bundle is an unofficial tester artifact.
