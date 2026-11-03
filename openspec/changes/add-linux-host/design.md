# Native Linux host design

## Context

Linux already executes Writ's pure Bend model. The missing layer is a trusted
launcher and broker that establish authentic facts and confine the process using
protected data. [Host research](../../../docs/HOST-PLATFORMS.md) records the Linux
API behavior and primary sources behind this proposal.

## Goals and boundaries

Preserve the Genode-informed portable contract while using native Linux process
and IPC mechanisms. Keep authored policy, verification, and state transitions in
Bend. A runtime binding may expose existing OS primitives; it must not become a
second authorization implementation. This proposal does not supply a working
launcher, filesystem device, external-language runtime, or GPU sandbox.

## Decisions

### Separate the monitor from each worker

The broker owns authority registries, the current ledger, protected storage, and
final output transports. The worker receives only the explicitly admitted
inputs and a private result channel. It cannot mutate broker state, inspect its
memory, inherit its credentials, or open its final-destination handles.

Use a trusted launch record to bind the selected runtime image, code identity,
configuration, subject, invocation, confinement profile, and process lifetime.
The broker's host incarnation and the session/handle generation distinguish new
instances from stale numeric identifiers after restart or FD/PID reuse.

### Establish the complete profile before input delivery

The initial profile is headless and denies direct network and device access.
Its implementation combines an explicit credential/namespace configuration,
privilege removal, `no_new_privs`, architecture-aware seccomp, required Landlock
rules, and resource/lifetime controls. Each layer has a declared purpose; no
single layer is described as complete confinement.

Apply the worker restrictions before untrusted code and before multithreaded
execution unless a separately verified synchronization method covers all threads.
Any failed setup step terminates the pending worker without delivering protected
data. User-namespace availability and the launcher's needed privilege are profile
preconditions, not reasons to weaken a profile silently.

Probe the running kernel's Landlock ABI and require every right named by the
profile. Upstream examples may drop unsupported rights for broad compatibility;
Writ's protected profile instead refuses launch. Record the kernel, configuration,
ABI, runtime, and profile versions in acceptance evidence. Do not assume all Linux
distributions enable the same LSMs or namespaces.

### Authenticate channels and control descriptor transfer

Choose a bounded local broker protocol, initially over a protected Unix-domain
connection. Match kernel-provided identity evidence to the trusted launch record.
Connection credentials alone are not a per-message proof that the original
process remains the sender: descriptors can be inherited or transferred, and
`SO_PEERCRED` records connection/socketpair-time credentials. In particular,
parent-created socketpair credentials cannot be relabeled as the child's identity.

Close inherited descriptors except an explicit allowlist. Deny unneeded descriptor
imports, socket creation, shared-memory attachment, tracing, and helper-process
launch. Initial worker sessions are nondelegating under that confinement profile.
A later delegation mechanism must bind the authenticated recipient to a new
generation, preserve the exact plan and origin obligations, and only narrow
rights or expiry. A different subject or plan requires new authorization; the
sender's integer FD is never reinterpreted as the recipient's credential.

The broker copies and validates bounded request data before deciding. It resolves
resources through its own stable handles and current registry. An untrusted path
string, a reused descriptor number, or memory changed after validation cannot
select a different object. Unsupported direct-copy, mapping, ioctl, or asynchronous
paths deny until they have equivalent mediation and tests.

### Preserve authority through release and recovery

Every release uses the shared final Bend gate with current authority. Closing one
FD is not general revocation: another duplicate may still refer to the same open
file description. Revocation disables new admissions and uncommitted publication,
and the launcher retires the affected worker/staging resources according to its
cancel policy. It cannot retract data already observed or already committed.

The worker writes only private staging. The broker seals the exact output bytes,
checks the schema and execution identity, and durably publishes only the accepted
artifact with its inherited terms and state transition. Crash recovery preserves
consumed invocations and resolves partially persisted work under the original
scope. Filesystem rename alone is not a transaction across all Writ state.

### Qualify each target independently

Replay shared allowed/denied Bend vectors, then run actual native escape-path
tests for descriptors, network, logs, shared memory, tracing, subprocesses,
restart, revocation races, and publication crashes. A passing Linux model test,
container startup, or filesystem mount alone does not qualify the host.

GPU access needs a separate validated profile. The first host grants no raw GPU
device or shared buffer to a protected worker. CPU fallback may satisfy a request
only when the request permits it; an operation requiring an unavailable GPU is
denied.

## Risks and trade-offs

The host kernel and selected runtime are larger trust dependencies than a small
capability kernel. Kernel compromise and unmeasured timing channels are outside
the initial tested claim. Narrow profiles sacrifice compatibility to keep the
effective authority enumerable. More effects require new acceptance evidence.

## Migration and rollback

Add an explicit versioned Linux profile. Keep existing model-only usage clearly
identified. If a profile cannot be re-established after an update, stop admitting
protected work, preserve durable authority/replay state, and retire in-flight
workers without publishing their results through a weaker path.
