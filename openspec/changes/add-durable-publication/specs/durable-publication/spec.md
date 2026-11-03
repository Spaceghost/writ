# Durable publication

## Purpose

Commit policy metadata, replay state, reservations, and exact sealed output through a recoverable transaction that cannot widen authority or publish twice.

## ADDED Requirements

### Requirement: DP-001 Authorization is durable before visibility

Output SHALL remain unavailable to its recipient until the accepted authorization, artifact identity, inherited policy, session transition, and ledger consumption are durably recorded together.

#### Scenario: Crash before authorization record

- **GIVEN** all model checks pass
- **WHEN** the host crashes before the durable commit completes
- **THEN** no recipient-visible output or committed spend is established.

### Requirement: DP-002 Commit validates current revisions

A publication transaction SHALL consume only the current authoritative revisions used by its final checks.

#### Scenario: Concurrent commit attempts

- **GIVEN** two requests target the same invocation and ledger revision
- **WHEN** both attempt durable authorization
- **THEN** at most one transaction commits.

### Requirement: DP-003 Revocation has a defined order with commit

Revocation ordered before the durable authorization point SHALL prevent publication under the revoked authority.

#### Scenario: Revocation wins the race

- **GIVEN** a capability is revoked before commit serialization
- **WHEN** a pending output reaches final authorization
- **THEN** publication is denied.

### Requirement: DP-004 Recovery reuses the exact committed intent

Recovery SHALL resume only the artifact, destination, policy, and billing scope in the durable committed intent.

#### Scenario: Destination changed during restart

- **GIVEN** an outbox records artifact A for destination X
- **WHEN** recovery is asked to deliver it to Y
- **THEN** the redirected delivery is rejected.

### Requirement: DP-005 Delivery deduplicates by committed identity

A supported publication sink SHALL suppress duplicate logical publication of the same committed invocation and artifact.

#### Scenario: Crash after receiver accepted output

- **GIVEN** a receiver has accepted invocation I and artifact A
- **WHEN** the sender restarts before recording the acknowledgement and retries
- **THEN** the receiver recognizes I and A and does not publish a second logical result.

### Requirement: DP-006 Origins and labels persist with payloads

Published and reloaded objects SHALL retain the full inherited policy bound to their committed artifact.

#### Scenario: Reload loses an origin record

- **GIVEN** stored output derives from origins A and B
- **WHEN** a reload attempts to expose the object with only A's obligations
- **THEN** the incomplete policy is rejected.

### Requirement: DP-007 Rollback cannot reset consumed authority

Recovery SHALL deny new publication when it cannot establish that authority epochs and consumed invocation/receipt records are current.

#### Scenario: Restoring an old ledger snapshot

- **GIVEN** a receipt was consumed after backup time
- **WHEN** the host restarts from that old backup without an authoritative reconciliation point
- **THEN** it denies new publication rather than reusing the receipt.

### Requirement: DP-008 Unsupported idempotency is explicit

A sink lacking a verified deduplication or transactional publication contract SHALL be denied publication through this capability.

#### Scenario: Raw external sink without deduplication

- **GIVEN** an output target cannot identify repeated invocations
- **WHEN** the host considers that target for an exactly-once operation
- **THEN** the operation is denied without publishing or consuming an additional receipt.
