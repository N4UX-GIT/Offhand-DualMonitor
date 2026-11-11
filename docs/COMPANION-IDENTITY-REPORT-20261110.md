# Companion 2.1.5 missing display identity report

Investigation date: 2026-11-10. Issue: OH-UI-040.

## Finding

The reported dialog is a Companion selection/identity preflight refusal. It is
raised before the topology bridge is written or the native WoW window is resized.
The exact message does not distinguish missing monitor identities from incomplete
selection controls, so it does not establish a Windows API or driver failure.
The reporter-specific cause remains unresolved.

The supplied screenshot shows Companion 2.1.5, Forever running and addon beta.28.
Mainhand displays Display 1 (1920x1080), split is unchecked and auto-span is off.
The modal covers the checked-display list, so its selection cannot be established.
The activity log records successful numbered overlays, followed by the refusal.
Full Companion build/hash, Windows build, exact WoW build and monitor connection
types are not supplied. Do not reuse the separate audio reporter's build as fact.

## Source trace

Reviewed current Companion/Source/Program.cs, unchanged from tag v2.1.5-beta.28
at dc5e9eb1526dd1ac0adad56d1021f7e9231cf5e1. This identifies the reviewed source,
not the reporter's installed bytes.

- PreparePhysicalSpanSelection, around line 7060: manual standard-layout Span
  rereads the UI controls into a copied selection before confirmation. A stale
  saved plan alone should not explain this refusal when current checked displays
  and the Mainhand choice all have identities. A disconnected saved display has
  a separate refusal before this step.
- SaveDisplaySettingsFromControls, line 4596: MonitorIdentities is saved only when
  every checked screen has StableId. MainhandIdentity requires a selected
  DisplayChoice with StableId. A fresh zero-checked selection supplies neither.
- ConfirmStableDisplayIdentity, line 4651: the exact dialog is thrown when either
  MonitorIdentities or MainhandIdentity is absent in a standard plan. It happens
  before the confirmation dialog, preference commit, topology write and resize.
- DisplayIdentity.Read/Resolve, lines 457-578: identity lookup uses active Windows
  source/target paths. A query failure, absent target/path or multiple targets
  for one source can leave identity empty. The single-child fallback applies only
  when active-path APIs are unsupported, not after arbitrary failures. These are
  implementation possibilities, not findings about the reporter's machine.
- ShowDisplayIdentifiers, line 4868: numbered overlays use Screen geometry and
  current roles. Their success does not prove a stable identity was obtained.
- CopyColorDiagnostics / RefreshColorStatus, lines 6428-6461: Copy Display
  Diagnostics works without a confirmed layout. That branch includes each
  display's device name, identity and IdentityDetail lookup reason. The card's
  'after a display layout is confirmed' text does not disable this evidence path.

Persistent identities prevent automatic role swaps when Windows renumbers
displays. Missing IDs must not be replaced with guessed monitor indices.

Microsoft contracts checked on 2026-11-10:

- [QueryDisplayConfig](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-querydisplayconfig):
  active-path enumeration, unsupported/access errors and retry on buffer changes.
