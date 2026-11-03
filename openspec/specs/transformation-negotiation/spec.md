# Transformation negotiation

## Purpose

Specify the implemented negotiation state machine for a single transformation
candidate using monitor-owned sessions and authenticated evidence snapshots.
Its ordered stages are Proposed, CandidateFixed, Challenged, Sampled,
OwnersApproved, Reserved, Running, and Committed. The final commit belongs to
the commit-backplane capability. Executor selection, execution of samples, and
sample-compute billing are not implemented by this state machine.

## Requirements

### Requirement: TN-001 Initial session

Opening a negotiation SHALL create a Proposed session at revision zero containing the supplied request and no selected challenge or reservation receipt.

#### Scenario: Open a transformation request

- **GIVEN** a request with an exact plan, reader, quote, amount, and deadline
- **WHEN** the request is opened
- **THEN** the session is Proposed at revision zero
- **AND** its challenge and receipt identifiers are zero

### Requirement: TN-002 Immutable negotiation terms

Every accepted negotiation transition SHALL retain the complete original request, including the plan, reader, quote, amount, and deadline.

#### Scenario: Terms survive negotiation

- **GIVEN** a Proposed request for reader 7, quote 42, amount 30, and deadline 180
- **WHEN** valid transitions advance the session to Running
- **THEN** those terms and the complete plan remain equal to the opened request

### Requirement: TN-003 Ordered revision-checked transitions

A negotiation transition SHALL advance only from its required stage at the exact expected session revision, incrementing that revision once on success.

#### Scenario: Valid next stage

- **GIVEN** a Proposed session at revision zero with a live request
- **WHEN** its requested candidate is pinned using expected revision zero
- **THEN** the session advances to CandidateFixed at revision one

#### Scenario: Stale caller

- **GIVEN** a Proposed session at revision zero
- **WHEN** pinning supplies expected revision one
- **THEN** the transition is rejected

#### Scenario: A sample cannot skip approval

- **GIVEN** a Sampled session with otherwise valid budget evidence
- **WHEN** the reader attempts to reserve the main execution budget
- **THEN** the transition is rejected because OwnersApproved has not been reached

### Requirement: TN-004 Live request snapshot

Every guarded stage transition SHALL reject a request when trusted time reaches its deadline or when its graph, policy, or authority epoch differs from the live transfer snapshot.

#### Scenario: Exact deadline

- **GIVEN** a Reserved session with request deadline 180 and valid evidence
- **WHEN** execution start is requested at trusted time 180
- **THEN** start is rejected

#### Scenario: Authority changed after reservation

- **GIVEN** a Reserved session bound to authority epoch 3
- **WHEN** start is requested against authority epoch 4
- **THEN** start is rejected

### Requirement: TN-005 Candidate pinning

Pinning SHALL fix only the complete candidate identity named by the immutable request at the trusted pinning time, without conferring operation approval.

#### Scenario: Candidate substitution

- **GIVEN** a Proposed request naming candidate A
- **WHEN** candidate B is supplied for pinning
- **THEN** pinning is rejected

#### Scenario: Pinned identity still needs admission

- **GIVEN** a candidate has been pinned and a fresh challenge has been selected
- **AND** its source read approval is absent
- **WHEN** permission to execute a protected sample is requested
- **THEN** the sample is denied despite the pinned identity

### Requirement: TN-006 Fresh request-bound challenge

Challenge selection SHALL require a positive challenge identifier and a matching plan-bound record issued strictly after pinning, no later than trusted time, and not expired at that time.

#### Scenario: Challenge issued after pinning

- **GIVEN** a candidate pinned at time 100 and a plan-bound challenge issued at 101 with expiry 180
- **WHEN** challenge selection occurs at time 110
- **THEN** the session advances to Challenged with that challenge identifier

#### Scenario: Future challenge

- **GIVEN** the selected challenge has issue time 101
- **WHEN** selection is attempted at time 100
- **THEN** the transition is rejected

#### Scenario: Challenge existed before the candidate was fixed

- **GIVEN** a candidate pinned at time 100
- **WHEN** selection supplies only a matching challenge issued at time 100 or earlier
- **THEN** the transition is rejected

### Requirement: TN-007 Platform nonce generation

The challenge nonce helper SHALL obtain all 256 nonce bits through the platform random effect, propagating an unsuccessful random-effect result instead of returning a fabricated successful nonce.

#### Scenario: Assemble a complete nonce

- **GIVEN** eight successful platform-random 32-bit results
- **WHEN** the nonce helper completes
- **THEN** the returned nonce contains all eight words in their requested order

#### Scenario: Random source failure

- **GIVEN** a platform-random request fails before all eight words are available
- **WHEN** the nonce helper is evaluated
- **THEN** it does not return a successful complete nonce

### Requirement: TN-008 Protected sample admission

