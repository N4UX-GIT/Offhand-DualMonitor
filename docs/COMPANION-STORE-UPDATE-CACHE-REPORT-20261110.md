# Store update availability report, 2026-11-10

The owner reported that the Store offered the new published update but Companion 2.1.5 had not changed its update indicator. Read-only local investigation found the installed public package was still 2.1.500.0, with the exact released 2.1.5.1 executable. No app update was installed during this investigation.

## Finding

The real package-local StoreUpdateCheck.ini recorded AttemptUtc=2026-11-09T16:50:31.0066867Z, Build=2.1.5.1, State=NoUpdate. The app had been restarted at approximately 09:08 UTC on November 10. Source StoreUpdateCache.Interval is one day; restarting honors the persisted attempt time. UntilDue therefore defers the next real query until November 10 at 16:50:31 UTC (17:50 CET). Publication does not invalidate this cache. A running app does reschedule a check at that deadline; this is not a startup-only check.

The released 2.1.5 code was then loaded into the existing read-only diagnostic host under the installed production Store family, with fresh isolated preferences/cache and game monitoring/actions disabled. After its ordinary startup delay, the real availability API returned Available in 2839 ms, with one request, no exception and the button text Update available. The host exited after recording the result. This demonstrates the exact released query/presentation code can detect an eligible update when a request is permitted. It does not demonstrate a normal production-app activation or identify the target package version, since the production query only returns an availability enum.

The app's original settings and Store cache hashes were unchanged. No production cache deletion/reset, app installation, network/security setting change, game input or source/package modification was performed. Raw local output is under dist/companion-215-update-report-20261110. [Sanitized receipt](evidence/companion-215-update-available-20261110.json) records the result.

## Implication

The observed stale indicator is explained by the deliberately conservative daily throttle. The current 2.1.6 payload retains that policy. A restart within the same day does not force a fresh query. The existing Store Updates action still opens Microsoft Store for a manual update.

For a future version, consider reducing the quiet interval to six hours and making the last/next check time visible in update guidance. This would need corresponding tests, privacy/help/listing changes and a new package; no such change is implemented here. Do not silently change the submitted or published artifacts.

Microsoft also documents publication-to-API propagation delays and detection limits of one check per 30 minutes and ten checks per 24 hours. These are separate from our own one-day cache. [Primary API documentation](https://learn.microsoft.com/en-us/uwp/api/windows.services.store.storecontext.getappandoptionalstorepackageupdatesasync?view=winrt-26100).

Shared KB status/Store update findings, current native source and the existing diagnostic harness were consulted before this investigation. No new WoW API or gameplay behavior is involved.
