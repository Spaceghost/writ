#!/usr/bin/env python3
"""Native OS/package acceptance probe; release decisions remain in Bend."""
import argparse
import concurrent.futures
import hashlib
import json
import os
from pathlib import Path
import select
import subprocess
import time


def check(condition, name):
    if not condition:
        raise AssertionError(name)
    print("PASS: " + name, flush=True)


def wait_for(predicate, name, seconds=30):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        if predicate():
            return
        time.sleep(.1)
    raise AssertionError("timeout: " + name)


class Probe:
    def __init__(self, package, base):
        self.package, self.base = package.resolve(), base.resolve()
        self.exe = self.package / "writ-linux"
        self.base.mkdir(mode=0o700)  # A fresh directory is mandatory.
        self.store = self.base / "store"
        self.processes, self.logs = {}, {}
        self.run("seed", self.store)

    def run(self, *args, success=True):
        result = subprocess.run([self.exe, *map(str, args)], text=True,
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=40)
        if success and result.returncode:
            raise AssertionError(result.stdout)
        return result

    def start(self, name, fail=False):
        root = self.base / name
        count = len(self.logs)
        log = self.base / f"{name}-{count}.log"
        args = [self.exe, "serve", root, self.store, self.package / "node",
                self.package / "node-policy.mjs", self.package / "public-sync.mjs"]
        if fail:
            args.append("--fail-writeback")
        with log.open("w") as output:
            proc = subprocess.Popen(args, stdout=output, stderr=output)
        self.processes[root] = proc
        self.logs[(root, count)] = log

        def ready():
            if proc.poll() is not None:
                raise AssertionError(log.read_text())
            return "READY " in log.read_text()
        wait_for(ready, "native mount ready")
        return root

    def info(self, root):
        return json.loads(self.run("inspect", root).stdout)

    def synced(self, root, expected):
        wait_for(lambda: self.info(root)["inSync"], "matching save marked in sync")
        check((root / "hello.txt").read_bytes() == expected, "saved bytes match exactly")

    def stop(self, root):
        self.run("stop", root)
        check(self.processes[root].wait(timeout=10) == 0, "provider stops cleanly")
        check(not self.info(root)["mounted"], "owned mount detached")

    def crash(self, root):
        self.processes[root].kill()
        self.processes[root].wait(timeout=10)

    def recovery_contains(self, root, expected):
        key = hashlib.sha256(str(root).encode()).hexdigest()
        return any(p.read_bytes() == expected for p in (self.store / "roots" / key / "recovery").glob("*.bin"))

    def fresh_read(self, name, expected):
        root = self.start(name)
        check(self.info(root)["onDisk"] == 0, "fresh root starts unhydrated")
        check((root / "hello.txt").read_bytes() == expected, "fresh root reads durable backing bytes")
        self.stop(root)

    def close(self):
        for root, proc in self.processes.items():
            if proc.poll() is None:
                result = self.run("stop", root, success=False)
                if result.returncode:
                    proc.kill()
                proc.wait(timeout=10)
            self.run("remove", root, self.store, success=False)


