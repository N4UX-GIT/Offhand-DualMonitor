"""Portable addon checks and freshness reporting for recorded live evidence."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
GENERATED = {"Core/ForeverState.lua", "Core/CompanionTopology.lua"}


def source_hash(data: bytes) -> str:
    text = data.decode("utf-8-sig").replace("\r\n", "\n").replace("\r", "\n")
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def local_file(root: Path, parent: Path, name: str) -> Path:
    path = (parent / name.replace("\\", "/")).resolve()
    if not path.is_relative_to(root.resolve()) or not path.is_file():
        raise ValueError(f"Missing or external addon load path: {name}")
    return path


def manifest_files(root: Path, toc: Path) -> set[Path]:
    """Follow each manifest independently, including nested XML load order."""
    seen: dict[str, Path] = {}

    def visit(parent: Path, name: str) -> None:
        path = local_file(root, parent, name)
        key = path.relative_to(root).as_posix().casefold()
        if key in seen:
            raise ValueError(f"{toc.name}: duplicate runtime load: {key}")
        seen[key] = path
        if path.suffix.lower() == ".xml":
            for element in ET.parse(path).iter():
                tag = element.tag.rsplit("}", 1)[-1]
                if tag in ("Script", "Include") and element.get("file"):
                    visit(path.parent, element.attrib["file"])

    for line in toc.read_text(encoding="utf-8-sig").splitlines():
        line = line.strip()
        if line and not line.startswith("#"):
            visit(toc.parent, line)
    if not seen:
        raise ValueError(f"{toc.name}: empty runtime load list")
    return set(seen.values())


def live_status(root: Path, receipt: dict) -> dict:
    if receipt.get("schema") != 1 or receipt.get("hash_mode") != "utf8-lf":
        raise ValueError("Unsupported live evidence receipt schema")
    hashes = receipt.get("source_fingerprints")
    if not isinstance(hashes, dict) or not hashes:
        raise ValueError("Live evidence receipt has no source fingerprints")
    changed = []
    for name, expected in hashes.items():
        if not isinstance(expected, str) or len(expected) != 64 or any(c not in "0123456789abcdef" for c in expected):
            raise ValueError(f"Invalid source fingerprint: {name}")
        path = local_file(root, root, name)
        if source_hash(path.read_bytes()) != expected:
            changed.append(name)
    if (not receipt.get("id") or not receipt.get("scope") or not receipt.get("client")
            or not isinstance(receipt.get("cases"), list) or not receipt["cases"]
            or not all(isinstance(case, str) and case for case in receipt["cases"])
            or not isinstance(receipt.get("evidence"), str)):
        raise ValueError("Live evidence receipt lacks cases, client or evidence reference")
    local_file(root, root, receipt["evidence"])
    return {
        "id": receipt["id"], "client": receipt["client"], "scope": receipt["scope"],
        "retest_required": bool(changed), "changed_files": sorted(changed),
        "deferred": receipt.get("deferred", []),
    }


def bridge_toc(directory: Path) -> Path:
    """A bridge folder holds exactly one Offhand_<Name>.toc; it ships as Offhand_<Name>/."""
    tocs = sorted(p for p in directory.iterdir() if p.is_file() and p.suffix.lower() == ".toc")
    if len(tocs) != 1 or not tocs[0].stem.startswith("Offhand_"):
        raise ValueError(f"Bridges/{directory.name} must contain exactly one Offhand_<Name>.toc")
    return tocs[0]


def bridge_manifests(root: Path) -> list[Path]:
    bridges = root / "Bridges"
    if not bridges.is_dir():
        return []
    return [bridge_toc(directory) for directory in sorted(p for p in bridges.iterdir() if p.is_dir())]


def installed_differences(root: Path, installed: Path, files: set[Path]) -> list[str]:
    """Root files compare with the installed Offhand folder. Bridge files, and
    each bridge TOC, compare with the sibling Offhand_<Name> folder."""
    targets: dict[Path, Path] = {}
    for path in files:
        relative = path.relative_to(root)
        if relative.parts[0] == "Bridges" and len(relative.parts) > 2:
            directory = root / "Bridges" / relative.parts[1]
            toc = bridge_toc(directory)
            sibling = installed.parent / toc.stem
            targets[path] = sibling / path.relative_to(directory)
            targets[toc] = sibling / toc.name
        else:
            targets[path] = installed / relative
    changed = []
    for path in sorted(targets):
        name = path.relative_to(root).as_posix()
        if name in GENERATED:
            continue
        target = targets[path]
        if not target.is_file() or source_hash(path.read_bytes()) != source_hash(target.read_bytes()):
            changed.append(name)
    return changed


def run_checks(root: Path, args: argparse.Namespace) -> dict:
    clients = sorted(root.glob("Offhand*.toc"))
    if not clients:
        raise ValueError("No Offhand manifests found")
    bridges = bridge_manifests(root)
    manifests = clients + bridges
    files: set[Path] = set()
    for toc in manifests:
        loaded = manifest_files(root, toc)
        if toc in bridges and any(not path.is_relative_to(toc.parent.resolve()) for path in loaded):
            raise ValueError(f"{toc.name}: loads a file outside its bridge folder")
        files.update(loaded)
    compiler = args.luac or shutil.which("luac") or shutil.which("luac.exe")
    if not compiler:
        raise ValueError("Lua 5.1 compiler required; pass --luac")
    version = subprocess.run([compiler, "-v"], capture_output=True, text=True, check=True)
    if "Lua 5.1" not in version.stdout + version.stderr:
        raise ValueError("Use the supported Lua 5.1 compiler")
    lua_files = sorted(p for p in files if p.suffix.lower() == ".lua")
    for path in lua_files:
        subprocess.run([compiler, "-p", str(path)], check=True)
    suites = sorted((root / "tests").glob("*.lua"))
    if not suites:
        raise ValueError("No Lua regression suites found")
    if not args.skip_lua_tests:
        runtime = args.lua or shutil.which("lua") or shutil.which("lua.exe")
        if not runtime:
            raise ValueError("Lua 5.1 runtime required; pass --lua")
        version = subprocess.run([runtime, "-v"], capture_output=True, text=True, check=True)
        if "Lua 5.1" not in version.stdout + version.stderr:
            raise ValueError("Use the supported Lua 5.1 runtime")
        for suite in suites:
            subprocess.run([runtime, str(suite)], cwd=root, check=True, stdout=subprocess.DEVNULL)
    receipts = sorted((root / "tests" / "compatibility").glob("*.json"))
    if not receipts:
        raise ValueError("No compatibility evidence receipts found")
    status = [live_status(root, json.loads(p.read_text(encoding="utf-8"))) for p in receipts]
    installed = installed_differences(root, Path(args.installed).resolve(), files) if args.installed else []
    return {
        "manifests": len(manifests), "bridges": [toc.stem for toc in bridges],
        "runtime_lua_files": len(lua_files),
        "lua_suites": len(suites), "lua_suites_run": not args.skip_lua_tests,
        "live_evidence": status, "installed_differences": installed,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--lua", help="Lua 5.1 executable")
    parser.add_argument("--luac", help="Lua 5.1 compiler")
    parser.add_argument("--skip-lua-tests", action="store_true", help="CI already runs every Lua suite separately")
    parser.add_argument("--installed", help="Optional installed Offhand folder to compare before live QA")
    parser.add_argument("--require-fresh-live", action="store_true",
                        help="Fail if recorded live evidence predates the relevant source; does not certify deferred cases")
    parser.add_argument("--report", help="Optional JSON report output path")
    args = parser.parse_args()
    try:
        result = run_checks(ROOT, args)
        if args.report:
            report = Path(args.report)
            report.parent.mkdir(parents=True, exist_ok=True)
            report.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
        bridges = len(result["bridges"])
        bridge_note = f" ({bridges} bridge{'' if bridges == 1 else 's'})" if bridges else ""
        print(f"PASS: {result['manifests']} manifests{bridge_note}, {result['runtime_lua_files']} runtime Lua files, "
              f"{result['lua_suites']} Lua suites ({'run' if result['lua_suites_run'] else 'handled separately'}).")
        for status in result["live_evidence"]:
            state = "RETEST REQUIRED" if status["retest_required"] else "RECORDED SOURCE MATCHES"
            print(f"{state}: {status['id']} ({status['client']})")
            for name in status["changed_files"]:
                print(f"  {name}")
            if status["deferred"]:
                print("  Still deferred: " + ", ".join(status["deferred"]))
        if result["installed_differences"]:
            print("Installed addon differs from this checkout:")
            for name in result["installed_differences"]:
                print(f"  {name}")
            return 1
        if args.require_fresh_live and any(s["retest_required"] for s in result["live_evidence"]):
            return 1
        return 0
    except (ValueError, OSError, ET.ParseError, subprocess.CalledProcessError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
