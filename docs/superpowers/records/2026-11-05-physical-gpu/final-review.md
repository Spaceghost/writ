# Final whole-branch review: lane/physical-gpu (validate-physical-gpu-execution)

Reviewed tree: lane/physical-gpu at f23ce66 (master 1c73004 merged at dbed241), worktree
`../writ-lanes/physical-gpu`. Read-only review on 2026-11-05. No GPU workload was rerun.

**Assessment: Needs fixes before merge**

The central GPU claims hold. Every one closes the chain from claim to evidence: built binary,
`.gpu` holding an sm_89 cubin with `bend_dev`, an observed run, a sanitizer log the record
cites, a recounted launch count, the gate verdict, a typed comparison with the CPU result, and
the verifier run on the original inputs. I found no route by which a record passes the gate
without an observed `bend_dev` launch. The fixes required before merge are all text, plus the
already-planned device corpus rerun on the merged tree. One published claim is false on the
merged tree as worded (I-1). Two limits carried from Task 2 were never stated (I-2). One
evidence hash is malformed (I-3).

## Findings, by severity

### Important (fix before merge)

**I-1. "Byte-identical to tests-native.txt" is false on the merged tree as worded.**
On master, `verification/tests-native.txt` is now the 1428-check capture
(sha256 `6faee219...9318`, 1428 PASS lines). `cmp verification/gpu-corpus-on.txt
verification/tests-native.txt` now reports a difference at byte 25272, line 498. The 782 capture
(`fc3a08aa...16ff`) is only identical to the file **as of 98db68bf**
(`git show 98db68bf:verification/tests-native.txt | sha256sum` = `fc3a08aa...`). Places
that state it without that pin:
- VERIFICATION.md:203-205 ("byte-identical to `tests-native.txt`, on the 782 tree"). The tree is scoped, but the file named is the current one.
- verification/gpu-trust-profile.md:183 ("The library corpus prints the same 782 PASS lines ... byte-identical to verification/tests-native.txt"). This row also names neither the tree nor the revision.
- verification/gpu-validation-hosts.md:62 ("byte-identical to `gpu-corpus-off.txt` and `tests-native.txt`").
- openspec/traceability/gpu-validation.md:56, GV-003 ("byte-identical to tests-native.txt, on the 782 tree").

Fix: in each place write "byte-identical to `verification/tests-native.txt` as of 98db68bf
(sha256 `fc3a08aa...062916ff`)". When the final round reruns the device corpus on the merged
tree, compare the new captures with the current `tests-native.txt` (`6faee219...`). Add a
merged-tree row and keep the 782 row as history. In the trust profile, also add the limit "the
device corpus ran on the 782 tree; the merged tree has no `--gpu on` corpus run" (or replace it
after the rerun). It is the one listed limit missing from the trust profile's "Limits of this
statement".

**I-2. Task 2's carried harness notes were never closed or stated.** progress.md records "four
hardening notes carried to the final round" (task-2-review.md:11-14). observe.sh and
check-record.sh are unchanged since 50ed67c (sha256 `efd08afb...`, `7d4df17b...`, verified).
Only note 4 (binary_sha256 not re-hashed) appears in any Limits text. The other three are
missing:
- scripts/gpu-validation/observe.sh:273-275: `target_cuda_visible_devices` is **inferred**. It comes from a separate `compute-sanitizer sh -c` probe, not from the probe binary's own environment. No published file says so. It underpins the hidden-device finding the gate relies on.
- observe.sh:262/278: `$SANLOG` is not removed before the observed pass. A stale log is not currently reachable, because the sanitizer overwrites it (task-2-review.md:11), but that property depends on sanitizer behaviour.
- scripts/gpu-validation/check-record.sh:289: the pid in `pmon_max_sm` is not compared with the pid in `compute_app_seen`.

Fix (required, text only): state all three in openspec/traceability/gpu-validation.md (GV-001
gap) and in the trust profile's gate row (verification/gpu-trust-profile.md:179). The
inference wording matters most. Do **not** change the harness before the corpus rerun. Every
record and the hosts table bind `efd08afb`/`7d4df17b`, and a changed harness would split
harness versions across rows. The code hardening is optional and belongs in a follow-up.

