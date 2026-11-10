"""Prepare Beta 30 using its reviewed addon ZIP and frozen Companion 2.1.5.

Never builds native code, uploads assets, creates tags or publishes a release.
Rejects source, archive, receipt and inventory drift before staging anything.
"""
from pathlib import Path
import argparse
import hashlib
import json
import re
import shutil
import subprocess
import zipfile

VERSION = '2.1.5-beta.30'
ADDON_SHA = '115b377cadc6df3de9c44f89b2495b760bcb0c1df9075015af22732538f6df71'
EXE_SHA = '95811dbb7020a20e2541ae123e69fe80721c83a0fd52d0ee5557dd6d54dccc2a'
PORTABLE_SHA = '9a8ad31226c659be9dd30f626033118ede597993caf41dc138d329642a361c8f'
RECEIPT_SHA = '739348a64715893412b9af99be55b4d45f04df0a3d6e4d6637a8c4ac959852fb'
NATIVE_REVISION = '7bc07a60113c7c990067d5fd86215ace310399cc'
PORTABLE = 'Offhand-Companion-v2.1.5.zip'


def digest(data):
    return hashlib.sha256(data).hexdigest()


def require(condition, message):
    if not condition:
        raise ValueError(message)


def native_inputs(root):
    return {
        'Companion/Source/Program.cs', 'Companion/Source/LayoutDocument.cs',
        'Companion/Source/WorkspaceLayoutService.cs', 'Companion/Source/FlexibleWorkspaceEditor.cs',
        'Companion/Source/app.manifest', 'Media/offhand-logo.ico', 'Media/offhand-logo-small.png'
    }


