# Plan: Unikraft closing boots and rules (tasks 3.1, 3.2, 3.3)

Spec: `openspec/changes/add-unikernel-library-runtime/` section 3 and `openspec/changes/add-unikernel-appliance-host/` UA-001 to UA-010 (read them first; the appliance change is not implemented and this plan does not implement it; 3.2 applies its requirements to the library image as a checklist with evidence or a quoted gap per requirement). Every Unikraft run so far is a QEMU TCG boot on the CPU (`run.sh` passes `-accel tcg`). Task 3.1 wants the image booted under hardware acceleration and recorded apart from emulation; `/dev/kvm` exists on this host and is world-readable (`crw-rw-rw- root kvm`). Task 3.3 wants OpenSpec strict and the Bend checks on the final tree.

## Global Constraints

- Lane `lane/unikraft-closing`, worktree `../writ-lanes/unikraft-closing`, created from master after `lane/unikraft-signals` and `lane/unikraft-lanes` have landed, so the images booted are the shipped configuration. Environment as in the other Unikraft plans; `W` from `hosts/unikraft/scripts/env.sh`. Reuse the images the earlier lanes built (their sets and hashes are in the evidence files); rebuild only if a hash does not match, and say so.
- Touch only: `hosts/unikraft/scripts/run.sh` (an accelerator option, default `tcg`, that passes `-accel kvm` when asked; no other change), a new `verification/unikernel-kvm.txt`, a new `verification/unikernel-appliance-rules.md`, `docs/UNIKERNELS.md` (a KVM paragraph and the appliance checklist link), `verification/unikernel-matrix-unikraft.md` (the boot rows), `openspec/changes/add-unikernel-library-runtime/tasks.md` (boxes 3.1, 3.2, 3.3), `openspec/traceability/unikernel-library-runtime.md` (UL rows that gain executed evidence). No policy source, no host C, no Unikraft change.
- KVM boots are a different machine from TCG: record the host CPU model, kernel, QEMU version, and `-cpu` used (`-cpu host` under KVM; say if `max` was kept), and keep every KVM result in its own file and its own matrix column; never overwrite a TCG number with a KVM one. If `/dev/kvm` is refused (permission or a nested-virtualization error), record the exact error and leave 3.1 open.
- Heartbeat every 10 minutes in `docs/superpowers/records/2026-11-05-unikraft-closing/activity.log`; reports at `task-N-report.md` there; one commit per task; no manifest, no push.

### Task 1: KVM boots (3.1)

Add the accelerator option to `run.sh`. Boot, under KVM, the hello probe, the exit-code probes (success, die, exit, crash: the exit map must hold: 33, 35, 39, 253), the fault probe (overflow: message then 253), and the corpus image with `check-corpus.sh` (782 PASS, program lines equal to the reference); record wall times beside the TCG ones from the evidence files. Write `verification/unikernel-kvm.txt` and check 3.1 citing it.

Acceptance: every KVM boot has its console lines, exit code, and wall time; the exit map and corpus count hold; TCG records untouched.

### Task 2: Appliance rules applied to the library image (3.2)

Write `verification/unikernel-appliance-rules.md`: one row per UA-001 to UA-010 (quote each requirement's title from the appliance change's spec), with the evidence file and section that meets it for the library image, or an explicit gap in the requirement's own words. Run the rebuild drill the appliance change describes (a clean rebuild of one image from the pinned sources, with elapsed wall time and the resulting hash against the recorded one; note that Unikraft clean builds embed the build time so the hash differs, and say what is compared instead). Write the trusted-base statement (the libraries in the image from `unikernel-pins.txt` and the inventory, including the experimental signal library). Check 3.2 citing the file.

Acceptance: ten rows, each with evidence or a quoted gap; the drill's elapsed time and hash comparison recorded; the trusted-base statement names every library.

### Task 3: Final checks (3.3)

On the lane's tree: `bend Tests.bend` (782), `bend PROOF.bend`, OpenSpec 1.16.0 strict; record all three in the report and in `tasks.md` 3.3; confirm with `git diff --stat master -- '*.bend'` that no policy source changed across the unikernel lanes (name the Bend files that did change, if any, and why they are not policy). Update the traceability rows and the UNIKERNELS.md Open list to the final state.

Acceptance: three results recorded; the no-policy-change statement is backed by the diff; the box is checked.
