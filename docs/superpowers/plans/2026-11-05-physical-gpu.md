# Plan: Physical GPU execution for the three device-requesting paths

Spec: `openspec/changes/validate-physical-gpu-execution/` (proposal, design, `specs/gpu-validation/spec.md` GV-001 to GV-008, tasks 1.1 to 4.3; read all four first, then `openspec/README.md`, `openspec/traceability/parallel-execution.md`, `VERIFICATION.md` "GPU-directed source", `docs/BEND-RUNTIME.md`, and `verification/runtime-profile-hosts.md`). Writ has three native device requests, all reached through `GpuLibrary.bend`: the graph sweep (`Gpu.sweep` calls `run_tree!`, entry `GpuLibrary.solve`), the decentralized-label batch (`DlmGpu.batch` calls `Dlm.batch!`, entry `GpuLibrary.label_batch`), and the transfer-admission batch (`TransferGpu.batch_gpu` calls `Transfer.batch!`, entry `GpuLibrary.transfer_batch`); `verification/gpu-codegen.txt` records `#define BANGS 3` for `GpuExample.bend`. The gap: every recorded run is CPU execution. `gpu-example-native.txt` says "CPU fallback is allowed. No device attestation", the 782 corpus and every runtime-profile row ran `--gpu off`, `verification/gpu-native-build.txt` is empty, and `environment.txt` records no device and no CUDA toolkit on the host that produced it. This host now has an NVIDIA GeForce RTX 4090 and CUDA 13.4. Nothing in this plan turns an existing CPU result into GPU evidence, and nothing changes the library's CPU fallback.

What the pinned runtime does, read from the Bend 2.0.39 driver and its embedded runtime C (2026-11-04 probe; Task 1 re-records it):

- Build. `bend X.bend -o bin` uses the GPU backend when the emitted C has a nonzero `BANGS` and `$CUDA_HOME`, `$CUDA_PATH`, `/usr/local/cuda` or `/opt/cuda` holds `include/nvrtc.h`. It then needs clang 19 or newer, compiles with `-DBEND_CUDA=1 -I<cuda>/include -L<cuda>/lib64 ... -lcuda -lnvrtc` at `-O3`, and runs `bin +RTS --gpu-build`. That writes `bin.gpu`: an 8-byte source hash followed by an NVRTC cubin for `--gpu-architecture=sm_<major><minor>`, with `-DCUBE_LOG=<from L2>`, `--fmad=false` and `-default-device`. The kernel is `bend_dev`. nvcc is not used. If the device probe fails, `--gpu-build` exits 0 and writes nothing. That is a silent case, and Task 1 checks for it.
- Run. `--gpu on`, or a size such as `--gpu 8GB`, requires the device: when `gpu_probe` fails (`cuInit`, `cuDeviceGet(0)`, no concurrent managed access, or context setup), the runtime exits through `err_fail` and names the failing call. With no `--gpu` option the device is used if present and the runtime falls back to CPU **silently**. `--gpu off` always uses the CPU pool. On success the runtime prints nothing about the device. Its only stderr notes are `bend: compiling the GPU program (<path> is missing or stale)` and failures such as `device launch failed` or `device fault`. The heap is one `cuMemAllocManaged` region shared by host and device.
- Attribution hazard. `bend guide shaders` says that "a bang that follows the host's forks in one evaluation runs on the CPU pool". `--gpu on` succeeding therefore proves the device was opened, not that a given bang ran on it. Every claim in this plan needs observed `bend_dev` launches for the specific path.

## Global Constraints

