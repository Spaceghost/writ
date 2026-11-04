# Unikernels that could carry the Bend runtime

The theme for Writ's own-image deployments is **leverage an existing unikernel
and make the Bend runtime fit it**, not write a kernel. This note surveys the
candidates against the runtime surface recorded in [BEND-RUNTIME.md](BEND-RUNTIME.md)
and feeds the [library-unikernel runtime](../openspec/changes/add-unikernel-library-runtime/proposal.md)
and [appliance](../openspec/changes/add-unikernel-appliance-host/proposal.md)
changes. Surveyed 2026-11-03 from project documentation and papers; no
candidate was built or booted with Bend during this survey. Rows marked
"to verify" are claims the selection task must test, not facts established here.

## Two ways to fit

| Mode | What the image contains | Where the Bend runtime's host calls land |
| --- | --- | --- |
| **Binary compatibility** | The unmodified Linux ELF of the monitor plus a kernel that emulates enough of the Linux syscall ABI | The kernel's Linux-ABI layer; nothing in the Bend build changes |
| **Native link** | The generated C of the monitor compiled against the unikernel's own libc and linked into one kernel image | The unikernel's libc and core libraries directly; effects can be rewritten to call the kernel's APIs |

Binary compatibility is the fastest first boot and is the appliance change's
route. Native link is the end state the theme asks for: the monitor *is* the
kernel's only program, nothing is emulated that the monitor does not use, and
the effect table can be trimmed to the kernel's primitives.

## Candidates

| Unikernel | Shape | Threads, memory, faults, clock | Platforms and tooling | Licence and activity | Fit |
| --- | --- | --- | --- | --- | --- |
| **Unikraft** | Modular library OS; the application links against selected libraries; also has an ELF loader for binary compatibility | musl is the default libc since v0.11, with threads implemented through a `clone` syscall shim; `posix-mmap` library exists; fault handling to verify | KVM via QEMU and Firecracker, Xen, and a `linuxu` platform that runs the image as a Linux process for debugging; `kraft` build tool | BSD-3; active with regular releases | Strongest native-link candidate: the libc surface matches the runtime's needs on paper, and `linuxu` lets the port be debugged before any VM boot |
| **Nanos** | Linux-ABI kernel that runs one process with many threads; `ops` packages and boots an ELF | Threads yes; `mmap`, signals, and `select` to verify against the runtime | QEMU/KVM, cloud images; `ops` | Kernel Apache-2; vendor's prebuilt builds are commercial above a company-size threshold | Strongest binary-compatibility candidate; no native-link mode |
| **OSv** | Library OS that runs Linux ELF executables, including dynamically linked, with a full-featured POSIX layer | pthreads, `mmap`, `select`, and partial signals documented; mature C and JVM support | QEMU/KVM, Firecracker, Xen; `capstan` | BSD-3; community-maintained with a slower cadence | Good either way; the richest POSIX surface, so the least likely to miss a primitive, at the cost of a larger kernel |
| **HermitOS** | Rust kernel with a C ABI for applications built with its toolchain | Multithreading and a basic system interface; `mmap` and signal surface smaller, to verify | QEMU/KVM, Uhyve micro-hypervisor | MIT/Apache-2; active | Native-link only; worth a boot test, but its libc surface is the least like Linux of the four |
| Rumprun | NetBSD rump kernel; broad POSIX including pthreads | Broad, from NetBSD | Xen, KVM | BSD; largely dormant | Not recommended; activity too low to pin |
| IncludeOS | C++ library OS | C++ runtime; not a POSIX target | KVM | Apache-2; dormant | Not a fit |
| MirageOS on solo5 | OCaml library OS over the minimal solo5 tender interface | solo5 has no threads by design | KVM, seccomp tenders | ISC; active | Not a fit for the runtime, but solo5's tiny host interface is a useful reference for what a minimal Bend host could look like |

## What the selection task must check for each candidate

These map to the rows in BEND-RUNTIME.md. A candidate that lacks one may still
be usable if the runtime profile permits a substitute (a single lane removes
the thread rows; a halting trap replaces signals).

1. Anonymous reservation of several GiB with `MAP_NORESERVE` semantics, plus
   `mprotect` for the guard page, or an equivalent arena with a guard.
2. Thread creation and condition variables, or a declared single-lane mode.
3. A fault path that reaches the runtime's handler on an alternate stack, or a
   trap that halts with a recorded code. Resuming after a fault disqualifies.
