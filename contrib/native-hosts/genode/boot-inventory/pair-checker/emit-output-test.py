#!/usr/bin/env python3
"""Fixed, test-only bounded-pipe controls; no input data or secrets."""
import os
import sys

cases = {'stdout-cap': (1, 16384), 'stdout-over': (1, 16385),
         'stderr-cap': (2, 8192), 'stderr-over': (2, 8193)}
if len(sys.argv) != 2 or sys.argv[1] not in cases:
    raise SystemExit('unsupported synthetic output case')
fd, remaining = cases[sys.argv[1]]
while remaining:
    written = os.write(fd, b'x' * min(remaining, 4096))
    if written <= 0:
        raise SystemExit('synthetic output write failed')
    remaining -= written
