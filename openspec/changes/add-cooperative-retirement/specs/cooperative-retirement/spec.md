# Cooperative retirement

## Purpose

Coordinate authorized retirement of exact managed data versions and their
described copies or derivatives, while separating revocation from disposal and
reporting only the completion guarantees supported by participant evidence.

## ADDED Requirements

### Requirement: CR-001 Retirement effects remain distinct

The service SHALL distinguish unlink, revoke, retire, and purge in versioned requests, grants, and outcomes. Authority for one effect SHALL NOT imply another effect or access to protected payloads.

#### Scenario: An authorized namespace unlink succeeds

- **GIVEN** R may remove alias A but has no purge or payload-read grant
- **WHEN** R submits the exact unlink request
- **THEN** only the authorized alias is removed and no payload or purge authority is granted.

#### Scenario: Unlink is presented as completed erasure

- **GIVEN** alias A was removed while managed replicas remain
- **WHEN** a participant tries to report the payload purged
- **THEN** the unlink result cannot establish that disposal outcome.

### Requirement: CR-002 Current grants bind the complete scope

Retirement admission SHALL authenticate the requester and validate current grants for the exact versions, participants, effects, derivative coverage, retention terms, deadline, guarantee, and receipt audience. A scope change SHALL require new authorization.

#### Scenario: Agreed retirement terms cover the request

- **GIVEN** current grants bind R to retire A version 7 at participants P and Q under the stated terms
- **WHEN** R submits that exact scope
- **THEN** the request may be admitted within those terms.

#### Scenario: A caller adds an unapproved participant

- **GIVEN** the accepted scope covers P and Q only
- **WHEN** R expands it to purge R2's independent copy without a matching grant
- **THEN** the expansion is rejected and the existing scope is not widened.

### Requirement: CR-003 Matching does not grant destruction

A match, similarity score, ownership claim, search grant, or import hold SHALL NOT itself authorize unlink, revocation, or purge. Destructive effects SHALL require a separate authenticated grant for the exact target and effect.

#### Scenario: A reviewed match has a separate purge grant

- **GIVEN** a search found candidate A and an independently authenticated current grant permits its exact purge
- **WHEN** the purge request is evaluated
- **THEN** it may proceed based on that grant rather than the match score.

#### Scenario: A likely match is submitted for automatic deletion

- **GIVEN** a search result reports a high similarity score for another participant's object
- **WHEN** the requester supplies only that result as deletion authority
- **THEN** no destructive effect is admitted.

### Requirement: CR-004 Inventory coverage is explicit

Each participant SHALL inventory the requested managed aliases, replicas, staging, worker state, caches, indexes, derivatives, and backups within declared bounds. Missing, unknown, or unexamined coverage SHALL remain explicit and SHALL prevent a complete-scope claim.

#### Scenario: All enrolled inventory classes are accounted for

- **GIVEN** the request covers a replica, cached view, index entry, and backup at P
- **WHEN** P records each item and its required disposition within the admitted bounds
- **THEN** its coverage record includes the entire requested managed scope.

#### Scenario: An inventory scan exhausts its work limit

- **GIVEN** P has not examined all covered index entries before reaching its admitted limit
- **WHEN** it reports the scan outcome
- **THEN** the remaining coverage stays unresolved and the request is not reported complete.

### Requirement: CR-005 Retirement orders with publication

Each authority domain SHALL durably serialize its retirement barrier with new affected access, grant issuance, and publication authorization. Earlier barriers SHALL deny new affected authorization; already durably authorized publication SHALL be reconciled through the original durable protocol.

#### Scenario: Already authorized publication is reconciled

- **GIVEN** invocation I was durably authorized before the retirement barrier and delivery is uncertain
- **WHEN** recovery handles I during retirement
- **THEN** it reconciles the exact committed intent without duplicate effects and records any remaining retirement obligation.

#### Scenario: A pending result reaches a retired source's gate

