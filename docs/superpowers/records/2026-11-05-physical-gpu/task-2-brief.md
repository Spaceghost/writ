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

