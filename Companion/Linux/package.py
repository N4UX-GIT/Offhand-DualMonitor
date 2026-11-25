"""Build the reproducible x86-64 Linux tester tarball with a local Go SDK."""
import gzip
import hashlib
import io
import json
import os
from pathlib import Path
import re
import subprocess
import tarfile
import tempfile

ROOT = Path(__file__).resolve().parent
DEST = ROOT.parents[1] / "dist" / "linux-probe"
GO = os.environ.get("GO_EXE", "go")


def go(*args, **kwargs):
    return subprocess.check_output([GO, *args], cwd=ROOT, **kwargs)


def main():
    go("test", "-mod=readonly", "./...")
    go("vet", "./...")
    version = re.search(r'const version = "([0-9.]+)"', (ROOT / "main.go").read_text()).group(1)
    stem = f"offhand-linux-probe-{version}-linux-amd64"
    dest = DEST / (stem + ".tar.gz")
    DEST.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=DEST) as build:
        binary = Path(build) / "offhand-linux-probe"
        env = dict(os.environ, GOOS="linux", GOARCH="amd64", GOAMD64="v1", CGO_ENABLED="0")
        go("build", "-mod=readonly", "-trimpath", "-buildvcs=false", "-ldflags=-s -w -buildid=",
           "-o", str(binary), ".", env=env)
        payload = binary.read_bytes()
        if payload[:6] != b"\x7fELF\x02\x01" or payload[18:20] != b"\x3e\x00":
            raise ValueError("Expected a Linux x86-64 ELF executable")
        dep = Path(json.loads(go("list", "-m", "-json", "github.com/jezek/xgb"))["Dir"])
        sdk = Path(go("env", "GOROOT", text=True).strip())
        files = {"offhand-linux-probe": payload, "README.md": (ROOT / "README.md").read_bytes(),
                 "LICENSE": (ROOT.parent / "LICENSE").read_bytes(),
                 "LICENSE-xgb": (dep / "LICENSE").read_bytes(), "LICENSE-Go": (sdk / "LICENSE").read_bytes()}
        for name in ("go.mod", "go.sum", "main.go", "desktop.go", "probe_test.go"):
            files["source/" + name] = (ROOT / name).read_bytes().replace(b"\r\n", b"\n")
        tmp = Path(build) / dest.name
        with tmp.open("wb") as stream, gzip.GzipFile(filename="", fileobj=stream, mode="wb", mtime=0) as gz:
            with tarfile.open(fileobj=gz, mode="w", format=tarfile.USTAR_FORMAT) as package:
                for name, data in files.items():
                    info = tarfile.TarInfo(stem + "/" + name)
                    info.mode = 0o755 if name == "offhand-linux-probe" else 0o644
                    info.size = len(data)
                    package.addfile(info, io.BytesIO(data))
        with tarfile.open(tmp) as package:
            for name, data in files.items():
                assert package.extractfile(stem + "/" + name).read() == data
        tmp.replace(dest)
    checksum = hashlib.sha256(dest.read_bytes()).hexdigest()
    dest.with_suffix(dest.suffix + ".sha256").write_bytes(f"{checksum}  {dest.name}\n".encode())
    print(dest, checksum, sep="\n")


if __name__ == "__main__":
    main()