- **GIVEN** the retirement barrier commits before invocation I has durable publication authorization
- **WHEN** I attempts authorization under the retired scope
- **THEN** no new publication is authorized through the old grants.

### Requirement: CR-006 Disposal waits for quiescence

Retirement SHALL quiesce affected workers, asynchronous I/O, and device access before reclaiming their resources, and reject old-generation completions. Unconfirmed quiescence SHALL block the relevant disposal claim and unsafe resource reuse.

#### Scenario: A worker and its I/O are stopped

- **GIVEN** all affected worker and device accesses are confirmed quiescent
- **WHEN** the participant retires their resource generation
- **THEN** the resources may be reclaimed under the admitted disposal method.

#### Scenario: A device cannot confirm DMA shutdown

- **GIVEN** a device may still access a retired job's allocation
- **WHEN** its shutdown or reset fails
- **THEN** the allocation remains isolated, is not reused unsafely, and is not reported successfully disposed.

### Requirement: CR-007 Disposal evidence matches its guarantee

A disposal outcome SHALL identify the method, covered material, and evidence supporting the requested guarantee. Namespace removal, revoked access, or deletion of one key reference SHALL NOT be reported as stronger erasure; cryptographic erasure SHALL account for relevant key and recovery copies.

#### Scenario: Supported disposal evidence covers the request

- **GIVEN** the requested logical-retirement guarantee is supported and every named managed reference is retired
- **WHEN** P supplies the required method and coverage evidence
- **THEN** its receipt may claim that logical guarantee for that scope.

#### Scenario: A recovery key survives a claimed cryptographic erasure

- **GIVEN** ciphertext remains readable using a retained recovery key
- **WHEN** P deletes its primary key reference and claims cryptographic erasure
- **THEN** the claimed guarantee is rejected as incomplete.

### Requirement: CR-008 Shared resources preserve unrelated authority

Disposal SHALL remove only authorized references and material; it SHALL NOT destroy shared bytes or keys needed by unaffected grants. A shared reference that prevents the requested guarantee SHALL be reported as an unresolved constraint or authorized retention exception.

#### Scenario: Logical retirement preserves a shared block

- **GIVEN** retired object A and unaffected object B share a physical block and only A's references must be retired
- **WHEN** P removes A's authorized references
- **THEN** B's valid references and required block remain intact.

#### Scenario: Shared material prevents the requested purge

- **GIVEN** the request requires disposal of a key still needed by an unaffected authorized object
- **WHEN** P evaluates that disposal
- **THEN** it does not destroy the unaffected object's access or claim the stronger purge complete.

### Requirement: CR-009 Derived data retains its obligations

Covered derivatives SHALL be retired, explicitly retained under authorized terms, or replaced through separately admitted regeneration. Source deletion SHALL NOT clear a derivative's origin records, effective restrictions, or claimed source influence; replacement SHALL NOT silently exempt the old artifact from retirement.

#### Scenario: A derivative is replaced under a new plan

- **GIVEN** a separately admitted plan produces a valid replacement from its complete approved sources
- **WHEN** the replacement is durably published
- **THEN** it has its own provenance and the old artifact remains tracked until its retirement is resolved.

#### Scenario: A model is declared unaffected after its source is removed

- **GIVEN** a trained model is a covered derivative of A
- **WHEN** only A's source row is deleted
- **THEN** the model's lineage and retirement obligation remain without a supported regeneration or influence-removal result.

### Requirement: CR-010 Recovery cannot resurrect retired authority

Participants SHALL persist protected retirement tombstones and authority/replay state, reconcile restores before serving data, and reconcile retries of accepted publications without recreating retired objects. If current retirement state cannot be established, affected access and new publication SHALL be denied.

#### Scenario: An old backup is restored with current tombstones

- **GIVEN** backup B predates the retirement of A version 7
- **WHEN** B is restored and reconciled against the current retirement record
- **THEN** A's retired grants do not regain usability.

#### Scenario: Recovery lacks the authoritative retirement state

