# Offhand 2.1.3 Beta 7 candidate

Historical preparation, superseded by the clean
[2.1.3 Store update candidate](COMPANION-2.1.3-STORE-PREPARATION.md). The Beta 7
samples were not submitted to Microsoft and should not be used for the new review.

Prepared 2026-11-07. Companion and add-on now use the same clean version name:

| Component | Display/release version | Additional identity |
| --- | --- | --- |
| Companion | 2.1.3 Beta 7 / 2.1.3-beta.7 | File and manifest 2.1.3.8 |
| Add-on, all six manifests | 2.1.3 Beta 7 / 2.1.3-beta.7 | Protocol 1, topology schemas 1/2/3 |

The file version advances beyond the previous Beta 6 file version 2.1.3.7.
Historical experiment identities are retained in their separate conditional
builds. The ordinary candidate is not built with experiment or RDP-only flags.

This is an unpublished candidate, not an official release or Store update.
Microsoft review has not been requested or completed for these new hashes.
The prepared Beta 6 review samples are superseded. Published Test 3 Revision 4
and the canonical Beta 20 EXE/ZIP remain unchanged.

## Matching add-on

The runtime basis is the reconciled Revision 4 workspace add-on, including
Flexible Layout, named workspace profiles, supported-panel routing, independent
region themes and installed background-library support. The candidate metadata
now names the matching Companion rather than the frozen Beta 20 recommendation.
The existing minimum Companion version and schema negotiation remain intact;
the version rename alone does not require breaking older ordinary-span support.

Use the included Companion for this candidate. Versioned portable URLs refer to
the intended future `v2.1.3-beta.7` release and become usable only after publication.
The existing Microsoft Store link does not represent this unpublished build.

## Install or update

1. Close WoW and exit Companion through the tray menu. Back up the installed
   Offhand folder, Offhand SavedVariables and Companion preferences.
2. Extract `Offhand-Complete-v2.1.3-beta.7.zip` to a writable directory. Copy its
   `Offhand` folder into your client `Interface/AddOns`, without extra nesting.
3. Run the included `Offhand.exe`. Start WoW in ordinary Windowed mode with
   Offhand enabled. First-time users can run `/offhand guide` and Use Companion.
4. Review Mainhand and Workspace layout. Save changes, click Span WoW Now and
   type `/reload` once in WoW. The new notification makes that last step explicit.
5. Restore Window undoes the active span. Workspace layout > Use standard
   display layout disables custom regions. Retain backups for a full rollback.

Verify Beta 7 in both Companion's header/title and the add-on's version display.
No Test 3 revision suffix is stamped into the candidate add-on titles.
The package receipt and checksums identify the exact source and files.

## Review and validation boundary

Rebuild once from committed source and reuse its exact executable/runtime ZIP
in both the paired package and the refreshed Defender preparation folder.
The minimal runtime ZIP contains only LICENSE, Offhand.exe and README.txt.
The complete paired package is for testing, not the minimal Microsoft sample.

The review process is described in
[Defender preparation](COMPANION-DEFENDER-PREPARATION-20261107.md). That initial
Beta 6 sample record is historical; the Beta 7 bundle has its own hashes,
receipts and empty submission record. No detection or Microsoft approval is
invented. Any later rebuild, signing or archive repack needs new sample evidence.

The version changes are validated by manifest, Lua, Companion identity/bridge,
preferences, dashboard and relevant compatibility checks. Physical hotplug,
mixed DPI, three physical displays, Wine, full live WoW and protected-action
acceptance remain separate from static/simulated checks and local AV scans.