Permission to execute a protected sample SHALL require a live Challenged session, a current matching challenge, and complete paired transfer admission for the session plan.

#### Scenario: Authorized protected sample

- **GIVEN** a live Challenged session with a matching challenge and admitted read/write plan
- **WHEN** sample permission is checked at its current revision
- **THEN** permission is granted for that plan

#### Scenario: Missing source approval

- **GIVEN** the challenge is valid but a required source read grant has been removed
- **WHEN** sample permission is checked
- **THEN** permission is denied

### Requirement: TN-009 Scoped sample evidence

Advancing to Sampled SHALL require current sample permission and an unexpired passed sample record matching the selected sample identifier, exact plan, selected challenge, and nonce of a challenge issued after pinning.

#### Scenario: Failed or mismatched sample

- **GIVEN** a live Challenged session
- **WHEN** the selected sample reports failure or a different nonce
- **THEN** the transition to Sampled is rejected

#### Scenario: Old nonce under a reused challenge identifier

- **GIVEN** the registry contains fresh and pre-pinning challenge records with the same identifier
- **WHEN** a passed sample matches only the pre-pinning record's nonce
- **THEN** the transition to Sampled is rejected

### Requirement: TN-010 Every-origin approval

Advancing to OwnersApproved SHALL require a nonempty validated origin set and an unexpired approval for the exact plan from every contributing origin, regardless of sample success.

#### Scenario: All contributors approve

- **GIVEN** a Sampled plan inheriting origins A and B
- **WHEN** both origins have current approvals for that exact plan
- **THEN** owner approval succeeds

#### Scenario: One contributor withholds approval

- **GIVEN** a passed sample for a plan inheriting origins A and B
- **WHEN** only origin A has approved
- **THEN** owner approval is denied

#### Scenario: Approval names another destination

- **GIVEN** a passed sample and an origin approval for a plan writing to destination X
- **WHEN** the session plan writes to destination Y
- **THEN** that approval cannot satisfy the session's owner-approval requirement

### Requirement: TN-011 Exact reader budget

Main execution reservation SHALL require a live budget record matching the complete plan, selected positive receipt, negotiated reader as payer, quote, and exact amount.

#### Scenario: Reader-funded reservation

- **GIVEN** an OwnersApproved request for reader 7, quote 42, amount 30, and a matching live budget record
- **AND** reader 7 has 100 available units in a valid current ledger
- **WHEN** the budget is reserved using the matching receipt
- **THEN** the session becomes Reserved and reader 7 has 70 available units

#### Scenario: Payer or quote substitution

- **GIVEN** the negotiated reader is 7 and quote is 42
- **WHEN** the only budget record names payer 8 or quote 43
- **THEN** reservation is rejected

### Requirement: TN-012 Reservation admission

Entering Reserved SHALL require current OwnersApproved admission, fresh approval from every origin, and successful reservation against the supplied expected ledger revision.

#### Scenario: Reservation cannot bypass origin reauthorization

- **GIVEN** a session reached OwnersApproved before an origin approval was revoked
- **WHEN** reservation is attempted against the updated evidence snapshot
- **THEN** it is rejected without consuming ledger funds

#### Scenario: Ledger refusal

- **GIVEN** an OwnersApproved session and a matching budget record
- **WHEN** the ledger refuses reservation because the supplied ledger revision is stale
- **THEN** the session does not advance to Reserved

### Requirement: TN-013 Execution reauthorization

Entering Running SHALL require a live Reserved session, current every-origin approval, current paired transfer admission, a structurally valid ledger, a matching live budget record, and the exact live reservation hold.

#### Scenario: Revoked budget with a remaining hold

- **GIVEN** a Reserved session whose ledger hold is still live
- **WHEN** its matching budget record has been removed before start
- **THEN** execution start is denied

#### Scenario: Revoked data authority

- **GIVEN** a Reserved session
- **WHEN** a required source read grant or inherited-origin approval has been revoked
- **THEN** execution start is denied

#### Scenario: Valid execution start

- **GIVEN** a live Reserved session with every required grant, origin approval, budget record, and exact hold
- **WHEN** start is requested with the current session revision
- **THEN** the session advances to Running

### Requirement: TN-014 Denial preserves supplied state

A rejected negotiation operation SHALL return the original supplied session and, for reservation operations, the original supplied ledger without advancing revisions or consuming funds.

#### Scenario: Reject a stale pin

- **GIVEN** a Proposed session at revision zero
- **WHEN** pinning is rejected for a stale expected revision
- **THEN** the returned session remains the original Proposed session at revision zero

#### Scenario: Reject a reservation with changed terms

- **GIVEN** an OwnersApproved session and a ledger with 100 available units
- **WHEN** reservation is rejected because the budget names a different quote
- **THEN** the original session and ledger are returned
- **AND** available funds remain 100