- Lane `lane/physical-gpu`, worktree `../writ-lanes/physical-gpu`, created from current master. Environment: `export PATH="$HOME/.local/share/writ-toolchains/bend-2.0.39/bend/bin:/opt/cuda/bin:$PATH"; export BEND_NO_TELEMETRY=1; export CUDA_HOME=/opt/cuda`. Leave `CUDA_VISIBLE_DEVICES` unset except in the negative controls that set it, and record its value in every run. Build outputs go to `../writ-build/physical-gpu/`, never into the source tree; each `.gpu` file stays beside its binary.
- Host facts at plan time (2026-11-04 probe; Task 1 re-records them): GPU 0 NVIDIA GeForce RTX 4090, UUID `GPU-0188dad3-4d11-4254-3a0d-50e3808bf464`, bus `00000000:0C:00.0`, compute capability 8.9, driver/KMD 615.71.09, CUDA UMD 13.4. The display is on this GPU (gnome-shell and Xwayland are graphics processes, and global utilisation idles near 20 percent). nvcc 13.4.92 is at `/opt/cuda/bin/nvcc`. `/opt/cuda/include/nvrtc.h` and `libnvrtc.so.13` are present, and `ldconfig` resolves both `libnvrtc` and `libcuda`. clang is 23.1.1. `/dev/nvidia0`, `/dev/nvidiactl` and `/dev/nvidia-uvm` are mode 666. `compute-sanitizer` is in `/opt/cuda/bin`. Nsight Systems (`nsys`) and Nsight Compute (`ncu`) are **not** installed. Lean is not on PATH, so `--verdict` cannot run. The host is shared and loaded: load average 55 on 32 CPUs at plan time, and about 100 during earlier lanes.
- Touch only:
  - new `scripts/gpu-validation/`: `Bang.bend`, `Solver.bend`, `Labels.bend`, `Transfers.bend`, `observe.sh`, `check-record.sh`;
  - new `verification/gpu-toolchain.txt`, `gpu-gate-controls.txt`, `gpu-paths.txt`, `gpu-parity.txt`, `gpu-injection.txt`, `gpu-corpus.txt`, `gpu-corpus-on.txt`, `gpu-corpus-off.txt`, `gpu-pipeline.txt`, `gpu-trust-profile.md`, `gpu-validation-hosts.md`, `gpu-final-checks.txt`;
  - new `openspec/traceability/gpu-validation.md`;
  - `openspec/changes/validate-physical-gpu-execution/tasks.md` (boxes only, each citing its evidence);
  - `openspec/traceability/parallel-execution.md` (rows PX-001 and PX-008 and the limits paragraph: add pointers, delete nothing);
  - `VERIFICATION.md` ("GPU-directed source": add a dated section for this host and keep the earlier no-device paragraph as history).

  Do not change any `.bend` file outside `scripts/gpu-validation/`: no `Gpu*.bend`, no `Core`/`Dlm`/`Transfer`/`DataOS`, no examples, no tests, no laws or proofs. Do not change `verification/gpu-codegen.txt`, `gpu-example-*.txt`, `gpu-native-build.txt`, `environment.txt`, `tests-native.txt` or any runtime-profile file; they stay as the CPU-era record. Do not update the source manifest and do not push.
- Plan ruling, probe location: the validation programs are qualification probes under `scripts/gpu-validation/`, as `scripts/runtime-profile/*.bend` are. They are not added to `Tests.bend`. Reasons: (1) the library corpus stays at 782, so the device-versus-CPU corpus comparison in Task 6 is on the exact corpus already recorded; (2) attribution needs one bang path per binary, which the corpus cannot give; (3) AGENTS.md keeps library tests separate from host qualification. The probes may import library modules and `examples/Scenario.bend` and `examples/Expect.bend`. They must not import any `*Tests.bend` or `Test.bend`. They mark every synthetic record "SYNTHETIC" in their output, print one `PASS`/`FAIL` line per check, and exit nonzero when any expected outcome changes.
- Plan ruling, harness language: `observe.sh` and `check-record.sh` are POSIX sh, as `scripts/runtime-profile/check-binary.sh` is. They start processes, sample `nvidia-smi`, and read files. They make no Writ authority, label, or admission decision; every policy decision and every comparison of results is in the Bend probes. If Josh wants the gate in Bend (through `Process.run`), that is a later change, not this lane.
- Original-graph verification stays independent of solver work lists. Probes call `Core.verify` / `DataOS.verify` on the original `Core.Graph` and the original stamp, never on the solver's prepared tree, predecessor lists, or work list. `Dlm.verify_batch` replays the original query tree against the snapshot. Transfer outcomes are re-admitted with `Transfer.admit` against the authoritative `Context`. The device result is only ever the candidate.
- GPU claims and library-correctness claims are separate sentences in every file. "782 PASS with `--gpu on`" is a corpus result. It is GPU evidence only for the paths with observed `bend_dev` launches in that run. Any difference between device and CPU output is recorded as a finding, with both outputs and the diff. A difference is never re-run until it disappears, and never explained away.
- Every GPU evidence file has the shape of `verification/runtime-profile-parity.txt`:
  - a header with title, Bend version, compiler, host (kernel, CPU count, load average), date, environment, and an `Execution:` line saying which runs are device and which are CPU;
  - then `## Build` and `## Run` sections with each `$ command`, its `[exit status: N; stderr ...]`, binary, `.gpu` and stdout sha256, grep counts, and diffs;
  - then a `## Result` section and a `## Limits` section listing what was not exercised.

  Every run also carries the validation-run record from Task 2, kept inline in the evidence file between `--- record v1 ---` and `--- end record ---`.
