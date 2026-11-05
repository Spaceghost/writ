# Task 2 report: validation-run record, hardware-evidence gate, negative controls

Status: DONE_WITH_CONCERNS (the gate refuses every control it should; the concerns are an observer environment finding and the gate's trust model, below)

Files added (touch list only):
- `scripts/gpu-validation/observe.sh` (sha256 efd08afbd28e4b396b04f5956cd947e0c0bfd7ce2751a119b11bb786ad01a8ac)
- `scripts/gpu-validation/check-record.sh` (sha256 7d4df17bf05a75ffdd9dfa464ebceb08710ef719a6d924dac3238261dfcc88ab)
- `verification/gpu-gate-controls.txt` (the evidence: every command, its full output and exit status, all records inline)

No `.bend` file was added or changed (Bang.bend is still 5ff66256...). No manifest change, no push. The binary is Task 1's build, re-hashed rather than rebuilt: bang.c dc7f5730..., bang fccb498a..., bang.gpu 7cf384e0..., the same as verification/gpu-toolchain.txt.

## Record format and checker
`gpu-validation-record v1`: one `key: value` per line between `--- record v1 ---` and `--- end record ---`, with all 33 fields the brief lists in that order (record_version ... correctness, gate). There are no extra fields. The values hold:
- `source_sha256`: `path=sha256` for each GV_SOURCES file, plus observe.sh and check-record.sh, so each record is tied to a version of the harness.
- `binary_sha256`, `emitted_c_sha256` and `gpu_program_sha256`: in `sha256  path` form.
- `build_flags`: the driver's `cli_build` cpu/gpu lists, copied verbatim from `strings` of the pinned bend binary.
- `gpu_arch`: `sm=89`, read by cuobjdump from the cubin after the .gpu file's 8-byte header.
- `cuda_visible_devices`: `unset`, `set, empty`, or `set: <v>`.
- The evidence fields carry `log=PATH log_sha256=HEX` tokens: `observer` (the sanitizer log), `compute_app_seen` (the poll log), `pmon_max_sm` and `util_samples`.

observe.sh writes a pair for each workload. The plain record's `observer` begins `none`, and its `bend_dev_launches` is `not observed (plain pass)`. The observed record's `observer` begins `compute-sanitizer`, and its sampler fields read `not sampled (observed pass)`.

`check-record.sh FILE`:
- exit 2 with `INCOMPLETE: missing <field> (record N)` when a field is absent or empty;
- exit 2 with MALFORMED for a duplicate field, a wrong version, or unbalanced markers;
- otherwise it re-derives the gate. Exit 0 means PASS. Exit 1 means FAIL and the record honestly says FAIL. Exit 3 is `GATE MISMATCH`: a record's `gate` claim disagrees with the evidence.

It never fills in a value. Its `--derive` mode is what observe.sh uses to compute the `gate` line, and `--count-launches LOG NAME` is the shared launch counter. observe.sh leaves a field empty when it cannot establish the value (GV_SOURCES unset, for example), so the record comes out INCOMPLETE. It refuses to run with a non-empty BENDRTS, because those runtime options would not appear on the recorded command line.

## The gate's rule
A workload passes only as a pair of records, one observed and one plain, run with identical inputs. The pair must have identical source, toolchain, build, device, environment, options, workload and stdout. On top of that:
- `rts_options` must contain `--gpu on` or `--gpu <size>`;
- both exit statuses must be 0;
- both `correctness` fields must be `PASS p, FAIL 0` with p >= 1.

The observed pass's sanitizer log must exist with the recorded sha256, and it must meet all of these:
- its `Target application:` line is exactly this binary, options and arguments;
- it finished (`ERROR SUMMARY`), has no `were not printed` truncation, and instrumented at least one CUDA call;
- its driver version matches `driver_version`;
- the observed target saw the caller's CUDA_VISIBLE_DEVICES;
- it shows at least one `bend_dev` launch whose saved host backtrace has a frame in this binary. That recount must equal the record's `bend_dev_launches`. Any count of one or more passes, and the count is recorded.

The plain pass's `--query-compute-apps` poll log must exist with its hash and list the probe's PID (captured by an exec wrapper) at least once. Utilisation is recorded always, but it gates only plain runs of 10 s or more: those need at least one utilisation sample and a per-PID pmon SM sample above 0. pmon is never otherwise an input. The record's own claims are compared against the evidence and are never trusted.

## Controls (full commands and outputs in verification/gpu-gate-controls.txt)
Every control runs `GV_SOURCES=scripts/gpu-validation/Bang.bend GV_RUN_DIR=../writ-build/physical-gpu/runs/task2/<x> timeout 1300 sh scripts/gpu-validation/observe.sh ../writ-build/physical-gpu/bang MODE ARGS`.

| Control | MODE ARGS / environment | Plain exit | Observed exit | Launches (recount) | compute_app_seen | Checker exit | Gate |
|---|---|---|---|---|---|---|---|
| (a) | on 100 | 0 | 0 | 500 | yes 17/19 | 0 | PASS |
| (a-long) | on 600 (plain 23.9 s; util rule applies) | 0 | 0 | 3000 | yes 72/74; pmon max SM 33 (4 of 18 rows numeric) | 0 | PASS |
| (b) | off 100 | 0 | 255 (no CUDA call) | 0 | no | 1 | FAIL (mode; no launches; ...) |
| (c) | default 100, `CUDA_VISIBLE_DEVICES=` | 0, checksum PASS on the CPU | 0 | 500 in observed pass (see finding) | no | 1 | FAIL (mode; environment not reproduced; process not seen) |
| (c2) | default 100, `CUDA_VISIBLE_DEVICES=99` | 0, checksum PASS on the CPU | 255 | 0 | no | 1 | FAIL (mode; no launches; ...) |
| (d) | on 100, `CUDA_VISIBLE_DEVICES=` | 1, `bend: cuInit failed: CUDA_ERROR_NO_DEVICE` | 0 (device visible to the target) | 500 in observed pass | no | 1 | FAIL (plain exit 1; correctness; stdout differs; environment not reproduced) |
| (d2) | on 100, `CUDA_VISIBLE_DEVICES=99` | 1, `bend: cuInit failed: CUDA_ERROR_NO_DEVICE` | 255, same text | 0 | no | 1 | FAIL |
| (e) | on 0 (no bang reached) | 0, PASS | 0, ERROR SUMMARY 0 | 0 | yes 1/3 (context opened) | 1 | FAIL (`launches: 0 bend_dev launches attributed to bang`) |
| (f) | (a)'s record, `sed '/^driver_version:/d'` | - | - | - | - | 2, `INCOMPLETE: missing driver_version (record 1)` and `(record 2)` | INCOMPLETE |
| (g) | (a)'s records unchanged (gate PASS, 500 launches) in a directory without the sanitizer log | - | - | - | - | 3, `gate: FAIL (observer: log .../g/observed.sanitizer.log does not exist)` + GATE MISMATCH | FAIL |
| (g2) | (e)'s records with `bend_dev_launches: 5`, `gate: PASS` | - | - | - | - | 3, `observer: record claims bend_dev_launches '5', log shows 0` + MISMATCH | FAIL |
| (h) | (a)'s log with a `400 errors were not printed` line, its new hash written into the record | - | - | - | - | 3, `observer: sanitizer output truncated (were not printed)` + MISMATCH | FAIL |

Only (a) and (a-long) pass. (c) is a successful CPU computation (exit 0, checksum PASS) that the gate refuses. (d) and (d2) show the runtime's own refusal text, so there is no finding against "fails if the device is unavailable". The brief's six controls are (a) through (f). The controller's forged-record control is (g). (a-long), (c2), (d2), (g2) and (h) are additions.

## Hashes
- observe.sh efd08afb...a8ac, check-record.sh 7d4df17b...88ab; these are the values in every record's source_sha256.
- Bang.bend 5ff66256...9570; bang fccb498a...0700; bang.gpu 7cf384e0...b79d; bang.c dc7f5730...3d6c; `bend base` 3cd0b094...99ce.
- Sanitizer logs: (a) f88e9f2a...0ea4; (a-long) e4944794...1062; (c) e4310e92...aa63; (d) 638ea9c6...ea7c; (e) 99a48f8c...756d; (b), (c2) and (d2) are identical, 84b7f31a...5269 (one `Target application terminated before first instrumented API call` line).
- verification/gpu-gate-controls.txt: 7e00677067f2c4836cb7694f8a225f85d6181b6bed0e3be795d1a7bfa03394bc.

## Not exercised
- Any Writ GPU path. `--gpu <size>` (accepted by pattern only). A run of 10 s or more failing the utilisation rule on real hardware. (c2)'s plain pass ran 13 s and its gate reasons include the sampler rule, but that run was on the CPU.
- A separate probe with no GPU call. (e) is repeat 0 of the GPU-built bang, as the brief specifies.
- gdb, Nsight (absent), device memory checking. `bend Tests.bend` and `bend PROOF.bend`: no .bend or policy code changed.
- Shells: the scripts were run with /bin/sh (bash) and re-checked under `bash --posix` (all eight records) and `busybox sh` ((a) and (e)). dash is not installed. shellcheck reports only intentional word splitting (SC2086/SC2016) and one SC2209 style note.

## Concerns
1. Observer environment finding: compute-sanitizer 2026.3.0.0 removes an *empty* CUDA_VISIBLE_DEVICES from its target, while a non-empty value such as `99` passes through. In (c) and (d), the brief's exact `CUDA_VISIBLE_DEVICES=` form, the observed pass therefore ran on the device (500 launches) while the plain pass ran hidden. Both pairs are still refused. observe.sh now probes what the sanitizer's target sees, and the gate fails any pair where that differs from the caller's environment. Later tasks that hide the device should use an invalid id.
2. The observed pass's `exit_status` is compute-sanitizer's, which is 255 whenever no CUDA call is instrumented, even when the probe exited 0 with PASS ((b), (c2)). The plain pass holds the probe's own status. Recording both statuses in one field was not attempted.
3. Trust model: the evidence is unsigned run-local files. The gate catches claims that disagree with their evidence, missing or truncated logs, a different target command line, and an unreproduced environment. It does not resist a forger who rewrites a log and its record consistently. binary_sha256 is not re-hashed at check time, so a later rebuild does not invalidate old records.
4. The device identity fields come from `nvidia-smi -i 0`, which ignores CUDA_VISIBLE_DEVICES. That is exact on this one-GPU host only. `cc` is the compiler the driver would select here, not a fact read from the binary.
5. lane_commit in the records is 23b82c8 with the two scripts uncommitted (the record says so). Their hashes equal the committed files. The host load average was 43.70 to 91.65, and the display shares the GPU, so the wall times are indicative only.
