# Locality-aware execution

## Why

A customer table can stay with its origin while an approved report runs beside
it. The requester should name the data and desired result; an eligible executor
can do the work without first copying the table to the requester.

The pending rendezvous design selects authenticated providers but has no
placement contract for residency, permitted data movement, source proximity, or
the confidentiality of a submitted query or model.

## What Changes

Add [locality-aware-execution](specs/locality-aware-execution/spec.md). Placement
requirements filter offers before ranking. Every selected offer binds the
actual provider, execution domain, source versions, movement plan, host profile,
and approved total cost.

The first ranking profile preserves the existing rendezvous rule: lowest approved
total quote, then canonical provider and offer identities. Quotes include agreed
movement costs. A different preference order requires a separately versioned
extension and a coordinated change to the rendezvous contract.

## Capabilities

### New Capabilities

- `locality-aware-execution`: Place approved transformations within every
  source's permitted domains and movement limits without deriving authority from
  addresses, proximity, or provider claims.

### Modified Capabilities

None. The pending `executor-rendezvous` ordering remains the first profile's
ordering; placement adds eligibility conditions and a complete quote. It does
not silently replace ER-003 with a proximity heuristic.

## Impact

New Bend placement records, eligibility checks, movement estimates, and execution
bindings. Native hosts must enforce the selected constraints and supply scoped
evidence. This does not implement a remote transport, secure multiparty
computation, a confidential-compute platform, or a working host port.

All implementation and acceptance work remains pending.

## Dependencies

- [add-executor-rendezvous](../add-executor-rendezvous/proposal.md)
- [add-portable-host-contract](../add-portable-host-contract/proposal.md)
