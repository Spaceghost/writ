# The Bend native runtime's host surface

Writ's policy is Bend 2. A native build is one generated C file that contains
the program and the Bend runtime together. Every host target, including the
proposed [unikernel appliance](../openspec/changes/add-unikernel-appliance-host/proposal.md),
the [freestanding runtime](../openspec/changes/add-freestanding-bend-runtime/proposal.md),
Genode, and the future Drift-backed kernel, must supply what that generated file
asks of its host. This inspection records that surface for **Bend 2.0.39** so
the [runtime host profile](../openspec/changes/add-bend-runtime-host-profile/proposal.md)
has a concrete starting inventory.

Inspected on 2026-11-03 by emitting C for a one-line `IO.print` program with
`bend hello.bend -o hello.c` from the pinned toolchain. The emitted file was
3,074 lines. Nothing here changes Writ's policy model; it describes an upstream
compiler artifact and must be redone for any other Bend version.

## What the generated C uses from the host

| Area | Calls observed | Why the runtime needs it |
| --- | --- | --- |
| Memory | `mmap` with `MAP_ANON \| MAP_NORESERVE`, `mprotect`, `munmap` | Reserves the term heap and a 2 GiB evaluation stack with a guard page |
| Faults | `sigaltstack`, `sigaction(SIGSEGV)`, `sigaction(SIGBUS)`, `signal(SIGPIPE)` | Turns a stack overflow or bad access into a fail-stop error message |
| Threads | `pthread_create`, mutex, condvar, `pthread_detach`, `sched_yield` | One worker per `--threads` lane plus up to a bounded pool of IO helper threads |
| Clock | `clock_gettime(CLOCK_MONOTONIC)`, `nanosleep` | `IO.now`, `IO.sleep`, deadlines |
| Event loop | `pipe`, `fcntl(O_NONBLOCK)`, `select`, `read`, `write` | Wakes the loop when a helper thread finishes an effect |
| Process | `getenv("BENDRTS")`, `exit`, `sysconf(_SC_NPROCESSORS_ONLN)`, `sched_getaffinity`, cgroup `cpu.max` reads | Runtime options, exit status, default thread count |
| Atomics | C11 `stdatomic` operations and fences | Shared heap and scheduler state across lanes |
| GPU | `fopen`, CUDA driver and NVRTC, or Metal | Only when `!` calls are compiled for a device; absent with `--gpu off` on a machine without a device |

Effects are registered per program. Each effect the program uses contributes a
constructor that fills a row in an effect table; a request for an effect with no
row fails with "an alien request". A monitor that only uses `IO.print` and `IO.die`
therefore links no socket, file, audio, or process-spawning effect code, even
though the headers for those remain in the emitted file.

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
