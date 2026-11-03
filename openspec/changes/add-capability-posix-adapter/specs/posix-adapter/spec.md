# Capability POSIX adapter

## Purpose

Expose Writ's capability protocol through a real POSIX character-device boundary while preserving authenticated identity, exact operation scope, current authority, and confinement.

## ADDED Requirements

### Requirement: PA-001 Native sessions authenticate the caller

A device session SHALL bind its capability to the identity authenticated by the host rather than a subject value supplied in the request.

#### Scenario: Client changes claimed subject

- **GIVEN** the host identifies a process as R
- **WHEN** the client requests a capability session while claiming to be S
- **THEN** the request cannot obtain S's authority.

### Requirement: PA-002 Capability mounts preserve exact scope

Mounting a capability SHALL create a namespace for its approved immutable plan without granting ambient filesystem authority.

#### Scenario: Mount used to reach a different bucket

- **GIVEN** a token approves destination X
- **WHEN** a client traverses or requests destination Y through the mounted namespace
- **THEN** access to Y is denied.

### Requirement: PA-003 Every operational request revalidates authority

Native read, write, and execute requests SHALL pass the current paired-grant and capability checks before accessing protected data or publishing output.

#### Scenario: Open descriptor outlives revocation

- **GIVEN** a descriptor was opened while valid
- **WHEN** its registry grant is revoked before the next write
- **THEN** the write is denied.

### Requirement: PA-004 Native duplication cannot amplify rights

Descriptor duplication or inheritance SHALL preserve or reduce the source descriptor's subject, scope, rights, and expiry.

#### Scenario: Read-only descriptor duplicated

- **GIVEN** a descriptor has only read-request rights
- **WHEN** the client duplicates it and attempts a write
- **THEN** the duplicated descriptor does not authorize the write.

### Requirement: PA-005 Unsupported access routes fail closed

The device SHALL deny any ioctl, mapping, descriptor-transfer, accelerated-copy, or asynchronous operation whose scope-preserving behavior has not been implemented.

#### Scenario: Unsupported memory mapping

- **GIVEN** a protected descriptor has normal read permission
- **WHEN** a client requests an unimplemented memory mapping
- **THEN** the mapping is denied.

### Requirement: PA-006 Protocol parsing is bounded and versioned

The adapter SHALL reject malformed, unsupported-version, or over-limit requests before policy evaluation or protected allocation.

#### Scenario: Truncated token field

- **GIVEN** a request claims to contain a full 256-bit token
- **WHEN** its frame ends after the first word
- **THEN** the request is rejected without partial-token authorization.

### Requirement: PA-007 Actual writes use the exact sealed intent

The adapter SHALL publish only the sealed artifact and destination authorized by the durable commit path.

#### Scenario: Mutable buffer substituted after approval

- **GIVEN** a write intent names artifact A
- **WHEN** a client supplies different bytes to the same native write call
- **THEN** the substituted bytes are not published under that intent.

### Requirement: PA-008 Device deployment requires whole-worker confinement

The adapter SHALL require protected worker confinement before admitting plaintext through its device interface.

#### Scenario: Worker retains unrestricted stdout forwarding

- **GIVEN** a worker can forward stdout to a public destination
- **WHEN** the device is asked to deliver protected data
- **THEN** admission is denied until that output path is mediated or removed.
