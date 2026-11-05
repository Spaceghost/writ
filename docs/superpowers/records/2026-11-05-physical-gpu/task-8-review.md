# Task 8 review: trust profile (4.1, 4.2)

Reviewed: c0ff001 against 8e79ddc (`verification/gpu-trust-profile.md`, tasks.md boxes 4.1 and 4.2).

## Verdicts

1. Spec compliance: **APPROVED**
2. Honesty and precision: **NEEDS_FIXES** (no overstatement of a boundary, of adversarial completeness, of a Lean verdict or of performance; one checklist limit is missing, and the trusted list leaves out several components the cited evidence depends on)

## Findings (highest severity first)

### 1. Medium: the 1 ms timer limit is omitted (gpu-trust-profile.md:161)
The pipeline row's "Does not show" column names the missing Nsight split, the unexplained growth of the verify stage and the quiet host. It leaves out two limits that gpu-pipeline.txt "Limits" records. First, IO.now truncates CLOCK_MONOTONIC to integer ms, so components at 16 leaves and most `--gpu off` components sit at the resolution floor and several warm ratios are undefined. Second, the probe does not establish that each mark sees fully evaluated values.
Fix: add to that cell: "per-stage components below the 1 ms timer resolution (IO.now truncates CLOCK_MONOTONIC; several warm ratios are undefined); that each stage's work is not deferred past its mark".

### 2. Medium: the trusted list omits components the evidence depends on (gpu-trust-profile.md:71-86)
The file says that nothing executing during a GPU run is outside the trusted base (line 90). The list should therefore name everything the cited results rest on. Missing:
- Writ modules the probes import beyond the five named: `Ledger`, `Frontend`, `Backplane` and `Negotiation`, imported by `scripts/gpu-validation/Transfers.bend` (lines 54-57). `GpuLibrary.bend` is also the actual import behind `GPU.*`.
- Bend's `Base` library, including the C effect `effs/now.c` behind IO.now. gpu-pipeline.txt quotes it with its sha256, and every stage time comes from it.
- The interpreters and tools the harness runs: `/bin/sh` for observe.sh and check-record.sh; python3 for trun.py and summarize.py, whose CLOCK_MONOTONIC readings and acceptance rule produce the process wall times and decide which runs are accepted; and `sha256sum`, `diff` and `cmp`, on which every "byte-identical" and hash-binding claim rests.
- `cuobjdump`, the source of the "sm_89 cubin with `bend_dev`" fact cited at line 155 (gpu-toolchain.txt "Build").

Fix: add these to the existing bullets (library, harness, observers). Change "trusted only for the PASS and FAIL lines and gate verdicts they print" (line 71) to also cover summarize.py's run-acceptance decisions and statistics.

### 3. Low: line 85 overstates what supports the library's correctness
"Their correctness claims rest on the library corpus and the proofs" does not say where the proofs stand. This lane ran no `bend PROOF.bend`. No Lean verdict exists (line 242). The proof checker is the trusted Bend toolchain itself.
Fix: "... rest on the library corpus and on proofs checked by Bend's own checker (not rerun in this lane; no Lean kernel verdict, see 'What would strengthen the profile')."

### 4. Low: line 140, "not detected by anything in this lane's evidence", is imprecise in the other direction
In a probe run, a device or driver write that changes printed output would show up in the cross-process `--gpu off` stdout diff, because the `--gpu off` heap is a separate host mapping. That diff is an after-the-fact test comparison over fixed synthetic inputs. It is not a runtime guard, and a write that leaves the output unchanged, or one that happens outside a probe, goes unseen.
Fix: "... is not detected by any check that guards a run; only the after-the-fact `--gpu off` stdout comparisons of the probe runs would surface such a write, and only if it changed printed output."

### 5. Low: the gate row omits the binary_sha256 limit (gpu-trust-profile.md:156)
gpu-gate-controls.txt "Limits" also says: "binary_sha256 is hashed at run time and not re-hashed by check-record.sh, so a later rebuild does not invalidate an old record." This belongs to the same authenticity column.
Fix: append that sentence, quoted, to the "Does not show" cell.

