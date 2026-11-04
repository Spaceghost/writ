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

- [ ] 2.1 Author the console, time, exit, and ingress effect twins for the chosen kernel; publish their trust inventory; run the runtime profile's binary check on the image.
  Unchecked: only the exit part exists. `hosts/unikraft/exit_device.c` (a C termination
  and crash hook, not a Bend effect twin) gives QEMU 1 / 3 / 253 for success, `IO.die`, and
  a fault (verification/unikernel-exit-codes.txt); `hosts/unikraft/INVENTORY.md` lists it
  and the build scripts; the binary check ran on every image ELF and fails a `TCP.listen`
  image (verification/unikernel-binary-check.txt; static link, so effect rows only). No
  console, time, or ingress twin and no Bend effect definition has been written: the images
  use Bend 2.0.39's own `IO.print` row through lib-musl.
- [x] 2.2 Configure a single lane with the inline IO helper; build `Tests.bend` and the four examples; capture console output under QEMU and compare line for line with the Linux single-lane record.
  Evidence: verification/unikernel-corpus-qemu.txt. One CPU (`UKPLAT_CPU_MAXCOUNT=1`) and
  `+RTS --threads 1 --gpu off`; Bend 2.0.39 has no separate inline-IO switch, and the only
  effect these programs use, `IO.print`, runs on the IO loop without a helper thread. Under
  QEMU TCG with `-no-reboot` and the exit device, `Tests.bend` prints 764 PASS lines and
  `ALL LIBRARY TESTS PASSED` with QEMU exit 1, and `Example.bend`, `examples/Flow.bend`,
  `examples/Transfer.bend`, and `GpuExample.bend` (CPU-fallback line, no GPU claim) match,
  each diff empty after removing only SeaBIOS output and Unikraft's banner. The corpus is
  compared with a fresh Linux single-lane capture of the same 764-check tree
  (verification/unikernel-corpus-linux-reference.txt); verification/runtime-profile-parity-1.txt
  is the older 638-check record, and the "638 count" in UL-005's scenario predates the 764
  corpus. Emulated boots only, one lane.
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
