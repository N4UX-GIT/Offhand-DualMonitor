# Prototype 8 editor recovery

3 November 2026. Unpublished Companion `2.1.3-beta.3`, file/application
`2.1.3.4`, protocol 1. Clean source and build:
`73f2b9e69a3d8ef938b4d247d79ee26f5bb9c30f`. This follows the
[P7 persistence package](CUSTOM-WORKSPACE-REGIONS-PERSISTENCE-FOLLOWUP.md).

## Change

The multi-workspace editor could not disable custom mode after a required
monitor disappeared. Its Proposed method validated every selected custom monitor
before checking that the user had turned the feature off, despite the settings
publisher intentionally allowing a disabled plan to be saved with missing displays.
The new missing-Workspace-B regression case failed on P7 with
`Choose connected monitors for the game and each workspace` before the fix.

Disabling now creates a disabled settings copy without requiring every custom
display. It retains the saved region IDs, monitor identities, dimensions, count
and primary selection. When game and Workspace A resolve to different connected
displays, their pair becomes the ordinary selection. Otherwise the previous
selection is retained. Choose suitable connected displays in the main window
before applying a standard span. Saving a disabled plan does not move WoW.

Re-enabling a custom plan still requires every configured display. A missing B
is not silently replaced by another display or removed from the plan.

Workspace B controls are disabled when it is unused. Region dimensions and
visual selectors are disabled when custom mode is off; primary choice is disabled
when only Workspace A is used. A Workspace B removal confirmation applies only
when the original saved plan actually contained B. Adding and cancelling a new
pending B no longer asks to remove an already-saved workspace.

## Evidence

- New production C# editor/planner tests reproduce failure before the fix and
  pass after it. Includes missing B, all displays absent, disable/save during
  display loss, retained definitions, fail-closed re-enable and control states.
- Workspace fixture passes **324 checks per x64/x86 architecture**, including
  prior planner/bridge/clipping/settings tests, 100/125/150/200% fixture editor
  layout, and actual hidden-window native rollback. Exact production schema 2
  writer output is accepted by the Lua viewport for each architecture.
- Existing native span/Restore suite: **3,057 assertions per architecture**,
  160 custom rollback and 60 Restore cases each. These are synthetic windows.
- Existing taskbar presentation fixture: **25 assertions per architecture**.
- Preferences/dashboard policy, color/DPI **228 assertions per architecture**,
  partial topology **64 acceptance/rejection plus 32 position round trips**,
  and three-connected/two-selected **40 checks per architecture** pass.
- Addon runtime Core/UI/Locales/TOCs/Bindings is unchanged from `7146cc4`.
  The same 77-file addon ZIP is retained byte-for-byte, with its 85 passing Lua
  suites and six-TOC Lua 5.1/path/XML validation from the persistence follow-up.
  No new addon runtime, migration or client behavior is claimed here.

These tests do not establish physical monitor disconnect recovery, rendering or
input on three actual displays, native mixed-DPI behavior or protected-action
safety. Prototype 8 has no new live WoW acceptance at this checkpoint. P7 Retail
and Anniversary results remain attached to their original executable bytes.

## Artifacts and boundaries

| Component | SHA-256 |
| --- | --- |
| Prototype 8 EXE | `AB022A01DEE6D5CC627A5387DFC032D1B3D02BEA22DD0D5ED7CEC22157F388A3` |
| Original portable ZIP | `B9149D3684EDCE9DDC994335EA347F10F9A17C37DF81775268B3F3BDABCB7484` |
| Unchanged addon ZIP | `538D9E9BF9494A35CB95A8D63656B44230BC1F22EB948CB743D6F5B53150BCDB` |
| Unsigned validation MSIX | `598B3E27B1EDF0A76EA6BD9B5C3FD46BCE121AE529221CF9CF935F209CBA2754` |

MSIX boundaries, identity, capabilities, startup policy and exact portable EXE
parity pass. It uses separate validation identity/version `1.0.0.0`, remains
unsigned, and was neither installed nor submitted. The candidate build record
retains live verification pending. The new packet carries P7 runtime and the
unchanged persistence addon for rollback; prior packets stay immutable.

No installed addon, user configuration or physical display was changed during
this editor/packaging pass. Primary checkout and public Beta 20 assets remain
unchanged. Nothing was pushed, tagged, published or promoted. The shared knowledge
README, research skill, status and CompanionWorkspaceRegions evidence were
consulted; this fix follows local source/fixture evidence and adds no native API.
