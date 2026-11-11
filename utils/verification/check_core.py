#!/usr/bin/env python3
"""Check captured core test output; this is development tooling, not Writ policy.

The producer must also exit successfully. A log alone cannot establish which
program ran, authenticate evidence, or qualify a native host or GPU.
"""

import argparse
from pathlib import Path
import re
import sys

SUCCESS = "ALL LIBRARY TESTS PASSED"
DEFAULT_COUNT = Path(__file__).with_name("core-check-count.txt")


def read_count(path):
    raw = path.read_bytes()
    if not re.fullmatch(rb"[1-9][0-9]{0,4}\n", raw):
        raise ValueError("count must be one positive decimal integer (1..99999) followed by LF")
    return int(raw)


def check_output(lines, expected):
    passes = 0
    successes = 0
    last = None
    for number, raw in enumerate(lines, 1):
        line = raw.rstrip("\r\n")
        if line.startswith("FAIL"):
            raise ValueError(f"failure record at line {number}")
        if line.startswith(("PASS:", "PASS ")):
            passes += 1
        if line == SUCCESS:
            successes += 1
        last = line
    if successes != 1 or last != SUCCESS:
        raise ValueError("expected exactly one success marker, on the final line")
    if passes != expected:
        raise ValueError(f"expected {expected} PASS records, found {passes}; review the suite and shared count")
    return passes


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--count-file", type=Path, default=DEFAULT_COUNT)
    parser.add_argument("--print-count", action="store_true", help="validate and print the reviewed count")
    parser.add_argument("log", nargs="?", type=Path)
    args = parser.parse_args()
    if args.print_count == (args.log is not None):
        parser.error("provide either a log file or --print-count")
    try:
        count = read_count(args.count_file)
        if args.print_count:
            print(count)
        else:
            with args.log.open(encoding="utf-8") as stream:
                check_output(stream, count)
            print(f"Verified {count} core checks; final success marker present.")
    except (OSError, UnicodeError, ValueError) as error:
        print(f"Core verification failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
