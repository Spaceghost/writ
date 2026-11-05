### Task 5: Shared conformance vectors (tasks.md 1.4)

Requirements: PH-001 "One policy implementation across hosts", PH-002 "Subject identity survives the native boundary", PH-004 "References bind incarnation and generation", PH-005 "Delegation cannot widen Writ scope", PH-009 "Publication observes one current authority boundary", PH-010 "Revocation includes quiescence and stale completion rejection", and the shared-vector half of PH-012 "Qualification requires both decision and native tests" ("Two native adapters are compared", decision part only).

Create `HostConformanceVectors.bend`. It contains no `Test` import and is exported so that a native port can import it. It holds named vector inputs (wire bytes, the session evidence and target report, the fixture context) and each vector's expected normalized outcome. Create `HostConformanceTests.bend` (registered as `HostConformance`). For each vector it runs the full Bend path: `HostWire.decode_bytes`, then `HostPrimitives.use`, `admit_worker`, `seal`, `publish`, and `revoke` as the vector requires. It asserts the expected outcome with `Test.check`, then prints `VECTOR <PH-id>-<n> <primitive> <accepted|denied> <reason-or-id>`, rendered from the actual result. Ids are model slots and invocations only, never native values. Vector lines start with `VECTOR`, so they do not change the PASS count.

The vectors must cover at least the following.
- Exact plan binding: the baseline accepted publish; a delegated reference used on a session whose negotiated plan names destination E instead of D is denied (PH-005's first scenario); a plan with a changed input object is denied; a narrower delegated use of the same plan is accepted with the same intent.
- Retained provenance: the accepted intent retains the source labels and origins (the `BackplaneTests.retained` predicate). The delegated path's intent label and origins equal the root path's, and the delegation copies the parent's plan unchanged.
- Caller identity: a body claiming subject B on A's session gives the same outcome and the same intent as with no claim; a transferred endpoint with no edge is denied; an inherited endpoint is denied; a guessed slot from another session is denied; a reference from another host is denied.
- Revocation: revoke before authorization is denied; revoke after publication leaves reconcile returning the same digest; a stale completion after teardown is denied; creating a narrower proxy does not report the parent revoked.
- Replay: a second publish is denied with the ledger unchanged; a prior-incarnation reference after restart is denied; reconcile with a substituted digest is denied.
- Unchanged state on denial: every denied vector also asserts primitive-state equality and unchanged ledger revision, balance, and session revision.
- Two adapters: plan ruling, two synthetic target fixtures with different `host` ids and different slot allocation orders (A mints an unrelated entry first) run the whole set. The test asserts their normalized outcome lists are equal, after mapping slots to the vector's logical names.

Estimate: about 30 checks and about 26 vector lines; about 250 lines in each file. Capture the `VECTOR` lines to `verification/portable-host-vectors.txt` from two JavaScript runs and one native run, and show them byte-identical (`cmp`). Record the SHA-256 in the report. Add a "Vectors" section to the traceability file listing each vector id with its inputs (fixture names) and expected outcome, as `genode-capability-adoption.md` does. Check box 1.4.

Acceptance: every listed vector exists and passes; the captures are byte-identical across runs and backends; the traceability file lists every vector.

