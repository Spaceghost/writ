# Capability frontend

## Purpose

Model capability-mounted handles and descriptors that resolve an operation only
under current authority. This baseline is a pure character-device protocol model:
its outputs are records and plans, not OS descriptors, plaintext, or completed
writes. Caller identity and capability registries are authenticated inputs supplied
by the monitor; mounting does not mint a grant. Actual POSIX enforcement remains
integration work.

## Requirements

### Requirement: CF-001 Unambiguous valid registries and handle state

Mounting and authority-bearing handle operations SHALL reject malformed registry
or handle state, including duplicate tokens or handle identifiers, unsupported
rights, inconsistent plan authority epochs, and invalid identifier allocation.

#### Scenario: Duplicate capability token

- **GIVEN** two registry entries with the same token, even with identical fields
- **WHEN** a mount or descriptor operation is requested
- **THEN** the request is denied

#### Scenario: Duplicate descriptor identifier

- **GIVEN** two stored handles sharing an identifier
- **WHEN** an operation tries to resolve that identifier
- **THEN** resolution fails

#### Scenario: Allocator overlaps an existing identifier

- **GIVEN** a state whose next identifier is no greater than an already allocated identifier
- **WHEN** its handle state is validated
- **THEN** the state is rejected

### Requirement: CF-002 Mount binds a live capability to its subject

A mount SHALL require the monitor-authenticated subject and all 256 token bits to
match a current registry capability, with requested rights contained in that
capability's rights.

#### Scenario: Registered subject mounts permitted rights

- **GIVEN** a live capability for subject 7 with read, write, and execute rights
- **WHEN** subject 7 presents its exact token and requests those rights
- **THEN** a mounted protocol handle is allocated

#### Scenario: Another subject presents the token

- **GIVEN** the same capability bound to subject 7
- **WHEN** subject 8 attempts to mount it
- **THEN** mounting is denied

#### Scenario: Token differs only in its final word

- **GIVEN** a token sharing seven words with a registered token but differing in its eighth word
- **WHEN** it is used to mount a capability
- **THEN** mounting is denied

### Requirement: CF-003 Mounts and operational descriptors are distinct

The frontend SHALL distinguish mounted handles from operational descriptors,
allowing opens only from a live mount with no broader rights and allowing
operations only through a descriptor.

#### Scenario: Open a mounted capability

- **GIVEN** a live mounted handle with read and write rights
- **WHEN** its owner opens it with read rights
- **THEN** a distinct read-only descriptor is created

#### Scenario: Open requests broader rights

- **GIVEN** a read-only mounted handle
- **WHEN** opening requests read and write rights
- **THEN** opening is denied

#### Scenario: Use a mount as a descriptor

- **GIVEN** a valid mounted handle
- **WHEN** a read is requested directly through that mount identifier
- **THEN** operation resolution fails

### Requirement: CF-004 Monotonic handle allocation

Every successful mount, open, or descriptor duplication SHALL allocate the next
positive identifier and advance the frontend revision and allocation counter.

#### Scenario: Handle identifiers are exhausted

- **GIVEN** a valid frontend whose next handle identifier is the maximum supported Nat value
- **WHEN** mounting, opening or duplicating would require another identifier
- **THEN** allocation is rejected with the supplied state unchanged
- **AND** existing-handle resolution and owner cleanup do not depend on allocation availability

#### Scenario: Mount followed by open

- **GIVEN** an empty frontend with next identifier 1
- **WHEN** a capability is mounted and then opened using the successive current revisions
- **THEN** the mount receives identifier 1 and the descriptor receives identifier 2
- **AND** the next allocation identifier is 3

### Requirement: CF-005 Descriptor duplication preserves scope

Duplication SHALL require a live operational descriptor and create a distinct
descriptor preserving its subject, token, plan, authority epoch, expiry, and
current rights.

#### Scenario: Duplicate a narrowed descriptor

- **GIVEN** a live descriptor already narrowed to read rights
- **WHEN** its owner duplicates it
- **THEN** the new descriptor has read rights only and the same immutable plan

