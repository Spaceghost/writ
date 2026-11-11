#!/usr/bin/env python3
"""Reproducible native packaging. Runtime decisions remain in shared Bend."""
import argparse
import gzip
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys
import tarfile
import urllib.request

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[4]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(args, log=None, **kwargs):
    if log:
        with log.open("w") as output:
            subprocess.run(list(map(str, args)), stdout=output, stderr=subprocess.STDOUT, check=True, **kwargs)
    else:
        return subprocess.check_output(list(map(str, args)), text=True, **kwargs).strip()


def verify(directory, manifest):
    for line in manifest.read_text().splitlines():
        digest, name = line.split("  ", 1)
        path = directory / name
        if Path(name).is_absolute() or ".." in Path(name).parts or sha(path) != digest:
            raise RuntimeError("Manifest mismatch: " + name)


def download(pin, target):
    run(["curl", "--proto", "=https", "--tlsv1.2", "--retry", "3", "-fsSL", pin["url"], "-o", target])
    if sha(target) != pin["sha256"]:
        raise RuntimeError("Dependency checksum mismatch: " + target.name)


def archive(payload, target, stamp):
    # Explicit metadata and no gzip filename/time fields make packaging stable.
    with target.open("wb") as output, gzip.GzipFile(fileobj=output, mode="wb", filename="", mtime=0) as zipped:
        with tarfile.open(fileobj=zipped, mode="w", format=tarfile.USTAR_FORMAT) as tar:
            for path in sorted(payload.rglob("*")):
                info = tar.gettarinfo(str(path), str(path.relative_to(payload)))
                info.uid = info.gid = 0; info.uname = info.gname = ""; info.mtime = stamp
                if path.is_file():
                    with path.open("rb") as source:
                        tar.addfile(info, source)
                else:
                    tar.addfile(info)


def installer(archive_path, target):
    header = '''#!/usr/bin/env bash
set -euo pipefail
umask 077
work=$(mktemp -d "${TMPDIR:-/tmp}/writ-setup.XXXXXXXX")
trap 'rm -rf -- "$work"' EXIT
line=$(awk '/^__WRIT_ARCHIVE_BELOW__$/ { print NR + 1; exit }' "$0")
tail -n +"$line" -- "$0" > "$work/payload.tar.gz"
printf '%s  %s\\n' '@HASH@' "$work/payload.tar.gz" | sha256sum --quiet -c -
mkdir "$work/payload"
tar --no-same-owner -xzf "$work/payload.tar.gz" -C "$work/payload"
bash "$work/payload/install.sh" "$@"
exit 0
__WRIT_ARCHIVE_BELOW__
'''.replace("@HASH@", sha(archive_path))
    with target.open("wb") as output:
        output.write(header.encode()); output.write(archive_path.read_bytes())
    target.chmod(0o755)


