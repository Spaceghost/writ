# Task 5 review: injected faults and the wrong-but-faster control

Reviewer scope: read-only except this file. Commit under review: e337527 (base 843570f). No GPU workload was rerun.

## Verdicts
1. Spec compliance: APPROVED. All 11 faults are injected in the probe, between the device call and the check. Each is refused in every round by the named library path, and its reason is quoted. Every case has an unmutated control, and every case with an effect path checks that no effect follows. The forged fast run is real and the gate records it as FAIL. No `.bend` outside `scripts/gpu-validation/` changed, and there is no count pin.
2. Evidence integrity and reasoning: NEEDS_FIXES. All fixes are text, with no rerun and no probe change. The digest-collision finding is present, but it is hedged ("weak evidence", "at this size", "for this kind of difference"). It also does not reach the Task 3 cross-process comparisons that rest on the same digests. The unrecorded calibration runs are not in the evidence.

Ruling on `Core.sink_gate` (as the controller asked): it is in bounds, so keep it. The probe calls a pure function, prints the value labelled "unverified, printed and never used", and never feeds it to a decision, a capability or an effect. The AGENTS.md concern is alternate release routes, and this is not one, because nothing here can release anything. The diagnostic also earns its place: it is the only line showing that erase-source and clear-bit63 would widen authority if verification were skipped. Removing it would weaken the evidence without making anything safer.

## Findings, by severity

1. MEDIUM (evidence integrity). The digest-collision finding is hedged and too narrow, and the comparison of record is not named.
   - Hedges: verification/gpu-injection.txt:2491 says "A 32-bit digest is weak evidence of equality at large sizes". The controller ruling is that no digest is equality evidence. gpu-injection.txt:2476 says the contributions "cancel mod 2^32 at this size" and that the digest "is not evidence of equality at 16384 leaves for this kind of difference". task-5-report.md:59 says "not equality evidence at this size".
   - The collision is structural, not tied to one size. I rebuilt Labels.hash offline from Labels.bend:136-143 (scratch Python, word 2 for allowed and 1 for denied). The alternating correct tree and the allow-all tree hash equal at every power-of-two size from 256 leaves to 1048576. At 16384 both give 2954464355, which reproduces the recorded value. From 2 to 128 leaves they differ.
   - Reach not stated: verification/gpu-paths.txt:1571 records that the Task 3 cross-process `--gpu off` comparisons at SIZE 16384 and in the long runs compare "counts and a 32-bit digest". After this finding, those comparisons are evidence of equal counts only, for all three probes. gpu-injection.txt:2476 argues only that the counts would have caught this one case. A difference that keeps the counts the same (for example, two leaves swapped) would rest on the digest alone.
   - Fix (text):
     - At :2491, replace the sentence with: "No 32-bit digest in these probes is equality evidence. The comparison of record is the typed in-process comparison: Solver.result_equal, Dlm.answers_equal and Transfers.Decisions.equal, plus the per-leaf expected outcomes."
     - At :2476, replace "at this size" and "for this kind of difference" with the structural statement: equal for every power-of-two size from 256 leaves up, reproduced offline by the reviewer.
     - Add one Limits bullet: the Task 3 cross-process comparisons at 16384 and in the long runs (gpu-paths.txt:1571) are, after this finding, evidence of equal counts, not of equal results.
     - Make the same wording change in task-5-report.md:59.

2. LOW (evidence integrity). Unrecorded calibration runs are missing from the evidence.
   - activity.log line 128 (2026-11-05T04:41:26Z) says "calibrating ROUNDS with unrecorded plain runs".
   - Neither gpu-injection.txt nor the report mentions them. The plan requires failed and incomplete outcomes to be preserved, and a difference must never be re-run until it disappears.
   - Fix: add a line to `## Run` or `## Limits`. Give the number of calibration runs and their arguments. Say whether any printed a FAIL line or exited nonzero. Say that their outputs were not kept and that they are not evidence. If their outcomes are unknown, say so.

3. LOW (clarity). The solver clause breakdown comes from the last solve only, but the Result table reads as if it covered every round.
   - Where: gpu-injection.txt:2450-2453 print "clauses: seeds False only (500 of 500)". In Solver.bend, `Solver.inject_tail` prints `Solver.clauses` for the last device solve only. The 500 of 500 count is `Core.verify` returning the case's reason (`Solver.refusals`).
   - The breakdown itself is correct. The clause lines are at :396, :540, :685 and :830:
     - drop-node: seeds and calls fail;
     - erase-source: seeds only;
     - clear-bit63: calls only;
     - stale-stamp: live stamps only.
   - Fix: write "Core.verify -> Denied{...} (500 of 500); clauses (last solve): ...".

