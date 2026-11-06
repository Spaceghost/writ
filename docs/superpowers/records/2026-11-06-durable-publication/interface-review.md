# Durable publication: interface and threat-model review

Status: first-party design review, not an independent security review. This
record describes a proposed integration. No transaction, durable storage,
receiver protocol, confined worker, or recovery witness is implemented here.
The normative proposed requirements remain DP-001–008 in
`openspec/changes/add-durable-publication/specs/durable-publication/spec.md`.

## Existing path and the gap

`HostPublication.publish` checks `P.current`, looks up the worker's seal,
compares the current artifact fact and checks zero writers, re-resolves the
worker's session and identity at the context's time, checks phase, exact plan
and invocation replay, and calls `DataOS.commit_from_capability` once. That
facade re-resolves the frontend descriptor and runs `Backplane.commit`, whose
checks include current approvals, epochs, funding, original-graph verification,
destination policy, and the actual backend effects. `p_artifact` then requires
the committed artifact to match the seal. A successful `Published` contains
the proposed primitive state, session, ledger, and a `Publish{intent}` effect;
no storage operation happens in this call.

This effect is **not** an instruction a durable-profile binding may execute
immediately. The storage transaction must first make the exact result and its
replay state durable. The existing `P.Publication` persists only invocation,
digest, and destination in the pure model. `reconcile` compares those fields;
it neither checks a changed policy or backend nor writes storage or spends.

`AuditEvent.audited_commit` calls `DataOS.commit_from_capability` itself and
projects an event and decision-time policy. Calling it separately from
`HostPublication.publish` would evaluate two commits and can project an
acceptance even when a later host seal, plan, or artifact check refuses. Its
untrusted public `Recorded` constructor is not evidence of an authenticated
wrapper result. Audit integration must project the **final host result** from
the one commit and authoritative subject/context, or extend that path to
produce a corresponding record; it must not treat a facade acceptance as a
published event after an outer refusal. Review the event vocabulary and update
the contract if needed before asserting this integration is complete.

## Proposed serialization boundary

The monitor supplies current authoritative state; a worker supplies neither a
caller nor capability, authority, revision, sink-registration, storage outcome,
or witness facts. Under one serialization protocol the monitor evaluates the
existing final checks against a complete authoritative snapshot and stages the
full resulting `WriteIntent`, exact sealed artifact, finished session, ledger,
primitive replay state and any mandatory audit record and policy. The native
transaction compares the revisions or equivalent generation values for **all**
facts on which the evaluation depends, including identity, grants, policy,
graph, sink, session, ledger and replay state. It commits the staged values
atomically or makes none of them authoritative. A single session/ledger CAS
is insufficient if revocation or policy state can change outside it. The
clock/deadline and seal/writer facts need a native serialization contract too;
their safety cannot be inferred from version fields on unrelated records.

A storage acknowledgement is an authenticated fact from the registered storage
binding, not a worker-controlled `committed` boolean. A success permits a
monitor transition that selects the stored intent for delivery; conflict and
failure preserve the authoritative pre-transaction state. A lost acknowledgement
is **unknown**, not failure: it blocks a fresh spend or publication until an
authenticated transaction lookup determines the outcome. The profile's host
integration must quarantine and never execute the preliminary `Publish` effect;
the model alone cannot force an arbitrary host to do this. No profile is
qualified until this boundary is implemented and tested.

One possible implementation is a monitor-owned transaction state machine that
calls the existing host transition once and stores its returned intent as a
provisional value, never as an admitted effect. Its integration must ensure no
other host path can bypass the transaction. This is a design direction, not an
assertion that the public Bend types make that enforcement automatic. Event
creation needs a reviewed host-level wrapper around the same result, not a
second facade invocation. If the existing API cannot enforce the barrier, change
that API with corresponding review and tests rather than introducing a parallel
release route.

## Exact recovery and trust assumptions

The complete committed record includes the intent's plan, output policy,
confidentiality and integrity label, backend and artifact; the destination in
the plan; session and ledger transition; consumed invocation and receipt; and
any policy-bearing audit record. The record's encoding and equality must cover
each field and its version. A public data constructor or a digest supplied by a
caller is neither a seal nor proof of an authentic committed record. Encoding,
integrity, private storage and authoritative reads are explicit host obligations.

Receiver idempotency is a sink-specific authenticated protocol: a duplicate of
the same committed invocation/artifact/scope must be recognized, and a changed
scope using the same key must be rejected. An outbox retry alone provides no
proof that an external sink publishes once. A registration is effective only
when installed by the monitor and backed by separately reviewed sink evidence.

Recovery of a previously committed record can continue in its original scope
after a later revocation; new authorizations require current authority. A
rollback witness must authenticate both the recovered checkpoint and current
authority/replay high-water marks. The witness/storage update ordering and
crash behavior are not yet designed or qualified. If they cannot be reconciled,
the host must fail closed rather than claim rollback resistance.

## Requirement-to-evidence matrix

| Requirement | Existing evidence | Work needed; not yet evidence |
| --- | --- | --- |
| DP-001 durable before visible | Pure `HostPublication.publish` returns a proposed effect; no atomic store | Model barrier, then native atomicity and visibility/crash tests |
| DP-002 current revisions | PH-009 model gates and current session/ledger checks | Complete transaction read set, conflict model, concurrent native CAS test |
| DP-003 revocation ordering | PH-009 model tests live identity/commit gates | Both serialized race orders in model and qualified host |
| DP-004 exact recovery | PH-009 model checks invocation, digest and destination only | Bind full intent, policy, backend and billing scope; native integrity and substitution tests |
| DP-005 sink deduplication | None | Model retry/changed scope; authenticate and test an actual receiver protocol |
| DP-006 inherited policy | Backplane computes output policy; recovery record omits it | Exact persisted policy checks and real reload/copy tests |
| DP-007 rollback resistance | Ledger rejects replay against current state; AB-006 states the host obligation | Model fail-closed witness and native authenticated checkpoint/recovery evidence |
| DP-008 unsupported sinks | None for durable profile | Monitor-owned registration and default refusal; evidence for each supported sink |

## Review findings and decisions still needed within implementation

1. Specify how the transaction gates every relevant revision and time-dependent
   fact across the serialization point. Do not assert the model proves native
   atomicity.
2. Refactor or wrap the host publication result so only the post-durability
   route can produce an executable release for this profile. Audit projection
   must describe the final result of this same path.
3. Specify full-record canonical encoding, policy comparison and integrity;
   existing `reconcile` is intentionally too narrow for DP-004/006.
4. Choose and test the witness and receiver contracts before checking the
   corresponding acceptance tasks. Neither has been selected.
5. Independent security review and model/native tests remain outstanding.

## Concrete authentication gap probe

A synthetic Bend probe took the modeled committed state, added receipt 9999
to the ledger's `seen` IDs, changed the journal entry's receipt to 9999, and
then inspected the unchanged invocation, request and intent using receipt 9999.
`inspect` returned `Matches`. The added receipt is structurally valid replay
state, and the existing ledger has no receipt-to-committed-invocation mapping,
so the pure coherence checks cannot establish that this was the receipt used
for that invocation. The reproducible probe
`bend verification/probes/durable-journal-authentication-gap.bend` printed
`MATCHES: pure coherence did not authenticate the original receipt`; it did not
use or alter a real store. This is the documented trusted-journal
precondition, not recovery-integrity evidence. An authenticated complete
transaction record and current witness are required before this model result
can support a recovery decision. Do not freeze this acceptance as a security
law or treat it as a permitted production substitution.
