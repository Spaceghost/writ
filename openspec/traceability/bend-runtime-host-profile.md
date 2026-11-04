# Bend runtime host profile traceability

Proposed change: [add-bend-runtime-host-profile](../changes/archive/2026-11-04-add-bend-runtime-host-profile/specs/bend-runtime-host-profile/spec.md).
This is a proposed change; nothing here marks a host as satisfying the
profile or qualified. Every execution named here is CPU execution with
`--gpu off`; the Unikraft runs are emulated boots under QEMU TCG and the
Genode runs are `base-linux` (Genode-on-Linux) or x86_64 `base-hw` under QEMU
TCG (an emulated boot, not native hardware), recorded separately. The
Unikraft channel has no evidence here yet.

Implementation: the inventory command
[inventory.sh](../../scripts/runtime-profile/inventory.sh), the allowlists
[monitor-symbols.txt](../../scripts/runtime-profile/monitor-symbols.txt) and
[monitor-effects.txt](../../scripts/runtime-profile/monitor-effects.txt), the
binary check [check-binary.sh](../../scripts/runtime-profile/check-binary.sh),
and the source review in [BEND-RUNTIME.md](../../docs/BEND-RUNTIME.md).

Per-host record: [runtime-profile-hosts.md](../../verification/runtime-profile-hosts.md)
(per host: corpus output, PASS count, lanes, GPU mode, compiler, binary or
image hash, harness, binary check; review-only items listed apart).

Evidence files: [runtime-inventory-bend-2.0.39.txt](../../verification/runtime-inventory-bend-2.0.39.txt),
[runtime-profile-binary-check.txt](../../verification/runtime-profile-binary-check.txt),
[runtime-profile-parity.txt](../../verification/runtime-profile-parity.txt),
[runtime-profile-fault.txt](../../verification/runtime-profile-fault.txt),
[runtime-profile-reservation.txt](../../verification/runtime-profile-reservation.txt),
[genode-corpus-base-linux.txt](../../verification/genode-corpus-base-linux.txt),
[unikernel-corpus-qemu.txt](../../verification/unikernel-corpus-qemu.txt),
[unikernel-binary-check.txt](../../verification/unikernel-binary-check.txt).
"Reviewed-only gap" means the requirement, or the named part of it, has no
execution here; the gap text is quoted from its source.

| Requirement | Executed evidence | Reviewed-only gap |
| --- | --- | --- |
| RH-001 inventory pinned to a Bend version | `inventory.sh` emits C for `Hello.bend` with bend 2.0.39 and records the version and host-call groups (runtime-inventory-bend-2.0.39.txt; tasks.md 1.1) | migration scenario: "the check does not enforce the Bend version pin (RH-001 scenario 2)" (BEND-RUNTIME.md); no stale-marking mechanism exists |
| RH-002 monitor profile is an allowlist | Hello passes; Widened (`TCP.listen`) fails naming the effect and socket imports, dynamic, static, and static LTO (runtime-profile-binary-check.txt sections 1-5) | each denied group's reason is written in the allowlist files (review, tasks.md 1.2) |
| RH-003 binaries are checked, not assumed | the check run on produced binaries: Linux Hello/Widened (runtime-profile-binary-check.txt); Unikraft `tests-qemu.dbg`, effect rows only (unikernel-binary-check.txt, integration section); Genode monitor ELF fails its symbol half (VERIFICATION.md, "Genode Bend component, base-linux"); the base-hw monitor ELF likewise (effect rows Genode.log/put/take, symbol half FAIL; genode-channel-base-hw.txt, "BINARY CHECK") | "a static pass says nothing about the host-symbol surface" (BEND-RUNTIME.md); no corpus binary on Linux or Genode has its own check (runtime-profile-hosts.md, "Gaps") |
| RH-004 host primitives keep runtime semantics | reservation failure: `bend: reservation failed`, exit 1 (runtime-profile-reservation.txt); Genode base-linux memory, event loop, process rows run by Bend programs (genode-runtime-rows-base-linux.md, "Summary") | monotonic clock: no run exercises a clock moving backward on any host; Genode threads, `munmap`, and libc clock are C-probe rows, atomics "unverified" (runtime-profile-hosts.md, "Review-only") |
| RH-005 lane count does not change decisions | 638 tree: 1 and 4 lanes byte-identical, 638 PASS each (runtime-profile-parity.txt; runtime-profile-hosts.md rows 1-2); 782 tree: 1-lane reference and 4-lane `tests-native.txt` share sha256 `fc3a08aa...062916ff` (runtime-profile-hosts.md rows 3-4) | the 782 one- and four-lane captures come from different builds; no multi-lane run on Genode or Unikraft (runtime-profile-hosts.md, "Gaps") |
| RH-006 faults fail stop | Linux: `bend: memory fault (machine stack overflow?)`, exit 139 (runtime-profile-fault.txt); Genode base-linux: component terminated at the guard page, no resumption (genode-corpus-base-linux.txt, "FAULT ROW"); Genode base-hw: refused at the guard page, init records `exited with exit value 139`, core silent (genode-corpus-base-hw.txt, "OVERFLOW RUNS") | Genode base-linux: "init records nothing" (genode-corpus-base-linux.txt); Genode base-hw: the record is a self-reported exit with six limits (genode-bend-hello-base-hw.txt, "GB-003 ON BASE-HW"); Unikraft halt "inferred" (docs/UNIKERNELS.md) |
| RH-007 CPU fallback reported as executed | every row in runtime-profile-hosts.md states `--gpu off` / CPU; the parallel example's dispatch line is recorded as program text (runtime-profile-parity.txt, "Examples") | no device run on any host |
| RH-008 evidence per host, separated by kind | [runtime-profile-hosts.md](../../verification/runtime-profile-hosts.md): per-host rows with their own output and hash, including the Genode base-hw row (QEMU TCG, 782 PASS, `writ_bend_tests` hash under shim 9d9d32d2); review-only list kept apart |the Unikraft channel row filled from unikernel-channel-qemu.txt (QEMU TCG, exit 33; 2026-11-04); the Linux four-lane 782 binary and `tests.js` have no recorded hash |
