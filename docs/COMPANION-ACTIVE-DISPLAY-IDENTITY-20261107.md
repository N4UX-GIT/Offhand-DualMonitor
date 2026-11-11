# Active display identity follow-up, 2026-11-07

## Report and evidence boundary

The supplied Beta 20 screenshot shows two checked 1920 x 1080 displays,
single-display split disabled and a repeated request to select exactly two
displays. The reporter says only two monitors are connected. The screenshot
does not expose their Windows monitor identities or saved preferences, so it
does not establish an exact cause. Equal resolutions are valid and do not
imply equal monitor identities. A third device is not required for the known
Beta 20 failure: repeated identities can resolve both checked entries to one
display before the planner checks the count.

Reporter follow-up, 2026-11-07: the owner relays that restarting the PC resolved
this reported issue. Record this as a reporter-confirmed workaround. No
before/after identity capture or new candidate test was supplied, so the restart
does not establish the underlying cause or validate the pending correction.

The earlier [identity hardening](COMPANION-DISPLAY-IDENTITY-HARDENING-20261105.md)
protects against that collapse. However, Test 3 Revision 3 still reads monitor
child index zero through EnumDisplayDevices, even with the documented interface
name flag. Earlier reporter evidence in the primary checkout's
`docs/COMPANION-DISPLAY-SECOND-REPORT-20261106.md` shows two active GDI sources
whose first child points at the same disabled TV, including with that flag.
That is a confirmed enumeration gap in the previous correction, distinct from
the unconfirmed identity values in this new report.

## Local source correction

Based on `24f128293f4ac954cd205a2dc8847486a91b1138` on
`codex/workspace-current-addon-test`, with pending source changes:

- Resolve each GDI display source through QueryDisplayConfig's active paths.
  Read its source name and its actual target's monitor interface path through
  DisplayConfigGetDeviceInfo. Target adapter/ID come from the target, rather
  than the source. Model, resolution, reserved DeviceKey and child order are
  not used as persistent monitor identities.
- Enumerate monitor children only to retain an old migration alias whose
  interface path matches the active target. A stale first child does not
  become either the canonical identity or an unrelated migration alias.
- Refuse cloned sources, unnamed/missing targets and ambiguous identities.
  Transient query failures do not silently fall back to child zero. Retry
  buffer changes at most three times and cap native buffers.
- Retain a compatibility fallback only when the active-path API is absent or
  explicitly unsupported, and only when one interface child is returned.
  Existing global identity checks still reject duplicate fallback IDs.
- Keep identity schema 2, region geometry, named profiles and addon protocols.
  Existing canonical paths remain usable. Unresolvable old custom bindings
  still need explicit review; they are not guessed by display number.
- Include identity lookup provenance/failure in copied diagnostics, including
  when no valid plan exists. The additional native declaration reads the
  existing DisplayConfigGetDeviceInfo export, with a reviewed audit alias.

Microsoft contracts used:
[QueryDisplayConfig](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-querydisplayconfig),
[source name](https://learn.microsoft.com/en-us/windows/win32/api/wingdi/ns-wingdi-displayconfig_source_device_name),
[target name](https://learn.microsoft.com/en-us/windows/win32/api/wingdi/ns-wingdi-displayconfig_target_device_name),
[EnumDisplayDevices](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-enumdisplaydevicesw).

## Verification

- Display identity suite: 178 checks per architecture on x64 and x86, including
  the two 1920 x 1080 plan, repeated stale first children, active-child aliases,
  missing/duplicate children, cloned sources, duplicate current identities,
  missing target/source, unsupported fallback and failure refusal. Native
  target-name size (420 bytes) and path offset (164) are checked on both.
- Read-only native enumeration returned two distinct active-target paths on
  the local physical pair, on both architectures.
- Preferences/dashboard and display colour/scaling suites pass, including
  228 colour/interop/UI assertions per architecture and dashboard checks at
  100, 125, 150, 175 and 200 percent scaling.
- Interaction boundary passes: four source files, 41 reviewed declarations;
  restricted process/input symbols absent. No new process access, hooks,
  simulated input or injection was added.
- Local candidate builder verified executable/archive parity and preserved
  canonical public binary/archive hashes. A read-only reflection probe of the
  exact built executable confirmed two unique active paths. It did not launch
  Companion/WoW, apply a span or write preferences.

Candidate directory: `dist/monitor-active-path-candidate-20261107/`.
Executable SHA256:
`04D8A6DBA64F26536244EC341701233F1F4C421A91CA8CD14CA4E07ED3760139`.
Archive SHA256:
`F8E51415E1F382D0FD6A1608E034F52EA19B9EFECD7E211DB7096DDFF61BD483`.
The directory includes source/artifact hashes in `candidate.json` and the
read-only `Test-ExactCandidate.ps1` probe.

## Remaining acceptance and distribution

Published Test 3 Revision 3 is unchanged and does not contain this follow-up.
The initial investigation produced only the local candidate recorded above.
The owner subsequently authorized an unofficial Test 3 Revision 4 package;
its clean-source rebuild and exact source/artifact receipt are separate from
those initial candidate hashes. See
[Revision 4 guidance](CUSTOM-WORKSPACE-DISCORD-TEST-3-R4.md) and the package's
`TEST-BUILD.json`. Frozen canonical Companion artifacts are preserved. Addon
runtime remains the same reconciled source as Revision 3, with new TOC candidate
markers for Revision 4.

The remaining pre-package checks passed: 15 Companion suites, all 101 top-level
Lua suites, six manifests and Lua 5.1 syntax. This includes 3057 native rollback
assertions per architecture on synthetic windows, 36 Remote Desktop checks per
architecture, named profiles, workspace geometry and schema 1/2/3 bridges. No
live WoW client was used for these checks. The previous Revision 3 executable
also seeded named custom profiles with both choices of game monitor in isolated
fixture preference files for fresh-process candidate compatibility checks.

The reporter's exact cause and affected-hardware acceptance of the new candidate
remain open, although the reported symptom cleared after a PC restart.
Needed acceptance is fresh selection/review, successful Span and Restore,
restart with the saved roles, and any relevant dock/disabled-output topology.
Physical hotplug, affected identical panels, Wine and remote-session behavior
have not been established by these synthetic and local read-only checks.
