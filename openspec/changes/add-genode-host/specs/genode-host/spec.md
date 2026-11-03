# Genode reference host

## Purpose

Host Writ's Bend policy monitor on Genode's native capability and protection-domain mechanisms while preserving authenticated authority, exact information-flow scope, complete worker confinement, and honest platform-specific evidence.

## ADDED Requirements

### Requirement: GN-001 Platform profiles identify their enforcing configuration

A Genode host SHALL identify its pinned framework source, kernel/base platform, runtime, image, configuration, and execution environment. Validation of one profile SHALL NOT imply support or equivalent isolation on another profile.

#### Scenario: Native and hosted profiles are distinguished

- **GIVEN** an acceptance run on Genode base-hw under QEMU
- **WHEN** the host reports its supported configurations
- **THEN** that evidence applies only to the recorded base-hw profile
- **AND** base-linux remains separately qualified.

#### Scenario: A source pin changes

- **GIVEN** a profile was validated against a pinned source and configuration
- **WHEN** its framework or routing configuration changes
- **THEN** the old record is not accepted as evidence for the changed profile.

### Requirement: GN-002 The native runtime preserves Bend policy semantics

The host SHALL run Writ's authored policy, verification, and state-transition code in Bend 2 through an explicitly validated runtime/ABI boundary. Native bindings SHALL NOT supply an alternative authorization decision or bypass the complete commit gate.

#### Scenario: Runtime assumptions are unsupported

- **GIVEN** generated native output requires an unimplemented allocation or threading operation
- **WHEN** the Genode build or startup reaches that dependency
- **THEN** the host does not advertise a working Writ runtime or admit protected execution.

#### Scenario: Native policy is compared with the reference

- **GIVEN** the same authoritative inputs and denial corpus on the reference Bend backend
- **WHEN** the Genode-hosted Bend monitor evaluates them
- **THEN** the policy decisions and denied-state preservation match the reference contract.

### Requirement: GN-003 Native references remain local authority objects

The host SHALL obtain capabilities through native Genode mechanisms and resolve portable references through monitor-owned mappings. Serialized selectors, token-shaped data, and handles from another channel SHALL NOT manufacture native authority.

#### Scenario: A client submits a guessed selector

- **GIVEN** a client knows the numeric selector used by another protection domain
- **WHEN** it submits that integer as authority for a Writ request
- **THEN** the integer grants no access to the other domain's object.

#### Scenario: A portable record resembles a native capability

- **GIVEN** an untrusted message contains a well-formed Writ token and claimed native handle
- **WHEN** no current registered channel binding authenticates that reference
- **THEN** the request is denied before protected data is delivered.

### Requirement: GN-004 Delegation cannot impersonate the authenticated reader

The ingress SHALL preserve Writ's authenticated reader checks and explicit delegation policy. Possession of a delegated endpoint SHALL NOT by itself authenticate its holder as the original human or component. Untrusted workers SHALL NOT receive general commit authority.

#### Scenario: A real capability is delegated

- **GIVEN** component B receives a real session capability from component A
- **WHEN** B presents that capability as evidence that it is A's human reader
- **THEN** the ingress grants no such identity merely from possession
- **AND** denies the request unless the required actor or permitted delegation is established.

#### Scenario: A worker tries to publish directly

- **GIVEN** a transformation worker has approved inputs and a private result channel
- **WHEN** it tries to invoke a general publication endpoint
- **THEN** that authority is unavailable through its granted topology.

### Requirement: GN-005 Session routing preserves trusted identity meaning

The host SHALL distinguish parent-imposed session identity from client-selected resource text, restrict service routes explicitly, and bind routing generations to current authority. Request-body labels SHALL NOT be accepted as trusted parent assertions.

#### Scenario: A client chooses an administrator-looking label

- **GIVEN** an untrusted child selects a resource suffix resembling a privileged identity
- **WHEN** the parent routes its session request
- **THEN** the suffix does not acquire the trusted identity's policy.

#### Scenario: A route changes after session creation

- **GIVEN** a session was created under one routing generation
- **WHEN** its route or authority binding is replaced before a protected request
- **THEN** the host revalidates the current binding rather than relying on the original session creation.

### Requirement: GN-006 Protected workers have complete effect mediation

Before delivering protected inputs, the host SHALL inventory and restrict initial, inherited, requested, and delegated capabilities. Every worker-visible output route SHALL be absent or mediated under the same Writ policy, including diagnostics and device access.

#### Scenario: Public logging remains reachable

- **GIVEN** a worker lacks a NIC route but retains a public LOG or terminal session
- **WHEN** the host considers delivering protected plaintext
- **THEN** admission is denied until that output route is removed or policy-confined.

#### Scenario: A worker transfers authority through another RPC

- **GIVEN** a worker attempts to convey an input or output capability to an unrelated component
- **WHEN** that transfer is outside its approved topology
- **THEN** no receiving route grants the unrelated component the protected authority.

### Requirement: GN-007 Authority services resist client-induced blocking and excess

The host SHALL bound frames, capability arguments, allocation, and evaluation work before admission. Authority-critical entrypoints SHALL NOT synchronously invoke untrusted callbacks whose nonresponse can stop other tenants' authorization.

#### Scenario: Client supplies a nonresponding callback

- **GIVEN** a request includes a capability to a service controlled by the client
- **WHEN** that callback is not an approved bounded part of the protocol
- **THEN** the monitor rejects it without waiting on the service.

#### Scenario: Oversized request arrives

