# Task 7 report: whole-pipeline measurement

Status: DONE_WITH_CONCERNS. Nine series ran: three paths at 16, 1024 and 16384 leaves, with REPS 20 and 8 interleaved plain runs each. All 72 timing runs were accepted, and every series is labelled "taken on a loaded host; not representative". The memory-movement versus kernel-time split is a missing field (Nsight Systems). Both forged runs are rejected. The device pipeline was slower than the CPU pipeline in every measured cell, so no break-even was reached. No number here is a performance claim.

Files changed (touch list only):
- `scripts/gpu-validation/Solver.bend` (sha256 50bc4d0d1da213216559f8fde9f2ea8c2c323f424c0673f10f16e0c59cb3fbcd), `Labels.bend` (2e8e114da808ff70b34aa2499e750297637349864a6f06bfb08f25eba384c6b6) and `Transfers.bend` (d12620da19b521dc8ad7e86857f5b2d95a743ec34afa3b90067515782e291e7e): each gains mode `bench SIZE REPS`. Other modes are unchanged; the diff adds the bench section, a usage line and a `main` arm, and extends the header comment.
- New `verification/gpu-pipeline.txt`. It holds the header, Build, the quoted harness, Run (every command, its exit status, the raw per-repetition lines, and the 18 attestation runs with 36 records inline), Summary, Result and Limits.

No other `.bend` file changed. observe.sh and check-record.sh are unchanged. There is no manifest change and no push. Builds are in `../writ-build/physical-gpu/task7/` (BANGS 1 per binary; cubins sm_89 with bend_dev and window_dev). Runs are in `task7/series/`, `task7/compile/`, `task7/forged/` and `../writ-build/physical-gpu/runs/task7/`.

## Kept from the stalled attempt
I reviewed the whole uncommitted diff and kept all of it unchanged: the three bench sections, the usage lines and the `main` arms. They were complete in all three probes. They type-checked, built, and passed smoke runs (`bench 16 3`, on and off, all PASS, stdout byte-identical). I also kept the first implementer's two activity-log lines and its finding on IO.now's unit, which I re-verified. I deleted its three stale `*-check.c` files from task7/; they had never been built into a binary. All the harness is new: build.sh, trun.py, series.sh, summarize.py, mkruns.sh and assemble.sh.

## Stage timer
- `IO.now()` returns `io_tick()/1000000` (Base `effs/now.c`, quoted), and io_tick is CLOCK_MONOTONIC in ns. So the unit is integer milliseconds, truncated, with 1 ms resolution.
- The probe takes five marks per repetition: t1 before input construction, t2 before the bang, t3 after the call returns, t4 after the independent check on the original inputs, and t5 after the expected-outcome check. Each repetition prints a stderr line with prep, device_call, verify, check, total and the raw marks.
- After the last repetition the probe times the CPU reference separately (it is not a pipeline stage), then runs run mode's checks over all 20 results. Any FAIL exits 1.
- The harness (trun.py) reads CLOCK_MONOTONIC around the spawn and the exit. That adds three components:
  - process wall;
  - startup = t1 − spawn. This is bundled: exec, runtime init, CUDA context and module load, and with a stale .gpu also the NVRTC compile;
  - tail = exit − last t5, which holds the CPU reference, the final checks and exit.
- The totals therefore cover the whole process. Two components are bundled and named as such: startup and device call.

## Series (medians in ms; full min..max and every component are in gpu-pipeline.txt)
| Path | Size | Load before -> after | Label | Cold pipeline on / off | Warm total on / off | Process wall on / off |
|---|---|---|---|---|---|---|
| solver | 16 | 19.11 -> 19.11 | taken on a loaded host; not representative | 135 / 13 (10.26) | 4 / 0 (undefined) | 277 / 20 |
| labels | 16 | 17.86 -> 17.86 | taken on a loaded host; not representative | 134 / 12 (10.75) | 4 / 0 (undefined) | 280 / 19 |
| transfers | 16 | 18.93 -> 18.93 | taken on a loaded host; not representative | 127 / 12 (10.53) | 2 / 0 (undefined) | 199 / 17 |
| solver | 1024 | 20.72 -> 19.78 | taken on a loaded host; not representative | 184 / 41 (4.52) | 58 / 28 (2.07) | 1571 / 803 |
| labels | 1024 | 19.78 -> 19.78 | taken on a loaded host; not representative | 140 / 12 (11.22) | 16 / 0 (undefined) | 514 / 33 |
| transfers | 1024 | 18.84 -> 18.77 | taken on a loaded host; not representative | 153 / 15 (10.06) | 23 / 2 (11.50) | 766 / 97 |
| solver | 16384 | 15.95 -> 23.32 (48 to 57 mid-series) | taken on a loaded host; not representative | 11178 / 4750 (2.35) | 12710 / 4895 (2.60) | 380739 / 154563 |
| labels | 16384 | 23.43 -> 20.32 | taken on a loaded host; not representative | 313 / 22 (14.54) | 170 / 3 (56.67) | 3911 / 171 |
| transfers | 16384 | 18.98 -> 19.58 | taken on a loaded host; not representative | 531 / 61 (8.69) | 347 / 31 (11.19) | 8465 / 1328 |

