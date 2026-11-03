# Native Linux host

## Purpose

Apply Writ's portable authority and publication semantics to real Linux processes while keeping authenticated monitor state, protected execution, descriptor authority, and final output under one enforcing boundary.

## ADDED Requirements

### Requirement: LH-001 A supported profile is explicit

A Linux host SHALL identify and verify its runtime, architecture, kernel configuration, confinement profile, and required security interfaces before accepting protected work.

#### Scenario: Model execution without a launcher

- **GIVEN** the Bend library tests pass on Linux
- **WHEN** no validated worker launcher or broker is installed
- **THEN** the host is reported as model-only
- **AND** protected execution is unavailable.

#### Scenario: A required interface is absent

- **GIVEN** the chosen profile requires a confinement feature disabled by the running kernel
- **WHEN** the host attempts to prepare a protected worker
- **THEN** preparation is denied without substituting a weaker profile.

### Requirement: LH-002 Worker identity is bound to an authenticated lifetime

The broker SHALL bind each worker session to trusted launch evidence, current process lifetime, authenticated subject, monitor incarnation, and session generation rather than trusting caller-supplied IDs or connection possession alone.

#### Scenario: Parent-created socketpair is inherited

- **GIVEN** a parent creates a socketpair and transfers one endpoint to a worker
- **WHEN** the broker resolves the session actor
- **THEN** socketpair-time credentials are not treated as proof of the worker's identity
- **AND** the trusted launch binding must establish the intended actor.

#### Scenario: An endpoint moves to another process

- **GIVEN** a process obtains a session descriptor created for another worker
- **WHEN** it requests an operation without approved delegation
- **THEN** the endpoint possession does not authorize it as the original subject.

### Requirement: LH-003 Confinement precedes protected observation

The Linux launcher SHALL establish the complete selected confinement and resource profile before untrusted execution receives protected data, and SHALL deny launch if any required setup step fails.

#### Scenario: Filter setup fails

- **GIVEN** namespace setup succeeds but a required syscall filter cannot be installed
- **WHEN** the worker reaches the input-delivery barrier
- **THEN** no protected input is delivered
- **AND** the incomplete worker is retired.

#### Scenario: A thread escapes setup coverage

- **GIVEN** a runtime can create another thread during setup
- **WHEN** the launcher cannot establish the profile for every execution thread
- **THEN** protected dispatch is denied.

### Requirement: LH-004 Inherited authority is explicitly bounded

The launcher SHALL remove every inherited descriptor, mapping, credential, and environment-derived resource outside the declared worker profile, including public standard streams and device access, before releasing protected inputs.

#### Scenario: An old writable file descriptor survives

- **GIVEN** the worker would inherit a writable descriptor opened before Landlock enforcement
- **WHEN** the launcher inventories its effective authority
- **THEN** the descriptor is removed or the launch is denied
- **AND** later path restrictions are not credited with retroactively revoking it.

#### Scenario: An environment variable names a private broker socket

- **GIVEN** an inherited environment value would expose an unintended authority channel
- **WHEN** the worker launch environment is constructed
- **THEN** the value and reachable channel are excluded from the worker's authority.

### Requirement: LH-005 Required Landlock rights cannot be dropped

The Linux host SHALL probe the available Landlock interface and enforce every right required by its protected worker profile, rejecting unsupported configurations instead of silently reducing the handled restriction set.

#### Scenario: Older ABI lacks a required scope

- **GIVEN** a worker profile requires an IPC restriction unavailable in the current ABI
- **WHEN** the ruleset is prepared
- **THEN** the worker does not receive protected data under a reduced ruleset.

### Requirement: LH-006 Broker requests preserve exact resource scope

The Linux broker SHALL resolve bounded requests through current monitor-owned resource bindings and the common Bend authority path, preventing descriptor reuse, mutable request data, or pathname substitution from selecting a different operation or object.

#### Scenario: Validated request bytes are changed

- **GIVEN** an untrusted process changes its request buffer after submission
- **WHEN** the broker authorizes and executes the operation
- **THEN** only its validated immutable request snapshot may select the action.

#### Scenario: A descriptor number is recycled

- **GIVEN** a closed session descriptor number is reused for another local resource
- **WHEN** an old request names that number and generation
- **THEN** the old request cannot resolve to the new resource.

### Requirement: LH-007 Delegation is explicit and attenuating

The Linux host SHALL deny unauthorized descriptor transfer or process inheritance as a means of acquiring Writ authority; supported delegation SHALL authenticate the recipient, preserve the exact plan and origin obligations, and only narrow rights or expiry.

#### Scenario: Sender transfers an FD without a delegation record

- **GIVEN** a sender attempts to pass a Writ session through ancillary descriptor data
- **WHEN** the recipient has no approved subject binding
- **THEN** the transfer is prevented or the recipient's operation is denied.

#### Scenario: Delegate asks for a broader destination

- **GIVEN** an approved delegation covers one internal destination
- **WHEN** the recipient requests another destination
- **THEN** the request is denied under the original plan scope.

### Requirement: LH-008 Revocation controls future release

The Linux broker SHALL revalidate current authority at commit and invalidate stale sessions across revocation or monitor restart, without treating closure of one native descriptor as revocation of all copies.

#### Scenario: A duplicate remains open after revocation

- **GIVEN** a worker retains a duplicate descriptor when its Writ grant is revoked
- **WHEN** it submits an uncommitted result
- **THEN** publication is denied despite that open descriptor.

#### Scenario: A delayed result crosses a monitor restart

- **GIVEN** the monitor restarts with a new incarnation and preserved replay state
- **WHEN** a worker submits a result under its old session generation
- **THEN** the stale session cannot regain authority.

### Requirement: LH-009 Only sealed artifacts reach external destinations

The Linux host SHALL keep worker output and diagnostics confined until the applicable policy permits release, and SHALL publish only the sealed artifact accepted by the common durable commit path with its inherited terms and state transition.

#### Scenario: The worker swaps a staged object

- **GIVEN** output was validated under one artifact identity
- **WHEN** a worker attempts to replace the staged bytes or path before publication
- **THEN** different bytes cannot be released under the accepted identity.

#### Scenario: A public error channel contains protected data

- **GIVEN** a worker emits a secret-dependent error or exit result
- **WHEN** that observable channel is not approved for the inherited restrictions
- **THEN** the host withholds the protected content from the public observer.

### Requirement: LH-010 Qualification includes real host behavior

A Linux enforcement claim SHALL require shared decision-vector conformance and native adversarial evidence for the declared profile; model tests, namespace creation, a mounted frontend, or CPU fallback SHALL not establish untested isolation or GPU behavior.

#### Scenario: Decision vectors pass but an inherited socket can transmit

- **GIVEN** all shared policy vectors pass
- **WHEN** an adversarial worker sends protected data through an inherited socket
- **THEN** the host profile fails qualification until the channel is eliminated or correctly mediated.

#### Scenario: A protected job requires an unvalidated GPU

- **GIVEN** only the CPU profile has acceptance evidence
- **WHEN** a job requires direct GPU execution
- **THEN** the job is denied until a compatible device profile is qualified
- **AND** CPU fallback is not reported as physical GPU execution.
