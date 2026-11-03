# Policy-aware audit

## Purpose

Persist and expose scoped authorization evidence without allowing logs, queries,
errors, or automatic telemetry to bypass Writ's information-flow policy. This
delta specifies a future audit service with explicit durability and trust
boundaries; it does not describe implemented logging or prove timing isolation.

## ADDED Requirements

### Requirement: AU-001 Minimal scoped event records

Audit records SHALL contain only allowlisted event and operation-scope metadata,
including relevant version and authority identities, excluding payload bytes,
credentials, capability tokens, request bodies, and unrestricted error text.

#### Scenario: Error includes protected content

- **GIVEN** an execution error contains source text and a capability token
- **WHEN** an audit event is constructed
- **THEN** neither value is copied into the event
- **AND** the event retains only its permitted structured scope and outcome fields

#### Scenario: Committed operation is recorded

- **GIVEN** an accepted invocation with exact object versions and authority epochs
- **WHEN** its committed event is constructed
- **THEN** the event identifies that invocation and those exact versions and epochs

### Requirement: AU-002 Event policies include observed influences

Every audit event SHALL retain confidentiality and integrity restrictions
covering the authoritative data and control facts that influence its existence
and fields.

#### Scenario: Denial reveals a protected source fact

- **GIVEN** a denial reason depends on a protected object's metadata
- **WHEN** the denial is recorded
- **THEN** the event remains protected by that metadata's policy

#### Scenario: Multiple owners contribute evidence

- **GIVEN** an event combines facts governed by different owners
- **WHEN** its policy is derived
- **THEN** one owner's approval does not erase the other owner's restrictions

### Requirement: AU-003 Current owner-scoped query authority

Audit queries SHALL require current authority for their complete event and
metadata dependencies and for the response sink, without implicit global access
for an operator or a single contributing owner.

#### Scenario: Owner queries another owner's stream

- **GIVEN** a caller can read owner A's events but has no authority for owner B's events
- **WHEN** a query would expose B's entries or their count
- **THEN** that result is not released

#### Scenario: Authorized reader uses an unauthorized sink

- **GIVEN** a principal may inspect a protected event through one approved sink
- **WHEN** it requests the same result through an unapproved external endpoint
- **THEN** the export is denied

#### Scenario: Query grant is revoked

- **GIVEN** a query was prepared under a valid event-read grant
- **WHEN** that grant is revoked before its response is authorized
- **THEN** the protected response is not released

### Requirement: AU-004 Required audit is atomic with publication

A release requiring audit SHALL durably record its scoped event atomically with
authorization and consumption state before exposing protected output; failure to
record that required event denies the release without orphan consumption.

#### Scenario: Required append fails before durability

- **GIVEN** an otherwise approved release whose required audit record cannot be made durable
- **WHEN** publication attempts to commit
- **THEN** no output is published and no reservation is irreversibly consumed by that attempt

#### Scenario: Search index lags a durable event

- **GIVEN** the required event and publication have committed in the authoritative journal
- **WHEN** delivery to the secondary audit index fails
- **THEN** index recovery uses the same event identity without repeating publication or spending

### Requirement: AU-005 Denial recording preserves rejected operation state

Recording or failing to record a denied attempt SHALL leave the operation denied
and its rejected business state unchanged, without releasing protected diagnostic
details through another route.

#### Scenario: Denial is recorded successfully

- **GIVEN** a transfer has been denied with its reservation unconsumed
- **WHEN** a protected denial event is appended
- **THEN** the transfer remains denied and the reservation is not consumed by that audit append

#### Scenario: Denial event cannot be persisted

- **GIVEN** an operation is denied and audit storage is unavailable
- **WHEN** its denial event cannot be appended
- **THEN** the operation remains denied
- **AND** only a policy-permitted generic response is returned, without a plaintext log fallback

### Requirement: AU-006 Scoped verifiable append history

Audit history SHALL verify event identity, scope, order, and authenticated
predecessor commitments against a retained trusted head, rejecting alterations,
preventing duplicate logical entries, and refusing to certify a stale or
unverifiable history.

#### Scenario: Stored event is modified

- **GIVEN** a committed event covered by an authenticated history anchor
- **WHEN** stored event content changes
- **THEN** history verification rejects the altered event

#### Scenario: Duplicate event delivery

- **GIVEN** event E has already been durably accepted
- **WHEN** E is delivered again with identical content and scope
- **THEN** it is handled idempotently without creating another logical event

#### Scenario: Event identity reused with different content

- **GIVEN** event E has a committed identity and scope
- **WHEN** another submission reuses E's identity with altered content or scope
- **THEN** it is rejected

#### Scenario: Old valid prefix is restored

- **GIVEN** an independently retained trusted head beyond the restored history prefix
- **WHEN** verification observes that stale prefix
- **THEN** it refuses to certify completeness or authorize new required-audit releases until reconciliation

### Requirement: AU-007 No ambient telemetry export

Automatic audit exports, metrics, tracing, and alerts SHALL require explicit
current authority for their information content and output sink.

#### Scenario: Remote telemetry has no grant

- **GIVEN** audit events exist but no capability authorizes their remote telemetry sink
- **WHEN** an automatic exporter attempts transmission
- **THEN** the transmission is denied

#### Scenario: Export authority is revoked

- **GIVEN** an exporter previously had permission to send protected metrics
- **WHEN** that authority is revoked before the next transmission
- **THEN** subsequent transmissions are denied rather than falling back to an ungoverned channel

### Requirement: AU-008 Policy-safe observable metadata

Audit responses SHALL withhold unauthorized reason fields, identifiers, totals,
pagination state, and timestamps and use a fixed public denial category when
those protected details cannot be disclosed.

#### Scenario: Distinct secret denial reasons

- **GIVEN** two audit requests whose private failures differ only in a protected reason
- **WHEN** their caller has no authority for either reason
- **THEN** both responses use the same public denial category without those private fields

#### Scenario: Pagination would reveal another owner

- **GIVEN** a continuation token or stream counter would reveal activity outside the caller's authorized view
- **WHEN** a query response is constructed
- **THEN** that metadata is not disclosed

### Requirement: AU-009 Bounded audit work fails closed

Audit admission and queries SHALL enforce documented event, queue, work, and
response limits without silently dropping a required event to permit its
protected release.

#### Scenario: Required-event queue is full

- **GIVEN** the required-event queue has reached its permitted capacity
- **WHEN** another protected release requires an audit event
- **THEN** the release is not authorized by discarding that event

#### Scenario: Query exceeds its work budget

- **GIVEN** a query's declared resource limit has been reached
- **WHEN** evaluation cannot finish within that limit
- **THEN** it stops with a policy-safe outcome and does not expose unauthorized partial metadata
