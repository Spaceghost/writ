# GPU validation traceability

Proposed change: [validate-physical-gpu-execution](../changes/validate-physical-gpu-execution/specs/gpu-validation/spec.md).
This change is proposed and is not archived. Every execution named here is
one host, one GPU and one configuration: Linux 7.2.9-1-MANJARO x86_64,
NVIDIA GeForce RTX 4090 `GPU-0188dad3-4d11-4254-3a0d-50e3808bf464`, driver
615.71.09, CUDA UMD 13.4, Bend 2.0.39, clang 23.1.1, NVRTC 13.4.92, cubins
`sm=89`, on a shared and loaded host. Nothing here qualifies a host for
production use or claims a performance result.

Example. The Task 5 run `transfers-inject-fabricate-admitted` takes the
device's transfer decisions (5000 observed `bend_dev` launches), rewrites a
`Denied Read` leaf to an `Admitted` ticket, and replays it with
`Transfer.admit` against the authoritative `Context`: denied, 1000 of 1000
rounds ([gpu-injection.txt](../../verification/gpu-injection.txt), "Result").
The current gap: that replay is the same evaluator as the producer, it runs in
the same address space as the device result, and no profile protects the
`Context` from device code or the driver (GV-008).

Probes (qualification probes, not policy source, and not part of
`Tests.bend`): [Bang.bend](../../scripts/gpu-validation/Bang.bend),
[Solver.bend](../../scripts/gpu-validation/Solver.bend),
[Labels.bend](../../scripts/gpu-validation/Labels.bend),
[Transfers.bend](../../scripts/gpu-validation/Transfers.bend), with modes
`run`, `parity`, `inject`, `bench` and (Labels only) `bench-forged`. Harness:
[observe.sh](../../scripts/gpu-validation/observe.sh) (plain pass plus an
observed pass under compute-sanitizer, writing the validation-run record v1)
and [check-record.sh](../../scripts/gpu-validation/check-record.sh) (the
hardware-evidence gate). The harness makes no Writ authority, label or
admission decision; every comparison of results is in the Bend probes.

Evidence files, all under [verification/](../../verification/):
[gpu-toolchain.txt](../../verification/gpu-toolchain.txt),
[gpu-gate-controls.txt](../../verification/gpu-gate-controls.txt),
[gpu-paths.txt](../../verification/gpu-paths.txt),
[gpu-parity.txt](../../verification/gpu-parity.txt),
[gpu-injection.txt](../../verification/gpu-injection.txt),
[gpu-corpus.txt](../../verification/gpu-corpus.txt) (captures
[gpu-corpus-on.txt](../../verification/gpu-corpus-on.txt) and
[gpu-corpus-off.txt](../../verification/gpu-corpus-off.txt)),
[gpu-pipeline.txt](../../verification/gpu-pipeline.txt),
[gpu-trust-profile.md](../../verification/gpu-trust-profile.md); the
per-configuration table [gpu-validation-hosts.md](../../verification/gpu-validation-hosts.md)
and the final checks [gpu-final-checks.txt](../../verification/gpu-final-checks.txt).

Library correctness and the GPU claim are separate. A PASS count is a
correctness result for the tree it ran on. GPU evidence exists only for runs
with observed `bend_dev` launches attributed to the binary; CPU references,
verifiers, replays and every `--gpu off` run are CPU execution. "Reviewed-only
gap" quotes the requirement's own words for the part with no execution here.

