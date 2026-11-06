# Durable publication: implementation and evidence plan

Status: **planning only**. No durable-publication task is complete by virtue of
this plan. The proposed contract is [add-durable-publication](../../../openspec/changes/add-durable-publication/proposal.md);
its dependency on [confined execution](../../../openspec/changes/add-confined-transform-execution/proposal.md)
remains open. This plan authorizes neither host qualification nor a new release
route.

## Example and current gap

A worker produces sealed artifact A for destination X. After all current Writ
checks succeed, the host must atomically record the authorization, the exact
artifact and inherited policy, the finished session, the consumed ledger hold,
and replay state before X can see A. If the host crashes after X accepts A but
before recording the acknowledgement, recovery must retry the *same* committed
intent, and a supported receiver must recognize that retry. A different
destination, artifact, policy, or billing scope must not be substituted.

Today `DataOS.commit_from_capability` and `Backplane.commit` return pure
decisions and proposed state, not durable writes. `HostPublication.publish`
returns an effect on a successful pure transition and relies on its binding to
persist that outcome atomically before exposing it. Its recovery record binds
only invocation, digest, and destination: it does not detect changes to output
policy, labels, or backend. `HostPublication.reconcile` neither commits nor
spends. The existing model tests do not establish storage atomicity, actual
sealing, receiver deduplication, or crash recovery.

## Contracts and integration boundaries

- [DP-001–008](../../../openspec/changes/add-durable-publication/specs/durable-publication/spec.md)
  specify atomic authorization, current revisions, revocation ordering, exact
  recovery, sink deduplication, inherited policy, rollback resistance, and
  refusal of unsupported sinks. [Tasks 1.1–2.2](../../../openspec/changes/add-durable-publication/tasks.md)
  remain unchecked until their stated implementation **and** evidence exist.
- [CB-001–010](../../../openspec/specs/commit-backplane/spec.md), the
  [reservation ledger](../../../openspec/specs/reservation-ledger/spec.md),
  and [AB-006](../../../openspec/specs/authority-boundary/spec.md) retain
  their existing authority, verification, payment, serialization, and
  persistence obligations. A restored snapshot alone is not current authority.
- [Portable-host PH-009](../../../openspec/traceability/portable-host-contract.md)
  already models seal, live capability resolution, publication, and narrow
  reconciliation. Extend or compose the one authoritative path; do not wrap
  `HostPublication.publish` with a second independently callable release.
- [Audit section 2](../../../openspec/changes/add-policy-aware-audit/tasks.md)
  depends on this transaction. Reserve a place for a required audited event
  and its decision-time policy in the transaction design; do not claim durable
  audit merely because a slot exists. The v1 encoded event alone has no policy.
- Confined execution must establish actual input provenance, worker isolation,
  writer elimination, and sealed bytes before native end-to-end acceptance.
  Synthetic facts are model fixtures, not evidence that any host provides them.

## Proposed state and transitions for design review

Use Bend for state and every authorization, replay, recovery and release
decision. The native boundary reports facts and executes only effects admitted
by the monitor. Record constructors are public data, not proof of authentication.
The following is a design target, not an assertion that these types exist.

1. **Preparation:** monitor-owned current session, ledger, capability and
   authority snapshots, original graph, sink registration, sealed artifact
   facts, and revisions feed the existing final authorization path. A proposed
   record includes the complete committed `WriteIntent` and output policy,
   exact artifact identity and destination/backend, invocation and receipt,
   next session and ledger states, and all replay/epoch information required
   to recover. Bind any required audit event and its policy from the same
   decision. Reject inconsistent fields and unsupported sinks; callers cannot
   supply authoritative state or invent a successful transaction.
2. **Durable authorization point:** the host storage primitive must atomically
   compare every relevant current revision and persist the record, session,
   ledger, replay state, and required audit entry as one transaction. Model an
   acknowledged success, conflict, failure, and **unknown outcome** separately.
   Unknown outcome cannot be treated as either a fresh authorization or a
   completed write: reconciliation must establish what committed. No public
   publication is admitted before confirmed durability.
3. **Delivery:** only the stored committed intent may drive delivery, using an
   authenticated, registered sink with an actual deduplication or transactional
   contract. Key the receiver operation by committed invocation and artifact,
   and reject a repeated identity with changed contents or scope. A local
   outbox alone cannot prove receiver deduplication.
4. **Acknowledgement and recovery:** persist delivery progress idempotently;
   replay the exact committed record after crashes without spending again or
   reauthorizing a copied old snapshot. Later revocation stops future
   authorizations; it does not rewrite a committed outcome. Reconcile uncertain
   storage outcomes and trusted replay/epoch high-water marks before enabling
   new publication. Without an authenticated current witness, fail closed.

