# Library-unikernel Bend runtime: tasks

Selection (1.1, 1.2) is recorded in docs/UNIKERNELS.md ("Selection matrix, 2026-11"),
verification/unikernel-matrix-unikraft.md, verification/unikernel-matrix-osv.md, and
verification/unikernel-pins.txt. Unikraft 0.21.0 is a native link; OSv 0.57.0 is a
compat observation only (a Linux PIE through OSv's ELF loader), recorded so the matrix
has two candidates. All boot runs are QEMU TCG emulated boots (the one `linuxu` run was process execution, and native calibration runs on Linux). Of the port tasks only 2.2 (single-lane
corpus parity under QEMU TCG) is complete; the other port tasks and the boot tasks remain
pending.

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

## 2. Port

- [ ] 2.1 Author the console, time, and ingress effect twins for the chosen kernel (exit is the inventoried termination host layer); publish their trust inventory; run the runtime profile's binary check on the image.
  Unchecked: the ingress twin is missing. Exit: `hosts/unikraft/exit_device.c` (a C
  termination and crash hook, not a Bend effect twin) gives QEMU 1 / 3 / 253 for success,
  `IO.die`, and a fault (verification/unikernel-exit-codes.txt). Console and time:
  `hosts/unikraft/effects/Unikraft.bend` (`Unikraft.log`, `Unikraft.now`, `Unikraft.sleep`)
  with `.c` twins over `hosts/unikraft/host.c` and `.js` twins that fail; the probe
  `scripts/unikernel/Probe.bend` puts its text on serial through `Unikraft.log`, measures
  102 to 103 ms around a 100 ms sleep, shows its FAIL branch once (QEMU 3), and
  check-binary.sh sees exactly the three effects as rows beyond the profile
  (verification/unikernel-effects-qemu.txt, fix round 1; static link, so effect rows only).
  The sleep parks on the runtime's own timer (`io_wait_on`, as `IO.sleep` does), so the loop
  stays live; `io_work` is out because its helper thread outlives `main` on this
  configuration and turns success into QEMU 255 (that file, R0-E1), and the ingress twin
  must park on its device descriptor the same way. The re-park and clock-failure paths
  have not been exercised. The images still send `IO.print` through lib-musl; only
  `Unikraft.log` uses a twin, so the "Console effect" scenario (a twin for `IO.print`) is
  a gap.
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
  The exit hook should also move success off QEMU 1 (for example by writing s + 0x10), since
  QEMU itself exits 1 on its own startup errors; until then QEMU 1 counts as success only
  with the console check.
- [x] 2.2 Configure a single lane with the inline IO helper; build `Tests.bend` and the four examples; capture console output under QEMU and compare line for line with the Linux single-lane record.
  Evidence: verification/unikernel-corpus-qemu.txt (current result: its integration rerun
  section, tree aaa6885). One CPU (`UKPLAT_CPU_MAXCOUNT=1`) and `+RTS --threads 1 --gpu off`.
  "With the inline IO helper" is read as "no IO helper thread runs": Bend 2.0.39 has no
  separate inline-IO switch, and in the emitted C of all five programs `io_work`, the only
  function that creates an IO helper thread (`pthread_create(..., io_help, ...)`), is defined
  but never called, so `IO.print` runs on the IO loop itself (also the matrix's event-loop
  row, verification/unikernel-matrix-unikraft.md: no monitor-profile effect uses a helper
  thread). Under QEMU TCG with `-no-reboot` and the exit device, `Tests.bend` prints 782 PASS
  lines and `ALL LIBRARY TESTS PASSED` with QEMU exit 1 (at `-m 4096` and `-m 32`), and
  `Example.bend`, `examples/Flow.bend`, `examples/Transfer.bend`, and `GpuExample.bend`
  (CPU-fallback line, no GPU claim) match, each diff empty after removing only SeaBIOS
  output and Unikraft's banner; `hosts/unikraft/scripts/check-corpus.sh` and
  `check-image.sh` exit nonzero if any of these outcomes changes. The corpus is compared
  with a fresh Linux single-lane capture of the same 782-check tree
  (verification/unikernel-corpus-linux-reference.txt); the earlier 764-check run is kept as
  history in the evidence, verification/runtime-profile-parity-1.txt is the older 638-check
  record, and the "638 count" in UL-005's scenario predates the current corpus. Emulated
  boots only, one lane.
- [ ] 2.3 Install the halting fault handler; force a stack overflow and an arena exhaustion; record the console message and distinct exit codes.
  Unchecked: the forced stack overflow yields a distinct QEMU exit (253 from the exit hook's
  crash handler; Unikraft's own action is a power-off with no reset,
  verification/unikernel-crash-action.txt), but no halting handler prints the runtime's
  fault message (the console shows only Unikraft's crash screen, matrix E4), and arena
  exhaustion was not forced; by reading the emitted C it would exit with status 1 and share
  QEMU 3 with `IO.die`, so it has no distinct code.
- [ ] 2.4 Enable additional lanes behind the kernel's thread library; show the corpus still matches and record the lane count.

## 3. Boots and deployment rules

- [ ] 3.1 Boot the image under a hardware-accelerated hypervisor (Firecracker or QEMU with KVM); record results separately from software emulation.
- [ ] 3.2 Apply the appliance host's requirements UA-001 through UA-010 to the library image, including the rebuild drill with elapsed time and the trusted-base statement.
- [ ] 3.3 Validate OpenSpec strictly and run the ordinary Bend checks on Linux to show no policy source changed.