| Requirement | Probe mode | Executed evidence (file, section) | Reviewed-only gap |
| --- | --- | --- | --- |
| GV-001 Require observed physical execution | bang `on N`, `off`, default, hidden device, `on 0`; every observe.sh run of the path probes | Scenario "Forced fallback succeeds computationally": gpu-gate-controls.txt, "control (b)", "control (c)", "control (c2)" and "Result" (`--gpu off` and the silent default fallback compute PASS and the gate refuses them). Scenario "Device is present but execution is unobserved": "control (e)" (device opened, 0 launches, gate FAIL) and "control (g)", "control (g2)", "control (h)" (missing, contradicted or truncated observer log, gate FAIL). Observed execution: "control (a)", "control (a-long)" (500 and 3000 launches, gate PASS); gpu-toolchain.txt, "Observer 1: compute-sanitizer" | The gate checks that files agree, not signatures: it "does not resist a forger who rewrites a log and its record consistently" (gpu-gate-controls.txt, "Limits"). Device identity is exact on this one-GPU host only. compute-sanitizer strips an empty `CUDA_VISIBLE_DEVICES` from its target, so hiding the device needs an invalid id (gpu-gate-controls.txt, "Result", the observer finding). Harness notes (gpu-gate-controls.txt, "Limits"): `target_cuda_visible_devices` is inferred from a separate `compute-sanitizer sh -c` probe, not read from the probe binary's environment; observe.sh does not remove the sanitizer log before the observed pass (safe only because the sanitizer overwrites it); check-record.sh does not compare the `pmon_max_sm` pid with the `compute_app_seen` pid, and accepts any `ERROR SUMMARY` line without comparing its count with the dumped launches |
| GV-002 Validate all three native calculation paths | Solver, Labels, Transfers `run 16`, `run 16384`, long runs; GpuExample combined | Scenario "Three paths have attributable evidence": gpu-paths.txt, "Solver, s16384", "Labels, s16384", "Labels, long", "Transfers, s16384", "Transfers, long" (gate PASS, own single-bang binary each) and "Result" (the three-path sentence, scoped to this configuration). Scenario "Only the graph solver ran on the GPU": the corpus is that case and is recorded as solver-only GPU evidence (gpu-corpus.txt, "Result", "Limits") | The combined run's per-path split is "an inference from the launch grids, not an observation" (gpu-paths.txt, "Result"). The SIZE 16 runs fail the gate on presence and are recorded as refused |
| GV-003 Match reference decisions and verifier outcomes | `parity CASE`, `inject CASE N`; corpus `--gpu on` and `--gpu off` | "Wide restriction bits are changed": gpu-parity.txt, "solver-bit31-secrecy", "solver-bit32-untrusted", "solver-bit63-effects", "solver-wide-dimensions"; gpu-injection.txt, "solver-inject-clear-bit63". "Old epoch is presented as current": gpu-parity.txt, "labels-stale-epoch", "transfers-stale-context"; gpu-injection.txt, "solver-inject-stale-stamp", "transfers-inject-stale-context". "Stable malformed solver output": gpu-injection.txt, "solver-inject-drop-node", "solver-inject-erase-source" (Core.verify on the original graph refuses, 500 of 500). "Policy batch fabricates an allowance": gpu-injection.txt, "labels-inject-flip-denial", "transfers-inject-fabricate-admitted", "transfers-inject-forged-commit". Library-wide: gpu-corpus.txt, "Result" (782 PASS on and off, byte-identical to `verification/tests-native.txt` as of 98db68bf, sha256 `fc3a08aa...062916ff`, on the 782 tree); on the merged tree, corpus "Merged tree, 2026-11-05", "Result (merged tree)" (1428 PASS on and off, byte-identical to `verification/tests-native.txt` on the merged tree, sha256 `6faee219...9318`) | Label and transfer checks reuse the evaluator: "Dlm.verify_batch and the transfer replay are the same evaluators as the CPU reference ... they do not show an algorithm independent of the producer" (gpu-injection.txt, "Limits"); only Core.verify is a separate algorithm. The corpus exercises the solver bang only on the device: "Label and transfer batches in the corpus are host-side calls without `!`" (gpu-corpus.txt, "Limits"). No 32-bit digest is equality evidence (gpu-injection.txt, "Result", the digest-collision finding); the Task 3 cross-process comparisons at 16384 show equal counts only (gpu-paths.txt, "Limits"); the typed comparisons and gpu-parity.txt are the record. Finite synthetic cases; no fault inside the device, runtime or managed memory |
| GV-004 Bind evidence to reproducible inputs and environment | every observe.sh run (record v1); record tampering controls | Required fields: [check-record.sh](../../scripts/gpu-validation/check-record.sh) `REQUIRED` (source hashes, Bend, Base, compiler, CUDA home, NVRTC, build flags, emitted C, binary and `.gpu` sha256, arch, driver, device name, UUID, bus, `CUDA_VISIBLE_DEVICES`, RTS options, threads, workload, outcomes). Scenario "Driver identity is absent": gpu-gate-controls.txt, "control (f)" (`INCOMPLETE: missing driver_version`, exit 2). Scenario "Source changes after the measured run": gpu-validation-hosts.md, "Source binding" (the 782-tree corpus rows bind the 782 tree; `Tests.bend` changed on the merged tree, so they do not establish the 1428 tree; the merged tree was therefore rerun and bound separately: gpu-corpus.txt, "Merged tree, 2026-11-05", 4915 launches, gate PASS) | Only `driver_version` was deleted in an executed control; the other required fields are enforced by the same `REQUIRED` loop, by review. binary_sha256 "is hashed at run time and not re-hashed by check-record.sh, so a later rebuild does not invalidate an old record" (gpu-gate-controls.txt, "Limits"). The gate also does not re-check `gpu_program_sha256` or `gpu_arch` against the files, nor confirm that the module launched is the hashed cubin; the record carries those fields |
| GV-005 Measure the complete required pipeline | `bench SIZE 20` at 16, 1024, 16384; compile runs | gpu-pipeline.txt, "Series ..." (raw per-repetition lines), "Summary", "Result" (cold pipeline and warm total include startup, prep, device call, verify, check, tail); scenario "Warm inputs differ from cold inputs": the cold and warm conditions are defined and reported separately (header "Conditions", "Result"); scenario "Kernel timing excludes dominant transfer work": the GPU complete path is reported slower in every cell, and no kernel-only number exists | No Nsight split: "Missing field: the split of device_call_ms into managed-memory movement, dispatch and per-round kernel time ... neither is installed ... no value is estimated" (gpu-pipeline.txt, "Limits"). Timing not representative on a loaded host: "Every series is labelled 'taken on a loaded host; not representative'" (gpu-pipeline.txt, "Limits"). Stage attribution of verify and check assumes forcing at the binding, unproven (each series' caveat). The `IO.now` timer has 1 ms resolution: components below 1 ms print 0 and several warm ratios are undefined (gpu-pipeline.txt, "Limits"). No throughput figure is reported |
| GV-006 Correctness precedes performance acceptance | Labels `bench-forged 16384 200` (Task 5) and `bench-forged 16384 20` (Task 7); the acceptance rule over 72 timing runs | Scenario "Faster result has a wrong policy decision": gpu-injection.txt, "labels-forged" and "Result", the wrong-but-faster table (1164 ms, PASS 3 FAIL 3, gate FAIL, time not accepted); gpu-pipeline.txt, "Rejected" (both forged runs rejected; 72 of 72 timing runs accepted only with their attestations) | The forged run is a probe-side fake that never calls the device; no wrong device kernel was run. Timing not representative on a loaded host |
| GV-007 Limit performance claims to measured evidence | `bench SIZE 20` series | Scenario "No hardware measurement exists" and "One workload is faster": gpu-pipeline.txt, "Result" ("No speedup was measured, so this file contains no speedup sentence"; ratios carry their size, condition and configuration; nothing extrapolated) | No speedup or threshold claim exists to scope. Timing not representative on a loaded host; no quiet-host series |
| GV-008 Enforce a boundary for untrusted-device claims | none (no profile claims an untrusted device) | gpu-trust-profile.md, "Profile" (GT-1 trusted device, the only profile), "The managed heap is shared and writable" (`cuMemAllocManaged` of the whole term heap, stated not to be protection), "Threat-model exclusion" | Hostile device code and drivers excluded: a limit. "A profile treating GPU programs or the driver as untrusted SHALL protect authoritative monitor state and final commit with an enforced memory/device boundary independent of the candidate verifier": no such profile, boundary or access-denial test exists; both scenarios ("Device can write the verifier's authoritative heap", "Separate process retains a privileged shared-memory writer") are unexecuted. Task 4.2 stays open |

## Proof and verdict limits

The lane adds no laws and no library source. On the merged tree
`bend PROOF.bend` prints `ALL PROOFS CHECK` for the seventeen declared laws,
none of them about GPU execution. No Lean verdict: `bend PROOF.bend --verdict`
refuses because Lean is not on PATH (gpu-final-checks.txt). Nothing here is a
GPU proof.
