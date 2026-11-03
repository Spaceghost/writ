# Future kernel host using Drift

## Why

Writ needs a route from the Genode reference and Linux/Windows hosts to a later
kernel of its own. Drift provides portable device drivers and concrete host
recipes, while the future kernel must provide isolation, capabilities, IPC, and
durable effects. A driver library or booted driver demonstration does not supply
those Writ enforcement guarantees.

## What Changes

Introduce [drift-kernel-host](specs/drift-kernel-host/spec.md) as a future host
capability. Prefer researching a Genode base port over the new kernel so the
Genode-facing Writ integration can be reused. A direct kernel adapter must
independently pass the same portable host contract.

All policy and verification remain authored in Bend 2. Drift's upstream Nelua
and generated C remain an explicit driver dependency. This proposal adds no
kernel, native bridge, working port, or claim of hardware qualification.

## Capabilities

### New Capabilities

- `drift-kernel-host`: Enforce the portable Writ host contract on a future kernel
  using explicitly scoped Drift driver resources and independently qualified
  memory, capability, IPC, device, and publication mechanisms.

### Modified Capabilities

None. Existing library contracts and pending host prerequisites continue to apply.

## Impact

Future work includes a selected kernel and optional Genode base port, Bend
runtime/ABI support, native capability bindings, isolated driver domains, DMA
containment, quiescence, and a durable publication service. The implementation
must preserve Writ's current data and authority model across that change of host.

## Dependencies

- [add-portable-host-contract](../add-portable-host-contract/proposal.md)
- [add-genode-host](../add-genode-host/proposal.md)
- [add-confined-transform-execution](../add-confined-transform-execution/proposal.md)
- [add-durable-publication](../add-durable-publication/proposal.md)

The pinned Drift inspection and source evidence are in
[docs/DRIFT.md](../../../docs/DRIFT.md).
