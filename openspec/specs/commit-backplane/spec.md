# Commit backplane

## Purpose

Specify the final library decision that combines independently verified
constraints, current policy, negotiated funding, and a trusted execution binding
into a pure session/ledger transition and scoped write intent. The monitor owns
all authoritative inputs. An artifact identity describes sealed output supplied
by that monitor; this library does not hash bytes, authenticate an executor, or
perform a durable write. The capability-facing entry point adds live descriptor
and authenticated-reader checks to the same backplane.

## Requirements

### Requirement: CB-001 Unique full-request binding

Commit SHALL resolve exactly one authoritative binding keyed by the complete request, including its plan, reader, quote, amount, and deadline, rejecting any binding registry with duplicate full-request keys.

#### Scenario: Duplicate identical authority records

- **GIVEN** a registry contains two identical bindings for one complete request
- **WHEN** commit is attempted
- **THEN** it is rejected

#### Scenario: Conflicting records cannot depend on order

- **GIVEN** permissive and restrictive bindings share the same full-request key
- **WHEN** commit is attempted with either registry ordering
- **THEN** both attempts are rejected

#### Scenario: Changed reader has a different key

- **GIVEN** the registry contains a binding for reader 7
- **WHEN** an otherwise matching session request names reader 8 without its own binding
- **THEN** commit is rejected

#### Scenario: Different full requests coexist

- **GIVEN** a registry has one valid binding for each of two distinct full requests
- **WHEN** the first request commits with all required checks satisfied
- **THEN** the unrelated distinct binding does not prevent commit

### Requirement: CB-002 Live running session and current revisions

Commit SHALL require a Running session before its request deadline and exact expected session and ledger revisions.

#### Scenario: A passed sample is not a commit stage

- **GIVEN** a Sampled session with valid candidate data
- **WHEN** commit is requested
- **THEN** it is rejected

#### Scenario: Stale expected state

- **GIVEN** a Running session at revision 6 and a ledger at revision 1
- **WHEN** commit supplies expected session revision 5 or expected ledger revision 0
- **THEN** it is rejected

#### Scenario: Request reaches its deadline

- **GIVEN** a Running request with deadline 180
- **WHEN** commit is requested at trusted time 180
- **THEN** it is rejected

### Requirement: CB-003 Exact cross-subsystem epochs

Commit SHALL require exact graph, policy, and authority epoch agreement between the core and transfer snapshots, plus DLM authority-epoch agreement with the current authority epoch, preserving all supported epoch bits during comparison.

#### Scenario: High-word epoch mismatch

- **GIVEN** a core epoch has low word zero and high word two
- **WHEN** it is compared with transfer epoch 4294967296
- **THEN** they do not match

#### Scenario: High word retained

- **GIVEN** a core epoch has low word zero and high word one
- **WHEN** it is compared with transfer epoch 4294967296
- **THEN** the epochs match

#### Scenario: One subsystem changed authority

- **GIVEN** the request and transfer snapshot use authority epoch 3
- **WHEN** the principal snapshot uses authority epoch 4
- **THEN** commit is rejected

### Requirement: CB-004 Current data authority

Commit SHALL revalidate every inherited-origin approval and complete paired transfer admission against the current authoritative snapshot.

#### Scenario: Authority revoked during execution

- **GIVEN** a Running session previously admitted all required data access
- **WHEN** a required owner approval, source read grant, or destination write grant is absent at commit
- **THEN** commit is rejected

#### Scenario: Origin payment is no longer evidenced

- **GIVEN** an inherited source obligation requires a scoped payment witness
- **WHEN** that witness is absent from the current transfer snapshot
- **THEN** commit is rejected

### Requirement: CB-005 Current funding

Commit SHALL require both the current exact negotiation budget record and the corresponding live ledger hold, followed by a successful exact-scope ledger commit.

#### Scenario: Budget withdrawn after execution starts

- **GIVEN** a Running session still has its ledger hold
- **WHEN** the matching budget record is removed before commit
- **THEN** commit is rejected

#### Scenario: Hold already consumed

- **GIVEN** an earlier commit consumed the session's receipt
- **WHEN** the old Running session is submitted with the current ledger
- **THEN** commit is rejected

### Requirement: CB-006 Original-graph verification

Commit SHALL authorize a solver candidate only after independent verification against the authoritative original graph and current sink policy.

#### Scenario: Producer clears a required label

- **GIVEN** the original graph includes a protected source restriction
- **WHEN** the producer supplies a candidate that omits that restriction
- **THEN** commit is rejected

#### Scenario: Fully verified candidate

- **GIVEN** the candidate satisfies the original graph and all other commit gates
- **WHEN** commit is requested
- **THEN** candidate verification permits the commit to proceed

### Requirement: CB-007 Actual backend effects

Commit SHALL include a write effect for every backend and additionally include the network, display, or device effect corresponding to the selected backend, regardless of effects omitted by the candidate.