- **GIVEN** a participant can restore old payloads and grants but cannot establish the current retirement epoch
- **WHEN** a caller requests affected content or new publication
- **THEN** the participant denies the request instead of trusting the old snapshot.

#### Scenario: Delivery acknowledgement was lost before retirement

- **GIVEN** a receiver accepted invocation I, lost its acknowledgement, and then retired the artifact
- **WHEN** the sender retries the exact already-authorized I
- **THEN** the receiver reconciles the recorded outcome without recreating the retired object or restoring its authority.

### Requirement: CR-011 Receipts authenticate bounded claims

Retirement receipts SHALL authenticate the participant and bind request identity, participant incarnation, exact versions, authority epoch, method, coverage, and outcome. Receipts SHALL be disclosed only to their authorized audience and SHALL NOT be represented as proof that unknown copies do not exist.

#### Scenario: A valid receipt satisfies its participant's scope

- **GIVEN** P's authenticated current receipt covers its exact requested versions and required guarantee
- **WHEN** the coordinator verifies it
- **THEN** it may count P's stated managed outcome without extending the claim to unknown copies.

#### Scenario: A receipt is replayed for another version

- **GIVEN** P's receipt covers A version 7 in an earlier request
- **WHEN** it is offered as evidence that A version 8 was purged
- **THEN** it does not satisfy the new request.

### Requirement: CR-012 Aggregate status preserves incomplete outcomes

Overall completion SHALL require acceptable current evidence for every required participant and the requested guarantee. Pending, offline, unknown, overdue, and authorized-retention outcomes SHALL remain distinguishable; silence or a deadline SHALL NOT become a successful purge.

#### Scenario: Every required participant completes its guarantee

- **GIVEN** P and Q provide valid current receipts satisfying the request's complete scope
- **WHEN** the coordinator evaluates completion
- **THEN** it may report the requested managed guarantee complete.

#### Scenario: One participant is offline at the deadline

- **GIVEN** P completed but Q has not acknowledged its authority barrier or disposal
- **WHEN** the deadline passes
- **THEN** Q remains offline or pending and the overall result does not claim complete retirement.

### Requirement: CR-013 Retirement records preserve necessary evidence

Retirement SHALL preserve minimal protected tombstones, replay/accounting records, and provenance needed for remaining obligations, without creating fresh payload copies in logs. Receipt and inventory access SHALL remain scoped, including after the payload is retired.

#### Scenario: A completed retirement retains safe recovery evidence

- **GIVEN** payload disposal is complete and replay prevention still needs its opaque identity and epoch
- **WHEN** retirement metadata is retained
- **THEN** that protected evidence remains without copying the payload into the audit record.

#### Scenario: An audit entry would disclose retired content

- **GIVEN** an error includes protected payload bytes or another owner's unapproved inventory names
- **WHEN** the participant prepares a requester-visible retirement log
- **THEN** the unapproved content is not emitted through that log.

#### Scenario: A shared-reference limit has private owners

- **GIVEN** unaffected private references prevent the requested physical purge
- **WHEN** the requester may learn that purge is incomplete but not those references' owners or counts
- **THEN** its scoped receipt reports the incomplete guarantee without revealing the protected inventory.

### Requirement: CR-014 Requests are bounded and replay-safe

Retirement requests SHALL use bounded canonical framing, current-revision admission, and identities bound to their complete scope. Identical retries SHALL resolve the existing outcome; changed reuse SHALL be rejected without mutating operation or accounting state. Cancellation SHALL NOT resurrect revoked authority or purged data.

#### Scenario: A participant acknowledgement is lost

- **GIVEN** request Q already retired A version 7 but its acknowledgement was lost
- **WHEN** the same authorized request is retried
- **THEN** it resolves Q's existing outcome without a second destructive transition or charge.

#### Scenario: A retry targets a replacement object

- **GIVEN** Q binds A version 7 and the old path now names A version 8
- **WHEN** Q is retried with the replacement version or changed scope
- **THEN** it is rejected without modifying A version 8 or Q's accounting state.
