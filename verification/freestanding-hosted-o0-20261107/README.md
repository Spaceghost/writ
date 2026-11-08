# Exploratory hosted `-O0` frozen-C run, 2026-11-07

The frozen current `Tests.c` was built once as a static hosted Linux program
with clang `-O0`, then run single-lane with GPU disabled. This exploratory
configuration printed 2,809 PASS lines and `ALL LIBRARY TESTS PASSED`, with
build and run exit 0 and empty stderr. It does not establish freestanding
execution or replace the separate [optimized build failures](../freestanding-hosted-c-20261107/README.md).
In particular, optimization changes the generated runtime's calling-convention
macro expansion, so this is not equivalent ABI or runtime evidence for `-O2`.

## Source and result

The generated C was frozen from source commit
`bbaca70559efb72d6adc416874ad25db1786fe70`; the
[committed freeze inventory](../freestanding-c-freeze-20261107/generated-sha256.txt)
identifies it as SHA-256
`d71c26a430a92aae69b5dc16a98dc27194d783be57a00ae923c779cbdd8a4b3c`.
It matched that hash before and after compilation and after execution. The
compiler command was:

```sh
clang -std=c11 -O0 -static /home/jadams/tmp/writ-freestanding-freeze-20261107/outputs/current/Tests.c -o /home/jadams/tmp/writ-freestanding-o0-20261107/Tests -lpthread -lm
```

The resulting binary SHA-256 was
`2b2653b2234aab3fe2778711f5365b29c8ae338f81fad54a65d0c3ef1c47d01f`.
Its command was `Tests +RTS --threads 1 --gpu off`; the full
[stdout](run.stdout) has SHA-256
`ff9b11443479d5338225ac55649f939b89ab637e5a707549afda11b6b11ed96c`.
`cmp` exited 0 against the [Windows Node stdout](../windev-model-bridge-20261107/full.stdout).
That Node capture came from source `810e8ee`; `git diff --exit-code 810e8ee
bbaca70 -- '*.bend'` exited 0 with no output, so the tracked Bend source files
are identical between these revisions. This cross-backend match concerns these
outputs only; it does not prove the runtime or host boundary equivalent.

## Optimization-dependent calling convention

The frozen C conditionally defines `PRESERVE(A)` using
`__has_attribute(preserve_none) && __has_attribute(preserve_most) &&
__OPTIMIZE__`. It applies that macro to `WL_FN`, `OUTLINE`, and the `WlFn`
type; the `musttail` attributes remain in the source. With this clang 23.1.1,
a separately written small preprocessor probe reproducing the condition
reported `PRESERVE_ATTRIBUTES_DISABLED` at `-O0` and
`PRESERVE_ATTRIBUTES_ENABLED` at `-O2`; both checks exited 0 with empty
stderr. This probe is not a preprocessing or ABI inspection of the entire
71 MiB generated file. Its complete source was:

```c
#if __has_attribute(preserve_none) && __has_attribute(preserve_most) && __OPTIMIZE__
PRESERVE_ATTRIBUTES_ENABLED
#else
PRESERVE_ATTRIBUTES_DISABLED
#endif
```

The probe source SHA-256 was
`b03c6c966b69f33ca1d8e8dd7b8b26da188c37b6eba67bffd4b3d2ed931ddd68`.
Exact commands and captures are in the archive below. The different macro
expansion is why the `-O0` result cannot be presented as equivalent to the
`-O2` attempt, even though both use the same generated C bytes.

## Conditions and preserved limits

The build ran serially at nice 15 with a 600-second wall and CPU limit,
16 GiB virtual-memory cap, bounded file size, and core dumps disabled. The
run used the same scheduling, time and file limits with a 20 GiB virtual-memory
cap for Bend's reservations. `BENDRTS` was unset. The immediate preflight
recorded 86,304,228 KiB available before build and 85,826,252 KiB before run;
both exceeded the 40 GiB minimum. No retry was attempted.

Compiler, linker, libc, commands, timestamps, statuses, raw output, macro
checks, input and output hashes, and source comparison are retained in
[captures.tar.gz](captures.tar.gz), SHA-256
`bb0b72103d0019102e2427630f93b6db7ce8e97baf9beae5d9ff275366de603a`.
The archive contains no generated C, probe C file, or native binary. Those
artifacts remain under `~/tmp` outside the source package. The earlier 8 GiB
`-O2` out-of-memory failure and 16 GiB `-O2` timeout remain intact. No
freestanding build or serial comparison occurred, and task 2.1 remains open.