def validate(root, native):
    prepared = root / 'Release/Prepared' / VERSION
    inventory = json.loads((prepared / 'addon.json').read_text(encoding='utf-8-sig'))
    addon = prepared / ('Offhand-v' + VERSION + '.zip')
    require(inventory['version'] == VERSION and inventory['archiveSha256'] == ADDON_SHA,
            'Addon receipt identity changed')
    require(digest(addon.read_bytes()) == ADDON_SHA, 'Reviewed addon archive changed')
    files = inventory['files']
    require(len(files) == 93, 'Unexpected addon file count')
    with zipfile.ZipFile(addon) as z:
        require(len(z.namelist()) == len(set(z.namelist())) == 93, 'Duplicate addon ZIP entry')
        require(set(z.namelist()) == set(files), 'Addon ZIP inventory differs')
        for name, expected in files.items():
            require(name.startswith('Offhand/') and '\\' not in name
                    and '..' not in name.split('/'), 'Unsafe addon path')
            rel = name[len('Offhand/'):]
            require(digest(z.read(name)) == expected, 'Addon entry changed: ' + rel)
            require(digest((root / rel).read_bytes()) == expected, 'Reviewed source drift: ' + rel)
        base = root / 'Release/Prepared/2.1.5-beta.29/Offhand-v2.1.5-beta.29.zip'
        require(digest(base.read_bytes()) ==
                '004be4e1fe35dba3bc55f6579ba7d6aa5f5676328fe9c495305f18bbdba9694e',
                'Published Beta 29 baseline changed')
        with zipfile.ZipFile(base) as old:
            require(set(old.namelist()) == set(files), 'Published runtime inventory changed')
            changed = {n for n in files if z.read(n) != old.read(n)}
            allowed = {n for n in files if n.endswith('.toc')} | {
                'Offhand/Core/HUDTransientFrames.lua', 'Offhand/CHANGELOG.md', 'Offhand/README.md'}
            require(changed == allowed, 'Unapproved release delta: ' + str(changed ^ allowed))
            require(digest(z.read('Offhand/Core/HUDTransientFrames.lua')) ==
                    '377b44efb59d5cb660cccc3c159cc2f1f3e790f48962d55e26278f7e09342ff6',
                    'Loot module differs from native-tested candidate')
            for n in allowed:
                if n.endswith('.toc'):
                    expected = old.read(n)
                    for field in ('X-Offhand-Release', 'X-Offhand-Addon-Release'):
                        expected = expected.replace(('## '+field+': beta.29').encode(),
                                                    ('## '+field+': beta.30').encode())
                    require(z.read(n) == expected, 'Unapproved manifest change: ' + n)
    # Reject added runtime files too, rather than silently omitting new source.
    actual = set()
    for folder in ('Core', 'UI', 'Locales'):
        actual.update('Offhand/' + p.relative_to(root).as_posix()
                      for p in (root / folder).rglob('*') if p.is_file())
    require(actual == {n for n in files if n.split('/')[1] in ('Core', 'UI', 'Locales')},
            'Runtime source inventory drift')
    tocs = [n for n in files if n.endswith('.toc')]
    require(len(tocs) == 6, 'Expected six manifests')
    for name in tocs:
        text = (root / name[len('Offhand/'):]).read_text(encoding='utf-8-sig')
        for field, value in {
            'Version': '2.1.5', 'X-Offhand-Release': 'beta.30',
            'X-Offhand-Addon-Release': 'beta.30', 'X-Offhand-Companion-Version': '2.1.5',
            'X-Offhand-Companion-Release': '', 'X-Offhand-Companion-Protocol': '1',
            'X-Offhand-Companion-Min-Version': '2.1.2-beta.19'
        }.items():
            require(re.search(r'(?m)^## ' + re.escape(field) + r':[ \t]*'
                              + re.escape(value) + r'[ \t]*\r?$', text), 'Manifest identity: ' + field)
    topology = (root / 'Core/CompanionTopology.lua').read_text(encoding='utf-8-sig')
    require(re.sub(r'(?m)^--[^\n]*', '', topology).strip() == 'OffhandCompanionTopology = nil',
            'Packaged topology is not inert')
    bridge = (root / 'Core/ForeverState.lua').read_text(encoding='utf-8-sig')
    require(not re.sub(r'(?s)--\[\[.*?--\]\]', '', bridge).strip(), 'Recovery bridge is not inert')

    raw = (native / 'release.json').read_bytes()
    require(digest(raw.decode('utf-8-sig').replace('\r\n', '\n').encode('utf-8')) == RECEIPT_SHA,
            'Frozen native receipt changed')
    receipt = json.loads(raw.decode('utf-8-sig'))
    for key, value in {
        'version': '2.1.5', 'fileVersion': '2.1.5.1', 'archiveName': PORTABLE,
        'companionSourceRevision': NATIVE_REVISION, 'binarySha256': EXE_SHA,
        'archiveSha256': PORTABLE_SHA
    }.items():
        require(str(receipt[key]).lower() == value.lower(), 'Native receipt identity: ' + key)
    require(digest((native / 'Offhand.exe').read_bytes()) == EXE_SHA, 'Frozen native executable changed')
    require(digest((native / PORTABLE).read_bytes()) == PORTABLE_SHA, 'Frozen portable ZIP changed')
    require({r['path'] for r in receipt['inputs']} == native_inputs(root), 'Native source inventory changed')
    for item in receipt['inputs']:
        raw = (root / item['path']).read_bytes()
        if item['normalization'] == 'CRLF-to-LF':
            raw = raw.decode('utf-8-sig').replace('\r\n', '\n').encode('utf-8')
        else:
            require(item['normalization'] == 'none', 'Unknown normalization')
        require(digest(raw) == item['sha256'].lower(), 'Frozen native source drift: ' + item['path'])
    with zipfile.ZipFile(native / PORTABLE) as z:
        require(len(z.namelist()) == 3 and set(z.namelist()) == {'LICENSE', 'README.txt', 'Offhand.exe'},
                'Portable archive boundary changed')
        require(digest(z.read('Offhand.exe')) == EXE_SHA, 'Portable EXE differs from frozen executable')
    return addon, inventory, receipt


