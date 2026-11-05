# Task 5 report: injected faults, and correctness before performance

Status: DONE_WITH_CONCERNS. 11 faults were injected and all 11 were denied in every round. The forged fast run is recorded as FAILED. The concerns are a digest collision found by the forged run, and the commit path having no Decision input. Both are listed at the end.

Files changed (touch list only):
- `scripts/gpu-validation/Solver.bend` (sha256 01972f7ec80cdb26f4b1758f965483989d1a95cdc0183a6d490ceaf920ab8669): mode `inject CASE [ROUNDS]`.
- `scripts/gpu-validation/Labels.bend` (sha256 4c5c97b7fbeb6d506d11249422395604fb7b758740425dbd927b1790e3db08ce): modes `inject CASE [ROUNDS]` and `bench-forged SIZE REPS`.
- `scripts/gpu-validation/Transfers.bend` (sha256 6b45e9bfcef902eb577ba02367b35196edd114f1954e743104a1f00dda6ecbaa): mode `inject CASE [ROUNDS]`, the commit path, and 20 digest controls. It now also imports Dlm, Negotiation, Ledger, Frontend, Backplane and DataOS.
- new `verification/gpu-injection.txt`: every command, its output and status, the 15 record pairs inline, and the Result, no-hardware-coverage and Limits sections.

No other `.bend` file changed. observe.sh and check-record.sh are unchanged. There is no manifest change and no push. Builds are in `../writ-build/physical-gpu/task5/`, a new directory, with BANGS 1 per binary. Runs are in `../writ-build/physical-gpu/runs/task5/`. Run and parity modes are unchanged.

## How injection works
The probe takes the device-returned result, corrupts it, and calls the library check on the original inputs. No library module is touched. Each case prints:
- the device result, the CPU reference and the corrupted value, every field;
- a `control` line: the unmutated device result equals the CPU reference and passes the check. So the check is not an always-refuse, and the denial is the injection's;
- the library function's quoted return value on the corrupted value, plus the first field where it differs from the replay;
- `inject` PASS only if every round is refused;
- the effect check where an effect path exists.

## Per injected case (all gate PASS, 5000 bend_dev launches each, `--gpu off` stdout identical)
| Case | Corrupted | Denied by, quoted | Effect check |
|---|---|---|---|
| solver drop-node | node 2 removed (3 -> 2 nodes), wide-dimensions graph | Core.verify(original graph, ..., Scenario stamp) -> Denied{InvalidCandidate}; seeds and calls clauses False (500/500) | Core.authorize_sink -> Denied{InvalidCandidate} (unmutated: Approved) |
| solver erase-source | node 0 secrecy 2147483648/2147483649 -> 0/0 | Core.verify -> Denied{InvalidCandidate}; only the seeds clause False | Core.authorize_sink -> Denied{InvalidCandidate} (unmutated: Denied{FlowDenied}; the sink gate alone, as an unused diagnostic, would have Approved) |
| solver clear-bit63 | node 2 effects hi word 2147483649 -> 1 | Core.verify -> Denied{InvalidCandidate}; only the calls clause False | Core.authorize_sink -> Denied{InvalidCandidate} (unmutated: Denied{EffectDenied}; the sink gate alone would have Approved) |
| solver stale-stamp | candidate authority epoch 3 -> 2 | Core.verify -> Denied{StaleSnapshot}; only the live-stamp clause False | Core.authorize_sink -> Denied{StaleSnapshot} (unmutated: Approved) |
| labels flip-denial | root.left.right False -> True (allow-deny queries) | Dlm.verify_batch -> False; allowed at root.left.right (mutated True, replay False) (1000/1000) | none exists: a Bool result, and no entry point takes answers as authority |
| labels truncate | tree -> its left half (4 -> 2 leaves) | Dlm.verify_batch -> False; shape at root.left | as above |
| labels swap-shape | ((a b)(c d)) -> (a (b (c d))), same leaf order | Dlm.verify_batch -> False; shape at root.left (both leaf sequences TFTT) | as above |
| transfers fabricate-admitted | missing-read leaf Denied Read -> fabricated Admitted ticket 2012 | Transfer.admit(plan 2012, its Context) -> Denied Read; outcome at root.right (1000/1000) | none exists: a Decision is a proposal |
| transfers wrong-plan | ticket for 2001 given plan 2002 | Transfer.admit -> Admitted plan 2001; ticket plan invocation (presented 2002, replay 2001) | as above |
| transfers stale-context | admitted tree presented against the Context for 2041 at live 1.2.4 | Transfer.admit -> Denied Stale; outcome at root.left | as above |
| transfers forged-commit | Scenario plan 99 without its read grant: Denied Read -> fabricated Admitted | Transfer.admit(plan 99, without_read) -> Denied Read; DataOS.commit_from_capability -> Rejected{session, ledger} | the refused commit returns the exact Running session and held ledger, with no WriteIntent; its twin with the read grant live -> Committed (reader balance 45) |

