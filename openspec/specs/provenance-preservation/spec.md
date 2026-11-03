# Provenance preservation

## Purpose

Preserve the restrictions of every contributing origin when data is copied,
transformed, summarized, or presented again as a derived source. This baseline
describes policy decisions and returned metadata. The monitor supplies the
complete source and origin records; the library cannot recover an origin omitted
from those authoritative inputs. Grant and payment admission is specified in
[transfer-admission](../transfer-admission/spec.md).

## Requirements

### Requirement: PP-001 Nonempty valid origin policy

Admission and origin discovery SHALL reject a source policy with no inherited
origins or with operation flags outside the supported copy, transform, and
summarize kinds.

#### Scenario: Provenance removed from a source

- **GIVEN** an otherwise valid source policy whose origin list is empty
- **WHEN** it is used for admission or origin discovery
- **THEN** the request is rejected

#### Scenario: Unknown operation flag

- **GIVEN** a source or origin payment rule containing an unsupported operation flag
- **WHEN** the source is evaluated
- **THEN** it is rejected as an invalid policy

### Requirement: PP-002 Source labels include every origin's restrictions

A source policy SHALL retain at least all secrecy and untrusted-influence bits
declared by each inherited origin.

#### Scenario: Source omits an origin secrecy bit

- **GIVEN** an origin requiring secrecy bit 2 and a derived source omitting bit 2
- **WHEN** admission or origin discovery checks that source
- **THEN** the source is rejected

#### Scenario: Source omits an origin integrity influence

- **GIVEN** an origin declaring an untrusted influence that its source policy omits
- **WHEN** the source is evaluated
- **THEN** the source is rejected even if its secrecy restrictions are intact

### Requirement: PP-003 Derived sources cannot widen origin operation rights

A derived source's allowed operation kinds SHALL be a subset of every inherited
origin's allowed kinds.

#### Scenario: Bucket owner adds a forbidden operation

- **GIVEN** an origin permitting summarization only
- **WHEN** a derived source advertises copy, transform, and summarize rights
- **THEN** the source policy is rejected

#### Scenario: Further restriction is retained

- **GIVEN** origins permitting all three operation kinds and a source permitting only summarization
- **WHEN** an otherwise authorized summary is admitted
- **THEN** the source's narrower operation restriction remains in the output

### Requirement: PP-004 Every origin approves the operation identity

Admission SHALL require every inherited origin to permit the requested operation
kind and include the exact requested code identity in its approved-code set.

#### Scenario: One origin has no approved code

- **GIVEN** a source origin whose approved-code set is empty
- **WHEN** a plan requests an otherwise registered operation
- **THEN** admission is denied

#### Scenario: Summary requested from a copy-only origin

- **GIVEN** an origin permitting copy only
- **WHEN** a plan requests summarization
- **THEN** admission is denied

#### Scenario: Another origin cannot override a restriction

- **GIVEN** two inherited origins where only the first approves the requested code
- **WHEN** their combined source is used in that operation
- **THEN** admission is denied

### Requirement: PP-005 Derived labels accumulate across all contributors

Derived output SHALL carry the union of all source and inherited-origin secrecy
bits and the union of all source and inherited-origin untrusted-influence bits,
regardless of whether the operation copies, transforms, or summarizes data.

#### Scenario: Multiple origins including the highest bit

- **GIVEN** two sources with different secrecy and untrusted-influence bits, including secrecy bit 63
- **WHEN** their summary is admitted to a compatible destination
- **THEN** its output policy contains every contributing bit, including bit 63

#### Scenario: Encoding is not label removal

- **GIVEN** a transform or summary that changes protected source bytes
- **WHEN** its derived policy is computed
- **THEN** source restrictions remain present regardless of the new representation
- **AND** a destination lacking those clearances is rejected under transfer admission

### Requirement: PP-006 Output operation rights only narrow

Derived output SHALL carry the intersection of destination, source, and inherited
origin operation-kind permissions.

#### Scenario: Destination narrows the output

- **GIVEN** sources and origins allowing all operation kinds and a destination allowing summaries only
- **WHEN** an otherwise authorized summary is admitted
- **THEN** the output policy allows summaries only

#### Scenario: Destination cannot expand an origin

- **GIVEN** an origin and its source allowing summaries only and a destination allowing all operation kinds
- **WHEN** a summary is admitted
- **THEN** the output policy still allows summaries only

### Requirement: PP-007 Copies preserve one source's schema

A copy SHALL have exactly one input source and an output schema identical to
that source's atomic schema.

#### Scenario: Valid protected copy

- **GIVEN** one document source, a document output, and all required copy permissions
- **WHEN** the copy is evaluated
- **THEN** it may be admitted with its original restrictions retained

#### Scenario: Copy used to change schema

- **GIVEN** a document source and a plan labeling a summary-producing operation as copy
- **WHEN** its declared output schema differs from the source
- **THEN** admission is denied

#### Scenario: Copy used to combine sources

- **GIVEN** a copy plan containing two sources
- **WHEN** the plan is evaluated
- **THEN** admission is denied

### Requirement: PP-008 Complete origin records survive derivation

Derived output and its conversion to a new source policy SHALL retain every
inherited origin record, including origin version, labels, operation limits,
approved code identities, and payment rule.

#### Scenario: Summary becomes a source in another domain

- **GIVEN** an admitted summary containing an origin code restriction and a charge rule
- **WHEN** its output policy is converted to a source with a new object identity and read domain
- **THEN** the original code restriction and charge rule remain attached to their original origin version

#### Scenario: Two source origin lists are combined

- **GIVEN** sources A and B with inherited origin lists in their authoritative order
- **WHEN** output provenance is derived
- **THEN** A's complete origin records are followed by B's complete origin records without dropping either list

### Requirement: PP-009 Origin discovery precedes permission collection

Origin discovery SHALL return all inherited origin object versions in source and
origin order only after validating the current plan stamp, complete source
manifest, source policy epochs, schemas, and inherited-policy well-formedness.

#### Scenario: Discover owners before collecting grants

- **GIVEN** valid current source policies for a two-source plan and no read grants, write grants, or payment witnesses
- **WHEN** origin discovery runs
- **THEN** it returns the complete ordered origin list
- **AND** that discovery result alone does not admit the transfer

#### Scenario: Source metadata cannot support discovery

- **GIVEN** stale source authority, a mismatched object version, or a malformed source schema
- **WHEN** origin discovery runs
- **THEN** it returns no valid origin list
