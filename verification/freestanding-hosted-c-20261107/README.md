# Hosted references from frozen Bend C, 2026-11-07

The [initial C freeze](../freestanding-c-freeze-20261107/README.md) produced
separate historical and current `Tests.c` files. A custom hosted Linux build
used `clang -std=c11 -O2 -static <Tests.c> -o <Tests> -lpthread -lm` and ran
successful builds with `+RTS --threads 1 --gpu off`. These are explicitly
recorded static compiler flags; they do not establish that the binaries are
identical to Bend's own native build. No freestanding image, emulation, native
confinement or GPU execution is evidenced.

## Historical suite

The input was the C frozen from source
`28a10fefa09fc2250b65e24b01a65535765aba36`, SHA-256
`a7d7c6537c73256e24aacd8e998d3b8dfa7df70ab9b8998faba341ec67164671`.
Its build exited 0 with empty stdout and stderr. The resulting static binary,
SHA-256 `4fb1c6d9f594aa97097c4f1ef4835517c90ea6d8b07f5ff453fc83cee67fcf88`,
ran with exit 0 and empty stderr. The complete [stdout](historical.stdout)
contains 638 PASS lines, ends `ALL LIBRARY TESTS PASSED`, and has SHA-256
`4c541b0077cea099fc568fab8a5c5b8c8a3c46462781903cc26828e4049e95e0`.
It compared byte-for-byte equal (`cmp` exit 0) to the earlier
[historical single-lane capture](../runtime-profile-parity-1.txt).
The earlier record's original worktree provenance remains unproven.

## Current suite, 8 GiB attempt

The input was the C frozen from source
`bbaca70559efb72d6adc416874ad25db1786fe70`, SHA-256
`d71c26a430a92aae69b5dc16a98dc27194d783be57a00ae923c779cbdd8a4b3c`.
Under the configured 8 GiB virtual-memory limit, the static build exited 134;
[compiler stderr](current-8g-build.stderr) reports `LLVM ERROR: out of memory`
during LLVM IR generation. There was no executable or run for this attempt.
The input C passed its before/after hash checks. This records the observed
failure under that limit; it does not establish a general compiler defect or
whether any other configuration succeeds.

## Current suite, 16 GiB retry

One separate retry used the same compiler, flags and frozen current C with a
16 GiB virtual-memory cap and the same 600-second build timeout. Immediately
before launch the recorded `MemAvailable` was 77,307,728 KiB, above the
40 GiB precondition. The build reached the timeout and exited 124; its stdout
and stderr were empty. No executable or run resulted. The input passed both
before and after checks against the committed freeze hash. No further retry
was attempted. The 8 GiB failure and this timeout are distinct observations.

## Scope and limits

Both suites were compiled serially at nice 15 with a 600-second wall and CPU
time cap, 8 GiB virtual-memory cap, bounded file size, and core dumps disabled.
The successful historical run had the same scheduling, wall/CPU and file
caps and a 20 GiB virtual-memory cap for Bend's reservations. `BENDRTS` was
unset. The retry used the limits above except for its 16 GiB build cap. Compiler,
linker, libc, commands, times, logs, statuses, and hash checks are preserved in
the [capture archive](captures.tar.gz), SHA-256
`5c4ccf8980713f824dff56a76fba0e210825102d026e9565577e391a4aac926c`.
It contains no generated C or binaries. After the attempts, the 13 locally
retained C files were rechecked against the committed freeze inventory and
all matched; this includes both suite inputs. The captured per-build checks
also show each tested C matched before and after its build.

The historical example C files, current examples, and Hello C were not built
or run by this record. The current suite still needs a successful hosted run
from the exact frozen C. Both suites and the applicable examples need separate
freestanding builds and comparisons. Task 2.1 remains open.