def exercise(probe):
    root = probe.start("ordinary")
    hello = root / "hello.txt"
    info = probe.info(root)
    check(os.listdir(root) == ["hello.txt"] and hello.stat().st_size == 77 and hello.stat().st_blocks == 0,
          "metadata listing exposes logical size without payload allocation")
    check(info["fetchedBytes"] == 0 and info["onDisk"] == 0 and info["inSync"],
          "metadata-only root fetches zero payload bytes")
    original = hello.read_bytes()
    check(len(original) == 77 and original.startswith(b"Hello from Writ!"), "first read hydrates public fixture")
    check(probe.info(root)["fetchedBytes"] == 77, "hydration fetch counted exactly once")

    # A retained descriptor tests writes themselves, not just an open blocked
    # by path lookup. Rename is a second independent native operation.
    fd = os.open(hello, os.O_RDWR)
    temporary = root / "pending.tmp"
    temporary.write_bytes(b"replacement queued behind native guard\n")
    lock = subprocess.Popen([probe.exe, "probe-lock", root], stdin=subprocess.PIPE,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    try:
        check(bool(select.select([lock.stdout], [], [], 10)[0]), "native guard probe responds")
        check(lock.stdout.readline().strip() == "LOCK_PROBE_READY", "commit guard retained")
        with concurrent.futures.ThreadPoolExecutor(2) as workers:
            write = workers.submit(os.pwrite, fd, b"guarded", 0)
            rename = workers.submit(os.replace, temporary, root / "renamed.tmp")
            time.sleep(.3)
            blocked = not write.done() and not rename.done()
            lock.stdin.write("RELEASE\n"); lock.stdin.flush()
            check(lock.wait(timeout=10) == 0, "native guard released")
            check(blocked, "competing write and rename block throughout commit guard")
            check(write.result(timeout=10) == 7, "queued native write resumes")
            rename.result(timeout=10)
    finally:
        os.close(fd)
        if lock.poll() is None:
            lock.kill(); lock.wait(timeout=10)

    saved = b"short save\n"
    hello.write_bytes(saved)
    probe.synced(root, saved)
    check(probe.recovery_contains(root, saved), "ordinary save keeps recovery bytes")
    probe.crash(root)
    probe.fresh_read("fresh-after-kill", saved)
    root = probe.start("ordinary")  # Same-root dead-mount recovery.
    check((root / "hello.txt").read_bytes() == saved, "same-root restart retains committed cache")
    replacement = b"atomic editor replacement\n"
    (root / "editor.tmp").write_bytes(replacement)
    os.replace(root / "editor.tmp", root / "hello.txt")
    probe.synced(root, replacement)
    probe.stop(root)
    check((root / "hello.txt").read_bytes() == replacement, "stop materializes hydrated bytes")
    offline = b"edited while provider was stopped\n"
    (root / "hello.txt").write_bytes(offline)
    root = probe.start("ordinary")
    probe.synced(root, offline)
    probe.fresh_read("fresh-offline", offline)
    (root / "hello.txt").write_bytes(b"")
    probe.synced(root, b"")
    probe.fresh_read("fresh-empty", b"")
    (root / "hello.txt").write_bytes(offline)
    probe.synced(root, offline)
    probe.stop(root)

    failed = probe.start("failure", fail=True)
    unsaved = b"retain my failed local save\n"
    (failed / "hello.txt").write_bytes(unsaved)
    wait_for(lambda: probe.recovery_contains(failed, unsaved), "failed write recovery")
    check(not probe.info(failed)["inSync"], "failed backing write stays out of sync")
    check((failed / "hello.txt").read_bytes() == unsaved, "failed write preserves local bytes")
    probe.fresh_read("fresh-failure", offline)
    probe.crash(failed)
    failed = probe.start("failure")
    probe.synced(failed, unsaved)
    probe.fresh_read("fresh-retry", unsaved)
    probe.stop(failed)

    winner, stale = probe.start("winner"), probe.start("stale")
    winner_bytes, stale_bytes = b"winning save\n", b"stale local edit must survive\n"
    (winner / "hello.txt").write_bytes(winner_bytes)
    probe.synced(winner, winner_bytes)
    (stale / "hello.txt").write_bytes(stale_bytes)
    wait_for(lambda: probe.recovery_contains(stale, stale_bytes), "stale recovery")
    check(not probe.info(stale)["inSync"], "stale base is not marked in sync")
    probe.stop(stale)
    check((stale / "hello.txt").read_bytes() == stale_bytes, "stop retains conflicting local bytes")
    stale = probe.start("stale")
    time.sleep(.7)
    check(not probe.info(stale)["inSync"], "restart never silently rebases conflict")
    probe.fresh_read("fresh-conflict", winner_bytes)
    probe.stop(stale)

    # Busy cleanup must fail without deleting the provider or detaching files.
    held = os.open(winner / "hello.txt", os.O_RDONLY)
    try:
        check(probe.run("stop", winner, success=False).returncode != 0, "cleanup refuses live file handles")
        check(probe.info(winner)["mounted"], "refused cleanup leaves provider available")
    finally:
        os.close(held)
    probe.stop(winner)
    check((winner / "hello.txt").read_bytes() == winner_bytes, "cleanup preserves winner bytes")
    print("ALL LINUX NATIVE PARITY CHECKS PASSED", flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--package", type=Path, required=True)
    parser.add_argument("--base", type=Path, required=True)
    args = parser.parse_args()
    probe = Probe(args.package, args.base)
    try:
        exercise(probe)
    finally:
        probe.close()