4. A monotonic clock and a sleep that returns.
5. `pipe`, `fcntl(O_NONBLOCK)`, and `select` for the self-pipe, or a native
   completion queue if the effect loop is adapted.
6. `getenv`, `exit` with a status visible to the harness, and a sane answer for
   the CPU count.
7. Reproducible image builds, a serial console, and a way to run under QEMU
   and under a hardware-accelerated hypervisor separately.

## Recommendation for the first attempt

Try two in parallel, one per mode: **Nanos or OSv** in binary-compatibility
mode for the appliance (fastest to a booting corpus), and **Unikraft** in native
link mode for the library runtime (the theme's end state). Record both. The
appliance change may end up on whichever compat kernel boots the corpus first;
the library change should move to OSv only if Unikraft's libc proves to be
missing a primitive the runtime profile cannot waive.

None of this is a security claim. Every candidate is one address space, so the
image holds the monitor only, and the hypervisor, host kernel, and firmware stay
in the trusted base as the appliance change states.

## Selection matrix, 2026-11

Executed 2026-11-03 under the library-unikernel lane, Tasks 1 to 3. Every cell except those marked
"by construction" or "from documentation" comes from running an image; the evidence pointer names the block in
[unikernel-matrix-unikraft.md](../verification/unikernel-matrix-unikraft.md) (`E<n>`, and
Task 1's build matrix) or
[unikernel-matrix-osv.md](../verification/unikernel-matrix-osv.md) (`O-E<n>`). Pins are in
[unikernel-pins.txt](../verification/unikernel-pins.txt). All boot runs are emulated
boots under QEMU 11.1.2 with TCG; none is an accelerated boot and none is a device run.

The two columns are not the same kind of evidence. **Unikraft** is a native link: the
emitted C is the Unikraft application, built against lib-musl into one kernel image
(UL-001's mode). **OSv** is a compat observation: the emitted C is built by the host
toolchain into a Linux PIE and loaded by OSv's in-kernel ELF linker, which UL-001 excludes;
OSv has no mode that links application C into the kernel (from its documentation, not
built here).

| Row | Unikraft 0.21.0, `qemu/x86_64`, native link | OSv 0.57.0, `qemu/x86_64`, compat PIE |
| --- | --- | --- |
| Native link (UL-001) | **supplied**: links and boots with build adjustments A1 to A3, none in Bend output (Task 1 matrix) | **missing** (from documentation, not built): OSv documents no link-into-kernel application mode; the compat program runs through the ELF loader (mode note; O-E0 shows that loader rejecting a header, not the absence of a mode) |
| Memory | **supplied**, lazy: 8 GiB heap at the first hint and 2 GiB+guard stack; boots at `-m 8` (E1, E2) | **supplied**, lazy: heap at the third hint `1<<43`, stack mapped; boots at `-m 32` (O-E1, O-E2) |
| Faults | **substituted**: guard hit gives `CRIT: Unikraft Crash` and a halt; the runtime's handler never runs; QEMU 0 (E4) | **supplied**: the runtime's `bend: memory fault` message, then OSv powers off (`Uncaught signal 11` with `--verbose`); QEMU 0 (O-E4) |
| Memory exhaustion | **substituted**: the same Unikraft crash, QEMU 0 (E4, `-m 1024`) | **substituted**: OSv kernel `Aborted` in its page pool; halts without power-off, killed (O-E4, `-m 1024`) |
| Threads | **substituted** by a single lane: `pthread_create` returns 0, `pool_work` is not entered by shutdown; one CPU, cooperative (E5, E6) | **supplied**: second lane runs on one and on two vCPUs, correct results (O-E5, O-E6); but shutdown with an open pool **missing**: guest idles after `main` returns (O-E6) |
| Clock | **supplied** (E7) | **supplied** (O-E7) |
| Event loop | **supplied** with `posix-pipe` and `posix-poll` (A3); **missing** without them (E1, Task 1 A1+A2 run); the helper-thread wake path was not exercised | **supplied** (O-E1, O-E7); the helper-thread wake path was not exercised |
| Process: argv | **supplied** via `-append` (E3) | **supplied** via the kernel command line (O-E3) |
| Process: `BENDRTS` | **substituted**: build-time only, compiled into the environment (E8) | **supplied** at boot with `--env=` (O-E8) |
| Process: exit status | **missing**: return from `main` powers off with QEMU 0 whatever it returned; `exit`/`_exit` leave the guest idle until killed (E3, E9) | **substituted** (single lane): every exit path powers off with QEMU 0; the status appears only on the console with `--verbose` (O-E3, O-E9). The multi-lane hang is in the Threads cell; `IO.exit` with an open pool was not tried |
| Process: CPU count | **supplied** for one CPU (default `lanes 1`, E5); SMP not tried | **supplied**: 1 on `-smp 1`, 2 on `-smp 2` (O-E5) |
| Atomics | **supplied** by GCC's `stdatomic.h` (A1); exercised on one lane and one CPU only (E5, E9) | **supplied** by clang's `stdatomic.h`; exercised with two lanes on two vCPUs (TCG) (O-E5, O-E6) |
| Device dispatch | **missing** by construction: no accelerator code compiled, no `!` program run (E2) | **missing** by construction, the same (O-E2) |
| Reproducible image | **supplied**: rebuilds gave identical image hashes (unikernel-matrix-unikraft.md, "Build and run harness (outside the tree)", image hash table) | **supplied**: the probes image rebuilt to the same hash (unikernel-matrix-osv.md, "Image and executable hashes", rebuild line) |

`linuxu` is not a column: the pinned 0.21.0 has no `linuxu` platform, and the 0.16.3 run
(process execution, not a boot) stops at `bend: reservation failed` because `posix-mmap`
is unavailable there (E10).

### Chosen kernel for the native-link lane: Unikraft 0.21.0

- It is the only candidate that meets UL-001 at all. The OSv column's
  "Native link (UL-001)" cell is **missing** (from documentation, not built), and OSv's better cells (Faults **supplied**,
  Threads **supplied**) belong to the compat path, which the appliance change owns, not
  this one.
- Its native image already supplies the rows the first port needs: Memory **supplied**
  (E1, E2), Clock **supplied** (E7), Event loop **supplied** with A3 (E1, E7), argv
  **supplied** (E3), and a reproducible image.
- Its gaps are ones the runtime profile lets an effect twin or a declared mode close,
  rather than ones that need a different libc: Threads is a single lane (E6), which is
  what UL-005 asks for first; Faults is a halting trap with no resumption (E4), which
  RH-006 accepts once the code is recorded; the open problem is the exit status
  (**missing**, E3, E9), which is a platform shutdown path, not a libc primitive.
- The survey's fallback rule ("move to OSv only if Unikraft's libc proves to be missing a
  primitive the runtime profile cannot waive") is not triggered: in the A1 to A3
  configuration the only Unikraft cells marked **missing** are the exit status and device
  dispatch (by construction), and OSv does not supply a harness-visible status either
  (its cell is console-only).

### What the effect-twins task needs from Unikraft

1. **An exit path the harness can see.** Today every exit is QEMU status 0 or a hang
   (E3, E9), and a fault looks like success (E4). The exit twin needs a platform shutdown
   that carries a code: for example QEMU's `isa-debug-exit` device written by the exit
   twin and by the fault halt, with the run harness mapping its status, or a console
   record the harness parses and treats as authoritative. Either way the halt after
   `exit`, `_exit`, and the trap must power off instead of idling (E9), and corpus
   failure, arena exhaustion, and fault must give distinct codes (UL-006).
2. **A declared single-lane configuration.** Keep `UKPLAT_CPU_MAXCOUNT=1` and the
   cooperative scheduler, run with `+RTS --threads 1`, and use the inline IO helper
   (UL-005). On this kernel `--threads 2` creates a lane that never runs (E6), so a
   multi-lane build must not be configured by accident; SMP is a later task (2.4), and
   the OSv hang at shutdown with more than one lane (cause inferred, O-E6) should be
   investigated as part of it.
3. **The fault halt to carry the runtime's message.** The runtime's `SIGSEGV` handler
   does not run on Unikraft (E4); the halting fault handler (task 2.3) has to print the
   runtime's fault text, or an equivalent recorded line, before the coded halt.
4. **The A3 libraries kept or replaced.** The event loop needs `posix-pipe` and
   `posix-poll` (Task 1 A1+A2 run); an ingress twin that replaces the self-pipe could drop
   them, and UL-003's binary check decides which stay.

### Single most likely blocker, per candidate

- **Unikraft:** the exit status. No exit path reaches the harness (E3, E9), and until one
  does, RH-006 and UL-006 cannot be checked from the run's status.
- **OSv (for a native link):** the loader (from documentation, not built). OSv
  documents application loading only through its ELF linker (mode note in
  unikernel-matrix-osv.md; O-E0 shows the loader rejecting a header, not the absence of
  another mode), so UL-001 cannot be met without adding a link-into-kernel
  application mode to OSv itself.
