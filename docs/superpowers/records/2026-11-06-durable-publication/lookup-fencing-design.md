# Proposed transaction lookup and fencing boundary

A monitor submits transaction T to consume receipt R and record artifact A for
destination X. Its acknowledgement is lost. A later ordinary read returns
“absent,” then the delayed submission of T commits. If the monitor treated the
read as a failed transaction and authorized another spend, it could create two
conflicting outcomes. The current lane has no authenticated store, durable
pending registry, fenced lookup, or restart protocol. `DurablePending.bend`
blocks retries in a synthetic in-memory state; it cannot enforce that behavior
across restart or against another writer.

This is a **proposal for review**, not a specification of an implemented host
adapter or a new publication API. The relevant proposed contract is
[DP-001–008](../../../../openspec/changes/add-durable-publication/specs/durable-publication/spec.md),
with explicit model and host gaps in its
[traceability](../../../../openspec/traceability/durable-publication.md). The
existing [authority boundary](../../../../openspec/specs/authority-boundary/spec.md)
requires monitor-owned inputs, serialization and crash-safe replay state.
[Recovery design](recovery-design.md) and the [witness review](witness-design.md)
describe the independent witness and receiver gaps. All implementation and native acceptance tasks remain open.

## Identity and the complete transaction

A prospective transaction is named by **store authority and namespace,
namespace incarnation, and transaction ID**. The authenticated store authority
is a configured trust identity, not a path, descriptor, bearer token, or
caller assertion. Incarnation separates restored, replaced, migrated or reset
namespaces. Transaction IDs are monitor-assigned and unique within their
incarnation; their allocation method, collision handling and limits require a
reviewed host design. Neither invocation ID nor artifact ID alone is a
transaction ID: the full transaction also binds the request and its state
transition. Reusing the same identity with a different binding is a conflict,
never a new attempt. Duplicate exact submissions must resolve to one outcome.

The transaction record, or a reviewed authenticated commitment to a canonical
and fully retrievable record, must bind at least:

- Protocol and record versions; store authority, namespace, incarnation and
  transaction ID; and the authenticated issuer/monitor and its authority to
  address this namespace. These identities and versions have unambiguous,
  domain-separated encodings.
- The complete request and invocation, receipt, artifact, destination, backend,
  full write intent, derived policy, original restrictions and labels, including
  ordered provenance, payment, operation and sink-effect obligations.
- The complete authoritative preconditions and their serialization domain:
  graph and policy epochs, source versions, identity, grants, capabilities,
  authority epochs, all session, ledger and replay revisions, registered sink,
  worker and sealed-artifact facts, trusted time/deadline, and every other
  input to the final Bend gate. Revision values are meaningful only if the
  corresponding authority actually participates in the same serialization
  protocol. Facts that can change without a revision, including time and writer
  exclusion, need an explicit stability or final validation mechanism.
- The resulting session and ledger, replay/host state, retained exact intent,
  and any required audit event **and its decision-time policy**, as well as the
  expected prior state or commitment required to bind the atomic transition.
  If a mandatory component is missing, there is no complete durable record.

The current entry word/byte encoding describes only one journal entry. It is
not canonical transaction framing, a full read-set commitment, authenticated
storage, or a transaction-identity scheme. A digest supplied by a caller is
not authentication; any future commitment scheme must specify canonical full
coverage, domain separation, algorithm/version, collision and substitution
handling, verification, key ownership and rotation, and recovery of the exact
record. No cryptographic primitive is selected or implemented by this note.

## Before submission: do not lose knowledge of T

The monitor must establish durable, recoverable knowledge of the assigned ID,
its complete binding and unresolved status **before a submission can escape**.
Otherwise a crash between sending T and persisting the pending marker can
restart from `TxnReady` while T remains able to commit. A qualified protocol
must provide either a protected durable pending registry, or an equivalent
atomic store-side registration and authoritative restart enumeration that
cannot omit in-flight submissions. The reservation/registration itself needs
defined lost-acknowledgement behavior; an unconfirmed registration cannot be
assumed absent. The registry and any allocator are subject to rollback and
namespace-incarnation protection, not just ordinary filesystem persistence.

A single monitor-owned serialization domain must cover all writers able to
submit, including recovery workers and competing instances. It must prevent a
new authorization for the same invocation, receipt or affected state while an
unresolved T could still commit. A per-process mutex, a public `TxnUnknown`
constructor, or a single journal revision does not establish that property.
After restart, block affected work until pending identities, authoritative
state, and current rollback evidence have been reconciled. Failure to enumerate
or authenticate them leaves the profile unavailable.

## Candidate store operation semantics

The following describes required **observable properties**, not a chosen wire
protocol or implementation. Storage reports authenticated facts about its own
registered operation; the Bend monitor owns all authorization, scope, replay,
reconciliation and release decisions. An arbitrary host acknowledgement or a
constructed Bend record is not an authenticated fact.

1. **Submit T.** At one durable serialization point, compare the complete
   current preconditions, including the prescribed handling for time, sealing
   and writer exclusion; then atomically install the complete accepted record,
   session, ledger, replay state and required audit data, or install none of
   that business transition. All parties that can change those facts must be
   ordered consistently with this point. A response may be lost after commit.
   A stale or incomplete read set is not rescued by a successful storage CAS.
