# Future kernel host design

## Context

Drift snapshot `0b7aaca7f4ff5e3da0570379632f952ecfe754f7` provides native Nelua
drivers, generated C, a resource callback ABI, selected source-import profiles,
and host recipes. Its reference kernel is a bounded driver bring-up consumer;
the documented example omits paging, scheduler, IOMMU, filesystem, network stack,
and a general physical-memory allocator. See the pinned source links in
[docs/DRIFT.md](../../../docs/DRIFT.md).

Writ already computes policy and state transitions in Bend. Its public records
do not authenticate a caller or implement an OS boundary. This host must make
those preconditions real without relocating policy into a driver callback.

## Decisions

### Preserve the Genode reference

The preferred research route supplies the Genode base primitives needed to run
the then-qualified Genode-facing Writ component on the future kernel. That involves
real object/IPC/memory/thread semantics, not a naming shim. A direct kernel host
is permitted only with separate portable-host-contract qualification. Neither
path is an existing Drift feature.

### Separate authority from resource mechanics

The kernel owns address spaces, native object references, IPC origin, device
assignment, DMA mappings, interrupt routes, and resource accounting. The Bend
monitor owns subjects, grants, graph/authority epochs, session and ledger state,
complete source manifests, and immutable artifact bindings. The broker binds
native identities to those records; a request cannot replace them.

A native reference is checked with its authenticated peer/domain instance and
object generation. A reused slot, serialized numeric handle, `drift_dma.token`,
pointer, or bus address never creates authority. Kernel-level delegation must
preserve Writ's subject and plan restrictions; a newly delegated endpoint still
passes current Writ authorization.

### Keep the Bend decision path intact

The runtime port must execute the same Bend admission, verifier, negotiation,
ledger, and commit code. A native bridge translates bounded requests and genuine
kernel results; it does not replace those decisions with equivalent-looking
native policy. Drift's generated C and upstream source profiles remain explicit
external dependencies. The bridge and freestanding Bend runtime have not been
implemented or qualified by this proposal.

### Contain worker and driver domains

Protected workers have no raw block, NIC, PCI configuration, MMIO, DMA, debug,
or unrestricted logging route. Device servers receive only resources assigned
by the kernel. Untrusted driver domains cannot map monitor or other-tenant
memory, and their failures cannot grant authority to a client. Every admitted
profile identifies its trusted kernel, bridge, drivers, runtime, and boot chain.

The resource provider validates each register window, offset, width, DMA owner,
allocation range, direction, and lifetime. A device outside the trusted host
boundary needs effective DMA containment. Without it, that device is unavailable
to protected work; an arbitrary physical address is never a fallback mapping.

### Distinguish revocation from hardware quiescence

Revocation closes new use and invalidates current release authority. It cannot
retract an already performed external effect or erase plaintext already copied
into a worker. Such a worker remains confined. A restarted domain receives a new
instance/generation, and old endpoints or completions cannot authorize it.

The host must additionally stop outstanding hardware activity before recycling
its memory. Drift's callback contract requires resources to stay valid until DMA
has stopped. A reset failure leaves buffers and device ownership quarantined;
policy expiry alone is insufficient proof of quiescence. Polling is the initial
driver mode. Any later interrupt path needs independent device/epoch binding,
bounded completion delivery, and cancellation/teardown tests.

### Publication remains a separate transaction

The final Bend gate must pass before a scoped effect is scheduled. Partial block
writes remain private artifacts until the durable publication service atomically
makes payload, inherited policy, and accepted state visible, or uses its approved
recovery/outbox equivalent. Explicit device flush does not replace transaction
identity, idempotence, or recovery after an interrupted commit.

### The runtime host profile bounds the ported runtime

The ported Bend runtime is held to the runtime host profile. The monitor
profile's allow lists in `scripts/runtime-profile/` are the contract for what
the kernel-hosted monitor binary may link and call; Drift supplies drivers and
bring-up code beneath it, not the authority boundary, so a driver symbol never
widens the allow lists. `scripts/runtime-profile/check-binary.sh` is the check,
and the kernel run belongs in `verification/runtime-profile-hosts.md`. See
[docs/BEND-RUNTIME.md](../../../docs/BEND-RUNTIME.md). The freestanding runtime
change supplies the host layer this port would reuse.

## Conformance and evidence

Run the shared policy and host traces with real authenticated peers on a booted
kernel. Compare normalized decisions, retained provenance, replay rejection, and
denied-state behavior with the Genode reference. Native handles themselves are
host-local and are not expected to have matching integer values.

Acceptance includes unauthorized mappings, forged/stale object references,
cross-subject delegation, unmediated egress, resource exhaustion, driver crash,
wrong-device and stale completions, failed reset with retained DMA, revocation
after read, and publication crash/restart. CPU-only operation is a valid initial
profile. Unsupported GPU/device effects deny; a fallback is not reported as
physical GPU or DMA-isolation evidence.

Pin Writ, Drift, Genode where used, kernel, bridge, compiler/runtime, emulator,
device model, and image hashes. Separate source review, host models, emulated
device execution, and physical-device qualification. Drift's retained records
are prior driver evidence; they are not acceptance of this Writ host.

## Rollout and failure

Start with no protected inputs. Enable a profile only after its actual kernel
primitives, runtime, resource boundary, and denial paths pass. Failed qualification
keeps the host unavailable. Recovery preserves durable consumed invocation state
and authority generations. Rollback disables new work and retains uncertain
device resources; it never substitutes raw driver access for the broker.
