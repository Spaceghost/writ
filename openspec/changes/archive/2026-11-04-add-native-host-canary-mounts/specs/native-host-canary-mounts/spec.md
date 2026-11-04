## ADDED Requirements

### Requirement: NM001 Shared Bend decisions

The contribution SHALL keep authorization and mounted-view state in shared Bend modules. Native code SHALL be limited to approved OS/runtime bindings, packaging and probes. Only the trusted interpreter SHALL own authoritative state.

#### Scenario: Same decision corpus on native hosts

- **GIVEN** the same pinned generated Bend module and test corpus
- **WHEN** each native host executes the corpus
- **THEN** it reports the actual result without substituting another policy engine

#### Scenario: A worker supplies authority-shaped data

- **GIVEN** a mounted client supplying paths or packet fields
- **WHEN** it supplies a claimed actor or replacement policy state
- **THEN** the native binding provides no route for that data to replace authority

### Requirement: NM002 Exact immutable public input

The initial profile SHALL accept only explicitly designated public fixtures of at most 65536 bytes. The host SHALL freeze the exact bytes before initialization. Bend SHALL compute their SHA-256 and retain that identity for the view's lifetime. Public status remains an explicit operator precondition.

#### Scenario: Registered payload changes externally

- **GIVEN** a registered immutable host snapshot
- **WHEN** the original input path later changes
- **THEN** reads expose only the registered bytes and identity

#### Scenario: Initialization attempts to replace bytes

- **GIVEN** an initialized monitor
- **WHEN** another INIT supplies different bytes
- **THEN** the monitor refuses it and retains the original input

#### Scenario: Payload exceeds the limit

- **GIVEN** more than 65536 decoded payload bytes
- **WHEN** initialization is requested
- **THEN** it fails before admission or byte exposure

### Requirement: NM003 Full commit before observation

Admission SHALL use DataOS.commit_from_capability for the exact immutable Copy into the registered reader domain. The monitor SHALL retain the committed session, ledger, write intent and origin policy, including when later native setup fails. Metadata lookup or open SHALL NOT bypass this gate.

#### Scenario: Reader admission succeeds

- **GIVEN** the fixed local standing profile and sealed input
- **WHEN** the full facade commits the reader-domain copy
- **THEN** observation becomes eligible only for that native-bound reader

#### Scenario: Public destination or revoked capability

- **GIVEN** a destination violating retained restrictions or a revoked registry
- **WHEN** the same admission path is evaluated
- **THEN** no grant is produced and no mounted observation is enabled

#### Scenario: Admission is replayed

- **GIVEN** a monitor that already admitted its one reader
- **WHEN** ADMIT is repeated
- **THEN** it is denied without discarding or repeating committed state

### Requirement: NM004 Native identity and metadata

The host SHALL derive actor slots from native evidence joined to a retained process or session lifetime. Metadata and content SHALL require the admitted actor; only fixed public mount structure may be exposed beforehand. Unsupported namespace mutations and alternative object selection SHALL be rejected.

#### Scenario: An unrelated caller requests metadata

- **GIVEN** a mounted view and an unadmitted native caller
- **WHEN** it requests private metadata or contents
- **THEN** the view denies the request before returning those outputs

#### Scenario: Reused identity or forged label

- **GIVEN** a reused numeric PID or a client-controlled session label suffix
- **WHEN** the caller attempts to inherit an admitted actor slot
- **THEN** retained lifetime and trusted route checks prevent substitution

#### Scenario: Callback lacks fresh requester evidence

- **GIVEN** a callback providing only retained per-open context
- **WHEN** a read or cleanup is handled
- **THEN** the host uses that binding and does not report fresh actor authentication

### Requirement: NM005 Bounded handles and revocation

The monitor SHALL issue at most 32 live handles and 65535 lifetime handles without reuse, and process at most 100000 frames. Reads SHALL be bounded and clipped without overflow. Revocation and STOP SHALL prevent future observation and readmission while retaining commit evidence and permitting required cleanup.

#### Scenario: Closed or foreign handle is presented

- **GIVEN** a closed handle or one bound to another actor
- **WHEN** it is used for a read
- **THEN** the monitor denies access

#### Scenario: Revocation follows a successful read

- **GIVEN** an admitted reader and an open handle
- **WHEN** the trusted supervisor revokes the view
- **THEN** later mediated reads and opens fail without claiming erased plaintext

#### Scenario: A resource counter reaches its bound

- **GIVEN** the live-handle, lifetime-handle or request limit
- **WHEN** an operation would exceed it
- **THEN** it is refused without wraparound or state reset

### Requirement: NM006 Private canonical transport

The host SHALL serialize bounded canonical WRITFS1 frames over a broker-only channel and accept only the next exact reply sequence. Malformed replies, timeouts and interpreter loss SHALL poison the instance and stop byte service; no resynchronization, automatic retry or weaker authority path is permitted.

#### Scenario: Fragmented or coalesced valid frames

- **GIVEN** a private byte stream containing complete valid frames
- **WHEN** reads split or combine those frames
- **THEN** each frame produces exactly one ordered Bend transition and reply

#### Scenario: Ambiguous or failed peer

- **GIVEN** a malformed reply, timeout, sequence mismatch or terminated interpreter
- **WHEN** the native host attempts another operation
- **THEN** it denies service and retires the uncertain instance

### Requirement: NM007 Native presentation evidence

Each platform claim SHALL include real native filesystem reads and denials: WinFsp on Windows, FUSE on Linux, and File_system sessions plus VFS consumption on native Genode. WSL or Genode-on-Linux SHALL NOT substitute for another native target. Generated JavaScript execution SHALL be distinguished from machine code.

#### Scenario: Model tests pass without a mount

- **GIVEN** passing policy checks without a successful native filesystem run
- **WHEN** evidence is recorded
- **THEN** mounted support remains unverified

#### Scenario: Native Genode runs under QEMU

- **GIVEN** a selected native Genode base booted under QEMU
- **WHEN** filesystem sessions and a VFS consumer read and test denial
- **THEN** the record identifies that base, runtime, configuration and observed results

### Requirement: NM008 Scope confinement and cleanup claims

Confinement claims SHALL name the exact profile, tested channels, positive controls, observed denials and remaining gaps. Missing required setup SHALL deny before input. Tests SHALL clean up only owned resources and retain failures. This contribution SHALL NOT complete broader host, issuer, namespace or durable-publication tasks by implication.

#### Scenario: Required native control is absent

- **GIVEN** an unavailable or failed profile control
- **WHEN** the supervisor prepares a reader
- **THEN** it refuses before input and does not fall back to a weaker profile

#### Scenario: A probe reports a blocked egress attempt

- **GIVEN** a functioning target established by positive control
- **WHEN** the confined worker attempts the forbidden effect
- **THEN** evidence records the native result and applicable receiver-side checks

#### Scenario: Cleanup fails

- **GIVEN** resources created by this test instance
- **WHEN** a worker, mount, session or temporary resource fails to retire
- **THEN** the test remains failed and does not delete unrelated resources
