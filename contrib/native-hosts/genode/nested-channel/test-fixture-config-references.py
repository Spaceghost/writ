#!/usr/bin/env python3
"""Offline fixed-source parity controls; no execution of Genode or QEMU."""
import hashlib
from pathlib import Path
from zipfile import ZipFile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
PINS = {
    "writ_guard_positive.args": (1709, "9832324d540f478108e0df4063468163702be4b2716ffb0663e59e35fe7e577e"),
    "writ_guard_negative.args": (1667, "bb05c8aef62045425f71da1fee373b06e9b8539adc457592fdb50266856fe48c"),
    "writ_bend_monitor_nested_route_negative.run": (3525, "175a8e32cceaa6c4d38498a95e7754fc4fe5438ad0960a2ebadccb2f808e0c6e"),
}


def valid(data, length, digest):
    return len(data) == length and hashlib.sha256(data).hexdigest() == digest


def check(ok, name):
    if not ok:
        raise SystemExit("FAIL: " + name)
    print("PASS: " + name)


for name, (length, digest) in PINS.items():
    data = (HERE / name).read_bytes()
    check(valid(data, length, digest), "fixed_pin_" + name)
    altered = bytes([data[0] ^ 1]) + data[1:]
    check(not valid(altered, length, digest), "corrupt_reference_rejected_" + name)
    check(not valid(data, length, "0" * 64), "corrupt_pin_rejected_" + name)

vectors = {}
for scenario in ("positive", "negative"):
    with ZipFile(ROOT / "verification" / "genode-route-retry-42361441863" / "raw" / (scenario + ".zip")) as z:
        info = z.getinfo("installed-config.txt")
        check(info.file_size <= 16384, "archived_installed_bound_" + scenario)
        raw = z.read(info)
        expected = (HERE / ("writ_guard_" + scenario + ".args")).read_bytes()
        check(raw == expected + b"\n", "independent_archived_config_" + scenario)
        vectors[scenario] = expected
        if scenario == "negative":
            info = z.getinfo("actual.run")
            check(info.file_size <= 16384, "archived_fixture_bound")
            check(z.read(info) == (HERE / "writ_bend_monitor_nested_route_negative.run").read_bytes(), "negative_fixture_exact_archive")

line = b"  |     + service Writ_channel | + parent\n"
check(vectors["positive"].count(line) == 1 and vectors["positive"].replace(line, b"") == vectors["negative"], "only_negative_route_removed")
for scenario, data in vectors.items():
    check(data.isascii() and b"\0" not in data and data.endswith(b"\n"), "reference_ascii_" + scenario)
print("ALL FIXTURE REFERENCE CONTROLS PASSED (offline only)")
