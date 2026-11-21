"""Prepare the reviewed Beta 31 addon and frozen Companion 2.1.5."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
from xml.etree import ElementTree
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo

ROOT = Path(__file__).resolve().parent.parent
VERSION = '2.1.5-beta.31'
BASELINE_SHA = '4d64f8fa19ae6055c99af75a3346ad2701d76576a664cd8520cd044a255050ed'
EXE_SHA = '95811dbb7020a20e2541ae123e69fe80721c83a0fd52d0ee5557dd6d54dccc2a'
PORTABLE_SHA = '9a8ad31226c659be9dd30f626033118ede597993caf41dc138d329642a361c8f'
PORTABLE = 'Offhand-Companion-v2.1.5.zip'
REVIEWED_MODULES = {
    'Core/CanvasMapPresentation.lua': '70b3f268df2c8b95ebe5dc1222cc690608bf4320b40dcc01ec3b87c3d026ce18',
    'Core/CanvasPanelLifecycle.lua': 'eff59e78693f6a3b2ddae9c43e58e07c379a3183b749ee7714222c2ef99225fb',
    'Core/MainhandGamepad.lua': 'a59dd0eb2002c5707b59c5be0378229c29076a2394d099bd016f26b2c2d72eff',
    'Core/PopupBounds.lua': '1e89e82161c5fd8bf475d0f0c56c998c7b2627d5a6e9700786c2f8cc4a5b1843',
    'Core/Init.lua': '83d5f35608c0801b58646fd1ebe7eb6a904218be17178d3bec015ec8cbee9719',
    'UI/Controls.lua': '3daf302745d34f97c0dba42e8be57d314437968f58ee5e184f6f2639398e89f4',
    'UI/SetupVisuals.lua': 'd91e8a6cbda38f89dc5cd849fe79db258bf9e7c1393e58c7ccc649bc9382fc0c',
    'UI/Wizard.lua': '15a6282e701a719eeb280c1179fe5774d9ccf5ca39f7d619357df37abcaf0be3',
}


def digest(data):
    return hashlib.sha256(data).hexdigest()


def require(condition, message):
    if not condition:
        raise ValueError(message)


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT, text=True).strip()


def write_zip(path, files):
    with ZipFile(path, 'x') as archive:
        for name, data in sorted(files.items()):
            info = ZipInfo(name, (2026, 1, 1, 0, 0, 0))
            archive.writestr(info, data, compress_type=ZIP_DEFLATED)
    with ZipFile(path) as archive:
        require(archive.namelist() == sorted(files), 'Archive inventory mismatch')
        for name, data in files.items():
            require(archive.read(name) == data, 'Archive contents mismatch: ' + name)


def addon_contents():
    baseline = ROOT / 'Release/Prepared/2.1.5-beta.30/Offhand-v2.1.5-beta.30.zip'
    require(digest(baseline.read_bytes()) == BASELINE_SHA, 'Published Beta 30 archive changed')
    with ZipFile(baseline) as archive:
        old = {name.removeprefix('Offhand/'): archive.read(name) for name in archive.namelist()}
    tocs = {p.name for p in ROOT.glob('Offhand*.toc')}
    require(len(tocs) == 6, 'Expected six addon manifests')
    sources = tocs | {'Bindings.xml', 'LICENSE', 'README.md', 'CHANGELOG.md'}
    for folder in ('Core', 'UI', 'Locales'):
        sources.update(p.relative_to(ROOT).as_posix() for p in (ROOT / folder).rglob('*') if p.is_file())
    sources.update(p.relative_to(ROOT).as_posix() for p in (ROOT / 'Media').glob('*.blp'))
    require(sources == set(old), 'Addon inventory differs from the published baseline')
    files = {name: (ROOT / name).read_bytes() for name in sources}
    changed = {name for name in files if files[name] != old[name]}
    expected = tocs | set(REVIEWED_MODULES) | {'README.md', 'CHANGELOG.md'}
    require(changed == expected, 'Unexpected addon delta: ' + ', '.join(sorted(changed ^ expected)))
    for name, sha in REVIEWED_MODULES.items():
        require(digest(files[name]) == sha, 'Reviewed addon module changed: ' + name)

    entries = set()
    for name in sorted(tocs):
        expected_toc = old[name]
        for field in (b'X-Offhand-Release', b'X-Offhand-Addon-Release'):
            before = b'## ' + field + b': beta.30'
            require(before in expected_toc, 'Missing beta label: ' + name)
            expected_toc = expected_toc.replace(before, before.replace(b'beta.30', b'beta.31'))
        require(files[name] == expected_toc, 'Unexpected manifest change: ' + name)
        entries.update(line.strip().replace('\\', '/') for line in files[name].decode('utf-8-sig').splitlines()
                       if line.strip() and not line.lstrip().startswith('#'))
    require(entries <= files.keys(), 'Missing manifest files: ' + ', '.join(sorted(entries - files.keys())))
    for name in sorted(entries):
        if name.endswith('.lua'):
            subprocess.run(['lua', '-e', 'assert(loadfile(os.getenv("OFFHAND_RELEASE_LUA_FILE")))'],
                           cwd=ROOT, env={**os.environ, 'OFFHAND_RELEASE_LUA_FILE': name}, check=True)
        elif name.endswith('.xml'):
            ElementTree.fromstring(files[name])
    return {'Offhand/' + name: data for name, data in files.items()}


def prepare(out):
    require(not git('status', '--porcelain'), 'Commit the release source before packaging')
    revision = git('rev-parse', 'HEAD')
    files = addon_contents()
    native = ROOT / 'Companion/Prepared/2.1.5'
    exe = (native / 'Offhand.exe').read_bytes()
    portable = (native / PORTABLE).read_bytes()
    require(digest(exe) == EXE_SHA, 'Frozen Companion executable changed')
    require(digest(portable) == PORTABLE_SHA, 'Frozen Companion archive changed')
    receipt = json.loads((native / 'release.json').read_text(encoding='utf-8-sig'))

    out.mkdir(parents=True, exist_ok=False)
    addon = out / ('Offhand-v' + VERSION + '.zip')
    write_zip(addon, files)
    manifest = {
        'addonVersion': VERSION,
        'addonSourceRevision': revision,
        'addonArchiveSha256': digest(addon.read_bytes()),
        'addonFiles': {name: digest(data) for name, data in files.items()},
        'companionVersion': '2.1.5',
        'companionSourceRevision': receipt['companionSourceRevision'],
        'companionBinarySha256': EXE_SHA,
        'companionArchiveSha256': PORTABLE_SHA,
    }
    metadata = (json.dumps(manifest, indent=2, sort_keys=True) + '\n').encode('utf-8')
    (out / 'publication.json').write_bytes(metadata)
    (out / 'Offhand.exe').write_bytes(exe)
    (out / PORTABLE).write_bytes(portable)
    (out / 'curseforge-changelog.md').write_bytes((ROOT / 'docs/RELEASE-CHANGELOG-BETA31.md').read_bytes())
    write_zip(out / ('Offhand-Complete-v' + VERSION + '.zip'), {
        **files, 'Offhand.exe': exe,
        'COMPANION-LICENSE.txt': (ROOT / 'Companion/LICENSE').read_bytes(),
        'README-FIRST.txt': (ROOT / 'docs/INSTALL-2.1.5-beta.31.txt').read_bytes(),
        'PUBLICATION.json': metadata,
    })
    assets = sorted(out.iterdir())
    (out / 'checksums-sha256.txt').write_text(
        ''.join(digest(path.read_bytes()) + '  ' + path.name + '\n' for path in assets),
        encoding='ascii', newline='\n')
    print('Verified six manifests and', len(files), 'addon entries')
    print('Prepared', VERSION, 'from', revision, 'with addon SHA-256', manifest['addonArchiveSha256'])


if __name__ == '__main__':
    prepare(Path(sys.argv[1]).resolve())