Injected 11, denied 11, not denied 0. check-record.sh returns 0 on all 11 inject records.

## Wrong-but-faster control
`labels bench-forged 16384 200` runs run mode's checks with a constant allow-all tree in place of the device call (no bang). It was run between two honest `labels run 16384 200` runs:
- honest: 3208 ms and 3211 ms, 1000 launches, gate PASS;
- forged: 1164 ms, 0 launches, correctness PASS 3 FAIL 3, probe exit 1, gate FAIL; check-record.sh returns 1.

The forged run's wall time is recorded only as that of a failed run, marked not accepted. Task 7 must list it as rejected. Task 7's `bench` measurement does not exist yet, so this run was measured by observe.sh's plain-pass wall_ms and the same gate.

## Digest sensitivity control
- Every transfers inject run has 20 `digest control` lines, all PASS. Each one-field change moves Transfers.hash away from 2938088844. The fields are all 9 Plan fields; schema, secrecy, untrusted and kinds; the origin count; and origin object, secrecy, untrusted, kinds, approved codes and payment. A field-by-field rebuild of the ticket hashes equal.
- `transfers run 16384` (5 launches, gate PASS) runs the all-field digest on device output. Device and CPU both give 1820298339, and `--gpu off` is identical.

## No hardware coverage
Only labels-forged had 0 launches, by construction. Every injected case had 5000 launches. The checks applied to the injected values, the commit path and the digest controls are CPU code, as designed.

## Not exercised
- Faults inside the device, the runtime or managed memory, and any search over corruptions beyond these 11.
- bench-forged for the solver and transfers.
- Hidden-device, default-mode and `--gpu <size>` runs of these modes; device memory checking; Nsight.
- `bend Tests.bend` and `bend PROOF.bend`: no library, law or proof source changed.

## Concerns
1. Digest collision (finding). In the forged run, "device answer digest equals the CPU reference digest" PASSED 200 of 200. The allow-all tree and the correct 16384-leaf tree both have Labels.hash 2954464355. The tree, expected-pattern and Dlm.verify_batch lines still failed, so the run failed. The collision is structural: the reviewer reproduced it offline at every power-of-two size from 256 leaves up. So no digest in these probes is equality evidence. The comparison of record is the typed in-process comparison (Solver.result_equal, Dlm.answers_equal, Transfers.Decisions.equal). Task 3's 16384 cross-process label comparison would still have differed in the printed counts. Solver.hash and Transfers.hash have the same construction. Changing the digest would change the probes' hashes and unbind the Task 3 and Task 4 records, so I left it as a finding. A stronger digest, or a per-leaf dump, could come in a later rebuild if the controller wants it.
2. DataOS.commit_from_capability takes no Decision. A forged decision cannot be presented to it. The commit case therefore shows the commit refusing the forged request's plan against its authoritative Context, with no session or ledger change. It does not show a decision value being refused at commit. I read this as the intended design: there are no caller-controlled authority facts.
3. The label and transfer refusals come from the same evaluators as the CPU reference. They show these paths are neither always-accept nor always-refuse, but they are not independent algorithms. Core.verify is a separate algorithm.
4. Core.sink_gate, an exported helper, is called once per widening case, only to print that the corruption would have widened authority without verification. Its value is never used. If the reviewer considers even a printed call to it out of bounds, it can be removed.
5. Pre-commit capture: lane_commit is 843570f marked uncommitted. The source hashes equal the committed files.

## Fix round 1
Review: task-5-review.md. Spec compliance was approved. These are text changes only: no rerun, no probe change, and the probe hashes are unchanged (01972f7e, 4c5c97b7, 6b45e9bf).
1. Digest finding (review finding 1): gpu-injection.txt and concern 1 above now say the collision is structural (equal at every power-of-two size from 256 leaves up, reproduced by the reviewer). No digest in these probes is equality evidence. The typed in-process comparisons (Solver.result_equal, Dlm.answers_equal, Transfers.Decisions.equal) are the comparison of record. A new Limits bullet says the Task 3 cross-process comparisons at 16384 and in the long runs (gpu-paths.txt, Limits near line 1571) therefore show equal counts only. gpu-paths.txt is not edited; Task 9 reconciles the records.
2. Calibration runs (review finding 2): the Harness section lists the eight unrecorded plain `--gpu on` calibration runs (activity.log 04:41:26Z) with their arguments, exit statuses and wall times, plus the development interpreter runs. All exited 0 except the forged control (exit 1, as expected). Their outputs were not kept, and they are not evidence. A Limits bullet repeats this.
3. Solver table (review finding 3): the 500-of-500 count is now attributed to Core.verify, and each clause breakdown is labelled "last solve only".
4. Closure (review finding 4): `## Result` states that this task provides the label and transfer verifier-denial controls that Task 3 and Task 4 lacked.
The printed Core.sink_gate diagnostic stays (the reviewer ruled it in bounds).
