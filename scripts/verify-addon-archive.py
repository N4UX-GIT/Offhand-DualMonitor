"""Verify a public Offhand addon ZIP against a Git commit or tag."""

import argparse
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import stat
import subprocess
import sys
import zipfile


ROOT = Path(__file__).resolve().parents[1]
ROOT_FILES = {
    "Offhand.toc", "Offhand_Mainline.toc", "Offhand_Vanilla.toc", "Offhand_Classic.toc",
    "Offhand_Forever.toc", "Offhand_Wrath335a.toc", "Bindings.xml", "LICENSE", "README.md",
    "CHANGELOG.md",
}
TEXT_SUFFIXES = {".lua", ".xml", ".toc", ".md"}
# Preserve verification of the already-published Beta 44 archive.
BETA44_COMMIT = "d5a7de133ec7307be90987c49569fa7097cdbf2c"


def git(root, *args):
    return subprocess.check_output(["git", *args], cwd=root, stderr=subprocess.PIPE)


def addon_files(root, commit):
    files = {}
    listing = git(root, "ls-tree", "-r", "-z", commit)
    for record in listing.decode("utf-8").split("\0")[:-1]:
        metadata, name = record.split("\t", 1)
        path = PurePosixPath(name)
        folder = path.parts[0]
        suffix = path.suffix.lower()
        if not (
            name in ROOT_FILES
            or folder in {"Core", "Locales", "UI"}
            or (commit == BETA44_COMMIT and folder == "Offhand_Placement")
            or (folder == "Bridges" and suffix == ".lua")
            or (folder == "Media" and len(path.parts) == 2 and suffix == ".blp")
        ):
            continue
        mode, _, blob = metadata.split()
        if mode not in {"100644", "100755"}:
            raise ValueError(f"Expected a regular source file at {name}")
        files[name] = blob
    if missing := ROOT_FILES.difference(files):
        raise ValueError(f"Source revision is missing required addon files: {', '.join(sorted(missing))}")
    return files


def verify(root, archive_path, revision, checksums_path=None):
    commit = git(root, "rev-parse", "--verify", "--end-of-options", f"{revision}^{{commit}}").decode().strip()
    files = addon_files(root, commit)
    # Inspect and hash the same bytes so a changed archive cannot acquire a passing receipt.
    archive_bytes = archive_path.read_bytes()
    digest = hashlib.sha256(archive_bytes).hexdigest()
    if checksums_path:
        lines = checksums_path.read_text(encoding="utf-8-sig").splitlines()
        records = [line.split(maxsplit=1) for line in lines]
        matches = [record[0].lower() for record in records if len(record) == 2 and record[1] == archive_path.name]
        if matches != [digest]:
            raise ValueError(f"Expected one matching SHA-256 entry for {archive_path.name} in {checksums_path}")

    with zipfile.ZipFile(io.BytesIO(archive_bytes)) as archive:
        entries = archive.infolist()
        names = {entry.filename for entry in entries}
        if len({name.casefold() for name in names}) != len(entries):
            raise ValueError("Archive contains duplicate or case-colliding paths")
        expected = {name if name.startswith("Offhand_Placement/") else f"Offhand/{name}" for name in files}
        if expected != names:
            missing = ", ".join(sorted(expected - names)) or "none"
            extra = ", ".join(sorted(names - expected)) or "none"
            raise ValueError(f"Archive inventory differs. Missing: {missing}. Unexpected: {extra}.")
        for entry in entries:
            name = entry.filename.removeprefix("Offhand/")
            if stat.S_ISLNK(entry.external_attr >> 16):
                raise ValueError(f"Archive contains a symbolic link at {entry.filename}")
            packed = archive.read(entry)
            source = git(root, "cat-file", "blob", files[name])
            if name == "LICENSE" or PurePosixPath(name).suffix.lower() in TEXT_SUFFIXES:
                packed = packed.replace(b"\r\n", b"\n")
                source = source.replace(b"\r\n", b"\n")
            if packed != source:
                raise ValueError(f"Archive content differs from {commit} at {entry.filename}")

    return {"revision": commit, "archive": archive_path.name, "sha256": digest, "files": len(files)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    parser.add_argument("--revision", required=True, help="Git commit or tag that supplies the expected files")
    parser.add_argument("--checksums", type=Path, help="Release checksum list containing the ZIP filename")
    parser.add_argument("--report", type=Path, help="Write the verified archive SHA-256 and Git commit to JSON")
    args = parser.parse_args()
    try:
        result = verify(ROOT, args.archive, args.revision, args.checksums)
        if args.report:
            args.report.parent.mkdir(parents=True, exist_ok=True)
            args.report.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
        print(f"PASS: {result['archive']} ({result['files']} files) matches {result['revision']}")
        print(f"SHA-256: {result['sha256']}")
    except subprocess.CalledProcessError as error:
        print(f"FAIL: {error.stderr.decode(errors='replace').strip()}", file=sys.stderr)
        return 1
    except (OSError, RuntimeError, ValueError, zipfile.BadZipFile) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
