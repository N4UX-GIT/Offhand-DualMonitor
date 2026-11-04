# Companion interaction and release boundaries

4 November 2026. The user approved the layout roadmap subject to WoW
ToS/EULA, anti-cheat compatibility and antivirus considerations. These are
engineering/release constraints, not a claim of Blizzard approval or a
prediction of Warden detection behavior.

## Allowed development surface

The new layout document/planner performs local geometry calculations only.
The shipped Companion continues to use its reviewed native window/display
management and addon-owned file boundaries. New layout behavior must remain
explicitly selected, validated and reversible.

- No game-process memory inspection or modification, injected code/DLLs,
  remote threads, process debugging, packet interception, gameplay decisions,
  input broadcasting or automated gameplay.
- No synthetic game-key, mouse or chat-command path in the shipped Companion,
  including an automatic /reload or an input-injected acknowledgement channel.
- No Warden inspection, detection probing, concealment, bypass or spoofed
  approval. New features must remain defensible by what they do.
- Addon UI uses the exposed client UI APIs, respects protected-frame ownership
  and combat restrictions, and yields to established replacement addons.
- Keep the addon free and its Lua/XML visible. No in-game advertisements,
  donation requests or paywall. Existing local source searches found none of
  those solicitations in Core, UI or Locales for the inspected baseline.
- Retain player-initiated apply/restore and a visible reload-needed state.
  Layout hotkeys must not become gameplay automation or imply a fresh live
  combat/acceptance signal from stale on-disk SavedVariables.

