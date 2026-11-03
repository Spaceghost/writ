# Future kernel host using Drift

## Purpose

Enforce Writ's portable host behavior on a future kernel using Drift drivers while preserving the Genode reference, authentic native authority, confined resources, and durable publication semantics.

## ADDED Requirements

### Requirement: DKH-001 Kernel route preserves the common host contract

The future kernel host SHALL qualify either a Genode base path that reuses the Writ Genode integration or a separately implemented direct adapter against the same portable host contract.

#### Scenario: A Genode base is supplied

- **GIVEN** the kernel implements the required Genode base interfaces
- **WHEN** Writ is qualified on that kernel
- **THEN** the real component and native resource boundaries are tested with the common host traces.

#### Scenario: Direct adapter uses similar method names

- **GIVEN** a direct adapter exposes methods named after Genode interfaces
- **WHEN** no native authority and confinement evidence exists
- **THEN** name or type compatibility alone does not qualify the host.

### Requirement: DKH-002 Kernel isolation precedes protected execution

The host SHALL deny protected input delivery until the selected profile enforces separate worker and monitor address spaces, authenticated IPC, native object ownership, and bounded execution resources.

#### Scenario: Driver demo boots without paging

- **GIVEN** a booted driver demonstration has one shared address space
- **WHEN** protected Writ work is requested
- **THEN** the host refuses the request despite successful device I/O.

#### Scenario: Worker addresses monitor memory

- **GIVEN** the host profile admits protected workers
- **WHEN** a worker attempts to read or overwrite monitor state
- **THEN** the kernel denies access and the monitor's authority remains unchanged.

### Requirement: DKH-003 Native references retain peer and generation binding

The host SHALL resolve a native object reference only through its authenticated subject, domain instance, generation, and currently approved Writ scope.

#### Scenario: Numeric resource token is submitted as authority

- **GIVEN** a caller knows a DMA token, capability-slot number, pointer, or physical address
- **WHEN** it presents that value without the authenticated native binding
- **THEN** the request is denied.

#### Scenario: Revoked slot is reused

- **GIVEN** an old domain retains a reference to a slot later assigned to a new object
- **WHEN** it uses the old reference or delegates it to another subject
- **THEN** generation or subject mismatch prevents use of the new object.

### Requirement: DKH-004 Driver resources stay within assigned authority

The resource provider SHALL restrict each driver operation to kernel-assigned register windows, device identity, allocation ownership, and live resource bounds.

#### Scenario: Register access escapes the assigned window

- **GIVEN** a driver owns one bounded device register region
- **WHEN** an operation uses another region or an invalid offset or width
- **THEN** it cannot access the unassigned hardware resource.

#### Scenario: Worker requests raw output hardware

- **GIVEN** a worker is authorized only for a scoped Writ destination
- **WHEN** it requests raw block, NIC, PCI, or DMA access
- **THEN** that request cannot bypass the approved output service.

### Requirement: DKH-005 DMA containment and reclamation are explicit

The host SHALL admit device access only with the profile's required DMA containment and retain device-owned resources until hardware quiescence is established.

#### Scenario: Device cannot be contained

- **GIVEN** a device outside the trusted host boundary can access unrelated memory
- **WHEN** protected work requests that device
- **THEN** the device remains unavailable to the work.

#### Scenario: Reset fails after revocation

- **GIVEN** authority is revoked while a device still owns DMA buffers
- **WHEN** reset fails to establish quiescence
- **THEN** the buffers and required mappings remain quarantined instead of being reused.

### Requirement: DKH-006 Revocation does not relax inherited policy

The host SHALL block newly revoked operations while retaining confinement and inherited restrictions for data already delivered to a worker.

#### Scenario: Worker copied plaintext before revocation

- **GIVEN** a worker already copied protected input into private memory
- **WHEN** its input capability is revoked
- **THEN** the copied data cannot gain a public output route.

#### Scenario: Cached intent is used after revocation

- **GIVEN** an earlier snapshot permitted an operation that has not reached durable publication authorization
- **WHEN** the current authority rejects it at publication
- **THEN** the cached decision cannot authorize the effect.

