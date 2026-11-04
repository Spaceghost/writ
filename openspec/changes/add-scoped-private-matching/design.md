# Scoped private matching design

## First use

An importer asks whether one sealed upload substantially overlaps a partner's
registered collection. Both parties approve the search. The partner does not
publish its catalog, and the importer cannot submit an arbitrary list of guesses
under the upload's authority. A reviewer receives only the specifically approved
case handles. Reading a matched document or deleting the import is a separate
decision.

Begin with exact whole-object equality in a mutually trusted, confined matcher.
Canonical text or chunk overlap needs a registered normalization profile and
accuracy tests before it is enabled. Semantic similarity remains deferred behind
a separately reviewed matcher profile. This design does not treat an exact hash
comparison as semantic detection.

## Authority

| Participant | Controls |
| --- | --- |
| Import and corpus authorities | Whether their exact input snapshots may participate, which executor sees them, and which evidence may be released |
| Writ monitor | Authenticated scope, current grants, source and control dependencies, query accounting, artifact registration, and final release |
| Matcher | Execution of the pinned comparison and construction of a private candidate result; no independent publication authority |
| Result recipient | Only the disclosed receipt fields and separately granted follow-up operations |

All contributing origins on both sides must approve the comparison and its
disclosure terms. A controller's name in a submitted record is not authentication.
Import authority does not authorize scanning an uninvited corpus. A search grant
does not grant general payload reads, quarantine, revocation, or deletion.

## Search contract

One immutable, versioned search contract binds the authenticated participants,
invocation, import object versions and sealed identities, and complete declared
corpus snapshots. It also fixes the execution and privacy profile, provider,
matcher and normalizer versions, matching parameters, threshold, maximum result
count, ranking and tie rules, recipient, output fields, leakage profile, authority
epochs, expiry, budget account, and retention terms.

Changing any of those terms requires new scoped approval. Monitor-owned records
use a bounded canonical encoding; neither JSON nor a caller-created public Bend
record is an authority credential. Corpus identifiers in the contract are opaque
where disclosing a collection's identity is itself restricted.

The registered representation builder reads the actual sealed import. It binds
its fingerprints or chunks to that artifact and to the approved algorithm.
Accepting arbitrary caller-supplied fingerprints would turn an import check into
a guessing interface. A commitment proves consistency with committed data, not
that the data is authentic, lawfully held, or owned by the party submitting it.

## Complete scope

The corpus snapshot records the complete approved search universe. Before
evaluation, the monitor verifies input eligibility against current authority and
that the complete declared snapshot remains available. Indexes need coverage
evidence for every object in that snapshot. Pruning is acceptable only when the
qualified matcher establishes that the omitted work cannot change its result.

A proof that returned items belong to a corpus does not establish that all of
the corpus was searched. The same applies to a cryptographic protocol that lets
the sender choose a subset of a committed set. Missing shards or uncertain index
coverage yield an incomplete search, not an empty result. Approval for a smaller
corpus defines a new search; it cannot silently narrow an existing one.

Permission to compare an input and permission to report its match are separate.
Result eligibility precedes ranking. A jointly approved multi-corpus search ranks
only its reportable candidates under its approved global or per-corpus rule.
Uninvited or newly ineligible material cannot take a result slot, change an
authorized candidate's rank, or leak its existence through omission or counts.
If an approved required corpus becomes unavailable or unauthorized, the search
cannot claim completion under the old contract.

## Execution profiles

| Profile | Inputs visible to | Qualification boundary |
| --- | --- | --- |
| Trusted matcher | The specifically approved matcher and its declared trusted computing base | Real confinement, exact input binding, complete comparison, and controlled result publication |
| Cryptographic private matching | Only what the selected protocol and its agreed leakage model permit | Protocol security, input authorization and consistency, corpus coverage, implementation behavior, and the complete release path |

The first profile requires explicit mutual consent to the matcher seeing both
inputs. It cannot be described as cryptographically hiding those inputs from
that executor. Switching to it when a requested cryptographic profile fails is
not a permitted fallback.

