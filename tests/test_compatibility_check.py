import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("compatibility_check", Path(__file__).resolve().parents[1] / "scripts/check-compatibility.py")
check = importlib.util.module_from_spec(spec)
spec.loader.exec_module(check)


class CompatibilityChecks(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        (self.root / "Core").mkdir()
        (self.root / "Core/Test.lua").write_text("return true\n")
        (self.root / "Evidence.md").write_text("Observed live behavior")
        self.toc = self.root / "Offhand_Forever.toc"

    def test_shared_file_can_load_once_per_client_manifest(self):
        self.toc.write_text("## Interface: 16001\nCore\\Test.lua\n")
        other = self.root / "Offhand_Mainline.toc"
        other.write_text("Core/Test.lua\n")
        self.assertEqual(check.manifest_files(self.root, self.toc), check.manifest_files(self.root, other))

    def test_duplicate_toc_paths_are_rejected_after_normalization(self):
        self.toc.write_text("Core/Test.lua\nCore\\.\\Test.lua\n")
        with self.assertRaisesRegex(ValueError, "duplicate runtime load"):
            check.manifest_files(self.root, self.toc)

    def test_nested_xml_cannot_load_a_script_twice(self):
        (self.root / "Root.xml").write_text('<Ui xmlns="http://www.blizzard.com/wow/ui/"><Script file="Core/Test.lua"/></Ui>')
        self.toc.write_text("Root.xml\nCore/Test.lua\n")
        with self.assertRaisesRegex(ValueError, "duplicate runtime load"):
            check.manifest_files(self.root, self.toc)

    def test_recursive_xml_is_rejected(self):
        (self.root / "Root.xml").write_text('<Ui><Include file="Root.xml"/></Ui>')
        self.toc.write_text("Root.xml\n")
        with self.assertRaisesRegex(ValueError, "duplicate runtime load"):
            check.manifest_files(self.root, self.toc)

    def test_missing_and_external_load_paths_are_rejected(self):
        for name in ("Missing.lua", "../Outside.lua"):
            self.toc.write_text(name)
            with self.assertRaisesRegex(ValueError, "Missing or external"):
                check.manifest_files(self.root, self.toc)

    def test_line_endings_do_not_invalidate_source_evidence(self):
        self.assertEqual(check.source_hash(b"return true\n"), check.source_hash(b"return true\r\n"))

    def test_source_change_requires_new_live_evidence(self):
        receipt = {"schema": 1, "hash_mode": "utf8-lf", "id": "test", "client": "Forever 70959", "scope": "test",
                   "cases": ["escape"], "evidence": "Evidence.md",
                   "source_fingerprints": {"Core/Test.lua": check.source_hash(b"return true\n")}}
        self.assertFalse(check.live_status(self.root, receipt)["retest_required"])
        (self.root / "Core/Test.lua").write_text("return false\n")
        status = check.live_status(self.root, receipt)
        self.assertTrue(status["retest_required"])
        self.assertEqual(status["changed_files"], ["Core/Test.lua"])

    def test_empty_receipt_cannot_claim_live_coverage(self):
        with self.assertRaises(ValueError):
            check.live_status(self.root, {"schema": 1, "hash_mode": "utf8-lf", "source_fingerprints": {}})

    def test_workspace_restart_receipt_tracks_logout_login_and_panel_restore(self):
        path = check.ROOT / "tests/compatibility/forever-workspace-restart.json"
        receipt = json.loads(path.read_text(encoding="utf-8"))
        self.assertEqual(receipt["id"], "forever-workspace-restart")
        essential = {"Core/Init.lua", "Core/Config.lua", "Core/Viewport.lua", "Core/Canvas.lua",
                     "Core/CanvasPanelPlacement.lua", "Core/CanvasPersistence.lua",
                     "Core/CanvasBackpackState.lua", "Core/CanvasForeverBags.lua", "Core/CanvasForeverMap.lua"}
        self.assertFalse(essential.difference(receipt["source_fingerprints"]))

    def test_missing_evidence_cannot_claim_live_coverage(self):
        receipt = {"schema": 1, "hash_mode": "utf8-lf", "id": "test", "client": "Forever 70959", "scope": "test",
                   "cases": ["escape"], "evidence": "Missing.md",
                   "source_fingerprints": {"Core/Test.lua": check.source_hash(b"return true\n")}}
        with self.assertRaisesRegex(ValueError, "Missing or external"):
            check.live_status(self.root, receipt)

    def test_installed_comparison_excludes_only_known_generated_files(self):
        target = self.root / "installed"
        (target / "Core").mkdir(parents=True)
        source = self.root / "Core/Test.lua"
        (target / "Core/Test.lua").write_bytes(source.read_bytes())
        generated = self.root / "Core/ForeverState.lua"
        generated.write_text("generated")
        self.assertEqual(check.installed_differences(self.root, target, {source, generated}), [])
        (target / "Core/Test.lua").write_text("different")
        self.assertEqual(check.installed_differences(self.root, target, {source, generated}), ["Core/Test.lua"])


if __name__ == "__main__":
    unittest.main()
