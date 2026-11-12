#!/usr/bin/env python3
"""Exercise the exact downloadable Linux payload and per-user installer."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time


def check(condition, name):
    if not condition:
        raise AssertionError(name)
    print("PASS: " + name, flush=True)


def payload_check(path):
    for line in (path / "SHA256SUMS").read_text().splitlines():
        digest, name = line.split("  ", 1)
        check(hashlib.sha256((path / name).read_bytes()).hexdigest() == digest, "payload hash: " + name)


def main(output):
    output = output.resolve()
    logs = output / "logs"
    package = output / "portable with spaces"
    package.mkdir()
    subprocess.run(["tar", "-xzf", next((output / "dist").glob("*-portable.tar.gz")), "-C", package], check=True)
    payload_check(package)
    with (logs / "native-smoke.txt").open("w") as log:
        subprocess.run([sys.executable, package / "Smoke.py", "--package", package, "--base", output / "native-smoke"],
                       stdout=log, stderr=subprocess.STDOUT, check=True, timeout=300)
    for path in (output / "native-smoke").glob("*.log"):
        (logs / ("native-" + path.name)).write_bytes(path.read_bytes())
    home = output / "test-home"; home.mkdir(mode=0o700)
    data, installed, root = home / ".local/share", home / "app with spaces", home / "Writ"
    env = dict(os.environ, HOME=str(home), XDG_DATA_HOME=str(data))
    installer = next((output / "dist").glob("*-setup.run"))
    with (logs / "install.txt").open("w") as log:
        subprocess.run(["bash", installer, "--prefix", installed], env=env, stdout=log, stderr=subprocess.STDOUT, check=True, timeout=60)
    payload_check(installed)
    check((data / "applications/writ.desktop").is_file(), "per-user application launcher installed")
    subprocess.run([installed / "node", installed / "drive/Lifecycle.mjs", installed, "start"], env=env, check=True, timeout=45)
    with (logs / "installed-provider.txt").open("w") as log:
        proc = subprocess.Popen([installed / "writ-linux", "start"], env=env, stdout=log, stderr=log)
    try:
        deadline = time.monotonic() + 45
        while "READY " not in (logs / "installed-provider.txt").read_text():
            check(proc.poll() is None, "installed provider starts")
            if time.monotonic() > deadline:
                raise AssertionError("installed launch timeout")
            time.sleep(.2)
        check((root / "hello.txt").read_bytes().startswith(b"Hello from Writ!"), "installed legacy canary hydrates")
        saved = b"Installed Linux save retained by uninstall\n"
        (root / "hello.txt").write_bytes(saved)
        held = os.open(root / "hello.txt", os.O_RDONLY)
        try:
            with (logs / "uninstall-busy.txt").open("w") as log:
                refused = subprocess.run([installed / "uninstall.sh"], env=env, stdout=log, stderr=subprocess.STDOUT, timeout=45)
            check(refused.returncode != 0, "uninstaller aborts when native cleanup refuses")
            check((installed / "writ-linux").is_file() and proc.poll() is None,
                  "failed uninstall retains application and running provider")
        finally:
            os.close(held)
        with (logs / "uninstall.txt").open("w") as log:
            subprocess.run([installed / "uninstall.sh"], env=env, stdout=log, stderr=subprocess.STDOUT, check=True, timeout=45)
        check(proc.wait(timeout=10) == 0, "uninstaller stops provider")
        subprocess.run([package / "node", package / "drive/Lifecycle.mjs", package, "stopped"], env=env, check=True, timeout=15)
        check(not installed.exists() and not (data / "applications/writ.desktop").exists(), "application and launcher removed")
        check((root / "hello.txt").read_bytes() == saved, "uninstaller retains exact edited bytes")
        check((data / "WritDemo/store/head").is_file(), "uninstaller retains backing store")
        info = json.loads(subprocess.check_output([package / "writ-linux", "inspect", root], env=env, text=True))
        check(not info["mounted"] and not info["placeholder"], "uninstaller leaves an ordinary file")
        print("ALL LINUX PACKAGE CHECKS PASSED", flush=True)
    finally:
        if proc.poll() is None:
            subprocess.run([package / "writ-linux", "stop"], env=env, timeout=45)
            if proc.poll() is None:
                proc.kill()
            proc.wait(timeout=10)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    main(parser.parse_args().output)
