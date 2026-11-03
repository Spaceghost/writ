# Candidate Verification Specification

## Purpose

Check proposed assignments against the authoritative original graph and check
whether a verified assignment fits a particular sink. A successful calculation
or a stable producer output is not authority. Verification depends on complete
monitor-supplied original facts and remains a pure decision without performing IO.

## Requirements

### Requirement: CV-001 Verify against the original graph

Verification SHALL evaluate the validated original graph's seeds and constraints rather than accepting a producer's claim that its prepared work or result is complete.

#### Scenario: Producer reports a stable forged assignment

- **GIVEN** the original graph contains source restrictions
- **AND** a producer returns a stable assignment omitting them
- **WHEN** that assignment is checked against the original graph
- **THEN** verification denies the candidate

#### Scenario: Original graph contains an invalid endpoint

- **GIVEN** an original graph edge refers to a node outside its node list
- **WHEN** verification is requested with any candidate
- **THEN** the graph is rejected as invalid

### Requirement: CV-002 Require exact candidate shape

Verification SHALL require exactly one candidate state for every original node in original node order.

#### Scenario: Candidate truncates the node list

- **GIVEN** a nonempty valid original graph
- **WHEN** its candidate contains no nodes
- **THEN** verification denies the candidate

#### Scenario: Candidate inserts an extra node

- **GIVEN** a complete otherwise-valid candidate
- **WHEN** an extra state is prepended to its node list
- **THEN** verification denies the candidate

### Requirement: CV-003 Require the live snapshot

Verification SHALL require the original graph stamp and candidate stamp to equal the complete live snapshot stamp.

#### Scenario: Graph generation changes

- **GIVEN** a graph and candidate were created under graph generation 1
- **WHEN** the live graph generation is 2
- **THEN** verification denies the stale snapshot

#### Scenario: Candidate alone has a stale stamp

- **GIVEN** the graph's stamp matches the live snapshot
- **WHEN** the candidate carries a different stamp
- **THEN** verification denies the stale snapshot

#### Scenario: Authority changes only in a high bit

- **GIVEN** graph and candidate stamps agree on their lower words
- **WHEN** the live authority epoch differs in bit 63
- **THEN** verification denies the stale snapshot

### Requirement: CV-004 Preserve admissible static type choices

Verification SHALL require every candidate type domain to be nonempty and contained in its corresponding seed domain.

#### Scenario: Candidate erases all type possibilities

- **GIVEN** an original node has a valid nonempty type domain
- **WHEN** its candidate domain is empty
- **THEN** verification denies the candidate

#### Scenario: Candidate invents an unsupported type

- **GIVEN** an original domain uses supported type bits only
- **WHEN** its candidate introduces type bit 8
- **THEN** verification denies the candidate

### Requirement: CV-005 Retain every source restriction

Verification SHALL require each candidate node to include its seed's confidentiality, untrusted-provenance, and required-effect restrictions.

#### Scenario: Source secrecy is omitted

- **GIVEN** a seed carries secrecy bit 0
- **WHEN** the candidate clears that bit at the source node
- **THEN** verification denies the candidate

#### Scenario: Source provenance is omitted

- **GIVEN** a seed carries untrusted-provenance bit 1
- **WHEN** the candidate clears that bit at the source node
- **THEN** verification denies the candidate

#### Scenario: Source effect is omitted

- **GIVEN** a callee seed requires the network effect
- **WHEN** the candidate removes that required effect from the callee
- **THEN** verification denies the candidate

### Requirement: CV-006 Check every data/control implication

Verification SHALL require each flow-edge destination to include the candidate source's confidentiality and untrusted provenance.

#### Scenario: Derived secrecy is omitted

- **GIVEN** a candidate source carries secrecy bit 0 across an original flow edge
- **WHEN** the destination candidate omits that bit
- **THEN** verification denies the candidate

#### Scenario: Derived provenance is omitted

- **GIVEN** a candidate source carries untrusted-provenance bit 1 across an original flow edge
- **WHEN** the destination candidate omits that bit
- **THEN** verification denies the candidate

### Requirement: CV-007 Check every static equality

Verification SHALL require equal candidate type domains at both endpoints of every original equality edge.

#### Scenario: An equality endpoint retains a wider domain

- **GIVEN** the seed domains allow a summary-only assignment at both equality endpoints
- **WHEN** one candidate endpoint retains all eight possibilities while the other is summary-only
- **THEN** verification denies the candidate

### Requirement: CV-008 Check every call-effect implication

Verification SHALL require each caller to include the candidate callee's required effects along every original call edge.

#### Scenario: Caller conceals a callee's network effect

- **GIVEN** a candidate callee retains its required network effect
- **WHEN** the caller candidate omits that effect
- **THEN** verification denies the candidate

### Requirement: CV-009 Accept conservative closed assignments

Candidate verification SHALL permit additional restrictions when all other original-graph checks hold, without requiring proof that the assignment is the least restrictive solution.

#### Scenario: Additional restrictions remain closed

- **GIVEN** a valid candidate
- **WHEN** additional secrecy, untrusted-provenance, and effect bits are added to every node so all implications remain satisfied
- **THEN** candidate verification succeeds

#### Scenario: Additional restrictions still bind the sink

- **GIVEN** the additional restrictions exceed a sink's secrecy clearance
- **WHEN** sink authorization follows successful candidate verification
- **THEN** the sink is denied

### Requirement: CV-010 Enforce destination data policy

Sink authorization SHALL require both the verified node's confidentiality to fit the destination clearance and its untrusted provenance to fit the destination's tolerance.

#### Scenario: Secret summary targets a public destination

- **GIVEN** a verified summary retains its source's secrecy bit
- **WHEN** the selected sink has no secrecy clearance
- **THEN** authorization is denied for confidentiality

#### Scenario: Confidentiality fits but provenance does not

- **GIVEN** the sink covers all secrecy restrictions
- **WHEN** it omits a required untrusted-provenance bit from its tolerance
- **THEN** authorization is denied for integrity

#### Scenario: Destination covers both data-policy dimensions

- **GIVEN** the candidate is verified and the actual effect is granted
- **WHEN** the sink covers all secrecy and untrusted-provenance bits
- **THEN** sink authorization succeeds

### Requirement: CV-011 Cover both derived and requested effects

Sink authorization SHALL require live grants for the union of the verified node's required effects and the actual requested effect.

#### Scenario: Request adds a network effect

- **GIVEN** a verified node has no inherited network effect
- **WHEN** the request performs a network effect without a network grant
- **THEN** authorization is denied for effects

#### Scenario: Empty request mask cannot erase an inherited effect

- **GIVEN** the verified node inherits a callee's network effect
- **WHEN** the request declares an empty requested-effect mask and grants no effects
- **THEN** authorization is denied for effects

#### Scenario: High-word required effect lacks coverage

- **GIVEN** the verified node requires effect bit 63
- **WHEN** the sink grants only the corresponding low-word effects
- **THEN** authorization is denied for effects

### Requirement: CV-012 Reject nonexistent sink nodes without wrapping

Sink authorization SHALL deny a node index outside the verified candidate's node list instead of wrapping it to another node.

#### Scenario: Maximal U32 sink index

- **GIVEN** a verified five-node candidate
- **WHEN** the selected sink index is 4294967295
- **THEN** authorization reports an unknown node
- **AND** no existing node is selected by wraparound