- Long runs use bounded waits. Wrap every probe, corpus, sanitizer, and benchmark command in `timeout` (600 s unless the task gives another bound) and record the exit status; 124 means timed out and is a finding, not a retry loop. Append one line per step to `docs/superpowers/records/2026-11-05-physical-gpu/activity.log` (tab-separated UTC time, role, text). Add a heartbeat line at least every 10 minutes while a build, sampler, or run is going, because a silent 30 minutes marks the lane idle on the board. Never let a bounded wait exceed 10 minutes without a heartbeat. Samplers (`nvidia-smi pmon`, `nvidia-smi --query-gpu ... -lms`) run under `timeout` too and are killed when the run they observe ends.
- Reports go in `docs/superpowers/records/2026-11-05-physical-gpu/task-N-report.md`. Run `git add -A docs/superpowers/records/2026-11-05-physical-gpu` with each commit, and make one commit per task. Any task that finds a missing tool, a refused device, or a path that cannot be attributed reports BLOCKED or DONE_WITH_CONCERNS with the exact output. It does not work around the problem by changing library source.
- Validation commands for the final task, all run on the lane tree: `bend Tests.bend` (782), `bend PROOF.bend` (`ALL PROOFS CHECK`), `bend PROOF.bend --verdict` (record the exact refusal while Lean is absent), `~/.bun/bin/bunx @fission-ai/openspec@1.16.0 validate --all --strict --no-interactive`, and `git diff --stat master -- '*.bend'`, whose only entries must be `scripts/gpu-validation/*.bend`.

- Cross-lane ruling (controller, 2026-11-05): two Bend lanes are raising the corpus count in parallel; wherever this plan says 782, read "the count `bend Tests.bend` prints on this lane's tree", record that number, and do not touch any count pin. Josh is asked about Nsight Systems and a quiet host for Task 7; until answered, Task 7 records the missing split and the load average as the plan says. The Task 8 threat-model exclusion is recorded as a limit of the profile, not as closing 4.2's intent.

### Task 1: Establish the GPU toolchain and observation method

Requirement IDs: GV-004 "Bind evidence to reproducible inputs and environment" (environment half) and GV-001 "Require observed physical execution" (choosing the observation method). Spec task: groundwork for 1.3.

Write `verification/gpu-toolchain.txt` with each of the following as a command and its output:

- `nvidia-smi`;
- `nvidia-smi --query-gpu=name,uuid,pci.bus_id,driver_version,compute_cap,memory.total --format=csv`;
- `cat /proc/driver/nvidia/version`;
- `nvcc --version`, recorded as present but not used by Bend;
- `ls -l /opt/cuda/include/nvrtc.h /opt/cuda/lib64/libnvrtc.so*`;
- `ldconfig -p | grep -E 'nvrtc|libcuda'`;
- `clang --version`;
- `bend version`;
- `ls -l /dev/nvidia*`;
- `compute-sanitizer --version`;
- `which nsys ncu`, recorded as absent if absent;
- `uptime` and `nproc`.

Quote the runtime facts in this plan's header from the pinned driver: the `cli_build` CUDA search and flags, `gpu_probe`, `gpu_make` options, the `--gpu` parse, and the `why`/`err_fail` line. Use `strings` on the `bend` binary and cite the string you matched, so a later Bend version is detectably different.

Write `scripts/gpu-validation/Bang.bend`: one bang over a balanced fork tree of 4^7 leaves of flat U32 work, so the device has a full lane cube. It takes a repeat count from `IO.args`, puts an `IO` step before the bang (the shaders-guide rule), and prints a checksum that it compares with the same computation without `!`. Build it to `../writ-build/physical-gpu/bang`. Record:

- the emitted C's `#define BANGS` line, from a separate `-o bang.c`;
- that the build ran the CUDA compile, shown by `nm -D bang | grep -E 'cuInit|nvrtc'` or `ldd`;
- the `bang.gpu` sha256;
- `tail -c +9 bang.gpu > bang.cubin; cuobjdump -elf bang.cubin | head` and `cuobjdump -sass bang.cubin | grep -m3 Function`. These must show `sm_89` and `bend_dev`.

Then choose the dispatch observer and show that it works on `bang`. Try them in this order:

1. `compute-sanitizer --dump-kernel-launches yes --kernel-name-exclude regex=.* ./bang +RTS --gpu on -RTS 1`. This dumps every launch while excluding all kernels from checking, to keep overhead low.
2. If the sanitizer refuses managed memory or the runtime's launch pattern, use `gdb -batch` with a counting breakpoint on `cuLaunchKernel`, plus `cuModuleGetFunction` to confirm `bend_dev`.

Record which one works, the launch count, and its overhead (wall time with and without the observer). Also show that `nvidia-smi --query-compute-apps=pid,process_name,used_memory --format=csv` lists the PID during a run of several seconds (`bang` with a large repeat count), and that `nvidia-smi pmon -s u -d 1` gives per-PID SM samples for it.

If anything is missing (no `nvrtc.h` found by the driver, a CUDA build that fails, `--gpu-build` writing no `.gpu`, `--gpu on` refused, no working observer), record the exact command and output, list precisely what is missing, and report BLOCKED. Tasks 2 to 7 are then conditional on Josh's answer, and Tasks 8 and 9 may still run with every GPU row recorded as "not established on this host".

Acceptance: `gpu-toolchain.txt` names every component with its version and path; `bang.gpu` is a cubin for `sm_89` containing `bend_dev`; one observer is shown counting `bend_dev` launches for `bang`, and its overhead is recorded; or the file states exactly what is missing and the report is BLOCKED.

### Task 2: Validation-run record and hardware-evidence gate, with negative controls (1.1, 1.2)

Requirement IDs: GV-004 "Bind evidence to reproducible inputs and environment", and GV-001 "Require observed physical execution" (scenarios "Forced fallback succeeds computationally" and "Device is present but execution is unobserved").

Plan ruling, record format: record version `gpu-validation-record v1`, one `key: value` per line. Required fields:

