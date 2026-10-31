# Retail notification candidate and post-change verification

## Implemented scope

This candidate follows the source audit in RETAIL-NOTIFICATION-AUDIT-20261031.md.
Target reporter build is Retail 12.1.5.70688; pinned implementation evidence is
12.1.5.70575 at 15881d522c44cd106d3d8660106ec9f9d2f44167. Live target behavior
remains authoritative. No new native notification was activated during development.

The existing Retail native-stack adapter now covers ordinary StaticPopup1..4,
Premade Groups roots, LFDRoleCheckPopup, LFGReadyCheckPopup, LFGInvitePopup,
PVPReadyPopup, PetBattleQueueReadyFrame, RolePollPopup and LFGDungeonReadyPopup.
Only a known UIParent TOP stack root is translated. All native links, local
offsets, hidden ancestors, visibility and button handlers remain native.
Retail no longer independently centers ordinary pooled dialogs or applies an
individual transient anchor to the role poll/dungeon popup, avoiding competing
writers within the shared stack. Other clients retain their existing policy.
LFGInvitePopup is eligible only when a real native transaction supplies the
reviewed anchor; no legacy frame is force-shown or assumed active on 70688.

Standalone ChallengesKeystoneFrame, ChallengeModeCompleteBanner,
EventToastManagerFrame and EventToastManagerSideDisplay translate native anchors
to the corresponding Mainhand reference points, retaining scale/local offsets.
External secure post-hooks observe ShowKeystoneFrame, PlayBanner, UpdateAnchor and
DisplayToastsByLevel. The toast hook handles completed native two-point/custom
offset transactions. Later custom anchors, user placement, alternate parents,
managed systems, protected/forbidden roots cause ownership to yield.
Still-owned anchors restore when hidden, disabled or unspanned. Hooks install once;
there is no additional recurring ticker or global frame scan.

No native accept/start/cancel/close handlers, scripts, text, queue tables, frame
parents, scale or explicit sizes are replaced. Native keystone activation and
completion events are never fabricated. The code does not bypass combat or
protected-action restrictions. Existing main transient/viewport combat queues
and recovery passes own delayed reconciliation.

Known roots are excluded from generic workspace dragging/persistence and added
to full interaction diagnostics. Native death-recap/UIPanel, Talking Head,
inherited reward alerts, ghost button, queue-status, timer and seat-indicator
ownership remain as audited; no unverified generic movement was added to them.

## Automated evidence

All 69 Lua 5.1 suites pass on source and the frozen package snapshot.
retail-notifications.lua covers native keystone/banner/side-display transactions,
toast setup before show, repeated native resets, custom two-point offsets,
idempotence, mixed/portrait geometry, frame scale, conditional restoration,
combat exclusions, protected/forbidden/custom/managed/alternate-parent yielding
and non-Retail isolation. The expanded premade-group-dialogs.lua covers the added
confirmation roots and mixed ordinary/special stacks with hidden dependencies.
Original confirmed-fix regressions continue to pass. Six manifests pass source,
installed and extracted-package path/XML/Lua 5.1 checks.

These tests use mocks and a secure-snippet model. They do not prove live geometry,
native action success or taint safety.

## Local deployment and package

Five changed modules were copied to local Retail: HUDTransientPolicy,
HUDTransientFrames, HUDRecovery, Viewport and Canvas, with SHA256 verification.
Pre-update full addon backup and deployment inventory:
`D:/Games/World of Warcraft/_offhand_deploy_backups/retail-notifications-20261031-192908-379`.
Generated bridges, SavedVariables, Companion and other installs were preserved.
Run /reload out of combat to load the local candidate.

Reporter package:
`dist/Offhand-v2.1.2-beta.24-retail-test.3.zip`, 769355 bytes.
SHA256: `67ED31AAC15D4DBE576492CC8C3949F7E9F29CE1E12D5853EF3252F8FFE7C31A`.
All 76 extracted files match the frozen snapshot. Portable bridge placeholders,
no native executable, tests, caches or account data. Only snapshot TOC release
labels changed; canonical/installed metadata remains Beta 24. Test.1/.2 preserved.
Build snapshot, extracted package and per-file hashes:
`D:/Games/World of Warcraft/_offhand_deploy_backups/retail-reporter-test3-20261031-192944-624`.

## Live acceptance checklist

New baseline evidence: reporter explicitly identifies test.2 and supplies the
end-of-Mythic+ panel (dungeon title, timer result, keystone upgrade and party
portraits) remaining at the full-span center. Appearance is consistent with
ChallengeModeCompleteBanner; no /fstack identity was captured. The test.2 ZIP
lacks that policy while test.3 contains it and the native-method post-hook.
Record the test.2 failure; leave the test.3 completion retest PENDING.

Every row remains PENDING for this expanded candidate. Record exact client/build,
candidate hash, geometry, relevant addon owners, screenshot, native action and
fresh Lua/taint results. A preview is geometry evidence only.

| Scenario | Required post-change observations |
| --- | --- |
| Original Premade Groups regression | Roles, notes, sign-up and invitation accept/decline work; simultaneous prompts stay stacked on Mainhand. |
| Other group/PvP/pet-battle confirmations | Real native role/ready prompt, timeout/cancel and normal acceptance; no automated queueing. Record unavailable variants explicitly. |
| Ordinary/special mixed stack | Both popup orders, either close order and remaining visible dialog following a hidden anchor root. No seam drift or overlap. |
| Keystone insertion window | Open a real font without starting a timed key, inspect root and native close behavior. Do not start a challenge just for UI verification. |
| Completion banner | Capture after an intended real completion, retaining native animation and dismissal. Do not fabricate the event. |
| Main event toast | Natural display and refreshed content/custom offsets remain on Mainhand without visible anchor alternation. |
| Side display | Real level-up details/history where available; opening/closing and refresh retain position and restore native anchors. |
| Lifecycle/ownership | Reload, disable/unspan and re-enable/span, scaled/mixed-height layouts, active replacement addons, relevant combat transitions and current taint logs. |

The sidecar TESTING.txt gives the shareable install, rollback and feedback steps.
No claim of a post-change live pass is made until these observations exist.
