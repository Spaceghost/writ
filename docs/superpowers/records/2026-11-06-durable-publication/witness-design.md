# Rollback witness: threat and requirements review

Suppose receipt R was consumed after a backup was made, and the host restores
that backup. The restored ledger may be internally valid and show R as unused.
A current, authenticated view of the relevant authority and replay history is
needed before the monitor can authorize another publication. Today no such
witness, storage protocol, or native recovery path is implemented; the existing
journal tests use synthetic monitor-owned state. In particular, matching
in-memory records and revision numbers do not establish current history.

This is a design review for the proposed
[durable-publication change](../../../../openspec/changes/add-durable-publication/specs/durable-publication/spec.md),
not an implemented protocol or a new contract. Its DP-007 stale-backup scenario
and baseline [AB-006](../../../../openspec/specs/authority-boundary/spec.md)
remain unqualified; see the
[traceability record](../../../../openspec/traceability/durable-publication.md),
[recovery design](recovery-design.md), and [lookup and fencing design](lookup-fencing-design.md)
for current evidence and gaps.
No acceptance task is completed by this note. Independent security review,
a selected host, and real confinement and crash evidence remain outstanding.

## Threat and trust boundary

Treat storage contents, backups, local counters, log positions, network replies,
and public Bend records as potentially stale, replayed, reordered, copied,
truncated, or substituted. A witness service or protected primitive would be
trusted only for explicit guarantees about identity, currentness, serialization,
continuity, availability and its own recovery. The host binding may translate
native facts and perform admitted operations; decisions about authority,
reconciliation and effects remain in Bend. Possession of a descriptor, native
capability, signed-looking record or local secret alone is not portable caller
authentication and cannot turn untrusted data into a current witness.

The selected profile must name who owns the witness, who can advance or read
it, the isolation and persistence boundary, and which compromises it can resist.
A witness rolled back with the store, or reset or cloned without detecting its
incarnation, cannot detect that rollback. A witness sharing the compromised
administrator or signing key with the data store may fail under that compromise;
its independence must be justified, not assumed. If no independently current
trust basis remains after simultaneous loss, the monitor must remain unavailable
for new publication until an authorized recovery process establishes one.

## What must be bound

The authenticated history must cover every durable transition that can change
the truth of a later publication decision or replay check, not only the
publication sequence. The selected design must enumerate and serialize its
complete read and write domain, including:

- Authority-bearing identity, bindings, grants, revocations, capabilities,
  policy and graph epochs, inheritance and source-version facts used by the
  final gate, plus any sink registrations or issuer changes in that domain.
- Session and ledger transitions, reservation and consumed receipt identities,
  invocation replay history, committed exact requests and intents, and required
  audit events with decision-time policy. This includes deletion, expiry,
  cancellation, reissuance and compaction where they affect future decisions.
- The namespace or tenant, store and witness identities, format and algorithm
  versions, incarnation, ordering position, and a commitment to the complete
  state or authenticated history to which that position refers. Binding must
  rule out a valid record from another store, tenant, history or format being
  accepted as the current one. The commitment scheme and its canonical full
  transaction representation are not yet selected or reviewed.
- The ordering and authenticated provenance of every included authority update
  and transaction, including independently persisted subsystems. If a single
  serialization domain cannot cover them, the profile must specify how their
  atomicity, cross-store order and recovery are established. A vector of
  unrelated counters without authenticated linkage is insufficient.

Time, expiry, artifact sealing and writer exclusion are live facts as well as
potentially recorded facts. A witness to an old snapshot does not make an old
clock reading, seal observation or grant current at a later commit. The host
must acquire and serialize the relevant live facts at the final gate, under a
reviewed host contract. Nor does an identity field authenticate sealed bytes.
The experimental single-entry codec omits surrounding state, audit and witness;
it cannot serve as this complete commitment.

## Currentness, identity and equivocation

