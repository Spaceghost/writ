# Physical GPU validation tasks

All hardware, implementation, and measurement work below is pending.

## 1. Establish attributable hardware execution

- [x] 1.1 Implement a versioned validation-run record and verify that source hashes, toolchain/runtime/backend versions, device/driver identity, flags, and workload identifiers are required fields.
  Evidence: `verification/gpu-gate-controls.txt` ("Result", "control (f)"). The record v1 is written by
  `scripts/gpu-validation/observe.sh`; `check-record.sh` lists every required field in `REQUIRED` and
  refuses a record missing one (`INCOMPLETE: missing driver_version`, exit 2). Only the `driver_version`
  deletion was executed; the other fields are enforced by the same loop, by review.
- [x] 1.2 Implement the hardware-required profile and verify that forced CPU fallback fails its hardware-evidence gate while leaving ordinary library fallback behavior intact.
  Evidence: `verification/gpu-gate-controls.txt` ("Result": controls (b), (c), (c2) compute PASS on the
  CPU and the gate refuses them; only (a) and (a-long) pass). Ordinary fallback is intact:
  `verification/gpu-corpus-off.txt` (782 PASS with `--gpu off`, `verification/gpu-corpus.txt`, "Result").
- [x] 1.3 Compile and execute each of the three device-requesting paths on a supported physical GPU; retain attributable dispatch/completion evidence and document the exact supported configuration.
  Evidence: `verification/gpu-paths.txt` ("Result": solver, label batch and transfer batch each with observed
  `bend_dev` launches in its own single-bang binary and gate PASS; the configuration is in the header and
  each record) and `verification/gpu-validation-hosts.md`. Scoped to that one configuration.

## 2. Establish semantic parity

- [x] 2.1 Add Bend differential cases for both producers and policy batches, including bits 31/32/63, cycles, empty input, conflicts, stale epochs, and missing grants; verify complete results against the CPU reference and existing finite oracle where applicable.
  Evidence: `verification/gpu-parity.txt` ("Result": 20 cases, 18 device-validated, 0 differences, `--gpu off`
  stdout byte-identical); the finite four-node oracle runs in the corpus (`verification/gpu-corpus.txt`,
  "Result", 782 tree). Solver `empty` and `invalid-flow` dispatch nothing, so their parity is CPU-path only.
- [x] 2.2 Inject malformed, truncated, stale, and forged results and verify that original-graph validation, label replay, and live transfer admission deny them without output effects.
  Evidence: `verification/gpu-injection.txt` ("Result": 11 injected faults, each denied in every round by
  Core.verify, Dlm.verify_batch or Transfer.admit, with no effect; the forged commit is refused with the
  session and ledger unchanged). The label and transfer replays are the producers' own evaluators.
- [x] 2.3 Gate performance-report acceptance on successful correctness checks and verify that an intentionally wrong but faster result remains a failed run; document any scenario lacking hardware coverage.
  Evidence: `verification/gpu-injection.txt` ("Result", wrong-but-faster table: the forged faster run is a
  failed run, time not accepted; "No hardware coverage" list) and `verification/gpu-pipeline.txt`
  ("Rejected"; the acceptance rule).

## 3. Measure the whole pipeline

- [ ] 3.1 Capture host preparation, memory movement, dispatch, all calculation rounds, returned results, and independent verification/replay in total latency and throughput; verify that the reported total covers every required stage.
  Unchecked: the totals cover every stage (`verification/gpu-pipeline.txt`, "Result"), but memory movement,
  dispatch and kernel time are one bundled component, a missing field without Nsight, and no throughput
  figure is reported.
- [x] 3.2 Run matched CPU/GPU workloads with declared cold and warm conditions, sizes, and repetition methods; verify any speedup statement against the recorded end-to-end measurements and report regressions as measured.
  Evidence: `verification/gpu-pipeline.txt` ("Result", "Limits": nine matched series, cold and warm,
  sizes 16, 1024, 16384, REPS 20, interleaved pairs plus A-versus-A; no speedup statement; the slower GPU
  cases reported as measured). Every series is labelled "taken on a loaded host; not representative".

## 4. Record the trust boundary and evidence

- [x] 4.1 Document which compiler, runtime, host, GPU code, and driver components are trusted for each profile; verify that a shared writable monitor heap is never described as protection from those writers.
  Evidence: `verification/gpu-trust-profile.md` (physical-gpu lane, Task 8). One profile, GT-1 trusted
  device: the Bend 2.0.39 compiler and runtime, clang 23.1.1, NVRTC 13.4 and its `.gpu` cubin, the CUDA
  driver 615.71.09 (user-mode `libcuda` and the kernel module), the host kernel and user account, the
  display stack and other device clients, and the harness scripts are all trusted. The runtime's
  `gpu_map` allocates the whole term heap with `cuMemAllocManaged`, and the file states that this
  shared writable heap is not protection from device code or the driver.
- [ ] 4.2 For any profile claiming an untrusted GPU program or driver, implement the selected enforced memory/device boundary and verify denied access to authoritative snapshots and commit state; otherwise explicitly exclude that hostile component from the validated threat model.
  Unchecked: the exclusion is a recorded limit, not the boundary. No profile here claims an untrusted
  GPU program or driver; GT-1 excludes hostile device code and a hostile driver from the validated
  threat model, stated beside GV-008's own words (`verification/gpu-trust-profile.md`, "Threat-model
  exclusion"). By controller ruling (plan Global Constraints, 2026-11-05) that exclusion does not close
  this task's intent: no enforced memory/device boundary is implemented and no access-denial test exists.
- [x] 4.3 Publish the actual run artifacts, map scenarios to their evidence, run applicable Bend/proof checks and strict OpenSpec validation, and update verification claims only for configurations that passed.
  Evidence: `verification/gpu-validation-hosts.md`, `openspec/traceability/gpu-validation.md`,
  `VERIFICATION.md` ("GPU-directed source", the 2026-11-05 section) and `verification/gpu-final-checks.txt`
  (Tests 1428 on the merged tree, PROOF `ALL PROOFS CHECK`, `--verdict` refused without Lean, OpenSpec
  strict, the `.bend` diff limited to the probes). Claims are limited to the configurations that passed.
