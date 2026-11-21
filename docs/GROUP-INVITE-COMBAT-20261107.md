# Group invitations during combat, 7 November 2026

## Status and scope

Arual's screenshot asks whether group invites are broken during combat. It does
not identify client/build, Offhand version, input mode, topology, or whether the
failure is an invisible incoming popup, failed Accept/Decline, or sending invites.
Those details were requested. Investigation provisionally uses Forever
1.60.1.70862, consistent with this chat. Do not treat that as reporter evidence.

Two related placement conflicts are reproduced and corrected in source. The
reported combat failure remains unconfirmed. The correction is in private test14,
packaged and installed locally. It is not a verified combat fix or public release.
The [test14 attempt](FOREVER-DISCORD-TEST14-20261107.md) stopped at login before
any in-world popup testing.

## Findings

- Incoming PARTY_INVITE uses Blizzard's ordinary StaticPopup pool. Its native
  definition owns AcceptGroup, DeclineGroup, timeout and dismissal. Offhand has
  no direct party-invite event handler or replacement for those functions.
- Native OnShow deliberately disables Decline/Escape for roughly half a second.
  That is separate from an invite being unavailable throughout combat.
- Offhand's shared native-stack translator refuses combat-time writes, as does
  general transient placement. The general path deduplicates deferred work and
  processes it after PLAYER_REGEN_ENABLED. This defers positioning, not receipt
  of invitations. It does not queue or replay the group invitation itself.
- The screenshot's suggested explanation that a secure frame cannot move is a
  hypothesis. Neither missing AcceptGroup declarations in the shared corpus nor
  the native dialog's source proves the API's combat/taint contract.
- A native first popup anchors to the top of the full spanned UIParent. On a
  mixed-height layout, that position can be above the physical game display.
  If created during combat, Offhand will not relocate it until combat ends.
  This is a plausible visibility mechanism, not a reproduced reporter failure.

## Reproduced placement conflicts and correction

Core/SeamRedirect.lua still installed legacy OnShow centering on StaticPopup1..4
on Retail and Forever, although their dedicated modern translator already owns
the native linked stack. Its CENTER anchor destroys the stock TOP/linked anchor
that the translator recognizes. It also adds scripts to native action ancestors.

The broad UIParent/UISpecialFrames popup rescue could independently center the
same ordinary pooled root in a mixed-height void. The existing native-dialog
exclusion covered GuildInviteFrame/ChatConfigFrame but omitted StaticPopup1..4.

The candidate excludes Retail/Forever pools from the legacy script path and adds
their exact root identities to the existing native-dialog rescue exclusion.
The dedicated translator remains the position owner. Legacy client centering is
preserved. No native handlers, buttons, acceptance APIs, popup definitions,
visibility or combat restrictions are replaced or relaxed.

The integration regression calls the real HUD:HookFrames with fresh popup roots
on both modern clients and checks no legacy script attachment. It then invokes
the actual rescue ticker with a native TOP root inside the simulated monitor
void and checks its stack anchor survives. The first assertion fails against
frozen test13; after correcting the hook alone, the second assertion fails until
the generic rescue exclusion is added. Both pass with the final source. Legacy
OnShow centering remains installed. All 98 suites and six manifests pass.

## Source evidence

Shared knowledge status, PARTY_INVITE_REQUEST, StaticPopup combat, AcceptGroup
and C_PartyInfo.InviteUnit queries were consulted. The corpus is review-due;
AcceptGroup has no generated declaration entry. Exact-build upstream source was
read at Gethe/wow-ui-source revision 9dc84f0d3bbae1768ac3405b3716000bd93eda06:

- [GameDialogDefs.lua](https://github.com/Gethe/wow-ui-source/blob/9dc84f0d3bbae1768ac3405b3716000bd93eda06/Interface/AddOns/Blizzard_StaticPopup_Game/GameDialogDefs.lua),
  PARTY_INVITE at physical lines 1309-1338 and SetupLockOnDeclineButtonAndEscape.
- [StaticPopup.lua](https://github.com/Gethe/wow-ui-source/blob/9dc84f0d3bbae1768ac3405b3716000bd93eda06/Interface/AddOns/Blizzard_StaticPopup/StaticPopup.lua),
  StaticPopup_Show calls SetUpPosition before Show; SetUpPosition rebuilds TOP
  and dialog-to-dialog links. No copied upstream implementation is shipped.

Local paths: Core/HUDTransientFrames.lua PositionPremadeGroupDialogs and
PositionMainhandTransientFrames; Core/Init.lua RunOrQueueCombat and
PLAYER_REGEN_ENABLED; Core/SeamRedirect.lua HookFrames/RedirectExternalPopups;
Core/HUDTransientPolicy.lua IsNativeDialogRoot.

## Required native acceptance

Once the actual client/version and symptom are known, use a cooperating tester
to send a real invitation before combat, during manually controlled combat, and
after combat. Record receipt, visible popup/bounds, Accept/Decline result and
fresh blocked-action/taint errors separately. Repeat with Offhand disabled as a
baseline, then enabled on the reporter's actual layout; include a second native
popup to check stacking and an invite that expires before combat ends.

A synthetic popup or mocked InCombatLockdown does not validate AcceptGroup or
combat protection. The initial source pass launched no client. The later test14
attempt stopped at login and restored original settings/enablement. No live
combat, invitations, group actions or taint-safety claim was made.