#### Scenario: Duplicate a mounted handle

- **GIVEN** a mounted handle that has not been opened as a descriptor
- **WHEN** duplication is requested
- **THEN** duplication is denied

### Requirement: CF-006 Handle-local monotonic attenuation

Attenuation SHALL replace only the selected live handle's rights with a supported
subset of its existing rights, including an empty set, without changing that
handle's scope or previously duplicated handles.

#### Scenario: Remove write and execute rights

- **GIVEN** a descriptor with read, write, and execute rights
- **WHEN** its owner attenuates it to read only
- **THEN** reads remain eligible while writes and execution cannot resolve

#### Scenario: Restore removed rights

- **GIVEN** a descriptor already attenuated to read only
- **WHEN** attenuation requests read, write, and execute rights
- **THEN** the request is denied

#### Scenario: Existing duplicate retains its own rights

- **GIVEN** two descriptors created by duplication before either is attenuated
- **WHEN** one descriptor is narrowed to zero rights
- **THEN** the other descriptor retains its own rights subject to current registry authorization

### Requirement: CF-007 Live registry authority on every use

Opening, duplication, attenuation, and operation resolution SHALL require a
current registry entry preserving the handle's complete scope, rights, and
expiry, with the live authority epoch matching and time strictly before both
the retained and current expiries.

#### Scenario: Registry entry revoked

- **GIVEN** an open descriptor whose capability entry has been removed
- **WHEN** an operation or duplication is requested through it
- **THEN** the request is denied

#### Scenario: Registry rights contract

- **GIVEN** a descriptor retaining read, write, and execute rights while its current registry entry now permits read and write only
- **WHEN** even a read operation is requested through that wider descriptor
- **THEN** the descriptor fails live scope validation

#### Scenario: Registry expiry contracts

- **GIVEN** a descriptor retaining expiry 180 and a registry entry shortened to expiry 179
- **WHEN** the descriptor is used at time 100
- **THEN** the descriptor fails live scope validation

#### Scenario: Authority epoch changes

- **GIVEN** an open descriptor and registry capability from authority epoch 3
- **WHEN** an operation is requested in authority epoch 4
- **THEN** operation resolution fails

#### Scenario: Expiry boundary reached

- **GIVEN** a descriptor and its registry capability expiring at time 180
- **WHEN** an operation is requested at time 180
- **THEN** operation resolution fails

### Requirement: CF-008 Immutable plan resolution

Operation resolution SHALL return only the descriptor's registered plan after
exact agreement with the current registry plan; callers cannot replace the plan
through a read, write, or execute request.

#### Scenario: Read and write resolve the same plan

- **GIVEN** a fully authorized descriptor
- **WHEN** its owner requests read and write operations
- **THEN** both resolutions return the same complete stored plan

#### Scenario: Registry redirects an existing descriptor

- **GIVEN** an existing descriptor for destination A
- **WHEN** its registry token is rebound to a plan for destination B
- **THEN** the old descriptor cannot resolve an operation under the new plan

#### Scenario: Stored handle disagrees with its registry

- **GIVEN** a malformed descriptor record with a changed destination while the current registry retains the original plan
- **WHEN** an operation is resolved
- **THEN** resolution fails

### Requirement: CF-009 Request-specific rights

Resolution SHALL require the read right for read requests, the write right for
write requests, and all read, write, and execute rights for execution requests.

#### Scenario: Read-only descriptor

- **GIVEN** a live read-only descriptor and a plan satisfying transfer admission
- **WHEN** read is requested
- **THEN** the plan can resolve
- **AND** write and execute requests through that descriptor fail

#### Scenario: Read and write without execute

- **GIVEN** a live descriptor with read and write rights but no execute right
- **WHEN** the combined commit interface requests execution
- **THEN** the request is denied

#### Scenario: Zero-right descriptor

- **GIVEN** a descriptor attenuated to zero rights
- **WHEN** read, write, or execute is requested
- **THEN** none of those requests resolves a plan