- `record_version`, `lane_commit` (`git rev-parse HEAD`), `source_sha256` (each probe and each imported library `.bend`, sha256 per file);
- `bend_version`, `base` (the `bend base` sha256), `cc` (path and version), `cuda_home`, `nvrtc_version`;
- `build_flags` (copied from the driver), `emitted_c_sha256`, `binary_sha256`, `gpu_program_sha256`, `gpu_arch`;
- `driver_version`, `device_name`, `device_uuid`, `device_bus`, `cuda_visible_devices`;
- `rts_options`, `threads`, `workload` (probe name, mode, size, repeat);
- `exit_status`, `stdout_sha256`, `stderr`, `observer`, `bend_dev_launches`, `compute_app_seen`, `pmon_max_sm`, `util_samples` (count and interval), `wall_ms`, `load_avg`;
- `correctness` (the probe's PASS/FAIL summary), `gate` (PASS/FAIL/INCOMPLETE).

`check-record.sh FILE` exits 0 only if every field is present and non-empty, and exits 2 printing `INCOMPLETE: missing <field>` otherwise. It never fills in a value.

Plan ruling, gate: a run passes the hardware-evidence gate only if all of these hold:

- it ran with `--gpu on` or a size;
- `exit_status` is 0;
- `correctness` is all PASS;
- the observer counted at least one `bend_dev` launch from that binary and workload;
- `compute_app_seen` is yes;
- the record is complete.

Utilisation samples are always recorded. They are gating only for runs of 10 s or longer, which are also the runs where at least one per-PID SM sample above 0 is required. Shorter runs can fall between 1 s samples, and a global utilisation reading cannot be attributed to the probe while the display shares the GPU. Because the observer slows execution, each gated workload runs twice with identical inputs: once under the observer (for launch count and correctness), once plain (for `compute_app_seen`, the samplers, and wall time). Both runs' records go in the file.

Write `observe.sh PROBE_BIN MODE ARGS...`. It does the following:

1. Takes an idle baseline sample.
2. Starts `nvidia-smi pmon -s u -d 1` and `nvidia-smi --query-gpu=utilization.gpu,memory.used --format=csv -lms 200` under `timeout` into run-local files.
3. Polls `--query-compute-apps` while the probe runs.
4. Runs the probe under `timeout 600`, then runs the observer pass.
5. Writes the record and calls `check-record.sh`.

Run on `bang` and write `verification/gpu-gate-controls.txt`:

- (a) `--gpu on`: gate PASS.
- (b) `--gpu off`: checksum PASS, zero launches, gate FAIL, reason recorded.
- (c) `CUDA_VISIBLE_DEVICES=` with no `--gpu` option: the silent fallback. Checksum PASS, exit 0, zero launches, gate FAIL. This shows that ordinary library fallback still works and that the gate catches it.
- (d) `CUDA_VISIBLE_DEVICES=` with `--gpu on`: the runtime must exit nonzero with its own message naming the CUDA call (expected `cuInit failed` or `cuDeviceGet failed` with a `CUDA_ERROR_*` name). Record it verbatim. Gate FAIL. If it exits 0 instead, that is a finding against "fails if the device is unavailable" and the report is DONE_WITH_CONCERNS.
- (e) Device present but unobserved: `bang` with repeat 0, so no bang is reached, under `--gpu on`. Exit 0 and the context is opened, but there are zero launches. Gate FAIL.
- (f) A record with `driver_version` deleted: `check-record.sh` INCOMPLETE. This is GV-004's "Driver identity is absent".

Acceptance: six controls, each with its command, exit status, launch count, and gate verdict; only (a) passes; (c) shows a successful CPU computation that the gate refuses; (d) shows the runtime's own refusal text.

### Task 3: Compile and execute each path on the device (1.3)

Requirement IDs: GV-002 "Validate all three native calculation paths", and GV-001 "Require observed physical execution".

Write `scripts/gpu-validation/Solver.bend`, `Labels.bend` and `Transfers.bend`. Each calls exactly one `GpuLibrary` entry (`solve`, `label_batch`, `transfer_batch`) behind an `IO` step, with mode `run SIZE`. `SIZE` is the leaf count, rounded to a power of two, built from `examples/Scenario.bend` facts replicated with distinct indices: a chain-and-fan graph for the solver, and alternating allow and deny queries or requests for the batches. Each probe then:

- computes the CPU reference in the same program (`Core.solve_cpu`, `Dlm.batch` without `!`, `Transfer.batch` without `!`) on the same immutable inputs;
- compares the complete result;
- runs the independent check: `Core.verify` on the original graph and stamp, `Dlm.verify_batch` on the original queries, and `Transfer.admit` per original plan against its `Context`.

Build each one, with its own `.gpu`, in `../writ-build/physical-gpu/`. Record `BANGS` (expected 1 per probe) and the cubin check as in Task 1. Run each through `observe.sh` at SIZE 16 and 16384, plus one plain run sized to last at least 10 s for the samplers. Also run `GpuExample.bend` (all three together, `BANGS 3`) once through the observer, to show the launch count when the paths run in one process.

Write `verification/gpu-paths.txt` with one section per path and one for the combined run. If a path shows zero `bend_dev` launches under `--gpu on`, record that the bang ran on the CPU pool, and you may try exactly one probe-side restructuring: moving the `IO` boundary so that no host fork precedes the bang. Record both attempts. If it still shows zero launches, the path stays unvalidated and the report says so; library source is not touched.

Acceptance: each of the three paths has its own build evidence, at least one observer-counted `bend_dev` launch, a passing correctness line against the CPU reference and the independent check, and a gate PASS record. Alternatively, the file states which path could not be attributed and why. The "complete three-path" sentence appears only if all three pass, and it is scoped to this exact configuration (device UUID, driver, Bend, CUDA, `.gpu` hashes).

### Task 4: Differential parity cases (2.1)

Requirement ID: GV-003 "Match reference decisions and verifier outcomes" (scenarios "Wide restriction bits are changed", "Old epoch is presented as current" and "Policy batch fabricates an allowance").

Add mode `parity` to the three probes: a fixed case list, run once on the device path and compared field by field with the CPU reference on the same snapshot. Compare node order and count, type domains, every restriction word, policy outcomes, answer-tree and decision-tree shape, provenance on admitted tickets, and failure classes (`InvalidGraph`, `TypeConflict`, `IterationLimit`, denial reasons).

Cases, at a minimum:

- solver: bit 31, 32 and 63 in distinct restriction dimensions; a cycle; the empty graph (no dispatch expected, and that is recorded as "no device coverage"); a type conflict; an invalid flow; a round budget of 1;
- labels: allow and deny pairs; a stale epoch in the query; a missing principal;
- transfers: paired grants admitted; missing read, missing write, and missing payment grants denied; a stale context epoch.

Each case prints `PASS parity <case>` or `FAIL parity <case>: <field>`.

Run each probe in `parity` mode under the observer and plain, with `--gpu on`, and again with `--gpu off`. Both outputs must be identical, so diff them. Record each case's launch count: a case with zero launches has CPU coverage only, and is listed as such.

The independent four-node oracle (`PropertyTests.bend`, 320 cases) runs inside the corpus in Task 6. Do not copy it. State that it is finite coverage of its documented cases, not of arbitrary graphs or sizes.

Write `verification/gpu-parity.txt`.

Acceptance: every listed case has a PASS or FAIL line from both `--gpu on` and `--gpu off`, the two outputs are diffed, each case's launch count is recorded, and any mismatch is a recorded finding with both values.

### Task 5: Injected faults, and correctness before performance (2.2, 2.3)

Requirement IDs: GV-003 "Match reference decisions and verifier outcomes" (scenario "Stable malformed solver output"), and GV-006 "Correctness precedes performance acceptance".

Add mode `inject` to the probes. Take the device-produced result and mutate it in the probe. The mutations:

- solver candidate: drop a node; erase a source fact; clear bit 63; renumber the stamp to an earlier epoch;
- label answers: flip a denial to an allowance; truncate the answer tree; swap the tree shape;
- transfer decisions: fabricate an `Admitted` for the missing-read request; attach a ticket for a different plan; present it against a stale `Context`.

Each mutation must be denied by the independent path:

- `Core.verify` on the original graph, which must not be given the solver's tree or work list;
- `Dlm.verify_batch` replay;
- `Transfer.admit` against the authoritative `Context`. For one admitted case, also route it through `DataOS.commit_from_capability` with the forged decision and show the commit refuses it and no output or ledger effect occurs (read `DataOS.bend` for what "no effect" returns).

Then add the wrong-but-faster control. A `bench-forged` mode returns a constant allow-all answer without running the bang, so it is faster by construction. Feed it through the same measurement and gate as Task 7. The record must show `correctness` FAIL and `gate` FAIL, with its wall time present but marked "not accepted".

Write `verification/gpu-injection.txt`, including a list of the scenarios that have no hardware coverage (cases whose launch count was 0).

Acceptance: every mutation is denied, with the denying function and result printed; the forged fast run is a recorded failed run; and the no-hardware-coverage list is explicit, even if it is empty.

### Task 6: The 782 corpus with the device on and off

Requirement IDs: GV-003 "Match reference decisions and verifier outcomes" (library-wide), and GV-001 "Require observed physical execution" (attributing what the corpus ran on the device).

Build `bend Tests.bend -o ../writ-build/physical-gpu/tests-gpu`, with CUDA detected. Record the `BANGS` line of the emitted C. The corpus reaches the solver bang through `CoreTests` and `PropertyTests`; label and transfer batches in the corpus are host-side calls without `!`. Also record the binary and `.gpu` hashes. Then run, each under `timeout 600` with heartbeats:

- `tests-gpu +RTS --threads 4 --gpu off > verification/gpu-corpus-off.txt`;
- `tests-gpu +RTS --threads 4 --gpu on > verification/gpu-corpus-on.txt`;
- `--gpu on` once more under the observer, recording the `bend_dev` launch count. Bound it at 600 s; if it times out, record that and give the plain run's result alone.

For each capture, record the PASS count (`grep -cE '^PASS[: ]'`), the final line, and the stdout sha256. Diff on against off, and each of them against the committed 782 reference: sha256 `fc3a08aa33059b67fc9602d20496f6d40ad7950e5dd32bada6fc37c6062916ff`, `verification/tests-native.txt`. If the default device heap is exhausted (`corpus reservation failed`, or a fault), record it verbatim, rerun with `--gpu 16GB`, and keep both results.

Write `verification/gpu-corpus.txt` with two separate result sentences:

1. Library correctness: the count and diffs.
2. GPU claim: "N `bend_dev` launches observed; the solver bang in the corpus executed on the device". If N is 0, write "the corpus ran under `--gpu on` but no device dispatch was observed; this is not a device corpus run".

Any differing line is a finding, with the diff shown.

Acceptance: both captures are committed, counts and hashes are recorded, three diffs are shown, the launch count or timeout is recorded, and the two claims are stated separately.

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

### Task 8: Trust profile (4.1, 4.2)

Requirement ID: GV-008 "Enforce a boundary for untrusted-device claims".

Write `verification/gpu-trust-profile.md`.

Profile `GT-1 trusted device` is the only profile this lane validates. Trusted:

- Bend 2.0.39 compiler and runtime;
- clang 23.1.1;
- NVRTC 13.4 and the `.gpu` cubin it produced;
- the CUDA driver 615.71.09 (user-mode `libcuda` and the kernel module);
- the host kernel and the user account;
- the display stack sharing the device.

Under GT-1, wrong returned values are caught by the checks shown in Tasks 4 and 5. Arbitrary writes are not caught: the runtime allocates the whole term heap, including the original graph, snapshots, contexts, and the values the commit path reads, as one `cuMemAllocManaged` region that device code and the driver can write (cite the `gpu_map` string from Task 1 and the shaders-guide "one heap shared by the CPU and the GPU" sentence). The file says, in those terms, that the shared writable heap is not protection from those writers.

Spec task 4.2 is closed by its exclusion branch. No profile here claims an untrusted GPU program or driver; hostile device code and a hostile driver are outside the validated threat model. A separate host process would not change that while the driver can write its memory (GV-008's second scenario). Name what a future profile would need: an enforced boundary with authoritative state outside any device-mappable or driver-writable memory, for example a Genode or other separate-kernel arrangement with IOMMU-confined DMA, plus corruption and access-denial tests. Implement none of it.

Acceptance: every component is listed as trusted, and nothing is called protected; 4.2's exclusion is stated in the requirement's own words; and no sentence presents algorithmic verification as a memory boundary.

### Task 9: Publish, trace, and final checks (4.3)

Requirement IDs: all of GV-001 to GV-008, for traceability. Spec task 4.3.

Write `verification/gpu-validation-hosts.md` in the shape of `runtime-profile-hosts.md`. It has one row per executed configuration: bang, solver, labels, transfers, combined example, corpus on, corpus off, and the bench series. The columns are:

- configuration;
- output and PASS count;
- `bend_dev` launches and observer;
- `--gpu` mode and `CUDA_VISIBLE_DEVICES`;
- device UUID and driver;
- compiler, NVRTC, and arch;
- binary and `.gpu` sha256;
- harness command;
- gate verdict;
- evidence section.

Add a gap list. It names, at least, no kernel-only or transfer-split timing, no untrusted-device profile, and any path or case without launches.

Write `openspec/traceability/gpu-validation.md`, in the shape of the other traceability files, with GV-001 to GV-008 rows. Each row names the probe mode, the evidence file and section, or an explicit reviewed-only gap.

Add pointers to PX-001 and PX-008 in `parallel-execution.md` and a dated host section in `VERIFICATION.md` "GPU-directed source". Keep the earlier "no `/dev/nvidia0`, no CUDA toolkit" paragraph as the record of that environment, and say that this host differs.

Check `tasks.md` boxes only where their acceptance passed, each citing its file. Leave failed or partial ones unchecked with a one-line reason. Run the validation commands from Global Constraints and put their outputs in `verification/gpu-final-checks.txt`:

- `bend Tests.bend`: 782;
- `bend PROOF.bend`;
- `--verdict`: the refusal, verbatim;
- OpenSpec strict;
- `git diff --stat master -- '*.bend'`: only `scripts/gpu-validation/`. Name each probe file and state that it is a qualification probe, not policy source.

Do not archive the change. Archiving is a controller decision after landing.

Acceptance: every claim in `VERIFICATION.md` and the traceability file links to an evidence section; every unchecked box gives its reason; all five checks are recorded; and the `.bend` diff is limited to the probes.
