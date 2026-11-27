"""Exercise release archive verification against a pinned Git tree."""

import hashlib
from pathlib import Path
import runpy
import subprocess
import tempfile
import unittest
import zipfile


verifier = runpy.run_path(str(Path(__file__).resolve().parents[1] / "scripts/verify-addon-archive.py"))


class VerifyAddonArchiveTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        fixture = tempfile.TemporaryDirectory()
        cls.addClassCleanup(fixture.cleanup)
        cls.root = Path(fixture.name)
        cls.files = {name: b"fixture\n" for name in verifier["ROOT_FILES"]}
        cls.files.update({
            "Core/Config.lua": b"return {}\n",
            "Bridges/DaylightUI/Core.lua": b"return {}\n",
            "Media/icon.blp": b"\x00\r\n",
            "Offhand_Placement/Before.lua": b"local _, private = ...\n",
        })
        source_files = cls.files | {"docs/QA.md": b"QA only\n", "Media/icon.png": b"source art"}
        for name, contents in source_files.items():
            path = cls.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(contents)
        verifier["git"](cls.root, "init", "-q")
        verifier["git"](cls.root, "-c", "core.autocrlf=false", "add", ".")
        verifier["git"](cls.root, "-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid",
                        "-c", "commit.gpgSign=false", "commit", "-qm", "Release source")
        verifier["git"](cls.root, "tag", "v2.1.5-beta.test")
        (cls.root / "Core/Config.lua").write_bytes(b"-- local edits after the tag\n")

    def write_archive(self, files):
        archive_path = self.root / "addon.zip"
        with zipfile.ZipFile(archive_path, "w") as archive:
            for name, contents in files.items():
                entry = name if name.startswith("Offhand_Placement/") else f"Offhand/{name}"
                archive.writestr(entry, contents)
        return archive_path

    def test_checks_tag_and_accepts_crlf_in_text(self):
        archive = self.write_archive(self.files | {"Core/Config.lua": b"return {}\r\n"})
        digest = hashlib.sha256(archive.read_bytes()).hexdigest()
        checksums = self.root / "checksums.txt"
        checksums.write_text(f"{digest.upper()}  {archive.name}\n", encoding="utf-8-sig")
        record = verifier["verify"](self.root, archive, "v2.1.5-beta.test", checksums)
        self.assertEqual(record["sha256"], digest)
        self.assertEqual(record["files"], len(self.files))
        self.assertEqual(record["revision"], verifier["git"](self.root, "rev-parse", "HEAD").decode().strip())

    def test_rejects_changed_text_and_binary(self):
        for path, contents in {"Core/Config.lua": b"return nil\n", "Media/icon.blp": b"\x00\n"}.items():
            with self.subTest(path=path), self.assertRaisesRegex(ValueError, "Archive content differs"):
                verifier["verify"](self.root, self.write_archive(self.files | {path: contents}), "HEAD")

    def test_rejects_missing_extra_and_case_colliding_files(self):
        missing = self.files.copy()
        del missing["Bridges/DaylightUI/Core.lua"]
        examples = [
            (missing, "Missing: Offhand/Bridges/DaylightUI/Core.lua"),
            (self.files | {"docs/QA.md": b"QA only\n"}, "Unexpected: Offhand/docs/QA.md"),
            (self.files | {"Core/config.lua": b"return {}\n"}, "case-colliding paths"),
        ]
        for files, error in examples:
            with self.subTest(error=error), self.assertRaisesRegex(ValueError, error):
                verifier["verify"](self.root, self.write_archive(files), "HEAD")

    def test_rejects_stale_or_duplicate_checksum_entries(self):
        archive = self.write_archive(self.files)
        checksums = self.root / "checksums.txt"
        digest = hashlib.sha256(archive.read_bytes()).hexdigest()
        for entry in (f"{'0' * 64}  {archive.name}\n", f"{digest}  {archive.name}\n" * 2):
            with self.subTest(entry=entry), self.assertRaisesRegex(ValueError, "one matching SHA-256 entry"):
                checksums.write_text(entry, encoding="utf-8")
                verifier["verify"](self.root, archive, "HEAD", checksums)


if __name__ == "__main__":
    unittest.main()
