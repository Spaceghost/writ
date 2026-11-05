# Library-unikernel runtime traceability

Proposed change: [add-unikernel-library-runtime](../changes/add-unikernel-library-runtime/specs/unikernel-library-runtime/spec.md).
This is a proposed change; nothing here marks an accelerated boot, a Bend
effect twin, or a host acceptance scenario as implemented. Every execution
named here is a Unikraft 0.21.0 `qemu/x86_64` image booted under QEMU 11.1.2
with TCG (an emulated boot), one CPU, one lane, `--gpu off`, except where a row
says otherwise. Nothing was booted under KVM or Firecracker.

Implementation: the host binding under [hosts/unikraft/](../../hosts/unikraft/)
(inventory: [INVENTORY.md](../../hosts/unikraft/INVENTORY.md)): the exit and
crash hook [exit_device.c](../../hosts/unikraft/exit_device.c) (the boot and
termination host layer, alone), the effect twins
[effects/](../../hosts/unikraft/effects/) (`Unikraft.log`, `.now`, `.sleep`,
`.take`, `.put`) with their C side [host.c](../../hosts/unikraft/host.c), the
channel monitor [monitor/](../../hosts/unikraft/monitor/) (scaffolding), and the
app template [app/](../../hosts/unikraft/app/). Scripts are under
[hosts/unikraft/scripts/](../../hosts/unikraft/scripts/): `mkapp.sh`,
`build.sh`, `run.sh`, `console.sh`, `check-image.sh`, `check-corpus.sh`,
`check-channel.sh`, `check-fault.sh` (`env.sh` is sourced by the others). The
check scripts exit nonzero if an expected console, PASS count, or QEMU status
changes; the
runtime profile's `scripts/runtime-profile/check-binary.sh` produced the
binary-check record.

Evidence files: [unikernel-pins.txt](../../verification/unikernel-pins.txt),
[unikernel-matrix-unikraft.md](../../verification/unikernel-matrix-unikraft.md),
[unikernel-matrix-osv.md](../../verification/unikernel-matrix-osv.md),
[unikernel-exit-codes.txt](../../verification/unikernel-exit-codes.txt),
[unikernel-crash-action.txt](../../verification/unikernel-crash-action.txt),
[unikernel-corpus-qemu.txt](../../verification/unikernel-corpus-qemu.txt),
[unikernel-corpus-linux-reference.txt](../../verification/unikernel-corpus-linux-reference.txt),
[unikernel-binary-check.txt](../../verification/unikernel-binary-check.txt),
[unikernel-effects-qemu.txt](../../verification/unikernel-effects-qemu.txt),
[unikernel-channel-qemu.txt](../../verification/unikernel-channel-qemu.txt),
[unikernel-fault-qemu.txt](../../verification/unikernel-fault-qemu.txt),
[unikernel-openspec-validate.txt](../../verification/unikernel-openspec-validate.txt).
The selection matrix prose is in [UNIKERNELS.md](../../docs/UNIKERNELS.md).

"E<n>" labels are the numbered evidence blocks of the matrix files. "Reviewed-only
gap" means the requirement, or the named part of it, has no execution here and
the gap text is quoted from [tasks.md](../changes/add-unikernel-library-runtime/tasks.md)
(or from the evidence file named).