- **GIVEN** a request exceeds the profile's frame, graph, or capability-count limit
- **WHEN** the native service receives it
- **THEN** the request is rejected before protected allocation or expensive verification.

### Requirement: GN-008 Published artifacts have no remaining writers

The host SHALL establish immutable output bytes before registering a sealed artifact. Genode dataspace sealing alone SHALL NOT establish immutability while earlier writable CPU attachments or device mappings remain usable.

#### Scenario: Writer retains an old attachment

- **GIVEN** a worker mapped a result dataspace writable before it was sealed
- **WHEN** the host prepares that result for publication
- **THEN** the existing writer prevents acceptance as an immutable artifact
- **AND** publication waits for writer elimination and verified immutable capture.

#### Scenario: Result bytes change after candidate verification

- **GIVEN** a candidate passed the graph verifier
- **WHEN** its mutable output differs from the final registered artifact
- **THEN** the changed bytes cannot be published under the earlier binding.

### Requirement: GN-009 Revocation governs release without claiming data recall

The host SHALL linearize current authority checks with release, invalidate revoked endpoint authority, and quarantine or terminate affected workers as required. Revocation SHALL NOT be described as erasing plaintext already copied by a worker.

#### Scenario: Grant is revoked before release

- **GIVEN** a worker completed under a previously valid session
- **WHEN** the grant is revoked before the release decision is linearized
- **THEN** the publisher produces no output under that revoked grant.

#### Scenario: A server ignores session close

- **GIVEN** a server does not comply with the trusted parent's close request
- **WHEN** the host requires its authority to end
- **THEN** the host withholds further release and uses parent-controlled isolation or teardown
- **AND** does not report successful revocation merely because close was requested.

#### Scenario: A worker copied protected input earlier

- **GIVEN** a worker retained plaintext before its read grant was revoked
- **WHEN** the host processes revocation
- **THEN** its retained and derived state remains restricted
- **AND** no unrestricted output route is enabled as cleanup.

### Requirement: GN-010 Restarts cannot resurrect old authority

The host SHALL bind native references to current channel and service incarnations, invalidate them on replacement, and reconcile durable invocation and receipt state before admitting work after restart.

#### Scenario: Native selector is recycled

- **GIVEN** a stopped service's selector value is reused by a new service
- **WHEN** a client presents a reference from the old incarnation
- **THEN** the old reference cannot address authority in the new incarnation.

#### Scenario: A committed invocation is replayed after restart

- **GIVEN** durable state records a completed publication
- **WHEN** the monitor restarts and receives the old invocation
- **THEN** it preserves the existing receipt outcome and does not publish or charge again.

### Requirement: GN-011 Native quotas and Writ budgets remain separate

The host SHALL bound Genode RAM/capability resources before protected admission and preserve Writ's independent execution budget and replay rules. Reclaimed native quota SHALL NOT itself settle, refund, or reset a Writ reservation.

#### Scenario: Session resource quota is exhausted

- **GIVEN** a worker's resource allocation exceeds its current native quota
- **WHEN** it requests another dataspace or session
- **THEN** the allocation fails without gaining authority or exposing protected payloads through diagnostics.

#### Scenario: Teardown restores native quota

- **GIVEN** a job has an outstanding or committed Writ reservation
- **WHEN** its Genode protection domain is destroyed and quota is reclaimed
- **THEN** its monetary/accounting outcome follows the ledger protocol rather than automatic quota restoration.

### Requirement: GN-012 VFS paths cannot replace immutable object identity

The host SHALL bind actual inputs and outputs to approved object versions and sealed artifact identities independently of VFS path handles. Reconfiguration SHALL NOT substitute a new object beneath an existing approval.

#### Scenario: Existing path resolves to new content

- **GIVEN** a plan approves object A at a path
- **WHEN** VFS reconfiguration makes that path resolve to object B
- **THEN** the plan cannot read or publish B under A's approval.

#### Scenario: A destination service is replaced

- **GIVEN** a plan names one destination version and write domain
- **WHEN** the routed destination service is replaced before publication
- **THEN** the host revalidates its authoritative identity and rejects a mismatch.

### Requirement: GN-013 GPU execution requires its own compatible boundary

The initial Genode profile SHALL support CPU policy execution without requiring GPU access. A later GPU profile SHALL establish runtime compatibility, bounded device authority, protected verifier state, and physical execution evidence before claiming GPU enforcement support.

#### Scenario: A request falls back to CPU

- **GIVEN** Bend source requests a parallel device path
- **WHEN** the validated profile executes it on the CPU
- **THEN** the result is reported as CPU execution and establishes no device isolation or speedup.

#### Scenario: Device can write monitor memory

- **GIVEN** an accelerator mapping allows writes to authoritative monitor state
- **WHEN** the host evaluates that device profile for protected work
- **THEN** the profile is rejected even if its proposed candidates pass functional tests.

### Requirement: GN-014 Support claims require native adversarial evidence

The host SHALL retain positive and negative native integration evidence for each claimed profile, including its trusted components and exclusions. Source inspection, pure Bend tests, and documentation validation SHALL NOT substitute for host confinement evidence.

#### Scenario: Only the model tests have run

- **GIVEN** Writ's Bend suites and OpenSpec validation pass on a conventional host
- **WHEN** Genode support status is reported
- **THEN** the native runtime, routing, sealing, and confinement claims remain unverified.

#### Scenario: A hybrid Linux bridge is included

- **GIVEN** a base-linux profile includes a component with direct Linux host access
- **WHEN** the profile records its security boundary
- **THEN** that bridge and its inherited descriptors are explicitly covered by the profile's trust and confinement evidence.
