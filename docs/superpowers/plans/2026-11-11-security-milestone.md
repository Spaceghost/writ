# Security milestone: durable authorization boundary

A sealed corporate document must not become visible if Writ loses the audit
record or crashes between consuming its authorization and recording its policy.
Recovery must preserve the same version, origins, destination, receipt and event.
The current publication model emits a proposed release immediately and records
only invocation, digest and destination for reconciliation.

Branch: `lane/security-milestone`, based on `236bfb81`. Follow the existing
[durable publication plan](2026-11-06-durable-publication.md), DP-001–008, PH-009,
and the policy-aware audit requirements. Preserve all existing authority laws.

This implementation tranche supplies the shared Bend transaction boundary:

1. Extract the existing host publication checks into a preparation with no
   release effects. Preserve the legacy model API and its existing tests.
2. Compose that one checked result with its decision-time audit policy, complete
   output policy, next session and ledger. No second authorization or spend.
3. Admit delivery only after a matching storage transaction and current witness
   are confirmed. Model conflict, definite failure and uncertain outcome
   separately. Uncertainty prevents a new attempt.
4. Bind recovery and receiver acknowledgement to the complete stored record,
   including backend, sink generation, inherited restrictions and receipt.
   Unsupported receivers and rollback without a current witness fail closed.
5. Exercise adversarial scenarios on JavaScript and native CPU; run the full
   suite and ordinary proofs, obtain independent review, update traceability
   and source manifest, and integrate to master as the user requested.

The corporate native profile remains unavailable: native authenticated storage,
anti-rollback witness, receiver deduplication, crash injection and confined
execution are separate qualification gates. A pure receipt constructor is not
authentication, native CPU execution is not a durable-store test, and this
tranche does not claim legal admissibility or complete ransomware prevention.
Do not check combined model/native acceptance tasks prematurely. The ordinary
Windows sync preview and its live manifest are not relabelled as protected.

After this tranche, bind the protocol to a qualified Windows service/store and
receiver before enabling protected publication. Controlled redaction remains an
explicit owner-authorized transition retaining original provenance; no label
clearing or implicit declassification is introduced here.