**I-3. Malformed hash in an evidence file.** verification/gpu-parity.txt:3982 gives
solver.gpu as `db3438f73ad2d6c9a283fb...` with 65 hex characters. The file on disk and the
hosts table give `db3438f7ad2d6c9a283fb25c30b67adcbc83e50949db91c30b255dcbeeba7bfb`. It is the
only hex string of the wrong length in the published GPU files (I scanned all of them). Fix:
correct the Result line to the 64-character value, with a one-line Task 9-style note that it is
a transcription fix and no rerun was done.

### Minor (should fix; text; may go in the final round)

**M-1. Two limits are missing from the traceability gaps.** The trust profile has them; the
traceability file does not: (a) compute-sanitizer strips an empty `CUDA_VISIBLE_DEVICES`, so
hiding the device needs an invalid id (gpu-gate-controls.txt "Result" finding); (b) the 1 ms
`IO.now` timer resolution and the undefined warm ratios (gpu-pipeline.txt "Limits"). Fix: add
(a) to the GV-001 gap and (b) to the GV-005 gap. All the other listed limits are present in
both files: digest collision, same evaluator, logical replay in the same address space,
Core.verify the only separate algorithm, no signatures, one-GPU identity, presence-poll gaps,
loaded host, no Nsight, no Lean, no merged-tree corpus.

**M-2. Load wording contradicts the pipeline file** (Task 9 Low 1, carried).
verification/gpu-validation-hosts.md:97 says "every timing was taken at a 1-minute load above
16". gpu-pipeline.txt:4482 says the solver 16384 series started at 15.95 and the load fell to
about 10 to 16 during it. That Limits bullet's first sentence ("every series was taken at a
1-minute load average above 16") also contradicts its own later sentences. Fix: "above 16 at
every series boundary but one (15.95); about 10 to 16 for a few minutes inside the solver
16384 series" in both places.

**M-3. "Slower than the CPU in every measured cell" reads as a performance result** (Task 9 Low
2, carried). VERIFICATION.md:225 and openspec/traceability/parallel-execution.md:27. Fix: "the
complete `--gpu on` pipeline took longer than `--gpu off` of the same binary in every measured
cell on this loaded host; this is not a performance result".

**M-4. GPU claim and verifier outcome are fused in one sentence.** VERIFICATION.md:210-221 (the
"GPU claim" paragraph) includes "for 11 injected faults on device results, each denied in every
round". The denial is a CPU verifier outcome. The PX-001 pointer
(openspec/traceability/parallel-execution.md:11) joins "observed `bend_dev` launches ... and
gate PASS" with "results equal to the CPU reference and accepted by the independent check or
replay". The same holds for the three-path sentence in gpu-paths.txt "Result", but that one
follows the wording of GV-002's own scenario and can stay. Fix VERIFICATION.md and PX-001: the
GPU sentence names the observed launches and gate PASS. A second sentence says that the device
results equalled the CPU reference (typed comparison) and that the CPU-side check or replay
accepted them or denied the injected faults.

**M-5. Gate limits not stated.** check-record.sh:263 accepts any `ERROR SUMMARY` line. It does
not compare the summary count with the number of dumped launches, so a sanitizer-reported CUDA
API error would not fail the gate. I checked every stored finished log, and in each one the
summary count equals the `Launch #` count, so no such error occurred. The gate also neither
re-checks `gpu_program_sha256` and `gpu_arch` against the files nor confirms that the module
launched is the hashed cubin. The record carries those fields; the gate does not check them.
I re-hashed every binary and `.gpu` on disk, and all fifteen match the hosts table. Fix: add
both to the gate row of the trust profile and to the GV-004 gap, next to the binary_sha256
sentence. Hardening, optional and later: fail when `ERROR SUMMARY N` differs from the launch
count.

**M-6. tasks.md:15** says "782 PASS with `--gpu off`" without the tree. Fix: add "(782 tree,
98db68bf)". tasks.md:3 ("All hardware ... work below is pending") is already planned for the
final round.

