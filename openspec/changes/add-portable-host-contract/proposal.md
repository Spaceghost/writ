# Portable host enforcement contract

## Why

Writ has a shared Bend decision engine but no implemented native host boundary.
Genode is now the reference capability platform, with direct Linux, native
Windows, and a later Drift-backed kernel as additional targets. Matching decision
results alone would not establish equivalent authority or confinement.

## What Changes

Define the common host obligations and conformance evidence for authenticated
session binding, scoped workers, immutable artifacts, current commit authority,
and revocation. Preserve one Bend policy implementation while allowing each host
to enforce the boundary with its own native mechanisms.

## Capabilities

### New Capabilities

- `portable-host-contract`: Common native-boundary semantics and qualification
  evidence for Genode, Linux, Windows, and future kernel integrations.

### Modified Capabilities

None. Existing subject, exact-plan, provenance, and commit requirements remain.

## Impact

Future Bend service interfaces and shared conformance vectors, platform-specific
runtime/ABI bindings, and integration probes. This change provides the contract;
it does not add a native adapter, kernel, capability issuer, or sandbox.

## Dependencies

The contract is independent of any single host implementation. An enforcing
deployment also requires authenticated grant issuance, confined execution, and
durable publication. Platform changes depend on this contract; it must not depend
back on those implementations.
