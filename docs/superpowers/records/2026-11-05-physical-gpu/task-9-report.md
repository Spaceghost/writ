# Task 9 report: publish, trace, final checks (4.3)

Status: DONE_WITH_CONCERNS

## Merge
`git merge master` (master at 1c73004) into lane/physical-gpu: clean, no conflicts (VERIFICATION.md merged automatically), merge commit dbed241. No conflict markers remain (grep over *.md, *.txt, *.bend). Every final check below ran on the merged tree.

## The five checks (verbatim; full record in verification/gpu-final-checks.txt)
1. `bend Tests.bend`: exit 0; 1428 lines matching `^PASS[: ]`, 0 `^FAIL`; last line `ALL LIBRARY TESTS PASSED`.
2. `bend PROOF.bend`: exit 0; `ALL PROOFS CHECK` / `Use --verdict for mathematical validity.`; 17 `def Laws.` declarations.
3. `bend PROOF.bend --verdict`: exit 1; stderr:
   `Error: BendTT infrastructure: the kernel did not build (lean: Executable not found in $PATH: "lean"); --verdict needs Lean v4.34.0 (elan toolchain leanprover/lean4:v4.34.0), or $BENDTT set to a built kernel`
4. `~/.bun/bin/bunx @fission-ai/openspec@1.16.0 validate --all --strict --no-interactive`: exit 0; `Totals: 44 passed, 0 failed (44 items)`.
5. `git diff --stat master -- '*.bend'`: exactly scripts/gpu-validation/Bang.bend (138), Labels.bend (968), Solver.bend (1213), Transfers.bend (1556); `4 files changed, 3875 insertions(+)`. Each is named in gpu-final-checks.txt as a qualification probe, not policy source.

## Diff (task commit)
- New: verification/gpu-validation-hosts.md (host row: GPU executed with observed launches, CPU fallback for the rest, loaded host; 11 configuration rows: bang, bang refused controls, solver, labels, transfers, combined example, parity, injection, corpus on, corpus off, bench series; source-binding note; gap list).
- New: openspec/traceability/gpu-validation.md (GV-001 to GV-008, each with probe mode, evidence file and section, and the gap quoted).
- New: verification/gpu-final-checks.txt (the five checks in the evidence-file shape).
- openspec/traceability/parallel-execution.md: pointers appended to the PX-001 and PX-008 rows and one sentence after the limits paragraph; nothing deleted.
- VERIFICATION.md, "GPU-directed source": the no-device paragraph kept, with one line marking it as that environment's record; new "2026-11-05: one GPU host" section. Library correctness and the GPU claim are separate paragraphs.
- openspec/changes/validate-physical-gpu-execution/tasks.md: 1.1, 1.2, 1.3, 2.1, 2.2, 2.3, 3.2, 4.3 checked, each citing its file; 3.1 left unchecked with its reason; 4.1 and 4.2 untouched (Task 8's state).
- verification/gpu-paths.txt, gpu-corpus.txt, gpu-pipeline.txt: the carried notes (below), text only.
- No count pin changed, no manifest, no archive, no .bend file.

## Traceability summary
| Req | Executed evidence | Gap |
| --- | --- | --- |
| GV-001 | gpu-gate-controls.txt controls (a), (a-long) pass; (b), (c), (c2), (e), (g), (g2), (h) refused | gate checks file consistency, not signatures |
| GV-002 | gpu-paths.txt, the three single-bang paths gate PASS | combined-run split inferred; SIZE 16 presence failures |
| GV-003 | gpu-parity.txt (bits, stale, fabricated allowance), gpu-injection.txt (malformed solver output), gpu-corpus.txt | label and transfer checks reuse the evaluator; corpus exercises the solver bang only on the device; no digest is equality evidence |
| GV-004 | check-record.sh REQUIRED; control (f); source binding in gpu-validation-hosts.md | only driver_version deletion executed; binary not re-hashed by the gate |
| GV-005 | gpu-pipeline.txt series and Result | no Nsight split; timing not representative on a loaded host; no throughput figure |
| GV-006 | gpu-injection.txt forged run; gpu-pipeline.txt Rejected | forged run is probe-side, no wrong kernel |
| GV-007 | gpu-pipeline.txt Result (no speedup sentence) | loaded host; no quiet-host series |
| GV-008 | gpu-trust-profile.md (GT-1, heap, exclusion) | hostile device code and drivers excluded: a limit; no boundary; 4.2 open |
No Lean verdict for any law.

## Carried notes closed
- Task 5 (digest ruling): gpu-paths.txt header paragraph and Limits now say the Task 3 cross-process comparisons at 16384 and in the long runs show equal counts only, for all three probes, and point to the typed in-process comparisons (Solver.result_equal, Dlm.answers_equal, Transfers.Decisions.equal) and gpu-parity.txt "Comparison". The original Limits wording is kept as history; the captured `digest equals` PASS lines are kept verbatim and declared not equality evidence.
- Task 6: gpu-corpus.txt Limits bullet added: the corpus's label and transfer batches are host-side calls without `!`, not exercised on the device.
- Task 7 Low 1: "smallest measured ratio" now says "of the two pipeline columns" is 2.07 and names 1.96 (cold process wall, solver 1024) as the smallest overall. No number changed.
- Task 7 Low 2: a stage-attribution caveat line under each of the nine series headings in gpu-pipeline.txt, quoting that probe's `v` and `e` bindings and stating forcing is unproven.
- Task 8: boxes 4.1 and 4.2 not redone.

## Concerns
1. The device corpus evidence is the 782 tree's (lane commit 98db68bf). On the merged tree Tests.bend and FacadeTests.bend differ from the recorded hashes, so the 1428 tree has no `--gpu on` corpus run. Stated in the hosts table, the traceability (GV-004) and VERIFICATION.md. The library modules of the path probes (Core, Gpu, GpuLibrary, Dlm, DlmGpu, Transfer, TransferGpu, Scenario and the rest) hash the same on the merged tree.
2. tasks.md line 3, "All hardware, implementation, and measurement work below is pending.", is now false; it was left because the touch list allows boxes only. Likewise parallel-execution.md's intro sentence ("It does not validate GPU hardware ...") was left because only the PX-001/PX-008 rows and the limits paragraph are in scope; the row pointers qualify it. The controller may want both lines amended.
3. Box 3.1 left unchecked: the totals cover every stage, but memory movement, dispatch and kernel time are one bundled component (no Nsight) and no throughput figure is reported. Box 3.2 checked though every series is labelled loaded-host, not representative; 1.1 checked with only the driver_version deletion executed (other required fields enforced by the same loop, reviewed). The controller may judge either differently.
4. The brief's "782" for Tests.bend is read under the cross-lane ruling as the count on this tree: 1428.
