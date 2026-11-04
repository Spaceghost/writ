# Scoped private matching

## Purpose

Compare an approved import with specifically approved corpus snapshots and
release bounded evidence under a jointly authorized search contract. Exact
matching in a mutually trusted confined service is the first proposed profile;
cryptographic and broader similarity profiles require separate qualification.
No comparison establishes ownership, global cleanliness, or deletion authority.

## ADDED Requirements

### Requirement: SM-001 Both sides authorize the search

Search admission SHALL require current authenticated approval from every
contributing import and corpus authority for the same comparison, executor,
recipient, and disclosure scope.

#### Scenario: Jointly approved comparison

- **GIVEN** the import and corpus authorities approve the same search and result recipient
- **WHEN** all current admission checks succeed
- **THEN** that search may proceed within the approved scope.

#### Scenario: Import authority scans an uninvited corpus

- **GIVEN** the importer has approved its upload but the corpus authority has not approved comparison
- **WHEN** the importer requests a search of that corpus
- **THEN** the search is denied without revealing corpus contents or a match result.

### Requirement: SM-002 Approval binds an immutable search contract

Search approval SHALL bind exact input snapshots, participants, invocation,
provider, execution profile, matcher and normalizer versions, parameters,
threshold, result limit, ranking rule, recipient, fields, leakage profile,
epochs, expiry, budget account, and retention terms.

#### Scenario: Reusing the unchanged approved plan

- **GIVEN** a search contract remains unchanged and its authority remains current
- **WHEN** dispatch validates its complete scope
- **THEN** its approval applies only to that contract.

#### Scenario: Lowering the threshold after approval

- **GIVEN** a search was approved for threshold T and recipient R
- **WHEN** a request lowers T or substitutes recipient S under the same approval
- **THEN** the changed search requires new scoped approval.

### Requirement: SM-003 Representations bind actual approved inputs

Comparison SHALL use only registered representations derived from the actual
sealed import and approved corpus versions by the pinned representation builder,
with authenticated artifact and algorithm bindings.

#### Scenario: Fingerprints come from the sealed upload

- **GIVEN** the registered builder processes sealed import A under normalizer N
- **WHEN** the matcher verifies the resulting representation binding
- **THEN** it may use that representation only as evidence about A under N.

#### Scenario: Guessed fingerprints replace the upload

- **GIVEN** a caller has comparison authority for import A
- **WHEN** it supplies fingerprints of guessed documents as if they came from A
- **THEN** comparison rejects those representations.

### Requirement: SM-004 Completion requires complete declared coverage

A completed search SHALL establish coverage of every object in each approved
corpus snapshot through the qualified matcher and coverage evidence; missing or
newly ineligible inputs, membership-only proofs, and consistency with a chosen
subset do not establish completion.

#### Scenario: Complete qualified index

- **GIVEN** a current index covers every object in the approved corpus snapshot and every required input remains authorized
- **WHEN** qualified evaluation and coverage checks finish
- **THEN** the search may claim completion for that snapshot.

#### Scenario: Sender omits a committed shard

- **GIVEN** a provider proves returned items belong to the approved corpus but omits one required shard
- **WHEN** it claims that an empty result completes the search
- **THEN** completion is rejected and the search remains incomplete.

### Requirement: SM-005 Execution respects the approved trust profile

Dispatch SHALL use only the approved trust profile, with explicit mutual approval
of every executor that sees both plaintext inputs; a trusted matcher does not
satisfy a request to hide inputs cryptographically from that executor.

#### Scenario: Mutually trusted matcher

- **GIVEN** both sides explicitly approve matcher M and its declared trusted boundary seeing their inputs
- **WHEN** the qualified trusted-matcher profile is dispatched
- **THEN** M may compare those inputs under the approved confinement and output limits.

#### Scenario: Plaintext fallback for a private protocol

- **GIVEN** the search requires a cryptographic profile that conceals inputs from the executor
- **WHEN** that profile is unavailable and the service proposes a plaintext matcher
- **THEN** dispatch is denied rather than silently changing the trust boundary.

### Requirement: SM-006 Cryptographic claims need complete qualification

A cryptographic profile SHALL remain disabled until independent review and
implementation evidence cover its claimed malicious-participant model, input
authorization and consistency, corpus coverage, approved leakage, and result
release; OPRF use or a semi-honest proof alone is insufficient.

#### Scenario: Qualified cryptographic profile

- **GIVEN** a registered protocol has independently reviewed evidence for the exact claimed profile
- **WHEN** a search requests that profile and satisfies its additional admission rules
- **THEN** dispatch may use it only within its recorded guarantees and assumptions.

#### Scenario: OPRF is presented as the entire privacy proof

