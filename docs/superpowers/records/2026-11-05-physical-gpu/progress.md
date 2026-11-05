# SDD ledger — plan: docs/superpowers/plans/2026-11-05-physical-gpu.md
Branch: lane/physical-gpu

Conflict scan: nine tasks, each with its own verification/gpu-*.txt; Tasks 2-8 add files under scripts/gpu-validation/ without rewriting another task's probe; Task 9 alone edits tasks.md, traceability, VERIFICATION.md. Plan rulings (probe location, shell harness) accepted. Open for Josh: Nsight install, a quiet host for Task 7. Threat-model exclusion (Task 8) is a recorded limit.
Task 1: dispatched implementer
Task 1: implementer DONE_WITH_CONCERNS (35c8b3b): CUDA build works; bang.gpu is sm_89 with bend_dev; compute-sanitizer counts launches (5 per bang). Rulings carried to every later task: sanitizer form is `--dump-kernel-launches --print-limit 0 --kernel-name-exclude regex=.*`; observe.sh fails closed on "were not printed"; gates require at least one attributed bend_dev launch, never a fixed count; nvidia-smi pmon is corroboration only; the -O3/-O2 mismatch in runtime-profile-parity.txt and check-binary.sh is a finding for a later records lane, not this one. Reviewer dispatched.
Task 1: review spec APPROVED, record NEEDS_FIXES (unbacked load range, unquoted rebuild, Execution line overclaims, -lcuda grep). Fix round 1 dispatched.
Task 1: complete (fix round 1 verified by the controller: load range backed, rebuild quoted, Execution line narrowed, -lcuda grep).
Task 2: dispatched implementer
Task 2: implementer DONE_WITH_CONCERNS (50ed67c): 12 controls, 2 pass (observed --gpu on), 10 refused. Rulings carried to later tasks: hide the device with an invalid CUDA_VISIBLE_DEVICES id (the sanitizer strips an empty one); the gate checks consistency of files, not signatures (a limit to state in the trust profile, Task 8); device identity from GPU 0 is exact on this one-GPU host only (state it). Reviewer dispatched.
Task 2: complete (review APPROVED both axes; four hardening notes carried to the final round).
Task 3: dispatched implementer
Task 3: implementer DONE_WITH_CONCERNS (d2a29e5): all three paths validated on the device (solver 15 launches, labels 5/6000, transfers 5/1000; combined 20), device results equal to CPU and verified on the original inputs. Rulings: the SIZE 16 gate failures (process ends before the 200 ms presence poll) stay recorded as refused, not reworked; the ROUNDS argument is accepted; the combined-run per-path split is an inference and is labelled so. Reviewer dispatched.
Task 3: review NEEDS_FIXES on both axes, text only (the transfer digest is not all-field; no denial control for labels/transfers stated; pre-commit capture and exit-status provenance). The central claim holds (54 hashes verified, nine records re-gated). Fix round 1 dispatched.
Task 3: fix round 1 verified by the controller (text only; digest fields stated; Limits lines added); complete.
Task 4: dispatched implementer