### Requirement: DKH-007 Driver failures and events respect domain lifetime

The host SHALL contain untrusted driver faults and bind asynchronous interrupts or completions to the live device and domain generation before delivery.

#### Scenario: Driver faults during a request

- **GIVEN** a driver serves a protected worker through a restricted domain
- **WHEN** the driver crashes
- **THEN** the fault cannot modify monitor authority or give the worker a new output path.

#### Scenario: Completion arrives for a retired device instance

- **GIVEN** an old device request remains pending during teardown
- **WHEN** its completion arrives after the domain generation changes
- **THEN** it cannot complete or mutate a request in the replacement domain.

### Requirement: DKH-008 Clocks and quotas are enforced by the host

The host SHALL apply trusted monotonic deadlines and enforce configured memory, capability, execution, and event quotas independently of worker reports.

#### Scenario: Worker reports extra time or resources

- **GIVEN** a worker exhausts its time or allocation budget
- **WHEN** it supplies a smaller usage value or a later deadline
- **THEN** the host's own accounting still limits the operation.

#### Scenario: Deadline clock becomes invalid

- **GIVEN** a request depends on an exclusive expiry
- **WHEN** the host cannot establish a valid monotonic time reading
- **THEN** it refuses the protected operation rather than extending the expiry.

### Requirement: DKH-009 The native bridge preserves Bend authority ownership

The kernel host SHALL execute Writ's Bend decision path using monitor-owned facts, with the native bridge limited to bounded translation and genuine host operations.

#### Scenario: Worker supplies a complete authority context

- **GIVEN** a worker sends records resembling a valid registry, session, and ledger
- **WHEN** the bridge parses the request
- **THEN** those records cannot replace the monitor's authoritative state.

#### Scenario: Driver callback attempts policy authorization

- **GIVEN** a resource callback can access a device
- **WHEN** a Writ operation needs release authority
- **THEN** callback access alone cannot substitute for the current Bend commit checks.

### Requirement: DKH-010 Device completion preserves publication atomicity

The host SHALL publish an artifact and its accepted Writ state only through the durable publication contract, including recovery from partial I/O and interrupted commit.

#### Scenario: Block write partially completes

- **GIVEN** an output write completes some sectors before failure
- **WHEN** the storage service handles the error
- **THEN** an incomplete artifact is not exposed as a committed Writ result.

#### Scenario: System restarts after flush

- **GIVEN** payload bytes were flushed before publication state was durably resolved
- **WHEN** the system restarts
- **THEN** recovery follows the invocation's transaction record without duplicate spending or publication.

### Requirement: DKH-011 Portable conformance includes denial behavior

The kernel host SHALL pass the common normalized policy and host traces, including forged authority, stale references, revoked release, and unsupported-effect denial.

#### Scenario: Host chooses a different native handle representation

- **GIVEN** Genode and the future kernel use different native object identifiers
- **WHEN** the same authorized and unauthorized scenarios are run
- **THEN** their normalized Writ decisions and retained restrictions agree.

#### Scenario: Kernel profile lacks a required GPU boundary

- **GIVEN** an operation requires a device effect the profile cannot isolate
- **WHEN** dispatch evaluates that requirement
- **THEN** it denies the effect instead of silently widening the profile.

### Requirement: DKH-012 Qualification names the actual execution boundary

Qualification SHALL identify the Writ, Drift, kernel, bridge, runtime, toolchain, image, and device versions and distinguish source review, model execution, emulated hardware, and physical-hardware evidence.

#### Scenario: Prior Drift driver logs are available

- **GIVEN** Drift retains successful driver or source-profile test records
- **WHEN** the Writ kernel host is evaluated
- **THEN** those records remain driver evidence and cannot replace a booted Writ integration test.

#### Scenario: A complete emulated-kernel run succeeds

- **GIVEN** a pinned kernel image executes Writ and its actual native isolation tests under an emulator
- **WHEN** the result is reported
- **THEN** it is scoped to that image and device model without claiming physical-device qualification.
