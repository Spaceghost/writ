### Task 7: End-to-end evidence and traceability (task 2.1)

Add a `scenarios` section. Each case is one lifecycle from `open`, through public entry points only (Issuance, Negotiation, Rendezvous, Backplane):
- Current authority: two providers and two origins; offers, approvals, selection, challenge, sample, approve, reserve, start, dispatch and commit, all accepted.
- Revocation, at three points: an origin approval withdrawn before selection, a grant revoked between selection and dispatch, and a grant revoked between dispatch and commit.
- Replay: a resubmitted offer serial, an approval serial, evidence, and a dispatch.
- Denials: the seven listed cases (unauthenticated provider, scope narrower than the plan, a candidate substituted after selection, selection racing revocation, grant expiry before dispatch, dispatch to an unselected provider, and identical candidates distinguished only by identity), each as one lifecycle.

Plan ruling (HostPrimitives leg): if the `HostPrimitivesTests` fixtures can bind a worker session whose caller subject is the provider without editing them, one scenario drives `HostPrimitives.issue` and `admit_worker` from `provider_registry`. Otherwise the scenario stops at `F.checked_plan`, and the traceability file records the HostPrimitives leg as reviewed-only.

Estimate about 12 checks.

Write `verification/executor-rendezvous.txt`. It records:
- the commands, the Bend version, the date and the lane's base SHA;
- the Rendezvous summary line;
- the total PASS count ("1428 plus N = M");
- the law list, with each law's rationale and limits, and any law that is "tested, not proved";
- the mutation totals per task;
- what was not exercised: transport authentication, signatures, durable state, concurrent hosts, trial metering, any native host, and settlement. A CPU run is not a GPU test.

Write `openspec/traceability/executor-rendezvous.md` in the shape of `grant-issuance.md`:
- one row per ER-001 to ER-008, with the functions, the exact named tests, the laws and the coverage boundary;
- explicit reviewed-only gaps: per-use projection rebuilding, host serialization of installs, worker session identity supplied by the adapter, and the HostPrimitives leg if Task 7 stopped short of it.

It opens by stating that the change is proposed and that no host adapter or acceptance scenario is implemented. Check box 2.1.

Acceptance: green suite and proofs. Every traceability row cites existing test names verbatim, and the evidence file matches the run.