4. LOW (traceability). The evidence does not say that it closes the Task 3 gap.
   - task-3-review.md finding 2 asked for a label and transfer verifier-denial control. These inject runs provide it: Dlm.verify_batch refuses 1000 of 1000 in three cases, and the Transfer.admit replay refuses 1000 of 1000 in four. gpu-injection.txt never names that limit as closed.
   - Fix: add one sentence to `## Result`: "This provides the label and transfer verifier-denial controls that gpu-paths.txt and gpu-parity.txt lacked (Task 3 review finding 2)."

5. INFO. "Not accepted" appears only in the evidence prose, not in the record.
   - The forged record (runs/task5/labels-forged/record.txt) carries `wall_ms: 1164`, `correctness: PASS 3, FAIL 3` and `gate: FAIL (...)`. It has no "not accepted" field. The marking is in the gpu-injection.txt table and text.
   - observe.sh is frozen by the plan, so this is acceptable here. Task 7's bench record should carry the marking as a field.

6. INFO. The stale-context wording is inverted relative to the brief.
   - The brief says "present it against a stale Context". The probe keeps the device decision (made at 1.2.3) and presents it against an authoritative Context that has advanced to 1.2.4. That is the correct security framing, because the device's view is the stale one, and the evidence states exactly what was done. No change is needed.

## 1. Spec compliance (details)

