# Task 4 report: differential parity cases

Status: DONE_WITH_CONCERNS. 20 cases ran. 18 are device-validated. The solver's empty-graph and invalid-flow cases have CPU coverage only, which is expected because neither one sweeps. No difference was found between the device and the CPU. The concerns are listed at the end.

Files changed (touch list only):
- `scripts/gpu-validation/Solver.bend` (sha256 823ab04b7cfb66b6546b93c695c980009bc16840b62869e21a91d9c39d2afd1e)
- `scripts/gpu-validation/Labels.bend` (sha256 4bb420f15e931b642c35045c1f783f6d11ff07c2bf736ac1a4a04fe65a0a6455)
- `scripts/gpu-validation/Transfers.bend` (sha256 9f15ea73281fc9040ed68a388a35397a78da15babcda3f17271135adfc6c468d)
- new `verification/gpu-parity.txt`: every command, its output and status, the 24 record pairs inline, and the Result and Limits sections.

No other `.bend` file changed. observe.sh and check-record.sh are unchanged. There is no manifest change and no push. Builds are in `../writ-build/physical-gpu/task4/`, a new directory so the Task 3 binaries stay as recorded. Runs are in `../writ-build/physical-gpu/runs/task4/`.

## What changed in the probes
- New mode `parity CASE [ROUNDS]`. CASE is `all` or one case name. ROUNDS repeats the device call on the same case, each repeat behind its own IO.now().
- Per case, each probe runs the device call, then an IO step, then the CPU reference on the same immutable inputs (Core.solve_cpu, Dlm.batch or Transfer.batch, without `!`). It prints these lines:
  - `PASS parity CASE` or `FAIL parity CASE: FIELD (device X, CPU Y)`. This line needs the typed equality and a field-by-field walk to agree. For the solver, the walk covers the outcome, the failure class, the stamp epochs (lo and hi), the node count, and per node the type domain and the lo and hi words of secrecy, untrusted and effects, then the sweeps. For labels it covers the shape and every leaf. For transfers it covers the shape, the denial reason, every Plan field, and every OutputPolicy field, including each retained origin's codes and payment rule.
  - an `expected` line, against the result stated with the case;
  - a `verify` line on the original inputs. For the solver this is Core.verify on the original graph, plus a `stale` line in which Core.verify must refuse each candidate with StaleSnapshot under authority epoch 4. For labels it is Dlm.verify_batch, and for transfers Transfer.admit per original plan.
  - a comparator control per probe: a one-field change must be named exactly and refused by the typed equality.
- Every case prints the device result, the CPU result and the expected result in full, so the `--gpu off` stdout diff is all-field.
- Run mode: Solver.device takes the round budget (run mode passes 0n). Transfers.hash now covers every Plan field and the origin codes and payment rules (Task 3 review finding 1), and its comment says so. The headers name Task 4.

## Cases, launches and gate (single-case runs, `--gpu on`)
| Probe/case | Exercises | bend_dev launches | Gate | parity on/off |
|---|---|---|---|---|
| solver/bit31-secrecy | secrecy bit 31 along flow, 3 sweeps | 15 | PASS | PASS/PASS |
| solver/bit32-untrusted | untrusted bit 32 along flow | 15 | PASS | PASS/PASS |
| solver/bit63-effects | effect bit 63 along calls | 15 | PASS | PASS/PASS |
| solver/wide-dimensions | bits 31, 32, 63 in all dimensions; flow vs calls separation | 10 | PASS | PASS/PASS |
| solver/cycle | 3-node flow+calls cycle | 15 | PASS | PASS/PASS |
| solver/empty | empty graph, 0 sweeps | 0 | FAIL (0 launches) | PASS/PASS: no device coverage |
| solver/type-conflict | TypeConflict after 1 sweep | 5 | PASS | PASS/PASS |
| solver/invalid-flow | InvalidGraph (edge to node 5), no sweep | 0 | FAIL (0 launches) | PASS/PASS: no device coverage |
| solver/budget-1 | IterationLimit with budget 1 | 5 | PASS | PASS/PASS |
| solver/budget-2 | the permitted twin, Solved in 2 | 10 | PASS | PASS/PASS |
| labels/allow-deny | 3 allow, 1 deny (adds readers) | 5 | PASS | PASS/PASS |
| labels/stale-epoch | epoch 3 allow; epochs 2 and 4 deny | 5 | PASS | PASS/PASS |
| labels/missing-principal | Named{2}, Named{5}, Unsupported deny; control allow | 5 | PASS | PASS/PASS |
| labels/empty-batch | NoQueries -> NoAnswers | 5 | PASS | PASS/PASS |
| transfers/paired-admitted | two admitted, origin retained | 5 | FAIL (presence) | PASS/PASS |
| transfers/paired-admitted, ROUNDS 400 | the same case repeated | 2000 | PASS | PASS/PASS |
| transfers/missing-read | admitted twin + Denied Read | 5 | PASS | PASS/PASS |
| transfers/missing-write | admitted twin + Denied Write | 5 | PASS | PASS/PASS |
| transfers/missing-payment | paid admitted (Charge retained) + Denied Payment | 5 | PASS | PASS/PASS |
| transfers/stale-context | live 1.2.3 admitted; 1.2.4, 1.3.3, 2.2.3 Denied Stale | 5 | PASS | PASS/PASS |
| transfers/empty-batch | EmptyBatch -> EmptyDecisions | 5 | PASS | PASS/PASS |

The `parity all` runs had 90 (solver), 20 (labels) and 30 (transfers) launches. Each equals the sum of the single-case counts, and all three are gate PASS. Re-check: check-record.sh returns 0 for 21 pairs and 1 for the 3 FAIL pairs.

## Comparison result
- In all 24 runs, the `--gpu off` stdout is byte-identical to both the plain-pass and the observed-pass `--gpu on` stdout. The stdout includes every field of every case.
- No FAIL line appears in any stdout. Every expected, verify, stale and comparator-control line passed.
- No device-versus-CPU difference was found, so there is nothing to record verbatim.

## Not exercised
- Delegation edges in the label snapshot; multi-source, Copy and Transform transfers; the InvalidPolicy, Source, Schema, Operation, Origin and Destination denials; large or adversarial inputs.
- Hidden-device (invalid CUDA_VISIBLE_DEVICES), default-mode and `--gpu <size>` runs of parity mode; device memory checking; Nsight.
- Verifier refusal of a wrong label or transfer candidate (Task 5).
- The four-node oracle (Task 6). It is finite coverage of its documented cases, as are these 20.
- `bend Tests.bend` and `bend PROOF.bend`: no library, law or proof source changed.

## Concerns
1. transfers/paired-admitted at ROUNDS 1 was refused by the gate on presence (pid never listed in 2 polls, 0.63 s plain pass, 5 launches observed). It is validated only through the ROUNDS 400 rerun, as the ruling allows. The other single-round runs of 0.57 to 1.16 s were each seen once, so presence at this scale is luck of the 200 ms poll. That is the same gate property Task 3 found.
2. The label and transfer `verify` lines run the same evaluator as the CPU reference, so they are not independent. Only Core.verify is a separate algorithm.
3. Pre-commit capture: every lane_commit is b0d40dd marked uncommitted for the three probes. The records are bound by source_sha256, which equals the committed files.
4. The empty label and transfer batches still dispatch the bang (5 launches each). Only the solver's empty graph skips the device. This is an observation, not a defect.
