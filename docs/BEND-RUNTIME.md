# The Bend native runtime's host surface

Writ's policy is Bend 2. A native build is one generated C file that contains
the program and the Bend runtime together. Every host target, including the
proposed [unikernel appliance](../openspec/changes/add-unikernel-appliance-host/proposal.md),
the [freestanding runtime](../openspec/changes/add-freestanding-bend-runtime/proposal.md),
Genode, and the future Drift-backed kernel, must supply what that generated file
asks of its host. This inspection records that surface for **Bend 2.0.39** so
the [runtime host profile](../openspec/changes/archive/2026-11-04-add-bend-runtime-host-profile/proposal.md)
has a concrete starting inventory.

Inspected on 2026-11-03 by emitting C for a one-line `IO.print` program with
`bend hello.bend -o hello.c` from the pinned toolchain. The emitted file was
3,074 lines. Nothing here changes Writ's policy model; it describes an upstream
compiler artifact and must be redone for any other Bend version.

The inspection is repeatable: `sh scripts/runtime-profile/inventory.sh`, run
from the repository root, emits C for
[`scripts/runtime-profile/Hello.bend`](../scripts/runtime-profile/Hello.bend)
into `../writ-build/runtime-profile/` and records the extracted host calls and
effect rows in
[`verification/runtime-inventory-bend-2.0.39.txt`](../verification/runtime-inventory-bend-2.0.39.txt).
The table below was reconciled against that record. The extraction is textual,
so it also counts calls in code compiled only for CUDA or Metal.

## What the generated C uses from the host

| Area | Calls observed | Why the runtime needs it |
| --- | --- | --- |
| Memory | `mmap` with `MAP_ANON \| MAP_NORESERVE`, `mprotect`, `munmap` | Reserves the term heap and a 2 GiB evaluation stack with a guard page; a failed reservation fails stop with `reservation failed` |
| Faults | `sigaltstack`, `sigaction(SIGSEGV)`, `sigaction(SIGBUS)`, `signal(SIGPIPE)`; the handler uses `write(2)`, `signal(SIG_DFL)`, and `raise` | Turns a stack overflow or bad access into a fail-stop error message, then re-raises the signal |
| Threads | `pthread_create`, `pthread_mutex_lock`/`unlock`, `pthread_cond_wait`/`signal`/`broadcast`, `pthread_detach`, `pthread_self`, `sched_yield` | One worker per `--threads` lane plus up to a bounded pool of IO helper threads; `pthread_self` lets the first failing thread claim the error report |
| Clock | `clock_gettime(CLOCK_MONOTONIC)`, `nanosleep` | `IO.now`, `IO.sleep`, deadlines, and the wait of a thread that lost the error claim |
| Event loop | `pipe`, `fcntl(O_NONBLOCK)`, `select`, `read`, `write` | Wakes the loop when a helper thread finishes an effect |
| Process | `getenv("BENDRTS")`, `exit`, `sysconf(_SC_NPROCESSORS_ONLN)`, `sched_getaffinity`, and `fopen`/`fscanf`/`fclose` of cgroup `cpu.max` (or the cgroup v1 `cpu.cfs_quota_us` and `cpu.cfs_period_us`) on Linux; `_exit(1)` on a runtime failure | Runtime options, exit status, default thread count |
| Allocation and text | `malloc`, `calloc`, `realloc`, `free`, `strdup`, `snprintf`, and C stdio for program output | Option parsing, IO work records, strings passed to effects |
| Atomics | C11 `stdatomic` operations (`atomic_load_explicit`, `atomic_store_explicit`, `atomic_fetch_*_explicit`, compare-exchange) and the `__atomic_exchange_n`/`__atomic_store_n` builtins for host spin locks | Shared heap and scheduler state across lanes |
| GPU | CUDA driver (`cu*`) and NVRTC (`nvrtc*`) calls plus `open` and `fopen` of the cached device program under `BEND_CUDA`; Metal (`MTLCreateSystemDefaultDevice` and Objective-C messages) under `__OBJC__` | Only when `!` calls are compiled for a device; the Hello binary built here with `bend -o` imports no CUDA or NVRTC symbol even though a CUDA toolkit is installed |

`fopen`, `fscanf`, and `fclose` therefore belong to both the process and the
GPU rows: a Linux monitor that drops the GPU code still reads its cgroup quota
with them at startup, because `main` computes the default thread count before
it parses `--threads`.

Effects are registered per program. Each effect the program uses contributes a
constructor, such as `io_print_use`, that calls `io_eff(CID_IO_print, io_print_run)`
to fill a row in an effect table; a request for an effect with no row fails with
"an alien request". The Hello program registers exactly one row, `IO.print`.
The exit path is not a row: the IO loop handles the `Halt` request (from
`IO.die`) and the `Exit` request (from `IO.exit`), and the `Emit` that finishes a
task, before it consults the table, so every program has them. A monitor
that only uses `IO.print` and `IO.die` therefore links no socket, file, audio,
or process-spawning effect code, even though the headers for those remain in
the emitted file.

In the built binary the constructor is gone: `bend -o` compiles at `-O2`, and
clang evaluates `io_print_use` at compile time and drops it (it is present at
`-O0`). The external `io_print_run` stays as a global text symbol, so a check
of the binary reads effect rows from `<prefix>_run` symbols rather than from
`_use` constructors.

