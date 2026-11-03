# Policy-aware audit

## Why

The current library rejects invalid requests but does not persist an audit trail.
Operational evidence must record the exact authorization scope without becoming
another route for protected content, metadata, or decision reasons to escape.

## What Changes

Introduce [policy-aware-audit](specs/policy-aware-audit/spec.md) as a new
capability. Add protected event records, owner-scoped queries, verifiable append
history, and an explicit required-audit failure policy coordinated with durable
publication. This is a proposed service contract; none of these audit storage or
query facilities is currently implemented.

## Capabilities

### New Capabilities

- `policy-aware-audit`: Record and expose authorization evidence under its own
  information-flow policy, with durable required events, scoped queries and
  exports, and detectable history tampering relative to trusted anchors.

### Modified Capabilities

None. The existing library still returns pure decisions and state transitions;
the new service records their authoritative invocation context and outcome.

## Impact

New Bend event construction, policy assignment, append coordination, verification,
and query/response authorization. Durable storage, cryptographic primitives, and
transport remain explicit host dependencies. This does not add a second policy
engine in another language or a claim of whole-system noninterference.

## Dependencies

- [add-durable-publication](../add-durable-publication/proposal.md)