Blizzard's [addon policy](https://eu.forums.blizzard.com/en/wow/t/wow-user-interface-add-on-development-policy/1642)
requires visible/free addon code and compliance with its terms. Publicly indexed
[EULA](https://www.blizzard.com/en-gb/legal/08b946df-660a-40e4-a072-1fbde65173b1/blizzard-end-user-license-agreement)
and [anti-cheating agreement](https://www.blizzard.com/en-us/legal/simple/cd5930c0-2784-420c-a23d-1e0d6ff8599b/anti-cheating-agreement)
excerpts address unauthorized automation/software and information collection.
Full-page fetches of the legal texts returned HTTP 403 during this review.
That access gap is recorded; this document does not establish complete legal
review, an exemption for external window tools or permission for a particular
Companion feature. No vendor was contacted on the user's behalf.

## Existing native surface and source audit

At source 86240b1, Program.cs has 36 native import declarations for display
information, window identification/position/style/clipping, GDI region handles,
distribution identity and DPI context. These are not new imports introduced
by the layout foundation.

The existing process-path helper first uses Process.MainModule.FileName, then
falls back to OpenProcess with PROCESS_QUERY_LIMITED_INFORMATION and
QueryFullProcessImageName. Its purpose is executable-path identification, not
gameplay-state collection. The fallback handle is closed in finally. This is
not a claim that framework internals never query process/module information.
Microsoft documents the limited-access path-query contract in
[QueryFullProcessImageName](https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-queryfullprocessimagenamew).
No broader process rights, debug privileges or new process probe is required
by the layout model. A future change to this helper needs specific review.

`scripts/Test-CompanionInteractionBoundary.ps1` checks the reviewed import
names/libraries and explicit entry-point aliases, rejects named process-memory
and synthetic-input APIs, pins the limited process-query access expression,
and emits source hashes. The existing isolated SpanPresentationTest experiment
is identified separately and is not treated as ordinary candidate code. Its
source is still checked for the restricted symbols.

This is a bounded textual tripwire. It is not a complete semantic security
analysis, analysis of the CLR/OS, an antivirus verdict or a Warden test. Do not
weaken it to hide a detection. Review any intentional native-surface change and
its purpose before updating the baseline. Candidate creation invokes the audit
before compilation and records the audit receipt's hash.

## Antivirus, provenance and distribution

Keep ordinary transparent .NET builds with stable product/publisher metadata.
Avoid obfuscators, executable packers, self-modifying or self-extracting loaders,
dynamic code download/execution, stealth services and unnecessary elevation.
Do not add Defender exclusions, disable protection, restore quarantined files
automatically or ask testers to ignore malware alerts.

Record the exact source, compiler/build recipe, EXE/archive hashes, signature
status and exact-artifact scan evidence for each candidate. Reuse the same
verified EXE bytes in all archives. A rebuilt executable needs new evidence;
historical Beta 18/Beta 20 Microsoft reviews do not transfer to another hash.
The frozen public files and published Test 2 assets remain unchanged.

Authenticode signing with a legitimately issued and consistently used publisher
certificate is a useful distribution improvement when signing infrastructure
is available. It does not guarantee a clean malware verdict or SmartScreen
reputation. Do not fabricate a signature, buy a certificate or use credentials
without the necessary user authorization.

Microsoft distinguishes SmartScreen reputation from Defender Antivirus
detection and describes developer dispute submission in its
[developer FAQ](https://learn.microsoft.com/en-us/defender-xdr/developer-faq).
There is no preemptive universal false-positive exemption. If a candidate is
detected, stop its promotion, retain the exact hash/verdict and prepare a
developer submission through the official channel. External submission or
correspondence requires authorization; none was performed in this review.

## Test 2 local scan, 4 November 2026

Local report-only custom scan of copies of the exact published files:

| File | SHA-256 |
| --- | --- |
| Companion 2.1.3 Beta 5 EXE | 574B54FA19ED341AC871E0F5840855F6316412C765828314228C22F264D3F186 |
| Workspace Test 2 complete ZIP | 5A9F88CC2F37B0E5B6E0D17691216BA8B3D2AC97E20216E748E8E085D34DF459 |

Defender platform 4.18.26100.4, engine 1.1.26100.4, definitions 1.463.125.0
(last updated 4 November 2026 at 11:32:50 +01:00). MpCmdRun custom scan exited
0 and explicitly reported that it found no threats. Antivirus and real-time
protection were enabled before and after; no exclusion or protection setting
was changed. The per-scan DisableRemediation option only requested reporting
without actions, and includes archive scanning as documented by
[Microsoft](https://learn.microsoft.com/en-us/defender-endpoint/command-line-arguments-microsoft-defender-antivirus).

The EXE is unsigned. This local result is specific to those files, that engine
and definitions at that time. It is not a Microsoft analyst determination,
SmartScreen reputation result, future-file guarantee, or anti-cheat clearance.
Private command output/hash receipts remain under ignored
dist/defender-test2-baseline-20261104-233724.

## Approved roadmap, first implementation increment

`Companion/Source/LayoutDocument.cs` defines a versioned document, deep draft
copies, immutable resolved rectangles and a pure planner. It supports same-
monitor center/stacked/offset geometry in fixtures, caps two workspaces, retains
the existing new-layout allocation limits, and rejects overlap, malformed IDs,
ambiguous/disconnected/resized monitors and future document versions. Explicit
legacy conversion preserves geometry and region IDs; an old plan outside the
new limits is refused for conversion without modifying its original data.

The model is compiled by its dedicated x64/x86 tests. It is not connected to
the production GUI, native Apply, saved profile store or a new addon topology
reader. The ordinary candidate builder still compiles Program.cs. Thus no new
same-monitor runtime feature or automatic behavior is enabled by this increment.

239 pure model/legacy checks pass per architecture. Eight source-boundary
mutation cases are rejected. These are simulation/static evidence. General
topology negotiation, versioned profile migration and a native feasibility
spike remain the next gated work packages in the
[roadmap](FANCYZONES-GAP-ANALYSIS-AND-IMPLEMENTATION-PLAN.md).

Existing native fixtures also pass: 352 schema 2 planner/clip/bridge/persistence
checks per x64/x86 architecture, actual generated C# bridge consumption by Lua,
25 native profile checks per architecture, and the preferences/dashboard/source
boundary suite. The new planner does not relax those old contracts.

The candidate builder's new audit hook was exercised in an unpublished compile
smoke check, preserving the ordinary Program.cs source hash
758D60CA5392249268565CA1CC6DF56F0E893F743A43FEC40E3CAEEBA045A4B1.
It produced a separately hashed EXE
0A4B376B0C8FAE4E9B59DB9D47C14E51544DAD5AA8BB9E87D620CB39D0325173
and verified its runtime ZIP/interaction-audit receipt. A second local custom
Defender scan of that build directory explicitly found no threats, exit 0,
using definitions 1.463.125.0. That EXE is unsigned and was not launched or
published. It is build-workflow evidence, not native acceptance for the new
model, and does not change Test 2's binary identity. Private receipts are under
dist/layout-foundation-buildcheck-20261104-234114.
