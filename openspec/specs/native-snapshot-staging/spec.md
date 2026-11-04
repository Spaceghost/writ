# native-snapshot-staging Specification

## Purpose
Create verified private, read-only Btrfs and ZFS copies through Writ's existing
Bend authority path while preserving full native scope and explicitly limiting
the claim to a trusted administrative storage adapter.

## Requirements

### Requirement: NS-001 Native staging remains a Bend operation

The adapter SHALL keep authored planning, policy, validation, sequencing, and tests in Bend, using only the declared native snapshot/clone primitives for whole units without a general plaintext Open, mounted frontend, file-copy fallback, or new Go/C policy implementation.

#### Scenario: A native copy is requested

- **GIVEN** an admitted Btrfs subvolume or ZFS snapshot
- **WHEN** its private stage is created
- **THEN** the native filesystem performs the snapshot or clone
- **AND** payloads do not traverse a per-file copying loop or FUSE data path.

#### Scenario: An unsupported release is requested

- **GIVEN** this administrative staging adapter
- **WHEN** a caller asks it to mount a result, export a zvol, or open protected plaintext
- **THEN** no such release operation is available through its supported entry points.

### Requirement: NS-002 Native and logical scope remain distinct

The monitor SHALL bind authoritative logical object versions and registered locators to complete native filesystem/pool and object identities, preserving canonical uint64 values without truncation and treating public records, names, and native IDs as descriptions rather than credentials.

#### Scenario: A native identifier exceeds uint32

- **GIVEN** a root ID, GUID, generation, or creation TXG above the uint32 range
- **WHEN** the adapter parses, seals, or compares the observation
- **THEN** all native bits remain significant
- **AND** no low-word value becomes the logical object identifier.

#### Scenario: A destination container is supplied

- **GIVEN** a monitor-registered destination locator and FSID or pool GUID
- **WHEN** the host validates its private parent
- **THEN** the locator determines the parent path or dataset
- **AND** the native container identity is compared to the observed store rather than interpreted as a path.

### Requirement: NS-003 Only complete sealed source units are admitted

The adapter SHALL admit a source only when its observed native kind and scope identify a read-only leaf Btrfs subvolume root or a ZFS snapshot whose parent has the declared leaf filesystem/volume type, rejecting writable, nested, ordinary-directory, ambiguous, or live-dataset substitutes.

#### Scenario: A Btrfs source contains a nested subvolume

- **GIVEN** a read-only subvolume with a nested subvolume
- **WHEN** source sealing is requested
- **THEN** admission is denied instead of silently omitting the nested contents.

#### Scenario: A live readonly ZFS dataset is named

- **GIVEN** a dataset whose readonly property is enabled
- **WHEN** it is supplied without a snapshot selector
- **THEN** it is not accepted as an immutable source snapshot.

### Requirement: NS-004 Source seals identify canonical manifests

The native source seal SHALL identify the versioned canonical descriptor of the admitted provider, full source identity, locator, origin, and source conditions; it is not a payload content checksum or independent execution attestation, and these semantics remain distinct from rclone's SHA-256 of actual payload bytes.

#### Scenario: The source generation or artifact changes

- **GIVEN** a plan sealed for one complete source observation
- **WHEN** a caller substitutes another generation or artifact word before authorization
- **THEN** the original seal does not authorize that substituted source description.

#### Scenario: A native seal is displayed

- **GIVEN** a successful native source seal
- **WHEN** the interface or evidence describes its SHA-256
- **THEN** it identifies a source manifest
- **AND** it is not described as a traversal/hash of every payload byte.

### Requirement: NS-005 Every executable action uses the common facade

Native authorization SHALL invoke the current capability-to-commit facade and match its accepted Storage intent to the complete logical plan, source seal, and provider-specific operation; a preview or structural command check grants no independent authority.

#### Scenario: Authority or scope is stale

- **GIVEN** a well-formed native preview
- **WHEN** the descriptor is revoked, subject or revision differs, or the destination cannot accept the source restrictions
- **THEN** the native operation is not authorized.

#### Scenario: Another backend or operation is substituted

- **GIVEN** a generic accepted intent for another backend, invocation, source artifact, or provider operation
- **WHEN** it is presented for this native plan
- **THEN** it cannot authorize the requested native command.

### Requirement: NS-006 Creation preserves a private readonly destination

The host SHALL require an absent target in the observed registered filesystem/pool and a private parent, creating only readonly results: Btrfs beneath a canonical current-UID `0700` directory, ZFS filesystems unmounted with mount/sharing disabled, and zvols with device exposure and snapshot devices disabled.

#### Scenario: The destination already exists or belongs to another store

- **GIVEN** an existing target, dangling target symlink, or mismatched filesystem/pool
- **WHEN** the host checks the destination before mutation
- **THEN** it refuses the creation without overwriting or adopting the object.

#### Scenario: A native stage succeeds

- **GIVEN** a source and destination satisfying native and Writ checks
- **WHEN** the native creation and post-observation succeed
- **THEN** the result remains read-only and private under the declared provider controls
- **AND** no mount or block-device export is performed by the adapter.

### Requirement: NS-007 Native commands and observations are bounded

