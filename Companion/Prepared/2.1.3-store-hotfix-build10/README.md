# Companion 2.1.3 Store hotfix, build 2.1.3.10

The frozen executable in this directory is the Store settings-persistence
hotfix. Package it with Store version **2.1.301.0** and the existing assigned
identity/publisher. The submission MSIX SHA256 is recorded in release.json.

Runtime source is commit a9a5d15e20a5506ab51382eb86c92fda26ad6c90.
An isolated MSIX registration/upgrade used byte-identical baseline and hotfix
executables with a distinct unsigned test identity. Legacy import, repeated
saves, relaunch, Unicode/unknown fields, lock failures and retry passed. The
real Store installation and its preferences were unchanged, and the test
package was removed. This does not establish affected-machine reproduction or
an upgrade under the production package identity.

WACK overall PASS, all 13 required tests passed. One optional blocked-executable
finding was reviewed and retained: existing user-initiated URI Process.Start
calls and CsI bytes within the unchanged icon PNG. Local Defender scans of the
EXE, candidate ZIP and submission MSIX found no threats. No Microsoft AV review
determination is implied.

Original 2.1.3 and Beta20 archives remain frozen. The source add-on keeps its
Beta27 version and protocol. See the dated incident record for evidence and
the subsequent Store submission status.
