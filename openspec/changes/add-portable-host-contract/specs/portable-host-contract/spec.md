# Portable host enforcement contract

## Purpose

Preserve Writ's subject, information-flow, and operation guarantees across Genode,
Linux, Windows, and future kernel hosts through explicit native authority bindings
and independently recorded platform qualification evidence.

## ADDED Requirements

### Requirement: PH-001 One policy implementation across hosts

Every host adapter SHALL route protected operation decisions through the shared Bend authority and verification path.

#### Scenario: Native transport accepts a request

- **GIVEN** the native service accepts a well-formed operation request
- **WHEN** its exact Writ plan fails current transfer or commit checks
- **THEN** the host does not perform the protected effect.

#### Scenario: An adapter offers a fast publication route

- **GIVEN** an optional native fast path can write output
- **WHEN** it lacks the complete Bend authorization result bound to the actual artifact
- **THEN** that route is unavailable for protected work.

### Requirement: PH-002 Subject identity survives the native boundary

The adapter SHALL derive the effective requesting subject from trusted session and delegation state rather than caller-supplied identifiers or native endpoint possession alone.

#### Scenario: A client changes its claimed subject

- **GIVEN** a native session is bound to subject A
- **WHEN** its message claims to be subject B
- **THEN** the claim cannot change the authenticated Writ subject.

#### Scenario: A delegated endpoint hides its new holder

- **GIVEN** a subject-bound operation requires the invoking actor to be established
- **WHEN** a transferred endpoint does not provide that evidence or an approved delegation binding
- **THEN** the protected operation is denied.

### Requirement: PH-003 Native handles remain host-local authority

An adapter SHALL resolve native resource access only through its trusted local binding and SHALL NOT accept a serialized selector, descriptor, handle, or driver token as transferable authority.

#### Scenario: A guessed numeric handle

- **GIVEN** a caller guesses the numeric value of another session's resource
- **WHEN** it presents that number in a request
- **THEN** the number grants no access to the resource.

#### Scenario: A reference crosses hosts

- **GIVEN** a plan names a resource held by another host
- **WHEN** the receiving host lacks a newly authenticated and scoped grant
- **THEN** it denies access despite recognizing the resource description.

### Requirement: PH-004 References bind incarnation and generation

Resource resolution SHALL require the current host incarnation, resource generation, and unique live binding.

#### Scenario: Handle reuse after restart

- **GIVEN** a new host instance reuses an old numeric handle
- **WHEN** a request or completion carries the prior incarnation
- **THEN** it cannot resolve the new resource.

#### Scenario: Conflicting live mappings

- **GIVEN** two live bindings ambiguously match one reference
- **WHEN** an operation tries to use that reference
- **THEN** resolution is denied rather than choosing by table order.

### Requirement: PH-005 Delegation cannot widen Writ scope

Delegation SHALL preserve the exact plan and origin obligations, only narrow rights or lifetime, and require new authorization for a changed effective subject. Root issuance SHALL check the monitor-supplied current Frontend revision and full live capability scope and require paired transfer admission before committing the entry.

#### Scenario: A formerly live handle loses its registry grant

- **GIVEN** a monitor retained a Frontend handle and the current registry no longer contains its grant
- **WHEN** the monitor issues a root from that handle using its current authority snapshot
- **THEN** issuance denies with its supplied host state unchanged and no effects
- **AND** later use and publication still require their own current checks.

#### Scenario: A transferred endpoint requests another bucket

- **GIVEN** a delegated operation names destination D
- **WHEN** its holder requests destination E
- **THEN** the operation is denied unless the complete new scope receives required authorization.

#### Scenario: A narrower proxy leaves an old handle alive

- **GIVEN** a new proxy exposes fewer operations
- **WHEN** an older broad endpoint still exists
- **THEN** the adapter does not report the older authority as revoked solely because the proxy was created.

### Requirement: PH-006 Required confinement precedes plaintext

Protected inputs SHALL be delivered only after the host establishes every required confinement control for the declared execution profile.

#### Scenario: A required kernel feature is missing

- **GIVEN** a profile requires an unavailable native isolation control
- **WHEN** protected execution is requested
- **THEN** admission is denied without downgrading the profile or delivering plaintext.

#### Scenario: An inherited output remains accessible

- **GIVEN** a worker retains an unapproved descriptor, handle, shared-memory route, or service
- **WHEN** the host prepares its input delivery
- **THEN** the route is removed or mediated before delivery, or execution is denied.

### Requirement: PH-007 Quotas and observable channels are bounded

The host SHALL enforce the declared resource and output-channel limits before and throughout protected execution.

#### Scenario: A worker encodes a secret in diagnostics

- **GIVEN** protected input influences a log, error, status, or exposed metadata field
- **WHEN** the worker attempts a public diagnostic emission
- **THEN** the host subjects it to the applicable output policy.