The host SHALL use literal argv with fixed trusted executables and a cleared fixed-locale environment, enforce the documented 512-character native-selector, 65,536-byte combined-output, and 15-second subprocess bounds, and reject incomplete or ambiguous observations without returning raw tool diagnostics.

#### Scenario: A selector contains an alias or command-looking component

- **GIVEN** an empty, dot, dot-dot, leading-dash, control-containing, or oversized component sequence
- **WHEN** the selector reaches a supported host entry point
- **THEN** it cannot choose a native resource through an alternate interpretation or shell command.

#### Scenario: Native output exceeds the cap

- **GIVEN** a subprocess whose combined output exceeds its bound
- **WHEN** the runtime completes the call
- **THEN** the adapter receives a failure rather than a successful truncated observation.

### Requirement: NS-008 Receipts retain the full intent and verified native result

A successful stage receipt SHALL retain the complete accepted intent and model state and require pre-mutation source equality plus the documented native postconditions for source, new identity, origin, kind, readonly/leaf/root status, and private controls; unsupported metadata changes or command substitutions cannot mint a receipt.

#### Scenario: A path appears with an unrelated identity

- **GIVEN** a native command has been attempted
- **WHEN** the observed result has another parent/origin, store, kind, or registered locator
- **THEN** the host does not report a verified stage under the accepted intent.

#### Scenario: Native snapshot bookkeeping advances a generation

- **GIVEN** exact source equality before a Btrfs snapshot operation
- **WHEN** that native operation changes source-root transaction metadata
- **THEN** only its generation may differ, with `old < new == created.creation == created.generation`
- **AND** the receipt preserves the original seal and created native facts rather than discarding generations.

#### Scenario: Another generation appears during later reconciliation

- **GIVEN** a receipt preserving the original source seal and its verified created snapshot facts
- **WHEN** the source matches neither the original sealed observation nor the single derived Btrfs snapshot-transaction observation
- **THEN** reconciliation rejects that observation rather than accepting another advance.

#### Scenario: A recorded Btrfs stage is reconciled

- **GIVEN** the created object still matches its complete recorded observation
- **WHEN** the source matches the original sealed observation or differs only by the admitted snapshot-transaction generation
- **THEN** source reconciliation may succeed under that two-state rule
- **AND** the receipt is not claimed to record which source state was observed at completion.

#### Scenario: An accepted stage is recorded

- **GIVEN** all applicable native postconditions pass
- **WHEN** a receipt is returned
- **THEN** its plan, policy, DLM label, backend, artifact, session, and ledger are the accepted values
- **AND** it retains the actual created native identity.

### Requirement: NS-009 Uncertain effects are not replayed or adopted

The host SHALL distinguish refusal before mutation from an unknown outcome after an attempted mutation, preserving returned model state and allowing only read-only reconciliation of a previously recorded exact receipt rather than blind retry, path-based adoption, deletion, automatic refund, or a rollback/publication claim.

#### Scenario: A native creation times out

- **GIVEN** the mutation command was started
- **WHEN** completion or its postconditions cannot be established
- **THEN** the outcome is unknown because a native object may exist
- **AND** the adapter does not repeat or delete that operation automatically.

#### Scenario: A recorded path now names another object

- **GIVEN** a previously verified stage receipt
- **WHEN** reconciliation observes another native identity or changed private controls
- **THEN** it rejects that observation without creating or adopting an object.

#### Scenario: Model authorization succeeded but storage did not

- **GIVEN** the facade returned updated session and ledger state
- **WHEN** native execution subsequently fails
- **THEN** the monitor retains that returned state for its recovery protocol
- **AND** copying an older gate is not treated as a refund or replay authorization.

### Requirement: NS-010 Qualification states its actual native evidence and trust limits

Native staging claims SHALL distinguish model/parser/runtime checks from actual Btrfs/ZFS kernel fixtures and retain the trusted administrative single-writer precondition, without claiming hostile-admin tamper detection, authenticated issuance, general confinement, handle revocation, durable publication, or untested backend support.

#### Scenario: Model tests pass but the native lane has not passed

- **GIVEN** successful Bend model or parser tests
- **WHEN** the relevant native kernel fixture is missing, unsupported, or failing
- **THEN** the backend's live acceptance evidence remains pending
- **AND** structural OpenSpec validation does not qualify it.

#### Scenario: A privileged administrator mutates and restores a clone

- **GIVEN** ZFS GUID and creation TXG describe a clone's creation identity
- **WHEN** privileged code changes its contents and restores readonly/presentation properties between observations
- **THEN** current identity/control comparisons are not claimed to detect that history
- **AND** such interference violates the declared administrative ownership boundary.

#### Scenario: An operator invokes the administrative example

- **GIVEN** the CLI uses synthetic example authority
- **WHEN** the operator selects source fixtures
- **THEN** public fixture content is an operator precondition
- **AND** the CLI is not claimed to classify payloads or authenticate an issuer.

#### Scenario: A disposable native fixture finishes

- **GIVEN** a job created fresh regular-file-backed storage containing public test data
- **WHEN** the fixture exits or fails
- **THEN** its evidence identifies the actual tools, kernel, source, and observed behavior
- **AND** cleanup is limited to storage resources that the job successfully created.
