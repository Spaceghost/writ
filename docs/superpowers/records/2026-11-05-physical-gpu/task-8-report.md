# Task 8 report: trust profile (4.1, 4.2)

Status: DONE_WITH_CONCERNS

## Delivered
- `verification/gpu-trust-profile.md` (new).
- `openspec/changes/validate-physical-gpu-execution/tasks.md`: 4.1 checked, citing the file; 4.2 left unchecked with a note.
- No `.bend`, script, library, law, proof or manifest change. No push.

## Profile sections in brief
- Opening example: the Task 5 fabricate-admitted injection is caught by `Transfer.admit`; a device or driver write to the `Context` itself would not be caught. That is the gap.
- Profile: one profile, GT-1 trusted device. "Trusted" is defined as an assumption, not a demonstration. Nothing is called protected.
- Trusted components: Bend 2.0.39 compiler and runtime (driver sha256 2ec160fa...), generated C and device program; clang 23.1.1; NVRTC 13.4.92 and the `.gpu` cubin; CUDA driver 615.71.09 (UMD `libcuda`, KMD, device nodes mode 666); the GPU and its firmware; host kernel and user account; the display stack and the other device clients (from the Task 1 `nvidia-smi` table); harness scripts (observe.sh, check-record.sh, the Task 7 harness); the observers (compute-sanitizer, nvidia-smi); the Writ library and probes as Bend source.
- Outside the base: only what GT-1 does not admit at all (hostile device code, a hostile driver, interfering local processes). This is stated as a limit.
- Managed heap: quotes `gpu_map` (`cuMemAllocManaged(..., CU_MEM_ATTACH_GLOBAL)`) and `corpus_setup` (`CORPUS = gpu ? gpu_map(size) : corpus_map(size)`), read today from the pinned driver strings, plus Task 1's grep of the allocation line and the shaders guide sentence "Memory is one heap shared by the CPU and the GPU". The file says in bold that the shared writable heap is not protection from those writers, and that such a write is not detected by anything in the evidence. It also covers `--gpu off` (ordinary host mapping, same trust).
- Evidence table: what each file shows and does not show (see citations below).
- Logical-replay paragraph: in-process verification catches wrong returned values of the tested kinds and is not a memory boundary.
- Threat-model exclusion: GV-008's requirement and both scenarios are quoted, along with 4.2's own text. The "otherwise" branch is taken and recorded as a limit. By the cross-lane ruling it does not close 4.2's intent. design.md "Trust profiles require real boundaries" is quoted.
- What would strengthen the profile: an enforced boundary (authoritative state outside device-mappable or driver-writable memory, for example Genode or a separate kernel with IOMMU-confined DMA, plus corruption and access-denial tests); a separate verifier process (insufficient alone, per GV-008 scenario 2); a device memory checker (memcheck/racecheck); Nsight Systems/Compute; a second GPU; a Lean verdict; signed run records; label and transfer checks independent of their producers. None is implemented.
- Limits of the statement: one configuration; the heap facts are read from strings, not observed at run time; co-tenants are trusted by assumption; no performance or qualification claim; Tests/PROOF not run.

## Evidence citations
- verification/gpu-toolchain.txt: header; "Toolchain" (nvidia-smi process table); "Runtime facts from the pinned driver" ("cli_build: GPU compile flags...", "gpu_make: NVRTC options and the .gpu layout", including the cuMemAllocManaged grep at lines 278-279); "Observer 1: compute-sanitizer"; "Result"; "Limits".
- verification/gpu-gate-controls.txt: "Result" (controls a to h; the sanitizer finding on an empty CUDA_VISIBLE_DEVICES; control (b) for no CUDA call under --gpu off); "Limits" (file consistency, not signatures; GPU 0 identity on a one-GPU host only).
- verification/gpu-paths.txt: "Result" (finding 1: the presence poll misses short runs); "Limits" (same address space, logical check; same evaluators; inferred combined split).
- verification/gpu-parity.txt: "Result"; "Limits" (same evaluators; Core.verify the only separate algorithm).
- verification/gpu-injection.txt: "Result" (11 faults denied; forged run FAIL; structural digest collision); "Limits" (no fault inside the device, runtime or managed memory; checks are logical, in the same address space).
- verification/gpu-corpus.txt (with -on/-off): "Result"; "Limits" (solver bang only).
- verification/gpu-pipeline.txt: "Harness"; "Result"; "Limits" (no Nsight split; verify growth unexplained; loaded host).
- openspec/changes/validate-physical-gpu-execution/specs/gpu-validation/spec.md, GV-008 (quoted); tasks.md 4.2 (quoted); design.md "Trust profiles require real boundaries" (quoted).
- `bend guide shaders` (the heap sentence, quoted).

