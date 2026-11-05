# SDD ledger — plan: docs/superpowers/plans/2026-11-05-physical-gpu.md
Branch: lane/physical-gpu

Conflict scan: nine tasks, each with its own verification/gpu-*.txt; Tasks 2-8 add files under scripts/gpu-validation/ without rewriting another task's probe; Task 9 alone edits tasks.md, traceability, VERIFICATION.md. Plan rulings (probe location, shell harness) accepted. Open for Josh: Nsight install, a quiet host for Task 7. Threat-model exclusion (Task 8) is a recorded limit.
Task 1: dispatched implementer
Task 1: implementer DONE_WITH_CONCERNS (35c8b3b): CUDA build works; bang.gpu is sm_89 with bend_dev; compute-sanitizer counts launches (5 per bang). Rulings carried to every later task: sanitizer form is `--dump-kernel-launches --print-limit 0 --kernel-name-exclude regex=.*`; observe.sh fails closed on "were not printed"; gates require at least one attributed bend_dev launch, never a fixed count; nvidia-smi pmon is corroboration only; the -O3/-O2 mismatch in runtime-profile-parity.txt and check-binary.sh is a finding for a later records lane, not this one. Reviewer dispatched.
Task 1: review spec APPROVED, record NEEDS_FIXES (unbacked load range, unquoted rebuild, Execution line overclaims, -lcuda grep). Fix round 1 dispatched.
Task 1: complete (fix round 1 verified by the controller: load range backed, rebuild quoted, Execution line narrowed, -lcuda grep).
Task 2: dispatched implementer