#### Scenario: A worker exhausts its resource quota

- **GIVEN** a worker reaches its admitted memory, handle, or work bound
- **WHEN** it requests additional resources
- **THEN** exhaustion cannot grant wider access or expose private result data.

### Requirement: PH-008 Artifact sealing excludes all writers

An artifact SHALL become eligible for publication only when its exact bytes and execution scope are fixed and no remaining CPU, process, or device writer can mutate them.

#### Scenario: A read-only mapping retains a writable alias

- **GIVEN** the consumer sees a read-only output mapping but another writer remains
- **WHEN** the result is offered as sealed
- **THEN** sealing is rejected or the writer is eliminated before registration.

#### Scenario: A path is retargeted

- **GIVEN** an output path or virtual-filesystem handle now resolves to a different object
- **WHEN** publication uses the earlier artifact identity
- **THEN** the replacement bytes are not published under that identity.

### Requirement: PH-009 Publication observes one current authority boundary

The host SHALL serialize current authorization with the durable publication protocol for the exact invocation and artifact.

#### Scenario: Revocation precedes authorization

- **GIVEN** source approval or a capability is revoked before publication authorization commits
- **WHEN** a previously prepared operation reaches the final gate
- **THEN** publication is denied under the new authoritative state.

#### Scenario: Crash recovery repeats a publication attempt

- **GIVEN** an invocation was durably authorized and its publication outcome is uncertain
- **WHEN** the host recovers
- **THEN** it reconciles the same invocation through the durable protocol without duplicate spending or a new artifact substitution.

### Requirement: PH-010 Revocation includes quiescence and stale completion rejection

Revocation SHALL stop newly unauthorized effects and prevent retired workers, devices, or asynchronous completions from accessing reused resources.

#### Scenario: A device completes after teardown

- **GIVEN** its former domain and buffers have been revoked
- **WHEN** a queued completion arrives with the old generation
- **THEN** it cannot mutate or publish a new invocation's resources.

#### Scenario: A reader already copied plaintext

- **GIVEN** a reader previously received authorized plaintext
- **WHEN** its access is revoked
- **THEN** future operations are denied as required
- **AND** the host does not describe revocation as erasing independent earlier copies.

### Requirement: PH-011 The transport has a bounded canonical schema

Authoritative transport facts SHALL use a versioned canonical schema with explicit widths, bounds, and rejection of unknown or malformed representations.

#### Scenario: A peer sends an unknown authority variant

- **GIVEN** the peer encodes an unsupported version or record tag
- **WHEN** the host decodes its request
- **THEN** no authority record or protected operation is created from that representation.

#### Scenario: A peer supplies a complete trusted context

- **GIVEN** a message includes serialized policies, caller identity, ledger, or execution bindings
- **WHEN** the adapter constructs the operation's authoritative context
- **THEN** only independently authenticated monitor state is used as authority.

### Requirement: PH-012 Qualification requires both decision and native tests

A protected host profile SHALL pass shared Bend decision vectors and native confinement, revocation, artifact, and recovery probes before being reported as supported.

#### Scenario: The library suite passes on a development host

- **GIVEN** all pure Writ tests pass but native escape-path probes are absent
- **WHEN** support is reported
- **THEN** only library execution is reported as verified.

#### Scenario: Two native adapters are compared

- **GIVEN** both claim the same protected profile
- **WHEN** shared plans and adversarial transitions are evaluated
- **THEN** their decisions, retained restrictions, and denial state satisfy the same contract
- **AND** target-specific native probe evidence accompanies each claim.

### Requirement: PH-013 Runtime and accelerator evidence remains target-specific

A support record SHALL identify the actual OS, kernel, runtime, configuration, and execution backend used for each claimed milestone.

#### Scenario: Tests run under WSL

- **GIVEN** Bend tests run in a Linux environment on a Windows machine
- **WHEN** the result is recorded
- **THEN** it is Linux execution evidence and not native Windows confinement evidence.

#### Scenario: A device request falls back to CPU

- **GIVEN** the source requests GPU work but the runtime executes it on the CPU
- **WHEN** the host reports validation
- **THEN** the result does not establish physical GPU execution or isolation.

### Requirement: PH-014 Unisolated accelerators cannot access protected state

Protected accelerator work SHALL require a validated isolation profile that prevents the producer and its device access from modifying authoritative monitor state.

#### Scenario: A shared device heap exposes the original graph

- **GIVEN** the producer can modify both candidate and authoritative graph memory
- **WHEN** that accelerator profile is considered for protected work
- **THEN** it is rejected until the required isolation is established.

#### Scenario: CPU execution satisfies the admitted request

- **GIVEN** GPU isolation is unavailable and the approved request permits CPU execution
- **WHEN** the host selects a verified CPU profile
- **THEN** it may execute there while recording the actual backend and preserving all policy checks.
