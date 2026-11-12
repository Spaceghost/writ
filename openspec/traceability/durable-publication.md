# Durable publication traceability

The proposed [DP-001–008 contract](../changes/add-durable-publication/specs/durable-publication/spec.md)
is not qualified on a native host. The shared protocol in
`DurablePublication.bend` and complete logical record in
`PublicationRecord.bend` implement the model tranche below. Test names refer to
`DurablePublicationTests.bend`; store, witness and receiver inputs are synthetic.

| Requirement | Implemented model evidence | Native acceptance still needed |
| --- | --- | --- |
| DP-001 Durable before visibility | Preparation emits only conditional Persist; original host/session/ledger remain current; exact durable record plus witness admits one Deliver; missing witness and unknown outcome emit none | Canonical bounded record codec, authenticated atomic storage of payload/policy/session/ledger/replay/audit, actual crash and failed-append tests |
| DP-002 Current revisions | Existing live host/capability gate reused once; waiting and uncertain states block concurrent preparation; changed head on absence requires reconciliation | Global serialized CAS including every authority mutation, concurrent independent monitor attempts |
| DP-003 Commit/revocation order | Revoked registry rejected before preparation; post-commit retry uses stored result and never reauthorizes | Real revocation/store race; current protocol blocks head changes until authoritative reconciliation, which remains unimplemented |
| DP-004 Exact recovery | Record equality binds complete plan/output policy, label, backend, artifact/locator, sink identity/generation, next session/ledger, host replay projection and event/policy; substitutions rejected at confirmation, private receiver reconciliation and acknowledgement; cold restore requires an empty newer host incarnation | Authenticated reload with no caller-controlled record, artifact re-opening/sealing, actual cross-process recovery |
| DP-005 Receiver idempotency | First acceptance and exact duplicate distinguished; crash-window retry modeled; changed records rejected | Real receiver atomic compare-and-apply, authenticated receipts, crash after acceptance before acknowledgement |
| DP-006 Inherited policy | Full origin rules and audit influences retained and compared; stripped origins, changed labels or audit policy rejected | Inseparable payload/policy storage and protected copy/rename/reload |
| DP-007 Rollback resistance | Stale, missing, inconsistent or newer independent witness blocks local recovery; same revision/different digest refused; unknown cannot become fresh authorization | Independent current witness custody, authenticated hash chain, backup restoration, witness loss and compromise tests |
| DP-008 Unsupported sinks | Unsupported contract, wrong backend or unregistered receiver refused | Versioned, administrator-owned registration and verification of each real receiver contract |

Five ordinary laws cover the actual resolve/prepare/retry/restore entry points:
`durable_unknown_emits_nothing`, `durable_unknown_preserves_current`,
`durable_uncertain_blocks_preparation`, and
`durable_unconfirmed_cannot_retry`, and `durable_unknown_cannot_restore`.
They establish pure transition properties,
not storage or endpoint enforcement.

The existing `HostPublication.publish` remains a compatibility API for the
earlier pure host model. A future protected binding must import only the
durable entry points and must have a structural boundary check excluding the
legacy Publish/Reconcile effects. No protected native binding exists here.
The combined implementation/native tasks remain unchecked.

Delivery envelopes intentionally omit ledger, audit and replay history.
`reconcile_receiver` operates on private monitor storage; no external wire
protocol for full records is implied. Audit idempotency is keyed by host,
store epoch and sequence. Review found missing cold-recovery replay metadata,
an omitted artifact locator, ambiguous event numbering and an overly broad
delivery payload; the record projection, restore transition, composite key
and narrow Delivery type address those findings.
