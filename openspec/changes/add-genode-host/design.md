# Genode reference host design

## Context

The current library owns no native protection domain or capability. Genode's
object-capability model can enforce service reachability; Writ's Bend gate must
still enforce the permitted use of information after that service is reachable.
The researched source and supporting references are in
[docs/GENODE.md](../../../docs/GENODE.md).
The selected nested-init reference and proposed public routing fixture are
scoped in the [nested routing plan](nested-routing-fixture-plan.md); no nested
profile is implemented or qualified by that plan.

## Goals and boundaries

Use Genode as the reference capability architecture while keeping one portable
Writ policy contract. Begin runtime/session development on base-linux, then qualify
the native x86_64 base-hw reference under QEMU. Both need separate protected-host
evidence. A runtime port, real service, and adversarial host tests are
prerequisites for a support claim. This design introduces no completed native
adapter and no exception to the Bend-only authored policy requirement.

## Decisions

### Pin the platform and port the runtime explicitly

Use Genode 26.08 commit `d18ee9e917200b059549e21f2dd9a55bfe61a0eb` as the initial
reference. Record the compiler, generated artifacts, runtime dependencies,
framework image, kernel, configuration, and hardware/emulator. Inventory Bend's
allocation, threading, synchronization, clock, randomness, and IO dependencies
before selecting the runtime/ABI integration. Native Genode's C++ RPC API is not
an already supplied Bend backend. Begin with CPU execution and identical policy
corpus results.

### Separate authority ingress from worker endpoints

The trusted supervisor owns worker creation and session routing. An authenticated
ingress binds a current native channel to the Writ reader and exact plan. Only
trusted monitor components hold policy and commit endpoints. The transform worker
receives approved input dataspaces and a private result channel; it receives no
general publication capability.

Native capability selectors are local names. Portable protocol fields cannot
manufacture them or impersonate a reader. A real delegated capability carries
endpoint authority; it is not evidence of the original human actor. Preserve
the facade's subject/reader checks and reject when the adapter cannot establish
the required actor or permitted delegation. Neither a proxy nor a type name makes
a capability intrinsically nondelegable.

### Preserve trusted route meaning

Session labels distinguish parent-imposed identity from client-selected resource
intent. Configure explicit service routes and narrowly scoped endpoints. The
monitor records route/configuration generations with authority bindings and
rechecks them before use. Existing sessions communicate directly after creation,
so session creation policy does not replace Writ's use-time checks. Label text in
an RPC payload is never accepted as a trusted routing assertion.

### Admit a complete effect topology

Inventory initial, inherited, dynamically requested, and delegated capabilities.
Network, terminal, GUI, file/block, logging/reporting, shared memory, signals, and
device/GPU channels are either confined to approved destinations or absent.
Diagnostics must remain policy-controlled. Authority services do not invoke
arbitrary client-supplied callbacks on their critical entrypoints. All requests
are bounded before expensive parsing, allocation, or verification.

### Seal actual bytes, not just a dataspace name

Use broker-owned staging memory with known writers. Quiesce or terminate worker
writers, copy into a fresh publication buffer that was never writable by them,
validate schema and digest, and eliminate every writable attachment/device mapping
before publishing its immutable artifact binding. Genode's `seal_ram` alone only
restricts future attachments and does not revoke earlier writable mappings.

Pin object versions independently of paths. A Genode 26.08 VFS reconfiguration
can resolve an existing path handle against different content; reauthorization
and identity verification must prevent substitution under an existing plan.

### Linearize revocation and recover durable state

Resolve the current grant and all existing Writ gates at the release point.
Destroying an RPC object invalidates its native aliases, while a server ignoring
close requires parent-enforced teardown. Already copied plaintext remains
protected information: terminate/quarantine affected workers and carry labels
through their staging state. Never reinterpret revocation as erasing knowledge.

Invalidate channel incarnations on restart, reconcile durable invocations, and
retain receipt replay state before accepting new work. A recycled selector or
RAM quota refund cannot restore an expired grant or refund an execution charge.

### Distinguish base-linux and future GPU qualification

Normal base-linux components use socket-based capability transport and seccomp;
hybrid host components and inherited descriptors need their own trust review.
Record and test that complete profile rather than treating Linux execution as
native base-hw evidence.

GPU execution is optional until a compatible Bend compute runtime and isolated
device path exist. Keep authoritative graph/state outside the device's writable
memory. CPU fallback is an explicit execution mode, not physical GPU evidence.

## Risks and trade-offs

The configuration and supervisor become part of the enforcing boundary. A
misrouted log or delegated endpoint can defeat an otherwise correct policy gate.
Per-job worker teardown and an extra output copy trade throughput for an auditable
initial boundary. Timing and other shared-hardware channels are not proven absent.
The deployment must state which kernel, runtime, drivers, and publishers it trusts.

## Migration and rollback

Enable the profile only after its native acceptance gate passes. Roll back by
disabling new protected admissions, revoking channel generations, reconciling
in-flight durable transactions, and terminating affected workers. Preserve origin
policy and replay records; do not replace a failed adapter with direct host IO.