- Injection site.
  - Every mutation is a probe-side function applied to the device result after `device_rounds` returns and the `IO.now()` step: `Solver.mutate`, `Labels.mutate`, `Transfers.mutate`, `fabricate_right` and `replan_left`.
  - `git diff --stat master -- '*.bend'` lists only scripts/gpu-validation/*.bend.
  - `git diff --name-only 843570f..e337527` lists the three probes, verification/gpu-injection.txt, activity.log and task-5-report.md, all on the touch list.
  - observe.sh and check-record.sh are unchanged (efd08afb..., 7d4df17b...).
- Exactly what was corrupted (gpu-injection.txt:19-37, and probe descriptions):
  - drop-node: the last node is removed, 3 nodes -> 2.
  - erase-source: node 0 secrecy 2147483648/2147483649 -> 0/0.
  - clear-bit63: node 2 effects hi word AND 0x7fffffff, 2147483649 -> 1.
  - stale-stamp: the authority epoch lo word minus 1, 3 -> 2.
  - flip-denial: root.left.right False -> True.
  - truncate: root -> root.left.
  - swap-shape: the tree is reshaped with the leaf sequence kept, TFTT on both sides.
  - fabricate-admitted: root.right is replaced by an Admitted ticket for 2012.
  - wrong-plan: the root.left ticket plan 2001 -> 2002, output policy kept.
  - stale-context: the decisions are unchanged, and the authority Context is advanced to 1.2.4.
  - forged-commit: root.right is replaced by an Admitted ticket for plan 99.
- Independent paths on the original inputs.
  - Solver: `Solver.verify_result` calls `Core.verify(graph, candidate, Scenario.core_stamp())` with the same immutable wide-dimensions Core.Graph passed to `GPU.solve`. There is no make_tree and no work list.
  - Labels: `Dlm.verify_batch(queries, snapshot, mutated)` runs on the original query tree.
  - Transfers: `Transfers.replay(authority, mutated)` calls `Transfer.admit(p, c)` per original plan and Context.
  - Quoted results in the stdout on disk:
    - `Denied{InvalidCandidate}` for drop-node, erase-source and clear-bit63, and `Denied{StaleSnapshot}` for stale-stamp;
    - `-> False` for the three label cases;
    - `Transfers.replay ... -> False` for the four transfer cases, with the replay trees (A2011 D:Read), (A2001 A2002), (D:Stale A2042) and (A99 D:Read).
- Every round: k = n in each inject line. That is 500 of 500 for the solver and 1000 of 1000 for labels and transfers, read in each run's plain.stdout.
- Controls: every case has an unmutated control. It checks that the device result equals the CPU reference and that the check accepts it, so no path is an always-refuse.
- No effect.
  - Solver: `Core.authorize_sink` refuses with the case's reason in 500 of 500 rounds. Its unmutated values are Approved, FlowDenied, EffectDenied and Approved for the four cases.
  - forged-commit: `DataOS.commit_from_capability -> Rejected{session, ledger} (no WriteIntent)`. The exact Running session and held ledger come back, compared field by field. The twin with the read grant live is `Committed`, reader balance 45.
  - The commit path in detail:
    - I checked that `Transfers.negotiation_without_read` differs from `Scenario.negotiation(now())` only in the transfer Context (Scenario.bend:142 and :202-210), and that the binding replicates `Scenario.backplane` (:226-229). So the differential isolates the withdrawn read grant.
    - Admission happens in `Frontend.checked_plan`, as the comment at Frontend.bend:287 says.
    - The probe-fabricated `Rejected` branch in `Transfers.commit_opened` is guarded by the "descriptor opened" control.
  - Labels and transfers (non-commit): no entry point takes an answer tree or a Decision as authority, and the evidence says so.
- Commit path re-running admission: this is the correct demonstration, per the controller ruling. Not flagged.
- Forged fast run. `labels bench-forged 16384 200` gives:
  - 0 launches (recount 0);
  - plain wall_ms 1164, against 3208 and 3211 for the honest runs either side (1000 launches each);
  - three FAIL lines (tree 0/200, pattern 0/200, verify_batch 0/200), probe exit 1, and `gate: FAIL`. The gate refuses it on exit status and correctness, not only on the launch count. check-record.sh returns 1.
  - The evidence table marks it "FAILED, wall time not accepted" (see finding 5).
- Label and transfer denial controls now exist (see finding 4 for the missing pointer).
- The all-field transfer digest is exercised.
  - `transfers run 16384` (5 launches, gate PASS) prints hash 1820298339 for both the device and the CPU, and the `--gpu off` stdout is identical.
  - All 20 single-field digest controls, plus the base rebuild, PASS in all four transfer inject runs (21 `PASS digest control` lines each).
- Touch list and count pin: no "782" was added, and the imports are library modules only, with no *Tests.bend or Test.bend.

## 2. Evidence integrity and reasoning (details)

- Digest collision: stated as a finding (gpu-injection.txt:2476), with the in-process typed comparison and the expected-pattern check as what refused the forged tree. It needs the wording fixes in finding 1.
- Same-evaluator limit: stated at :2486. Dlm.verify_batch and the transfer replay are the producer's evaluators, and Core.verify is named as the separate algorithm.
- Per-check breakdown for the solver corruptions: present and correct (finding 3 is wording only).
- Pre-commit capture: stated in the header (:7) and in Limits (:2493). Every source_sha256 in the records equals the committed files.
- No overreach.
  - "They are not a protection boundary" (:2485).
  - "not a search over corruptions" (:2484).
  - Wall times are "indicative only" (:4, :2483).
  - Nothing claims adversarial completeness.
- Spot checks: I checked all 15 run directories under ../writ-build/physical-gpu/runs/task5/, more than the six required:
  - `check-record.sh record.txt`: exit 0 for 14 and exit 1 for labels-forged, matching the evidence and activity.log.
  - `check-record.sh --count-launches observed.sanitizer.log BIN`: 5000 for each of the 11 inject runs, 5 for transfers-run-16384, 1000 and 1000 for the honest runs, and 0 for forged. Each equals the record's `bend_dev_launches`.
  - Stdout: plain equals observed equals off by sha256 for the 12 runs with a twin. The honest and forged label runs have no off twin, as stated. Each equals the record's `stdout_sha256`. No FAIL line appears except the forged run's three.
  - Every on-disk record.txt appears verbatim inline in gpu-injection.txt (15 of 15).
  - `sha256sum -c` passes on all 67 distinct `hash  path` lines in gpu-injection.txt. The binary and `.gpu` hashes on disk equal the record fields and the Result line. All 16 source_sha256 entries in the transfers record are OK against the tree.
  - The emitted .c files each have `BANGS 1`.

## What I ran
- Read:
  - the brief, the report, the plan's Global Constraints, and the Task 3 and Task 4 reviews;
  - the three probe diffs in full;
  - gpu-injection.txt: the header, Build intro, the Result and Limits sections, and the inline record and clause lines;
  - Core.verify, sink_gate and authorize_sink (Core.bend:318-359), DataOS.commit_from_capability and commit_resolved, and Backplane.accepted, session and ledger;
  - the Scenario transfer, negotiation and backplane fixtures, and the Transfers replay helpers.
- Ran: check-record.sh (default and `--count-launches`) on all 15 stored records, sha256sum (`-c` on the evidence hash lines, the probes, the harness, the binaries and the `.gpu` files), the stdout hash comparisons, a verbatim-inclusion check, the git diff name and stat checks, greps, and an offline Python model of Labels.hash.
- Did not run: any probe, observe.sh, any GPU workload, `bend Tests.bend` or `bend PROOF.bend`.
