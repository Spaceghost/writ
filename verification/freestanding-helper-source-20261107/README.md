# Frozen Bend C: one-lane scheduler and IO helper source review

When a future freestanding monitor runs the frozen Writ corpus on one CPU
lane, it still needs to preserve the generated runtime's scheduling and IO
semantics. This source review narrows the helper-thread question for the
[13 frozen inputs](../freestanding-c-freeze-20261107/README.md); it does not
run a runtime or implement a host layer.

## Inputs and textual observations

The reviewed generated C files are the five historical inputs from
`28a10fefa09fc2250b65e24b01a65535765aba36` and the eight current inputs from
`bbaca70559efb72d6adc416874ad25db1786fe70`, including `Hello.bend`. Their
exact hashes and local scratch location are in the [freeze record](../freestanding-c-freeze-20261107/README.md).
The installed Bend 2.0.39 source inventory was checked against the freeze's
[toolchain inventory](../freestanding-c-freeze-20261107/bend-install-sha256.txt)
afterward. Both source and generated-C inventories identify the artifacts
inspected; neither establishes how future compilers or inputs behave.

The [scan](scan.txt), produced by [scan.sh](scan.sh), first verified all 13
generated C hashes against the committed freeze manifest. It then searched
the full generated files for the tokens `io_work`, `io_wait_on` and calls to
`io_eff`. Each file contains one `io_work` and one `io_wait_on` occurrence:
their static function definitions. Each contains the `io_eff` definition and
one registration, `io_eff(CID_IO_print, io_print_run)`. These are source-text
observations, not a compiled-binary or dynamic reachability analysis. The
local generated C is not committed and may be removed; verify or regenerate
and compare its hash before repeating the scan.

The same scan found `io_work` calls in the installed Base effect sources for
file open, read, size and write, process execution, and random generation.
Those source files are not evidence that the corresponding effect rows appear
in the frozen programs. A different program, compiler, or effect selection must
be re-inventoried; the observed absence is not a general rule that one-lane
Bend programs need no IO helpers.

To reproduce the textual scan from a checkout containing this record and a
retained freeze, use the absolute freeze-manifest path:

```sh
bash verification/freestanding-helper-source-20261107/scan.sh \
  /home/jadams/tmp/writ-freestanding-freeze-20261107/outputs \
  /home/jadams/.local/share/writ-toolchains/bend-2.0.39/bend \
  "$PWD/verification/freestanding-c-freeze-20261107/generated-sha256.txt"
```

## Control-flow implications

The following references are to the frozen current `Hello.c`; function names
and the recorded hash identify the exact file. The other frozen outputs have
the same recorded token observations, but those observations alone do not
prove that every runtime path is identical.

* `corpus_setup` bounds `pool_size` from the selected thread count.
  `pool_open` creates workers in a loop starting at one and stopping before
  `pool_size`: when that value is one, that loop creates no additional
  evaluator worker. `corpus_eval` can nevertheless call `pool_open` and
  `cube_run`, and `pool_turn` still uses mutex, condition-broadcast and
  `POOL_WAIT` code. One lane therefore does not establish that every
  synchronization primitive can safely be a no-op.
* `io_work` increments `io_busy`, may create and detach `io_help`, queues the
  work and returns `IO_PARK`. The helper waits on a condition, performs the
  call and writes its completion to the wake pipe. `io_take` reads the pipe,
  applies the saved pack function, requeues the continuation and decrements
  `io_busy`. Replacing that sequence with inline work would need to preserve
  ordering, accounting, errors and wake behavior; it is not demonstrated here.
* `io_loop` initializes a stack, ignores `SIGPIPE`, and opens a wake pipe before
  evaluating the program. Its loop can call `io_wait`, which handles queued
  completions and parked deadlines or descriptors through `select`. The
  `io_print_run` registered in these files performs output directly. The
  absence of textual `io_work` and `io_wait_on` uses beyond their definitions
  narrows these frozen inputs; it does not prove the event loop, pipe, clocks,
  waits, or failure handling can be omitted from an unchanged runtime.
* `main` calls `cpu_count` before parsing `--threads`; `--threads 1` alone does
  not remove that initialization path. The source also contains guard and
  signal setup in `pool_stack`. A host layer must account for the reachable
  behavior and failures, not just the effect names.

FR-001 requires the generated evaluator, scheduler and dispatch to remain
unchanged. The proposed inline helper and direct completion queue are not
validated by these observations; a host-symbol substitute must preserve the
original behavior, and a change to those generated components needs a
separately reviewed plan. No runtime, native confinement, GPU, or freestanding
claim is made, and no OpenSpec task is completed by this review.