- **GIVEN** an implementation blinds queries with an OPRF but has no input-authorization or result-leakage qualification
- **WHEN** it requests activation as a maliciously secure private matcher
- **THEN** activation is denied.

### Requirement: SM-007 Matching uses a qualified versioned relation

Evaluation SHALL use only the approved, qualified matching relation: exact
equality initially, with canonical chunk or semantic profiles disabled until
their normalization, parameters, accuracy limits, and security behavior receive
separate qualification.

#### Scenario: Exact whole-object match

- **GIVEN** the approved exact-equality profile compares two equal complete byte sequences
- **WHEN** its qualified comparison finishes
- **THEN** it produces an exact-equality candidate without claiming semantic or ownership conclusions.

#### Scenario: Semantic search disguised as exact matching

- **GIVEN** only the exact-equality profile is qualified
- **WHEN** a request asks an unqualified embedding model to rank similar works under that profile
- **THEN** the request is denied rather than relabeled as exact matching.

### Requirement: SM-008 Eligibility precedes ranking

Ranking SHALL consider only currently eligible candidates in the approved
corpora, under the pinned cross-corpus or per-corpus rule; ineligible material
cannot affect visible candidates, result slots, order, or counts.

#### Scenario: Uninvited corpus does not affect ranking

- **GIVEN** a search authorizes corpora A and B but not C
- **WHEN** data in C changes while all approved inputs remain fixed
- **THEN** the search's candidates, order, and counts remain unchanged.

#### Scenario: Ineligible candidate consumes a slot

- **GIVEN** a worker ranks an ineligible candidate ahead of eligible candidates and removes it only after truncation
- **WHEN** the resulting candidate list is validated
- **THEN** that list is rejected without disclosing the ineligible candidate or its effect.

### Requirement: SM-009 Result limits apply before disclosure

Result release SHALL expose only approved fields for at most the approved number
of eligible candidates meeting the approved threshold, with filtering performed
inside the trusted matcher or qualified secure computation before any recipient
learns the result.

#### Scenario: Bounded positive receipt

- **GIVEN** a contract permits three opaque handles and only two eligible candidates meet its threshold
- **WHEN** the sealed result is authorized for release
- **THEN** the recipient receives only those two handles and other explicitly approved fields.

#### Scenario: Full intersection hidden only in the interface

- **GIVEN** a contract permits three results
- **WHEN** a protocol sends ten matches to the recipient and proposes displaying only three
- **THEN** that protocol does not satisfy the release contract and is rejected before disclosure.

### Requirement: SM-010 Observable leakage is explicit

Admission SHALL require an enforceable approved leakage profile for result count,
ordering, empty answers, identifiers, scores, status, disposition, availability,
callbacks, errors, timing, framing, and corpus metadata; unsupported concealment claims and unapproved observable
channels are denied.

#### Scenario: Deliberately permitted empty answer

- **GIVEN** both sides approve disclosure of an empty-result bit under a qualified response profile
- **WHEN** the authorized completed result contains no qualifying candidates
- **THEN** that bit may be disclosed under the agreed profile and accounting rules.

#### Scenario: Scores leak through a status channel

- **GIVEN** a contract permits opaque handles but no scores
- **WHEN** a worker emits exact scores through status messages
- **THEN** the emission is blocked and that behavior cannot qualify under the approved profile.

#### Scenario: Import disposition would reveal a hidden verdict

- **GIVEN** a submitter may not observe whether its private import matched the corpus
- **WHEN** making the import available only after a negative match would reveal that decision
- **THEN** the service withholds that observable disposition until it has separate disclosure authority or an approved uniform response profile.

### Requirement: SM-011 Query allowances accumulate durably

Comparison SHALL reserve and account for cumulative disclosure allowance against
authenticated principals and approved scope groups before observable evaluation;
concurrent requests, empty answers, uncertain aborts, new sessions, and changed
nonces cannot reset or evade the allowance.

#### Scenario: Last available query is reserved

- **GIVEN** one query remains in a shared allowance and two requests race to reserve it
- **WHEN** the monitor serializes their reservations
- **THEN** at most one request receives permission to evaluate.

#### Scenario: Empty probes recreate sessions

- **GIVEN** completed empty answers exhausted a principal's allowance
- **WHEN** the principal submits new nonces and session identifiers for the same governed scope
- **THEN** further comparison is denied until new allowance is independently authorized.

### Requirement: SM-012 Recovery preserves exact search accounting

Recovery SHALL retain consumed allowance and exact invocation, input, result,
and authorization bindings, redelivering an already authorized result without
free reevaluation and denying new searches when accounting high-water marks are
uncertain.

#### Scenario: Delivery retry after durable authorization

- **GIVEN** an exact receipt and its allowance consumption were durably authorized before a delivery failure
- **WHEN** that invocation is retried
- **THEN** recovery redelivers the same receipt under the durable-publication contract without a new comparison.