An authentic old checkpoint is still old. A signature or MAC on a response
proves neither that it is the latest response nor that a stale replica or forked
witness has not answered. A candidate protocol must specify an authenticated
current read against the correct witness identity and namespace, with an
explicit consistency guarantee. If it uses challenges, it must prevent replay
of an old challenge/response across crashes and cloned or restored monitors;
challenge binding alone does not make a lagging or equivocating signer current.
The freshness mechanism and its trust assumptions remain open.

Currentness must also remain meaningful at the subsequent serialization point:
if another writer can advance authority or spend state after the read, the
transaction must recheck or fence against the relevant current generation under
the selected protocol. A time-of-check observation alone does not serialize a
later write. The actual enforcement, including concurrent monitors and network
partitions, is a host obligation and has not been modeled here.

A design must state what prevents or detects two different histories claiming the
same witness position or incarnation. This includes concurrent writers,
failover, restored witness state, cloned keys and malicious or compromised
witness operators. Sequence equality, a larger number, or a well-formed hash
chain by itself does not establish a unique current branch. If uniqueness or
currentness cannot be established, do not choose the more convenient branch:
block new publication, preserve the conflicting evidence privately, and use an
authorized reconciliation procedure. Whether any equivocation is detectable
under a given trust model must be stated; a fully compromised sole witness can
lie consistently unless another protected observation constrains it.

## Crash ordering and candidate observations

The following is a requirements matrix, not a selected algorithm. “Matching”
means the same authenticated namespace, incarnation and complete committed
history, not merely an equal numeric position. A real design must also specify
atomicity, durability and unknown acknowledgements for each step.

| Observation after recovery | Required safe behavior | Missing basis |
| --- | --- | --- |
| Store and witness demonstrably match | Continue only after current authority, time, seal, sink and serialization checks for any new transaction; previously committed intent remains exact | Authenticated current reads and a serialization protocol; matching data alone is insufficient |
| Store behind witness, or backup restored | Block new publication and do not infer the missing spends or roll back the witness | Authenticated retrieval and reconciliation of all missing history, or an authorized recovery process; no such process exists |
| Store appears ahead of witness | Block new publication and delivery until a reviewed protocol establishes whether an authenticated extension is legitimate and updates or reconciles the witness | Provenance and continuity of every intervening authority/replay transition, not just a higher store counter; no extension protocol exists |
| Same position, different commitment or incarnation | Treat as conflict, preserve evidence and block; do not silently select either state | Trusted fork detection, unique identity and authorized reconciliation |
| Witness unavailable, untrusted, stale, reset or response uncertain | Remain unavailable for new publication; do not fall back to local state or infer a failed update | Witness availability, recovery and anti-replay contract |
| Transaction or witness-update acknowledgement lost | Treat outcome as unknown; do not authorize a replacement, advance the witness twice or release an unverified result | Authenticated exact lookup and a fence that prevents a still-running earlier operation from later conflicting; no such protocol exists |
| Separate stores partially advanced or restored | Block until the complete cross-store authority and replay history is authenticated and reconciled | An atomic or otherwise reviewed cross-store serialization and recovery protocol |

No recipient-visible output can precede durable authorization and whatever
current witness evidence the chosen profile requires. A witness-ahead state is
not automatically permission to publish, and an independently authenticated
stored intent is not a live authorization for a changed operation. Once a
transaction is genuinely committed under the required ordering, subsequent
revocation prevents future authorization; it does not alter the committed scope.
Any retry still requires the separately qualified sink protocol.

## Pending submissions and rollback

A local pending marker written before submission is not enough: after the
submission escapes, a crash can restore a snapshot from before the marker while
the original submission is still in flight. The restarted monitor might then
issue a conflicting authorization even though the store may later accept the
original. A current witness for completed transactions alone does not close
this window if it can still match that pre-marker snapshot. Conversely, an
anchored marker does not fence a store that can independently accept an old
submission after the monitor declares it aborted.

