# Recovery and rollback: design constraints for review

Status: **proposed only**. There is no durable store, authenticated witness,
receiver protocol, or crash-tested implementation in this lane. This note
spells out unresolved interfaces; it does not extend the current OpenSpec
contract or claim its acceptance scenarios pass.

## Example

An authorization for invocation I consumes receipt R and records artifact A
for destination X. The host crashes after the receiver accepts A but before
the host records the acknowledgement. A safe restart must retain the original
policy and billing scope, recognize I/R as spent, and retry only the recorded
intent through a sink that deduplicates it. If the host restores an older
snapshot that predates I, it must not accept the old receipt again.

## Distinct records and trust boundaries

1. **Committed transaction.** A protected store atomically holds the
   authorization, complete intent, request and receipt, updated session,
   ledger, host replay state and any mandatory policy-bearing audit record.
   The native binding reports only facts about the registered storage operation;
   it does not create an authorization. The transaction's concurrency check
   must cover every input needed by the final Bend gate. A journal revision
   that leaves live grants, policy epochs, clock or sealing facts outside its
   serialization domain is not enough.
2. **Authenticated recovery anchor.** A separately protected authority has a
   current commitment to the relevant epoch and replay history, including
   every authority or spend transition needed to prevent rollback. A locally
   supplied counter, matching untrusted digests, or public Bend record is not
   an authenticated witness. Its namespace, identity, content commitment,
   update authorization, monotonicity and failure semantics must be specified
   and tested for the selected host.
3. **Receiver identity and idempotency.** The monitor registers a specific
   supported sink and scope. That sink must authenticate and durably deduplicate
   the committed invocation, artifact and scope, rejecting conflicting reuse of
   a key. Sender-side retries alone cannot establish one logical result. The
   receiver's exact supported guarantees are a qualification prerequisite.

## Existing native primitives are not this transaction

The [WritFS native snapshot backend](../../../../writfs/README.md) creates private
Btrfs snapshots and ZFS clones, but its documented model commit and native
creation are not one atomic durable transaction. It does not publish a
logical object or provide this recovery journal. The
[Linux mounted-view canary](../../../../contrib/native-hosts/linux/README.md)
also explicitly describes its event journal as non-durable. Neither is an
authenticated rollback witness or a deduplicating receiver. They may inform a
future storage integration, but their existing evidence does not close a DP
requirement or qualify a protected host.

## Failure ordering to resolve before implementation

- A transaction outcome may be **unknown** when an acknowledgement is lost.
  Do not execute the provisional host effect, spend again, or assert failure.
  Query the authoritative store by a transaction identity that cannot be
  repurposed for a different request; if the result cannot be authenticated,
  remain unavailable.
- If local transaction state and the recovery anchor are updated separately,
  their ordering is security-sensitive. A crash can leave storage ahead of or
  behind the anchor. A behind or unprovable state cannot authorize new work.
  A storage-ahead state may be reconciled only by a separately specified and
  authenticated extension protocol; a numeric comparison alone does not prove
  that it is the legitimate next transaction.
- The witness must cover **all** relevant authority and replay updates, not
  just a publication counter. Otherwise an old capability, grant, epoch,
  ledger, or receipt snapshot could appear current even when the publication
  head matches. If the system has several independently durable stores, their
  cross-store commit and reconciliation protocol must be specified as well.
- No recipient-visible delivery may occur until the selected protocol has
  made both the committed transaction and the rollback evidence required for
  that profile reliable. Otherwise a crash followed by restoration could
  expose an artifact and then erase the only evidence of the spend.
- Once durable authorization and the required anchor are established,
  revocation does not rewrite the recorded outcome. A replay uses the exact
  stored request, receipt, artifact, backend, destination and policy. Any new
  authorization rechecks current revocation and authority at serialization.

## Evidence matrix

| Fault or adversary | Required result | Present evidence |
| --- | --- | --- |
| Crash before transaction | No visible output or committed spend | Pure model rejects without changing input; native atomicity missing |
| Lost transaction acknowledgement | Unknown until authenticated lookup and fencing; no new spend or release | Monitor-local blocking model only; persistent tracking, authenticated lookup, fencing and native failure tests missing |
| Storage ahead of anchor | Fail closed unless authenticated extension reconciles it | No witness protocol or test |
| Storage behind anchor or restored old backup | Fail closed for new publication | No witness protocol or test |
| Revocation before authorization | Final host gate denies | Pure journal test only; native ordering missing |
| Revocation after committed authorization | Original committed scope remains | Pure inspection test only; no durable recovery |
| Receiver accepted, acknowledgement lost | Exact retry; receiver suppresses a duplicate | Intent comparison only; receiver protocol and native crash test missing |
| Changed policy, destination, backend, receipt or quote | Deny substitution | Pure comparison tests against a trusted record; stored-record integrity missing |

## Decisions that cannot be inferred from model tests

Select a storage and anchor implementation, its trusted owner and namespace,
the transaction identity and authenticated encoding, the full serialization
domain, an idempotent receiver protocol, the crash-reconciliation algorithm,
and how authority epochs are included in the protected history. Review those
choices before enabling effects or claiming DP-001–008 on a host. A failed or
unsupported native primitive remains a denied profile, not an excuse to
relax these requirements.

## Lost acknowledgement: model and unresolved lookup race

Suppose transaction T is submitted, its acknowledgement is lost, and a read
returns “absent” before T reaches its serialization point. Treating that read
as proof of failure allows the monitor to authorize another spend while T can
still commit. A safe negative result requires an authenticated, authoritative
operation that also fences T from any future commit. Its scope must cover the
same store, transaction identity and serialization domain as the original
submission; ordinary absence, a timeout, or a stale replica is insufficient.
A positive result must identify the exact committed transaction and its full
record, including session, ledger, replay and required audit state, not just an
entry or matching invocation. In either case, the separate current rollback
witness remains required before a host may use recovered state.

`DurablePending.bend` is a conservative monitor-local simulation of this gap.
It stages the existing journal transition once, retains the original and proposed
states, and blocks another attempt while pending or after a lost acknowledgement.
There is intentionally no resolution transition or delivery effect. The named
`DurablePendingTests.bend` checks exercise this blocking, repeated retries and
state preservation under synthetic inputs. A public constructor can fabricate
any model state, and a host can reconstruct an old `TxnReady`; the model does
not authenticate observations, fence a transaction, survive restart, serialize
other workers, or prevent a native binding from bypassing it. It is not a
transaction protocol, a new release path or proof of crash recovery.

The integrated Bend and Node suites pass 2,157 checks with identical output
(SHA-256 `d05bcd77076c6d9c81c82ccf929969a44a03947fa001e2551230ce6f4e7fd1ce`).
The host QuickJS harness passes 2,157 checks at 17,839 ticks without exception;
the eight new checks also pass as a native CPU executable. Removing the
unknown-state block or replacing a lost acknowledgement with a fresh state
causes named checks to fail. This samples two mutations, not a security review
or proof. Existing proof checks pass without a Lean kernel verdict, and
OpenSpec strict passes 44/44. The complete generated native CPU suite also
passes with byte-identical output using Clang `-O0`. The optimized native CPU
build also passes with byte-identical output; neither CPU run is a GPU or
Genode guest test.

The separate [lookup and fencing design](lookup-fencing-design.md) and
[rollback witness review](witness-design.md) detail candidate boundary
properties and cross-store failure cases. Neither selects an implementation or
changes the proposed acceptance status.
