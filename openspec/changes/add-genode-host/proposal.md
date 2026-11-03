# Genode reference host

## Why

Writ currently checks pure authoritative records but does not supply the host
boundary protecting those records or confining a worker. Genode provides native
object capabilities, protection domains, routed sessions, and resource quotas
that should form the reference integration. Writ adds portable information-flow
and per-operation policy without treating its public records as kernel objects.

## What Changes

Introduce [genode-host](specs/genode-host/spec.md) as a new capability, initially
targeting a pinned Genode 26.08 x86_64 base-hw configuration with a separate
base-linux profile. Define the trusted component topology, capability mapping,
Bend runtime boundary, artifact sealing, revocation, and native acceptance gates.
The requirements are proposed behavior; no Genode port is declared implemented.

## Capabilities

### New Capabilities

- `genode-host`: Host Writ's Bend monitor and confined workers on Genode, preserving exact authority and release semantics through native capabilities and scoped services.

### Modified Capabilities

None. Existing Writ policy, authenticated-reader, and independent-verifier
requirements remain in force.

## Impact

Adds a reference host integration and native test images. Runtime/ABI porting,
session bindings, deployment configuration, and hardware isolation need explicit
evidence. Authored Writ policy remains Bend 2; generated backend output and the
external Genode framework are not additional Writ policy implementations.

The researched mechanism mapping and source pins are in
[docs/GENODE.md](../../../docs/GENODE.md).

## Dependencies

- [add-portable-host-contract](../add-portable-host-contract/proposal.md)
- [add-authenticated-grant-issuance](../add-authenticated-grant-issuance/proposal.md)
- [add-confined-transform-execution](../add-confined-transform-execution/proposal.md)
- [add-durable-publication](../add-durable-publication/proposal.md)
