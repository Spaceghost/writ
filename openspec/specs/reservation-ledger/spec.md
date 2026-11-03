# Reservation ledger

## Purpose

Specify the pure ledger transitions that reserve a reader's available units,
consume an exact reservation once, and refund cancellation or expiry. The model
operates on monitor-owned state within the supported numeric range. It does not
authenticate accounts, settle money, persist state, or prevent a host from
replaying an obsolete in-memory snapshot. Serialization and durable persistence
belong to the enforcing host.

## Requirements

### Requirement: RL-001 Structurally valid ledger

Ledger mutations SHALL reject state with duplicate account principals, duplicate seen receipts, duplicate committed invocations, duplicate active receipt or invocation keys, or a hold whose payer is absent, receipt is unseen, or invocation is already committed.

#### Scenario: Duplicate payer

- **GIVEN** two accounts have principal 7
- **WHEN** ledger validity is checked or a mutation is attempted
- **THEN** the state is invalid and the mutation cannot be applied

#### Scenario: Hold lacks its replay record

- **GIVEN** an active hold has receipt 11 but the seen-receipt set omits 11
- **WHEN** a mutation is attempted
- **THEN** the mutation is rejected

### Requirement: RL-002 Revision-checked transitions

Every applied ledger mutation SHALL require the supplied expected revision to equal the current revision and produce a successor revision exactly one greater.

#### Scenario: Stale reservation request

- **GIVEN** a valid ledger at revision one
- **WHEN** a new reservation supplies expected revision zero
- **THEN** the reservation is rejected

#### Scenario: Successful commit revision

- **GIVEN** a valid ledger at revision one with an eligible exact hold
- **WHEN** that hold is committed using expected revision one
- **THEN** the resulting ledger has revision two

### Requirement: RL-003 Reservation reduces available balance

A successful reservation SHALL subtract its exact units from an existing payer's available balance and register the hold, rejecting reservations that exceed the available balance.

#### Scenario: Reserve part of a balance

- **GIVEN** payer 7 has 100 available units
- **WHEN** a valid reservation for 30 units is applied
- **THEN** payer 7 has 70 available units
- **AND** the exact 30-unit hold is active

#### Scenario: Overdraft

- **GIVEN** payer 7 has 70 available units
- **WHEN** a reservation requests 71 units
- **THEN** the reservation is rejected

### Requirement: RL-004 Reservation is live on creation

A reservation SHALL be admitted only while trusted time is strictly less than the hold's expiry.

#### Scenario: Reserve at the expiry boundary

- **GIVEN** an otherwise valid reservation expires at time 50
- **WHEN** reservation is requested at time 50
- **THEN** it is rejected

#### Scenario: Reserve before expiry

- **GIVEN** an otherwise valid reservation expires at time 50
- **WHEN** reservation is requested at time 10
- **THEN** it is admitted

### Requirement: RL-005 One active reservation per uncommitted invocation

A new reservation SHALL reject an invocation that already has an active hold or appears in the committed-invocation set.

#### Scenario: Concurrent holds for one invocation

- **GIVEN** invocation 23 already has a live hold under receipt 11
- **WHEN** a different receipt attempts to reserve more units for invocation 23
- **THEN** the second reservation is rejected

#### Scenario: New receipt for a completed invocation

- **GIVEN** invocation 23 is recorded as committed
- **WHEN** an unused receipt requests a reservation for invocation 23
- **THEN** the reservation is rejected

### Requirement: RL-006 Receipt identifiers are not recycled

Every admitted receipt identifier SHALL remain in the seen-receipt set after commit, cancellation, or expiry, preventing any later reservation from reusing it.

#### Scenario: Replay a cancelled receipt

- **GIVEN** receipt 11 was reserved and then cancelled
- **WHEN** a new reservation attempts to use receipt 11
- **THEN** the reservation is rejected even though the previous hold was removed

#### Scenario: Replay an expired receipt

- **GIVEN** receipt 11 was refunded and removed by expiry processing
- **WHEN** another invocation attempts to reserve using receipt 11
- **THEN** the reservation is rejected

### Requirement: RL-007 Exact live hold scope at commit

Commit SHALL require an active hold under the requested receipt whose invocation, payer, and units match exactly and whose expiry is strictly later than trusted time.

#### Scenario: Change receipt scope

- **GIVEN** receipt 11 holds 30 units for invocation 23 and payer 7
- **WHEN** commit supplies invocation 24, payer 8, or amount 1
- **THEN** commit is rejected

#### Scenario: Commit an expired hold

- **GIVEN** receipt 11 expires at time 50
- **WHEN** commit is requested at time 50 or later
- **THEN** commit is rejected

### Requirement: RL-008 Single consumption

A successful commit SHALL remove the active hold and record its invocation as committed without deducting the reserved units from available balance a second time.

#### Scenario: Consume a reservation

- **GIVEN** 30 units were reserved from a 100-unit balance, leaving 70 available
- **WHEN** the exact hold is successfully committed
- **THEN** available balance remains 70
- **AND** the hold is removed and its invocation is recorded as committed

#### Scenario: Commit replay

- **GIVEN** a hold has already committed
- **WHEN** the same receipt and invocation are submitted against the resulting ledger
- **THEN** commit is rejected

### Requirement: RL-009 Scoped live cancellation

Cancellation SHALL refund and remove a hold only when its receipt, invocation, payer, amount, and unexpired lifetime match the request.

#### Scenario: Refund a live hold

- **GIVEN** receipt 11 holds 30 units for invocation 23 and payer 7 until time 50
- **AND** payer 7 has 70 available units
- **WHEN** the exact hold is cancelled at time 20
- **THEN** payer 7 has 100 available units and the hold is removed

#### Scenario: Cancellation cannot select another payer

- **GIVEN** receipt 11 belongs to payer 7
- **WHEN** cancellation names payer 8
- **THEN** cancellation is rejected

### Requirement: RL-010 Expiration refunds once

Expiry processing SHALL refund and remove an existing hold only when trusted time is greater than or equal to that hold's expiry.

#### Scenario: Expired hold returns its units

- **GIVEN** a 30-unit hold expires at time 50 and its payer has 70 available units
- **WHEN** expiry processing is applied at time 50 or later
- **THEN** available balance becomes 100 and the hold is removed

#### Scenario: Early expiry request

- **GIVEN** a hold expires at time 50
- **WHEN** expiry processing is requested at time 49
- **THEN** it is rejected

#### Scenario: Reap the same hold twice

- **GIVEN** a hold has already been removed by expiry processing
- **WHEN** its receipt is submitted for expiry again
- **THEN** the second request is rejected and no additional refund occurs

### Requirement: RL-011 Denial preserves the ledger

A rejected ledger operation SHALL return the original supplied state, preserving revision, balances, holds, seen receipts, and committed invocations.

#### Scenario: Denied overdraft has no accounting effect

- **GIVEN** a current ledger with 70 available units
- **WHEN** a reservation for 71 units is rejected
- **THEN** the original ledger is returned with the same revision and 70 available units
- **AND** no new hold or seen receipt is added

#### Scenario: Rejected replay cannot refund funds

- **GIVEN** a hold has already committed
- **WHEN** cancellation of that receipt is rejected
- **THEN** the returned ledger is unchanged
