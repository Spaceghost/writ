# Durable publication model: partial implementation report

Status: **work in progress**. No durable-publication acceptance box is closed.
This is a pure reference model. It performs no storage, publication, native
crash recovery, sink deduplication, witness authentication, or audit append.

## Implemented in this lane

- `DurablePublication.prepare` calls the existing `HostPublication.publish`
  once, retains its proposed state and full commit result, and discards its
  `PublishEffect`. A prepared record is not a durable authorization.
- `DurableIntent.intent_equal` structurally compares the complete write
  intent: exact plan, output schema and restrictions, every origin's full
  code and payment rules, DLM label tree, backend, and artifact. Equality is
  not authentication. It is stricter than semantic label equivalence.
- `DurableJournal` models a single pure update of host state, session, ledger,
  and an entry retaining the full request, receipt and intent. Its revision,
  invocation and receipt uniqueness, host and ledger coherence, and 64-entry
  bound are checked. `inspect` compares the retained intent and billing scope
  without emitting a release. Its answer is private monitor information.
- The journal is an idealized model. Its input must already be authoritative,
  authenticated and current; the model cannot establish those facts or prove
  atomic storage. A real host must serialize all authority, time, and sealing
  facts, not just the journal revision. The host record and ledger cannot
  reconstruct or authenticate all policy, backend or receipt associations.

## Checks and limits

The focused tests exercise successful preparation, refusal, stale revisions,
modeled revocation ordering, replay, changed artifact, backend and billing
scope, malformed host/ledger/journal relationships, full-state denial
preservation, and the record-count boundary. `DurableIntentTests` also varies
the complete intent's constituent restrictions. Mutation sampling removed
individual comparison and journal gates; the tests caught the sampled
mutations. The initial pass revealed missing tests for a policy owner, right
label branches, several coherence gates and the capacity guard; tests were
added and those removals then failed. This is not a complete security review.

The sampled intent removals covered the plan, output, label, backend and
artifact gates; the output fields; the origin object, restrictions, allowed
operations, code list and payment terms; both label trees, their left and
right branches, owner and delegate. The sampled journal removals covered the
authorization and inspection revision gates, host/ledger validity, duplicate
invocation and receipt checks, ledger replay membership, entry/intent plan
and invocation comparisons, host destination and artifact comparisons,
history coverage, inspection receipt/request/intent comparisons, and the
record-count and capacity gates. Mutants were run against copies under
`/tmp/writ-durable-publication/`, not against authoritative source. The
enumeration is a review aid rather than a claim of exhaustive mutation coverage.

The pinned Bend 2.0.39 `bend Tests.bend` run passes 2006 checks (1942 baseline
plus 64 new checks). `bend PROOF.bend` reports `ALL PROOFS CHECK` for the
existing laws; it does not prove these new transitions. Lean is not on PATH,
so no kernel verdict is claimed. The full JS corpus ran in the existing
host QuickJS harness: 2006 passed, 17,649 ticks, no exception; this is not a
Genode guest run. OpenSpec 1.16.0 strict passed 44/44, structural validation
only. The final native CPU build and output comparison are running separately;
no GPU test is claimed.

## Still required

The actual durability barrier and unknown-outcome reconciliation, complete
authenticated checkpoint/witness protocol, protected canonical storage,
sink-specific deduplication, correct audit projection of the final host result,
native isolation/sealing, crash injection and independent security review all
remain open. The model's `Matches` result cannot be exposed to an untrusted
caller without separately authorizing and policy-gating the observation.
