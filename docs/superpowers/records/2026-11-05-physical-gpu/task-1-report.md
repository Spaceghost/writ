# Task 1 report: GPU toolchain and launch-observation method

Status: DONE_WITH_CONCERNS (the concerns are about the method, not missing tools; see the end)

Files added (touch list only):
- `scripts/gpu-validation/Bang.bend` (sha256 5ff66256015086c56d8424edebb234b1d1dee91a1d846ae7c06e24e396179570)
- `verification/gpu-toolchain.txt` (the evidence; every command below is there with its full output)

No `.bend` file outside `scripts/gpu-validation/` was touched. No manifest, no push.

## Environment
`export PATH="$HOME/.local/share/writ-toolchains/bend-2.0.39/bend/bin:/opt/cuda/bin:$PATH"; export BEND_NO_TELEMETRY=1; export CUDA_HOME=/opt/cuda`.
CUDA_VISIBLE_DEVICES unset in every run. CUDA_PATH=/opt/cuda is inherited from the login environment (same directory as CUDA_HOME, which the driver searches first). Load average 48 to 115 throughout.

## Toolchain (versions and paths)
| Component | Version | Path |
|---|---|---|
| GPU | NVIDIA GeForce RTX 4090, cc 8.9, 24564 MiB, UUID GPU-0188dad3-4d11-4254-3a0d-50e3808bf464, bus 00000000:0C:00.0 | GPU 0 |
| Kernel module / KMD | 615.71.09 (built with gcc 16.2.1) | /proc/driver/nvidia/version |
| CUDA UMD | 13.4 | /usr/lib/libcuda.so.1 (ldconfig) |
| NVRTC | 13.4.92 | /opt/cuda/include/nvrtc.h, /opt/cuda/lib64/libnvrtc.so.13.4.92 |
| nvcc (present, not used by Bend) | 13.4.92 | /opt/cuda/bin/nvcc |
| clang | 23.1.1 | /usr/bin/clang |
| bend | 2.0.39, sha256 2ec160fa...45cd | ~/.local/share/writ-toolchains/bend-2.0.39/bend/bin/bend |
| compute-sanitizer | 2026.3.0.0 (build 38855100) | /opt/cuda/bin/compute-sanitizer |
| cuobjdump | 13.4.92 | /opt/cuda/bin/cuobjdump |
| gdb | 18.1 | /usr/bin/gdb |
| nsys, ncu | absent (`which` exit 2; no /opt/cuda/nsight* or /opt/nvidia/nsight*) | |
| device nodes | /dev/nvidia0, nvidiactl, nvidia-modeset, nvidia-uvm, nvidia-uvm-tools, all crw-rw-rw- | /dev |
| host | Linux 7.2.9-1-MANJARO x86_64, glibc 2.44, nproc 32 | |

## Runtime facts from the driver
33 fixed-string greps over `strings -n 6` of the bend binary, all matched (exit 0), each cited with its line number in the evidence file: the `cli_build` CUDA search (`CUDA_HOME`, `CUDA_PATH`, `/usr/local/cuda`, `/opt/cuda`, first holding `include/nvrtc.h`), the `BANGS` test, `-DBEND_CUDA=1`, `-I/-L<cuda>`, `-O3`, `-lcuda -lnvrtc`, the `--gpu-build` second step, the clang >= 19 requirement for GPU builds; `gpu_probe` (cuInit, cuDeviceGet(0), concurrent managed access, primary context, cuCtxSetCurrent, `"%s failed: %s"`); `gpu_make` (`--gpu-architecture=sm_%d%d`, `-DCUBE_LOG=%u`, `--fmad=false`, `-default-device`, 8-byte hash then cubin); `cuModuleGetFunction(... "bend_dev")`; `cuMemAllocManaged`; the `--gpu-build` silent case (`if (gpu_probe() == NULL && !gpu_make(...))`); the `--gpu` parse; the `why`/`err_fail` lines; `cuLaunchKernel` and the stderr notes. All match the plan header.

## Probe
`Bang.bend`: `Bang.tree!` over a four-way fork tree of depth 7 (16384 leaves), each leaf a 4096-step xorshift32 loop on a Nat counter (structural tail call). REPEATS from `IO.args`; each round's bang is in a pure def and is preceded by `IO.now()`. After all device rounds, an `IO.now()` step, then the same rounds without `!`; PASS/FAIL on the rotate-xor checksum, exit 1 on mismatch, exit 2 on a missing argument. Not a Writ authority program, so it has no SYNTHETIC records.

Development notes: the first drafts failed the checker on a computed match scrutinee, function calls inside `(.. : U32)` (shifts are `<<`/`>>` by Nat there), U32-counter recursion (rejected as non-terminating via a mutual helper; switched to Nat counters), and a non-reusable pattern variable (`Some{+total}`).

## Build evidence
- `bend ... -o ../writ-build/physical-gpu/bang.c`: exit 0; `408:#define BANGS   1`; sha256 dc7f5730...6c.
- `bend ... -o ../writ-build/physical-gpu/bang`: exit 0, stderr empty, 4.0 s (9.2 s on the first build).
- `nm -D bang`: `U cuInit` and seven `nvrtc*@libnvrtc.so.13`; `ldd`: libcuda.so.1 => /usr/lib/libcuda.so.1, libnvrtc.so.13 => /opt/cuda/lib64/libnvrtc.so.13.
- bang sha256 fccb498a92dad8519056134d629be004ccb3b98471f8fbf48101bd88577d0700; bang.gpu (43104 bytes) sha256 7cf384e07fde15285cdc0ce82e7d4033258495511dd94d91c354ea037bb8b79d; header `08 a5 90 df c8 6f 33 d9`.
- `tail -c +9 bang.gpu > bang.cubin`: sha256 45943ecb...baf9, "ELF 64-bit LSB executable, NVIDIA CUDA architecture".
- `cuobjdump -elf bang.cubin | head`: `64-bit ELF: type=ET_EXEC, ABI=8, sm=89, toolkit=13.4`.
- `cuobjdump -sass bang.cubin | grep -m3 Function`: `window_dev`, `bend_dev`.
- Rebuilds (including after the comment-only edit) reproduced identical bang.c, bang and bang.gpu hashes.

