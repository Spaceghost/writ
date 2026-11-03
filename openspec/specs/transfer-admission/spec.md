# Transfer admission

## Purpose

Decide whether a complete, versioned operation has compatible source-read and
destination-write authority before any protected transfer is admitted. This
baseline covers the pure decision library over monitor-supplied authoritative
records. It does not authenticate or mint grants, move bytes, or settle payments.
Origin preservation is specified separately in
[provenance-preservation](../provenance-preservation/spec.md).

## Requirements

### Requirement: TA-001 Paired authority for every admitted transfer

Admission SHALL require a matching source-read grant for every input and a
matching destination-write grant for the same operation.

#### Scenario: Complete paired authority

- **GIVEN** a valid one-source plan with matching read and write grants and all other conditions satisfied
- **WHEN** the plan is evaluated
- **THEN** admission returns an accepted ticket for that plan

#### Scenario: Missing source permission

- **GIVEN** a valid destination-write grant but no read grant for one input
- **WHEN** the plan is evaluated
- **THEN** admission is denied

#### Scenario: Missing destination permission

- **GIVEN** valid read grants for every input but no matching write grant
- **WHEN** the plan is evaluated
- **THEN** admission is denied

### Requirement: TA-002 Complete ordered input manifest

Admission SHALL require a nonempty input manifest whose ordered object versions
and length match the supplied source policies and the registered operation's
input-schema slots.

#### Scenario: Expanded manifest under an old grant

- **GIVEN** a read grant scoped to input A and a proposed plan using inputs A and B
- **WHEN** the expanded plan is evaluated with that old read grant
- **THEN** admission is denied even if B has its own otherwise valid source policy

#### Scenario: Reordered source policies

- **GIVEN** a manifest ordered A then B and source policies ordered B then A
- **WHEN** the plan is evaluated
- **THEN** admission is denied

#### Scenario: Empty manifest

- **GIVEN** a plan with no input objects
- **WHEN** the plan is evaluated
- **THEN** admission is denied

### Requirement: TA-003 Exact source identity and read domain

Each source-read grant SHALL match the source object identifier, object version,
and read-security domain named by the corresponding authoritative source policy.

#### Scenario: Wrong read domain

- **GIVEN** an input in read domain 5 and a grant for read domain 6
- **WHEN** the plan is evaluated
- **THEN** the grant does not authorize the input

#### Scenario: Same object with another version

- **GIVEN** an input at object 10 version 4 and a grant for object 10 version 5
- **WHEN** the plan is evaluated
- **THEN** admission is denied

### Requirement: TA-004 Destination agreement across both authorities

Both read and write grant scopes SHALL bind the plan's exact destination object
version and the destination policy's write-security domain.

#### Scenario: New writer redirects an old read

- **GIVEN** a source-read grant approved for destination A
- **WHEN** a plan substitutes destination B and supplies a fresh write grant for B
- **THEN** admission is denied because the old read grant does not authorize B

#### Scenario: Write-domain substitution

- **GIVEN** a source-read grant scoped to write domain 6
- **WHEN** the same destination is presented under write domain 9 with a new write grant
- **THEN** admission is denied

#### Scenario: Wrong destination version in the writer grant

- **GIVEN** a plan for destination version 8 and a write grant for version 9
- **WHEN** the plan is evaluated
- **THEN** admission is denied

### Requirement: TA-005 Invocation and operation scope

Each accepted grant SHALL match the plan's invocation, complete 256-bit code
identity, operation kind, and complete ordered input manifest.

#### Scenario: Invocation substitution

- **GIVEN** a plan for invocation 99 and a write grant scoped to invocation 100
- **WHEN** the plan is evaluated
- **THEN** admission is denied

#### Scenario: Code identity differs only in its final word

- **GIVEN** a read grant whose first seven code-identity words match the plan but whose eighth word differs
- **WHEN** the plan is evaluated
- **THEN** admission is denied

#### Scenario: Summary grant used for a transform

- **GIVEN** a grant scoped to summarization and a plan requesting transformation
- **WHEN** the plan is evaluated
- **THEN** that grant does not authorize the plan

### Requirement: TA-006 Current graph policy and authority epochs

Admission SHALL reject a plan or grant whose graph, policy, or authority stamp
differs from the live snapshot, or a source, destination, or registered operation
whose policy epoch differs from that snapshot.

#### Scenario: Authority changed after approval

- **GIVEN** a plan and grants at authority epoch 3
- **WHEN** admission uses a live snapshot at authority epoch 4
- **THEN** admission is denied

