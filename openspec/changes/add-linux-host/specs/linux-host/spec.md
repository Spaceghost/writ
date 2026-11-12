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

### Requirement: LH-011 Local supervisor authority is explicitly provisioned

The proposed profile SHALL establish an operator-controlled supervisor boundary before protected work. Authenticated administrator actions SHALL install the authority directory, exact placements, and separate source-read and destination-write approval roles. The supervisor SHALL bind each worker lifetime and session to its intended local service principal. A UID, PID, pidfd, socket or public Bend record alone SHALL NOT establish that principal, grant authority or authenticate a human.

#### Scenario: Local process identity is not source approval

- **GIVEN** a worker has the configured UID and a retained process lifetime
- **AND** the source-read authority has not issued an applicable approval
- **WHEN** the supervisor considers issuing the worker a scoped grant
- **THEN** the issuer denies the grant
- **AND** neither operator control nor destination-write approval substitutes for source-read approval.

#### Scenario: A worker supplies authority-shaped state

- **GIVEN** a worker can send an ordinary request to its broker session
- **WHEN** it sends a claimed subject, registry, authority directory, timestamp or serialized monitor state
- **THEN** those bytes cannot replace the supervisor-owned identity, clock or issuer state.

#### Scenario: A transferred administrative endpoint does not carry its role

- **GIVEN** an administrative channel endpoint provisioned for one role has been passed to a different process
- **WHEN** the receiver reads a record sent by the second process
- **THEN** the receiver attributes the record to the role retained for the actual sender's lifetime, or denies it
- **AND** possession of the endpoint never attributes the record to the role that owned the endpoint before the transfer.

#### Scenario: An unprovisioned sender is not attributed

- **GIVEN** a record arrives from a process with no retained role
- **WHEN** the receiver classifies the record
- **THEN** the record is denied
- **AND** no `from` is attached to any issuance.

### Requirement: LH-012 Trusted time advances independently of denied policy state

The supervisor SHALL retain a trusted monotone clock high-water mark separately from policy state, sampling before every untrusted request, including malformed and denied requests. An unavailable, ambiguous, overflowing or regressing sample SHALL poison protected effects. Revocation, retirement, quiescence and STOP SHALL remain available as fail-closed cleanup; handed-off bytes cannot be recalled.

#### Scenario: A request is denied after a later trusted sample

- **GIVEN** the clock owner has retained time 110
- **WHEN** a request is denied after sampling time 150
- **THEN** the clock watermark retains 150 while policy state stays unchanged.

### Requirement: LH-015 Clock poison blocks protected effects

Clock poison SHALL block new grants, metadata and byte observations, worker-input delivery, publication and effect handoff.

#### Scenario: Clock poison blocks use but allows cleanup

- **GIVEN** the clock owner observes a regression
- **WHEN** an actor requests a protected effect or safe cleanup
- **THEN** the owner denies the protected effect and permits safe cleanup.

#### Scenario: An expired request is followed by a lower sample

- **GIVEN** a descriptor expires at time 150 and a request is denied at trusted time 150
- **WHEN** the next clock sample is 149
- **THEN** the clock owner refuses further protected use rather than reviving the descriptor
- **AND** the earlier denial leaves Issuance, Frontend, session and ledger policy state unchanged while the separate clock watermark retains 150.

#### Scenario: A malformed request observes a later time

- **GIVEN** the owner has retained time 110
- **WHEN** it observes time 150 before rejecting a malformed untrusted request
- **THEN** it retains the 150 watermark without treating the malformed bytes as an authority transition
- **AND** a later lower sample cannot restore expired authority.

### Requirement: LH-013 Current local authority and effects share one owner

For each admitted use the supervisor SHALL serialize current issuer, authenticated subject, trusted time and epoch with Frontend, Linux session and canary state. It SHALL rebuild the issuer read grants, write grants and registry for that subject and time, and re-resolve the exact descriptor and paired plan.

