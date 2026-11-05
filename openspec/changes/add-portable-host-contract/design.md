# Portable host contract design

## Decision

Use Genode's native capability/session architecture as the reference. Keep the
policy, negotiation, ledger, and verification logic in Bend 2 across all hosts.
The host maps its native authenticated resources into monitor-owned facts and
executes only the effects admitted by that logic.

The target matrix and source-backed reasoning are in
[docs/PLATFORMS.md](../../../docs/PLATFORMS.md). This package specifies new behavior;
no host-enforcement implementation is implied.

## Native authority versus Writ policy

Native capabilities establish object reachability. Writ adds the exact plan,
origin obligations, source/destination pairing, labels, approvals, budget, and
current commit checks. A successful native RPC never substitutes for those checks.

The bridge retains the native capability/FD/HANDLE in a local resource table.
Any Bend-visible reference names that trusted table entry; it is not reconstructed
by casting a message integer into native authority. Host incarnation and resource
generation prevent old references from resolving after restart or handle reuse.
Duplicate current mappings are rejected rather than resolved by ordering.

## Subject identity and delegation

Distinguish bearer authority from authenticated actor identity. Genode permits
capability delegation; descriptors and handles can also be transferred or inherited.
A native endpoint may identify the service object without identifying the actual
current caller. The adapter must establish the identity/delegation semantics that
the Writ subject-bound grant requires, or deny the request.

The first topology keeps Writ commit authority inside the trusted supervisor.
Workers receive approved inputs and a private result channel, not an externally
delegable release session. A proxy endpoint alone is not nondelegable. Any later
bearer/delegated use must preserve the exact plan and contributing-owner terms,
only narrow rights/lifetime, and explicitly reauthorize any changed subject.
Changing inputs or destination creates a new plan requiring complete admission;
it is not an attenuation of an existing exact-plan grant.

## Runtime boundary

The portable implementation owns policy decisions. Target bindings provide the
necessary allocation, scheduling, clock, entropy, IPC, isolation, and persistence
primitives. Native compilation is a separate milestone from confinement. Generated
backend artifacts and upstream OS/framework code stay in the dependency inventory;
no unreviewed native branch may duplicate or bypass the Bend release decision.

Define a bounded, versioned, canonical binary request format before transport work.
Specify byte order, integer widths, variant tags, lengths, and unknown-version
rejection. Native resource references never become transferable credentials by
serialization. Do not accept a peer-supplied Context, Ledger, Binding, or caller
identity as a monitor fact.

## Five primitive families

1. Bind authenticated sessions and their permitted delegation.
2. Create bounded worker domains and account for every observable source/effect.
3. Exchange scoped inputs and immutably sealed result artifacts.
4. Revalidate and durably publish one approved invocation.
5. Revoke, quiesce, and tear down resources without stale reuse.

Unsupported primitive requirements deny protected admission. Profiles cannot
silently drop controls to match an older kernel or a convenient development host.

## Publication and revocation ordering

The monitor owns one serialization boundary for policy updates, consent, handle
state, the ledger, and publication authorization. Revocation committed before that
authorization must deny it. Publication already authorized at that boundary is
reconciled through the durable-publication protocol; a change in timing does not
justify duplicate effects or a retroactive promise to recall released data.

An input read can create enduring knowledge. Closing a service or unmapping a
buffer does not erase earlier copies. To prevent post-revocation leakage from a
worker, retain confinement, stop its effects, quiesce asynchronous IO/DMA, invalidate
completions from old generations, and reclaim memory only when safe. Any stronger
data-recall guarantee is outside this contract.

Artifact sealing requires absence of all mutable aliases and writers, including
devices and retained mappings. A path, read-only consumer handle, renamed file, or
single read-only mapping does not establish immutability. Publication binds the
actual immutable object/version and bytes registered for that exact invocation.

## Qualification corpus

Shared Bend vectors exercise identical allow/deny, output-policy, state, replay,
and revocation decisions. Each real host also runs adversarial native probes for
forged/transferred handles, cached mappings, inherited channels, helper processes,
public logs, sockets, output substitution, restart, quota exhaustion, and crashes.
Passing the pure vectors is necessary but not sufficient for protected operation.

Compare logical outcomes and retained policy across hosts; do not require identical
native handle values, scheduling, or timing. Record exact target and runtime pins.
Report library, protocol, isolation, durable-publication, and accelerator milestones
separately. Section 1 (the shared Bend interfaces and conformance vectors) is implemented as a library model; section 2 (host qualification: feature negotiation, native adversarial probes, alias elimination and durable publication under revocation and crash, and per-target runtime evidence) remains pending.

The section 1 model implements these rulings. The holder of an identity entry
is the bound session, not the subject: another session of the same subject and
token holds nothing. Execution profiles, session roles, and client
delegability are monitor state. A target's facts can only narrow them, never
name a profile, and worker sessions are bound non-delegable. Admission allows
one unreclaimed worker per identity entry. Identity slots are never reused
within an incarnation, and a retired reference is denied `Retired`. `issue`
binds a root to its Frontend handle's plan, owner (subject and token), rights,
and lease. The only publication route is `HostPublication.publish` through
`DataOS.commit_from_capability`, which re-binds the plan. Recovery repeats only
the recorded invocation, digest, and destination. Revocation proceeds as
revoke, then quiesce, then reclaim, and recalls nothing. The traceability file
[portable-host-contract.md](../../traceability/portable-host-contract.md) maps
each ruling to its checks and to the gaps that remain.

## Migration and rollback

Introduce versioned profiles without changing existing library semantics. Disable
new protected work when required controls, identities, or versions are unavailable.
Reconcile in-flight work under its original scope and preserve epochs, consumed
receipts, and sealed artifact identities. Never fall back to an unconfined host,
an older authority snapshot, or an alternate publication API.
