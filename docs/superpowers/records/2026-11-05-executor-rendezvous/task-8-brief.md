### Task 8: Full verification and host preconditions (task 2.2)

Run, with outputs going into `verification/executor-rendezvous.txt` and the records only, never into the shared captures:
- `bend Tests.bend -o ../writ-build/executor-rendezvous/tests.js && node ../writ-build/executor-rendezvous/tests.js`;
- `bend Tests.bend -o ../writ-build/executor-rendezvous/tests-native && ../writ-build/executor-rendezvous/tests-native +RTS --threads 4 --gpu off`. This is a CPU run, not a GPU test, and the record says so. Both outputs must be byte-identical (`cmp`), with the same PASS count;
- `bend PROOF.bend` (`ALL PROOFS CHECK` and the law count);
- one attempt at `bend PROOF.bend --verdict`. If the Lean kernel is missing, record the exact error line as NOT VERIFIED;
- `~/.bun/bin/bunx @fission-ai/openspec@1.16.0 validate --all --strict --no-interactive`.

Re-run the full mutation sweep on the final tree and record the totals. Add a "Remaining host preconditions" section to `docs/EXECUTOR-RENDEZVOUS.md`:
- transport identity for providers and approvers;
- signature verification for off-host offers and approvals;
- durable, serialized rendezvous state;
- per-use projection rebuilding;
- an adapter that admits workers only from `provider_registry` after a recorded dispatch;
- enablement and capability negotiation;
- trial metering (`add-metered-sample-execution`);
- quote settlement;
- the count re-pin by the controller.

Run `git diff --stat master` and confirm the touch list held. Check box 2.2 and update the tasks.md preface line.

Acceptance:
- both backends pass with the same total, recorded but not pinned;
- `ALL PROOFS CHECK`;
- OpenSpec strict passes;
- every mutant is killed or carries an accepted equivalence argument;
- all seven boxes are checked, each citing its evidence;
- no count pin or shared capture changed, and the change is not archived.