- Each series ran 8 runs in the order on, off, off, on, on, off, on, on: three pairs in both orders, then one A-versus-A pair. That gives 5 on runs and 3 off runs per series.
- The A-versus-A pairs differ by up to 23 percent (solver 16384).
- Ratios put the GPU first and use complete pipelines only.
- Slower cases: all nine cells, wherever the ratio is defined. Break-even: not reached at any measured size. There is no speedup sentence and no threshold.
- No repeat series was run. The load was above 16 at every series boundary except the start of solver 16384 (15.95). It dipped to about 10 to 16 only in the middle of that series, and was 23.14 when the series ended.

## Cold versus warm, and compile
- Cold = repetition 1 of a fresh process, plus startup. Warm = repetitions 2 to 20 in the same process, on the resident inputs.
- Under `--gpu on`, startup is 123 to 204 ms median, against 10 to 39 ms off. It dominates the cold pipeline at sizes 16 and 1024.
- The CUDA context opens before main, so cuInit is in startup and not in rep 1's device_call.
- Compile, not pipeline: with the .gpu deleted, startup was 1019, 486 and 11541 ms (solver, labels, transfers), against 157, 123 and 154 ms for the fresh-.gpu run that followed. Each regenerated .gpu was cmp-identical to the original.

## Attestation runs
- Beside each series sit two observe.sh runs with the same binary and arguments (`bench SIZE 20`).
- `--gpu on`: gate PASS in all 9, with bend_dev launches of 300 (solver: 20 solves x 3 sweeps x 5) or 100 (labels, transfers: 20 x 5), and compute_app_seen yes. The plain size-16 runs now last long enough for the poll, unlike Task 3's.
- `--gpu off`: correctness FAIL 0 in both passes, 0 launches, and gate FAIL by design. The sanitizer exits 255 with "no CUDA API call was instrumented", as in Task 6.
- One attestation covers the 5 (on) or 3 (off) timing runs of its series. The timing runs themselves are plain and were not individually observed.
- The solver 16384 observed pass took 370 s, inside its 600 s bound. No run hit a timeout (124).

## Missing field
The split of device_call into managed-memory movement, dispatch and per-round kernel time is recorded as a missing field, never estimated. It would come from Nsight Systems (`nsys`), with per-kernel times from Nsight Compute (`ncu`). Neither is installed, and the runtime has no device timer. The measurement is therefore incomplete for those components, and the evidence file says so.

## Rejected
- The Task 5 forged run (`labels bench-forged 16384 200`, 1164 ms, 0 launches, PASS 3 FAIL 3, exit 1, gate FAIL) is rejected; its time is not accepted.
- The Task 7 rerun of the same control on this binary (`bench-forged 16384 20`, 443.8 ms, exit 1, 3 FAIL) is rejected too. Its digest line passed 20 of 20, which is the Task 5 collision; no digest is equality evidence.
- No series timing run was rejected.

## Not exercised
- A quiet host, Nsight, and per-kernel or per-transfer timing.
- Sizes other than 16, 1024 and 16384; REPS other than 20; other input shapes.
- `--gpu <size>`, default mode, CUDA_VISIBLE_DEVICES set, and non-default `--threads`.
- The combined GpuExample binary and the corpus.
- Device memory checking.
- `bend Tests.bend` and `bend PROOF.bend`: no library, law or proof source changed.

## Concerns
1. Loaded host. Every series is labelled not representative, and none could be repeated at load below 16. The A-versus-A spread (up to 23 percent) is larger than some on/off differences would need to be to mean anything, though not larger than the measured ratios.
2. The device call does not appear to hold the whole bundle. Under `--gpu on`, the verify component (CPU code) runs much longer than off: labels 16384 149 vs 2 ms, transfers 316 vs 26, solver 4707 vs 1592. The tail grows the same way. Managed-memory faults on host access are the likely cause, but this is not established. I left the time where it was measured and compared complete pipelines only. A device-call figure quoted alone would understate the device path's cost on this runtime.
3. The 1 ms timer resolution leaves most CPU components at size 16 and 1024 at 0 to 2 ms. Several warm ratios are therefore undefined, and are printed as undefined.
4. The probe does not prove that every mark sees fully evaluated values. The numbers are consistent with each step's value being computed before the next mark.
5. Pre-commit capture: the records' lane_commit is 880c488 marked uncommitted. The probe hashes in the records equal the committed files.
6. The evidence file is 644 KB, the largest in verification/. It inlines all 72 runs' per-repetition lines and the 36 records.