2. **Resolve or fence T.** A candidate operation must have a linearizable,
   durable result relative to **every** submission of this identity. If T
   committed, return an authenticated reference to its exact complete record
   and its committed position. Otherwise atomically establish a durable fence
   or equivalent irreversible terminal fact, after which no earlier, queued,
   delayed, retried, or concurrently submitted T can commit. Only then can a
   negative result mean `FencedAbsent`. The authenticated result must bind the
   requested store authority, namespace, incarnation, transaction ID, exact
   expected binding or its reviewed commitment, outcome and relevant position.
   A timeout, ordinary missing read, stale replica, dropped connection or bare
   local counter is **unknown**, not `FencedAbsent`.
3. **Handle outcomes.** On authenticated `Committed`, retrieve and verify the
   full transaction record and its exact binding; a match says only what the
   store committed, not that rollback evidence or delivery qualification is
   present. On authenticated `FencedAbsent`, do not install the proposed state:
   first reload all current authoritative state and reconcile the witness;
   a later attempt runs the full current Bend authorization with a fresh ID.
   Fencing T does not prove that another transaction did not alter the same
   invocation, receipt, grant or ledger. For conflict, malformed, mismatched,
   unauthenticated, stale or unclassifiable responses, retain uncertainty or fail
   closed. No result here yields a native publication effect.

A negative terminal fact must survive the store's acknowledged crash and
failover cases and remain effective against delayed submissions. Retention and
compaction may retire it only under a reviewed namespace/epoch and reclamation
protocol that makes every old submission impossible and preserves rollback
protection. Expiring a tombstone because of elapsed wall time alone does not
prove an old request cannot arrive. A store that cannot supply these properties
is unsupported for this recovery protocol; this note does not assert that any
existing store does so.

## Authenticity, freshness and rollback are separate

An authenticated response must be bound to the intended store authority and
namespace; its request/response binding must prevent replay or substitution
between transaction IDs and incarnations. A fresh challenge can prevent replay
of an old signed message, but does not by itself establish that a responding
store contains current history. The monitor must independently establish current
authority and replay history through the selected authenticated rollback
witness and any reviewed store–witness reconciliation. This includes pending
registrations and fences when they affect whether an old transaction may
commit. A restored but internally consistent store, matching transaction
record, digest, or nominal counter is not a current witness.

If the store and witness update separately, neither numerical ordering nor a
matching local head proves a legitimate extension. Until a reviewed protocol
establishes the required history and admissible update order, loss, rollback,
store/witness disagreement, or an ambiguous current witness keeps publication
unavailable. A transaction confirmed at the store is not permission to deliver:
the durable authorization, required witness, qualified authenticated sink,
exact sealed bytes and policy obligations must all be established first.

## Interleavings to model and test

| Race or failure | Required observation; remaining evidence |
| --- | --- |
| Crash before T is registered, including unknown registration acknowledgement | No submission can escape untracked; prove durable pre-registration or equivalent restart enumeration on the selected host. |
| Lookup races delayed T | Linearize commit or fence: a committed T returns its exact record; a fenced T cannot subsequently commit. Ordinary absence remains unknown. |
| Two monitors submit or resolve the same T | Exact duplicate has one terminal outcome; changed binding under the same ID is rejected. Authentication, isolation and failure injection are still needed. |
| A different T consumes the same receipt or changes a grant | Fencing the first T does not restore a stale snapshot; current authority, budgets, epochs, original graph and replay state are revalidated before any fresh attempt. |
| Fence is acknowledged then store or witness rolls back | Do not accept old submissions or new authorizations from the stale state; qualify fence durability, incarnation and authenticated witness reconciliation. |
| Commit succeeds, acknowledgement or lookup response is lost | Keep T unknown; retry resolution without spending again. Validate exact committed scope and current witness before any separate delivery path. |
| Lookup response replays across namespace or conflicts with the requested binding | Reject it and remain blocked; demonstrate authenticated binding to authority, incarnation, ID, complete record and freshness. |
| Store is unavailable, result is malformed, witness is absent or a replica is stale | Do not infer failure or success; remain unavailable until authenticated reconciliation. |
| A terminal negative is compacted, then a delayed submission arrives | An incarnation or equivalent proven mechanism rejects the old submission; prove retention, reclamation and failover behavior. |

## Present evidence and review gates

`DurablePendingTests.bend` names the synthetic checks `durable pending blocks a
new authorization after a lost acknowledgement` and `durable pending remains
blocked across retries with a changed expected revision`. These checks neither
implement a store operation nor prove its linearization, authentication,
durability, retry behavior or fencing. The experimental entry codec is not a
full transaction representation. There are no native crash or multi-writer
results for this proposal, no qualified witness or sink, and no completed DP
acceptance scenario. The exact storage API, uniqueness and canonical binding,
pending-registration method, time and seal serialization, witness coordination,
monitor restart procedure, reclamation and host-specific trust assumptions
remain open for independent security review and implementation.