The cryptographic profile remains disabled until independently reviewed evidence
supports the claimed malicious-participant model and the exact chosen
functionality. PSI, MPC, and OPRF name families of techniques; none alone supplies
the whole contract. An OPRF can hide a client's input during PRF evaluation while
still allowing the client to learn from its permitted results. Published hashes
of guessable text or identifiers invite offline dictionary comparison.

Cryptographic comparisons need authorized inputs, consistency across repeated
executions, complete declared coverage, authenticated channels, and a pinned
implementation. Qualification also addresses side channels, malformed inputs,
collusion assumptions, permitted aborts, and protocol metadata. Bend authorship,
GPU acceleration, a successful benchmark, or a semi-honest proof does not by
itself qualify a malicious-participant privacy claim.

## Bound disclosure before release

Return at most the approved number of candidates meeting the approved threshold.
An unconditional top-k result could reveal the best available candidates even
when none is a useful match. The default receipt contains an opaque case handle
and an approved match category. Names, paths, owners, excerpts, numerical scores,
ordering, and follow-up links are separate disclosure choices.

The trusted matcher or secure computation applies these limits before the
recipient learns any result. Receiving an entire intersection and hiding some
entries in the user interface already violates a smaller result allowance.
Cryptographic protocols whose outputs exceed the contract are unsuitable without
an independently qualified composition that enforces the boundary.

The contract separately specifies leakage through result count, rank, empty
answers, status, errors, timing classes, packet sizes, and disclosed corpus
metadata. A profile may deliberately permit some of those observations. When it
promises to conceal one, it needs matching framing, scheduling, or protocol
evidence; unsupported promises deny admission. Errors never enumerate uninvited
collections. General hardware covert-channel resistance remains limited to the
qualified host threat model.

Import disposition is also observable. Admission, quarantine, deletion, callbacks,
and file availability can reveal a verdict even when its receipt is hidden.
Either authorize that coarser decision explicitly under the leakage contract,
or retain a uniform approved pending/review response until separately authorized
disposition. A private reviewer result cannot silently drive a public side effect.

Repeated exact answers are a membership oracle even when the protocol correctly
hides intermediate data. Input commitments and query budgets limit this risk;
they do not turn an observable answer into zero disclosure. Accounting is tied to
authenticated principals and owner-defined scope groups, not a caller-chosen
session ID. Multiple accounts cannot be assumed to represent different people
without an identity policy that supports that assumption.

## State and recovery

| State | Permitted action |
| --- | --- |
| Proposed | Validate the contract and obtain joint approval; no protected comparison |
| Admitted | Durably reserve the applicable query allowance and prepare the approved worker |
| Running | Compare only the pinned inputs; retain results inside the approved boundary |
| Sealed | Register the exact result, completeness evidence, dependencies, and consumption record |
| Durably authorized | Publish or redeliver only the recorded result under its recorded authorization |

Failure before authorized publication leaves no recipient-visible match result.
If the import requires this check, an incomplete, denied, expired, or unknown
execution leaves it blocked from admission under that check. Any public status
uses the approved leakage contract. Matching cannot publish its own error text.

Reserve allowance before any comparison-dependent observation can occur.
Execution that may already have disclosed information consumes its applicable
allowance, including a permitted empty answer. Aborts and uncertain recovery do
not automatically refund disclosure allowance. Retrying a completed invocation
redelivers its existing receipt; it does not evaluate new inputs for free.
Concurrent requests use serialized account revisions. Recreating a session,
changing a nonce, or restoring an old checkpoint cannot reset cumulative limits.
Unknown accounting high-water marks disable new searches until reconciled.

A rejected final release does not itself mutate release state or consume a new
release allowance. It also does not undo an earlier, separately recorded
comparison observation or its consumption. This preserves the atomic rejection
rule of controlled disclosure while accounting for information already exposed
by an approved protocol or operational channel.

