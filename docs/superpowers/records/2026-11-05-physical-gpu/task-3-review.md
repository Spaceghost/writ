# Task 3 review: the three native paths on the device

Reviewer scope: read-only except this file. Commit under review: d2a29e5 (base 16bf000). No GPU workload was rerun.

## Verdicts
1. Spec compliance: NEEDS_FIXES (one text fix: say in the evidence that the label and transfer probes have no verifier-denial control. Everything else in the brief is met.)
2. Evidence integrity: NEEDS_FIXES (one overstated coverage claim, the transfer digest, plus two missing Limits bullets. All fixes are text in gpu-paths.txt and the report. No rerun, no probe change.)

The central claim holds. Each path has its own single-bang binary with `bend_dev` in its cubin. Each has an observer-counted launch in a gate-PASS run. Every device result equals the in-process CPU reference field by field. The verifier or replay is run on the original inputs. I found no device-versus-CPU difference and no way the probes hand solver work lists to the verifier.

## Findings, by severity

1. MEDIUM (evidence integrity). The transfer digest does not cover every field, but three documents say it does.
   - Where it is claimed: verification/gpu-paths.txt:10 ("counts and an all-field digest at the larger sizes"), gpu-paths.txt:1571 ("a 32-bit digest over every field"), task-3-report.md:26 ("an all-field digest"), and the probe's own header, scripts/gpu-validation/Transfers.bend:33 ("a hash over every field in leaf order").
   - What the code hashes: `Transfers.hash` (Transfers.bend:287-297) hashes only the invocation of each ticket's Plan. It skips the plan stamp, sources, destination, code, kind and output_type. `Transfers.hash_origins` (Transfers.bend:281-283) binds `cs` (approved codes) and `pay` (payment rule) but never mixes them in.
   - What this affects: at SIZE 16384 and in the long run, the cross-process `--gpu off` stdout comparison covers counts, shape, denial codes, invocation, output schema, labels and kinds, and each origin's object/version/labels/kinds. It does not cover the fields listed above.
   - What it does not affect: the in-process comparison. `Transfers.Decisions.equal` (Transfers.bend:153-211, which uses `Transfer.Plan.equal`) compares every field, so the in-process correctness claim stands. The Solver and Labels digests do cover every field (Solver.bend:203-208, Labels.bend:128-135).
   - Fix: in gpu-paths.txt:10 and :1571 and in report line 26, say that the digest is all-field for the solver and labels. For transfers, list the fields it covers and the ones it omits. Do not edit Transfers.bend now, because that would change its sha256 and unbind every record. Record the stale header comment as a known defect. Then fix `Transfers.hash` to include every Plan field plus the origin codes and payment, together with the comment, in the next task that rebuilds the probe (Task 4 adds `parity` mode).

2. LOW-MEDIUM (spec compliance). The label and transfer probes have no control in which the verifier denies something, and the evidence never says so.
   - What exists: Solver.bend:310-312 has a real denied control. `Core.verify` must return `InvalidCandidate` for the unsolved seed assignment, and it passes at gpu-paths.txt:471 and :584.
   - What is missing: no probe shows `Dlm.verify_batch` or the `Transfer.admit` replay rejecting a wrong candidate. The batches do contain denied leaves, but those are denied policy outcomes, not a verifier refusing anything.
   - Why it matters: neither replay is shown here to reject anything, so an always-true replay would pass both probes.
   - What the file says: gpu-paths.txt:10 says only that "the solver adds a denied control". The absence is implied, not stated.
   - Fix: add a Limits bullet. It should say that the label and transfer probes have no verifier-denial control, that Dlm.verify_batch and the Transfer.admit replay were not shown to reject a wrong candidate in this task, and that Task 5's `inject` mode covers this (flipped denial, truncated tree, fabricated Admitted, wrong-plan ticket).

3. LOW (evidence integrity). The pre-commit capture is missing from the Limits list. It is stated in the header (gpu-paths.txt:7) and in report concern 4, but not under `## Limits` (gpu-paths.txt:1568-1576). Fix: add a bullet. It should say the probes were uncommitted at capture, so every record's lane_commit is 16bf000 marked "uncommitted: ?? ...", and the source_sha256 values bind the records to the committed files (I checked them, see below).

4. LOW (evidence integrity). The evidence never says which process each exit_status comes from.
   - In each pair, the plain record's `exit_status` is the probe's.
   - The observed record's `exit_status` is compute-sanitizer's (observe.sh:32, :293).
   - The observe.sh line `[exit status: N]` is the gate's verdict.
   - The probe's own status under the sanitizer is not recorded. It is shown only indirectly: sanitizer exit 0 with the default error-exitcode, and an observed stdout identical to the plain stdout, ending `result: all checks PASS`.
   - gpu-paths.txt:12 explains the observe.sh status but not the two record fields. Fix: add one clause to line 12 naming the source of each.

