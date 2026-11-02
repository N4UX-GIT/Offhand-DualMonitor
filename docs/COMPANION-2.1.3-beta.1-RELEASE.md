# Offhand Companion 2.1.3 Beta 1

Draft candidate notes, updated 2 November 2026. Unpublished; targeted Retail and
Anniversary native checks passed. Broader live QA and Store delivery acceptance
are pending; unsigned MSIX executable parity passed locally. This is a Companion update, separate from addon
release numbering. Protocol 1 and the existing addon minimum stay unchanged.

<!-- offhand-companion-version: 2.1.3-beta.1 -->

Revision 4 adds restore-failure rollback and passes local synthetic/package
checks plus targeted Retail normal restore/repeated recovery. Broader QA remains
pending. Network disconnects are excluded from acceptance blockers at the user's
request following their report of poor Starlink connectivity. Earlier targeted passes
apply to revision 3; use the exact revision 4 live record for its scope.

## Changes prepared for testing

- Automatic recovery after the captured Graphics Options reset on Retail and
  Anniversary, once a Companion-applied span has been verified stable.
- Recovery retains Restore Window and Pause priority, bounded retries,
  stability verification and immediate cancellation when display choices change.
- Both manual span and optional delayed auto-span can establish recovery
  ownership. Restarting Companion does not infer an arm from an existing span.
- HDR/SDR and Windows scaling diagnostics with a compact, scrollable dashboard.
- Wine process-path fallback diagnostics, guarded display-selection persistence
  and suspension of auto-span after a failed window operation.
- Updated guidance for using the span after exiting Companion.
- Failure rollback now restores prior topology bytes and native window state,
  including its clipping region, with diagnostics for incomplete restoration.
  Synthetic-window verification passed; actual WoW rollback acceptance is pending.
- Settings saves now publish atomically, preserving the previous file on
  interrupted or rejected writes and retaining unknown settings keys.
- Failed Restore Window operations now retain prior clipping and placement as
  well as style and bounds. Region-clear failures are reported.

The experimental resize sequence remains disabled in this candidate. It is not
a confirmed sharpness fix. Automatic graphics recovery is not enabled for Era,
Forever, PTR or unknown clients; their ordinary Span/Restore remains available.
Custom workspace regions are being investigated and are not included.

## Candidate acceptance

Follow [the exact QA procedure](COMPANION-PRODUCTION-RECOVERY-QA.md), preserving
the candidate's executable hash and client build. Prior tester acceptance of
older builds does not establish acceptance of this combined executable. Forever
testing remains deferred until November 4 and does not become production-eligible
automatically when that date arrives.

The public portable Beta 20 executable/archive remain unchanged. The candidate
ZIP is for local review; no Store version, submission or public tag is assigned.
