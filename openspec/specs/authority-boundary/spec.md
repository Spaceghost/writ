# Authority boundary

## Purpose

Define the conditions under which Writ's pure library decisions can be used as authorization. These requirements are integration preconditions and interpretation rules; the library does not itself implement caller authentication, complete dependency extraction, confinement, or durable storage.

## Requirements

### Requirement: AB-001 Decisions are conditional on authoritative inputs

An authorization decision SHALL be interpreted as valid only relative to the monitor-owned facts, current state, and authenticated caller supplied to the library.

#### Scenario: Public record construction does not authenticate authority

- **GIVEN** an untrusted caller constructs a well-formed capability and context record
- **WHEN** the caller presents those records as evidence of permission
- **THEN** record construction alone establishes no authenticated authority
- **AND** a conforming integration uses its own authenticated registry and state.

### Requirement: AB-002 Returned descriptions do not perform external effects

The library's admitted tickets, capability handles, and committed write intents SHALL describe permitted model transitions without themselves reading protected plaintext, exposing OS descriptors, publishing payloads, or settling money.

#### Scenario: Accepted commit remains a model result

- **GIVEN** authoritative fixtures satisfying every commit gate
- **WHEN** the commit operation returns an accepted intent and updated ledger
- **THEN** those values describe the authorized transition
- **AND** actual persistence and output require the enforcing host.

### Requirement: AB-003 Dependency completeness is a caller obligation

A conforming integration SHALL include every data and control source in the authoritative dependency graph and operation manifest before requesting authorization.

#### Scenario: Opaque worker observes an additional source

- **GIVEN** a worker can read documents A and B while producing output from A
- **WHEN** the integration cannot prove that B has no influence
- **THEN** B's restrictions and origin obligations remain dependencies of the output
- **AND** acceptance of a graph that omitted B is not evidence of complete dependency extraction.

### Requirement: AB-004 Identity equality is distinct from execution authenticity

A conforming integration SHALL bind the actual executed operation and sealed output bytes to their registered identities before using identity comparisons as authorization evidence.

#### Scenario: Metadata names one artifact while bytes name another

- **GIVEN** an accepted intent names sealed artifact A
- **WHEN** a host attempts to publish different bytes under that intent
- **THEN** the integration contract forbids publication of the substituted bytes
- **AND** equality of the intent's identifier alone does not verify a payload digest or execution attestation.

### Requirement: AB-005 Protected execution requires complete effect mediation

A conforming integration SHALL mediate every machine-visible output path available to a worker that receives protected data.

#### Scenario: Capability mount coexists with an unchecked socket

- **GIVEN** a process can read protected data through a capability mount
- **WHEN** it also retains an independently usable network socket
- **THEN** that host configuration does not satisfy Writ's enforcement contract
- **AND** the capability mount cannot be presented as complete exfiltration prevention.

### Requirement: AB-006 Authoritative transitions require serialization and durability

A conforming integration SHALL serialize accepted model transitions against current authoritative revisions and preserve their replay state across crashes.

#### Scenario: Old in-memory state is restored

- **GIVEN** an invocation has already committed in authoritative storage
- **WHEN** an integration evaluates a copied pre-commit ledger as if it were current
- **THEN** the integration has violated the authoritative-state contract
- **AND** pure revision checks alone are not rollback-resistant persistence.

### Requirement: AB-007 Untrusted work requires resource admission

A conforming integration SHALL bound request size, graph size, policy depth, numeric range, and evaluation work before admitting untrusted proposals.

#### Scenario: Structurally terminating proposal exhausts resources

- **GIVEN** a proposal is finite but exceeds the host's configured graph-size limit
- **WHEN** the host receives it
- **THEN** the host rejects it before expensive policy evaluation
- **AND** structural termination is not treated as a resource quota.