def build(args):
    output, policy = args.output.resolve(), args.policy.resolve()
    if output == REPO or REPO in output.parents or output.exists():
        raise RuntimeError("Use a new output directory outside the checkout")
    output.mkdir(parents=True)
    logs, dist, payload = [output / name for name in ("logs", "dist", "payload")]
    for directory in (logs, dist, payload, payload / "lib"):
        directory.mkdir()
    verify(REPO, REPO / "verification/source-sha256.txt")
    verify(policy, policy / "SHA256SUMS")
    commit = run(["git", "rev-parse", "HEAD"], cwd=REPO)
    if policy.joinpath("commit.txt").read_text().strip() != commit:
        raise RuntimeError("Generated policy belongs to another commit")
    version = (HERE.parents[2] / "windows/cloud-files/release/VERSION").read_text().strip()
    if not re.fullmatch(r"\d+\.\d+\.\d+-preview\.\d+", version):
        raise RuntimeError("Only versioned previews are supported")
    stamp = int(run(["git", "show", "-s", "--format=%ct", "HEAD"], cwd=REPO))
    pins = json.loads((HERE / "toolchains.json").read_text())
    env = dict(os.environ, SOURCE_DATE_EPOCH=str(stamp), LC_ALL="C", TZ="UTC")
    download(pins["node"], output / "node.tar.xz")
    download(pins["fuse"], output / "fuse.tar.gz")
    run(["tar", "-xf", output / "node.tar.xz", "-C", output])
    run(["tar", "-xf", output / "fuse.tar.gz", "-C", output])
    node = output / ("node-v" + pins["node"]["version"] + "-linux-x64")
    fuse = output / ("fuse-" + pins["fuse"]["version"])
    wheels = output / "wheels"; wheels.mkdir()
    for name in ("meson", "ninja"):
        pin = pins[name]
        with urllib.request.urlopen(f'https://pypi.org/pypi/{name}/{pin["version"]}/json', timeout=30) as response:
            metadata = json.load(response)
        asset = next(item for item in metadata["urls"] if item["digests"]["sha256"] == pin["sha256"])
        download(dict(pin, url=asset["url"]), wheels / asset["filename"])
    run([sys.executable, "-m", "venv", output / "tools"])
    tools = output / "tools/bin"
    run([tools / "python", "-m", "pip", "install", "--no-index", "--no-deps", *sorted(wheels.iterdir())], logs / "build-tools.txt")
    env["PATH"] = str(tools) + os.pathsep + env["PATH"]
    for attempt in (1, 2):
        fuse_build = output / f"fuse-build-{attempt}"
        native = output / f"native-{attempt}"
        build_env = dict(env, CC=args.cc, CFLAGS=f"-ffile-prefix-map={fuse_build}=. -ffile-prefix-map={fuse}=fuse")
        run([tools / "meson", "setup", fuse_build, fuse, "--prefix=/usr", "--libdir=lib", "--buildtype=release",
             "-Dutils=false", "-Dexamples=false", "-Dtests=false", "-Duseroot=false", "-Denable-io-uring=false"],
            logs / f"fuse-configure-{attempt}.txt", env=build_env)
        run([tools / "meson", "compile", "-C", fuse_build, "-j", "2"], logs / f"fuse-build-{attempt}.txt", env=build_env)
        build_env = dict(env)
        if not args.dynamic_cxx:
            build_env["LDFLAGS"] = "-static-libstdc++ -static-libgcc"
        run(["make", "-C", HERE.parent, f"OUT={native}", f"CC={args.cc}", f"CXX={args.cxx}",
             f"VERSION={version}", f"SOURCE_COMMIT={commit}", f"FUSE_CFLAGS=-I{fuse}/include -I{fuse_build}",
             f"FUSE_LIBS={fuse_build}/lib/libfuse3.so.4"], logs / f"native-build-{attempt}.txt", env=build_env)
    for relative in ("native-{}/writ-linux", "fuse-build-{}/lib/libfuse3.so.4"):
        if sha(output / relative.format(1)) != sha(output / relative.format(2)):
            raise RuntimeError("Repeated native build differs: " + relative)
    copies = {
        output / "native-1/writ-linux": "writ-linux",
        output / "fuse-build-1/lib/libfuse3.so.4": "lib/libfuse3.so.4",
        node / "bin/node": "node", node / "LICENSE": "NODE-LICENSE.txt",
        fuse / "LICENSE": "FUSE-LICENSE.txt", fuse / "LGPL2.txt": "FUSE-LGPL2.txt",
        output / "fuse.tar.gz": "libfuse-source.tar.gz",
        policy / "public-sync.mjs": "public-sync.mjs",
        HERE.parents[2] / "runtime/node-policy.mjs": "node-policy.mjs",
        HERE.parent / "Smoke.py": "Smoke.py",
    }
    for name in ("README.txt", "install.sh", "uninstall.sh"):
        copies[HERE / name] = name
    for source, name in copies.items():
        shutil.copyfile(source, payload / name)
        (payload / name).chmod(0o755 if name in ("writ-linux", "node", "install.sh", "uninstall.sh") else 0o644)
    run([payload / "node", policy / "public-sync-tests.js"], logs / "linux-model.txt")
    run([payload / "writ-linux", "version"], logs / "version.txt")
    run(["ldd", payload / "writ-linux"], logs / "native-dependencies.txt")
    info = dict(version=version, sourceCommit=commit, sourceManifestSha256=sha(REPO / "verification/source-sha256.txt"),
                dependencies=pins, nativeToolchain=run([*shlex.split(args.cxx), "--version"]),
                compilerPackages=run(["dpkg-query", "-W", "gcc-11", "g++-11", "libc6-dev", "libssl-dev"])
                if shutil.which("dpkg-query") else "Local development toolchain; see nativeToolchain",
                runnerImage=(env.get("ImageOS", "") + " " + env.get("ImageVersion", "")).strip(),
                osRelease=Path("/etc/os-release").read_text(), python=sys.version,
                nativeRebuildSha256=sha(payload / "writ-linux"), fuseRebuildSha256=sha(payload / "lib/libfuse3.so.4"),
                profile="Public single-file local-store preview; no interactive editor or protected-host qualification")
    (payload / "BUILD-INFO.json").write_text(json.dumps(info, indent=2) + "\n")
    (payload / "SHA256SUMS").write_text("".join(f"{sha(p)}  {p.relative_to(payload)}\n" for p in sorted(payload.rglob("*")) if p.is_file()))
    name = f"Writ-{version}-linux-x64"
    for attempt in (1, 2):
        package = output / f"package-{attempt}"; package.mkdir()
        archive_path = package / (name + "-portable.tar.gz")
        archive(payload, archive_path, stamp)
        installer(archive_path, package / (name + "-setup.run"))
    matches = []
    for suffix in ("-portable.tar.gz", "-setup.run"):
        first, second = [output / f"package-{n}" / (name + suffix) for n in (1, 2)]
        if sha(first) != sha(second):
            raise RuntimeError("Repeated package differs: " + suffix)
        shutil.copyfile(first, dist / first.name)
        matches.append(f"MATCH {sha(first)} {first.name}")
    (logs / "reproducibility.txt").write_text("\n".join(matches) + "\n")
    shutil.copyfile(payload / "BUILD-INFO.json", dist / "BUILD-INFO-linux.json")
    print("Packages built; native and installation checks are required before publication.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--policy", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--cc", default="gcc-11")
    parser.add_argument("--cxx", default="g++-11")
    parser.add_argument("--dynamic-cxx", action="store_true", help="Development compiler override; recorded in build evidence")
    build(parser.parse_args())