#### Scenario: A later use follows issuer revocation

- **GIVEN** a descriptor was opened with a previously current issuer snapshot
- **WHEN** an authority revokes its required approval
- **THEN** the owner rebuilds the projections from current issuer state before the next use.

#### Scenario: An accepted issuer revoke requires containment

- **GIVEN** a synthetic Rendezvous owner has issued an input and admitted a worker
- **WHEN** its issuer accepts an approval revocation
- **THEN** it retains that issuer change and requires whole-instance containment before further protected processing
- **AND** trusted cleanup returns only actual shared stop effects while retaining their history.

#### Scenario: A reader authorization expires independently

- **GIVEN** the selected provider remains current but the reader has no current matching Transfer grant
- **WHEN** the owner samples time before the next request
- **THEN** it requires containment without processing that request.

### Requirement: LH-016 Effects follow the current joint check

Before observation, delivery or publication, the owner SHALL enforce independent original-graph verification and original policy, operation, sink, budget and confinement obligations. It SHALL retain accepted state before effect handoff and order handoff against revocation. The existing public-canary Copy SHALL commit at most once; its session, ledger, intent and provenance SHALL survive later failure without a second charge or alternate release route.

#### Scenario: Cached grant projections survive a revocation

- **GIVEN** a descriptor and a Copy committed while source and destination approvals were current
- **WHEN** an authority revokes either approval before a later use
- **THEN** the supervisor rebuilds all projections from the current issuer state and denies that use
- **AND** it retains the original committed evidence without replaying the Copy.

#### Scenario: The former canary path remains reachable

- **GIVEN** the combined profile has a joint owner and the prior standalone canary dispatcher is still reachable by a worker
- **WHEN** that dispatcher could return an observation without the joint owner's current checks
- **THEN** the combined profile is not admitted or qualified.

### Requirement: LH-014 Local restart does not revive authority or replay effects

Restart SHALL invalidate old process and session attribution, and SHALL NOT restore an earlier clock watermark, issuer state, committed ledger, receipt or invocation as current. The profile SHALL reconcile uncertain commits and retain replay state under applicable authority and durability contracts before admitting further protected effects.

#### Scenario: Restart invalidates earlier attribution

- **GIVEN** a prior session and an uncertain committed operation
- **WHEN** the supervisor restarts
- **THEN** it invalidates the old session and reconciles the prior outcome before admitting further protected effects.

### Requirement: LH-017 Incomplete recovery denies protected effects

If clock continuity, authenticated authority, quiescence, persistence or prior outcome cannot be established, the instance SHALL remain incomplete and deny new protected effects while permitting safe cleanup.

#### Scenario: A session lifetime becomes uncertain

- **GIVEN** the joint owner may have admitted protected processing
- **WHEN** its trusted supervisor reports that a session ended or its lifetime is ambiguous
- **THEN** the owner requires whole-instance containment and admits no new protected effect
- **AND** it retains policy state, issuer, credentials, clock and stop history while recording containment for checked cleanup.

This control models a supervisor signal. Detecting session loss, serializing it
with effect handoff and physically containing workers remain host obligations;
previously delivered bytes cannot be recalled.

#### Scenario: Monotone clock origin resets on reboot

- **GIVEN** an earlier incarnation observed a grant's expiration
- **WHEN** a reboot creates a lower monotone-clock origin and no rollback-resistant continuity is available
- **THEN** the supervisor does not reuse the earlier grant or stale state
- **AND** it reports the instance incomplete until the required authorization and replay-safe reconciliation of any prior committed evidence are established.

#### Scenario: A committed Copy precedes a setup failure

- **GIVEN** the single Copy has committed and subsequent session setup fails
- **WHEN** the supervisor handles the failure or restarts
- **THEN** it preserves the committed session, ledger and intent
- **AND** it neither replays the Copy nor substitutes a new settlement decision.
