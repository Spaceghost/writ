# Proposed audit integration with durable publication

Suppose Alice requests a summary derived from Alice's and Bob's protected
records. The worker produces sealed artifact A for destination X, and the
monitor's final checks accept it. If audit is required, one protected record
of that same final decision, with both owners' decision-time restrictions,
must become durable with the exact authorization and ledger consumption before
X can observe A. Today the audit wrapper and host publication path are
separate pure models: neither appends a durable record, and calling both as
currently written would evaluate the capability commit twice. No audit–durable
transaction, authenticated history, witness, qualified sink, or crash-tested
host integration exists.

This is a **design mapping for review**, not a selected protocol, changed
contract, new release route, or completion of any task. The relevant proposed
contracts are [AU-001–009](../../../../openspec/changes/add-policy-aware-audit/specs/policy-aware-audit/spec.md)
and [DP-001–008](../../../../openspec/changes/add-durable-publication/specs/durable-publication/spec.md);
[AB-001/002/006](../../../../openspec/specs/authority-boundary/spec.md) and
[CB-001–014](../../../../openspec/specs/commit-backplane/spec.md) remain
applicable. The [existing audit traceability](../../../../openspec/traceability/policy-aware-audit.md)
and [durable traceability](../../../../openspec/traceability/durable-publication.md)
distinguish model evidence from unimplemented host behavior. Section 2 of the
[audit tasks](../../../../openspec/changes/add-policy-aware-audit/tasks.md) and
all durable acceptance tasks remain open.

## The one-decision boundary

`AuditEvent.audited_commit` calls `DataOS.commit_from_capability` once, then
projects its returned `B.CommitResult` into an event and derives a policy from
monitor inputs. Its laws preserve that facade result; they do not establish a
final host publication or a durable append. Separately,
`HostPublication.publish` re-resolves the worker and descriptor, checks the
seal, writer exclusion, phase, plan and replay, calls the same facade once,
then checks the returned intent's plan and artifact against the host record.
Its `Published` includes a proposed `Publish` effect; an outer `Refused` can
occur before the facade call or after a provisional `B.Committed` result.
`DurablePublication.prepare` discards that effect and retains a prospective
state, but it neither persists nor authenticates anything.

Therefore the durable profile cannot call `audited_commit` beside `publish`:
that is two independent evaluations and can create a `CommitAccepted` event
for a provisional facade result that the final host gate later refuses. It
also cannot rerun checks to invent a denial reason, wrap a caller-constructed
`B.Committed`, `B.Rejected`, `Recorded` or `PublishResult` as evidence, or
execute the preliminary `Publish` effect. A future reviewed Bend integration
must project the event from the **one final host outcome and the same
monitor-owned decision snapshot**, with the existing capability/backplane
transition evaluated once. It must extend or compose the existing path, not add
a separately callable release. The current exported constructors and helpers
cannot enforce which invocation produced a value; the monitor/host integration
must enforce that origin until a reviewed interface can do so.

A necessary unresolved design decision is event vocabulary. Existing
`commit_event` accepts a `B.CommitResult` and an authenticated `F.Ref`; it
has `Committed` or `NotCommitted` and no host-specific denial reason. An
outer refusal before identity resolution has neither that facade result nor a
verified reference, while an outer artifact/plan refusal can follow a
provisional facade acceptance. Reusing the latter acceptance, fabricating a
facade rejection, or claiming an unverified subject is not an answer. Specify
and review a final-host event representation and the authenticated subject and
scope available at each gate before writing this integration. A staged
accepted-authorization event is private and provisional until the required
transaction is confirmed; whether any later delivery event exists is another
explicitly reviewed choice. Event names must not imply recipient delivery
merely because authorization was recorded.

## Decision-time event, policy and provenance

The current audit event allowlist excludes payload bytes, credentials, tokens,
request bodies, receipts, payment witnesses and unrestricted error text. The
accepted event's allowed scope includes the invocation, ordered source
versions, destination, epochs, code and operation; its artifact digest can
itself reveal a low-entropy output. An event's fields, existence, event ID and
policy are sensitive. The full transaction separately needs its complete
request, receipt, intent, original restrictions and other replay state; those
must not be copied into an audit event merely because they are in the same
protected transaction.