- [DISPLAYCONFIG_TARGET_DEVICE_NAME](https://learn.microsoft.com/en-us/windows/win32/api/wingdi/ns-wingdi-displayconfig_target_device_name):
  monitor device path and target naming information.

## Verification

Existing tests/companion-display-selection.ps1 passed 177 checks on each of x64
and x86, including migrations, ambiguity, reconnect and active-path resolution.
Its read-only native smoke test returned a valid identity on this machine's
single active display. This is not the reporter's topology or a two-screen span.

An isolated reflection probe compiled against production source exercised actual
SaveDisplaySettingsFromControls(false) and ConfirmStableDisplayIdentity(true):

| Synthetic state | Result |
| --- | --- |
| Complete checked pair and selected Mainhand | Identity preflight accepted |
| Workspace StableId missing | Exact reported message |
| Mainhand StableId missing | Exact reported message |
| Mainhand dropdown empty | Exact reported message |
| Fresh preferences, no displays checked | Exact reported message |

All 26 assertions passed on each architecture, including confirmation-state
preservation. No form was shown, span invoked, preferences written or WoW
controlled. The one-off probe is retained at
C:/Users/NAUX/AppData/Local/Temp/Offhand-identity-investigation-eeb004dff6ac43529ce5e326ed065fb5/IdentityGuardProbe.cs.

Existing read-only diagnostic archive
dist/Offhand-Monitor-ID-Diagnostic-20261106-v3.zip was verified: all five entries
match tools/display-identity source. SHA256:
2519745F4815AF2083C637CE5A71C0D5A131BC31D77FCB050F97C80957BB9DDE.
At this initial investigation stage, no production source, executable, package
or user settings were changed.

## Reporter evidence needed

1. Dismiss the modal. Copy Display Diagnostics and provide its full text. Capture
   an unobscured screenshot of the checked displays and Mainhand selection.
2. State the physical display count and connection types, plus any dock, disabled
   TV, virtual display or remote session. These are topology questions, not
   presumed causes. For ordinary two-monitor use, select both intended displays
   and explicitly choose the game display in Mainhand, then retry once.
3. If an identity is still missing, use the existing v3 monitor-ID diagnostic in
   the same display/session configuration. Capture once with the applications
   fully closed, retaining saved preferences, and return the JSON privately.
   It includes raw active-path result codes and monitor-child comparisons that
   separate a missing identity from a selection-binding problem.

Identify Displays is an overlay, not an identity repair. An addon reinstall or
SavedVariables deletion does not address this preflight path. A runtime change
should follow the reporter's evidence; this investigation does not justify
bypassing identity validation or declaring a particular driver at fault.

## Authorized source improvement, 2026-11-10

The owner subsequently requested clearer errors and diagnostics while retaining
the safety checks. Companion source now explains the original missing-binding
refusal using current standard selection controls:

- No checked displays: asks the player to check displays and choose Mainhand.
- No Mainhand choice: asks for a Mainhand selection.
- Unchecked Mainhand: asks the player to check it or choose a checked display.
- Missing monitor identity: names each affected display and its resolution,
  and directs the player to Copy Display Diagnostics.
- Ambiguous identity: identifies the display that cannot be distinguished.
- Complete UI identities but incomplete saved bindings: explains that the
  selection is not fully saved, without attributing a failure to Windows.

The existing missing-binding condition still throws. The new feedback helper is
read-only; it cannot authorize Span, repair IDs or save settings. Confirmation,
schema, uniqueness, disconnected-display, session and planner checks retain their
existing decisions. Other planner refusals still use their existing messages.

Copied diagnostics now include checked display count and labels, Mainhand choice
and checked state, split mode, current session, UI/current topology agreement,
saved binding values/validity/confirmation state, actual saved-plan validation
failure, and every current display's bounds, identity and lookup reason. Custom
and remote sessions mark the standard controls inactive rather than assigning a
false incomplete-selection status to them. The unconfirmed-layout card explicitly
states that Copy Display Diagnostics is available.

Active target-name failures now retain their Windows result code in IdentityDetail;
unavailable targets and empty monitor device paths have separate explanations.
The accepted identity values and fallback conditions are unchanged.

Validation after the change:

- Display selection suite: 247 checks on each of x64/x86, including actual
  production UI capture, confirmation refusal, diagnostics-card data, automatic
  confirmation guards, preserved pending settings and unchanged sentinel file.
- Preference/layout suite: passed, including 100-200% dashboard scaling and
  frozen-artifact packaging checks.
- Color/diagnostics suite: 228 assertions per architecture.
- Remote Desktop suite: 36 checks per architecture.
- Native rollback fixture: 3,057 assertions per architecture on synthetic test
  windows, including 160 custom rollback and 60 Restore cases per architecture.
- Targeted diff whitespace checks passed.

These are source, simulated and local fixture results. The reporter's hardware
has not been tested. No public executable/archive was rebuilt, installed or
released; this source change belongs in a future Companion candidate. The
initial investigation's tag and line references above describe the old source.