#### Scenario: Network output hidden by the candidate

- **GIVEN** the selected backend is network and the sink lacks network authority
- **WHEN** a candidate claiming no network effect is committed
- **THEN** commit is rejected

#### Scenario: Storage still needs write authority

- **GIVEN** the selected backend is storage and the sink lacks write authority
- **WHEN** commit is requested
- **THEN** commit is rejected

### Requirement: CB-008 Exact output schema

Commit SHALL require the candidate sink's final type to equal the plan's declared output schema exactly.

#### Scenario: Static narrowing selects another schema

- **GIVEN** the original graph admits a type assignment different from the registered operation's declared output schema
- **WHEN** a candidate chooses that otherwise valid assignment at the output sink
- **THEN** commit is rejected

### Requirement: CB-009 Combined output restrictions

Commit SHALL join the transfer-derived and graph-derived confidentiality and integrity restrictions and recheck the resulting policy against the actual transfer destination.

#### Scenario: Control dependency adds a restriction

- **GIVEN** transfer admission permits an output based on its explicit source labels
- **AND** the verified graph adds a control dependency the actual destination cannot accept
- **WHEN** commit is requested
- **THEN** commit is rejected despite the earlier transfer admission

#### Scenario: Destination accepts the complete restriction set

- **GIVEN** the destination accepts every transfer-derived and graph-derived restriction
- **AND** all other commit checks pass
- **WHEN** commit is requested
- **THEN** the combined-policy gate permits commit

### Requirement: CB-010 Decentralized label flow

Commit SHALL require the binding's source label to flow to its destination label under the current validated decentralized principal policy.

#### Scenario: Secret-to-public destination

- **GIVEN** the source label protects information from public release
- **WHEN** the binding names a public destination label without an allowed flow
- **THEN** commit is rejected even if the caller possesses a capability

### Requirement: CB-011 Bound artifact identity

A successful commit SHALL carry the exact complete 256-bit artifact identity from its authoritative execution binding, with no replacement artifact selected by the commit caller.

#### Scenario: Preserve the final identity word

- **GIVEN** a trusted binding names artifact A
- **WHEN** commit succeeds
- **THEN** the write intent names A in all eight 32-bit words
- **AND** an identity differing only in the final word does not compare equal

#### Scenario: Binding supplies the artifact

- **GIVEN** the authoritative binding for the request names artifact B
- **WHEN** commit succeeds with that binding
- **THEN** the write intent names B

### Requirement: CB-012 Retained output scope and provenance

A successful write intent SHALL retain the exact plan, selected backend, output schema, inherited origins and operation restrictions, combined confidentiality/integrity restrictions, and a DLM label at least as restrictive as both binding labels.

#### Scenario: Commit preserves source obligations

- **GIVEN** an admitted transformation inherits protected origins and limited operation rights
- **WHEN** its commit succeeds
- **THEN** the intent preserves those origin records and operation limits
- **AND** the output retains the combined labels and declared schema

### Requirement: CB-013 All-or-nothing model transition

Commit SHALL return either a Committed session with the successor ledger and write intent, or the unchanged supplied session and ledger with no write intent.

#### Scenario: Successful transition

- **GIVEN** every commit gate passes and the exact reservation can be consumed
- **WHEN** commit is evaluated
- **THEN** the session becomes Committed, the ledger revision advances once, and a scoped write intent is returned
- **AND** the reserved amount is not deducted twice

#### Scenario: Late denial retains reservation

- **GIVEN** the session is Running with a live reservation
- **WHEN** commit fails because an owner approval was revoked
- **THEN** the original Running session and original ledger are returned
- **AND** the reservation remains unconsumed

#### Scenario: Terminal session cannot commit again

- **GIVEN** a session has become Committed
- **WHEN** it is submitted for another commit
- **THEN** the request is rejected

### Requirement: CB-014 Fresh capability-to-commit authorization

The capability-facing commit interface SHALL require a current executable descriptor whose stored plan equals the session plan and whose authenticated subject equals the negotiated reader before invoking all backplane checks.

#### Scenario: Capability revoked after opening

- **GIVEN** the reader previously opened a valid descriptor
- **WHEN** its capability is absent from the current registry at commit
- **THEN** commit is rejected without consuming the reservation

#### Scenario: Different authenticated reader

- **GIVEN** a descriptor and token validly belong to subject 8
- **AND** the negotiated session names reader 7
- **WHEN** subject 8 attempts commit
- **THEN** commit is rejected

#### Scenario: Read and write rights do not imply execution

- **GIVEN** the descriptor has read and write rights but lacks execute rights
- **WHEN** commit is requested through it
- **THEN** commit is rejected

#### Scenario: Valid capability still needs policy approval

- **GIVEN** a current executable descriptor for the negotiated reader and exact plan
- **WHEN** the destination label fails the backplane's flow check
- **THEN** commit is rejected
