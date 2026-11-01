# Offhand addon development workflow

This document defines how addon work moves from an individual change to an
Offhand release without creating separate permanent codebases for each World of
Warcraft client.

## Branch model

| Branch | Purpose |
| --- | --- |
| `main` | Current released source and the frozen public Companion |
| `addon/develop` | Reviewed addon integration for the next release |
| `addon/shared/<issue>-<description>` | Short-lived work affecting multiple clients |
| `addon/retail/<issue>-<description>` | Short-lived Retail or Mainline work |
| `addon/forever/<issue>-<description>` | Short-lived Forever work |
| `addon/classic/<issue>-<description>` | Short-lived Classic or Anniversary work |
| `addon/vanilla/<issue>-<description>` | Short-lived Vanilla work |
| `addon/wrath335a/<issue>-<description>` | Short-lived Wrath 3.3.5a work |
| `addon/rc/<version>` | Optional temporary release-candidate freeze |

Do not create permanent client branches merely because a client needs a
different TOC, API adapter, or protected-UI boundary. Offhand shares most of its
runtime across clients, so permanent client branches would make compatible fixes
easy to omit. Prefer capability detection and isolate the client-specific
behavior inside the shared source.

A permanent client branch is justified only if that client becomes an
independently released product with a materially different codebase and its own
version, packaging, and maintenance policy.

## Integration and promotion

1. Branch individual work from `addon/develop` using the appropriate scope
   prefix.
2. Open the pull request against `addon/develop`. Keep incomplete work as a
   draft.
3. Run all repository regression suites and validate every supported manifest.
4. Record affected clients and the highest evidence level actually reached.
5. A source-reviewed change may enter `addon/develop` with live testing still
   pending only when that gap is explicit in the issue matrix and pull request.
6. Regularly merge `main` into `addon/develop` through a pull request. Do not
   merge `addon/develop` into `main` as routine synchronization.
7. Promote the tested release set to `main` through one explicit release pull
   request. Promotion requires the applicable live, taint, persistence,
   packaging, and rollback evidence.

Addon work must not modify or rebuild `Companion/Offhand.exe`. Ordinary addon
branches retain the exact frozen executable and its approved SHA-256. Companion
changes use `companion/develop` and the Companion release workflow.

## Evidence states

Use these terms consistently in issues, pull requests, QA notes, and release
decisions:

| State | Meaning |
| --- | --- |
| Implemented | The source contains the intended change |
| Static validated | Load order, manifests, paths, and syntax passed |
| Automated validated | Relevant simulated regression suites passed |
| Live pending | Required behavior has not yet been observed in the target client |
| Live verified | The intended behavior was observed in the named client and configuration |
| Candidate verified | The packaged candidate matches the tested source and expected contents |
| Released | The change is present in an identified published version |

Never use `fixed` by itself when live or packaged verification is still
pending. State the evidence level and remaining gate instead.

## Tracking requirements

Every durable issue row must identify:

- Client family and observed build when known.
- Source branch or pull request containing the change.
- Static and automated validation results.
- Live client result or a precise pending test.
- Intended addon release.
- Packaged candidate and published release when those stages are reached.

Update the summary matrix in `docs/ISSUES.md` when evidence or release state
changes. The detailed issue section remains the authority for reproduction,
safety boundaries, and test procedure.
