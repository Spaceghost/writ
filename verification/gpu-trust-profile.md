# GPU trust profile (GV-008; spec tasks 4.1 and 4.2)

Recorded 2026-11-05 UTC (physical-gpu lane, Task 8) on the one GPU host of this lane:
Linux 7.2.9-1-MANJARO x86_64, 32 online CPUs, NVIDIA GeForce RTX 4090
`GPU-0188dad3-4d11-4254-3a0d-50e3808bf464` at bus `00000000:0C:00.0`, compute capability
8.9, driver and KMD 615.71.09, CUDA UMD 13.4 (verification/gpu-toolchain.txt, header and
"Result").

This file states what the GPU evidence of this lane runs on and trusts. It is a trusted-base
statement, in the shape of `verification/unikernel-appliance-rules.md` ("Trusted-base
statement") and `hosts/genode/INVENTORY.md`. It is not a host qualification and not a
security boundary. Nothing in it is implemented code; no `.bend` file, script or library
module changed for it.

Example. In the Task 5 run `transfers-inject-fabricate-admitted`, the probe takes the
device's transfer decisions, rewrites one leaf from `Denied Read` to an `Admitted` ticket,
and hands the result to `Transfer.admit` against the authoritative `Context`. The replay
denies it, 1000 of 1000 rounds (verification/gpu-injection.txt, "Result"). That is a wrong
returned value, and the checks catch it. Now suppose device code, or the driver, wrote into
the `Context` itself, or into the original graph, before the replay read it. Nothing in this
lane's evidence would notice: the replay would read the altered value as authoritative. The
gap is that the device, the driver and the verifier share one writable heap.

## Profile

There is one profile, **GT-1 trusted device**. It is the only profile this lane validates.
No other profile is defined here, and no profile here treats a GPU program or the driver as
untrusted.

Under GT-1, every component below is in the trusted base. "Trusted" means that the evidence
assumes the component behaves as documented and does not act against Writ's state. It does
not mean that the component was shown to behave that way, and nothing below is called
protected.

## Trusted components

Every component in this list is trusted under GT-1.

- **Bend 2.0.39 compiler and runtime.** The pinned driver binary
  `$HOME/.local/share/writ-toolchains/bend-2.0.39/bend/bin/bend`, sha256
  `2ec160fa4486d33aff51e9eedcc294d6b531dc10c279c00b0c00685dae2045cd`. It emits the C, embeds
  the runtime (heap, scheduler, bang dispatch, `gpu_probe`, `gpu_map`, `gpu_make`,
  `cube_run`) and the CLI build steps (verification/gpu-toolchain.txt, "Runtime facts from
  the pinned driver"). The generated C and the generated device program are its output and
  are trusted with it.
- **clang 23.1.1** at `/usr/bin/clang`, which compiles the emitted C with `-DBEND_CUDA=1` at
  `-O3` and links `libcuda` and `libnvrtc` (verification/gpu-toolchain.txt, "cli_build: GPU
  compile flags and the --gpu-build step").
- **NVRTC 13.4 and the `.gpu` cubin it produced.** `libnvrtc.so.13.4.92` under `/opt/cuda`
  compiles the device program at `--gpu-build` time (options `--gpu-architecture=sm_89`,
  `-DCUBE_LOG=...`, `--fmad=false`, `-default-device`), and the runtime writes an 8-byte
  source hash followed by the cubin to the `.gpu` file beside each binary
  (verification/gpu-toolchain.txt, "gpu_make: NVRTC options and the .gpu layout"). Each
  task's `.gpu` sha256 is in its evidence file's "Build" section. The cubin holds the
  `bend_dev` kernel that every device run launches. nvcc 13.4.92 is present and is not used.
- **The CUDA driver 615.71.09**: the user-mode `libcuda.so.1` (CUDA UMD 13.4) and the
  kernel module (KMD 615.71.09, `/proc/driver/nvidia/version`), with the device nodes
  `/dev/nvidia0`, `/dev/nvidiactl` and `/dev/nvidia-uvm`, all mode 666
  (verification/gpu-toolchain.txt, "Result"). The driver allocates and migrates the managed
  heap (next section), loads the module, and launches every kernel.
- **The GPU and its firmware**: the RTX 4090 named above. Nothing in this lane inspects it.
- **The host kernel and the user account**: Linux 7.2.9-1-MANJARO, glibc 2.44, and the
  account that ran every build and run. Because the device nodes are mode 666, any local
  process can open the device; GT-1 assumes that none of them interferes.
- **The display stack and the other clients sharing the device.** gnome-shell and Xwayland
  are graphics processes on this GPU. Slack, ghostty, Dozer, a QEMU process, Electron, Zoom,
  browser processes (two of them `C+G`) and a long-running process run through
  `/lib64/ld-linux-x86-64.so.2` (PID 633329, `C+G`) were also listed on it
  (verification/gpu-toolchain.txt, the `nvidia-smi` process table in "Toolchain"). GT-1
  assumes that none of them interferes with a Writ run. No run tested that.
- **The harness scripts**, trusted only for the PASS and FAIL lines and gate verdicts they
  print: `scripts/gpu-validation/observe.sh` (sha256 `efd08afb...`) and
  `scripts/gpu-validation/check-record.sh` (sha256 `7d4df17b...`), POSIX sh, which start
  processes, sample `nvidia-smi`, and read files; and the Task 7 timing harness outside the
  tree, `../writ-build/physical-gpu/task7/{build.sh,trun.py,series.sh,summarize.py,mkruns.sh}`,
  quoted with hashes in verification/gpu-pipeline.txt, "Harness". They make no Writ
  authority, label or admission decision; every comparison of results is in the Bend probes.
- **The observers**: compute-sanitizer 2026.3.0.0, the launch observer, which counts
  `bend_dev` launches with host backtraces and excludes every kernel from memory checking by
  design; and `nvidia-smi` (`--query-compute-apps`, `pmon`, `--query-gpu`), which is
  corroboration only (verification/gpu-toolchain.txt, "Result", "Observer 1:
  compute-sanitizer"; verification/gpu-gate-controls.txt, "Result").
- **The Writ library and the probes**, as Bend source: `Core`, `Dlm`, `Transfer`, `DataOS`,
  `Gpu`, the `GPU.*` entry points the probes call, `examples/Scenario.bend`, and `scripts/gpu-validation/{Bang,Solver,Labels,Transfers}.bend`.
  Their correctness claims rest on the library corpus and the proofs, which this file does
  not restate.

## Outside the trusted base

Nothing that executes during a GPU run is outside the trusted base under GT-1. The only
things outside it are those this profile does not admit at all:

- hostile device code, meaning a GPU program other than the cubin above, or that cubin
  acting against Writ's state;
- a hostile driver, user-mode or kernel-mode;
- any other local process acting against the device or the run.

These are excluded from the validated threat model (see "Threat-model exclusion"). They are
not handled by anything in this lane, and their exclusion is a limit of GT-1.

## The managed heap is shared and writable

Under `--gpu on` the runtime allocates the whole term heap as one CUDA managed region. The
pinned driver's runtime C, read from the same binary as above (sha256 `2ec160fa...`) with
`strings -n 6 "$(command -v bend)" | sed -n '256429,256438p;256601,256609p'` on 2026-11-05
(excerpt; `...` marks omitted lines; Task 1 matched the allocation line, not the function name):

```
static u64* gpu_map(u64 bytes) {
  CUdeviceptr p = 0;
  if (cuMemAllocManaged(&p, bytes, CU_MEM_ATTACH_GLOBAL) != CUDA_SUCCESS) {
    err_fail("corpus reservation failed");
#if CUDA_VERSION >= 13000
  cuMemAdvise(p, bytes, CU_MEM_ADVISE_SET_PREFERRED_LOCATION,
    (CUmemLocation){ CU_MEM_LOCATION_TYPE_DEVICE, gpu_dev });
...
static u64* corpus_setup(bool gpu, long threads, u64 bytes) {
  ...
  CORPUS     = gpu ? gpu_map(size) : corpus_map(size);
  u64* H     = CORPUS;
```

The `cuMemAllocManaged(&p, bytes, CU_MEM_ATTACH_GLOBAL)` line is the one Task 1 matched in
the driver strings (verification/gpu-toolchain.txt, "gpu_make: NVRTC options and the .gpu
layout", the grep at its lines 278-279). The shaders guide says the same thing in prose:
"Memory is one heap shared by the CPU and the GPU: unified on Apple; managed on CUDA, where
each page faults across PCIe on the first touch by the other side" (`bend guide shaders`).

So under `--gpu on`, the one region `H` holds every term the program builds: the original
`Core.Graph` and its stamp, the label snapshot, each transfer `Context`, the device's
candidate results, the CPU reference results, the verifier's inputs, and the session,
ledger and registry values the commit path reads. The `bend_dev` kernel runs over that
region, and the driver can read and write all of it. CPU-side checks such as `Core.verify`,
`Dlm.verify_batch`, `Transfer.admit` and `DataOS.commit_from_capability` read their
"authoritative" inputs from the same region the device writes.

Stated plainly: **the shared writable heap is not protection from those writers.** Device
code or the driver can write the original graph, the snapshots, the contexts, and the
values the commit path reads, and a write of that kind is not detected by anything in this
lane's evidence. The checks compare one value in the heap with another value in the same
heap, so they cannot notice when the reference value itself was altered.

Under `--gpu off` the heap comes from `corpus_map` (an ordinary host mapping) and no CUDA
call is made (verification/gpu-gate-controls.txt, control (b)). That changes where the heap
lives, not the trust: the runtime, the host kernel and the user account are still trusted.

## What the evidence shows, and what it does not

Each row is scoped to this host, this GPU, driver 615.71.09, Bend 2.0.39 and CUDA/NVRTC
13.4.92. Every wall time in this lane was taken on a loaded, shared host and is indicative
only.

| Evidence (file, section) | Shows | Does not show |
| --- | --- | --- |
| verification/gpu-toolchain.txt, "Result" and "Limits" | The toolchain is present with the versions above; a bang build takes the CUDA path and writes an sm_89 cubin with `bend_dev`; compute-sanitizer counts `bend_dev` launches per process; `--gpu off` makes no CUDA call. | Any memory access by a kernel (all kernels are excluded from checking by design); which Bend def a lane ran; any Writ path. |
| verification/gpu-gate-controls.txt, "Result" and "Limits" | The gate passes only `--gpu on` runs with at least one observed `bend_dev` launch; forced CPU fallback, the hidden device, zero launches, a missing driver field, a missing or truncated log, and a record whose claims disagree with its log are refused. Finding: compute-sanitizer removes an empty `CUDA_VISIBLE_DEVICES` from its target (it "unhides" the device), so hiding uses an invalid id. | Authenticity. The gate checks that files are consistent with one another, not signatures: "it does not resist a forger who rewrites a log and its record consistently". Device identity comes from `nvidia-smi -i 0`, which ignores `CUDA_VISIBLE_DEVICES`, and is exact on this one-GPU host only. |
| verification/gpu-paths.txt, "Result" and "Limits" | Each of the three paths (solver, label batch, transfer batch) compiled for sm_89, ran with observed launches in its own single-bang binary, and gave results equal to the CPU reference and accepted by the check or replay. | Finding (1): short runs (0.25 to 0.5 s) fail the gate's presence rule because the process ends before the 200 ms `--query-compute-apps` poll lists it; presence is a poll, not an observation of every run. "The independent checks run in the same process and in the same address space as the device result; they are a logical check, not a memory-protection boundary." The combined-run per-path split is inferred. |
| verification/gpu-parity.txt, "Result" and "Limits" | 20 cases (bits 31, 32, 63, cycles, empty input, conflicts, stale epochs, missing grants): 18 device-validated, 0 differences, `--gpu off` stdout byte-identical. | The label and transfer `verify` lines "replay the same evaluators as the CPU reference" (Dlm.verify_batch is Dlm.batch plus answers_equal; the transfer replay is Transfer.admit, which Transfer.batch calls). Only Core.verify is a separate algorithm. Finite, small, synthetic cases. |
| verification/gpu-injection.txt, "Result" and "Limits" | 11 probe-injected faults on device results (dropped node, erased source, cleared bit 63, stale stamp, flipped denial, truncated tree, swapped shape, fabricated Admitted, wrong plan, stale context, forged commit), each denied in every round; the forged faster run is recorded as FAIL and its time is not accepted. Finding: the 32-bit digests collide structurally (the allow-all and the correct label trees hash equal at every power-of-two size from 256 leaves), so no digest is equality evidence; the typed in-process comparisons are the record. | "No fault is injected inside the device, the runtime or managed memory, and no bit flip in transit is simulated." "Each injection is a probe-side change of a value in the same process. The checks are logical, in the same address space. They are not a protection boundary." They do not show a verifier independent of its producer for labels and transfers. |
| verification/gpu-corpus.txt (with gpu-corpus-on.txt and gpu-corpus-off.txt), "Result" and "Limits" | The library corpus prints the same 782 PASS lines with `--gpu on` and `--gpu off`, byte-identical to verification/tests-native.txt; 4915 `bend_dev` launches attributed to the solver bang. | GPU evidence for the label or transfer paths (the corpus binary reaches only the solver bang); which launches belong to which test. |
| verification/gpu-pipeline.txt, "Result" and "Limits" | Complete-pipeline timings for the three paths at sizes 16, 1024 and 16384, each series labelled "taken on a loaded host; not representative"; the GPU path was slower in every cell; the verify stage (CPU code) is larger under `--gpu on`. | The split of the device call into memory movement, dispatch and kernel time (Nsight is absent); the cause of the verify-stage growth (managed-memory faults on host access is "likely but unestablished"); anything about a quiet host. |

Across all of these, the in-process verification is a logical replay. It reads the original
inputs and the candidate from the same heap, in the same process, after the device call.
Under GT-1 it catches wrong returned values of the kinds tested: Core.verify on the original
graph (a separate algorithm, an original-graph closure check), and the label and transfer
replays (the same evaluators as their producers). It is not a memory boundary, and it says
nothing about a write to its own inputs.

## Threat-model exclusion

GV-008, "Enforce a boundary for untrusted-device claims", in its own words:

> A profile treating GPU programs or the driver as untrusted SHALL protect authoritative
> monitor state and final commit with an enforced memory/device boundary independent of the
> candidate verifier.

Scenario "Device can write the verifier's authoritative heap":

> **GIVEN** a GPU program or driver can modify original snapshots or final authorization state
> **WHEN** a deployment claims that component is outside the trusted computing base
> **THEN** the untrusted-device security claim is rejected despite correct verifier code

Scenario "Separate process retains a privileged shared-memory writer":

> **GIVEN** the verifier runs in another host process
> **AND** the driver still has authority to write that process's memory
> **WHEN** the deployment evaluates its isolation evidence
> **THEN** process separation alone does not satisfy the untrusted-driver boundary

Spec task 4.2's own words: "For any profile claiming an untrusted GPU program or driver,
implement the selected enforced memory/device boundary and verify denied access to
authoritative snapshots and commit state; otherwise explicitly exclude that hostile
component from the validated threat model."

GT-1 takes the "otherwise" branch, and records it as a limit of the profile:

- **Hostile device code and a hostile driver are excluded from the validated threat model.**
  No profile here claims an untrusted GPU program or driver. GT-1 makes no untrusted-device
  security claim, so the first scenario's claim is not made. Under GT-1 a GPU program or the
  driver can modify original snapshots and final authorization state (previous section), and
  that is exactly why no such claim may be made.
- **A separate host process would not change this.** If the verifier ran in another process
  while the driver kept authority to write that process's memory, the second scenario
  applies: process separation alone does not satisfy the untrusted-driver boundary. No such
  arrangement was built or run.
- **The exclusion is a limit, not a result.** By controller ruling (plan, Global
  Constraints, cross-lane ruling of 2026-11-05), recording the exclusion does not close the
  intent of spec task 4.2: the enforced boundary for an untrusted-device profile does not
  exist, and no access-denial test exists. The design says the same: "Any stronger profile
  that treats GPU programs or the driver as hostile requires an enforced boundary protecting
  authoritative state, original snapshots, and the final commit path"
  (openspec/changes/validate-physical-gpu-execution/design.md, "Trust profiles require real
  boundaries").

## What would strengthen the profile

None of the following is implemented. Each is a missing piece, not a plan of record.

- **An enforced boundary, for any future untrusted-device profile.** Authoritative state
  (original graphs and stamps, label snapshots, transfer contexts, session, ledger,
  registry, and the final commit path) held outside any device-mappable or driver-writable
  memory. For example, a Genode or other separate-kernel arrangement in which the GPU
  driver runs in its own component and the device's DMA is confined by an IOMMU to buffers
  the monitor hands it, with the monitor copying candidates out before checking them. Then
  scoped corruption tests and access-denial tests that show the device and the driver
  refused access to that state, with their limits stated and without claiming they prove
  all hardware behaviour.
- **A separate verifier process** whose memory the driver has no authority to write. On its
  own, per GV-008's second scenario, this does not satisfy the boundary; it is one part of
  the arrangement above.
- **A device memory checker**: compute-sanitizer's memcheck (and racecheck) on `bend_dev`,
  which this lane excluded by design to count launches. It would report out-of-bounds and
  racy accesses by the shipped kernel. It would not make a hostile kernel or driver
  trustworthy.
- **Nsight Systems and Nsight Compute** (`nsys`, `ncu`, not installed): the split of the
  device call into managed-memory migration, dispatch and kernel time, and per-kernel
  timelines. That evidence is about attribution and performance, not about a boundary.
- **A second GPU** (or a second host), so that device identity is recorded through the
  `CUDA_VISIBLE_DEVICES` to `cuDeviceGet` mapping rather than assumed from GPU 0, and so
  that parity is shown on more than one device and driver.
- **A Lean verdict**: `bend PROOF.bend --verdict` with the documented Lean kernel toolchain.
  Lean is not on PATH on this host (plan, Global Constraints), so no kernel-checked verdict
  exists for the proofs this lane relies on.
- **Signed run records**: the gate checks file consistency, not signatures, so a record and
  its log rewritten together pass it (verification/gpu-gate-controls.txt, "Limits").
- **Label and transfer checks independent of their producers**: only Core.verify is a
  separate algorithm today (verification/gpu-parity.txt, "Limits").

## Limits of this statement

- One profile, one host, one GPU, one driver, one Bend and one CUDA version. A change to any
  trusted component listed above needs its evidence rerun before GT-1 extends to it.
- The managed-heap facts come from the pinned driver's embedded runtime C, read as strings
  from the binary. They were not observed at run time: no run dumped the allocation or
  traced a device write to the heap.
- The display stack and the other device clients are trusted by assumption. No run tested
  their interference, or its absence.
- This file makes no performance claim and no host-qualification claim. A CPU fallback is
  not a GPU test, and the `--gpu off` runs in this lane are CPU execution throughout.
- Not run for this task: `bend Tests.bend` and `bend PROOF.bend`. No library, law, proof or
  probe source changed.