## Observer
Chosen: compute-sanitizer.
- The plan's exact command `compute-sanitizer --dump-kernel-launches yes ...` fails on this version: `compute-sanitizer: extra yes detected on the input command line`, exit 255. `--dump-kernel-launches` is a bare flag here.
- Working form: `compute-sanitizer --dump-kernel-launches --print-limit 0 --kernel-name-exclude regex=.* ./bang +RTS --gpu on -RTS N`.
- `--print-limit 0` is required: at the default (100) the 100-round run listed 100 of 500 launches ("400 errors were not printed"). The "ERROR SUMMARY: N errors" equals the dump-record count; without `--dump-kernel-launches` the same run reports 0 errors.
- Launch counts: N=1: 5, N=2: 10, N=10: 50, N=100: 500 bend_dev launches; no other kernel; per bang grids (1),(128),(128),(128),(1) x 128 threads; host backtrace cuLaunchKernel <- cube_run <- corpus_eval <- io_step <- io_loop <- main. All runs PASS.
- `--gpu off` under the sanitizer: "Target application terminated before first instrumented API call", exit 255 (no CUDA call).
- Overhead at 100 rounds, interleaved: plain 3.073 / 3.039 / 3.558 s; observed 3.435 / 3.908 / 3.683 s (+0.1 to +0.9 s, 4 to 29 percent). `--gpu off`: 3.988 s. Loaded host; indicative only.
- gdb fallback: not exercised (not needed).

## nvidia-smi
300-round run, 9.0 s, PID 637844: `--query-compute-apps` listed `637844, ./bang, 388 MiB` in 3 of 3 samples. `pmon -s u -d 1`: 8 rows for the PID, 1 with a numeric SM (44 percent), 7 with "-". Earlier exploratory runs (200 and 1500 rounds): 2 of 11 and 3 of 46 numeric. Other compute clients (browser GPU process, Signal, a long-running AppImage process PID 633329) and the display share the GPU.

## Commands run (in order, summarised; outputs in the evidence file)
1. `bend guide shaders`; reads of the brief, plan, check-binary.sh, runtime-profile-parity.txt, AGENTS.md.
2. `bend scripts/gpu-validation/Bang.bend -o ../writ-build/physical-gpu/bang.c` (four failing drafts, then exit 0).
3. `bend ... -o ../writ-build/physical-gpu/bang`; `nm -D`, `ldd`, `sha256sum`, `cuobjdump -elf`, `cuobjdump -sass`.
4. `./bang +RTS --gpu off|on -RTS 1`; `./bang` (no argument).
5. compute-sanitizer: exact plan form (refused), flag form, default print limit at 100, `--print-limit 0` at 1/2/10/100, no-dump control, `--gpu off` control; three interleaved overhead pairs at 100.
6. nvidia-smi compute-apps and pmon during 200 (exploratory), 300 (captured) and 1500 (exploratory) round runs, each under `timeout`.
7. The toolchain command list and the 33 driver-string greps, captured into the evidence file.
8. A rebuild into the scratch directory after the comment edit; hashes identical.

## Not exercised
- Any Writ GPU path (Gpu.sweep, Dlm.batch, Transfer.batch): Tasks 3 onward.
- The validation-run record (Task 2) is not attached to these runs.
- Default `--gpu` (no option), `--gpu <size>`, the failed-probe `err_fail` path, the silent `--gpu-build` case, CUDA_VISIBLE_DEVICES controls: read from driver strings only; Task 2's negative controls.
- gdb observer; Nsight (absent); device memory checking (all kernels excluded by design).
- `bend Tests.bend`, `bend PROOF.bend`: no policy code changed; not part of Task 1.

## Concerns
1. The plan's sanitizer command needs two corrections for every later task: drop the `yes` value, and add `--print-limit 0`. Without the second, counts above 100 are silently truncated, which would undercount (or, with a "count >= 1" gate, still pass) a path. observe.sh in Task 2 should also check the sanitizer summary for a "were not printed" line and fail closed on it.
2. The observer counts five bend_dev launches per bang in this probe (the runtime's 1, 2, 4.. pass schedule plus cube grow/drain). The per-bang count is a property of the runtime and the workload, not a constant; later tasks should gate on "at least one bend_dev launch attributed to the path" and record the count, not compare against 5.
3. pmon SM samples are sparse on this shared, loaded GPU (1 of 8, 2 of 11, 3 of 46 rows numeric). It corroborates, but cannot serve as a gate.
4. Side observation, outside this task's scope: the 2.0.39 driver's CPU build flags include `-O3` (driver line 258802 is in the shared `cpu` list), while `verification/runtime-profile-parity.txt` and `check-binary.sh` say `bend -o` builds at -O2. Not changed here (those files are off the touch list); flagged for the controller.
5. Other compute processes shared the GPU during every run; Task 7 timings will need the quiet-host answer from Josh.