Any candidate recovery design must preserve knowledge of every submission
that can still commit across monitor restart, store restore and witness recovery,
and control all writers with access to that store and transaction namespace.
One possible approach to analyze is a durably recorded, witness-covered pending
identity before submission can escape, with an authenticated store fence or
terminal result before that identity is cleared. This is a proposed ordering to
review, not a claim that such a marker or primitive exists, nor the only possible
design. A single qualified atomic system or another protocol might establish
the same invariant differently. If a marker can be lost, copied into another
namespace, silently replaced or pruned before every old writer is fenced, it
cannot be used to declare the outcome absent.

The marker would have to bind a non-reusable transaction identity, the intended
store and authority domain, exact transaction scope and immutable proposal, and
the witness incarnation or generation required by the selected protocol. It is
a private record of uncertainty, not a committed spend, authority grant, proof
that the artifact is sealed, or permission to release. Current grants, policy,
time, seal and other final facts still need revalidation at serialization; a
marker must not freeze stale authority. After a crash, recovery needs an
authenticated result for that exact submission: either the full committed
transaction, or an authoritative terminal failure coupled to a fence proving
it and all equivalent old attempts cannot later commit. Ordinary absence, a
local timeout, a marker cancellation, and a witness counter do not supply that
proof. If the store cannot enforce the fence, or the required outcome or
current witness is unavailable, remain blocked.

If marker storage, the transaction store and witness advance separately, every
crash ordering must be accounted for, including marker-only, store-ahead,
witness-ahead, acknowledgement loss, restored backups and simultaneous recovery
of multiple monitors. Reconciliation must authenticate the cross-store history
and fence conflicting in-flight writers before clearing or replacing a marker;
it cannot assume the three writes were atomic. A newly recreated monitor,
rotated key or restored old witness must not bypass this condition. Native
fault-injection evidence must include a delayed original submission arriving
after a negative lookup and after attempted marker deletion.

## Key, identity and lifecycle changes

A witness key, service identity or instance change is itself an authenticated,
ordered authority transition. Define the authorized updater, trust roots,
namespace and epoch, how old and new identities are linked to the same complete
history, how concurrent old writers are fenced, and how a monitor distinguishes
rotation from rollback, clone or replacement. A certificate or new key supplied
with the recovered store is not self-authenticating. A transition must cover
both ordinary rotation and crash/lost-acknowledgement ordering; accepting either
key indefinitely can permit a stale or compromised writer to fork history.

Revocation, suspected compromise, disaster recovery, backup restore, migration,
retirement, history compaction and witness replacement need separate reviewed
procedures. Recovery after compromise cannot assume the compromised key proves
its own revocation or that an attacker deleted captured secrets. Checkpoints and
pruning need authenticated continuity of all still-relevant spent and authority
facts; discarding a receipt or old grant record merely to fit a bounded journal
can reopen replay. Key loss or an unverifiable transition causes unavailability,
not automatic creation of a new trusted history. The procedure for establishing
a replacement root and the operator authority it requires remain undecided.

## Evidence required before a host claim

For each selected platform, document the exact primitive, trust and source
inventory, identities, configuration, durability and current-read semantics,
serialization domain, key protection, provisioning and revocation path, and
independence assumptions. Test the actual host with power-loss or fault injection
at every store/witness commit and acknowledgement boundary; restore backups of
both sides separately and together; force stale, reordered, duplicated and
forged replies; race writers, revocation and witness updates; exercise a fork,
witness restart and key rotation; and verify fail-closed behavior and exact
reconciliation. Include loss of all trusted recovery evidence and unsupported
configurations. Qualify the receiver and sealed artifact separately.

Link each claimed result to the precise DP scenario, host version, commands,
artifacts and observed failures, and distinguish model tests from actual host
and confinement evidence. A passing pure-state test, OpenSpec validation, CPU
fallback or synthetic signature is not a witness, native crash test, GPU test,
or production qualification. No concrete witness profile or such evidence
currently exists in this lane.