#### Scenario: Source metadata is stale within a current plan

- **GIVEN** a current plan, current grants, and a source policy from an older policy epoch
- **WHEN** the plan is evaluated
- **THEN** admission is denied

### Requirement: TA-007 Exclusive expiry for grant use

A read or write grant SHALL authorize use only while the supplied current time
is strictly less than that grant's expiry.

#### Scenario: Use before expiry

- **GIVEN** matching grants expiring at time 200 and all other conditions satisfied
- **WHEN** admission runs at time 199
- **THEN** those grants remain eligible

#### Scenario: Use at the expiry boundary

- **GIVEN** matching grants expiring at time 200
- **WHEN** admission runs at time 200
- **THEN** admission is denied

### Requirement: TA-008 Registered operation approval

Admission SHALL require the plan's code identity and operation kind to match the
current registered operation.

#### Scenario: Registered code differs

- **GIVEN** a plan and grants for code A but a registered operation for code B
- **WHEN** the plan is evaluated
- **THEN** admission is denied

#### Scenario: Registered kind differs

- **GIVEN** a summarization plan but a registered operation of kind copy
- **WHEN** the plan is evaluated
- **THEN** admission is denied

### Requirement: TA-009 Runtime schema agreement

Admission SHALL require each source and the declared output to have one supported
atomic schema, each source schema to fit its registered input slot, and the output
schema to equal the registered output and fit the destination's accepted types.

#### Scenario: Ambiguous runtime source schema

- **GIVEN** a source policy naming two possible atomic schemas instead of one
- **WHEN** the plan is evaluated
- **THEN** admission is denied

#### Scenario: Output schema substitution

- **GIVEN** a registered operation producing a summary and a plan declaring bytes
- **WHEN** the plan is evaluated
- **THEN** admission is denied even if the destination accepts both schemas

#### Scenario: Valid exact schema

- **GIVEN** document inputs accepted by their registered slots, a registered summary output, and a destination accepting summaries
- **WHEN** a summary plan with otherwise valid authority is evaluated
- **THEN** schema checking permits admission

### Requirement: TA-010 Scoped source-payment prerequisites

Every applicable origin charge SHALL require a live payment witness matching the
origin object version, invocation, code identity, operation kind, destination
object version, and quote, with current time strictly before witness expiry.

#### Scenario: One of two origins is unpaid

- **GIVEN** a two-origin summary for which both origins require payment
- **WHEN** only the first origin has a matching payment witness
- **THEN** admission is denied

#### Scenario: Payment belongs to another destination

- **GIVEN** a valid payment witness for destination A
- **WHEN** a plan for destination B presents that witness
- **THEN** the witness does not satisfy the charge

#### Scenario: Payment reaches its deadline

- **GIVEN** an otherwise matching witness expiring at time 100
- **WHEN** admission runs at time 100
- **THEN** the witness does not satisfy the charge

#### Scenario: Charge excludes the requested kind

- **GIVEN** an origin charge applying only to summarization
- **WHEN** an otherwise valid copy plan is evaluated without a payment witness
- **THEN** that charge does not prevent the copy

### Requirement: TA-011 Destination confidentiality and integrity limits

Admission SHALL reject derived output when its secrecy restrictions exceed the
destination's clearance or its untrusted influences exceed the destination's
tolerated influences.

#### Scenario: Secret summary directed to public storage

- **GIVEN** an approved summary operation over a secret source and a destination with no secrecy clearance
- **WHEN** the plan is evaluated
- **THEN** admission is denied despite valid read and write grants

#### Scenario: Integrity mismatch with adequate secrecy clearance

- **GIVEN** a destination that covers all output secrecy but tolerates none of the output's untrusted influence
- **WHEN** the plan is evaluated
- **THEN** admission is denied

### Requirement: TA-012 Admission is a pure decision

Transfer admission SHALL return either a denial or a ticket containing the exact
plan and derived output policy without consuming grants, payment witnesses,
reservations, or invocation identities.

#### Scenario: Identical evaluation repeats

- **GIVEN** an accepted plan and an unchanged authoritative snapshot
- **WHEN** admission is evaluated again with the same inputs
- **THEN** it returns the same accepted decision
- **AND** neither call itself performs a write or consumes a receipt

#### Scenario: Conditions change after ticket creation

- **GIVEN** an earlier accepted ticket and a current snapshot missing its source-read grant
- **WHEN** the plan is evaluated against the current snapshot
- **THEN** admission is denied regardless of possession of the earlier ticket
