# Frontend revision V2

## Purpose

Propose a versioned frontend revision and migration that retain owner cleanup,
exact state and stale-request rejection across the current bounded-Nat limit.
The model, authentication, migration and host qualification are unimplemented.

## ADDED Requirements

### Requirement: FR-001 Exact tagged revisions

A V2 frontend SHALL compare an explicit version tag and both U32 revision words, and advance without wrap exactly once per successful ordinary V2 mutation.

#### Scenario: Carry between words

- **GIVEN** an active V2 revision with low word `4294967295`, a high word below that value, and enough cleanup reserve after the mutation
- **WHEN** an authorized mutation advances its revision
- **THEN** the high word increases once and the low word becomes zero.

#### Scenario: Old request has the same numeric value

- **GIVEN** a migrated V2 frontend and a queued V1 request with its old numeric revision
- **WHEN** the V1 request is evaluated after migration
- **THEN** the V1 request is denied without reinterpreting its revision as V2.

### Requirement: FR-002 Reserve owner cleanup and retirement

Every admitted active V2 state SHALL retain one representable revision successor for each open handle and one additional successor for retirement.

#### Scenario: Last cleanup slot

- **GIVEN** an active state with one open expired handle, one cleanup successor and one retirement successor
- **WHEN** its authenticated owner closes it with the exact token and current revision
- **THEN** the close records a tombstone and retains the retirement successor.

#### Scenario: Allocation would consume cleanup reserve

- **GIVEN** an active state with `O` open handles and `O + 2` remaining revision successors
- **WHEN** an otherwise authorized mount would consume that reserve
- **THEN** the mutation is denied and the complete state is unchanged.

#### Scenario: Exact allocation headroom

- **GIVEN** an active state with `O` open handles and `O + 3` remaining revision successors
- **WHEN** an otherwise authorized mount succeeds
- **THEN** its successor retains one cleanup successor per now-open handle and one retirement successor.

### Requirement: FR-003 Complete bounded reserve validation

Reserve validation SHALL count the complete original handle set under a monitor-owned resource bound, and SHALL refuse acceptance if its scan or arithmetic is incomplete.

#### Scenario: Revoked handle still needs cleanup

- **GIVEN** an open handle whose registry capability is revoked
- **WHEN** the open-handle reserve is computed
- **THEN** that handle is included in the required cleanup count.

#### Scenario: Count exceeds admitted work

- **GIVEN** a snapshot cannot be completely scanned within the admitted resource profile
- **WHEN** reserve validation is requested
- **THEN** no successful validation or mutation is returned.

### Requirement: FR-004 Exact legacy migration

Migration SHALL preserve every original handle field, tombstone and allocation watermark while mapping the current V1 Nat revision injectively to V2 words.

#### Scenario: Terminal legacy revision

- **GIVEN** a complete authoritative V1 state at revision `281474976710655` with one open handle
- **WHEN** its authenticated migration is validated and committed
- **THEN** its V2 revision is high `65535` and low `4294967295`
- **AND** the handle and allocation watermark are unchanged.

#### Scenario: Migration is not a V2 mutation

- **GIVEN** the current V1 revision maps exactly to V2 pair P
- **WHEN** the monitor commits the version-control transition
- **THEN** the initial V2 revision is P, without an additional mutation increment.

#### Scenario: Tombstone removed from candidate

- **GIVEN** the original V1 state contains a closed handle
- **WHEN** a migration candidate omits that handle
- **THEN** migration is denied without changing the original state.

### Requirement: FR-005 Monitor-owned migration authority

A qualified integration SHALL serialize migration against the exact authoritative state and authenticate the migration control operation independently of its public records.

#### Scenario: Constructed snapshot is presented as current

- **GIVEN** an untrusted caller constructs a structurally valid V1 state and V2 candidate
- **WHEN** the caller presents those records as an authenticated migration
- **THEN** record construction alone does not establish the monitor's current state or permission to migrate.

#### Scenario: State changes before commit

- **GIVEN** a candidate was evaluated from an earlier authoritative snapshot
- **WHEN** the source state changes before the migration commits
- **THEN** migration is rejected without replacing the current state.

### Requirement: FR-006 Full original-state verification

Migration acceptance SHALL independently verify every relevant original frontend and binding record rather than trusting a producer's work list, supplied count, or digest.

