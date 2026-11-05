### Task 5: Injected faults, and correctness before performance (2.2, 2.3)

Requirement IDs: GV-003 "Match reference decisions and verifier outcomes" (scenario "Stable malformed solver output"), and GV-006 "Correctness precedes performance acceptance".

Add mode `inject` to the probes. Take the device-produced result and mutate it in the probe. The mutations:

- solver candidate: drop a node; erase a source fact; clear bit 63; renumber the stamp to an earlier epoch;
- label answers: flip a denial to an allowance; truncate the answer tree; swap the tree shape;
- transfer decisions: fabricate an `Admitted` for the missing-read request; attach a ticket for a different plan; present it against a stale `Context`.

Each mutation must be denied by the independent path:

- `Core.verify` on the original graph, which must not be given the solver's tree or work list;
- `Dlm.verify_batch` replay;
- `Transfer.admit` against the authoritative `Context`. For one admitted case, also route it through `DataOS.commit_from_capability` with the forged decision and show the commit refuses it and no output or ledger effect occurs (read `DataOS.bend` for what "no effect" returns).

Then add the wrong-but-faster control. A `bench-forged` mode returns a constant allow-all answer without running the bang, so it is faster by construction. Feed it through the same measurement and gate as Task 7. The record must show `correctness` FAIL and `gate` FAIL, with its wall time present but marked "not accepted".

Write `verification/gpu-injection.txt`, including a list of the scenarios that have no hardware coverage (cases whose launch count was 0).

Acceptance: every mutation is denied, with the denying function and result printed; the forged fast run is a recorded failed run; and the no-hardware-coverage list is explicit, even if it is empty.

