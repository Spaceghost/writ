#!/usr/bin/env python3
"""Read-only Linux cgroup observations; this program cannot launch or signal.

Exit 2 always means the invocation supervisor is unavailable/incomplete.
Writability observations do not attest to isolation or another process's rights.
"""
import json
import os
import pathlib
import sys


def decode_mount_field(value):
    escapes = {"040": " ", "011": "\t", "012": "\n", "134": "\\"}
    result = []
    index = 0
    while index < len(value):
        if value[index] != "\\":
            result.append(value[index])
            index += 1
            continue
        code = value[index + 1:index + 4]
        if code not in escapes:
            raise ValueError("malformed mountinfo escape")
        result.append(escapes[code])
        index += 4
    return "".join(result)


def safe_absolute_path(value):
    if (not value.startswith("/") or os.path.normpath(value) != value or
            any(ord(character) < 32 for character in value)):
        raise ValueError("unsafe or ambiguous cgroup path")
    return value


def inspect():
    result = {"status": "incomplete", "launch_supported": False,
              "signals_supported": False, "observations": [],
              "reason": "No reviewed real supervisor or verified no-migration boundary exists."}
    if not sys.platform.startswith("linux"):
        result["observations"].append("Linux cgroup inspection unavailable")
        return result
    try:
        entries = pathlib.Path("/proc/self/cgroup").read_text().splitlines()
        groups = [line[3:] for line in entries if line.startswith("0::")]
        if len(groups) != 1:
            raise ValueError("unified cgroup membership is missing or ambiguous")
        group = pathlib.PurePosixPath(safe_absolute_path(groups[0]))
        candidates = []
        for line in pathlib.Path("/proc/self/mountinfo").read_text().splitlines():
            before, after = line.split(" - ", 1)
            if after.split()[0] != "cgroup2":
                continue
            parts = before.split()
            root, mount = map(decode_mount_field, (parts[3], parts[4]))
            root, mount = map(safe_absolute_path, (root, mount))
            try:
                relative = group.relative_to(pathlib.PurePosixPath(root))
            except ValueError:
                continue
            candidates.append((len(root), pathlib.Path(mount) / str(relative)))
        if not candidates:
            raise ValueError("unified cgroup mount could not be identified")
        candidates.sort(key=lambda item: item[0], reverse=True)
        if len(candidates) > 1 and candidates[0][0] == candidates[1][0]:
            raise ValueError("unified cgroup mount is ambiguous")
        current = candidates[0][1]
        procs = current / "cgroup.procs"
        if not procs.exists():
            raise ValueError("current cgroup.procs is unavailable")
        # Access checks are observations under this process's current credentials,
        # not proof about a future workload or all principals with access.
        result["observations"].append("current cgroup: " + str(current))
        result["observations"].append("current cgroup.procs writable: " +
                                      str(os.access(procs, os.W_OK, effective_ids=True)).lower())
        for name in ("cgroup.events", "cgroup.type", "cgroup.kill"):
            result["observations"].append(name + " present: " + str((current / name).exists()).lower())
    except (OSError, ValueError, IndexError, NotImplementedError) as error:
        result["observations"].append("inspection incomplete: " + str(error))
    return result


if __name__ == "__main__":
    if len(sys.argv) != 1:
        print("This preflight accepts no workload or options.", file=sys.stderr)
        sys.exit(2)
    print(json.dumps(inspect(), indent=2, sort_keys=True))
    sys.exit(2)
