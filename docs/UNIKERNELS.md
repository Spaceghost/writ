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

## Port status (unikernel port lane, 2026-11-04)

The matrix below records the kernels **before** the port; where a cell has since changed,
it points here. Current state on Unikraft 0.21.0, QEMU TCG emulated boots, one lane:

- **Corpus parity:** `Tests.bend` (782 checks, merged tree aaa6885) prints 782 PASS lines
  and `ALL LIBRARY TESTS PASSED` with QEMU exit 33 (1 under the first exit map), its console identical line for line to a
  Linux `--threads 1 --gpu off` capture after removing only SeaBIOS output and Unikraft's
  banner; the four examples match likewise ([unikernel-corpus-qemu.txt](../verification/unikernel-corpus-qemu.txt)). Checked by
  `hosts/unikraft/scripts/check-corpus.sh` and `check-image.sh`, which exit nonzero when an
  expected outcome changes.
- **Exit status:** the exit hook `hosts/unikraft/exit_device.c` writes program statuses as
  s + 0x10, so success is QEMU 33 and `IO.die(…, 1, …)` is 35 (2s + 33 for s up to 108);
  a runtime or host-layer `_exit(1)` without `exit()` is 17, a signal death 19, a crash 253
  ([unikernel-fault-qemu.txt](../verification/unikernel-fault-qemu.txt); the first map,
  QEMU 1 for success, is in [unikernel-exit-codes.txt](../verification/unikernel-exit-codes.txt)).
  No outcome is QEMU 1, which QEMU returns on its own startup errors; success still needs
  the console check.
- **Faults:** with the posix signal library adopted in the template (2026-11-04, the
  Unikraft signals lane; pins below), a forced stack overflow (`scripts/unikernel/Overflow.bend`)
  prints the runtime's own line `bend: memory fault (machine stack overflow?)` before the
  Unikraft crash screen. The image still ends in a Unikraft crash
  (`Cannot deliver SIGSEGV`, `lib/posix-process/signal/deliver.c:428`) and the hook's crash
  value, QEMU 253; it does not resume. `check-fault.sh` requires the message line for the
  overflow probe and fails on the image built without signals (negative control)
  ([unikernel-fault-qemu.txt](../verification/unikernel-fault-qemu.txt), "Result" and
  "Fault message runs"). Arena exhaustion (`scripts/unikernel/Exhaust.bend`, `-m 1024`) is
  still a Unikraft crash with no message, QEMU 253: with signals it now crashes on an
  assertion in `lib/posix-process/signal/deliver.c:125` (the alternate stack already in
  use) instead of in `heap_alloc_miss`. The earlier record predicted the message would
  appear there; that prediction was wrong. Exhaustion therefore has neither the runtime's
  message nor a code of its own: it shares 253 with the fault, a recorded limit of UL-006
  ([unikernel-fault-qemu.txt](../verification/unikernel-fault-qemu.txt), "Arena
  exhaustion with signals"). The exit map is unchanged with the library present (success
  33, `IO.die` 35, `IO.exit(3)` 39, runtime stop 17, crash 253;
  [unikernel-exit-codes.txt](../verification/unikernel-exit-codes.txt), "CURRENT MAP,
  RE-RECORDED WITH POSIX SIGNALS"). Every run is a QEMU TCG boot on the CPU; no GPU test.
- **After a crash or `main`:** no reset observed; QEMU ends with 0, consistent with an ACPI
  power-off ([unikernel-crash-action.txt](../verification/unikernel-crash-action.txt)).
- **Console and time effects:** `Unikraft.log`, `Unikraft.now`, `Unikraft.sleep`
  (`hosts/unikraft/effects/Unikraft.bend`, `.c` twins over `hosts/unikraft/host.c`). For
  example, `scripts/unikernel/Probe.bend` built with `WRIT_HOST_LAYER=y` prints
  `probe: hello from Bend through the Unikraft console` on serial through the twin, reads
  102 to 103 ms around `Unikraft.sleep(100)`, and exits 1 (QEMU 3 then, 35 under the current map) when the delta leaves
  [100, 1100), shown once from a scratch build ([unikernel-effects-qemu.txt](../verification/unikernel-effects-qemu.txt), fix round 1).
  The sleep parks on the runtime's own timer (`io_wait_on`, as `IO.sleep` does), so the loop
  stays live and no helper thread is created: an `io_work` helper thread outlives `main` on
  this configuration and turned success into QEMU 255 (now 19, a signal death, by reading the map; not rerun) ([unikernel-effects-qemu.txt](../verification/unikernel-effects-qemu.txt), R0-E1).
  Gap: the re-park and clock-failure paths of `host.c` have never been exercised (no clock
  fault can be injected without patching Unikraft), and a fully stopped clock is bounded
  only by the harness timeout. `IO.print` still goes through lib-musl, not a twin.
- **Ingress (scaffolding):** `Unikraft.take` / `Unikraft.put` carry 64-byte records in
  80-byte frames over QEMU's second serial port (COM2, a Unix socket on the host;
  `hosts/unikraft/effects/Channel.md`). For example, the client probe's report-to-summary
  request reaches `hosts/unikraft/monitor/Monitor.bend`, which answers Committed (reason 0);
  the same plan naming S's session is Denied by `DataOS.commit_from_capability` (reason 6)
  ([unikernel-channel-qemu.txt](../verification/unikernel-channel-qemu.txt)). Gap: the
  subject is a build-time word, not a route; whoever reaches the socket speaks as it
  (UL-008 and the appliance host must close this). `take` polls COM2 on the runtime timer
  (10 ms idle, 1 ms while a frame is arriving) because COM2 has no descriptor or interrupt
  here, and its FIFO is off, so each wake collects about one byte: 0.14 to 0.56 s per
  request round trip under QEMU TCG (0.86 s with a fixed 10 ms poll). `host.c` answers at
  most 8 bad-length frames per boot and drops later ones; a client that never reads can
  still block a reply in `com_write`.
