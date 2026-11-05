# Task 7 review: whole-pipeline measurement

Reviewed: commit 96eeac5 (range 880c488..96eeac5), verification/gpu-pipeline.txt, the three bench sections, task-7-brief.md and task-7-report.md.

## Verdicts

1. Spec compliance: APPROVED
2. Evidence integrity: APPROVED

Two low-severity wording findings follow. Neither blocks approval.

## Findings (by severity)

### Low 1. "Smallest measured ratio" ignores a smaller one in the same file
verification/gpu-pipeline.txt:4450 says the smallest measured ratio is 2.07 (solver, warm total, 1024). The ratio table just above it (cold process wall, solver 1024) gives 1.96.
Fix: say "smallest measured ratio of the two pipeline columns is 2.07", or name 1.96 as the smallest overall. No number changes.

### Low 2. Evaluation-order caveat is in Limits but not at the probe
In the bench loop (for example Labels.bend `Labels.bench.reps`, in the 880c488..96eeac5 diff), `t1`..`t5` are bound with `+`, but `v` (verify_batch result) and `e` (expected-pattern result) are bound without it. Their cost is attributed to verify_ms and check_ms only if the IO.pure binding forces them before the next mark. The data is consistent with that: warm prep is 0 everywhere, off-mode verify_ms is nonzero, and the gpu-pipeline.txt Limits section (the "marks see fully evaluated values" bullet) states that this is unproven. This is the caveat the brief asks for, and it is stated.
Fix (optional): add one comment line in each bench section stating that stage attribution assumes v and e are forced at their binding, and that this is unproven.

## What I verified

Spec compliance:
- Nine series (solver, labels, transfers at 16, 1024 and 16384), REPS 20, eight plain runs each in the order on, off, off, on, on, off, on, on. That gives three interleaved pairs in both orders plus an on/on A-versus-A pair. 72 timing runs.
- Each series table row carries the load average before and after, plus the label "taken on a loaded host; not representative". The solver 16384 row notes the 15.95 start and the mid-series peaks.
- Each series has an on and an off attestation run beside it. The on attestation shows gate PASS with 300 or 100 bend_dev launches. The off attestation shows 0 launches and gate FAIL by design, explained. The timing runs themselves are plain, and the Execution line says they are not individually observed.
- Cold and warm are defined, stage times are taken inside the probe, and the compile-versus-pipeline runs are labelled "compile, not pipeline".
- Missing field: the memory-movement versus kernel-time split names Nsight Systems and Nsight Compute, is never estimated, and is stated as incomplete.
- Rejected: the Task 5 forged run (1164 ms, matching verification/gpu-injection.txt:2262 and 2486) and the Task 7 rerun (443.8 ms, exit 1, 3 FAIL). Both are listed as rejected with times not accepted. The digest-collision note is kept.
- Wording: "slower cases, every measured cell" and "break-even not reached" are scoped to this host, load and sizes. The file says explicitly that it contains no speedup sentence and that no timing number is a performance claim. It makes no claim about the library.
- Touch list: the diff against 880c488 touches only the three probes in scripts/gpu-validation/, verification/gpu-pipeline.txt, and the records directory (task-7-report.md, progress.md, activity.log). No other .bend files changed and no count pin was touched. grep for count pins in the evidence file found none. The 1428 hit is not there.

Evidence integrity:
- Stage marks, from the Labels.bend diff. t1 is taken before input construction. t2 is taken before the bang, t3 right after `IO.pure(... Labels.device ...)`, t4 after `Dlm.verify_batch` on the original inputs, and t5 after the expected-pattern check. Device call, verify and check are therefore attributed to separate marks. Repetitions 2 and up take t1 after the previous repetition's print, so printing is not counted. The CPU reference is timed separately and labelled as not a pipeline stage. The Solver.bend and Transfers.bend sections have the same shape, per the report and the diff statistics. The caveat is in Limits (see Low 2).
- Timer: IO.now is io_tick()/10^6, integer milliseconds. The file quotes now.c and states 1 ms resolution. Ratios whose CPU median is 0 print as "undefined" in the summary and the ratio table.
- A-versus-A: 388125 against 477950 ms (23.1 percent) and 12329 against 15196 (23.3 percent) match the summary lines. The file states the up-to-23-percent variation.
- Spot-checked six run records on disk against the file (series dir ../writ-build/physical-gpu/task7/series): solver-16/01-on, labels-1024/04-on, transfers-16384/03-off, solver-1024/06-off, labels-16384/08-on and transfers-16/02-off. The stdout sha256, spawn and exit monotonic times and 20 bench lines all match, and exit status 0 with all-PASS is consistent.
- Ran check-record.sh on all nine `--gpu on` attestation records (runs/task7/*-attest-on/record.txt): all gate PASS. The nine `--gpu off` records give gate FAIL for the stated reason (no device requested, sanitizer exit 255), as the file says.
- sha256 of the three probe sources and the first 20 hex digits of the three binaries equal the hashes in the file.
- Pre-commit capture stated (lane_commit 880c488 marked uncommitted; probe hashes equal the committed files).
- Limits list: loaded host, no Nsight, 1 ms timer, stage evaluation unproven, no repeat series (the plan allowed one), and also not exercised items and the one-attestation-per-series scope. This is complete.

Not run: no timing or GPU workload, no Bend build, no Tests.bend or PROOF.bend (no library source changed). Controller rulings (verify-stage growth, 644 KB file, kept stalled-attempt edits) were not flagged.