5. INFO. The two batch "independent checks" are the same computation as the CPU-reference comparison.
   - `Dlm.verify_batch` is literally `answers_equal(batch(queries, snapshot), candidate)` (Dlm.bend:371-372).
   - The transfer replay is `Transfer.admit` per leaf, which is exactly what `Transfer.batch` does (Transfer.bend:764-772).
   - So for labels and transfers, the "verifier" PASS line repeats the CPU-reference PASS line; it is not a separate algorithm.
   - gpu-paths.txt:1572 says this adequately ("the library's own evaluators"). Optionally add: "for the batches the replay is therefore not independent of the CPU-reference comparison". Only `Core.verify` is a genuinely different algorithm from the producer (a closure check against the original edges).

6. INFO. The solver's denied control is coarse. Every summary node is left unsolved, so many constraints fail at once. A single-field mutation (one bit dropped from one node) would show sensitivity. That is Task 5's `inject` scope, so no fix is needed here.

## 1. Spec compliance (details)

- One probe per path, one bang each.
  - Solver.bend:117-118 calls only `GPU.solve`, Labels.bend:92-93 only `GPU.label_batch`, Transfers.bend:113-114 only `GPU.transfer_batch`.
  - Each is a pure def reached after an `IO.now()` step (Solver.bend:126-129, Labels.bend:101-104, Transfers.bend:122-125).
  - BANGS is quoted at gpu-paths.txt:31, :116 and :201 (`#define BANGS   1`), and :286 (`#define BANGS   3` for gpu-example).
  - `bend_dev` in each `.gpu` is shown by `cuobjdump -sass ... | grep Function` at gpu-paths.txt:81-82, :166-167, :251-252 and :336-337 (`Function : window_dev` / `Function : bend_dev`). The cubin is `tail -c +9` of the `.gpu`, file type ELF CUDA, sm=89.
  - I reran this check on the on-disk `.gpu` files and got the same: sm=89, window_dev and bend_dev for all four. I also checked that each probe's emitted `.c` has `BANGS 1` and gpu-example.c has `BANGS 3`.
- Gate PASS with launch count, per path:
  - solver s16384: 15 launches, PASS (gpu-paths.txt:565, :572-574);
  - labels s16384: 5 launches, PASS (:806, :813-815); labels long: 6000 launches, PASS (:918, :925-927);
  - transfers s16384: 5 launches, PASS (:1158, :1165-1167); transfers long: 1000 launches, PASS (:1270, :1277-1279);
  - combined: 20 launches, PASS (:1382, :1389-1391).
  - The three SIZE 16 FAILs on compute_app_seen stay recorded as refused, per the controller ruling.
- What is compared at each size:
  - In process, every size, every round: the complete result type.
    - Solver: `Solver.result_equal` (Solver.bend:134-141) compares the outcome constructor, the Stamp (all three Bits64 via `Core.Stamp.equal`), every node State (types, secrecy, untrusted, effects via `Core.State.equal`, Core.bend:152-155), the sweep count, and the Error on failure. That is every field of SolveResult/Candidate/State/Stamp (Core.bend:12-63).
    - Labels: `Dlm.answers_equal` (Dlm.bend:354-363) compares shape and every leaf boolean. Answers has no other fields.
    - Transfers: `Transfers.Decisions.equal` (Transfers.bend:153-211) compares shape, Denial code (all ten constructors, none with fields), Ticket.plan via `Transfer.Plan.equal` (all 7 fields, Transfer.bend:249-254), and OutputPolicy (all 5 fields). Each origin rule is compared on all 6 fields, with Codes and PaymentRule recursively. This matches the type definitions at Transfer.bend:55-158.
  - Cross process at SIZE 16: the full last device result is printed and compared byte for byte with `--gpu off`. The dumps cover every field (Solver.bend:288-295, Labels.bend:209-231, Transfers.bend:409-419).
  - Cross process at SIZE 16384 and in the long runs: counts plus a 32-bit digest. The digest is all-field for the solver and labels, partial for transfers (finding 1).
  - Every probe also checks an expected outcome per leaf, so a CPU and device that are wrong in the same way still fail.
- Verifier on the original inputs.
  - Solver.bend:152-155 passes `Core.verify` the `graph` value built at Solver.bend:96-98 and :334, the same immutable Core.Graph handed to `GPU.solve`. It also passes `Scenario.core_stamp()` as the live stamp.
  - The probe never touches `Gpu.make_tree`, predecessor lists or work lists. `Core.verify` (Core.bend:321-329) destructures the original Graph's seeds and flow/equal/calls edges and checks the candidate against them.
  - Labels.bend:170 calls `Dlm.verify_batch(queries, snapshot, r)` on the original query tree and snapshot.
  - Transfers.bend:248-257 walks the original request tree, calling `Transfer.admit(p, c)` per original Plan and Context.
