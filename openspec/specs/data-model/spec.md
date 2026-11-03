# Data Model Specification

## Purpose

Define the finite type, restriction, identity, and version domains used by Writ's
security-core library. These values describe authoritative facts supplied by a
monitor; constructing a value does not authenticate it. Numeric IDs, amounts,
times, and counters currently use the pinned runtime's bounded natural-number
arithmetic, whose compiled cap is 2^48−1. This is a documented runtime limit, not
a library-level checked-overflow result or an arbitrary-precision guarantee.

## Requirements

### Requirement: DM-001 Finite static type domains

The model SHALL represent static type possibilities as nonempty subsets of document, summary, text, bytes, event, tensor, boolean, and integer.

#### Scenario: Fully unknown static type

- **GIVEN** a node with all eight supported possibilities
- **WHEN** the graph is validated without contradictory constraints
- **THEN** the type domain is accepted
- **AND** that acceptance does not convert any runtime value to another schema

#### Scenario: Empty seed domain

- **GIVEN** a node whose seed contains no type possibilities
- **WHEN** the graph is validated
- **THEN** the graph is rejected

#### Scenario: Unsupported type bit

- **GIVEN** a node whose type mask contains bit 8, outside the eight supported possibilities
- **WHEN** the graph is validated
- **THEN** the graph is rejected

### Requirement: DM-002 Separate restriction dimensions

The model SHALL retain confidentiality, untrusted provenance, and required effects as separate restriction dimensions alongside the static type domain.

#### Scenario: Confidentiality clearance does not establish integrity

- **GIVEN** a verified summary whose secrecy is covered by a destination
- **AND** its untrusted provenance is not tolerated by that destination
- **WHEN** sink authorization is requested
- **THEN** authorization is denied for integrity

#### Scenario: Clear data still requires an effect grant

- **GIVEN** a verified node with no secrecy or untrusted-provenance bits
- **AND** it requires a network effect
- **WHEN** the destination grants no effects
- **THEN** sink authorization is denied for effects

### Requirement: DM-003 Exact 64-bit restrictions

Restriction union, intersection, equality, and containment SHALL preserve all 64 bits without treating high-word restrictions as equivalent to low-word restrictions.

#### Scenario: Union retains the boundary and highest bits

- **GIVEN** one restriction contains bits 0 and 63
- **AND** another contains bits 1 and 32
- **WHEN** their union is calculated
- **THEN** the result contains exactly bits 0, 1, 32, and 63

#### Scenario: Low-word permission does not cover bit 63

- **GIVEN** a required restriction contains only bit 63
- **WHEN** containment is checked against permission for every low-word bit and no high-word bits
- **THEN** containment is false

#### Scenario: Intersection preserves high-word identity

- **GIVEN** the two restriction values have low/high words 7/2147483649 and 3/2147483648
- **WHEN** their intersection is calculated
- **THEN** the result has low/high words 3/2147483648

### Requirement: DM-004 Complete snapshot identity

Snapshot equality SHALL compare graph generation, policy generation, and authority epoch in full, including every bit of the constraint model's 64-bit components.

#### Scenario: Only authority's high word changes

- **GIVEN** a graph and candidate share the earlier snapshot
- **WHEN** the live authority epoch differs only in its high word
- **THEN** verification rejects the earlier snapshot

#### Scenario: Policy generation changes independently

- **GIVEN** the graph generation and authority epoch are unchanged
- **WHEN** the live policy generation changes
- **THEN** the earlier candidate is stale

### Requirement: DM-005 Exact 256-bit identities

Equality for operation identities, capability tokens, and output artifact identities SHALL compare all 256 bits.

#### Scenario: Operation identity differs in its final word

- **GIVEN** a read grant pins one operation identity
- **WHEN** the requested identity differs only in the final U32 word
- **THEN** the grant does not authorize that request

#### Scenario: Capability token differs outside its prefix

- **GIVEN** the registry contains a capability with a specific 256-bit token
- **WHEN** a mount request presents a token sharing its prefix but differing in its final word
- **THEN** lookup does not match the registered capability

#### Scenario: Output artifact identity is retained

- **GIVEN** a trusted execution binding names a complete 256-bit artifact identity
- **WHEN** final commit succeeds
- **THEN** its write intent retains that exact identity
- **AND** an identity differing in the final word is unequal

### Requirement: DM-006 Versioned ordered source identity

Source-manifest equality SHALL preserve each object's version and the complete ordered sequence of source occurrences.

#### Scenario: Source version changes

- **GIVEN** an approved read names object 10 at version 4
- **WHEN** an otherwise matching request uses object 10 at version 5
- **THEN** the earlier read does not authorize the changed source

#### Scenario: Source manifest expands

- **GIVEN** a read grant binds a one-source manifest
- **WHEN** the operation requests an additional source
- **THEN** the old grant does not authorize the expanded manifest

#### Scenario: Manifest order differs

- **GIVEN** two unequal versioned sources A and B
- **WHEN** the manifests [A, B] and [B, A] are compared
- **THEN** the manifests are unequal

#### Scenario: Repeated source occurrence is explicit

- **GIVEN** a versioned source A
- **WHEN** the manifests [A] and [A, A] are compared
- **THEN** the manifests are unequal
- **AND** manifest equality itself does not create a per-occurrence payment rule