`Recorded{event, policy}` contains the actual `EventPolicy`: individual
`Influence{owner, label, edge}` records, secrecy bits and untrusted-influence
bits. Existing derivation includes plan source and destination data **and**
control influences, authoritative context source/destination control
influences, the requester's control influence, and for commit the unique
binding's joined source/destination label as a control influence. Missing or
ambiguous labels or binding, and an unrepresentable requester principal, use
maximal restrictions. Preserve each owner's influence, edge and label, ordered
source occurrences, both bit sets, and the authenticated provenance and
version of the data from which the policy was derived. Never flatten to one
owner, erase a restrictive origin, replace a mixed policy with a permissive
one, or treat confidentiality authority as waiving integrity, payment,
operation or sink-effect obligations. The complete transaction must separately
preserve the intent's full origin rules, code/payment terms and label trees;
the event policy is not a substitute for those obligations.

The existing `commit_policy` depends on negotiated plan, transfer context,
label table, requester and binding, but **does not by itself cover every host
fact introduced by `HostPublication`**. A final-host event's existence or
outcome can also depend on worker/session resolution, seal and writer facts,
replay state, time and the artifact/plan comparison. A reviewed integration
must enumerate the actual read set and derive conservative data/control
influences for every additional protected dependency, or withhold the event
when adequate authenticated policy is unavailable. The old facade policy must
not be asserted sufficient without that analysis. Do not infer a principal or
policy from a caller-provided identifier, native handle, raw error or
untrusted observation. Preserve the existing outcome-independent policy
invariant where applicable; any broader law or event semantics needs an
explicit rationale and review.

Audit event version 1 encodes an `EventRecord` word list **without** its
`EventPolicy`. Its decoder produces an untrusted description; it cannot prove
that a wrapper ran or that a policy was attached. A durable profile needs a
reviewed versioned complete representation of event **and decision-time
policy**, or authenticated retention of the exact immutable authoritative
inputs sufficient to re-derive the identical policy. Recomputing from the
current label table or stripping the event policy on restart can change what a
reader sees. In particular, decoding an event alone and re-logging it is not
allowed. A format or resource-limit refusal must not truncate fields, lower
policy or silently discard a required event to permit release.

## Atomicity, retries and the secondary index

At the serialization point, the required-audit predicate, authenticated
identity, current capability/epochs/approvals, original graph, budget, sink and
sealed-artifact facts must be current within the host's reviewed serialization
domain. A worker or caller cannot choose whether audit is required, invent a
successful append, supply a pre-approved sink, or select a less restrictive
policy. The provisional result, complete event/policy and transaction state
are private monitor data.

For a required-audit acceptance, the one authoritative transaction must
atomically establish the complete committed authorization and exact intent,
finished session, consumed ledger hold, replay state and required audit
record—including its decision-time policy and authenticated history linkage—or
establish none of that business transition. Its event ID must be fresh,
monitor-owned and stable across retries, bound to the exact event **and**
policy/transaction scope. A conflicting reuse is rejected; an identical retry
is idempotent only under a qualified authenticated append protocol. A public
event ID or matching hash supplied by a caller is not proof of either fact.
No recipient effect is admitted until the transaction and the current witness
required by the selected profile are established and the exact registered sink
has separately satisfied its delivery contract.

A crash or lost acknowledgement creates **unknown**, not an assured rollback.
Keep the transaction/event identity and affected state quarantined, and do not
spend again or report a definite failure that would enable retry while the
original can still commit. Authenticated lookup of the complete binding plus
a fence for a negative result, pending-state recovery, and the rollback witness
are separate unresolved requirements in [lookup and fencing](lookup-fencing-design.md)
and [witness review](witness-design.md). If storage and the witness update
separately, a matching revision or a numerically newer head does not establish
which extension is authentic. Missing, stale, conflicting or unavailable
history blocks required-audit release until reviewed reconciliation succeeds.
No supported implementation is selected here.

