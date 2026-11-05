# GPU validation: per-configuration device evidence

Record for task 4.3 of the proposed change
[validate-physical-gpu-execution](../openspec/changes/validate-physical-gpu-execution/)
(GV-001 to GV-008), in the shape of
[runtime-profile-hosts.md](runtime-profile-hosts.md). It collects, per executed
configuration, the output, the observed `bend_dev` launches, the GPU mode, the
device, the toolchain, the binary and `.gpu` hashes, the harness and the gate
verdict that the physical-gpu lane's evidence files already hold. Nothing here
was rerun for this record: every value is copied from the file and section
named in its row. This record qualifies no host for production use, and it
makes no performance claim.

Example. `observe.sh ../writ-build/physical-gpu/labels on run 16384` ran the
label batch (`GPU.label_batch` -> `Dlm.batch!`) on the RTX 4090 with 5 observed
`bend_dev` launches attributed to the binary, compared every answer with the
CPU reference and `Dlm.verify_batch` on the original queries, and passed the
gate (verification/gpu-paths.txt, "Labels, s16384"). That is GPU evidence for
that one binary, those arguments and this configuration. The current gap: no
run splits device time into memory movement, dispatch and kernel time (Nsight
is not installed), every timing was taken on a loaded host, and no profile
treats device code or the driver as untrusted.

Two claims are kept apart in every row. Library correctness is what a run's
PASS lines and comparisons show. The GPU claim is limited to the runs with
observed `bend_dev` launches; everything else in a run (the CPU references,
the verifiers and replays, every `--gpu off` run) is CPU execution.

## The host

| Host | GPU execution | Device and driver | Toolchain | Load | Evidence |
| --- | --- | --- | --- | --- | --- |
| Linux 7.2.9-1-MANJARO x86_64, 32 online CPUs, shared (the display and other graphics and compute clients use the same GPU) | **GPU executed, with observed launches**, for the configurations below whose gate verdict is PASS: compute-sanitizer 2026.3.0.0 counted `bend_dev` launches attributed to the binary. **CPU fallback for the rest**: every `--gpu off` run, every CPU reference and verifier or replay inside every probe (no bang), the corpus's label and transfer batches (host-side calls without `!`), and the refused gate controls | NVIDIA GeForce RTX 4090, `GPU-0188dad3-4d11-4254-3a0d-50e3808bf464`, bus `00000000:0C:00.0`, compute capability 8.9; driver and KMD 615.71.09; CUDA UMD 13.4 | Bend 2.0.39 (driver sha256 `2ec160fa...2045cd`); clang 23.1.1 (emitted C with `-DBEND_CUDA=1` at -O3); NVRTC 13.4.92; cubins `sm=89` | **Loaded host**: 1-minute load average from 10.79 to 99.82 across the lane's captures (99.82 at the Task 1 fix-round rebuild), never quiet; every wall time is indicative only, and every timing series is labelled "taken on a loaded host; not representative" | verification/gpu-toolchain.txt, "Toolchain", "Result"; each file's header lines `Host:` and `GPU:` |

Identity limit: device name, UUID, bus and driver come from `nvidia-smi -i 0`,
which ignores `CUDA_VISIBLE_DEVICES`. They are exact on this one-GPU host only
(verification/gpu-gate-controls.txt, "Limits").

## Executed configurations

Common to every row unless the row says otherwise: device
`GPU-0188dad3-4d11-4254-3a0d-50e3808bf464`, driver 615.71.09; clang 23.1.1,
NVRTC 13.4.92, `sm=89`; `CUDA_VISIBLE_DEVICES` unset and `BENDRTS` unset.
The harness is `scripts/gpu-validation/observe.sh` (sha256 `efd08afb...a8ac`)
with `check-record.sh` (sha256 `7d4df17b...88ab`); its exit status is the
gate's (0 PASS, 1 FAIL). Each observe.sh run has a plain pass (not observed)
and an observed pass under compute-sanitizer; the launch count is the observed
pass's, recounted by check-record.sh from the sanitizer log. Abbreviations:
`toolchain`, `controls`, `paths`, `parity`, `injection`, `corpus`, `pipeline`
are `verification/gpu-<name>.txt`.

