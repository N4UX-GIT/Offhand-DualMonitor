# Companion 2.1.7 local Store update test

The owner approved reducing quiet Store checks to every six hours and showing the last-check time. This is a next-version local test, not a Store/GitHub release. Production source identifies 2.1.7, file 2.1.7.1, future MSIX 2.1.700.0. Existing 2.1.6 submission artifacts and published portable/addon assets stay unchanged.

## Behavior

The startup delay remains 30 seconds. Successful, failed and interrupted attempts retain an exclusive persisted six-hour allowance across restarts and build changes. Existing daily cache files need no reset: attempts older than six hours become eligible. Cached badges expire at six hours; a new build clears an old badge without resetting its attempt throttle. Store-managed download/install behavior is unchanged.

Advanced displays a wrapped Store status and timestamp below the existing advanced controls. The footer button/tray tooltips expose the same timestamp without adding a caption beneath the action buttons. Successful results say Last checked. Unavailable, incomplete, expired or previous-build results use Last attempted; absent/corrupt timestamps never invent a time. Display uses the Windows local culture/timezone. Help, privacy and the Store-specific tutorial explain six hours. Portable GitHub checks remain manual; a real portable installation does not show Store-only details.

The local launcher loads a hash-pinned production payload and substitutes only simulated Store responses with isolated configuration/cache under LocalTestData. Available, NoUpdate, Unavailable and Timeout scenarios use the normal scheduler, result rendering and persisted cache. Monitoring, game controls and tray game actions are disabled. Setup/Advanced, Help, disclosure toggles, tray/minimize/exit and the Store page action remain available. No actual Store availability request, package download or installation is performed automatically. The installed Companion can remain open.

## Checks

The update suite covers the exact six-hour boundary, restart/failure throttling, migration of a seven-hour-old daily cache, stale/late completions, corrupt/oversized cache, exclusive locks, local timestamp wording, cancellation, OS metadata binding, actual timer rearming and scaled Advanced/tooltip accessibility. Production and preview variants run on x64/x86. The existing preference/layout matrix covers 100%-200%, enlarged controls, stable Show/Hide, tab symmetry and tutorial lifecycle. The layout fixture now identifies controls without assuming the advanced card contains only one label.

This source change uses no new game API. Shared KB status/search, the prior actual Available response and Microsoft primary API documentation were consulted. Six hours remains below Microsoft's documented detection limits of one request per 30 minutes and ten per day. [API reference](https://learn.microsoft.com/en-us/uwp/api/windows.services.store.storecontext.getappandoptionalstorepackageupdatesasync?view=winrt-26100).

Exact build, local UI review and preservation results are appended after preparing the package. Store-associated 2.1.7 service/upgrade acceptance, WACK and fresh Store delivery remain later release checks. The simulation does not establish those outcomes. Current Beta 28 remains compatible through the unchanged protocol; no addon changes or public download references are advanced.