#### Scenario: Producer omits a binding edge

- **GIVEN** an original binding has a descendant edge missing from the producer's candidate list
- **WHEN** the candidate is independently checked
- **THEN** the missing original edge prevents acceptance.

### Requirement: FR-007 Atomic installation and replay fencing

A qualified integration SHALL atomically install the V2 state, version fence and replay record, and SHALL reject restored or delayed V1 state as current after migration.

#### Scenario: Interrupted migration

- **GIVEN** the migration has not atomically committed
- **WHEN** the process stops before installation finishes
- **THEN** no V2 success is exposed and the authoritative old state remains intact.

#### Scenario: Old snapshot returns after commit

- **GIVEN** a migration committed and a later recovery presents the old V1 snapshot
- **WHEN** recovery checks the independently protected active-version record
- **THEN** the old snapshot is not installed as current.

#### Scenario: Acknowledgement is lost after commit

- **GIVEN** the V2 installation committed but its acknowledgement was lost
- **WHEN** recovery determines the outcome from the authoritative transaction record
- **THEN** it retains the committed V2 state and does not apply the migration a second time.

### Requirement: FR-008 Coupled binding requests are version-fenced

The migrated binding facade SHALL reject legacy requests and preserve its independent current-revision and authority checks even when its numeric revision did not change.

#### Scenario: Unchanged binding revision

- **GIVEN** a migration changes the embedded frontend version while the binding revision remains numerically unchanged
- **WHEN** a queued V1 binding request names that old revision
- **THEN** it is denied rather than routed into V2.

### Requirement: FR-009 Binding close is all-or-nothing

Binding close SHALL validate the complete original cut and every distinct required frontend close before exposing destruction, quota refund or a changed state.

#### Scenario: A later derived close is refused

- **GIVEN** a binding cut contains several open descendant handles
- **WHEN** any required close or bounded validation fails
- **THEN** the original complete binding and frontend states are returned unchanged
- **AND** no destruction or quota refund is reported as committed.

### Requirement: FR-010 Retirement preserves history

Retirement SHALL require an empty open-handle set and SHALL retain all closed identifiers and replay-relevant instance history without resetting the active revision.

#### Scenario: Retire after the final close

- **GIVEN** an active V2 instance has no open handles and one retirement successor
- **WHEN** its authorized monitor retires it
- **THEN** the instance is retired at the successor revision with its tombstones preserved.

#### Scenario: Open handle remains

- **GIVEN** an active V2 instance still has an open handle
- **WHEN** retirement is requested
- **THEN** retirement is denied without changing the state.

#### Scenario: Retired instance receives an old request

- **GIVEN** a V2 instance has been retired with its tombstones preserved
- **WHEN** an old request names that instance and version
- **THEN** the retired instance is not reopened or treated as current.

### Requirement: FR-011 Authenticated instance-bound references

A qualified integration SHALL bind each persisted handle reference, binding and session to its authenticated, non-reused frontend instance identity.

#### Scenario: Delayed reference reaches a new instance

- **GIVEN** an old request references a retired instance and a new instance uses the same numeric handle ID
- **WHEN** the old request is presented to the new instance
- **THEN** the old reference is rejected despite matching numeric fields.

#### Scenario: Migrated open handle remains usable

- **GIVEN** migration preserved an open handle and its complete scope, and its capability was subsequently revoked
- **WHEN** its newly authenticated owner presents the exact handle and token in a V2 close request with the current V2 revision
- **THEN** the handle closes and records its tombstone under the owner-cleanup contract.

### Requirement: FR-012 Resources for promised cleanup

A qualified V2 integration SHALL reserve sufficient bounded work and resources to perform each promised owner cleanup under its admitted state profile.

#### Scenario: Admitted revoked handle

- **GIVEN** an admitted V2 state has an open handle whose capability is revoked
- **WHEN** its authenticated owner requests cleanup
- **THEN** the qualified profile supplies the bounded resources needed for the original-handle checks and close.

#### Scenario: Cleanup resources cannot be established

- **GIVEN** a host cannot establish those bounded resources or recovery behavior
- **WHEN** qualification of that profile is evaluated
- **THEN** that host profile is not qualified by the model's reserve calculation alone.