| Configuration | Output and PASS count | `bend_dev` launches and observer | `--gpu` mode and `CUDA_VISIBLE_DEVICES` | Device UUID and driver | Compiler, NVRTC, arch | Binary and `.gpu` sha256 | Harness command | Gate verdict | Evidence section |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Bang probe (`scripts/gpu-validation/Bang.bend`, one bang) | PASS 1, FAIL 0 (bang checksum equal to the no-bang checksum), both passes | 500 (`on 100`) and 3000 (`on 600`); compute-sanitizer | `+RTS --gpu on -RTS`; unset | as common | as common; BANGS 1 | `fccb498a92dad8519056134d629be004ccb3b98471f8fbf48101bd88577d0700`; `.gpu` `7cf384e07fde15285cdc0ce82e7d4033258495511dd94d91c354ea037bb8b79d` | `GV_SOURCES=scripts/gpu-validation/Bang.bend GV_RUN_DIR=../writ-build/physical-gpu/runs/task2/a timeout 1300 sh scripts/gpu-validation/observe.sh ../writ-build/physical-gpu/bang on 100` (and `on 600`) | PASS, PASS | controls "control (a)", "control (a-long)", "Result"; toolchain "Observer 1: compute-sanitizer" |
| Bang probe, ten refused controls | PASS 1 where the probe computed; (d) and (d2) stop at `bend: cuInit failed: CUDA_ERROR_NO_DEVICE` | 0 or 500 per control (see the file); (e) 0 | `off`, default (no `+RTS`), `on` with `CUDA_VISIBLE_DEVICES` empty or `99`, `on 0`; plus record tampering (f), (g), (g2), (h) | as common | as common | as above | as above, per control | FAIL or INCOMPLETE in every one (exit 1, 2 or 3) | controls "Result" table, "Limits" |
| Solver (`GPU.solve` -> `Gpu.sweep`'s `run_tree!`; `scripts/gpu-validation/Solver.bend`) | PASS 7, FAIL 0, both passes; `--gpu off` stdout identical | 15 at `run 16`, 15 at `run 16384`; compute-sanitizer | `+RTS --gpu on -RTS`; unset | as common | as common; BANGS 1 | `156185e34b1d08a8defeb01ab6c214eb3a19de7dc779b2a3befefa15c1e35bad`; `.gpu` `164461c13f46d93058f535178d56d0d7d4f3b553930a2b06484a5c8925950b67` | `GV_SOURCES="..." GV_RUN_DIR=../writ-build/physical-gpu/runs/task3/solver-s16384 timeout 1300 sh scripts/gpu-validation/observe.sh ../writ-build/physical-gpu/solver on run 16384` | PASS at `run 16384`; FAIL at `run 16` (presence: the 0.25 s process ended before the 200 ms poll listed it; recorded, not re-run) | paths "Solver, s16", "Solver, s16384", "Result" |
| Labels (`GPU.label_batch` -> `Dlm.batch!`; `scripts/gpu-validation/Labels.bend`) | PASS 6, FAIL 0, every run; `--gpu off` stdout identical | 5 (`run 16`), 5 (`run 16384`), 6000 (`run 16384 1200`); compute-sanitizer | `+RTS --gpu on -RTS`; unset | as common | as common; BANGS 1 | `527d2d99c4feb04101ec9db566229dfc0c20f09546b1f7c3945c57cc64d628f8`; `.gpu` `c09ae05a151736e50f2459389549795035d9dece5564a749a1933536a93f5339` | `observe.sh ../writ-build/physical-gpu/labels on run 16384` (and `run 16`, `run 16384 1200`), same form as the solver row | PASS at 16384 and long; FAIL at 16 (presence) | paths "Labels, s16", "Labels, s16384", "Labels, long", "Result" |
| Transfers (`GPU.transfer_batch` -> `Transfer.batch!`; `scripts/gpu-validation/Transfers.bend`) | PASS 6, FAIL 0, every run; `--gpu off` stdout identical | 5 (`run 16`), 5 (`run 16384`), 1000 (`run 16384 200`); compute-sanitizer | `+RTS --gpu on -RTS`; unset | as common | as common; BANGS 1 | `f3e811921e36ce42db3434904f48be15638fc83f383348d583eede9932e6c7c3`; `.gpu` `fddac93aad6d72fb5d9d6193f542e3dd95a131c7d97c239c76e982010cdaf09c` | `observe.sh ../writ-build/physical-gpu/transfers on run 16384` (and `run 16`, `run 16384 200`) | PASS at 16384 and long; FAIL at 16 (presence) | paths "Transfers, s16", "Transfers, s16384", "Transfers, long", "Result" |
| Combined example (`GpuExample.bend` -> `examples/Parallel.bend`, BANGS 3) | PASS 5, FAIL 0; `--gpu off` stdout identical | 20 in one process; compute-sanitizer. The split into 2 solver sweeps' launches plus one label and one transfer bang is inferred from the launch grids, not observed | `+RTS --gpu on -RTS`; unset | as common | as common; BANGS 3 | `27c8617594f92e3ecefc3920ca8d6ccbb52e77984bc3eb3ea1f9d2a5bbc6177e`; `.gpu` `be0ee70c020629f80de7f9e170594ffc9026bd4a6a1cb60e434013f0c2cfd005` | `GV_SOURCES="GpuExample.bend examples/Parallel.bend ..." ... observe.sh ../writ-build/physical-gpu/gpu-example on` | PASS | paths "GpuExample, combined", "Result" |
| Parity cases (Task 4 builds of the three probes, `parity CASE`) | 20 cases, every one `PASS parity CASE` on and off; `parity all`: solver PASS 35, labels PASS 13, transfers PASS 19, FAIL 0; `--gpu off` stdout byte-identical in all 24 runs | `parity all`: 90 (solver), 20 (labels), 30 (transfers); 18 of 20 cases device-validated; solver `empty` and `invalid-flow` dispatch nothing (0 launches); transfers `paired-admitted` validated through its ROUNDS 400 run (2000 launches); compute-sanitizer | `+RTS --gpu on -RTS`; unset | as common | as common; BANGS 1 each | solver `b05d62cb84bad78d19082c291a020462627048afc6b46571d41e0bc5faf805f6` / `.gpu` `db3438f7ad2d6c9a283fb25c30b67adcbc83e50949db91c30b255dcbeeba7bfb`; labels `63d5987e318252384ca518f7c525a05e8f18a3ee9682233c1ffc518cb92248e1` / `a3b6885c1fbf98661f0e0712b4fe990ec9b845c87c6732e85c16ca92673af2a1`; transfers `136b6e25345848f759abb9ad385ef015737f9133c866a7e71648c6ee6dc76d64` / `aaad38b58edc2fbf38b6fe901b44d9f592db255bd5c9330388f6597628441f0e` | `GV_EMITTED_C=../writ-build/physical-gpu/task4/solver.c GV_RUN_DIR=../writ-build/physical-gpu/runs/task4/solver-all timeout 1300 sh scripts/gpu-validation/observe.sh ../writ-build/physical-gpu/task4/solver on parity all` (same form per case) | 21 PASS pairs; 3 FAIL (solver `empty` and `invalid-flow`: 0 launches; transfers `paired-admitted` ROUNDS 1: presence) | parity "Result", "Comparison", "Limits" |
| Injected faults (Task 5 builds, `inject CASE N`; forged run `bench-forged`) | 11 injected cases, each denied in every round (500 of 500 solver, 1000 of 1000 labels and transfers) with its unmutated control passing; two honest runs (`labels run 16384 200`) PASS 6; one digest run (`transfers run 16384`, the all-field transfer digest on device output) PASS; forged run PASS 3, FAIL 3, exit 1 | 5000 per injected case; 1000 per honest run; 5 for the digest run; forged run 0 (no device call, by construction); compute-sanitizer | `+RTS --gpu on -RTS`; unset | as common | as common; BANGS 1 each | solver `15b55cde37de1ac64ea5bfc9c613e11c40557036a70332de6dc16128bd0fccba` / `.gpu` `d9fe90a9aab566ad8e13b62baa34dc8b5d3c1bb20912b5736d17b0c26c3a8928`; labels `42bbc57de024ecd349c29b04551be58d790c5656e44990caa7b0d026a405e8ab` / `b489ef9f527e76b89fcbd878210469cb2c717426261e85a399f7710ee850cecb`; transfers `d3f5e0fe0d3696ae497a417a37df8566182fe373246f3239ac401bb7984266f0` / `b1a4d2a7662e05ff31293c6f1699f2cb10393d959f9258c52b925afabc8ffa37` | `GV_EMITTED_C=../writ-build/physical-gpu/task5/solver.c GV_RUN_DIR=../writ-build/physical-gpu/runs/task5/solver-inject-drop-node timeout 1300 sh scripts/gpu-validation/observe.sh ../writ-build/physical-gpu/task5/solver on inject drop-node 500` (same form per case) | PASS for all 11 injected cases, both honest runs and the digest run (15 records, 14 PASS); FAIL for the forged run (its 1164 ms is not accepted) | injection "Result", "Limits" |
| Corpus on (`Tests.bend`, 782 tree, lane commit 98db68bf; history) | 782 PASS, 0 FAIL, `ALL LIBRARY TESTS PASSED`; capture `gpu-corpus-on.txt` sha256 `fc3a08aa...062916ff`, byte-identical to `gpu-corpus-off.txt` and to `verification/tests-native.txt` as of 98db68bf (sha256 `fc3a08aa...062916ff`); kept as history | 4915, all attributed to the one bang (`Gpu.sweep`'s `run_tree!`); compute-sanitizer. GPU evidence for the solver bang only: the corpus's label and transfer batches are host-side calls without `!` | capture `+RTS --threads 4 --gpu on` (device run, not individually observed; a supplementary sanitizer run of these options shows 4915 launches); gate pair `+RTS --gpu on -RTS` at the default 32 threads; unset | as common | as common; BANGS 1 | `53eeea2b44f58b504acc3a86ca25ca9bd90560408afba158463049d874bafdf1`; `.gpu` `40b1305c51e5a17506bb3de47f387b75f34cfbc2a81bcf1908cfe4dadb5147f9` | `GV_RUN_DIR=../writ-build/physical-gpu/runs/task6/tests-gpu-on timeout 1300 sh scripts/gpu-validation/observe.sh ../writ-build/physical-gpu/task6/tests-gpu on`; capture `timeout 600 ../writ-build/physical-gpu/task6/tests-gpu +RTS --threads 4 --gpu on > verification/gpu-corpus-on.txt` | PASS | corpus "Run", "Result", "Limits" |
| Corpus off (same binary, 782 tree) | 782 PASS, 0 FAIL, `ALL LIBRARY TESTS PASSED`; `gpu-corpus-off.txt` sha256 `fc3a08aa...062916ff` | 0: CPU execution (a supplementary run under the sanitizer: exit 255, "Target application terminated before first instrumented API call") | `+RTS --threads 4 --gpu off`; unset | not used (no CUDA call) | as above | as above | `timeout 600 ../writ-build/physical-gpu/task6/tests-gpu +RTS --threads 4 --gpu off > verification/gpu-corpus-off.txt` | not a gate run (CPU by design) | corpus "Run", "Result", "Limits" |
| Corpus on, merged tree (`Tests.bend`, 1428 tree, HEAD f23ce66; Task 9 final round) | 1428 PASS, 0 FAIL, `ALL LIBRARY TESTS PASSED`; capture `../writ-build/physical-gpu/runs/task9/tests-gpu-on.stdout` sha256 `6faee2192533a33a714641f1efe895a1352f619df554207805265bd60e9f9318`, `cmp`-identical to the `--gpu off` capture and to `verification/tests-native.txt` as it stands on the merged tree (sha256 `6faee219...9318`) | 4915, all attributed to the one bang (`Gpu.sweep`'s `run_tree!`); compute-sanitizer. GPU evidence for the solver bang only | capture `+RTS --threads 4 --gpu on` (not individually observed; a supplementary sanitizer run of these options shows 4915 launches); gate pair `+RTS --gpu on -RTS` at 32 threads; unset | as common | as common; BANGS 1 | `33cfab7bf4e59e6d7049836678d62a5fb6d4dda82d576b254edfb5638dd6482b`; `.gpu` `fad1046ded2c7c118f606085554a1331323180ed92969fc7eb9f41c61f178fb1` | `GV_SOURCES="<34 corpus sources>" GV_RUN_DIR=../writ-build/physical-gpu/runs/task9/tests-gpu-on timeout 1300 sh scripts/gpu-validation/observe.sh ../writ-build/physical-gpu/task9/tests-gpu on`; capture `timeout 600 ../writ-build/physical-gpu/task9/tests-gpu +RTS --threads 4 --gpu on > ../writ-build/physical-gpu/runs/task9/tests-gpu-on.stdout` | PASS | corpus "Merged tree, 2026-11-05": "Run (merged tree)", "Result (merged tree)", "Limits (merged tree)" |
| Corpus off, merged tree (same binary) | 1428 PASS, 0 FAIL, `ALL LIBRARY TESTS PASSED`; sha256 `6faee219...9318` | 0: CPU execution (supplementary sanitizer run: exit 255, "Target application terminated before first instrumented API call") | `+RTS --threads 4 --gpu off`; unset | not used (no CUDA call) | as above | as above | `timeout 600 ../writ-build/physical-gpu/task9/tests-gpu +RTS --threads 4 --gpu off > ../writ-build/physical-gpu/runs/task9/tests-gpu-off.stdout` | not a gate run (CPU by design) | corpus "Merged tree, 2026-11-05" |
| Bench series (Task 7 builds, `bench SIZE 20`, sizes 16, 1024, 16384, three paths: nine series) | 72 timing runs, all accepted (exit 0, `result: all checks PASS`, 20 repetition lines); every series labelled "taken on a loaded host; not representative"; the `--gpu on` pipeline was slower than `--gpu off` in every cell | the timing runs are plain and not individually observed; each series' `--gpu on` attestation (same binary and arguments): 300 (solver) and 100 (labels, transfers); `--gpu off` attestations 0; compute-sanitizer | timing runs `+RTS --gpu on -RTS` and `+RTS --gpu off -RTS`, order on off off on on off on on; unset | as common | as common; BANGS 1 each | solver `43e2402ce310c5cb5a042b71b596984dfefaf8a60de731d576e34adbfb8da8f8` / `.gpu` `fd3dc8162e947bafa74a42358f97b8573c60cc53f858783d02d111560518151d`; labels `156c2b9470b83be9ab9cab80c7d08ac170685492410b103e635bd7288088aa26` / `77a7e6fdd7e2d878dd73278b60b397ffade950550e7c15c9b016b799c4428d04`; transfers `d9febd99bbabe026875db53895f0c65f23ad4f9326b533351c86589e22e29129` / `17ff77d36f5606bae975f58bb93ee124f053637e7fd1e9b8f9bbe4cc5347039d` | timing `/usr/bin/python3 -I ../writ-build/physical-gpu/task7/trun.py <run dir> ../writ-build/physical-gpu/task7/solver on bench 16 20` (argv `timeout 600 ... +RTS --gpu on -RTS bench 16 20`); attestation `GV_EMITTED_C=... GV_RUN_DIR=../writ-build/physical-gpu/runs/task7/solver-16-attest-on timeout 1300 sh scripts/gpu-validation/observe.sh ../writ-build/physical-gpu/task7/solver on bench 16 20` | attestations: 9 `--gpu on` PASS; 9 `--gpu off` FAIL by design (no device requested); forged reruns rejected | pipeline "Series ...", "Attestation ...", "Result", "Limits" |

Source binding. Each row's records carry the `source_sha256` of every source
the probe imports. On the merged tree (master merged into `lane/physical-gpu`,
Task 9), the library modules named in the path, parity, injection and bench
records (`Core.bend`, `Gpu.bend`, `GpuLibrary.bend`, `Dlm.bend`,
`DlmGpu.bend`, `Transfer.bend`, `TransferGpu.bend`, `examples/Scenario.bend`
and the rest) still hash to the recorded values. The probe sources changed
from task to task within the lane (each task's records bind the probe version
it ran, and the probes' committed history holds every version). `Tests.bend`
and `FacadeTests.bend` changed on master after the Task 6 corpus runs, so the
782-tree corpus rows are evidence for the 782 tree only (GV-004 "Source changes
after the measured run"). The merged-tree corpus rows were rerun on the merged
tree (HEAD f23ce66, `.bend` sources clean) and bind its 34 corpus sources in
their record.

## Gaps this record does not close

- No kernel-only timing and no transfer split: the device call is one bundled
  component (allocation, managed-memory movement, dispatch, every round, result
  return); its split is a missing field because Nsight Systems and Nsight
  Compute are not installed (pipeline "Stage split (missing field)", "Limits").
- No untrusted-device profile: the only profile is GT-1 trusted device; hostile
  device code and a hostile driver are excluded from the validated threat model
  as a recorded limit, and no enforced memory or device boundary exists
  (verification/gpu-trust-profile.md, "Profile", "Threat-model exclusion").
- Paths and cases without launches: solver parity `empty` and `invalid-flow`
  (0 launches by construction; CPU-path parity only); the forged control
  (0 launches by construction); the corpus's label and transfer batches (no
  bang reaches them in the corpus binary). The three SIZE 16 path runs and the
  ROUNDS 1 `paired-admitted` run have observed launches but failed the gate on
  presence.
- No quiet-host measurement: the 1-minute load was above 16 on 32 CPUs at every
  series boundary but one (15.95, the start of the solver 16384 series), and about
  10 to 16 for a few minutes inside the solver 16384 series; no series was
  repeated (pipeline "Limits").
- No Lean verdict: `bend PROOF.bend --verdict` refuses because Lean is not on
  PATH (verification/gpu-final-checks.txt).
- No device memory checking: the sanitizer excludes every kernel by design, so
  no device memory access was checked.
- Not exercised on the device: `--gpu <size>` heap options, default mode for
  the path probes, multi-GPU hosts, the JavaScript backend.
- The gate checks consistency of files, not signatures; it does not resist a
  forger who rewrites a log and its record consistently (controls "Limits").
- The 32-bit probe digests are not equality evidence (injection "Result", the
  digest-collision finding); the Task 3 cross-process comparisons at 16384 and
  in the long runs show equal counts only (paths "Limits", reconciled in Task 9).
