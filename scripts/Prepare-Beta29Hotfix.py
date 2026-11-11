"""Freeze the reviewed addon-only hotfix; do not publish or change the checkout.

The input is the exact private QA14 archive and its associated test subject.
Retail friendly-name changes are deferred to the published beta28 behavior.
Run from the repository root. Use a fresh --output directory.
"""
from pathlib import Path
import argparse
import difflib
import hashlib
import json
import re
import shutil
import subprocess
import zipfile


def sha(data):
    return hashlib.sha256(data).hexdigest()


def between(text, start, end):
    a = text.index(start)
    return text[a:text.index(end, a)]


def replace_once(text, old, new):
    assert text.count(old) == 1, f"Expected exactly one reviewed segment: {old[:80]}"
    return text.replace(old, new, 1)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    base = root / 'dist/discord-qa-20261110-14/daylight-restoration-candidate'
    archive = base / 'Offhand-discord-private-QA.zip'
    expected = 'a6428faafef3b1b8ab1e2e02466d3b1233dc77d830f62190673db2258087868b'
    assert sha(archive.read_bytes()) == expected, 'Accepted private archive changed'
    receipt = json.loads((base / 'verification.json').read_text(encoding='utf-8'))
    out = Path(args.output).resolve()
    assert not out.exists(), 'Use a fresh output directory'
    subject = out / 'subject'
    shutil.copytree(base / 'validated-subject', subject)
    with zipfile.ZipFile(archive) as accepted:
        assert set(accepted.namelist()) == set(receipt['files'])
        for name, digest in receipt['files'].items():
            assert sha(accepted.read(name)) == digest, name
            if name.startswith('Offhand/'):
                assert sha((subject / name[8:]).read_bytes()) == digest, name

    def published(rel):
        return subprocess.check_output(
            ['git', 'show', f'v2.1.5-beta.28:{rel}'], cwd=root
        ).decode('utf-8').replace('\r\n', '\n')

    # Defer only the Retail preference change, retaining unrelated scale fixes.
    vp = subject / 'Core/Viewport.lua'
    text, old = vp.read_text(encoding='utf-8-sig'), published('Core/Viewport.lua')
    text = replace_once(text, between(text, 'local function RestoreLegacyFriendlyPlayerNames',
                                     'local function ValidPositive'),
                        between(old, 'local function ManageFriendlyPlayerNames',
                                'local function ValidPositive'))
    text = replace_once(text, between(text, '    -- Scaling does not own name/nameplate',
                                     '    if not db.enabled or'),
                        between(old, '    -- Friendly Retail plates', '    if not db.enabled or'))
    hook = between(old, '            if event == "CVAR_UPDATE" and (cvar == "unitnamefriendlyplayername"',
                   '            if event ~= "CVAR_UPDATE"')
    text = replace_once(text, '            if event ~= "CVAR_UPDATE"',
                        hook + '            if event ~= "CVAR_UPDATE"')
    vp.write_text(text, encoding='utf-8', newline='\n')
    init = subject / 'Core/Init.lua'
    text, old = init.read_text(encoding='utf-8-sig'), published('Core/Init.lua')
    block = between(old, '        if db.originalFriendlyPlayerName ~= nil', '    end\n\n    -- A disabled profile')
    text = replace_once(text, '    end\n\n    -- A disabled profile',
                        block + '    end\n\n    -- A disabled profile')
    init.write_text(text, encoding='utf-8', newline='\n')

    # Keep the published preference contract in the mixed geometry suite while
    # retaining the new portrait/4K regression in the first part of that suite.
    geom = subject / 'tests/geometry.lua'
    text, old = geom.read_text(encoding='utf-8-sig'), published('tests/geometry.lua')
    for start, end in [
        ('    -- Scaling must preserve player visibility', '    if name=="nameplateShowFriends"'),
        ('near(friendlyPlayerNames,0)\nassert(addon.db.originalFriendlyPlayerName==nil', 'local expectedHUDScale='),
        ('near(friendlyPlayerNames,1)\nassert(#friendlyPlayerNameWrites==1,\n    "disabling', 'near(nameplateWidth,300)'),
    ]:
        old_start = {
            '    -- Scaling must preserve player visibility': '    -- Retail 12.1 can render friendly player plates',
            'near(friendlyPlayerNames,0)\nassert(addon.db.originalFriendlyPlayerName==nil': 'near(friendlyPlayerNames,1)\nnear(addon.db.originalFriendlyPlayerName,0)',
            'near(friendlyPlayerNames,1)\nassert(#friendlyPlayerNameWrites==1,\n    "disabling': 'near(friendlyPlayerNames,0)\nassert(friendlyPlayerNameWrites[#friendlyPlayerNameWrites]',
        }[start]
        text = replace_once(text, between(text, start, end), between(old, old_start, end))
    geom.write_text(text, encoding='utf-8', newline='\n')
    deferred = out / 'deferred'
    deferred.mkdir()
    shutil.move(subject / 'tests/friendly-name-preferences.lua', deferred / 'friendly-name-preferences.lua')

    for toc in subject.glob('*.toc'):
        text = toc.read_text(encoding='utf-8-sig')
        assert text.count('beta.28') == 2, toc.name
        toc.write_text(text.replace('beta.28', 'beta.29'), encoding='utf-8', newline='\n')
    test = subject / 'tests/manifests.lua'
    test.write_text(test.read_text(encoding='utf-8-sig').replace('beta%.28', 'beta%.29').replace('Beta 28', 'Beta 29'),
                    encoding='utf-8', newline='\n')
    readme = subject / 'README.md'
    text = readme.read_text(encoding='utf-8-sig').replace('Pre-Release Beta 28', 'Pre-Release Beta 29', 1)
    readme.write_text(text, encoding='utf-8', newline='\n')
    notes = (root / 'docs/CURSEFORGE-BETA29-NOTES.md').read_text(encoding='utf-8')
    (out / 'curseforge-changelog.md').write_text(notes, encoding='utf-8', newline='\n')
    changelog = subject / 'CHANGELOG.md'
    text = changelog.read_text(encoding='utf-8-sig')
    previous = text[text.index('## [2.1.5-beta.28]'):]
    changelog.write_text('# Changelog\n\n## [2.1.5-beta.29] - 2026-11-10\n\n' +
                         notes[notes.index('This is an addon-only'):]+ '\n' + previous,
                         encoding='utf-8', newline='\n')

    diffs = []
    for rel in ('Core/Viewport.lua', 'Core/Init.lua', 'tests/geometry.lua', 'tests/manifests.lua'):
        diffs.extend(difflib.unified_diff((base / 'validated-subject' / rel).read_text(encoding='utf-8-sig').splitlines(True),
                                        (subject / rel).read_text(encoding='utf-8-sig').splitlines(True),
                                        fromfile='qa14/'+rel, tofile='beta29/'+rel))
    (out / 'scope-delta.diff').write_text(''.join(diffs), encoding='utf-8')
    failures, results = [], []
    for test in sorted((subject / 'tests').glob('*.lua')):
        result = subprocess.run(['lua', str(test)], cwd=subject, capture_output=True, text=True, timeout=60)
        results.append(f'{test.name}: exit={result.returncode}\n{result.stdout}{result.stderr}')
        if result.returncode:
            failures.append(test.name)
    (out / 'lua-validation.txt').write_text('\n'.join(results), encoding='utf-8')
    assert not failures, failures

    # Match the addon-only publication boundary: runtime, six manifests, BLP
    # artwork, bindings, license and player docs. Never ship the subject tree.
    paths = sorted(p for p in subject.rglob('*') if p.is_file() and (
        p.relative_to(subject).parts[0] in ('Core', 'UI', 'Locales') or
        (p.parent == subject / 'Media' and p.suffix == '.blp') or
        (p.parent == subject and (p.suffix == '.toc' or p.name in
                                 ('Bindings.xml', 'LICENSE', 'README.md', 'CHANGELOG.md')))))
    topology = (subject / 'Core/CompanionTopology.lua').read_text(encoding='utf-8-sig')
    assert re.sub(r'(?m)^--[^\n]*', '', topology).strip() == 'OffhandCompanionTopology = nil'
    assert not re.sub(r'(?s)--\[\[.*?--\]\]', '', (subject / 'Core/ForeverState.lua').read_text(encoding='utf-8-sig')).strip()
    output_zip = out / 'Offhand-v2.1.5-beta.29.zip'
    files = {}
    with zipfile.ZipFile(output_zip, 'w', compression=zipfile.ZIP_DEFLATED) as dest:
        for p in paths:
            rel = 'Offhand/' + p.relative_to(subject).as_posix()
            data = p.read_bytes()
            info = zipfile.ZipInfo(rel, (2026, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            dest.writestr(info, data)
            files[rel] = sha(data)
    with zipfile.ZipFile(output_zip) as check:
        assert len(check.namelist()) == len(files) == len(set(check.namelist()))
        for name, digest in files.items():
            assert sha(check.read(name)) == digest, name
    result = dict(version='2.1.5-beta.29', releaseType='Beta', addonOnly=True, published=False,
                  baseArchiveSha256=expected, archiveSha256=sha(output_zip.read_bytes()),
                  luaSuites=len(results), zipEntries=len(files), files=files,
                  deferred=['Retail friendly-name preference correction (OH-RET-002)'],
                  acceptedLimitations=['Actual simultaneous loot-roll and combat lifecycle not tested locally; included by explicit owner direction.'],
                  sourceRevision=subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip())
    (out / 'release-manifest.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
    (out / 'checksums-sha256.txt').write_text(result['archiveSha256']+'  '+output_zip.name+'\n', encoding='utf-8')
    print(json.dumps({k:v for k,v in result.items() if k!='files'}, indent=2))


if __name__ == '__main__':
    main()
