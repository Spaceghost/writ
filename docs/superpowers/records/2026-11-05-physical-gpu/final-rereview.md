# Final re-review: physical-gpu final fix round (c5f5982 on f23ce66)

This is a scoped re-review of `git diff f23ce66 c5f5982 -- . ':!docs/superpowers/records'` and of the
"Final fix round" section of task-9-report.md. It was read-only, and no GPU workload was rerun.

**Assessment: Ready to merge**

## Findings

| Item | Status | Evidence |
| --- | --- | --- |
| Planned 1: device corpus on the merged tree | CLOSED | See "Merged-tree corpus chain" below. |
| I-1: "byte-identical" names its capture | CLOSED | Every tests-native comparison is pinned to its capture. Task 6 rows give the file as of 98db68bf (`fc3a08aa...`). Merged-tree rows give the file on the merged tree (`6faee219...`). Fixed in VERIFICATION.md:203-212, gpu-trust-profile.md:186, gpu-validation-hosts.md:62-65, gpu-validation.md GV-003 and tasks.md 1.2. The remaining "byte-identical" phrases (parity, gpu-trust-profile.md:92) name their own comparison. |
| I-2: inferred `target_cuda_visible_devices` and the harness notes | CLOSED | All are stated in gpu-gate-controls.txt (Harness note and Limits), the GV-001 gap and the trust-profile gate row: the inference from a separate `compute-sanitizer sh -c` probe, `$SANLOG` not removed, and the pmon pid not compared. The harness is unchanged (efd08afb/7d4df17b), so every record binding still holds. |
| I-3: gpu-parity.txt:3982 hash | CLOSED | The hash is `db3438f7ad2d6c9a283fb25c30b67adcbc83e50949db91c30b255dcbeeba7bfb`: 64 characters, equal to `sha256sum ../writ-build/physical-gpu/task4/solver.gpu`. The transcription note is on the next line. |
| M-1: CVD stripping and the 1 ms timer in the traceability gaps | CLOSED | The CVD stripping is in the GV-001 gap and the timer is in the GV-005 gap. |
| M-2 / Task 9 Low 1: load range | CLOSED | The fix is in hosts:97-100 and in the first sentence of gpu-pipeline.txt:4482. The pipeline bullet now repeats the same facts in its later sentences. That is redundant but no longer contradictory, and it is optional to trim. |
| M-3 / Task 9 Low 2: "slower in every cell" | CLOSED where carried | VERIFICATION.md and parallel-execution.md:27 now say "took longer than `--gpu off` ... this is not a performance result". The residual phrasing is noted below. |
| M-4: fused sentences | CLOSED | In VERIFICATION.md and PX-001, the GPU sentence now names only the launches and gate PASS. A separate "CPU-side outcomes" sentence follows. |
| M-5: ERROR SUMMARY count, gpu sha/arch not re-checked | CLOSED | Stated in the trust-profile gate row, the GV-004 gap and gpu-gate-controls.txt Limits. |
| M-6: tasks.md 1.2 scope | CLOSED | Box 1.2 is pinned to the 782 tree at 98db68bf. |
| tasks.md line 3 | CLOSED | Line 3 now lists the checked boxes and gives the reasons 3.1 and 4.2 stay open. |
| parallel-execution.md intro | CLOSED | The intro now says "baseline evidence does not validate GPU hardware", points to PX-001/PX-008 and gpu-validation.md, and keeps scheduling performance and isolation unvalidated. |
| O-1: injected-faults row | CLOSED | The row now covers 15 records (11 injected, 2 honest, 1 digest, 1 forged). |
| O-2: "all-field digest" | Not changed (optional, accepted) | No change needed. |
| O-3: "Signal" note | CLOSED | Note added at gpu-trust-profile.md:72-75. |

## Merged-tree corpus chain (verified on disk)

- **Build.** `../writ-build/physical-gpu/task9/tests-gpu` has sha256 `33cfab7b...482b` and `.gpu` `fad1046d...8fb1`, both equal to the record and the hosts row. I ran `tail -c +9` on the `.gpu`, then `cuobjdump -elf` gives `sm=89`, and `-sass` lists `bend_dev` (and `window_dev`). The record's `gpu_arch` is `sm=89`.
- **Observed run and gate.** I reran `check-record.sh runs/task9/tests-gpu-on/record.txt`: `gate: PASS`, exit 0. `--count-launches` on the observed sanitizer log gives 4915. The threads-4 supplementary log also gives 4915. The `Target application` line is `.../task9/tests-gpu +RTS --gpu on -RTS`. Every line of the stored record appears verbatim in gpu-corpus.txt. Every `source_sha256` entry matches the current file.
- **Comparison.** `cmp` exits 0 for each pair: on against off, on against `verification/tests-native.txt`, off against tests-native, and the observed stdout against tests-native. All of them have sha256 `6faee219...9318`, the hash the section names, with 1428 PASS lines.
- **Separate sentences.** gpu-corpus.txt "Result (merged tree)" gives library correctness and the GPU claim (solver bang only) as separate paragraphs. VERIFICATION.md, the hosts table, GV-003/GV-004 and the trust profile no longer say that the merged tree lacks a device corpus run; a grep for that wording finds nothing. The trust profile now says "a later tree needs its own run".

## Checks run on c5f5982

- `bend Tests.bend` exits 0 with 1428 `PASS` lines, 0 `FAIL` and `ALL LIBRARY TESTS PASSED`. Its stdout sha256 is `6faee219...`, the same as tests-native.txt.
- `bunx @fission-ai/openspec@1.16.0 validate --all --strict --no-interactive` reports `Totals: 44 passed, 0 failed (44 items)`.
- `git diff --name-only master -- '*.bend'` lists only the four scripts/gpu-validation probes.

## New or residual (non-blocking, optional)

- The same "slower in every cell" phrasing survives outside the carried scope. It appears in openspec/traceability/gpu-validation.md:58 (GV-005: "the GPU complete path is reported slower in every cell"), verification/gpu-validation-hosts.md:66 and verification/gpu-trust-profile.md:187. Each sits beside "not representative" or "no speedup" labels. Optionally reword them to "took longer than `--gpu off` ... not a performance result" so the wording matches VERIFICATION.md.
- gpu-pipeline.txt:4482 states the load facts twice; optionally trim the second statement.
- Controller step, still pending: regenerate `verification/source-sha256.txt` before merge, as planned.
