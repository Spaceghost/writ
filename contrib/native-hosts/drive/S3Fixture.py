#!/usr/bin/env python3
"""Native acceptance driver for a checksum-pinned, loopback-only real S3 server.

Only the child created here is stopped. Credentials and raw server logs remain
in the private fixture tree; only selected, credential-free evidence is copied.
No Writ policy or reference-service behavior is implemented in this driver.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import secrets
import shutil
import socket
import subprocess
import sys
import tarfile
import time
import urllib.request
import zipfile


def main(args):
    platform = "win32" if sys.platform == "win32" else "linux"
    pins = json.loads(Path(__file__).with_name("fixture-pins.json").read_text())
    pin = pins[platform]
    root, package, logs = args.output.resolve(), args.package.resolve(), args.logs.resolve()
    if root.exists():
        raise RuntimeError("Use a new fixture directory outside the checkout")
    repo = Path(__file__).resolve().parents[3]
    if root == repo or repo in root.parents:
        raise RuntimeError("Keep generated artifacts outside the checkout")
    root.mkdir(parents=True, mode=0o700)
    logs.mkdir(parents=True, exist_ok=True)
    archive = args.archive.resolve() if args.archive else root / ("server.zip" if platform == "win32" else "server.tar.gz")
    if not args.archive:
        with urllib.request.urlopen(pin["url"], timeout=60) as response, archive.open("wb") as target:
            shutil.copyfileobj(response, target)
    if hashlib.sha256(archive.read_bytes()).hexdigest() != pin["sha256"]:
        raise RuntimeError("S3 fixture checksum mismatch")
    executable = root / ("weed.exe" if platform == "win32" else "weed")
    if platform == "win32":
        with zipfile.ZipFile(archive) as zipped:
            executable.write_bytes(zipped.read("weed.exe"))
    else:
        with tarfile.open(archive) as tar:
            executable.write_bytes(tar.extractfile("weed").read())
        executable.chmod(0o700)
    # Bind reservations avoid choosing ports already used by another local task.
    sockets = []
    try:
        for _ in range(8):
            sock = socket.socket(); sock.bind(("127.0.0.1", 0)); sockets.append(sock)
        ports = [sock.getsockname()[1] for sock in sockets]
    finally:
        for sock in sockets:
            sock.close()
    access_key, secret_key = secrets.token_hex(12), secrets.token_hex(24)
    configuration = root / "s3.json"
    connection = root / "connection.json"
    for path, value in [
        (configuration, {"identities": [{"name": "writ-acceptance", "credentials": [{"accessKey": access_key, "secretKey": secret_key}], "actions": ["Admin", "Read", "Write", "List", "Tagging"]}]}),
        (connection, {"endpoint": f"http://127.0.0.1:{ports[6]}", "bucket": "writ-acceptance", "prefix": "workspace", "region": "us-east-1", "accessKey": access_key, "secretKey": secret_key}),
    ]:
        with os.fdopen(os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600), "w") as output:
            json.dump(value, output)
    data = root / "data"; data.mkdir(mode=0o700)
    command = [str(executable), "mini", f"-dir={data}", "-ip=127.0.0.1", "-ip.bind=127.0.0.1",
               f"-s3.config={configuration}", "-bucket=writ-acceptance", "-admin.ui=false", "-webdav=false",
               "-s3.port.iceberg=0", "-s3.port.lance=0", "-master.telemetry=false",
               "-volume.max=8", "-master.volumeSizeLimitMB=64"]
    for i, service in enumerate(["master", "volume", "filer", "s3"]):
        command.extend([f"-{service}.port={ports[i * 2]}", f"-{service}.port.grpc={ports[i * 2 + 1]}"])
    node = package / ("node.exe" if platform == "win32" else "node")
    drive = package / "drive"
    ready = root / "ready.mjs"
    ready.write_text("""import {readFile} from 'node:fs/promises';
import {pathToFileURL} from 'node:url';
const {S3}=await import(pathToFileURL(process.argv[2]));
const client=new S3(JSON.parse(await readFile(process.argv[3])));
let last;for(let attempt=0;attempt<60;attempt++){
  try{await client.list('');process.exit(0);}catch(error){last=error;}
  await new Promise(resolve=>setTimeout(resolve,1000));
}throw Error('S3 fixture did not become ready: '+last.code);
""")
    with (root / "server-private.log").open("w") as server_log:
        server = subprocess.Popen(command, cwd=root, stdout=server_log, stderr=subprocess.STDOUT)
        try:
            subprocess.run([node, ready, drive / "s3.mjs", connection], check=True, timeout=90)
            with (logs / "drive-native.txt").open("w") as log:
                subprocess.run([node, drive / "Smoke.mjs", drive, connection, root / "acceptance"],
                               stdout=log, stderr=subprocess.STDOUT, check=True, timeout=300)
            shutil.copyfile(root / "acceptance/acceptance.json", logs / "drive-acceptance.json")
            if args.playwright:
                browser_evidence = logs / "drive-browser"; browser_evidence.mkdir()
                app_args = [node, drive / "app.mjs", "--data", root / "ui-state", "--folder", root / "ui-files"]
                with (root / "browser-app-private.log").open("w") as app_log:
                    app = subprocess.Popen([*app_args, "--no-open"], stdout=app_log, stderr=subprocess.STDOUT)
                    try:
                        for _ in range(300):
                            if app.poll() is not None:
                                raise RuntimeError("Packaged browser app exited during startup")
                            try:
                                session = json.loads((root / "ui-state/session.json").read_text())
                                if session.get("url"):
                                    break
                            except (FileNotFoundError, json.JSONDecodeError):
                                pass
                            time.sleep(0.1)
                        else:
                            raise RuntimeError("Packaged browser app startup timed out")
                        with (logs / "drive-browser.txt").open("w") as log:
                            subprocess.run([node, Path(__file__).with_name("BrowserSmoke.mjs"), args.playwright.resolve(),
                                            root / "ui-state", connection, browser_evidence],
                                           stdout=log, stderr=subprocess.STDOUT, check=True, timeout=300)
                    finally:
                        try:
                            subprocess.run([*app_args, "--stop"], stdout=app_log, stderr=subprocess.STDOUT, timeout=40)
                            app.wait(timeout=10)
                        finally:
                            if app.poll() is None:
                                app.kill(); app.wait(timeout=10)
            (logs / "drive-fixture.json").write_text(json.dumps({"server": "SeaweedFS", "version": pins["version"],
                "archive": pin, "transport": "signed S3 over loopback HTTP", "nativePlatform": platform,
                "node": subprocess.check_output([node, "--version"], text=True).strip()}, indent=2) + "\n")
            print("PASS real S3 acceptance with the exact packaged app and runtime", flush=True)
        finally:
            if server.poll() is None:
                server.terminate()
                try:
                    server.wait(timeout=15)
                except subprocess.TimeoutExpired:
                    server.kill(); server.wait(timeout=10)
            configuration.unlink(missing_ok=True); connection.unlink(missing_ok=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--package", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--logs", type=Path, required=True)
    parser.add_argument("--archive", type=Path)
    parser.add_argument("--playwright", type=Path, help="Installed pinned Playwright index.mjs for packaged UI checks")
    main(parser.parse_args())
