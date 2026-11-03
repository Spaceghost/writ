# Decentralized Labels Specification

## Purpose

Evaluate a finite owner-sensitive decentralized label model with separate
confidentiality and integrity policies. The registered principal universe and
delegation facts are monitor-supplied, epoch-bound inputs. This is a finite
semantic fragment, not the full Jif language or a signature verifier. A permitted
label flow does not mint a capability, owner approval, payment, declassification,
or integrity endorsement.

## Requirements

### Requirement: DL-001 Bound and validate the principal universe

Label admission SHALL support Top, Bottom, and at most 30 registered named principals while rejecting unknown, compound, and unsupported principals.

#### Scenario: Highest supported named principal

- **GIVEN** a registry with 30 names numbered 0 through 29
- **WHEN** its snapshot is prepared and principal 29 is checked against itself
- **THEN** preparation succeeds and reflexive authority is recognized

#### Scenario: Registry exceeds the supported universe

- **GIVEN** a request to prepare a snapshot with 31 named principals
- **WHEN** preparation is attempted
- **THEN** preparation returns no valid snapshot

#### Scenario: Unknown principal in a reflexive-looking policy

- **GIVEN** only names 0 through 2 are registered
- **WHEN** a policy using name 3 is compared with itself
- **THEN** label admission denies the query

#### Scenario: Unsupported compound principal

- **GIVEN** a policy contains an unsupported principal expression
- **WHEN** a flow involving that policy is requested
- **THEN** label admission denies the query

### Requirement: DL-002 Preserve delegation direction and closure

Authority evaluation SHALL include reflexivity, Top acting for every registered principal, every registered principal acting for Bottom, and the directed transitive closure of supplied delegations.

#### Scenario: Delegation is transitive but not reversed

- **GIVEN** principal 0 acts for principal 1 and principal 1 acts for principal 2
- **WHEN** authority is evaluated in their current snapshot
- **THEN** principal 0 acts for principal 2
- **AND** principal 2 does not gain authority for principal 0

#### Scenario: Top and Bottom keep their defined positions

- **GIVEN** a valid registry with principal 2 and no extra delegations
- **WHEN** authority is evaluated
- **THEN** Top acts for principal 2 and principal 2 acts for Bottom
- **AND** principal 2 does not implicitly act for Top

#### Scenario: No named principals are registered

- **GIVEN** a request to prepare a universe with zero named principals
- **WHEN** preparation is attempted
- **THEN** a valid snapshot containing Top and Bottom is produced

### Requirement: DL-003 Verify exact authority closure

Snapshot validation SHALL require the supplied authority relation to equal the complete closure of its declared principal universe and delegations.

#### Scenario: Invented authority bit

- **GIVEN** no delegation grants principal 0 authority over principal 1
- **WHEN** the supplied relation adds that authority
- **THEN** snapshot validation rejects it

#### Scenario: Declared delegation omitted from the relation

- **GIVEN** a declared delegation grants principal 0 authority over principal 1
- **WHEN** the supplied relation omits that authority
- **THEN** snapshot validation rejects it

#### Scenario: Malformed relation shape

- **GIVEN** a five-principal universe including Top and Bottom
- **WHEN** the supplied relation contains only one row
- **THEN** snapshot validation rejects it

#### Scenario: Out-of-universe authority bit

- **GIVEN** a snapshot has five registered principal slots
- **WHEN** one relation row includes an additional sixth-slot bit
- **THEN** snapshot validation rejects it

### Requirement: DL-004 Require the expected authority epoch

Authority and label-flow admission SHALL deny a request whose expected epoch differs from the supplied snapshot's epoch.

#### Scenario: Stale authority query

- **GIVEN** a valid snapshot at epoch 7
- **WHEN** an authority query expects epoch 8
- **THEN** it is denied even for Top acting for Bottom

#### Scenario: Stale otherwise-permitted flow

- **GIVEN** a valid snapshot at epoch 7
- **WHEN** a public-to-public flow expects epoch 8
- **THEN** it is denied

### Requirement: DL-005 Evaluate atomic policy ownership

For observer p, an atomic policy owned by o with delegate d SHALL admit candidate reader or writer q exactly when o does not act for p, or q acts for o, or q acts for d.

#### Scenario: Credited owner names a delegate

- **GIVEN** Alice owns a rule naming Bob and there are no extra delegations
- **WHEN** the rule is evaluated from Alice's perspective
- **THEN** its candidate set includes Alice, Bob, and Top
- **AND** it excludes Mallory and Bottom

