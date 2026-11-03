# Native Windows host

## Purpose

Preserve Writ's portable authority and publication semantics on native Windows by binding authentic worker sessions, explicit token and handle scope, confined execution, and sealed output to the same Bend decision core.

## ADDED Requirements

### Requirement: WH-001 Native qualification is separate from model execution

A Windows host SHALL identify its Windows build, architecture, Bend runtime/backend, ABI binding, and confinement profile, and SHALL establish native runtime and isolation evidence before advertising protected execution.

#### Scenario: The library passes in WSL

- **GIVEN** Writ's tests pass inside a Linux WSL environment
- **WHEN** native Windows support is reported
- **THEN** those tests are identified as Linux-target evidence
- **AND** no Windows handle or worker-isolation claim follows from them.

#### Scenario: Generated model code runs on Windows

- **GIVEN** generated JavaScript executes the pure Bend test vectors on Windows
- **WHEN** no validated native launcher or authority binding exists
- **THEN** the result is recorded as model execution only.

### Requirement: WH-002 The created worker satisfies its exact profile

The Windows launcher SHALL verify the actual worker's AppContainer or LPAC policy, capability set, object grants, and required restrictions before protected observation, and SHALL deny setup failure without silently choosing a weaker profile.

#### Scenario: LPAC creation cannot satisfy the runtime

- **GIVEN** an invocation selects the LPAC profile
- **WHEN** runtime startup requires an undeclared broader capability
- **THEN** protected dispatch is denied rather than retried as an unrestricted or ordinary AppContainer process.

#### Scenario: Only low integrity was established

- **GIVEN** a process has low integrity and a restricted token
- **WHEN** its selected profile requires verified LPAC behavior
- **THEN** those properties alone do not admit protected input.

### Requirement: WH-003 Broker identity derives from trusted Windows evidence

The Windows broker SHALL bind local IPC peers to authenticated security context, trusted launch evidence, process lifetime, monitor incarnation, and session generation; asserted names, SIDs, PIDs, pipe names, and handle values SHALL not supply that authority.

#### Scenario: Another process claims the worker's package identity

- **GIVEN** a caller presents the same package name or SID string as an authorized worker
- **WHEN** it lacks that worker's authenticated launch and session binding
- **THEN** its operation is denied.

#### Scenario: Pipe client inspection fails

- **GIVEN** the selected IPC authentication method requires client impersonation
- **WHEN** impersonation fails or provides insufficient identity evidence
- **THEN** the broker rejects the request
- **AND** it does not perform the client's operation under broker authority.

### Requirement: WH-004 Handle authority is an explicit allowlist

The Windows launcher SHALL limit inherited and reachable handles to the selected worker profile and prevent unauthorized acquisition of broker process, token, storage, IPC, mapping, desktop, or device authority before delivering protected data.

#### Scenario: A public console handle is inheritable

- **GIVEN** the launching process owns an inheritable console output handle
- **WHEN** a protected worker is created
- **THEN** that handle is excluded unless its output channel is explicitly authorized.

#### Scenario: A worker attempts to duplicate broker authority

- **GIVEN** the worker requests a process or token handle that would permit broker inspection or handle duplication
- **WHEN** the request crosses the host boundary
- **THEN** access is denied under the selected profile.

### Requirement: WH-005 Native object references do not widen Writ scope

The Windows broker SHALL resolve bounded immutable requests through current monitor-owned bindings and the common Bend authority path; supported delegation SHALL authenticate its recipient, preserve the exact plan and origin obligations, and only narrow rights or expiry.

#### Scenario: A session handle is transferred without delegation

- **GIVEN** a process receives an inherited or duplicated session handle
- **WHEN** no approved binding authorizes it as a recipient
- **THEN** handle possession alone cannot authorize the original subject's operation.

#### Scenario: An old numeric handle is reused

- **GIVEN** Windows reuses a closed handle value for another object
- **WHEN** a request presents the old session generation with that value
- **THEN** it cannot resolve to the new object or regain old authority.

### Requirement: WH-006 Worker lifetime and resources remain supervised

The Windows host SHALL enforce its declared resource limits and supervise every permitted worker descendant without unapproved breakaway, while treating Job Object membership as lifecycle control rather than a replacement for process access restrictions.

#### Scenario: A worker requests a child outside its job

- **GIVEN** the profile forbids unbrokered descendants
- **WHEN** the worker requests direct or indirect creation of an unsupervised process
- **THEN** the creation is denied or the profile fails qualification.

#### Scenario: The broker terminates unexpectedly

- **GIVEN** a protected worker is running when its broker fails
- **WHEN** the host performs lifecycle cleanup
- **THEN** the worker cannot publish through an inherited external channel
- **AND** protected work resumes only under a newly validated session.

### Requirement: WH-007 Private state and diagnostics retain information restrictions

The Windows host SHALL account for every worker-visible persistent or shared input and confine output channels including profile storage, registry state, caches, logs, errors, clipboard, desktop objects, and crash artifacts under the declared information-flow policy.

#### Scenario: An AppContainer profile is reused

- **GIVEN** a profile contains state influenced by a prior protected invocation
- **WHEN** another invocation would observe that state
- **THEN** its origin restrictions are retained or the state is securely excluded before reuse.

#### Scenario: A worker writes protected data to a crash diagnostic

- **GIVEN** a fault produces a diagnostic influenced by protected input
- **WHEN** the diagnostic would be exposed outside its allowed domain
- **THEN** the host withholds that content from the unapproved observer.

### Requirement: WH-008 Revocation is checked despite surviving native references

The Windows broker SHALL reject future protected use and uncommitted release under revoked or stale session authority, independently of whether duplicated handles, mapped views, or running worker processes still exist.

#### Scenario: A copied handle survives revocation

- **GIVEN** a worker retains a duplicate when its Writ capability is revoked
- **WHEN** it submits a result for publication
- **THEN** the live authority check denies release despite the surviving handle.

#### Scenario: A completion arrives after broker restart

- **GIVEN** the restarted broker has a new incarnation and preserved durable replay state
- **WHEN** a delayed completion uses an old worker session
- **THEN** it cannot restore expired authority or recommit a consumed invocation.

### Requirement: WH-009 Publication binds exact sealed output and durable state

The Windows host SHALL expose only the sealed artifact accepted by the common Bend commit gate and SHALL preserve its inherited policy, accounting, and replay state through the shared durable-publication contract.

#### Scenario: The worker mutates its output mapping after validation

- **GIVEN** a result was validated and assigned an artifact identity
- **WHEN** the worker changes a still-writable buffer or mapping
- **THEN** the changed bytes cannot be published under that identity.

#### Scenario: Publication is interrupted by a crash

- **GIVEN** publication is interrupted between durable steps
- **WHEN** the host recovers
- **THEN** it reconciles the original scoped operation without exposing an unauthorized result or spending the same invocation twice.

### Requirement: WH-010 Qualification includes Windows escape-path evidence

A native Windows enforcement claim SHALL require the shared decision vectors plus actual adversarial tests for the named Windows profile; passing policy tests or CPU execution SHALL not establish untested host channels or GPU isolation.

#### Scenario: Policy tests pass but a public output remains reachable

- **GIVEN** all common Bend decisions match expected results
- **WHEN** a protected worker can emit through an unapproved console, network, or shared object
- **THEN** the Windows profile fails qualification.

#### Scenario: A protected invocation requires an unqualified GPU

- **GIVEN** the CPU worker profile is qualified but no device profile is qualified
- **WHEN** an invocation requires GPU execution
- **THEN** dispatch is denied without granting a raw device handle or describing CPU fallback as a GPU run.
