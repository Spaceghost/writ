# rclone-contrib-remote Specification

## Purpose
Exercise Writ's transfer authority through an optional, bounded local rclone
integration without claiming production storage or whole-host confinement.

## Requirements

### Requirement: RC-001 Optional language boundary

The contribution SHALL keep rclone-specific code under `contrib/rclone/`, with Bend owning policy and service behavior and a separate Go module providing only rclone interfaces and bounded transport. Shared pure Bend SHA-256 code MAY live in `lib/Sha256.bend` behind the contribution's compatibility wrapper without changing payload-digest semantics. Core Writ SHALL not depend on the Go module.

#### Scenario: Core is used without Go

- **WHEN** the root Bend library and tests are run without the contribution
- **THEN** no Go compiler, rclone module, or reference service is required

#### Scenario: Adapter requests a transfer

- **WHEN** rclone's Copy hook receives source and destination references
- **THEN** it submits a complete service request without granting authority itself

#### Scenario: The pure digest primitive is shared

- **GIVEN** the native contribution and rclone use the shared Bend SHA-256 implementation
- **WHEN** rclone calls its existing digest compatibility entry point
- **THEN** the digest still identifies the same actual payload bytes
- **AND** rclone-specific service code and the isolated Go module remain under `contrib/rclone/`.

### Requirement: RC-002 Authenticated canonical envelope

The service SHALL authenticate a configured bounded token, accept only its
documented versioned envelope, and reject malformed fields, noncanonical numeric
or hex encodings, invalid paths, and oversized requests before state mutation.

#### Scenario: Wrong token

- **WHEN** a structurally valid request carries a different token
- **THEN** no object, metadata, or successful mutation result is released

#### Scenario: Ambiguous encoding

- **WHEN** a request contains a traversal path, overflowed version, extra field,
  embedded delimiter, or unsupported path encoding
- **THEN** it fails without changing the service state

### Requirement: RC-003 Authoritative ingress

The reference SHALL assign provenance and restrictions from its fixed ingress
profile, compute the actual payload digest in Bend, and keep published versions
immutable. Caller metadata SHALL not weaken those records.

#### Scenario: Private import

- **WHEN** an authorized request imports supported bytes into the private namespace
- **THEN** the resulting version has a service-assigned origin, protected policy,
  and SHA-256 identity of those exact bytes

#### Scenario: Unsupported ingress destination

- **WHEN** an import targets a namespace outside the private ingress profile
- **THEN** it is denied without creating the object

### Requirement: RC-004 Managed copy uses current Writ authority

A managed copy SHALL bind exact source and destination versions, run Writ's
existing capability-to-commit facade, and retain its accepted artifact identity
and output policy. No caller-supplied policy or candidate SHALL replace current
service-owned facts.

#### Scenario: Private object copied to archive

- **WHEN** a current private version is copied into an allowed archive destination
- **THEN** the committed copy has the same payload digest and inherited origin
  restrictions

#### Scenario: Public destination or stale version

- **WHEN** the destination cannot accept the source policy or a source/destination
  version changed after the request was formed
- **THEN** no destination version is published under that request

### Requirement: RC-005 No plaintext fallback

The reference SHALL deny generic plaintext Open and unsupported release routes.
The Go adapter SHALL never translate a policy denial into ErrorCantCopy or a
successful byte stream.

#### Scenario: Copy destination denies

- **WHEN** rclone requests a forbidden managed copy
- **THEN** it receives a terminal error rather than a request to download the source

#### Scenario: Client attempts to read or export

- **WHEN** rclone cat, a local copy, or a forced manual fallback opens a protected object
- **THEN** the client receives no protected payload bytes

### Requirement: RC-006 Scoped in-memory replay

Within one service instance, a repeated PUT/COPY ID SHALL recover only the exact
original request outcome. Reusing that ID with changed scope SHALL fail. The
reference SHALL explicitly disclose that restart discards its replay state.

#### Scenario: Acknowledgement lost

- **GIVEN** a request has committed in the running instance
- **WHEN** the identical request is repeated
- **THEN** the same version is returned without a second publication

#### Scenario: Replay changes destination or payload

- **WHEN** an existing request ID is reused with different request fields
- **THEN** it is denied without changing the original outcome

### Requirement: RC-007 Bounded and protected reference views

The reference SHALL enforce documented object, storage, path, request, and
response limits. Metadata, policy descriptions, and receipt views SHALL be
restricted to the authenticated reference audience and SHALL omit payloads and
credentials.

#### Scenario: Capacity exhausted

- **WHEN** an operation exceeds the per-object or aggregate storage limit
- **THEN** it fails while preserving existing versions and receipts

#### Scenario: Receipt inspected

- **WHEN** an authenticated caller inspects a committed request
- **THEN** the response describes its exact outcome without the token or file body

### Requirement: RC-008 Accurate compatibility and evidence

The contribution SHALL document its supported rclone subset, content comparison
rules, memory-only scope, fixed authority profile, and remaining deployment
requirements. Test evidence SHALL distinguish model checks from real CLI checks.

#### Scenario: Matching content with changed policy

- **WHEN** rclone skips a byte-identical object
- **THEN** the documentation does not claim that policy or provenance was reconciled

#### Scenario: Reference tests pass

- **WHEN** the bounded service and adapter pass their tests
- **THEN** that result is not reported as durable publication, arbitrary worker
  confinement, physical GPU validation, or production multitenant authentication
