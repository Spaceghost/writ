# Library-unikernel Bend runtime: tasks

The requirement-to-evidence mapping, with the open tasks quoted as gaps, is in openspec/traceability/unikernel-library-runtime.md.

Selection (1.1, 1.2) is recorded in docs/UNIKERNELS.md ("Selection matrix, 2026-11"),
verification/unikernel-matrix-unikraft.md, verification/unikernel-matrix-osv.md, and
verification/unikernel-pins.txt. Unikraft 0.21.0 is a native link; OSv 0.57.0 is a
compat observation only (a Linux PIE through OSv's ELF loader), recorded so the matrix
has two candidates. All boot runs are QEMU TCG emulated boots except the KVM boots of 3.1, recorded only in verification/unikernel-kvm.txt (the one `linuxu` run was process execution, and native calibration runs on Linux). Of the port tasks 2.2 (single-lane
corpus parity under QEMU TCG) and 2.3 (the fault message, with arena exhaustion's missing
distinct code kept as a recorded limit) are checked; 3.1, 3.2 and 3.3 are checked. The
change is not finished: 1.3, 2.1 and 2.4 are open (each box says why), and UL-008 is not
met (3.2 is a checklist of its gaps).

## 1. Selection

- [x] 1.1 Pin Unikraft and OSv versions and toolchains; build the generated C of the `IO.print` reference program against each as a native application and record build outcome.
  Checked with OSv as a recorded outcome, not a native build: OSv's documentation describes no mode that links
  application C into its kernel (unverified; no native-link attempt was made, and it is not a reason for the choice, which rests on Unikraft's executed native-link cells), so its build is a compat PIE (unikernel-matrix-osv.md).
- [x] 1.2 Fill the selection matrix, one row per runtime inventory item per candidate, by executing each primitive (reservation with guard, threads or single lane, fault path, clock, self-pipe, environment, exit); publish the matrix and the chosen kernel with reasons.
- [ ] 1.3 If Unikraft is chosen, run the reference program under its `linuxu` platform and record it as process execution, not a boot.
  Unchecked: the chosen pin (0.21.0) has no `linuxu` platform. The 0.16.3 `linuxu` image
  was run and recorded as process execution, but it stops at `bend: reservation failed`
  before the program's first output (unikernel-matrix-unikraft.md, E10), so the reference
  program has not run under `linuxu`.
  Stopping point (unikraft-linuxu lane, verification/unikernel-linuxu.txt): the stop is the
  runtime's 8 GiB CPU heap reservation, refused with `-ENOMEM` by `lib/ukmmap`, the only `mmap`
  linuxu can link (`posix-mmap` needs paging, which linuxu excludes). No runtime option shrinks it;
  raising `CONFIG_LINUXU_DEFAULT_HEAPMB` came closest but caps at 4095 MiB (a 32-bit length); and
  `ukmmap` has no `MAP_NORESERVE` reservation path. Still process execution, not a boot; the box
  stays unchecked.

## 2. Port

- [ ] 2.1 Author the console, time, and ingress effect twins for the chosen kernel (exit is the inventoried termination host layer); publish their trust inventory; run the runtime profile's binary check on the image.
  Unchecked: the ingress twins exist only as scaffolding (below; the subject is a
  build-time word, not an authenticated route). Exit: `hosts/unikraft/exit_device.c` (a C
  termination and crash hook, not a Bend effect twin) gives QEMU 33 / 35 / 253 for success,
  `IO.die`, and a fault (verification/unikernel-fault-qemu.txt; 1 / 3 / 253 before the
  effect-twins lane's Task 3, verification/unikernel-exit-codes.txt). Console and time:
  `hosts/unikraft/effects/Unikraft.bend` (`Unikraft.log`, `Unikraft.now`, `Unikraft.sleep`)
  with `.c` twins over `hosts/unikraft/host.c` (the twins' C side: console, clock, channel,
  and the COM2 scratch-register probe; part of the twins, not of the boot and termination
  host layer, which is `exit_device.c` alone) and `.js` twins that fail; the probe
  `scripts/unikernel/Probe.bend` puts its text on serial through `Unikraft.log`, measures
  102 to 103 ms around a 100 ms sleep, shows its FAIL branch once (QEMU 3, first map), and
  check-binary.sh sees exactly the three effects as rows beyond the profile
  (verification/unikernel-effects-qemu.txt, fix round 1; static link, so effect rows only).
  The sleep parks on the runtime's own timer (`io_wait_on`, as `IO.sleep` does), so the loop
  stays live; `io_work` is out because its helper thread outlives `main` on this
  configuration and turned success into QEMU 255 under the first exit map (that file,
  R0-E1; 19, a signal death, under the current map, not rerun). The ingress twin parks on
  the runtime timer the same way, since COM2 has no descriptor here (below). The re-park and clock-failure paths
  have not been exercised. The images still send `IO.print` through lib-musl; only
  `Unikraft.log` uses a twin, so the "Console effect" scenario (a twin for `IO.print`) is
  a gap.
  Ingress: `Unikraft.take` and `Unikraft.put` (same file, `.c` twins over `host.c`) carry
  the Genode channel's 64-byte records in fixed 80-byte frames over QEMU's second serial
  port (ISA COM2, `CONFIG_LIBNS16550_COM2`, a Unix socket on the host;
  `hosts/unikraft/effects/Channel.md`); `take` parks on the runtime timer between polls
  of COM2 (10 ms idle, 1 ms while a frame is arriving), since COM2 has no descriptor or
  interrupt in this configuration. The
  monitor `hosts/unikraft/monitor/Monitor.bend` (fuel 4, SYNTHETIC Scenario state) answered
  the host-side client probe with Committed (reason 0) and, for S's session named by the
  body under the R subject, Denied by `DataOS.commit_from_capability` (reason 6); a
  wrong-length frame got host.c's transport refusal (kind 3, reason 256) before Bend; the
  reason-5 contrast (S as the subject) is shown on Linux by `MonitorCheck.bend`
  (verification/unikernel-channel-qemu.txt). The subject is a build-time word
  (`WRIT_CHANNEL_SUBJECT`): there is no parent route on a unikernel, so this is
  SCAFFOLDING for the ingress twin and the gap UL-008's single-ingress rule and the
  appliance host must close; it is never read from the record body.
  `hosts/unikraft/INVENTORY.md` lists every file, exported symbol, and what it may touch.
  UL-004 amended (unikraft effect-twins lane, Task 1), as AGENTS.md requires a rationale for
  a contract change. The old text made the effect twins the only kernel-specific code, but
  the termination and crash hook cannot be a twin: a twin is a Bend effect the program
  calls, and no Bend code runs on a Unikraft crash or after `main` has returned, which is
  exactly when the hook reports how the image ended; moving that reporting into a twin would
  lose the crash and exit outcomes, and dropping the hook would hide them. The requirement
  now reads "the effect twins and the inventoried boot and termination host layer SHALL be
  the only kernel-specific code", and the trust inventory must name each such file, its
  exported symbols, and what it may touch, so the hook is reviewed as strictly as a twin; it
  still decides no authority question. "Exit" moves from the twins' primitives to that host
  layer, and the inventory sentence (each file, its exported symbols, what it may touch) is
  added to the requirement. The Kraftfile and Makefile.uk remain build configuration,
  listed in the inventory.
  Done in the effect-twins lane's Task 3: the exit hook writes s + 0x10, so success is
  QEMU 33 and no outcome is QEMU 1, which QEMU itself returns on its own startup errors.
  Still unchecked for the gaps above: the ingress subject is scaffolding, and `IO.print`
  has no twin (the "Console effect" scenario).
- [x] 2.2 Configure a single lane with the inline IO helper; build `Tests.bend` and the four examples; capture console output under QEMU and compare line for line with the Linux single-lane record.
  Runtime host profile: the runs cite `scripts/runtime-profile/` (check-binary.sh) and are
  recorded in `verification/runtime-profile-hosts.md` (Unikraft corpus and channel rows).
  Evidence: verification/unikernel-corpus-qemu.txt (current result: its integration rerun
  section, tree aaa6885). One CPU (`UKPLAT_CPU_MAXCOUNT=1`) and `+RTS --threads 1 --gpu off`.
  "With the inline IO helper" is read as "no IO helper thread runs": Bend 2.0.39 has no
  separate inline-IO switch, and in the emitted C of all five programs `io_work`, the only
  function that creates an IO helper thread (`pthread_create(..., io_help, ...)`), is defined
  but never called, so `IO.print` runs on the IO loop itself (also the matrix's event-loop
  row, verification/unikernel-matrix-unikraft.md: no monitor-profile effect uses a helper
  thread). Under QEMU TCG with `-no-reboot` and the exit device, `Tests.bend` prints 782 PASS
  lines and `ALL LIBRARY TESTS PASSED` with QEMU exit 1 (at `-m 4096` and `-m 32`; QEMU 33 under the current exit map, effect-twins lane Task 3), and
  `Example.bend`, `examples/Flow.bend`, `examples/Transfer.bend`, and `GpuExample.bend`
  (CPU-fallback line, no GPU claim) match, each diff empty after removing only SeaBIOS
  output and Unikraft's banner; `hosts/unikraft/scripts/check-corpus.sh` and
  `check-image.sh` exit nonzero if any of these outcomes changes. The corpus is compared
  with a fresh Linux single-lane capture of the same 782-check tree
  (verification/unikernel-corpus-linux-reference.txt); the earlier 764-check run is kept as
  history in the evidence, verification/runtime-profile-parity-1.txt is the older 638-check
  record, and the "638 count" in UL-005's scenario predates the current corpus. Emulated
  boots only, one lane.
- [x] 2.3 Install the halting fault handler; force a stack overflow and an arena exhaustion; record the console message and distinct exit codes.
  Checked (Unikraft signals lane, Task 3, 2026-11-04) with arena exhaustion's code recorded
  as a limit, not met. Handler and message: the template now enables Unikraft 0.21.0's
  posix signal library (`CONFIG_LIBPOSIX_PROCESS_SIGNAL: 'y'` in hosts/unikraft/app/Kraftfile;
  EXPERIMENTAL, lib/posix-process/Config.uk:78) and hosts/unikraft/scripts/build.sh passes
  `UK_CFLAGS="-std=gnu11 -include uk/config.h"`, which works around 0.21.0's include order in
  lib/posix-process/shutdown.c (signal.h:116/287); both are pins
  (verification/unikernel-pins.txt, "Unikraft image configuration pins"). The runtime's
  handler runs on its alternate stack: the forced stack overflow
  (`scripts/unikernel/Overflow.bend`) prints `bend: memory fault (machine stack overflow?)`
  before the Unikraft crash screen, then the image crashes (deliver.c:428) with the hook's
  crash value, QEMU 253, and does not resume. `hosts/unikraft/scripts/check-fault.sh`
  requires the message line for the overflow probe; it passes on two boots and fails on the
  image built without signals (verification/unikernel-fault-qemu.txt, "Result" and "Fault
  message runs"). Codes, re-recorded with the library and unchanged: success 33, `IO.die`
  35 (corpus failure: `Test.bend` `check` ends a failing test with `IO.die(Unit, 1, ...)`),
  `IO.exit(3)` 39, a runtime or host-layer `_exit(1)` 17 (told from `exit()` by an atexit
  mark), crash 253 (verification/unikernel-exit-codes.txt, "CURRENT MAP, RE-RECORDED WITH
  POSIX SIGNALS"). Every image set was rebuilt with the library and rechecked; the corpus
  is still 782 PASS (verification/unikernel-corpus-qemu.txt, unikernel-effects-qemu.txt,
  unikernel-channel-qemu.txt, unikernel-binary-check.txt).
  Recorded limit: arena exhaustion, forced with `scripts/unikernel/Exhaust.bend` at
  `-m 1024`, is still a Unikraft crash with no runtime message and QEMU 253, now on the
  assertion at lib/posix-process/signal/deliver.c:125 (the alternate stack already in use)
  instead of in heap_alloc_miss (verification/unikernel-fault-qemu.txt, "Arena exhaustion
  with signals"). The earlier record predicted that enabling the library would print the
  message here; that prediction was wrong. Exhaustion therefore has no code distinct from a
  fault, which UL-006 requires: this half of UL-006 is not met. The 4096 and 12288 MiB sizes
  were not rerun with signals.
  Not exercised: the signal value 19 and the non-halt value 251; with signals,
  posix-process shutdown sends SIGTERM to an init process still running and waits for it
  (lib/posix-process/shutdown.c:61-67), a path reachable only by a program still running at
  shutdown, which no shipped image is (verification/unikernel-fault-qemu.txt, "Exit map
  runs"; verification/unikernel-effects-qemu.txt). Every run is a QEMU TCG emulated boot on
  the CPU; no GPU test. The scenario states no number, so the spec is unchanged.
- [ ] 2.4 Enable additional lanes behind the kernel's thread library; show the corpus still matches and record the lane count.
  Open (2026-11-05, Unikraft lanes lane): a second lane runs (set `lanes`, `UKPLAT_CPU_MAXCOUNT=2`) but only on vCPU 0, because Unikraft 0.21.0 never calls uk_lcpu_start, and every `--threads 2` run, with the shipped template as well, ends in a shutdown assertion (QEMU 253), so the corpus was not run on two lanes (verification/unikernel-lanes-qemu.txt, "Stopping point").

## 3. Boots and deployment rules

- [x] 3.1 Boot the image under a hardware-accelerated hypervisor (Firecracker or QEMU with KVM); record results separately from software emulation.
  Done (2026-11-05, Unikraft closing lane): QEMU 11.1.2 with `-accel kvm -cpu host` (`run.sh` accel `kvm`) on an AMD Ryzen 9 5950X, kernel 7.2.9, recorded only in verification/unikernel-kvm.txt (TCG records unchanged). Hello 33, Die 35, Exit 39, Exhaust 253, Overflow fault message then 253, and the corpus 33 with 782 PASS lines, each passing its check script with the program lines equal to the references. Under KVM the guest runs briefly past exit_device.c's port write, so Unikraft's `pm.c:69` shutdown line, whole or cut off, can end a capture; the check scripts now drop a trailing unterminated fragment that is the start of a timestamped kernel line after the exit write (a cut-off timestamp, or the pm.c:69 line), nothing else, and count it every time: `kernel shutdown fragment after exit: dropped <0|1>` (the file's "Fix round" and "Fix round 2" list every count and the self-test). Follow-up: a halt after the write in exit_device.c, deferred to the next rebuild of every set. One vCPU, CPU only, no GPU; Firecracker not tried.
- [x] 3.2 Apply the appliance host's requirements UA-001 through UA-010 to the library image, including the rebuild drill with elapsed time and the trusted-base statement.
  Done (2026-11-05, Unikraft closing lane) as a checklist, not an appliance (the appliance change is not implemented): verification/unikernel-appliance-rules.md gives each of the ten requirements its evidence or its gap quoted in the requirement's words. Met for what exists: UA-003 (782 PASS; the "638 count" predates the corpus), UA-009, UA-010. Partly met: UA-001 (the only monitor image fails the profile check), UA-007 (rebuild only: no store, no reconciliation). Gaps: UA-002 (the hash differs because of the embedded build time), UA-004, UA-005 (the channel is not authenticated), UA-006 (no store), UA-008 (no boot clock check, no entropy). Rebuild drill: a fresh `drillhello` set from the pinned sources, built clean in 68.2 s (68.7 s from mkapp.sh to the image). The image hash is f8f49e7d against the recorded d0421dfb; with the 25-byte build time in `.uk_libinfo` masked, the images are byte-identical, and nm (4523 symbols), sizes, check-binary.sh (IO.print, PASS) and the boot's program lines (`hi`, QEMU 33, TCG and KVM) are equal. The trusted-base statement names QEMU, the host kernel, SeaBIOS, Unikraft 0.21.0, and all 55 linked objects, including the experimental signal library and `-include uk/config.h`.
- [x] 3.3 Validate OpenSpec strictly and run the ordinary Bend checks on Linux to show no policy source changed.
  Done (2026-11-05, Unikraft closing lane, tree 8be3b87 plus this lane's document edits; Bend 2.0.39, `BEND_NO_TELEMETRY=1`, Linux x86_64, from the worktree root):
  `bend Tests.bend`: exit 0, 782 `PASS:` lines, last line `ALL LIBRARY TESTS PASSED` (4.8 s).
  `bend PROOF.bend`: exit 0, `ALL PROOFS CHECK` then `Use --verdict for mathematical validity.`; run without `--verdict`, since no Lean kernel toolchain is installed here, so this is the checker's own result, not a kernel verdict.
  `bunx @fission-ai/openspec@1.16.0 validate --all --strict --no-interactive`: exit 0, `Totals: 44 passed, 0 failed (44 items)`; structural validation only, separate from the Bend checks.
  `git diff --stat master -- '*.bend'`: empty; this lane changed no Bend file. Across the unikernel lanes already on master, the commits touching the unikernel paths changed only Bend files under `hosts/unikraft/` (`effects/Unikraft.bend`, the effect twins' declarations; `monitor/Monitor.bend` and `monitor/MonitorCheck.bend`, the SYNTHETIC channel-monitor scaffolding, which imports the root modules and whose final gate is `DataOS.commit_from_capability`) and probe programs under `scripts/unikernel/` (Clock, Die, Exhaust, Exit, Hello, Lanes, Overflow, Probe); one integration commit among them (600f82e) also added a cross-reference comment to the Genode probe `scripts/genode/Hello.bend`. No root or library Bend file imports any of these, and no policy module (`DataOS.bend`, `LAWS.bend`, `PROOF.bend`, the other root libraries) is among them. CPU only; no GPU test.
