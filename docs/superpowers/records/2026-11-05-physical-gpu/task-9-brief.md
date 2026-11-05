### Task 9: Publish, trace, and final checks (4.3)

Requirement IDs: all of GV-001 to GV-008, for traceability. Spec task 4.3.

Write `verification/gpu-validation-hosts.md` in the shape of `runtime-profile-hosts.md`. It has one row per executed configuration: bang, solver, labels, transfers, combined example, corpus on, corpus off, and the bench series. The columns are:

- configuration;
- output and PASS count;
- `bend_dev` launches and observer;
- `--gpu` mode and `CUDA_VISIBLE_DEVICES`;
- device UUID and driver;
- compiler, NVRTC, and arch;
- binary and `.gpu` sha256;
- harness command;
- gate verdict;
- evidence section.

Add a gap list. It names, at least, no kernel-only or transfer-split timing, no untrusted-device profile, and any path or case without launches.

Write `openspec/traceability/gpu-validation.md`, in the shape of the other traceability files, with GV-001 to GV-008 rows. Each row names the probe mode, the evidence file and section, or an explicit reviewed-only gap.

Add pointers to PX-001 and PX-008 in `parallel-execution.md` and a dated host section in `VERIFICATION.md` "GPU-directed source". Keep the earlier "no `/dev/nvidia0`, no CUDA toolkit" paragraph as the record of that environment, and say that this host differs.

Check `tasks.md` boxes only where their acceptance passed, each citing its file. Leave failed or partial ones unchecked with a one-line reason. Run the validation commands from Global Constraints and put their outputs in `verification/gpu-final-checks.txt`:

- `bend Tests.bend`: 782;
- `bend PROOF.bend`;
- `--verdict`: the refusal, verbatim;
- OpenSpec strict;
- `git diff --stat master -- '*.bend'`: only `scripts/gpu-validation/`. Name each probe file and state that it is a qualification probe, not policy source.

Do not archive the change. Archiving is a controller decision after landing.

Acceptance: every claim in `VERIFICATION.md` and the traceability file links to an evidence section; every unchecked box gives its reason; all five checks are recorded; and the `.bend` diff is limited to the probes.