- Denied control: present for the solver. Absent for labels and transfers, and the absence is not stated (finding 2).
- Touch list.
  - `git diff --name-only 16bf000..d2a29e5` lists Labels.bend, Solver.bend and Transfers.bend under scripts/gpu-validation/, verification/gpu-paths.txt, and the record dir's activity.log and task-3-report.md. All are on the touch list.
  - `git diff --stat master -- '*.bend'` lists only scripts/gpu-validation/*.bend.
  - The probes import only Base, Core, Dlm, Transfer, GpuLibrary and examples/Scenario.bend. None imports a *Tests.bend or Test.bend file.
  - No count pin: no "782" anywhere in the new files. No manifest change.

## 2. Evidence integrity (details)

- Shape.
  - The header has the title, Bend version with driver hash, compiler, host with load range, GPU, date, environment, and the `Execution:` line (gpu-paths.txt:1-8).
  - `## Build` gives every `$ command` with `[exit status; stderr; wall]`, BANGS, nm -D, ldd, the cubin check and sha256s.
  - `## Run` has `uptime` before every run, the full inline record pair for every run, the observe.sh exit (= gate), plain stdout, plain-vs-observed cmp, launch recount, kernel histogram and ERROR SUMMARY, then nine `--gpu off` runs with sha256 and cmp.
  - Then `## Result` and `## Limits`.
- Hashes.
  - I extracted all 54 distinct `sha256  path` lines in gpu-paths.txt and ran `sha256sum -c` from the worktree root: all 54 are OK. They cover the three probes, every library source, every `.c`, binary, `.gpu` and `.cubin`.
  - observe.sh is efd08afb...a8ac and check-record.sh is 7d4df17b...88ab. Both are unchanged since 50ed67c.
- Records.
  - Each of the nine on-disk `record.txt` files appears verbatim inline in gpu-paths.txt.
  - I reran `check-record.sh` on each: exit 0 for the six PASS runs, exit 1 for the three s16 runs, matching the evidence. A rerun re-hashes the sanitizer, apps, pmon and util logs.
  - On disk, plain.stdout equals observed.stdout equals off.stdout in every run directory.
  - Sanitizer logs on disk: launch counts of 15, 15, 5, 5, 6000, 5, 5, 1000 and 20 `Kernel: bend_dev` blocks, each with the matching Target application line.
- Exit statuses: these are present for the probe (plain record) and the sanitizer (observed record), but the evidence does not say which is which (finding 4).
- Performance: "this is not a performance measurement" is stated (gpu-paths.txt:1565). The header says wall times are indicative only (line 4).
- Limits (gpu-paths.txt:1568-1576):
  - stated: the logical, same-process nature of the checks, which use the library's own evaluators (:1572); sparse pmon (:1573); the display sharing the GPU (:1569); and what was not exercised (:1570, :1574-1575);
  - missing: the pre-commit capture (finding 3) and the missing label/transfer denial control (finding 2).
- No overclaim: the evidence and report say nothing about adversarial inputs (both disclaim them), device memory checking (stated as not run) or a protection boundary (stated as "not a memory-protection boundary").
- Claim scope.
  - The "complete three-path" sentence (gpu-paths.txt:1564) is scoped to the configuration at :1557: UUID, driver, bend, NVRTC/CUDA, and the .gpu hashes in ## Build.
  - It concerns device results and their parity and verification only. It is not a library-correctness claim, and the Execution line keeps the corpus and tests explicitly out.
  - The combined-run split is labelled an inference (controller ruling).

## What I ran
- Read the brief, the report, the plan (Global Constraints and Task 3, plus Task 5 for scope), the Task 2 review, observe.sh and check-record.sh (header and relevant lines), all three probes in full, and the relevant parts of Core.bend, Dlm.bend, Transfer.bend, GpuLibrary.bend, DlmGpu.bend and TransferGpu.bend. Read gpu-paths.txt in full for structure, Build, one run section in full, the combined section, the off comparisons, Result and Limits.
- `sha256sum -c` on all 54 hash lines in gpu-paths.txt; sha256sum of observe.sh and check-record.sh; `git diff --stat 50ed67c..d2a29e5` for the scripts.
- `cuobjdump -elf` and `-sass` on the cubins I extracted from the four on-disk `.gpu` files (scratchpad copies); grep for BANGS in the emitted `.c` files.
- `check-record.sh` on the nine stored records (exit codes); a verbatim-inclusion check of each record in gpu-paths.txt; cmp of the plain, observed and off stdouts on disk; launch and Target-line greps on the nine sanitizer logs.
- `git diff --name-only master..HEAD`, `git diff --stat master -- '*.bend'`, and an import/count-pin grep.
- Did not run observe.sh, any probe, any GPU workload, `bend Tests.bend` or `bend PROOF.bend`.