The implementer must resolve the interface between `HostPublication.publish`,
its existing effect, the durable transaction, and `AuditEvent.audited_commit`
in the first design review. In particular, calling two independent commit
paths or allowing a host to execute the pre-durability effect would violate
this plan. Preserve the existing gate and laws; any change to a security law
requires a stated rationale and review.

## Work sequence and acceptance

Each task has implementation review and security review before the next
dependent task. Keep model work and real-host qualification separate; do not
check a combined OpenSpec box for a model-only result.

1. **Interface and threat-model review.** Map the existing publish and audit
   calls, all current revisions and owner-controlled facts, and the complete
   output policy and replay data. Specify the atomic-store and receiver
   contracts and the witness for rollback detection. Resolve the interface
   issue above and write the preconditions of each native fact. Deliverable:
   a reviewed design and a DP-001–008 scenario-to-evidence matrix with explicit
   gaps; no runtime behavior changes.
2. **Bend authorization and transaction model.** Model the current final
   checks, one prospective atomic commit, conflicts, failures, and unknown
   results without a second publication path. Denials preserve session,
   ledger and output state; two transactions against the same revision cannot
   both commit; test each ordering of revocation and serialization. Pin the
   actual dispatch path with adversarial tests, not only constructors or
   accessors. Demonstrate which guarantees depend on the host primitive.
3. **Bend exact recovery and sink model.** Test retries before delivery, after
   delivery and before acknowledgement; repeated acknowledgement; changed
   artifact, destination, backend, policy, receipt, and invocation; unsupported
   or forged sink registration; and a conflicting reused idempotency key.
   Test a rollback with an absent, stale, or inconsistent witness and recovery
   only after authenticated reconciliation. Preserve inherited origin and
   label restrictions on every reload and copy.
4. **Audit integration design and tests.** Bind required wrapper-produced
   event and decision-time policy to the same authorization transaction, with
   failed append preventing the protected effect where required. Denial events
   must not change rejected business state; record outage limits rather than
   claiming complete denial history. Full audit section 2 remains separate work.
5. **Native qualification, after prerequisites exist.** Select and explicitly
   inventory a host storage primitive and sink, prove their authority boundary,
   and run real crash/failure and concurrent-revision tests at every transaction
   and delivery boundary. Exercise stale backup restoration, witness loss,
   actual sealed bytes and policy reload. A sink without a verified receiver
   deduplication contract is unsupported. Record exact host, versions, source,
   hashes, commands, observed outcomes, and limitations; a Bend simulation is
   not crash or isolation evidence.
6. **Integration and records.** Update named-test traceability for each DP
   scenario and mark reviewed-only or native gaps explicitly. Run `bend
   Tests.bend`, native tests, and `bend PROOF.bend` using pinned Bend 2.0.39;
   attempt `--verdict` when the documented Lean kernel is available. Validate
   OpenSpec 1.16.0 strictly. Report actual CPU/GPU and Lean results, preserve
   source manifest alignment, and archive only after every task's evidence is
   complete.

## Crash and ordering matrix

| Interruption or race | Required observation | Evidence needed |
| --- | --- | --- |
| Before atomic authorization commits | No public output or committed spend | Model denial plus native atomicity and visibility test |
| Commit acknowledgement lost | Outcome remains unknown until reconciled; no second authorization | Model case plus host fault injection |
| Revocation before serialization | Final authority check rejects | Both model orderings and serialized host test |
| Revocation after committed authorization | Recovery retains the original committed scope | Model case and host transaction ordering evidence |
| Two commits use the same invocation/revision | At most one authorization and one spend | Model test and real concurrent transaction test |
| Receiver accepts, acknowledgement is lost | Retry has identical committed scope; receiver emits one logical result | Model test and sink-specific crash/deduplication evidence |
| Stored policy, artifact, backend, destination or receipt changes | Refuse substituted recovery | Per-field model checks and protected-storage/host tests |
| Old snapshot or missing current witness | New publication disabled until authoritative reconciliation | Model test and tested witness/recovery procedure |

## Explicit open dependencies

- The confined worker and native storage/sink needed for end-to-end evidence
  are not qualified here; no platform is selected by this plan.
- Board question q19 selected synthetic monitor-side Linux identity cases;
  those model checks are recorded in the [Linux synthetic report](../records/2026-11-05-linux-host/task-2-synthetic-report.md).
  Native Linux identity and confinement evidence remain open. No answer to
  Spaceghost's broader questions is assumed here.
- The atomic transaction, witness and sink protocols must be chosen and reviewed
  before implementation claims their guarantees. If a host cannot provide one,
  record the gap and refuse the unsupported profile.
