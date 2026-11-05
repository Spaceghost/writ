# Task 1 review: GPU toolchain and observation method

Reviewed range: cecf848..35c8b3b (4 files). Reviewer is read-only apart from this file.

## Verdicts
1. Spec compliance: APPROVED
2. Record quality: NEEDS_FIXES (documentation-only; no re-run needed except an optional quoted rebuild)

## Findings, by severity

### Record quality (all fixable by editing verification/gpu-toolchain.txt)
1. (medium) verification/gpu-toolchain.txt:4 and :688 state "load average 48 to 115". The quoted `uptime` lines show 1-minute values of 47.92 to 67.84 (lines 170, 330, 411, 616, 665; 5-minute figures reach 88.17). 115 is not backed by any quoted output (it comes from unrecorded exploratory runs). Fix: say "1-minute load average 47.92 to 67.84 in the quoted uptime lines (5-minute up to 88.17)", or quote the exploratory uptime that showed 115. Same wording in task-1-report.md:Environment.
2. (medium) verification/gpu-toolchain.txt:327 and :671: the build capture was taken from a Bang.bend that differs from the committed one (comment lines reworded after the capture). The claim that a rebuild "reproduced the same bang.c, bang and bang.gpu sha256" has no quoted command or output. I confirmed on disk that Bang.bend, bang, bang.gpu, bang.c and bang.cubin hash to the recorded values (5ff66256..., fccb498a..., 7cf384e7..., dc7f5730..., 45943ecb...), but the evidence file itself does not show the rebuild. Fix: add a short "## Build (rebuild after comment edit)" block with the two `bend` commands (scratch dir) and the three `sha256sum` lines, or rebuild once from the committed source and replace the capture.
3. (low) verification/gpu-toolchain.txt:8 (Execution line): "the `--gpu on` runs ... each of which the compute-sanitizer observer shows launching bend_dev (5 launches per round)". The unobserved `--gpu on` runs (run-on-1 at :422, the plain overhead runs :584/:593/:602, the 300-round nvidia-smi run :621) were not under the observer; only the sanitizer runs were. Also "5 launches per round" reads as a constant, contrary to the controller ruling (count is workload-dependent; later gates need at least one attributed bend_dev launch). Fix: "device runs are the compute-sanitizer runs below (bend_dev launches counted); other `--gpu on` runs are the same binary and arguments, device-requested but not individually observed; the count was 5 per round in this probe and is not a constant." Same softening at :673.
4. (low) The "-lcuda -lnvrtc" flag fact: only `-lnvrtc` is grepped (:211-213); the report (Runtime facts) says "`-lcuda -lnvrtc`" matched. libcuda linkage is shown via ldd (:366) but there is no driver-string line for `-lcuda`. Fix: add the grep for the `-lcuda` line or correct the report text.
5. (low) :138-139: the `which` PATH is replaced by "<PATH elided ...>". Disclosed in the text, acceptable; but this is edited output. Optional fix: quote it unabridged.
6. (info) No Nsight/overhead issues: overhead percentages (11.8, 28.6, 3.5) check against the quoted walls.

### Spec compliance
No blocking findings. Observations only:
- Bang.bend has no SYNTHETIC records, correct since it is not an authority program.
- The "no other kernel" statement is backed by a per-run count (`grep 'Kernel:' | grep -vc bend_dev` is 0 for 1, 2, 10, 100 rounds) and launch-number equals record count; only the 1-round run quotes the raw dump (:446-517). Acceptable.
- cuobjdump -elf head quoted `sm=89`; the -sass grep shows `window_dev` and `bend_dev` (:402-405); the cubin identity is tied to bang.gpu by `tail -c +9` and the recorded header bytes.

## Verified
- Evidence shape: header has Bend version, compiler, host, load average, date, environment, Execution; `## Toolchain`, `## Build`, `## Run`, `## Result`, `## Limits` present. Every component carries version and discovery command (`command -v`, ldconfig, ls -l, /proc).
- Git: `git diff --name-only cecf848..35c8b3b` is activity.log, task-1-report.md, scripts/gpu-validation/Bang.bend, verification/gpu-toolchain.txt: all within the touch list (records directory is allowed). `git diff --name-only master -- '*.bend'` lists only scripts/gpu-validation/Bang.bend. No count pin, no policy file, no manifest touched.
- Disk hash spot-check (ran sha256sum): all five built/source hashes match the evidence. Re-ran read-only `cuobjdump -elf` (sm=89, toolkit=13.4) and `cuobjdump -sass | grep Function` (window_dev, bend_dev) on the existing bang.cubin; `compute-sanitizer --version` returns 2026.3.0.0 (build 38855100), matching :133.
- Plan deviation explained: the failing form (`--dump-kernel-launches yes`) with its exact error (:440-443, exit 255), sanitizer version, and the reason for `--print-limit 0` (default limit truncated 500 to 100 listed, :519-523).
- Checksums: bang equals no-bang checksum on every quoted run; `--gpu off` and `--gpu on` 1-round outputs are byte-identical (cmp, :430). `--gpu off` under the sanitizer shows no CUDA call (:573-580), so a CPU run cannot be mistaken for a device run.
- Limits list covers: display and other clients sharing the GPU, load, gdb not exercised, no Writ path run, string-matched behaviours deferred to Task 2, no Nsight, record v1 not attached, device memory not checked. Nothing reads as a Writ GPU path having run. Wall times carry the load caveat (:4, :675, :688); pmon is stated as corroboration only.

## Not run
No build, no corpus, no probe run, no nvidia-smi sampling; only sha256sum, cuobjdump and compute-sanitizer --version on existing files.
