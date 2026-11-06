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
Changing the backend while storing the host gate's committed result was also
caught by the check comparing the journal's full intent to that gate's result.

The pinned Bend 2.0.39 `bend Tests.bend` run passes 2007 checks (1942 baseline
plus 65 new checks). `bend PROOF.bend` reports `ALL PROOFS CHECK` for the
existing laws; it does not prove these new transitions. Lean is not on PATH,
so no kernel verdict is claimed. The full JS corpus ran in the existing
host QuickJS harness: 2007 passed, 17,657 ticks, no exception; this is not a
Genode guest run. OpenSpec 1.16.0 strict passed 44/44, structural validation
only. The native CPU build and run (`+RTS --threads 4 --gpu off`) passed the
same 2007 checks; its output is byte-identical to `bend Tests.bend` (SHA-256
`66f490b4c4ef6486679efc07ed877e26f1a524d705d3c8d795dbef009178c77e`).
The subsequent source-header-only clarification has identical implementation
tokens and its focused tests pass. No GPU test is claimed.

## Still required

The actual durability barrier and unknown-outcome reconciliation, complete
authenticated checkpoint/witness protocol, protected canonical storage,
sink-specific deduplication, correct audit projection of the final host result,
native isolation/sealing, crash injection and independent security review all
remain open. Transition errors and inspection results can reveal protected
state, including invocation presence and capacity; they cannot be exposed to
an untrusted caller without separately authorizing and policy-gating the
observation. The source-header clarification was checked against the prior
revision with implementation tokens identical after comments were removed.

The current reference journal never prunes records. At 64 entries it refuses
every additional authorization; that is a fail-closed capacity limit, not a
production retention or compaction design. A future bounded implementation
needs an authenticated checkpoint and retained replay/epoch evidence before
retiring history. Existing host publications without corresponding complete
journal records also deny; migration must authenticate and reconcile them.
