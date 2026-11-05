# Task 9 review (publish, trace, final checks; 4.3)

Verdict 1, spec compliance: APPROVED
Verdict 2, record quality: APPROVED

No Critical or Important findings. Two Low items, neither blocking.

## Findings (by severity)

Low 1. verification/gpu-validation-hosts.md, gap "No quiet-host measurement" ("every timing was taken at a 1-minute load above 16 on 32 CPUs") and the host row ("10.79 to 99.82"). verification/gpu-pipeline.txt "Limits" itself says the load was above 16 at every series boundary except the start of solver 16384 (15.95) and fell to about 10 to 16 for a few minutes during that series. The gap sentence is slightly stricter than its source. Fix: "above 16 at every series boundary but one (15.95), and 10 to 16 for minutes inside the solver 16384 series (pipeline 'Limits')".

Low 2. VERIFICATION.md (new "Limits" paragraph) and parallel-execution.md (added sentence) say "the device path/device was slower than the CPU in every measured cell". It is stated with the loaded-host label and "no speedup is claimed", matching gpu-pipeline.txt "Result", but pipeline "Limits" also says "No timing number in this file is a performance claim", and the hosts-file preamble says "no performance claim". Optional fix: add "as measured on a loaded host, not a performance result" at those two sentences.

## Spec compliance, checked

- Five results recorded verbatim and consistent across report, gpu-final-checks.txt and the tasks.md 4.3 note: 1428 PASS, 0 FAIL, `ALL LIBRARY TESTS PASSED`; `ALL PROOFS CHECK` with 17 `Laws.` defs (I counted 17); the `--verdict` refusal text identical in report and file (lean not on PATH, exit 1); OpenSpec "44 passed, 0 failed"; `.bend` diff exactly Bang, Labels, Solver, Transfers under scripts/gpu-validation/, each named as a qualification probe, not policy source.
- GV-001 to GV-008 all have a traceability row with probe mode, evidence file and section, and a gap in the requirement's own words (GV-008 quotes the requirement and keeps 4.2 open). Scenario names match spec.md headings (all 15 scenarios appear).
- Six cited sections opened and matching the rows: gpu-gate-controls.txt "control (f)" and "Limits" (unsigned files, binary not re-hashed); gpu-paths.txt "Result" (three-path sentence, combined split "an inference from the launch grids") and "Limits" (digest note); gpu-injection.txt "Result" (digest collision, wrong-but-faster, "No hardware coverage"); gpu-pipeline.txt "Rejected", "Result", "Limits", "Stage split (missing field)" (header paragraph, line 30); gpu-corpus.txt "Limits" (label/transfer host-side); gpu-trust-profile.md "Profile", "Threat-model exclusion".
- Hosts table has the runtime-profile shape plus the ten requested columns, GPU executed (observed launches) vs CPU fallback stated per path, the loaded-host caveat, source binding, and the gap list (no kernel-only/transfer-split timing, no untrusted-device profile, paths and cases without launches, plus no merged-tree corpus run).
- PX-001 and PX-008 pointers appended; the original text is kept (the diff only appends); one sentence added after the limits paragraph.
- VERIFICATION.md: the earlier "no /dev/nvidia0 ... no CUDA toolkit" paragraph is retained with a "stays as history" line; the dated section says "This host differs" and states library correctness and the GPU claim as separate paragraphs.
- tasks.md: every checked box (1.1, 1.2, 1.3, 2.1, 2.2, 2.3, 3.2, 4.3) cites its file and section; 3.1 and 4.2 unchecked with reasons; 4.1 as Task 8 left it.
- Carried notes closed: gpu-paths.txt header and Limits (counts only; typed comparisons Solver.result_equal, Dlm.answers_equal, Transfers.Decisions.equal; gpu-parity.txt "Comparison"), with the old wording kept as history; gpu-corpus.txt Limits bullet; gpu-pipeline.txt "smallest measured ratio of the two pipeline columns" plus the nine stage-attribution caveats.
- No count pin touched, no manifest file, no library/test/proof source differs from master (`git diff master --name-only` outside records and verification: VERIFICATION.md, tasks.md, the two traceability files only).

## Record quality, checked

- Honesty of "no device corpus run on the merged tree": stated honestly and consistently in the hosts table (corpus rows labelled 782 tree, lane commit 98db68bf), its gap list, GV-003/GV-004 rows, VERIFICATION.md and gpu-final-checks.txt Limits. Not overstated: the rows claim only the 782 tree, and "source binding" says Tests.bend and FacadeTests.bend changed.
- No claim of a protection boundary (GT-1 and "not protection" stated), adversarial completeness (finite synthetic cases, forged run probe-side), performance result (labelled loaded, not representative), or Lean verdict ("No Lean verdict" in four places). The corpus is correctly scoped to solver-bang-only GPU evidence; the SIZE 16 gate FAILs and the 0-launch cases are disclosed rather than hidden.
- Merge clean: no conflict markers in *.md, *.txt, *.bend (grep returned nothing); `git diff --stat master -- '*.bend'` shows only the four probes (3875 insertions).

## Ran (merged tree, bend 2.0.39, run from the worktree root)

- `bend Tests.bend`: 1428 lines matching `^PASS[: ]`; last lines `Property: 324 checks passed; ...` and `ALL LIBRARY TESTS PASSED`.
- `bend PROOF.bend`: `ALL PROOFS CHECK` / `Use --verdict for mathematical validity.`; `grep -c '^def Laws\.' PROOF.bend` = 17.
- I did not rerun `--verdict` or OpenSpec; I compared their recorded outputs to the report (identical) and confirmed no spec file changed beyond tasks.md and the traceability files. No GPU run was made; this review is CPU-only.