#### Scenario: Observer does not credit the owner

- **GIVEN** Alice owns a rule naming Bob
- **AND** Alice does not act for observer Bob
- **WHEN** that rule is evaluated from Bob's perspective
- **THEN** its reader and possible-writer sets contain the whole registered universe

### Requirement: DL-006 Use confidentiality's join and meet directions

Confidentiality policy join SHALL intersect reader sets, while confidentiality policy meet SHALL union reader sets.

#### Scenario: Confidentiality join narrows readers

- **GIVEN** Alice owns one rule naming Bob and another naming Mallory
- **WHEN** their join is evaluated from Alice's perspective without extra delegations
- **THEN** its readers are Alice and Top

#### Scenario: Confidentiality meet broadens readers

- **GIVEN** the same two rules
- **WHEN** their meet is evaluated from Alice's perspective
- **THEN** its readers are Alice, Bob, Mallory, and Top

### Requirement: DL-007 Use integrity's dual join and meet directions

Integrity policy join SHALL union possible-writer sets, while integrity policy meet SHALL intersect possible-writer sets.

#### Scenario: Integrity join preserves either influence

- **GIVEN** Alice owns one writer rule naming Bob and another naming Mallory
- **WHEN** their join is evaluated from Alice's perspective without extra delegations
- **THEN** the possible writers are Alice, Bob, Mallory, and Top

#### Scenario: Integrity meet requires common possible writers

- **GIVEN** the same two writer rules
- **WHEN** their meet is evaluated from Alice's perspective
- **THEN** the possible writers are Alice and Top

### Requirement: DL-008 Prevent reader-set widening

Confidentiality flow admission SHALL require the destination's reader set to be contained in the source's reader set for every registered observer.

#### Scenario: Public information acquires restrictions

- **GIVEN** a public source and an Alice-owned destination restricted to Alice and Bob
- **WHEN** their confidentiality flow is checked under a valid current snapshot
- **THEN** the confidentiality flow is permitted

#### Scenario: Protected information targets a public sink

- **GIVEN** an Alice-owned source restricted to Alice and Bob
- **WHEN** its destination is public
- **THEN** confidentiality flow is denied
- **AND** an uncredited observer's permissive view does not override Alice's restrictive view

#### Scenario: Reader set narrows to the owner

- **GIVEN** a source readable by Alice and Bob under Alice's policy
- **WHEN** the destination retains only Alice and principals acting for her
- **THEN** confidentiality flow is permitted

### Requirement: DL-009 Prevent removal of possible writers

Integrity flow admission SHALL require the source's possible-writer set to be contained in the destination's possible-writer set for every registered observer.

#### Scenario: Trusted information loses integrity

- **GIVEN** trusted source information and an untrusted destination
- **WHEN** their integrity flow is checked under a valid current snapshot
- **THEN** the integrity flow is permitted

#### Scenario: Untrusted information attempts endorsement

- **GIVEN** an untrusted source and a destination requiring trusted provenance
- **WHEN** their integrity flow is checked
- **THEN** the flow is denied

#### Scenario: Bob's possible influence is removed

- **GIVEN** Alice's source policy includes Bob among possible writers
- **WHEN** the destination's Alice-owned policy removes Bob without another authorization mechanism
- **THEN** integrity flow is denied

### Requirement: DL-010 Retain both data and control labels

Combining a result with a data or control dependency SHALL join both confidentiality and integrity label components.

#### Scenario: Secret control selects a public value

- **GIVEN** a public value depends on secret control information
- **WHEN** their dependency label is combined and checked against a public destination
- **THEN** the flow is denied for the retained secrecy restriction

#### Scenario: Untrusted dependency influences a trusted value

- **GIVEN** a trusted value depends on untrusted information
- **WHEN** their labels are joined and checked against a trusted destination
- **THEN** the flow is denied for the retained untrusted influence

### Requirement: DL-011 Preserve whole-label lattice bounds

For valid labels under one current principal snapshot, label join SHALL be an upper bound and label meet SHALL be a lower bound in the permitted-flow ordering.

#### Scenario: Joined label is a permitted restriction

- **GIVEN** an Alice-and-Bob secret label and a stricter Alice-only label
- **WHEN** the original secret label flows to their join
- **THEN** the flow is permitted

#### Scenario: Met label can flow to the original label

- **GIVEN** the same two valid labels
- **WHEN** their meet flows to the Alice-and-Bob secret label
- **THEN** the flow is permitted
