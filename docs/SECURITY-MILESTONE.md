# Security milestone

If Writ authorizes a document export and the machine crashes, recovery must
retain the exact document version, every origin restriction, the destination,
the payment state and the audit event. Losing the reply from storage must not
cause Writ to spend again or release a different version.

The shared Bend protocol now separates preparation from confirmed publication.
Preparation runs the existing seal, live capability, authority, policy and
payment checks once. It stages a complete authorization record and its audit
policy, while keeping the original session and ledger current. Only matching
storage confirmation and a current independent witness can promote that state
and admit delivery. An uncertain outcome blocks another authorization.

The logical record retains the full plan and output policy, including origin
code and payment restrictions, DLM labels, backend, sealed artifact identity,
receiver identity and generation, next session and ledger replay state, and the
audit event with its decision-time influences. It also retains the host's
publication replay projection and the sealed artifact's object/version locator.
Cold recovery reconstructs replay state from that record into an empty, newer
host incarnation; it cannot revive old workers or capabilities. Exact comparison also rejects
semantically equivalent policy rewrites during recovery. It is not sufficient
to compare a content hash or the old invocation/destination tuple.

A registered receiver's private storage must atomically associate the complete
record with its unique transaction key before applying the effect. The receiver model
distinguishes first acceptance from an exact retry and rejects conflicting
contents. If an acknowledgement is lost, recovery uses the stored record;
it does not repeat authorization or payment. A missing or conflicting witness
stops recovery. This bounded model permits one outstanding transaction;
reconciliation with later authority mutations is still a native integration
requirement.

Delivery uses a separate minimal envelope containing the committed identity,
destination and sealed artifact locator. The full ledger, audit influences and
host history remain private monitor data and are never an output payload.
The current receiver model is internal storage reconciliation. An external
receiver wire protocol needs its own authentication and qualification.
Durable audit idempotency uses the composite host, store epoch and event
sequence; an event number alone is not globally unique.

Provenance remains useful evidence about derivation and authorization. This
work retains it together with the decision and audit policy. It does not turn
public Bend constructors or a local editable log into authenticated evidence.
Signatures, protected retention, key custody, a bounded canonical storage codec,
trusted time, chain-of-custody procedures and an actual native store remain
necessary for an evidentiary deployment.

The Windows preview continues to be ordinary folder/S3 sync. A protected
corporate profile remains unavailable until the native store, independent
anti-rollback witness, idempotent receiver and confinement gates pass.
The existing strict Windows confinement gate has failed; these model results
do not change that result. Native CPU tests are execution evidence for the
protocol, not protection of a desktop folder.

Approved redaction is a subsequent controlled-disclosure transition: retain
original provenance and policy, and attach a separately authenticated release
decision for the exact redacted version. No automatic label clearing is added.
Protection against destructive encryption also needs independently retained
versions and recovery keys, beyond the transaction boundary implemented here.

See the [scenario-to-evidence matrix](../openspec/traceability/durable-publication.md),
[implementation plan](superpowers/plans/2026-11-11-security-milestone.md), and
[pending native acceptance tasks](../openspec/changes/add-durable-publication/tasks.md).
