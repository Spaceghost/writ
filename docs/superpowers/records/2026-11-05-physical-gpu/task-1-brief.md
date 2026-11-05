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

