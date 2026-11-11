"""Freeze and verify a private addon-only QA bundle. Never install or launch."""
import datetime
import hashlib
import json
import re
from pathlib import Path
import shutil
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[2]
LABEL = "discord-qa-20261110"


def digest(data):
    return hashlib.sha256(data).hexdigest()


def main():
    stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S-%f")
    output = ROOT / "dist" / (LABEL + "-" + stamp)
    output.mkdir(parents=True)
    subject = output / "validated-subject"
    manifests = sorted(ROOT.glob("Offhand*.toc"))
    assert len(manifests) == 6, "review changed manifest inventory"
    paths = {p.relative_to(ROOT).as_posix() for p in manifests}
    for toc in manifests:
        for line in toc.read_text(encoding="utf-8").splitlines():
            line = line.strip().replace("\\", "/")
            if not line or line.startswith("#"):
                continue
            resolved = (ROOT / line).resolve()
            assert resolved.is_relative_to(ROOT) and resolved.is_file(), "unsafe/missing TOC input"
            paths.add(resolved.relative_to(ROOT).as_posix())
    paths.update(p.relative_to(ROOT).as_posix() for p in (ROOT / "Media").rglob("*") if p.is_file())
    paths.update({"Bindings.xml", "README.md", "CHANGELOG.md", "LICENSE"})
    # Freeze bytes once. The public package and the validation subject use the
    # same runtime; later edits in the shared checkout invalidate this build.
    source = {name: (ROOT / name).read_bytes() for name in sorted(paths)}
    def lua_body(data):
        text = re.sub(r"--\[\[.*?\]\]", "", data.decode("utf-8"), flags=re.S)
        return re.sub(r"--[^\r\n]*", "", text).strip()
    assert lua_body(source["Core/CompanionTopology.lua"]) == "OffhandCompanionTopology = nil"
    assert lua_body(source["Core/ForeverState.lua"]) == ""
    packaged = {}
    for name, data in source.items():
        if name.endswith(".toc"):
            data = ("## X-Offhand-Candidate: " + LABEL + "\n").encode() + data
        packaged[name] = data
        destination = subject / name
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(data)
    extra = list((ROOT / "tests").glob("*.lua")) + [ROOT / "package.ps1",
        ROOT / "tools/issue-capture/Install-QACandidate.ps1", ROOT / "tools/issue-capture/README.md"]
    for folder in ["tools/issue-capture/OffhandIssueProbe", "tools/performance/OffhandPerformanceProbe",
                   "tools/display-capture/OffhandDisplayProbe"]:
        extra += [p for p in (ROOT / folder).iterdir() if p.suffix in {".lua", ".toc"}]
    frozen_extra = {p.relative_to(ROOT).as_posix(): p.read_bytes() for p in extra}
    for name, data in frozen_extra.items():
        destination = subject / name
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(data)
    lua, luac = shutil.which("lua"), shutil.which("luac")
    assert lua and luac, "Lua 5.1 runtime and compiler required"
    powershell = shutil.which("pwsh") or shutil.which("powershell")
    assert powershell, "PowerShell parser required for the installer"
    installer = str(subject / "tools/issue-capture/Install-QACandidate.ps1").replace("'", "''")
    parse = "$t=$null;$e=$null;[void][System.Management.Automation.Language.Parser]::ParseFile('" + installer + "',[ref]$t,[ref]$e);if($e.Count){$e;exit 1}"
    run = subprocess.run([powershell, "-NoProfile", "-Command", parse], capture_output=True, text=True)
    if run.returncode:
        raise RuntimeError("Installer syntax failed\n" + run.stdout + run.stderr)
    tests = sorted((subject / "tests").glob("*.lua"))
    for test in tests:
        run = subprocess.run([lua, str(test)], cwd=subject, capture_output=True, text=True)
        if run.returncode:
            raise RuntimeError(test.name + "\n" + run.stdout + run.stderr)
    for path in subject.rglob("*.lua"):
        run = subprocess.run([luac, "-p", str(path)], capture_output=True, text=True)
        if run.returncode:
            raise RuntimeError(run.stderr)
    for name, data in {**source, **frozen_extra}.items():
        assert (ROOT / name).read_bytes() == data, "source drift during validation: " + name
    entries = {"Offhand/" + name: data for name, data in packaged.items()}
    for folder in ["tools/issue-capture/OffhandIssueProbe", "tools/performance/OffhandPerformanceProbe"]:
        for name, data in frozen_extra.items():
            if name.startswith(folder + "/"):
                entries[name.split("/")[-2] + "/" + name.split("/")[-1]] = data
    guide = frozen_extra["tools/issue-capture/README.md"]
    entries["README-FIRST.md"] = guide
    record = {"candidate": LABEL, "baselineHead": subprocess.check_output(
        ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        "sourceState": "shared dirty checkout, exact frozen bytes", "luaSuites": len(tests),
        "nativeQA": False, "installed": False, "published": False,
        "sourceSha256": {name: digest(data) for name, data in source.items()},
        "files": {name: digest(data) for name, data in entries.items()}}
    archive = output / "Offhand-discord-private-QA.zip"
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as bundle:
        for name, data in sorted(entries.items()):
            bundle.writestr(name, data)
    with zipfile.ZipFile(archive) as bundle:
        assert set(bundle.namelist()) == set(entries), "ZIP inventory mismatch"
        for name, expected in record["files"].items():
            assert digest(bundle.read(name)) == expected, "ZIP byte mismatch: " + name
    record["archiveSha256"] = digest(archive.read_bytes())
    record["installerSha256"] = digest(frozen_extra["tools/issue-capture/Install-QACandidate.ps1"])
    (output / "verification.json").write_text(json.dumps(record, indent=2), encoding="utf-8")
    (output / "README-FIRST.md").write_bytes(guide)
    (output / "Install-QACandidate.ps1").write_bytes(frozen_extra["tools/issue-capture/Install-QACandidate.ps1"])
    print(json.dumps({"output": str(output), "luaSuites": len(tests), "verifiedEntries": len(entries),
                      "archiveSha256": record["archiveSha256"]}))


if __name__ == "__main__":
    main()
