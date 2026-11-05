# Task 6 review (commit 765d743, base 98db68b)

## Verdicts
1. Spec compliance: APPROVED
2. Evidence integrity: APPROVED (one minor, non-blocking finding)

## Findings (by severity)
- Minor, verification/gpu-corpus.txt:316-323 (Limits). The plan asks the Limits list to name that label and transfer paths are not exercised on the device by the corpus. That statement is present only in the header (line 8) and the GPU-claim sentence (line 312), not as a Limits bullet. Fix: add one Limits bullet, "Label and transfer batches in the corpus are host-side calls without `!`; the corpus does not exercise them on the device." Text only, no rerun.
- Info, verification/gpu-corpus.txt:144. `git diff --stat master -- '*.bend'` shows the four lane probes (scripts/gpu-validation/*.bend), which is the plan's expected set and matches the final-task check. Task-6-specific "no .bend change" is separately confirmed below. No fix.

## Verified (run by me)
- sha256 of gpu-corpus-on.txt, gpu-corpus-off.txt, tests-native.txt are all fc3a08aa...16ff. `cmp` of on/off, on/reference, off/reference all exit 0 (silent). PASS count 782 and final line "ALL LIBRARY TESTS PASSED" in both captures. The quoted diff/cmp results (lines 129-142) match.
- Commit touches only: activity.log, task-6-report.md, gpu-corpus-on.txt, gpu-corpus-off.txt, gpu-corpus.txt. `git diff 98db68b..765d743 -- '*.bend'` is empty; tests-native.txt and other CPU-era files untouched; no count pin touched.
- Build: BANGS 1, emitted C, binary and .gpu hashes recorded; the binary and .gpu sha256 on disk match the record (53eeea2b..., 40b1305c...); sm=89, kernels bend_dev/window_dev recorded.
- Rerun `check-record.sh` on the stored run record.txt: `gate: PASS`, exit 0. `--count-launches` on observed.sanitizer.log: 4915, as attributed (all bend_dev, host frames in tests-gpu).
- Two sentences kept apart (Result, lines 310 and 312): correctness explicitly "not GPU evidence"; GPU claim limited to Gpu.sweep's `run_tree!`, with label/transfer paths excluded.
- The gate pair (default 32 threads) vs captures (`--threads 4`) difference is stated in lines 8, 12, 319; the `--threads 4` capture is labelled "not individually observed" and the supplementary sanitizer run "not a gate record". A reader cannot take it as observed.
- Limits state: launches not attributed per test or per sweep (line 318), off-under-sanitizer result (exit 255, 0 launches, line 322, consistent with control (b)), unexercised options, no Nsight split. Wall times carry the load caveat (header line 4, line 314) with "no performance claim".
- Evidence shape: header with Execution line, ## Build, ## Run, ## Result, ## Limits, inline record v1 pair.

Not run: corpus or any GPU workload (per instructions). Controller rulings (threads, off-under-sanitizer, new build dir) not flagged.