## Observed on this machine

| Check | Result |
| --- | --- |
| `clang -O2 -static hello.c` on Linux x86_64 (clang 23.1.1) | Builds a 1.1 MB statically linked executable |
| `./hello-static +RTS --threads 1 --gpu off` | Prints `hi` and exits 0 |
| Drift `tools/check-kernel.sh` (Spaceghost/drift `0b7aaca`, GCC 16.2.1, QEMU 11.1.2) | Builds the 32-bit reference kernel; under local QEMU it prints `Drift reference kernel` and exits before any device test passes, so the check fails here |

The static build matters because a Linux-binary-compatible unikernel consumes an
ordinary ELF executable. The Drift result is recorded as observed: it is not a
qualification of the reference kernel on this QEMU and compiler combination, and
it does not change what [docs/DRIFT.md](DRIFT.md) reports from the pinned
upstream records.

## Consequences for host targets

- A Linux-compatible unikernel must implement the rows above for the monitor
  profile. Thread creation, anonymous memory reservation, signal delivery on an
  alternate stack, a monotonic clock, and a self-pipe are the ones most likely
  to be missing or different.
- A freestanding port replaces `mmap` with an arena, pthreads with either a
  single lane or kernel threads, signals with a fault handler that halts, and
  the self-pipe with a direct completion queue. The reference evaluator and the
  effect table do not change.
- Drift's reference kernel is 32-bit Multiboot. The Bend term is a 64-bit word and
  the runtime is written for 64-bit hosts, so the freestanding route needs a
  long-mode kernel variant or a separately qualified 32-bit runtime build.
- Whatever the host, `--gpu off` behavior is the only one reachable without a
  device. Reporting it as GPU execution is prohibited by `AGENTS.md`.

The inventory above is the baseline for the runtime host profile's allowlist. A
profile that admits more host symbols than the monitor needs widens the
trusted base for no benefit; a profile that admits fewer cannot run the corpus.

The monitor profile derived from it is two allowlists,
[`scripts/runtime-profile/monitor-symbols.txt`](../scripts/runtime-profile/monitor-symbols.txt)
(exact import names, the inventory less the device group plus the startup,
stdio, and string imports `nm -u` shows for Hello on glibc) and
[`scripts/runtime-profile/monitor-effects.txt`](../scripts/runtime-profile/monitor-effects.txt)
(`IO.print`, `IO.print_err`, `IO.now`, `IO.sleep`; the exit path is
loop-handled, not a row). Each file records why its denied groups are denied.
`sh scripts/runtime-profile/check-binary.sh BINARY` reads a produced, dynamically
linked binary and exits 1 naming every import and effect outside them. For a
statically linked binary it checks the linked effect rows only and reports the
import comparison as not applicable, so a static pass says nothing about the
host-symbol surface. It finds effect rows by their `<prefix>_run` functions,
global or, after link-time optimization, local, and drops by exact name the
non-effect locals that match the same pattern (the runtime's `cube_run` and
`gpu_run`, and static glibc 2.44's `dlerror_run`); any other matching name is
mapped and denied unless allowlisted. It refuses (exit 2) a stripped binary, one
whose `io_eff_rows` table symbol is absent, and one in which no effect row is
found, rather than passing it; clang link-time optimization removes Hello's
`io_eff_rows`, so an LTO-built monitor is refused, not passed.
[`verification/runtime-profile-binary-check.txt`](../verification/runtime-profile-binary-check.txt)
records Hello passing and `scripts/runtime-profile/Widened.bend`, which adds
`TCP.listen`, failing on `TCP.listen` and the socket imports, dynamically, with
a plain static link, and with a static link-time-optimized link. A passing check
is one input to host qualification; it does not qualify a host by itself.
Reviewed-only gap: the check does not enforce the Bend version pin (RH-001
scenario 2). Its `_run` detection and effect-name mapping follow the C that
Bend 2.0.39 emits, so it must be re-validated for each toolchain before a
result is reused.

Lane parity and fail-stop were checked by execution on this Linux host, CPU
only with `--gpu off`.
[`verification/runtime-profile-parity.txt`](../verification/runtime-profile-parity.txt)
records `Tests.bend` and the four examples built natively and run with
`--threads 1` and `--threads 4`: 638 corpus PASS lines and 29 example PASS
lines at both lane counts, with no difference between the captures or from the
existing four-thread records.
[`scripts/runtime-profile/Overflow.bend`](../scripts/runtime-profile/Overflow.bend)
recurses without a tail call; at one billion levels it reaches the guard above
the 2 GiB evaluation stack, and
[`verification/runtime-profile-fault.txt`](../verification/runtime-profile-fault.txt)
shows the handler's `bend: memory fault (machine stack overflow?)`, no further
output, and exit status 139 from the re-raised `SIGSEGV`.
[`verification/runtime-profile-reservation.txt`](../verification/runtime-profile-reservation.txt)
shows Hello under `ulimit -v` failing the corpus or the stack reservation with
`bend: reservation failed` and exit 1, despite `MAP_NORESERVE`. These records
cover one host; they do not show that another host delivers the fault or
enforces the limit.