def verified_zip(files, output):
    with zipfile.ZipFile(output, 'w') as z:
        for name, data in sorted(files.items()):
            require(not re.search(r'(^|/)(WTF|SavedVariables|\.git|tests|tools|docs)(/|$)|\.(log|bak|ini)$',
                                  name, re.I), 'Private/development entry: ' + name)
            info = zipfile.ZipInfo(name, (2026, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            z.writestr(info, data)
    with zipfile.ZipFile(output) as z:
        require(len(z.namelist()) == len(files) and set(z.namelist()) == set(files), 'Bundle inventory mismatch')
        for name, data in files.items():
            require(digest(z.read(name)) == digest(data), 'Bundle entry mismatch: ' + name)


def prepare(root, native, out):
    addon, inventory, receipt = validate(root, native)
    require(not out.exists(), 'Use a fresh publication output directory')
    # A source revision must represent the complete release subject.
    status = subprocess.check_output(['git', 'status', '--porcelain'], cwd=root, text=True)
    require(not status.strip(), 'Commit the reviewed publication source before packaging')
    revision = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip()
    out.mkdir(parents=True)
    publication = {
        'version': VERSION, 'addonVersion': VERSION, 'companionVersion': '2.1.5',
        'releaseName': 'Offhand v2.1.5 Pre-Release Beta 30', 'prerelease': True, 'draft': True,
        'state': 'prepared_not_published', 'addonSourceRevision': revision,
        'addonArchiveSha256': ADDON_SHA, 'companionSourceRevision': NATIVE_REVISION,
        'companionBinarySha256': EXE_SHA, 'companionArchiveSha256': PORTABLE_SHA,
        'addonFiles': inventory['files'], 'validation': inventory['validation'],
        'provenance': 'Locally prepared bytes; no GitHub Actions attestation is claimed.'
    }
    data = (json.dumps(publication, indent=2, sort_keys=True) + '\n').encode('utf-8')
    (out / 'publication.json').write_bytes(data)
    shutil.copy2(addon, out / addon.name)
    shutil.copy2(native / PORTABLE, out / PORTABLE)
    shutil.copy2(native / 'Offhand.exe', out / 'Offhand.exe')
    with zipfile.ZipFile(addon) as z:
        contents = {n: z.read(n) for n in z.namelist()}
    contents.update({
        'Offhand.exe': (native / 'Offhand.exe').read_bytes(),
        'COMPANION-LICENSE.txt': (root / 'Companion/LICENSE').read_bytes(),
        'README-FIRST.txt': (root / 'docs/INSTALL-2.1.5-beta.30.txt').read_bytes(),
        'PUBLICATION.json': data,
    })
    verified_zip(contents, out / ('Offhand-Complete-v' + VERSION + '.zip'))
    shutil.copy2(root / 'docs/RELEASE-CHANGELOG-BETA30.md', out / 'curseforge-changelog.md')
    assets = sorted(p for p in out.iterdir() if p.is_file())
    (out / 'checksums-sha256.txt').write_text(''.join(digest(p.read_bytes())+'  '+p.name+'\n' for p in assets),
                                            encoding='ascii')
    require(digest((out / addon.name).read_bytes()) == ADDON_SHA, 'Copied addon bytes differ')
    print('Prepared ' + VERSION + ' at ' + str(out))
    print('Source ' + revision + '; addon ' + ADDON_SHA + '; Companion 2.1.5 unchanged')


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output', type=Path)
    p.add_argument('--native-directory', type=Path)
    p.add_argument('--validate-only', action='store_true')
    args = p.parse_args()
    root = Path(__file__).resolve().parent.parent
    native = (args.native_directory or root / 'Companion/Prepared/2.1.5').resolve()
    if args.validate_only:
        validate(root, native)
        print('PASS: reviewed addon source/ZIP and exact frozen Companion receipt/source/EXE/ZIP')
    else:
        p.error('--output is required') if not args.output else prepare(root, native, args.output.resolve())


if __name__ == '__main__':
    main()