### Requirement: CF-010 Transfer admission cannot be bypassed by a descriptor

Every read, write, and execute resolution SHALL pass the complete current
transfer-admission policy even when the descriptor possesses the requested right.

#### Scenario: Read has no destination approval

- **GIVEN** a live descriptor with a read right but no matching destination-write grant in the current transfer context
- **WHEN** read is requested
- **THEN** resolution fails

#### Scenario: Write has no source approval

- **GIVEN** a live descriptor with a write right but no matching source-read grant
- **WHEN** write is requested
- **THEN** resolution fails

#### Scenario: Descriptor cannot skip a source charge

- **GIVEN** a live descriptor with every frontend right but a missing required origin payment witness
- **WHEN** execution is requested
- **THEN** resolution fails

### Requirement: CF-011 Revision checks and denied-state preservation

Frontend operations SHALL require the current expected frontend revision and
return the original supplied state on a rejected mutation.

#### Scenario: Stale resolution

- **GIVEN** frontend revision 2
- **WHEN** a caller resolves an operation while expecting revision 1
- **THEN** resolution fails

#### Scenario: Stale mutation

- **GIVEN** frontend revision 1 after mounting
- **WHEN** an open request presents expected revision 0
- **THEN** opening is rejected
- **AND** the returned state retains revision 1 and the original handles

### Requirement: CF-012 Owner cleanup closes handles

The authenticated subject presenting the exact token and current revision SHALL
be able to close its open handle for cleanup even after capability revocation or
expiry; closure records a tombstone instead of erasing the identifier.

#### Scenario: Another subject tries to close a handle

- **GIVEN** a descriptor owned by subject 7
- **WHEN** subject 8 presents its identifier to close it
- **THEN** closure is denied

#### Scenario: Owner cleans up a revoked handle

- **GIVEN** an open handle whose registry capability has been revoked
- **WHEN** its authenticated owner presents the same token and current revision to close it
- **THEN** the close transition records the handle as closed

#### Scenario: Close is replayed

- **GIVEN** a handle already marked closed
- **WHEN** a further close request uses its identifier at the current revision
- **THEN** the request is rejected

### Requirement: CF-013 Closed handles never regain authority

A closed handle SHALL remain unusable with its identifier permanently reserved,
while independently duplicated handles retain their own lifecycle.

#### Scenario: Closed descriptor is reused

- **GIVEN** a tombstoned descriptor
- **WHEN** read, duplication, or attenuation is attempted through it
- **THEN** each attempted use is denied

#### Scenario: Duplicate survives another descriptor's close

- **GIVEN** two live descriptors sharing a capability scope
- **WHEN** one is closed
- **THEN** the other remains eligible for independently authorized use
- **AND** a later open receives a new identifier rather than the tombstoned one

### Requirement: CF-014 Capability-bound final commit

The combined commit interface SHALL resolve current execution rights, require
the resolved plan to equal the negotiated plan, and require the authenticated
descriptor subject to equal the negotiated reader before applying the complete
commit backplane.

#### Scenario: Valid descriptor reaches the full backplane

- **GIVEN** a live execution-capable descriptor belonging to the negotiated reader and every backplane condition satisfied
- **WHEN** final commit is requested
- **THEN** the model returns a committed state and scoped write intent with inherited provenance

#### Scenario: Descriptor subject is not the negotiated reader

- **GIVEN** a live descriptor owned by subject 8 and a negotiated request funded by reader 7
- **WHEN** subject 8 requests final commit
- **THEN** commit is denied

#### Scenario: Capability revoked before final commit

- **GIVEN** a previously usable descriptor and an execution reservation
- **WHEN** its capability is revoked before final commit
- **THEN** commit is denied without consuming the reservation

#### Scenario: Capability possession cannot override policy

- **GIVEN** a valid descriptor and a backplane label-flow denial
- **WHEN** final commit is requested
- **THEN** the capability does not override that denial
