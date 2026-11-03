# S3 adapter

## Purpose

Provide a bounded object-request interface that preserves Writ's capability,
information-flow, provenance, and durable-publication rules after the real POSIX
adapter is established. This delta specifies future implementation, not an
existing S3 service or universal protocol compatibility.

## ADDED Requirements

### Requirement: SA-001 Explicit supported subset

The adapter SHALL admit only the documented operation and request-variant subset
after the real capability POSIX adapter and durable publication have met their
acceptance requirements.

#### Scenario: Unimplemented operation

- **GIVEN** an endpoint supporting GET and PUT but no bucket-policy mutation
- **WHEN** a caller requests bucket-policy mutation
- **THEN** the operation is denied without reaching a backing-store bypass

#### Scenario: Missing deployment prerequisite

- **GIVEN** no accepted POSIX enforcement deployment
- **WHEN** protected S3 requests are enabled
- **THEN** the adapter refuses to admit protected work

### Requirement: SA-002 Authenticated exact request binding

Every admitted request SHALL bind its authenticated principal and canonical
object operation to the exact capability plan, including applicable source and
destination versions and the response sink.

#### Scenario: Caller claims another identity

- **GIVEN** a request authenticated as principal A
- **WHEN** request fields claim principal B's capability authority
- **THEN** no authority belonging to B is obtained

#### Scenario: Object path changes after authentication

- **GIVEN** an authenticated request scoped to object X
- **WHEN** another decoding of the path would select object Y
- **THEN** the ambiguous request is rejected instead of accessing Y

### Requirement: SA-003 GET requires approved output authority

A GET response SHALL release protected data only with both a current source-read
grant and current write authority for its recipient sink, preserving all source
restrictions for the exact object version and selected range.

#### Scenario: Read permission without an approved recipient

- **GIVEN** permission to read object X but no permission to write its data to the requesting client's response sink
- **WHEN** the client requests GET X
- **THEN** no protected response bytes are released

#### Scenario: Valid restricted read

- **GIVEN** an exact versioned GET with matching source and recipient authority
- **WHEN** all label and operation conditions are satisfied
- **THEN** only the approved object version and range are released to that sink

### Requirement: SA-004 PUT and COPY preserve operation provenance

PUT and COPY SHALL publish only an admitted, sealed output with authoritative
ingress or source provenance and the inherited policy required by the normal
transfer and durable-publication paths.

#### Scenario: Upload claims an unprotected label

- **GIVEN** an authenticated ingress policy assigns restrictions to an uploaded object
- **WHEN** a PUT supplies headers claiming a weaker label
- **THEN** the client headers do not remove the assigned restrictions

#### Scenario: Server-side copy violates an origin restriction

- **GIVEN** an object whose inherited origins forbid copying
- **WHEN** a COPY requests a new bucket despite the backing store being capable of copying the bytes
- **THEN** the copy is denied

### Requirement: SA-005 Multipart state remains scoped and unpublished

Multipart uploads SHALL bind parts and completion to one authenticated principal
and exact operation scope, keeping incomplete data invisible and publishing only
the admitted frozen part manifest.

#### Scenario: Incomplete upload is queried

- **GIVEN** an upload with some staged parts but no committed completion
- **WHEN** GET, HEAD, or LIST targets its proposed object
- **THEN** none exposes the incomplete object or its staged content

#### Scenario: Another principal reuses an upload identifier

- **GIVEN** upload U belongs to principal A
- **WHEN** principal B tries to append, complete, or abort U
- **THEN** the request is denied

#### Scenario: Parts change after approval

- **GIVEN** completion approval for part manifest M
- **WHEN** a part is replaced before publication to produce manifest N
- **THEN** N is not published under M's approval

### Requirement: SA-006 Metadata and query results obey output policy

HEAD, LIST, conditional responses, and any supported registered query SHALL
authorize their complete observable metadata or result against every observed
source's policy and the approved response sink.

#### Scenario: Listing count depends on a hidden object

- **GIVEN** a caller may observe public metadata but not a protected object's existence
- **WHEN** a LIST result would reveal that existence through a count or page token
- **THEN** that result is not released without authority for the protected metadata

#### Scenario: HEAD requests a protected size

- **GIVEN** an object size is protected metadata
- **WHEN** a caller lacking its read-and-response authority requests HEAD
- **THEN** the size is not disclosed

#### Scenario: Arbitrary query is unsupported

- **GIVEN** no registered supported query operation for the request
- **WHEN** a client submits a query through the endpoint
- **THEN** it is denied without executing a general query engine

### Requirement: SA-007 No alternate raw-storage route

The adapter SHALL deny requests that bypass Writ's authority path through raw
storage credentials, direct object URLs, presigned backing-store access, or
unsupported transport methods.

#### Scenario: Presigned storage access requested

- **GIVEN** an authenticated user can perform some Writ object operations
- **WHEN** the user requests a presigned URL for direct backing-store access
- **THEN** the adapter does not issue such an alternate access route

### Requirement: SA-008 Current versions and revocation at release

The adapter SHALL check current object versions and authority at every protected
release unit and final write commit, rejecting stale conditions or revocation
ordered before that unit's authorization point.

#### Scenario: Revocation during a streaming GET

- **GIVEN** one authorized response unit has been delivered
- **WHEN** its source grant is revoked before the next unit is authorized
- **THEN** no later unit is released under the revoked grant

#### Scenario: Destination changes before a conditional write

- **GIVEN** a write plan conditioned on destination version V
- **WHEN** the destination has advanced to another version before commit
- **THEN** the stale conditional write is rejected

#### Scenario: Grant revoked before multipart completion

- **GIVEN** all upload parts are staged
- **WHEN** write authority is revoked before completion commits
- **THEN** the upload is not published as an object

### Requirement: SA-009 Durable publication and scoped retries

Accepted writes and completed multipart uploads SHALL publish artifact, inherited
metadata, and consumption state through the durable-publication transaction,
with retries bound to the same invocation and exact sealed artifact.

#### Scenario: Completion retried after acknowledgement loss

- **GIVEN** an invocation has durably published an upload, its acknowledgement was lost, and the caller remains authorized to receive the outcome
- **WHEN** the identical completion request is retried
- **THEN** the committed outcome is recovered without another logical publication or charge

#### Scenario: Retry changes the artifact

- **GIVEN** invocation I names committed artifact A
- **WHEN** a retry for I presents artifact B
- **THEN** B is not accepted under I's prior authorization

#### Scenario: Failure before durable authorization

- **GIVEN** an upload has passed policy checking but no durable authorization record exists
- **WHEN** a failure interrupts completion
- **THEN** no output becomes visible and no reservation is irreversibly consumed by that failed attempt
