# A future kernel using Drift

Use **Drift for portable device drivers beneath Writ's host boundary**. Keep
Genode as the reference for isolation, capability ownership, session routing,
and revocation. The later kernel must provide those mechanisms before it handles
protected Writ data.

This inspection is pinned to [Spaceghost/drift at
`0b7aaca`](https://github.com/Spaceghost/drift/tree/0b7aaca7f4ff5e3da0570379632f952ecfe754f7),
dated 2026-10-31. Source and retained evidence were read; no Drift target was
built or booted during this review. Writ's future kernel host remains proposed
in [add-drift-kernel-host](../openspec/changes/add-drift-kernel-host/proposal.md).

## What Drift already provides

Drift's native drivers are authored in Nelua and shipped with generated C. Its
documented native build is freestanding: the host supplies resources, and the
drivers use bounded synchronous polling. It also has a separate bounded protocol
VM and selected Linux/Windows source-import profiles. These are different driver
execution paths with separately documented scope.
([Overview](https://github.com/Spaceghost/drift/blob/0b7aaca7f4ff5e3da0570379632f952ecfe754f7/README.md),
[native contract](https://github.com/Spaceghost/drift/blob/0b7aaca7f4ff5e3da0570379632f952ecfe754f7/docs/native.md))

| Existing boundary | What it provides | What the future kernel must supply |
| --- | --- | --- |
| `drift_hw` register callbacks | Reads/writes within host-selected regions | Device discovery, ownership, bounded mappings, and permission to expose those regions |
| `drift_hw` DMA callbacks | Explicit CPU/device addresses, allocation, synchronization, and release | Address-space protection, device mappings, allocation ownership, and safe reclamation |
| `time_us` / `wait_us` | Monotonic time and a wait/yield contract | A trusted clock, scheduling, deadlines, and enforced resource quotas |
| `drift_block_*` | Common block bind/read/write/flush API | Object storage, policy metadata, publication atomicity, and crash recovery |
| `drift_net_*` | Common Ethernet frame send/receive API | A network stack and an authorized, policy-aware egress service |

The exact signatures and lifetime rules are in
[`drift_hw.h`](https://github.com/Spaceghost/drift/blob/0b7aaca7f4ff5e3da0570379632f952ecfe754f7/include/drift_hw.h)
and [`drift_io.h`](https://github.com/Spaceghost/drift/blob/0b7aaca7f4ff5e3da0570379632f952ecfe754f7/include/drift_io.h).
The `drift_dma.token` field is host bookkeeping. Its numeric value, a physical
address, a register offset, or a C pointer must never be accepted as Writ authority
merely because a caller supplies it.

## Existing ports are useful evidence, with specific scope

| Material inspected | Evidence and limit |
| --- | --- |
| [Genode speaker service](https://github.com/Spaceghost/drift/blob/0b7aaca7f4ff5e3da0570379632f952ecfe754f7/ports/genode/README.md) | Native service/client RPC, real emulated port I/O, and lifecycle checks. A separate configuration omits `IO_PORT` and expects Genode startup fail-stop. |
| [Stored Genode CI record](https://github.com/Spaceghost/drift/blob/0b7aaca7f4ff5e3da0570379632f952ecfe754f7/ports/genode/records/ci-41228402323/README.md) | Retained logs describe source `d9cbb4411c3378b96acc33fbf27cabb625419149` on Genode 26.08/base-hw under QEMU. These are earlier driver-integration records, not a Writ test or a fresh run of the inspected head. |
| [Genode Virtio RNG recipes](https://github.com/Spaceghost/drift/blob/0b7aaca7f4ff5e3da0570379632f952ecfe754f7/ports/genode/virtio-rng/README.md) | Separate Linux-source and Windows-source components use Platform/Dma resources and check emulated-device completions. The recipe explicitly excludes IOMMU and physical interrupt qualification; no RNG run was reproduced here. |
| [Hosted Linux/Windows records](https://github.com/Spaceghost/drift/blob/0b7aaca7f4ff5e3da0570379632f952ecfe754f7/benchmarks/source-import/hosts/ci-41228402217/README.md) | Stored native process/model results. A successful Windows source profile establishes neither Windows kernel-driver loading nor Writ confinement. |
| [Reference kernel](https://github.com/Spaceghost/drift/blob/0b7aaca7f4ff5e3da0570379632f952ecfe754f7/examples/kernel/README.md) | A small Multiboot x86/QEMU consumer exercises real emulated controllers. Its documented adapter omits paging, scheduler, IOMMU, filesystem, network stack, and a general physical-memory allocator. |

Drift's existing Genode code is a practical starting point for host integration:
typed session RPC, parent-provided resources, and a negative resource test already
have concrete examples. Its speaker service does not implement Writ's provenance,
paired grants, owner approvals, or complete worker confinement. Its source-import
profiles implement explicitly selected APIs; they do not provide general `.ko`
or `.sys` binary compatibility.
([Genode session/server](https://github.com/Spaceghost/drift/blob/0b7aaca7f4ff5e3da0570379632f952ecfe754f7/ports/genode/src/server/drift_speaker/main.cc),
[compatibility contract](https://github.com/Spaceghost/drift/blob/0b7aaca7f4ff5e3da0570379632f952ecfe754f7/docs/compatibility.md))

## Preferred route: preserve the Genode-facing boundary

The first research option for the future kernel is to supply the Genode base
primitives needed by Writ's Genode integration. That keeps its component and
session design while changing the kernel beneath it. Drift would supply selected
device drivers inside that system. A direct kernel adapter is an alternative
only if it separately satisfies the same [portable host contract](PLATFORMS.md).
Neither route is implemented by Drift's current callbacks or reference kernel.

The kernel work includes protected address spaces, authenticated IPC origins,
capability-table ownership, safe delegation, object lifetime and revocation,
threads and scheduling, physical-memory ownership, and controlled device access.
The [Genode integration design](GENODE.md) is the behavioral reference. A Genode
API name or structurally similar record is insufficient evidence of compatibility.

Keep Writ's admission, verification, provenance, and state transitions authored
in **Bend 2**. Drift remains an external Nelua/generated-C driver dependency.
The Bend runtime, target ABI, and bridge to native object operations require a
real port and an executable acceptance record. Compiling Bend to C does not by
itself provide a freestanding runtime or satisfy the kernel's isolation contract.

## The portable boundary to preserve

These are proposed semantic operation families, not existing Drift or Writ APIs:

| Operation family | Required meaning on every host |
| --- | --- |
| Bind a session | Obtain identity from the native authenticated channel; bind a monitor-owned reference to its subject, host/domain instance, generation, and approved scope |
| Create a worker domain | Install the executable and explicit resource routes before plaintext delivery; enforce memory, capability, execution, and output limits |
| Exchange scoped artifacts | Deliver only approved inputs, retain all their origins, and seal immutable output bytes before registering an artifact identity |
| Publish an intent | Recheck current Bend authority and apply the exact accepted state/output transaction through the durable publication contract |
| Revoke and stop | Stop new use, reject stale generations, quiesce outstanding work, and reclaim only resources proven no longer accessible |

Native Genode capabilities, Linux descriptors, Windows handles, and future
kernel capability slots stay local to their host. A portable message may name a
broker reference, but possession of that number is not authentication. Importing
or delegating a reference requires the host's authenticated channel and current
Writ policy; a change of kernel does not relax subject or plan binding.

## Device isolation must precede driver reuse

The proposed kernel gives a Drift driver only its assigned register windows and
DMA resources. Workers receive approved data services, not raw block, NIC, PCI,
MMIO, or DMA authority. Untrusted driver domains must not map the Writ monitor or
another tenant's memory. Devices outside the trusted host boundary need effective
DMA containment; an unsupported device remains unavailable to protected work.

Drift distinguishes CPU pointers from bus addresses and requires coherent or
uncached DMA plus explicit publish/acquire synchronization. The kernel must honor
those requirements without expanding the device's authorized memory. On reset
failure, Drift retains allocations until quiescence is established. A revoked
Writ grant or expired deadline cannot make a still-running DMA engine safe to
free. These are separate policy and hardware lifetime conditions.
([Resource ABI](https://github.com/Spaceghost/drift/blob/0b7aaca7f4ff5e3da0570379632f952ecfe754f7/include/drift_hw.h),
[failure contract](https://github.com/Spaceghost/drift/blob/0b7aaca7f4ff5e3da0570379632f952ecfe754f7/docs/native.md))

The current native API polls. A later interrupt adapter must bind each interrupt
and completion to its device and current generation, enforce bounded queues, and
keep stale callbacks away from reused objects. A driver crash must leave the
monitor's authority intact and prevent stale device resources from becoming a
new domain's resources. These are new kernel obligations, not claims about the
current polling drivers.

Revocation also cannot erase plaintext a worker has already copied. After a read,
confinement and inherited policy must continue until the domain is destroyed or
its state is otherwise safely contained. It cannot reopen a public output merely
because its former input capability has disappeared.

## Storage success is not publication success

`drift_block_write` can report a successful prefix while the failing hardware
command has partially written. Flush is explicit. The future storage service must
therefore keep partial artifacts unreachable and implement the
[durable publication protocol](../openspec/changes/add-durable-publication/design.md)
around payload, provenance, ledger, and session state. A flush alone is not an
atomic Writ transaction.
([Drift common I/O semantics](https://github.com/Spaceghost/drift/blob/0b7aaca7f4ff5e3da0570379632f952ecfe754f7/docs/io.md))

## Implementation order and acceptance

1. Freeze the common host traces against the Genode reference and document the
   selected kernel/profile, compiler, bridge, and trusted components.
2. Implement and attack-test memory isolation, authenticated IPC, capability
   lifetime, clocks, and quotas before admitting protected plaintext.
3. Bind one Drift-backed device in a restricted driver domain; exercise denied
   mappings, wrong-device completions, reset failure, and retained DMA.
4. Run the actual Bend authority path on the booted kernel through the chosen
   Genode base or direct host adapter; compare normalized decisions with the
   established host traces.
5. Qualify crash/restart, publication recovery, revocation after read, device
   teardown, and unsupported-feature denial. Preserve model, emulated-device,
   and physical-device evidence as separate results.

All of those integration steps remain pending. The existing Bend library and
Drift's driver examples make the boundaries concrete; they do not complete the
future kernel host.