## Box states
- 4.1: `[x]`, citing verification/gpu-trust-profile.md.
- 4.2: `[ ]`, with the note that the exclusion is a recorded limit and that, by the controller ruling, the intent is not closed.

## Checks
- `openspec validate --all --strict --no-interactive` (1.16.0): 44 passed, 0 failed.
- `bend Tests.bend` and `bend PROOF.bend` were not run: no Bend source changed.
- Wording scan: every "protect" and "boundary" in the file is negated, a quote, or future work.

## Concerns
1. The brief says "Spec task 4.2 is closed by its exclusion branch". The plan's cross-lane ruling and the dispatch say the exclusion does not close 4.2's intent. I followed the ruling and left 4.2 unchecked. If the controller wants the box checked as a recorded-limit closure, it is a one-character change, and the note would need rewording.
2. The plan says Task 9 alone edits tasks.md. The dispatch directed the 4.1 and 4.2 box edits here, so I made them. Task 9 should not redo them.
3. The brief asks to "cite the gpu_map string from Task 1". Task 1 grepped the `cuMemAllocManaged` line, not the `gpu_map` name. The function name and the `corpus_setup` caller were read today from the same driver binary (same sha256) and quoted in the profile with the command. That makes them a new read, not a Task 1 record.
4. The trusted list adds items beyond the brief's six (the GPU and its firmware, the other device clients, the observers, the Writ library and probes). Without them the list would leave pieces in force during a run that were not named as trusted.

## Fix round 1

These edits respond to task-8-review.md. All of them are text-only changes to verification/gpu-trust-profile.md. tasks.md is unchanged.

1. The 1 ms timer limit and the deferred-evaluation limit are now in the pipeline row's "Does not show" cell. A matching bullet is added under "Limits of this statement".
2. The trusted list now names more of the Writ modules: `GpuLibrary` (imported as `GPU`) and `Ledger`, `Frontend`, `Backplane` and `Negotiation`, which Transfers.bend imports. A new bullet names Bend's Base library, including `effs/now.c` (fc4c1d87...). Another new bullet names the host tools: `/bin/sh`, python3 (trun.py's clock readings and summarize.py's acceptance rule), `sha256sum`, `diff`, `cmp`, and `cuobjdump`. The harness bullet now also covers summarize.py's run-acceptance decisions and statistics.
3. The library bullet says the proofs were checked by Bend's own checker, were not rerun in this lane, and have no Lean kernel verdict.
4. The heap statement used to say a write was "not detected by anything in this lane's evidence". It now says no check that guards a run would detect it. The after-the-fact `--gpu off` stdout comparisons would show such a write only if it changed printed output. The opening example was aligned with this wording.
5. The gate row quotes the binary_sha256 re-hash limit.
6. The Task 7 harness citation now reads "quoted in 'Harness', with their sha256 in 'Build'".
7. The device clients are quoted as `nvidia-smi` recorded them, including the three truncated `...rack-uuid=...` entries. Task 1's identification is quoted. The table is marked as a single snapshot; the clients during later runs were not recorded.
8. "the only profile this lane validates" now reads "the only profile under which this lane's evidence is stated".

OpenSpec 1.16.0 `validate --all --strict --no-interactive` gives 44 passed, 0 failed. No Bend source changed, so Tests and PROOF were not run.