| Requirement | Executed evidence | Reviewed-only gap |
| --- | --- | --- |
| UL-001 the image is a native link | The generated C of `IO.print` (Hello) built against lib-musl as the Unikraft application on `qemu/x86_64` 0.21.0 links and boots to `hi` with build adjustments A1 to A3, none in Bend output (unikernel-matrix-unikraft.md, Task 1 build matrix; E1); `hosts/unikraft/scripts/mkapp.sh` and `build.sh` build every corpus image the same way; `app/Kraftfile` selects no ELF-loader library | OSv is a compat PIE and is not a native link; its native-link status is "unverified (from documentation; no native-link attempt made)" (UNIKERNELS.md); "A build enables the ELF loader": rejection is by review of the Kraftfile; no run tries it |
| UL-002 selection by an executed matrix | Two candidates, Unikraft 0.21.0 and OSv 0.57.0, with one cell per runtime inventory row, each from an executed probe (unikernel-matrix-unikraft.md E1 to E10; unikernel-matrix-osv.md O-E1 to O-E9); the chosen kernel and reasons are in UNIKERNELS.md "Selection matrix, 2026-11"; versions in unikernel-pins.txt | cells marked "by construction" (device dispatch) and OSv's native link are not executed; they are labeled so and support no part of the choice; tasks.md 1.3 is open: "the chosen pin (0.21.0) has no `linuxu` platform" and the 0.16.3 `linuxu` run "stops at `bend: reservation failed` before the program's first output" |
| UL-003 only profile libraries are linked | Runtime profile binary check on every image ELF: effect rows `IO.print` only, PASS (unikernel-binary-check.txt); negative control `Widened.bend` (adds `TCP.listen`) built as an image fails with checker exit 1 (the same file) | the check is on effect rows only: "a static binary has no imports, so the undefined-symbol comparison is not applicable", so "a PASS here does not cover the host-symbol surface (what Unikraft and musl link in)"; no captured list of linked kernel libraries is recorded (the Kraftfile names its library configuration); the channel monitor image's check lists `Unikraft.log`, `Unikraft.put`, `Unikraft.take` as rows beyond the monitor profile (FAIL, exit 1; unikernel-channel-qemu.txt, unikernel-fault-qemu.txt), so the profile's effect list does not yet name the Unikraft effects |
| UL-004 effect twins bind to kernel primitives | console and time: `Unikraft.log`, `Unikraft.now`, `Unikraft.sleep` (`hosts/unikraft/effects/Unikraft.bend`, `.c` twins over `host.c`); the probe `scripts/unikernel/Probe.bend` puts its text on serial through `Unikraft.log` and measures 102 to 103 ms around a 100 ms sleep; check-binary.sh sees exactly those effects beyond the profile (unikernel-effects-qemu.txt); ingress: `Unikraft.take` / `Unikraft.put` carry the channel records over COM2, Committed (reason 0) and Denied by `DataOS.commit_from_capability` (reason 6) round trips, QEMU 33 under the current map (unikernel-channel-qemu.txt; unikernel-fault-qemu.txt "Channel monitor"); exit: `exit_device.c`, the boot and termination host layer alone, gives QEMU 33 / 35 / 17 / 253 for success, `IO.die`, a runtime `_exit(1)`, and a crash (unikernel-fault-qemu.txt); UL-004 amended with its rationale (tasks.md 2.1); `hosts/unikraft/INVENTORY.md` lists every file, its exported symbols, and what it may touch | tasks.md 2.1 open: "the ingress subject is scaffolding, and `IO.print` has no twin (the \"Console effect\" scenario)"; the subject is a build-time word, not an authenticated route (UL-008); `host.c`'s re-park and clock-failure paths are not exercised; "Twin reaches beyond the profile": rejection is by review |
| UL-005 single lane first, with parity | `Tests.bend` prints 782 PASS lines and `ALL LIBRARY TESTS PASSED`, QEMU exit 1 under the first exit map and QEMU 33 under the current one (rebuilt image, unikernel-corpus-qemu.txt "Task 3 rerun"), at `-m 4096` and `-m 32`; `Example.bend`, `examples/Flow.bend`, `examples/Transfer.bend`, `GpuExample.bend` match with empty diffs against fresh Linux single-lane captures (unikernel-corpus-qemu.txt, integration rerun section; unikernel-corpus-linux-reference.txt); `check-corpus.sh` and `check-image.sh` | the scenario's "638 count" "predates the current corpus" (tasks.md 2.2): the compared corpus is 782 checks; tasks.md 2.4 open: "Enable additional lanes behind the kernel's thread library; show the corpus still matches and record the lane count" (matrix E6: with one CPU and the cooperative scheduler the second lane is not run); "Multi-lane divergence": no multi-lane run exists |
| UL-006 faults halt with a distinct code | fault message: executed. With Unikraft's experimental posix signal library adopted in the template (`CONFIG_LIBPOSIX_PROCESS_SIGNAL: 'y'`, `lib/posix-process/Config.uk:78`) and `build.sh`'s `-include uk/config.h` (unikernel-pins.txt, "Unikraft image configuration pins"), the forced stack overflow (Overflow.bend) prints `bend: memory fault (machine stack overflow?)` before the Unikraft crash screen and ends at the crash hook's QEMU 253, two boots; `check-fault.sh` requires the message line for the overflow probe and fails on the image built without signals (negative control) (unikernel-fault-qemu.txt, "Result", "Fault message runs"); codes, re-recorded with the library and unchanged: success 33, `IO.die` (corpus failure, through `Test.bend`'s `check`) 35, `IO.exit(3)` 39, a runtime or host-layer `_exit(1)` 17 (booted with a bad `+RTS` argument; and with no second serial port, unikernel-channel-qemu.txt), crash 253 (unikernel-exit-codes.txt, "CURRENT MAP, RE-RECORDED WITH POSIX SIGNALS"; unikernel-fault-qemu.txt, "Exit map runs"); the corpus rebuilt with the library is still 782 PASS (unikernel-corpus-qemu.txt); Unikraft's own crash action is a power-off with no reset, so the image does not resume (unikernel-crash-action.txt) | arena exhaustion: limit. Exhaust.bend (`-m 1024`, the only size rerun with signals) is still a Unikraft crash with no runtime message, QEMU 253, now on the assertion at `lib/posix-process/signal/deliver.c:125` (the alternate stack already in use); the earlier prediction that the message would appear there was wrong; it has no code distinct from a fault (unikernel-fault-qemu.txt, "Arena exhaustion with signals"); tasks.md 2.3 is checked with this half recorded as a limit, not met; not exercised: the signal value 19, the non-halt value 251, and the shutdown SIGTERM-and-wait path (`lib/posix-process/shutdown.c:61-67`), reachable only by a program still running at shutdown (unikernel-fault-qemu.txt, "Exit map runs"; unikernel-effects-qemu.txt); "Handler resumes": rejection is by review |
| UL-007 three environments, recorded separately | process execution: the 0.16.3 `linuxu` image, recorded as process execution and stopping at `bend: reservation failed` (matrix E10); the native Linux run is the reference capture (unikernel-corpus-linux-reference.txt); software emulation: all QEMU TCG runs above, each labeled an emulated boot | tasks.md 3.1 open: "Boot the image under a hardware-accelerated hypervisor (Firecracker or QEMU with KVM)"; no accelerated run exists, so the image is emulated-boot evidence only; tasks.md 1.3 open: the reference program "has not run under `linuxu`", so "linuxu run passes" has no instance |
| UL-008 appliance rules apply unchanged | none | tasks.md 3.2 open: "Apply the appliance host's requirements UA-001 through UA-010 to the library image, including the rebuild drill with elapsed time and the trusted-base statement"; clean builds are not hash-stable (embedded build time), so the reproducibility requirement is also unmet; tasks.md 3.3 is open: this record is not that validation |

The OpenSpec structural validation run during the port lane is
[unikernel-openspec-validate.txt](../../verification/unikernel-openspec-validate.txt);
it is separate from the Bend tests and proof checks.
