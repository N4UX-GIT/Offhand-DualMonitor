"""Exercise the production Beta 29 publisher's drift and release safeguards."""
from pathlib import Path
import importlib.util
import io
import json
import shutil
import subprocess
import unittest
import urllib.error
import uuid
import zipfile
from unittest.mock import patch

ROOT = Path(__file__).resolve().parent.parent


def module(name, file):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'scripts' / file)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


publication = module('beta29_publication', 'Prepare-Beta29Publication.py')
guard = module('beta29_guard', 'Assert-Beta29Draft.py')


class Publication(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # Keep fixtures under ignored dist for inspection, without recursive deletion.
        cls.fixture = ROOT / 'dist' / ('publication-beta29-test-' + uuid.uuid4().hex)
        cls.fixture.mkdir(parents=True)
        receipt = ROOT / 'Release/Prepared/2.1.5-beta.29/addon.json'
        files = json.loads(receipt.read_text(encoding='utf-8-sig'))['files']
        paths = [n[len('Offhand/'):] for n in files]
        paths += ['Release/Prepared/2.1.5-beta.29/addon.json',
                  'Release/Prepared/2.1.5-beta.29/Offhand-v2.1.5-beta.29.zip']
        paths += ['Companion/Prepared/2.1.5/' + n
                  for n in ('Offhand.exe', publication.PORTABLE, 'release.json')]
        for rel in set(paths):
            dest = cls.fixture / rel
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / rel, dest)
        for rel in publication.native_inputs(ROOT):
            dest = cls.fixture / rel
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes(subprocess.check_output(
                ['git', 'show', f'{publication.NATIVE_REVISION}:{rel}'], cwd=ROOT))
        # Historical Beta 29 tests use its immutable product bytes.
        with zipfile.ZipFile(ROOT / 'Release/Prepared/2.1.5-beta.29/Offhand-v2.1.5-beta.29.zip') as z:
            for name in files:
                (cls.fixture / name[len('Offhand/'):]).write_bytes(z.read(name))
        cls.native = cls.fixture / 'Companion/Prepared/2.1.5'

    def test_valid_exact_subject(self):
        publication.validate(self.fixture, self.native)

    def test_drift_rejected(self):
        for rel in ('Core/Viewport.lua', 'Release/Prepared/2.1.5-beta.29/Offhand-v2.1.5-beta.29.zip',
                    'Companion/Prepared/2.1.5/Offhand.exe',
                    'Companion/Prepared/2.1.5/' + publication.PORTABLE,
                    'Companion/Prepared/2.1.5/release.json', 'Companion/Source/Program.cs'):
            with self.subTest(path=rel):
                p = self.fixture / rel
                original = p.read_bytes()
                try:
                    p.write_bytes(original + b'changed')
                    with self.assertRaises((ValueError, json.JSONDecodeError)):
                        publication.validate(self.fixture, self.native)
                finally:
                    p.write_bytes(original)

    def test_added_runtime_file_rejected(self):
        p = self.fixture / 'Core/Unexpected.lua'
        p.write_text('-- unreviewed source\n', encoding='utf-8')
        try:
            with self.assertRaisesRegex(ValueError, 'inventory drift'):
                publication.validate(self.fixture, self.native)
        finally:
            # Preserve the fixture evidence outside the product tree.
            p.rename(self.fixture / 'Unexpected.lua.fixture')

    def test_bundle_entry_boundary(self):
        output = self.fixture / 'boundary-test.zip'
        with self.assertRaisesRegex(ValueError, 'Private/development'):
            publication.verified_zip({'Offhand/WTF/SavedVariables.lua': b'private'}, output)
        publication.verified_zip({'Offhand/Core/Example.lua': b'-- known bytes'}, output)

    def test_workflow_lanes(self):
        text = (ROOT / '.github/workflows/release.yml').read_text(encoding='utf-8-sig')
        old = text.split('\n  prepare-215:\n')[1].split('\n  prepare-215-beta29:\n')[0]
        self.assertIn('Stage Pre-Release Beta 28', old)
        self.assertIn('Stage Companion 2.1.5 separately', old)
        lane = text.split('\n  prepare-215-beta29:\n')[1]
        self.assertIn("github.ref_name == 'v2.1.5-beta.29'", lane)
        self.assertIn('draft: true', lane)
        self.assertIn('prerelease: true', lane)
        self.assertIn('make_latest: false', lane)
        self.assertIn('Assert-Beta29Draft.py', lane)
        self.assertNotIn('Restore-FrozenCompanion.ps1', lane)
        self.assertIn("github.ref_name != 'v2.1.5-beta.29'", text.split('\n  prepare-213:')[0])


class DraftGuard(unittest.TestCase):
    def test_draft_allowed(self):
        body = io.BytesIO(json.dumps({'tag_name': 'v2.1.5-beta.29', 'draft': True}).encode())
        with patch.object(guard.urllib.request, 'urlopen', return_value=body):
            guard.check('N4UX-GIT/Offhand-DualMonitor', 'fixture-token')

    def test_published_rejected(self):
        body = io.BytesIO(json.dumps({'tag_name': 'v2.1.5-beta.29', 'draft': False}).encode())
        with patch.object(guard.urllib.request, 'urlopen', return_value=body):
            with self.assertRaisesRegex(ValueError, 'Published'):
                guard.check('N4UX-GIT/Offhand-DualMonitor', 'fixture-token')

    def test_missing_allowed_auth_error_rejected(self):
        for status in (404, 401):
            error = urllib.error.HTTPError('https://api.github.com/', status, 'fixture', {}, None)
            with patch.object(guard.urllib.request, 'urlopen', side_effect=error):
                if status == 404:
                    guard.check('N4UX-GIT/Offhand-DualMonitor', 'fixture-token')
                else:
                    with self.assertRaisesRegex(RuntimeError, 'HTTP 401'):
                        guard.check('N4UX-GIT/Offhand-DualMonitor', 'fixture-token')


if __name__ == '__main__':
    unittest.main(verbosity=2)
