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
