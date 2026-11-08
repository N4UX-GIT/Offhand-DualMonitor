# Private Discord test15, 7 November 2026

Includes all test14 candidates and the
[native bag follow-up](BAG-COMBAT-FOLLOWUP-20261107.md).

- Hide close buttons now discovers additional separate native bags without
  requiring saved positions. Mainhand buttons remain reversible and native.
- Bag placement/recovery and chrome wait for both player combat and lockdown to
  clear. Native opener fallbacks recheck combat and preserve saved intent.
- In-combat native far-edge placement and X redraws are still limitations.
  The new Lua error has no supplied stack and has not been reproduced locally.

All 99 suites and six manifests pass in source and extracted runtime. No new
live run was attempted; the previous test14 attempt required sign-in before
addon loading. Combat, protected item actions, reporter topology and taint safety
remain pending. See the follow-up for the manual retest matrix.

Private version: 2.1.2-beta.26-forever-discord.test15. Canonical source TOCs stay
public Beta26. Complete retains the frozen public Beta20 Companion. Runtime ZIPs
exclude tests, reference caches, private QA, logs and saved state. Installed
generated CompanionTopology.lua and ForeverState.lua are preserved. Test14 ZIPs
remain unchanged for rollback. No publication or Discord posting is performed.