### 6. Low: the Task 7 harness hashes are cited to the wrong section (gpu-trust-profile.md:75-76)
"quoted with hashes in verification/gpu-pipeline.txt, 'Harness'". The script texts are under "Harness" (line 139). Their sha256 values are in "Build" (lines 114-118).
Fix: "quoted in 'Harness', with their sha256 in 'Build'".

### 7. Low: the device clients are identified beyond what the record says (gpu-trust-profile.md:65-70)
The `nvidia-smi` table truncates three names to `...rack-uuid=...`. Task 1's "Result" identifies the compute clients as "a browser GPU process, Signal, and a long-running AppImage process, PID 633329". The profile's "browser processes (two of them `C+G`)" reidentifies them and drops Signal. The table is also a single snapshot (2026-11-04 21:01 CST). The clients present during the Task 2 to 7 runs were not listed.
Fix: quote the truncated names as recorded, cite Task 1's identification, and add "a snapshot at one time; the clients during later runs were not recorded".

### 8. Low: "validates" (gpu-trust-profile.md:26)
"It is the only profile this lane validates" can be read as qualifying GT-1 as a profile. Lines 30-33 and 259 say the opposite.
Fix: "It is the only profile under which this lane's evidence is stated."

No finding on: the boundary language (every "protect"/"boundary" is negated, quoted or future work); the 11 injections, which are not presented as a search; the absence of any performance claim or Lean claim.

## What I verified
- Read the brief, the report, the diff, the plan's Global Constraints (touch list, cross-lane ruling at plan line 38, "Lean is not on PATH" at line 14), GV-008, design.md "Trust profiles require real boundaries", and every Result and Limits section of gpu-toolchain, gpu-gate-controls, gpu-paths, gpu-parity, gpu-injection, gpu-corpus and gpu-pipeline.
- Fresh strings read: `sha256sum` of the pinned bend is `2ec160fa4486d33a...2045cd`, equal to gpu-toolchain.txt line 110. `strings -n 6 ... | sed -n '256429,256438p;256601,256609p'` gives `static u64* gpu_map` at 256429, the `cuMemAllocManaged(&p, bytes, CU_MEM_ATTACH_GLOBAL)` line at 256431 (equal to Task 1's grep at gpu-toolchain.txt lines 278-279), and `CORPUS = gpu ? gpu_map(size) : corpus_map(size);` at 256607. The excerpt's `...` elisions are honest. `#define gpu_map pool_mmap` (256282) applies only under `!BEND_CUDA`, so it does not contradict the quote.
- The shaders guide sentence is quoted exactly (`bend guide shaders`, line 22).
- GV-008's requirement and both scenarios, task 4.2's text and the design.md sentence are quoted exactly.
- Every quoted evidence phrase checked against its file is exact: the gate forger sentence, the paths "logical check, not a memory-protection boundary", the parity "replay the same evaluators", the two injection Limits quotes, the corpus 782/4915 figures, and the pipeline "likely but unestablished".
- The numbers in the opening example match gpu-injection.txt "Result" (fabricate-admitted, 1000 of 1000).
- Script hashes: observe.sh `efd08afb...`, check-record.sh `7d4df17b...` equal the committed files. The Task 7 harness names match gpu-pipeline.txt.
- Checklist limits present: digest collision (159), same-evaluator label and transfer checks (158, 159, 167), logical replay (163-168), Core.verify as the only separate algorithm (158, 247), file consistency rather than signatures (156, 245), identity on a one-GPU host (156), sanitizer unhiding (156), presence-poll gaps (157), loaded host (150), no Nsight (161, 236). Missing: the 1 ms timer (finding 1).
- Spec items: one profile; compiler and GPU backend, generated C and device program, clang, NVRTC and the cubin, UMD and KMD, host kernel and account, display and clients, harness, plus the additions, all named trusted. The heap is stated as no protection, in bold, with the allocation quoted. The exclusion is a limit, beside GV-008 and 4.2. The strengthening list is headed "None of the following is implemented". Box 4.1 is `[x]` citing the file; box 4.2 is `[ ]` with the ruling note.
- `git diff --name-only 8e79ddc c0ff001`: the profile, tasks.md, the task-8 report and activity.log only. All are within the touch list and records; no `.bend` change.
- `bunx @fission-ai/openspec@1.16.0 validate --all --strict --no-interactive`: 44 passed, 0 failed.
- Not run: `bend Tests.bend` and `bend PROOF.bend` (no source changed).
