# Frozen Offhand Companion 2.1.3

These are the exact portable EXE and three-file ZIP prepared from source commit
`d2934ef802cf0c8deb62d29fd0c932658e64afa3`. The EXE is byte-identical to the
payload of Store Submission 3, package 2.1.300.0. `release.json` records the
identities and input fingerprints. No rebuild or repack was performed here.

Use `scripts/Prepare-213Publication.ps1` from a clean committed checkout to
combine these assets with the current 2.1.3 add-on. The package receipt retains
separate add-on and Companion source revisions. The top-level historical
`Companion/Offhand.exe` and `Companion/Offhand-Companion.zip` remain Beta 20.
They are not the 2.1.3 publication inputs.

Portable signing is absent. WACK/local clean scans do not imply Defender review
or certification acceptance. See the dated Microsoft submission and WACK records
under `docs`. Public Beta 20 and Revision 4 downloads must not be replaced.