#### Scenario: Backup restores an unspent allowance

- **GIVEN** a restored checkpoint cannot establish whether a later query consumed the remaining allowance
- **WHEN** the service tries to admit a new search from the checkpoint
- **THEN** admission remains disabled until authoritative accounting is reconciled.

### Requirement: SM-013 Results retain both sides' provenance

Candidate results SHALL retain original policies and complete origins from both
sides and every influencing metadata or control input, except where a reviewed
sound analysis establishes independence; omission from a visible match list does
not establish independence.

#### Scenario: Negative result depends on both inputs

- **GIVEN** a completed no-match result depends on protected import A and corpus B
- **WHEN** its candidate policy is constructed
- **THEN** the original restrictions and origins of both A and B remain recorded.

#### Scenario: Hidden ranking input is discarded

- **GIVEN** protected input C influences candidate order but is absent from the visible positive list
- **WHEN** the worker omits C from the result's provenance without a sound independence analysis
- **THEN** result validation rejects the omission.

### Requirement: SM-014 Release rechecks the actual sealed result

Release authorization SHALL recheck current scope, grants, epochs, accounting,
and the exact sealed result; any policy reduction uses the controlled-disclosure
release view retaining original policies, origins, effective policy, and release
chain, rather than silently weakening a legacy source policy.

#### Scenario: Scoped release view passes the final gate

- **GIVEN** a sealed result has complete provenance and a current release view approved for its exact recipient and fields
- **WHEN** all live checks pass before durable authorization
- **THEN** only that result may be published with its original policy and release chain retained.

#### Scenario: Owner revokes before release authorization

- **GIVEN** a comparison finished but its required origin approval was revoked before durable release authorization
- **WHEN** the service attempts to publish the sealed result
- **THEN** publication is denied despite the earlier successful comparison.

### Requirement: SM-015 Incomplete searches do not become clean results

Search outcomes SHALL distinguish completed scoped results from incomplete,
denied, expired, or unknown execution, disclosing only approved status and keeping
imports subject to a mandatory check unadmitted until that check is satisfied.

#### Scenario: Completed empty search is scoped

- **GIVEN** every required corpus was searched successfully under the approved matcher and snapshot
- **WHEN** no candidate meets the threshold and the empty-answer disclosure is authorized
- **THEN** the receipt reports no qualifying match only within that exact completed scope.

#### Scenario: Timeout cannot satisfy a mandatory import check

- **GIVEN** a required corpus times out before comparison completes
- **WHEN** the importer requests admission on the basis of zero returned matches
- **THEN** the import remains unadmitted under that check and no completed no-match receipt is issued.

### Requirement: SM-016 Match evidence does not establish ownership

A match receipt SHALL describe only the qualified relation within its recorded
scope, without establishing theft, ownership, global cleanliness, or new
authority over an import or matched work.

#### Scenario: Identical licensed material

- **GIVEN** an approved exact comparison finds identical material that the importer is separately licensed to use
- **WHEN** a receipt is issued
- **THEN** it records the equality evidence without asserting theft or changing authority.

#### Scenario: Claimant converts similarity into control

- **GIVEN** a participant receives an overlap receipt
- **WHEN** it presents that receipt as proof that it owns and may control the import
- **THEN** the receipt supplies no such authority.

### Requirement: SM-017 Follow-up operations need separate grants

Access to a comparison or its receipt SHALL confer no payload-read, quarantine,
revocation, or deletion right; each follow-up operation requires its own current
exactly scoped authority.

#### Scenario: Reviewer receives a separate read grant

- **GIVEN** a reviewer holds a match receipt and a separately issued current read grant for matched object A
- **WHEN** the reviewer requests the approved read of A
- **THEN** the normal read checks apply using that grant rather than the comparison receipt.

#### Scenario: Receipt is used as a delete capability

- **GIVEN** a reviewer has comparison authority but no deletion grant
- **WHEN** the reviewer requests deletion of the import or a matched object using its receipt
- **THEN** deletion is denied.

### Requirement: SM-018 Derived matching material remains scoped

Retention and reuse of fingerprints, indexes, caches, evidence, and receipts
SHALL respect their approved scope, access policy, and retention terms; derived
identifiers do not become public or globally reusable search credentials.

#### Scenario: Working index expires while audit evidence remains

- **GIVEN** a contract permits a one-day working index and longer protected receipt retention
- **WHEN** the index retention expires
- **THEN** the index is retired while retained receipts remain accessible only under their separate approved policy.

#### Scenario: Scope-specific fingerprints enter a global index

- **GIVEN** fingerprints were authorized only for a bilateral search
- **WHEN** a service attempts to reuse them in an unapproved global lookup index
- **THEN** reuse is denied.