The authoritative journal, not a search index or telemetry sink, must contain
the required event and policy. If an index update fails after a confirmed
commit, recovery may re-send the **same** event identity and exact protected
record to an authorized index under its own idempotency contract; it does not
repeat the business authorization, spend or publication. Index acknowledgement,
queue state, error details and identifiers are themselves subject to the
applicable policy. A local retry does not prove a receiver deduplicates.

## Denials, errors and observable channels

For a denied business attempt, the original session, ledger and host business
state remain unchanged whether a policy-protected denial append succeeds,
fails, fills a queue or has an unknown outcome. Audit bookkeeping may advance
only under its own reviewed serialization and authority rules; it must not
turn denial into permission or release a provisional artifact. Do not promise
complete denial history during storage outages: the host cannot claim an event
was recorded when it cannot prove that. A negative append acknowledgement is
not proof of absence if the append could still complete.

Project denial content from the actual result, never raw exception text,
payload, capability token or native diagnostic. An early refusal has no
verified scope or authenticated subject merely because a worker named one;
withhold or use a separately authenticated monitor/transport identity and a
reviewed conservative policy. The existing admission `ScopeNotRead` rule
limits unvouched scope and stream membership; extending it to host-level
failures requires an explicit reviewed design rather than copying untrusted
fields. A caller may receive only a policy-permitted generic status when the
reason, event existence, index status or audit failure cannot be disclosed.
There is no plaintext fallback log, alternate telemetry sink, automatic
release, or hidden declassification.

Queries, exports, metrics, alerts and any response or index-delivery effects
still require current scoped grants, authorized sinks and all event policy
influences at the time of the actual authorized output. Do not cache a prior
`Page` or `Sent` and deliver it after revocation. Queue, record, lookup and
query work need finite profile bounds; a full required-event queue must not
silently drop the event. The existing query work budget does not bound the
cost of building the whole visible view, and timing, scheduling and traffic
remain residual channels. This design does not claim constant-time or complete
noninterference.

## Scenario-to-evidence gaps

| Contract scenario | Existing named model evidence | Still needed; no acceptance claim |
| --- | --- | --- |
| AU-001 error includes protected content; AU-002 multiple owners | `AU-001 no payload, error-text, credential or caller-token sentinel occurs in an admission event`; `AU-002 multiple owners contribute evidence: Bob and Alice are separate influences and event_owners gives Bob then Alice` | Host-level final-result projection, complete host-gate influence analysis, authenticated provenance and exact retained event/policy. |
| AU-004 required append fails; DP-001 crash before record | `durable preparation retains the proposed committed state and exact artifact`; `audit_commit_returns_library_result` | One integrated final decision; atomic event/policy, ledger, session, intent and replay write; native fault injection and visibility test. Neither existing model appends. |
| AU-004 search index lags; AU-006 duplicate/reused event identity | None for a durable append or index | Authenticated idempotent identity and scope, policy-bound index delivery, conflict detection, crash/ack tests; no duplicate spend or delivery. |
| AU-005 denial append succeeds or fails | `AU-005 a commit rejected for a revoked capability is returned unchanged, keeps the hold and session, and is recorded as CommitRejected NotCommitted` | Model and host tests for final-host denials, successful/failed/unknown append, unchanged business state, and safe public output. Existing wrapper returns an in-memory description only. |
| AU-006 stale prefix; DP-007 restored ledger | `durable journal refuses a receipt absent from ledger replay state` | Authenticated current full history, pending/fence coverage and independent witness; local coherence cannot authenticate an old or altered snapshot. |
| AU-007 no ambient export; AU-008 private denial; AU-009 queue full | `AU-007 no fallback: Transmission has only Sent and Withheld (an exhaustive match without a wildcard), and Withheld carries nothing`; `AU-009 a page limit of 0 or of max_page()+1 is refused (LimitOutOfRange)` | Real append queue and bound, policy-safe host errors, no diagnostic bypass, current grant/sink serialization and real-host adversarial evidence. |

Before implementation, review the one-call host/audit API and event vocabulary,
the exact authority and policy inputs, event-ID allocation and binding, the
transaction/store/witness ordering, denial append semantics, sink/index
contracts, resource limits, and a cross-feature crash matrix. Independent
security review remains outstanding. No AU-004–006 or DP acceptance scenario is
closed by this design note.