- **UL-004 amended:** the effect twins and the inventoried boot and termination host layer
  are the only kernel-specific code (the crash hook cannot be a twin; rationale in the
  change's tasks.md 2.1).
- **Host code:** listed in [hosts/unikraft/INVENTORY.md](../hosts/unikraft/INVENTORY.md).
- **Image configuration pins (trust inventory):** every `qemu/x86_64` image made from
  `hosts/unikraft/app/` (corpus, examples, effects probe, channel monitor, fault and exit
  probes) links Unikraft 0.21.0's `lib/posix-process` with POSIX signals,
  `CONFIG_LIBPOSIX_PROCESS_SIGNAL: 'y'` in `hosts/unikraft/app/Kraftfile`. The library is
  marked EXPERIMENTAL in `lib/posix-process/Config.uk:78` and selects
  `LIBPOSIX_PROCESS_MULTITHREADING`, `LIBPOSIX_PROCESS_EXECVE`, `LIBUKLOCK`, and
  `LIBUKLOCK_SEMAPHORE`. `hosts/unikraft/scripts/build.sh` passes
  `UK_CFLAGS="-std=gnu11 -include uk/config.h"` to every compilation unit: the include works
  around 0.21.0's include order in `lib/posix-process/shutdown.c` (`signal.h:116`'s guard
  reads 0, so the declaration at `signal.h:287` is skipped and `shutdown.c:63` fails to
  build); no Unikraft source is patched. Both are pins
  ([unikernel-pins.txt](../verification/unikernel-pins.txt), "Unikraft image configuration
  pins"); every image set was rebuilt with them and its checks rerun, the corpus at 782 PASS
  ([unikernel-corpus-qemu.txt](../verification/unikernel-corpus-qemu.txt),
  [unikernel-effects-qemu.txt](../verification/unikernel-effects-qemu.txt),
  [unikernel-channel-qemu.txt](../verification/unikernel-channel-qemu.txt),
  [unikernel-binary-check.txt](../verification/unikernel-binary-check.txt)).
- **Open:** an authenticated ingress subject (task 2.1, UL-008); a twin for `IO.print`
  (the "Console effect" scenario, 2.1); no resynchronisation of the channel after a
  partial frame (later frames are read shifted; with the refusal cap reached, the channel
  goes silent until the harness timeout); the take twin's busy-poll back-off is not traced;
  arena exhaustion ends in a Unikraft crash with no runtime message and shares the crash
  code 253 with a fault, so it has no code of its own (2.3's recorded limit,
  [unikernel-fault-qemu.txt](../verification/unikernel-fault-qemu.txt), "Arena exhaustion
  with signals"); the signal value 19 and the non-halt value 251 have not been exercised
  with the library; with signals, posix-process shutdown sends SIGTERM to an init process
  still running and waits for it (`lib/posix-process/shutdown.c:61-67`), a path reachable
  only by a program still running at shutdown and not exercised (no shipped image leaves a
  helper thread; a program that ignored SIGTERM would run until the harness timeout); statuses
  above 108 share 0x7f (QEMU 255); `timeout`'s own 125 and 127 equal the QEMU codes of
  program statuses 46 and 47; one gpuexample boot (of three) printed Unikraft's "PM driver
  failed the operation: -5" after the exit hook's port write, before QEMU exited with 33,
  cause unknown ([unikernel-corpus-qemu.txt](../verification/unikernel-corpus-qemu.txt),
  Task 3 rerun); more lanes (2.4); accelerated boots (3.1).

## Selection matrix, 2026-11

Executed 2026-11-03 under the library-unikernel lane, Tasks 1 to 3. Every cell except those marked
"by construction" or "from documentation" comes from running an image; the evidence pointer names the block in
[unikernel-matrix-unikraft.md](../verification/unikernel-matrix-unikraft.md) (`E<n>`, and
Task 1's build matrix) or
[unikernel-matrix-osv.md](../verification/unikernel-matrix-osv.md) (`O-E<n>`). Pins are in
[unikernel-pins.txt](../verification/unikernel-pins.txt). Every Unikraft and OSv boot run is an emulated
boot under QEMU 11.1.2 with TCG (the one `linuxu` run was process execution); none is an accelerated boot and none is a device run. Every Unikraft QEMU run in the matrix used `-no-reboot`, so in the matrix QEMU status 0 alone cannot distinguish a guest power-off from a guest reset; the unikernel port's Task 2 then ran the crash and the return from `main` without `-no-reboot` and observed no reset in either: QEMU ends by itself with 0, consistent with an ACPI power-off, and with a debug-exit device at Unikraft's default port 0x501 the same paths exit 85 (crash) and 83 (halt), showing that Unikraft's own `qemu_crash` and `qemu_exit`, whose last step is that power-off, ran ([unikernel-crash-action.txt](../verification/unikernel-crash-action.txt)). "Powers off" for those Unikraft paths therefore rests on those runs plus the source, not on a printed message (OSv prints "Powering off.", so its label was observed already).

The two columns are not the same kind of evidence. **Unikraft** is a native link: the
emitted C is the Unikraft application, built against lib-musl into one kernel image
(UL-001's mode). **OSv** is a compat observation: the emitted C is built by the host
toolchain into a Linux PIE and loaded by OSv's in-kernel ELF linker, which UL-001 excludes;
OSv has no mode that links application C into the kernel (from its documentation, not
built here).

| Row | Unikraft 0.21.0, `qemu/x86_64`, native link | OSv 0.57.0, `qemu/x86_64`, compat PIE |
| --- | --- | --- |
| Native link (UL-001) | **supplied**: links and boots with build adjustments A1 to A3, none in Bend output (Task 1 matrix) | **unverified (from documentation; no native-link attempt made)**: OSv's documentation describes no link-into-kernel application mode; the compat program runs through the ELF loader (mode note; O-E0 shows that loader rejecting a header, not the absence of a mode) |
| Memory | **supplied**, lazy: 8 GiB heap, first hint taken (inferred from no further calls; E2 printed the mmap arguments, not return values), and 2 GiB+guard stack; boots at `-m 8` (E1, E2) | **supplied**, lazy: heap at the third hint `1<<43`, stack mapped; boots at `-m 32` (O-E1, O-E2) |
| Faults | **substituted**: guard hit gives `CRIT: Unikraft Crash` and, inferred, a halt; the runtime's handler never runs; QEMU exits 0 under -no-reboot; power-off vs reset not distinguished (inferred) (E4) | **supplied**: the runtime's `bend: memory fault` message, then OSv powers off (`Uncaught signal 11` with `--verbose`); QEMU 0 (O-E4) |
| Guest RAM exhaustion (stack growth) | **substituted**: the same Unikraft crash; QEMU exits 0 under -no-reboot; power-off vs reset not distinguished (inferred); arena exhaustion not induced (E4, `-m 1024`, Overflow) | **substituted**: OSv kernel `Aborted` in its page pool; halts without power-off, killed (O-E4, `-m 1024`) |
| Threads | **substituted** by a single lane: `pthread_create` returns 0, `pool_work` was not entered before shutdown in a non-yielding program (E6); behaviour when the main lane yields not tried; one CPU, cooperative (E5, E6) | **supplied**: second lane runs on one and on two vCPUs, correct results (O-E5, O-E6); but shutdown with an open pool **missing**: guest idles after `main` returns (O-E6) |
| Clock | **supplied** (E7) | **supplied** (O-E7) |
| Event loop | **supplied** with `posix-pipe` and `posix-poll` (A3); **missing** without them (E1, Task 1 A1+A2 run); the helper-thread wake path was exercised later and works, but the never-ending helper thread turned success into QEMU 255 at shutdown under the first exit map (19, a signal death, under the current map; not rerun) ([unikernel-effects-qemu.txt](../verification/unikernel-effects-qemu.txt), R0-E1) | **supplied** (O-E1, O-E7); the helper-thread wake path was not exercised |
| Process: argv | **supplied** via `-append` (E3) | **supplied** via the kernel command line (O-E3) |
| Process: `BENDRTS` | **substituted**: build-time only, compiled into the environment (E8) | **supplied** at boot with `--env=` (O-E8) |
| Process: exit status | (matrix, before the port; see [unikernel-exit-codes.txt](../verification/unikernel-exit-codes.txt)) **missing**: return from `main` ends the run with QEMU 0 whatever it returned (power-off inferred; QEMU exits 0 under -no-reboot; power-off vs reset not distinguished (inferred)); `exit`/`_exit` leave the guest idle until killed (E3, E9) | **substituted** (single lane): every exit path powers off with QEMU 0; the status appears only on the console with `--verbose` (O-E3, O-E9). The multi-lane hang is in the Threads cell; `IO.exit` with an open pool was not tried |
| Process: CPU count | **consistent with supplied**; not distinguishable from the runtime's fallback at one CPU (default `lanes 1`, E5); SMP not tried | **supplied**: 1 on `-smp 1`, 2 on `-smp 2` (O-E5) |
| Atomics | **supplied** by GCC's `stdatomic.h` (A1); exercised on one lane and one CPU only (E5, E9) | **supplied** by clang's `stdatomic.h`; exercised with two lanes on two vCPUs (TCG) (O-E5, O-E6) |
| Device dispatch | **missing** by construction: no accelerator code compiled, no `!` program run (E2) | **missing** by construction, the same (O-E2) |
| Rebuild-stable image (not UL-008 reproducibility) | (matrix, before the port; see [unikernel-crash-action.txt](../verification/unikernel-crash-action.txt), Images) **incremental** rebuilds on one host and path gave identical image hashes (unikernel-matrix-unikraft.md, "Build and run harness (outside the tree)", image hash table), but **clean builds are not hash-stable**: Unikraft embeds the build time (`HOSTUTC`, `lib/uklibid`), and two clean builds differ in those bytes | **rebuild-stable on one host and path**: the probes image rebuilt to the same hash (unikernel-matrix-osv.md, "Image and executable hashes", rebuild line) |

`linuxu` is not a column: the pinned 0.21.0 has no `linuxu` platform, and the 0.16.3 run
(process execution, not a boot) stops at `bend: reservation failed` (E10). The
unikraft-linuxu lane (2026-11-04, [unikernel-linuxu.txt](../verification/unikernel-linuxu.txt))
traced the stop and recorded it as a stall: the failing reservation is the runtime's first one,
the fixed 8 GiB CPU heap (`corpus_map`, 13 `mmap` requests of `0x200000000` bytes with
`MAP_NORESERVE`), each answered `-ENOMEM` by Unikraft's own `lib/ukmmap`, which serves `mmap` as a
zeroed `uk_memalign` from the platform heap; `posix-mmap` cannot be configured there because it
needs `ukvmem`, which selects paging, and `linuxu` depends on `!HAVE_PAGING`. Of the three
attempts, no runtime option shrinks the heap or the 2 GiB stack (the generated C accepts only
`--threads`, `--gpu`, `--gpu-build` and `--help`); raising `CONFIG_LINUXU_DEFAULT_HEAPMB` came
closest, but the heap length is a 32-bit byte count, so 4095 MiB is the most the platform can map
(granted by the host, still under half of one 8 GiB request; 8196 wraps to 4 MiB); and `ukmmap`
has no lazily backed or reserving path for `MAP_NORESERVE`. The reference program therefore has
not run under `linuxu`, and getting further would need the generated C, the runtime, or Unikraft
changed, which the lane does not do. After the failure the process does not exit (killed, 124).

### Chosen kernel for the native-link lane: Unikraft 0.21.0

- The choice rests on Unikraft's executed cells: native link **supplied** (Task 1 A1+A2+A3
  row), so it is the one candidate here shown to meet UL-001. OSv's native-link status is
  **unverified** (documentation only, no attempt made) and is not a reason for the choice;
  OSv's better cells (Faults **supplied**, Threads **supplied**) belong to the compat path,
  which the appliance change owns, not this one.
- Its native image already supplies the rows the first port needs: Memory **supplied**
  (E1, E2), Clock **supplied** (E7), Event loop **supplied** with A3 (E1, E7), argv
  **supplied** (E3), and an image that is rebuild-stable only incrementally (matrix, before the port; clean builds embed the build time, see [unikernel-crash-action.txt](../verification/unikernel-crash-action.txt)).
- Its gaps are ones the runtime profile lets an effect twin or a declared mode close,
  rather than ones that need a different libc: Threads is a single lane (E6), which is
  what UL-005 asks for first; Faults is a halting trap with no resumption (E4), which
  RH-006 accepts once the code is recorded; the open problem was the exit status
  (**missing**, E3, E9; matrix, before the port; since supplied by the exit hook, see
  [unikernel-exit-codes.txt](../verification/unikernel-exit-codes.txt)), which is a platform shutdown path, not a libc primitive.
- The survey's fallback rule ("move to OSv only if Unikraft's libc proves to be missing a
  primitive the runtime profile cannot waive") is not triggered: in the A1 to A3
  configuration the only Unikraft cells marked **missing** are the exit status and device
  dispatch (by construction), and OSv does not supply a harness-visible status either
  (its cell is console-only).

### What the effect-twins task needs from Unikraft

1. **An exit path the harness can see.** (Matrix, before the port; now done, see
   [unikernel-exit-codes.txt](../verification/unikernel-exit-codes.txt).) In the matrix every exit was QEMU status 0 or a hang
   (E3, E9), and a fault looked like success (E4). The exit twin needs a platform shutdown
   that carries a code: for example QEMU's `isa-debug-exit` device written by the exit
   twin and by the fault halt, with the run harness mapping its status. The device-carried
   code is the requirement; a console line is diagnostic only, because program output
   shares the console and could forge a parsed status (unless the framing is one the
   program cannot emit). Either way the halt after
   `exit`, `_exit`, and the trap must power off instead of idling (E9), and corpus
   failure, arena exhaustion, and fault must give distinct codes (UL-006).
   **Unikernel port Task 1 (verification/unikernel-exit-codes.txt):** the host binding
   `hosts/unikraft/exit_device.c` writes the status to `isa-debug-exit` from Unikraft's
   termination table, requests the halt on the init process's exit, and writes 0x7e from
   `UK_CRASH_EVENT`. With `CONFIG_LIBUKBOOT_MAINTHREAD=y` (the cause of the E9 idle was
   main running on the init thread) the harness now sees QEMU 1 for success, 3 for
   `IO.die(Unit, 1, ...)`, 253 for the Overflow fault, and 7 for `IO.exit(3)`. Open:
   `IO.die` status 1 and a runtime `_exit(1)` (and so arena exhaustion, by reading the
   emitted C) share code 3, and statuses above 124 share 255.
   **Unikraft effect-twins Task 3 (verification/unikernel-fault-qemu.txt):** program
   statuses are now s + 0x10 (success 33, `IO.die` 35, `IO.exit(3)` 39), a runtime or
   host-layer `_exit(1)` is 17 (told from `exit()` by an atexit mark), crash 253. Arena
   exhaustion, forced, is a Unikraft crash (253), not the runtime's fail-stop.
2. **A declared single-lane configuration.** Keep `UKPLAT_CPU_MAXCOUNT=1` and the
   cooperative scheduler, run with `+RTS --threads 1`, and use the inline IO helper
   (UL-005). On this kernel `--threads 2` creates a lane whose `pool_work` was not entered before shutdown in a non-yielding program (E6; behaviour when the main lane yields not tried), so a
   multi-lane build must not be configured by accident. `UKPLAT_CPU_MAXCOUNT=1` is now set explicitly in the Kraftfile (done: `hosts/unikraft/app/Kraftfile`; in the matrix it was only a resolved default, matrix ~565); SMP is a later task (2.4), and
   the OSv hang at shutdown with more than one lane (cause inferred, O-E6) should be
   investigated as part of it.
3. **The fault halt to carry the runtime's message.** The runtime's `SIGSEGV` handler
   does not run on Unikraft (E4); the halting fault handler (task 2.3) has to print the
   runtime's fault text, or an equivalent recorded line, before the coded halt. Task 3
   of the effect-twins lane: with `CONFIG_LIBPOSIX_PROCESS_SIGNAL=y` it does run and
   prints its text, then the image crashes (253). Adopted 2026-11-04 (Unikraft signals
   lane): the template enables the experimental library, `build.sh` carries the compile
   workaround, and the corpus rerun is 782 PASS; arena exhaustion still crashes without
   the message (Port status, "Faults").
4. **The A3 libraries kept or replaced.** The event loop needs `posix-pipe` and
   `posix-poll` (Task 1 A1+A2 run); an ingress twin that replaces the self-pipe could drop
   them, and UL-003's binary check decides which stay. lib-musl itself selects
   `LIBPOSIX_VFS` and `LIBUKFS` (a VFS core, no filesystem driver; matrix ~565), which
   UL-003's "no filesystem library" check will meet.
5. **The platform action after a crash and after `main` (settled).** Run without
   `-no-reboot` (unikernel port Task 2,
   [unikernel-crash-action.txt](../verification/unikernel-crash-action.txt)): with the
   exit hook and the debug-exit device the Overflow crash exits QEMU 253 before any
   reset; without the hook, or without the device, Unikraft's own crash action ends
   QEMU with 0 and no reset (banner once, no output after the crash screen), consistent
   with an ACPI power-off (85 with a device at 0x501), and the return from `main` does
   the same (83 at 0x501). A monitor `system_reset` control does re-run
   the image, so a reset would have been seen. No observed path resumes the program.
   The harness still passes `-no-reboot` on every run as a guard against any path that
   does reset (a triple fault, `LIBUKDEBUG_CRASH_ACTION_REBOOT`, another platform
   driver), so that such a path ends QEMU instead of re-running the program, which
   would be resumption at the image level and forbidden by UL-006.
6. **Compiler parity (UL-005).** The emitted C is compiled as `-std=gnu11` with GCC here,
   while the Linux reference uses clang's default dialect: a compiler and dialect
   difference, not an evaluator edit.

### Single most likely blocker, per candidate

- **Unikraft:** the exit status (matrix, before the port; since resolved by the exit hook,
  see [unikernel-exit-codes.txt](../verification/unikernel-exit-codes.txt)). No exit path reached the harness (E3, E9), so RH-006 and UL-006 could
  not be checked from the run's status.
- **OSv (for a native link):** the loader (from documentation, not built). OSv's
  documentation describes application loading only through its ELF linker (mode note in
  unikernel-matrix-osv.md; O-E0 shows the loader rejecting a header, not the absence of
  another mode), so, if that holds, UL-001 would need a link-into-kernel
  application mode added to OSv itself (unverified).
