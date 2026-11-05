### Task 7: Whole-pipeline measurement (3.1, 3.2)

Requirement IDs: GV-005 "Measure the complete required pipeline", GV-006 "Correctness precedes performance acceptance", and GV-007 "Limit performance claims to measured evidence".

Add mode `bench SIZE REPS` to the three probes. For each repetition, the probe takes `IO.now` (check its unit with `bend base IO.now` and the Base source, and record it) at these points:

1. before input construction (host preparation);
2. before the bang;
3. after the bang returns, which covers allocation, managed-memory movement, dispatch, every sweep or batch round, and result return;
4. after the independent verification or replay;
5. at the end.

It prints the components and the total. The total is process wall time from `observe.sh` for the cold run. Plan ruling, stage split: memory movement, dispatch, and per-round kernel time cannot be separated inside the bang on this host. Managed memory moves by page fault, the runtime exposes no timer, and `nsys`/`ncu` are absent. Report them as one "device call" component, and record their separation as a missing field, never an estimate. That makes the report incomplete for those components, and it says so.

Define the conditions:

- Cold: a fresh process with the first repetition, which includes `cuInit`, module load, and first-touch faults. Also record a run with a stale `.gpu` (deleted first) that shows NVRTC compile time separately, and label it "compile, not pipeline".
- Warm: repetitions 2 to REPS in the same process, on the same resident inputs.

Sizes are 16, 1024 and 16384 leaves per path, with REPS 20, all from the plain run (never the observed one). CPU matching uses the same binary, inputs, and checks with `--gpu off`. Use interleaved on/off pairs in both orders, three pairs per size, plus one on/on A-versus-A pair (the method in `bend guide shaders` "Measuring"). Record `uptime` before and after each series. Plan ruling, loaded host: a series whose load average exceeds 16 (half the CPUs) is marked "loaded host, not representative" and may be repeated once when the load drops; both are kept.

Only runs whose `correctness` is all PASS and whose gate passed (on) or whose correctness passed (off) are accepted for comparison; the rest are listed as rejected with their reason.

Write `verification/gpu-pipeline.txt` with:

- raw per-repetition lines;
- medians and spread per component, condition, size, and mode;
- the ratio of complete pipelines only, with the GPU result first;
- slower cases and break-even stated as measured;
- no threshold and no claim beyond the measured sizes on this configuration.

Kernel-only numbers do not exist here; if any component is quoted alone, it is labeled a component.

Acceptance: every accepted measurement has its record, its correctness line, and its load average; the totals cover every stage, and the bundled ones are named; any speedup sentence quotes the exact size, condition, and configuration it comes from; and the forged run from Task 5 appears as rejected.