Immediately before durable release authorization, the Bend gate rechecks current
participants, grants, epochs, exact scope, applicable accounting state, result
schema, artifact identity, and release evidence. Revocation ordered before that
point denies release. Afterward, recovery follows the existing durable-publication
contract for that exact result; it does not resurrect permission for new work.

## Results remain protected data

A candidate receipt inherits the original policies and origin records of both
inputs, including metadata and control inputs that can influence ranking,
completion, or a negative answer. Merely displaying fewer bytes is not grounds
for weakening those restrictions. A sound, reviewed independence analysis may
establish that an input does not influence a particular result; absence from the
visible positive list is not such an analysis.

If the recipient lacks the original result clearance, publication requires the
versioned [controlled-disclosure contract](../add-controlled-disclosure/design.md).
The release view retains the original policies and full origins alongside the
specifically authorized effective policy and release chain. It is not converted
into a legacy source policy that silently drops original obligations. The final
gate applies to the actual sealed result, not a worker's claimed label or the
name of an approved matcher.

Original-graph verification precedes that separate release transition. The new
release-aware gate keeps integrity, operation-kind limits, approved code, source
charges, compute accounting, and sink-effect checks intact. It does not pass a
lowered candidate into the v1 verifier or ask the v1 transfer path to reinterpret
missing origin restrictions as authorization.

Fingerprints, indexes, evidence, caches, and retained receipts have scoped access
and retention rules. A comparison-specific handle or fingerprint does not become
a globally reusable lookup key. Reuse in another scope needs its own authority.
Expired working material is retired according to its approved retention terms;
retained audit evidence remains protected rather than publicly searchable.

## Interpret evidence narrowly

An exact match establishes the qualified equality relation, not theft, ownership,
or a right to control the import. Canonicalized or chunk matching adds false
positives and false negatives that its acceptance corpus must measure. Semantic
similarity adds model-specific behavior and remains a separate future profile.
Encoding or encryption can evade an external-import matcher; faithfully retained
provenance inside Writ supplies a different guarantee.

A completed empty search means no qualifying match was found within the named
scope, snapshot, and matcher. It says nothing about unsearched collections or
other matching rules. Uncertain execution is not an empty search. A positive
receipt may support review or a separately preauthorized quarantine decision;
it cannot mint read, ownership, revocation, or deletion authority. Cooperative
deletion has its own authorization and completion evidence.

## Evidence and rollout

This package contains proposed acceptance contracts and a source-backed design.
It contains no matcher implementation, cryptographic proof, host qualification,
or GPU execution result. First implement the contract and exact trusted-matcher
profile in Bend with a public example that exercises permitted disclosure and
denied probes. Qualify each native host separately. Keep stronger profiles
disabled until their actual protocol, matcher, and host evidence is recorded.

Rollback stops new searches, reconciles reserved work, and preserves consumed
allowances, authority epochs, sealed results, and durable release records.
Unknown profile or contract versions are denied; rollback never substitutes a
broader disclosure profile.

## References

- [RFC 9497: Oblivious Pseudorandom Functions](https://www.rfc-editor.org/rfc/rfc9497.html)
  specifies OPRF, VOPRF, and POPRF properties. Sections 7.3 and 7.4 address domain
  separation and secret-dependent timing. It does not specify Writ's complete
  search, input-authorization, or result-release contract.
- [PICS: Private Intersection over Committed (and reusable) Sets](https://www.usenix.org/conference/usenixsecurity26/presentation/goel)
  studies inconsistent-input attacks across repeated PSI executions. Its reported
  construction enforces exact receiver-set consistency but permits sender subsets;
  that distinction motivates the separate coverage requirement here.
- [Private Computation on Common Fuzzy Records](https://petsymposium.org/popets/2025/popets-2025-0031.php)
  demonstrates fuzzy record comparison using explicit rules, circuit PSI, and MPC.
  Its [paper](https://petsymposium.org/popets/2025/popets-2025-0031.pdf) proves
  semi-honest security, not this proposal's malicious-participant profile or
  general private semantic search.
