# Forever Discord test5, 7 November 2026

## Candidate and validation

The plan and report status are in `docs/ISSUES.md`. Test5 includes the prior
combined test4 work plus native dialog placement, external player-aura ownership
and French setup/recovery translations. It is an unreleased test candidate
built from dirty source based on 9c7e83c.

- Addon: `dist/Offhand-v2.1.2-beta.26-forever-discord.test5.zip`
- Complete: `dist/Offhand-Complete-v2.1.2-beta.26-forever-discord.test5.zip`
- Receipt: `dist/forever-discord-test5-20261107/verification-manifest.json`
- Manual checklist: `dist/forever-discord-test5-20261107/TESTING.txt`

The frozen snapshot contains 412 source files and the ZIP has 79 runtime entries.
All 91 Lua suites and six manifest/path/XML/Lua 5.1 checks pass on the frozen
source and with the packaged runtime extracted over the validation checkout.
Archive contents match staged hashes. Only staged TOCs carry the test5 release
identifier. Complete retains the frozen public Beta 20 Companion. Reference
caches and private live evidence are excluded from both ZIPs.

## Local client smoke test

Windows Forever 1.60.1 build 70840, WoW1 EU, existing level 1 Shaman QA character
in Durotar. Guild invite, popup, chat, panel manager and aura XML sources match
byte-for-byte between build 70790 and 70840. This does not prove runtime equivalence.

Installed after a full addon-folder backup at
`dist/forever-discord-test5-20261107/installed-backup`. Copied and hash-verified
77 runtime files, preserving the two generated topology/recovery bridges.
Offhand SavedVariables and BugGrabber baseline were backed up privately before
entering the world.

Observed:

- Cold load completes. Offhand reports loaded; Beta 20 Companion verifies
  `beta.26-forever-discord.test5` installed with protocol 1.
- General chat tab > Settings opens native ChatConfigFrame at its stock
  horizontal center. Combat Log tab changes its controls; Okay closes it.
  No chat preferences were changed.
- `/reload` completes and Offhand loads again. `/offhand diag full` executes.
- BugGrabber messages and counters match the baseline; only its session number
  changed. No new errors were recorded during this path. Combat/taint acceptance
  is still pending.
- Both launched QA applications were closed; Battle.net and unrelated apps
  remain open. Test5 remains installed with rollback backup available.

A delayed launch initially opened two clients and caused BLZ51900060. Both were
closed; the single-client retry reached the world. No credentials or security
settings were entered or changed.

Spanning was not attempted: public Beta 20 reported a disconnected saved display
identity, with neither current display selected. Its saved plan was preserved.
This validates only the unspanned smoke path. Real guild invites, popup stacks
on the split, Chat Settings on Mainhand/restoration, physical controller focus,
combat, French wrapping and the exact Ellesmere/Naowh setup remain pending.
A server shutdown countdown was visible during testing.

## Companion and bot handoff

### Native Companion continuation

The active Beta 6 prototype was launched after backing up public preferences.
Both current displays are selected and Mainhand remains the 2560x1440 primary;
workspace is the portrait 1440x2560 at (-1440,-1114). Both displays use 100%
Windows scaling. Mainhand and Delay controls fit visibly. This is native 100%
evidence; enlarged 175% coverage remains simulated.

Forever 70840 reports no servers available (BLZ51934200), matching Battle.net's
05:00-06:00 CET maintenance notice. At that unavailable-server screen, Span WoW
Now succeeds. Native readback reports outer (-1440,-1114 4000x2560), client
4000x2560 and matching region/expected geometry. Restore Window succeeds and
the activity log confirms automatic span paused for that client. No in-world
addon UI was available during this continuation, so this is Companion window
lifecycle evidence only. No display selection or Windows layout was changed.

WoW and Companion test windows were closed; Battle.net remains open. Opening
the activity log changed only its collapse preference. Public preferences were
then restored byte-for-byte from the backup. The 77 installed runtime files
still match the package. Generated topology/recovery bridge files were updated
by the normal Companion lifecycle, and their resulting hashes are recorded in
`dist/forever-discord-test5-20261107/continuation-20261107/native-span-receipt.json`.
The first smoke run's bridge-preservation result above remains historical.

The bot commit was checked again against the configured N4UXADDONS- repository;
there are still zero statuses, checks or deployment records. No public health
URL or Railway service target is in the non-secret repository configuration.
Hosting identification is needed to verify activation.

### Build provenance

The historical companion-display-selection checkout reproduces and corrects
a 175% clipping path. Its handoff identifies the active custom-workspace checkout
at `C:/Users/NAUX/.codex/worktrees/classic-graphics-recovery/Offhand`. That source
already has dynamic measured dashboard layout. Added the enlarged 175% sizing
and ancestor-containment regression there; the full preference suite, display
checks and 100-200% dashboard probes pass.

Built `dist/companion-discord-dpi-20261107/Offhand-Companion-v2.1.3-beta.6.zip`
with that checkout's candidate script and custom-regions option. Native
interaction audit passes. This is the full existing custom-workspace prototype,
separate from the addon Complete archive. Public Beta 20 is unchanged.
Reporter/Store DPI acceptance remains open.

Bot diagnostics correction and three passing Node regressions are committed and
pushed to N4UXADDONS main as b9f0324e607e4659ddbcd9995ff54cf751d8044f. GitHub
exposes zero statuses, check runs or deployments for that commit. Its empty
aggregate pending state is not a rollout confirmation. Railway activation is
unverified. A duplicate local bot was not started because startup also performs
Discord writes. No Discord messages or report tags were changed in this continuation.