### Optional

- O-1. verification/gpu-validation-hosts.md:61: the injected-faults row omits Task 5's 15th record, `transfers-run-16384`. That run exercises the all-field transfer digest on device output (5 launches, gate PASS; check-record.sh exit 0, rechecked). Add it, or say "11 injected cases, two honest runs, one digest run".
- O-2. gpu-injection.txt:2477 and gpu-parity.txt "Limits" say "all-field digest". Each is qualified right away ("does not make the digest equality evidence"), so this is acceptable. "20-field digest" would read less like a coverage claim.
- O-3. verification/gpu-trust-profile.md:72-73 quotes Task 1's description of the device clients ("Signal"), which does not match the recorded process table it quotes just above. It is labelled as Task 1's wording. A short note would remove the apparent contradiction.

## Planned final round (already ruled; confirm when done)

1. Rerun the device corpus on the merged 1428 tree: an observe.sh pair at `--gpu on` plus the
   `--threads 4` on and off captures, compared with the current `tests-native.txt`
   (`6faee219...`). Add the merged-tree rows to the hosts table, gpu-corpus.txt, VERIFICATION.md,
   the trust profile and GV-003/GV-004, and delete the "no merged-tree corpus" gap only after
   that. This closes I-1's second half.
2. tasks.md:3 and openspec/traceability/parallel-execution.md:5-7 (the intro still says "does
   not validate GPU hardware"; it should say that this baseline evidence does not, and point to
   the proposed change's one-host evidence).
3. Controller regenerates `verification/source-sha256.txt`. It is stale for VERIFICATION.md,
   tasks.md and parallel-execution.md, and it lacks the new scripts/gpu-validation/ and
   verification/gpu-* files. Rerun OpenSpec strict after the text fixes.

## What I verified, and how

Chain from claim to evidence, per path and for the corpus:
- **Build to sm_89 and `bend_dev`.** For all fifteen built binaries (bang, solver, labels, transfers, gpu-example, and the task4/5/6/7 builds), I took `sha256sum` of the binary and `.gpu`, ran `tail -c +9 X.gpu`, then `cuobjdump -elf` (`sm=89`) and `cuobjdump -sass` (`Function : bend_dev`). Every hash equals the hosts table. Each evidence file's Build section shows the same commands. observe.sh also records `gpu_arch` from cuobjdump in every record.
- **Observed run and launch attribution.** For eleven records (task3 solver-s16384, labels-long, transfers-long, gpu-example-combined; task4 solver/labels/transfers-all; task5 solver-inject-drop-node, labels-inject-flip-denial, transfers-inject-fabricate-admitted; task6 tests-gpu-on), I ran `check-record.sh --count-launches` on the stored sanitizer log. The counts were 15, 6000, 1000, 20, 90, 20, 30, 5000, 5000, 5000 and 4915, each equal to the record and the published tables. The sanitizer `Target application` line names the binary and arguments, and plain and observed stdout are `cmp`-identical. The corpus `--threads 4` supplementary log also shows 4915, and its stdout is `cmp`-identical to gpu-corpus-on.txt. The corpus plain-pass PID appears in 8 of 9 polls, as claimed.
- **Gate reruns.** I ran check-record.sh on 63 stored records, with these exit statuses: task2 a and a-long 0; b, c, c2, d, d2, e 1; f 2; g, g2, h 3 (exactly the controls table). task3: the s16384, long and combined runs 0; the three s16 runs 1 (presence). task4: 21 PASS, 3 FAIL (solver-empty, solver-invalid-flow, transfers-paired-admitted), as the file says. task5: 14 PASS, 1 FAIL; the forged `labels-forged` exits 1 with correctness `PASS 3, FAIL 3` and 0 launches. task6 tests-gpu-on 0. task7: nine attest-on runs 0 (300/100/100 launches), nine attest-off runs 1.
- **Inline records equal the stored records.** For seven runs across five files (paths, injection, corpus, parity, gate-controls), every line of the on-disk `record.txt` appears verbatim in the evidence file.
- **Source binding.** I compared the recorded `source_sha256` with the current files. Only the probe sources changed between tasks (task3's Transfers.bend `f7073cb4` is `git show d2a29e5:`; task4's Solver.bend `823ab04b` is `git show 5ca227c:`). For the corpus, only Tests.bend and FacadeTests.bend differ (`git show 98db68bf:Tests.bend` = recorded `a0248cdf`). This matches hosts "Source binding".
- **Typed comparison and original-graph verification.** scripts/gpu-validation/Solver.bend calls `Core.verify(graph, candidate, Scenario.core_stamp())` on the immutable input `graph` (lines 163-166, 696-703, 1044), never on Gpu.make_tree output. Core.bend:321-328 `verify` walks the graph's own flow, equality and call edges and seeds, independent of any work list. Equality of record is `Solver.result_equal`, `Dlm.answers_equal` and `Transfers.Decisions.equal`. Every file says no digest is equality evidence (paths Limits reconciled; injection Result).
- **Rules.** `git diff master --name-only` shows exactly four `.bend` files, all under scripts/gpu-validation/. No library, test, law or proof source changed. No count pin was touched. The 1428 count and 17 laws come from master (gpu-final-checks.txt). tests-native.txt, gpu-codegen.txt and gpu-example-*.txt are unchanged by the lane.
- **Scripts read in full.** observe.sh and check-record.sh, including every fail-closed branch: missing or duplicate field → 2; unbalanced markers → 2; mode without `--gpu on|size` → FAIL; nonzero exit or non-all-PASS → FAIL; log missing, hash mismatch, wrong target, truncated, uninstrumented, unfinished or wrong driver → FAIL; claimed count different from the recount → FAIL; 0 launches → FAIL; presence not recounted → FAIL; CVD mismatch → FAIL; record gate claim disagrees with derivation → 3. `--gpu on` cannot fall back silently (controls (d)/(d2): `cuInit failed`, exit 1), so a plain pass on the CPU cannot pair with a device observed pass under the mode rule. Unquoted `$RTS` and `$GV_SOURCES` are deliberate word-splits; paths with spaces would fail closed in `tok`. The remaining weaknesses are stated (forgery, binary not re-hashed) or are in I-2 and M-5.
- **Cross-document numbers agree.** Launch counts, the 20/18 parity cases and 24 runs (21/3), 11 injected faults, 12 controls (2 pass, 10 refused), 72 timing runs and 9+9 attestations, 4915, and the hosts-table hashes agree. The exceptions are I-1, I-3 and M-2. "5 launches per bang" is scoped to the probe (gpu-toolchain.txt Result: "not a constant of the runtime"); gpu-paths' "3 sweeps x 5" is scoped to the solver probe. The corpus does not use it as a constant (grid mapping "not established"). No "weak evidence" or "cause unknown" text remains; the verify-stage growth is "likely but unestablished".

Not done: no GPU run, no `bend Tests.bend` or `bend PROOF.bend` rerun (the recorded outputs in
gpu-final-checks.txt and the Task 9 review's reruns were read), no OpenSpec rerun.

## What remains open for the change after this branch

- Spec task 3.1: no split of the device call into memory movement, dispatch and kernel time (Nsight absent), and no throughput figure.
- Spec task 4.2: no enforced memory/device boundary and no access-denial test. Hostile device code and drivers are excluded as a limit of GT-1, which does not close the task.
- No quiet-host timing series; no second GPU or host (device identity is from GPU 0 only); no `--gpu <size>`, default-mode, multi-GPU or JavaScript-backend device runs for the path probes.
- No device memory checking (memcheck/racecheck on `bend_dev`); no fault injected inside the device, runtime or managed memory.
- Label and transfer checks independent of their producers (only Core.verify is a separate algorithm); collision-resistant or no digests in the probes; signed run records.
- No Lean `--verdict`.
- The harness hardening in I-2 and M-5 (code), applied together with a re-recorded harness hash.
- Archiving the change is a controller decision after landing.
