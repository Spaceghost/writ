# Library-unikernel runtime traceability

Proposed change: [add-unikernel-library-runtime](../changes/add-unikernel-library-runtime/specs/unikernel-library-runtime/spec.md).
This is a proposed change; nothing here marks an accelerated boot, a Bend
effect twin, or a host acceptance scenario as implemented. Every execution
named here is a Unikraft 0.21.0 `qemu/x86_64` image booted under QEMU 11.1.2
with TCG (an emulated boot), one CPU, one lane, `--gpu off`, except where a row
says otherwise. Nothing was booted under KVM or Firecracker.

Implementation: the host binding under [hosts/unikraft/](../../hosts/unikraft/)
(inventory: [INVENTORY.md](../../hosts/unikraft/INVENTORY.md)): the exit and
crash hook [exit_device.c](../../hosts/unikraft/exit_device.c) and the app
template [app/](../../hosts/unikraft/app/). There are no Bend effect twins yet
(tasks.md 2.1). Scripts are under
[hosts/unikraft/scripts/](../../hosts/unikraft/scripts/): `mkapp.sh`,
`build.sh`, `run.sh`, `console.sh`, `check-image.sh`, `check-corpus.sh`
(`env.sh` is sourced by the others). `check-image.sh` and `check-corpus.sh`
exit nonzero if an expected console, PASS count, or QEMU status changes; the
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
| UL-003 only profile libraries are linked | Runtime profile binary check on every image ELF: effect rows `IO.print` only, PASS (unikernel-binary-check.txt); negative control `Widened.bend` (adds `TCP.listen`) built as an image fails with checker exit 1 (the same file) | the check is on effect rows only: "a static binary has no imports, so the undefined-symbol comparison is not applicable", so "a PASS here does not cover the host-symbol surface (what Unikraft and musl link in)"; no captured list of linked kernel libraries is recorded (the Kraftfile names its library configuration); the ingress channel is not in the image (tasks.md 2.1) |
| UL-004 effect twins bind to kernel primitives | the exit part only: `exit_device.c` gives QEMU 1 / 3 / 253 for success, `IO.die`, and a fault (unikernel-exit-codes.txt; check-image.sh asserts the status); `hosts/unikraft/INVENTORY.md` lists every authored non-Bend file and what it may touch | tasks.md 2.1 open: "No console, time, or ingress twin and no Bend effect definition has been written: the images use Bend 2.0.39's own `IO.print` row through lib-musl"; `exit_device.c` "is a C termination and crash hook, not a Bend effect twin", and UL-004's "only kernel-specific code" wording is unreconciled ("2.1 must either subsume the hook under the twins or amend UL-004 with an explicit rationale"); "Twin reaches beyond the profile": rejection is by review |
| UL-005 single lane first, with parity | `Tests.bend` prints 782 PASS lines and `ALL LIBRARY TESTS PASSED`, QEMU exit 1, at `-m 4096` and `-m 32`; `Example.bend`, `examples/Flow.bend`, `examples/Transfer.bend`, `GpuExample.bend` match with empty diffs against fresh Linux single-lane captures (unikernel-corpus-qemu.txt, integration rerun section; unikernel-corpus-linux-reference.txt); `check-corpus.sh` and `check-image.sh` | the scenario's "638 count" "predates the current corpus" (tasks.md 2.2): the compared corpus is 782 checks; tasks.md 2.4 open: "Enable additional lanes behind the kernel's thread library; show the corpus still matches and record the lane count" (matrix E6: with one CPU and the cooperative scheduler the second lane is not run); "Multi-lane divergence": no multi-lane run exists |
| UL-006 faults halt with a distinct code | the forced stack overflow (Overflow.bend) ends the guest at the guard page with QEMU 253 from the crash hook; success is 1 and `IO.die` is 3 (unikernel-exit-codes.txt; unikernel-crash-action.txt shows Unikraft's own crash action is a power-off with no reset, so the image does not resume) | tasks.md 2.3 open: "no halting handler prints the runtime's fault message (the console shows only Unikraft's crash screen, matrix E4), and arena exhaustion was not forced; by reading the emitted C it would exit with status 1 and share QEMU 3 with `IO.die`, so it has no distinct code"; "Handler resumes": rejection is by review |
| UL-007 three environments, recorded separately | process execution: the 0.16.3 `linuxu` image, recorded as process execution and stopping at `bend: reservation failed` (matrix E10); the native Linux run is the reference capture (unikernel-corpus-linux-reference.txt); software emulation: all QEMU TCG runs above, each labeled an emulated boot | tasks.md 3.1 open: "Boot the image under a hardware-accelerated hypervisor (Firecracker or QEMU with KVM)"; no accelerated run exists, so the image is emulated-boot evidence only; tasks.md 1.3 open: the reference program "has not run under `linuxu`", so "linuxu run passes" has no instance |
| UL-008 appliance rules apply unchanged | none | tasks.md 3.2 open: "Apply the appliance host's requirements UA-001 through UA-010 to the library image, including the rebuild drill with elapsed time and the trusted-base statement"; clean builds are not hash-stable (embedded build time), so the reproducibility requirement is also unmet; tasks.md 3.3 is open: this record is not that validation |

The OpenSpec structural validation run during the port lane is
[unikernel-openspec-validate.txt](../../verification/unikernel-openspec-validate.txt);
it is separate from the Bend tests and proof checks.
